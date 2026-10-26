import base64
import math
import os
import re
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional

import aiofiles
from fastapi import WebSocket
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.models import (
    Chat,
    ChatMember,
    ChatType,
    CustomEmoji,
    CustomEmojiSet,
    MediaUploadChunk,
    MemberRole,
    Message,
    MessageType,
    Sticker,
    StickerSet,
    User,
    UserCustomEmojiSet,
    UserStickerSet,
)
from app.services.encryption import decrypt_file_to_bytes
from app.services.utils import _guess_mime, increment_unread, serialise_message, static_url
from app.ws.connection_manager import push_to_chat
from app.ws.handlers.chat_handler import _can_send


def _user_max_file_size(user: User) -> int:
    from app.services.plan_svc import user_limits

    return user_limits(user)["file_size_limit"]


async def handle_init_upload(payload: dict, db: AsyncSession, user: User) -> dict:
    filename = payload.get("filename")
    total_chunks = payload.get("total_chunks")
    file_size = payload.get("file_size")
    media_subtype = payload.get("media_subtype", "media")

    max_file_size = _user_max_file_size(user)
    if not file_size or file_size <= 0:
        return {"error": "file_size is required"}
    if file_size > max_file_size:
        return {"error": f"File size exceeds limit of {max_file_size / 1024 / 1024:.0f} MB (got {file_size / 1024 / 1024:.2f} MB)"}
    if not total_chunks or total_chunks <= 0:
        return {"error": "total_chunks is required"}
    # A client could declare a small file_size but then upload more/larger
    # chunks than that implies. Bound the chunk count against the declared
    # size so the cumulative-bytes check below can't be out-run.
    if total_chunks > math.ceil(file_size / settings.CHUNK_SIZE) + 1:
        return {"error": "total_chunks does not match declared file_size"}

    if media_subtype not in ("media", "voice", "circle"):
        return {"error": "media_subtype must be media, voice, or circle"}
    upload_id = uuid.uuid4().hex
    ext = filename.rsplit(".", 1)[-1] if "." in filename else "bin"
    subdir = media_subtype if media_subtype in ("voice", "circles") else "media"
    temp_name = f"{subdir}/{user.id}_{upload_id}.{ext}"
    temp_path = os.path.join(settings.UPLOAD_DIR, temp_name)
    os.makedirs(os.path.dirname(temp_path), exist_ok=True)
    async with aiofiles.open(temp_path, "wb"):
        pass
    db.add(
        MediaUploadChunk(
            upload_id=upload_id,
            user_id=user.id,
            filename=filename,
            media_subtype=media_subtype,
            total_chunks=total_chunks,
            received_chunks=0,
            received_bytes=0,
            max_bytes=max_file_size,
            temp_path=temp_path,
        )
    )
    await db.flush()
    return {"upload_id": upload_id, "chunk_size": settings.CHUNK_SIZE}


async def handle_upload_chunk(payload: dict, db: AsyncSession, user: User) -> dict:
    upload_id = payload.get("upload_id")
    chunk_index = payload.get("chunk_index")
    chunk_b64 = payload.get("chunk_base64")
    r = await db.execute(
        select(MediaUploadChunk).where(
            MediaUploadChunk.upload_id == upload_id,
            MediaUploadChunk.user_id == user.id,
        )
    )
    up = r.scalar_one_or_none()
    if not up:
        return {"error": "Upload session not found"}
    try:
        data = base64.b64decode(chunk_b64)
    except Exception:
        return {"error": "Invalid base64 chunk"}

    if up.received_bytes + len(data) > up.max_bytes:
        try:
            os.remove(up.temp_path)
        except OSError:
            pass
        await db.execute(delete(MediaUploadChunk).where(MediaUploadChunk.id == up.id))
        return {"error": f"Upload exceeds the {up.max_bytes / 1024 / 1024:.0f} MB limit"}

    async with aiofiles.open(up.temp_path, "r+b") as f:
        await f.seek(chunk_index * settings.CHUNK_SIZE)
        await f.write(data)
    up.received_chunks += 1
    up.received_bytes += len(data)
    complete = up.received_chunks >= up.total_chunks
    return {
        "upload_id": upload_id,
        "chunk_index": chunk_index,
        "received": up.received_chunks,
        "total": up.total_chunks,
        "complete": complete,
    }


async def handle_get_file(payload: dict, db: AsyncSession, user: User) -> dict:
    file_path = payload.get("file_path")
    if not file_path:
        return {"error": "file_path is required"}

    base_dir = os.path.abspath(settings.UPLOAD_DIR)
    safe_relative_path = file_path.lstrip("/\\")
    full_path = os.path.abspath(os.path.join(base_dir, safe_relative_path))

    if not full_path.startswith(base_dir + os.sep) and full_path != base_dir:
        return {"error": "Security error: invalid or malicious file path"}

    db_path = file_path.replace("\\", "/")
    from app.services.media_retention import available_message_clause

    r = await db.execute(
        select(Message)
        .join(ChatMember, ChatMember.chat_id == Message.chat_id)
        .where(
            Message.media_path == db_path,
            available_message_clause(),
            ChatMember.user_id == user.id,
            ChatMember.is_banned == False,
        )
        .order_by(Message.id.desc())
    )
    msg = r.scalars().first()
    if not msg:
        return {"error": "File not found or not associated with any chat"}

    enc_path = full_path + ".enc"
    target_path = enc_path if os.path.exists(enc_path) else full_path
    if not os.path.exists(target_path):
        return {"error": "Physical file not found on server"}

    async with aiofiles.open(target_path, "rb") as f:
        file_bytes = await f.read()

    if not msg.is_e2ee and msg.media_iv and msg.media_tag:
        try:
            file_bytes = decrypt_file_to_bytes(target_path, msg.media_iv, msg.media_tag)
        except Exception as e:
            return {"error": f"Failed to decrypt file on server: {str(e)}"}

    file_b64 = base64.b64encode(file_bytes).decode("utf-8")
    return {
        "file_path": file_path,
        "filename": msg.media_name,
        "mime_type": msg.media_type or "application/octet-stream",
        "is_e2ee": msg.is_e2ee,
        "data_base64": file_b64,
    }


async def handle_create_sticker_set(payload: dict, db: AsyncSession, user: User) -> dict:
    name = str(payload.get("name") or "").strip().lower()
    title = str(payload.get("title") or "").strip()
    if not re.fullmatch(r"[a-z0-9_]{3,64}", name):
        return {"error": "Sticker set name must contain 3-64 Latin letters, digits or underscores"}
    if not 1 <= len(title) <= 128:
        return {"error": "Sticker set title must contain 1-128 characters"}
    if await db.scalar(select(StickerSet.id).where(StickerSet.name == name)):
        return {"error": "Sticker set name is already taken"}
    sticker_set = StickerSet(owner_id=user.id, name=name, title=title, is_public=bool(payload.get("is_public", True)))
    db.add(sticker_set)
    await db.flush()
    db.add(UserStickerSet(user_id=user.id, set_id=sticker_set.id))
    return {"id": sticker_set.id, "name": name, "title": title, "is_public": sticker_set.is_public}


async def handle_add_sticker(payload: dict, db: AsyncSession, user: User) -> dict:
    from app.services.public_media_uploads import save_public_media
    try:
        set_id = int(payload.get('set_id', 0))
    except (TypeError, ValueError):
        return {'error': 'Invalid sticker metadata'}
    sticker_set = await db.scalar(select(StickerSet).where(StickerSet.id == set_id, StickerSet.owner_id == user.id))
    if not sticker_set:
        return {'error': 'Sticker set not found or access denied'}
    try:
        media = await save_public_media(payload, db, user, directory=f'stickers/{set_id}',
            limit=25 * 1024 * 1024, image_limit=5 * 1024 * 1024,
            max_seconds=10, max_dimension=2048)
    except ValueError as error:
        return {'error': str(error)}
    sticker = Sticker(set_id=set_id, file_path=media['path'],
        emoji=str(payload.get('emoji') or '')[:32] or None,
        width=media['width'], height=media['height'], media_type=media['mime'],
        duration_seconds=max(1, math.ceil(media['duration'])) if media['is_video'] else None,
        file_size=media['size'])
    db.add(sticker)
    await db.flush()
    return {'id': sticker.id, 'set_id': set_id, 'url': static_url(media['path']),
        'media_type': media['mime'], 'duration_seconds': sticker.duration_seconds,
        'width': media['width'], 'height': media['height']}


async def handle_save_sticker_set(payload: dict, db: AsyncSession, user: User) -> dict:
    try:
        set_id = int(payload.get("set_id", 0))
    except (TypeError, ValueError):
        return {"error": "Invalid set_id"}
    sticker_set = await db.scalar(select(StickerSet).where(StickerSet.id == set_id, StickerSet.is_public == True))
    if not sticker_set:
        return {"error": "Sticker set not found"}
    existing = await db.scalar(
        select(UserStickerSet.id).where(UserStickerSet.user_id == user.id, UserStickerSet.set_id == set_id)
    )
    if not existing:
        db.add(UserStickerSet(user_id=user.id, set_id=set_id))
    return {"saved": True, "set_id": set_id}


async def handle_remove_sticker_set(payload: dict, db: AsyncSession, user: User) -> dict:
    try:
        set_id = int(payload.get("set_id", 0))
    except (TypeError, ValueError):
        return {"error": "Invalid set_id"}
    sticker_set = await db.get(StickerSet, set_id)
    if not sticker_set:
        return {"error": "Sticker set not found"}
    if sticker_set.owner_id == user.id and payload.get("delete_permanently") is True:
        stickers = (await db.execute(select(Sticker).where(Sticker.set_id == set_id))).scalars().all()
        await db.execute(delete(UserStickerSet).where(UserStickerSet.set_id == set_id))
        await db.execute(delete(Sticker).where(Sticker.set_id == set_id))
        await db.delete(sticker_set)
        for item in stickers:
            try:
                Path(settings.UPLOAD_DIR, item.file_path).resolve().unlink(missing_ok=True)
            except OSError:
                pass
        return {"deleted": True, "set_id": set_id}
    await db.execute(delete(UserStickerSet).where(UserStickerSet.user_id == user.id, UserStickerSet.set_id == set_id))
    return {"saved": False, "set_id": set_id}


async def handle_delete_sticker(payload: dict, db: AsyncSession, user: User) -> dict:
    try:
        sticker_id = int(payload.get("sticker_id", 0))
    except (TypeError, ValueError):
        return {"error": "Invalid sticker_id"}
    sticker = await db.scalar(
        select(Sticker)
        .join(StickerSet, StickerSet.id == Sticker.set_id)
        .where(Sticker.id == sticker_id, StickerSet.owner_id == user.id)
    )
    if not sticker:
        return {"error": "Sticker not found or access denied"}
    await db.delete(sticker)
    try:
        Path(settings.UPLOAD_DIR, sticker.file_path).resolve().unlink(missing_ok=True)
    except OSError:
        pass
    return {"deleted": True, "sticker_id": sticker_id}


async def handle_list_sticker_sets(payload: dict, db: AsyncSession, user: User) -> dict:
    rows = (await db.execute(
        select(StickerSet)
        .join(UserStickerSet, UserStickerSet.set_id == StickerSet.id)
        .where(UserStickerSet.user_id == user.id)
        .order_by(UserStickerSet.added_at.desc())
    )).scalars().all()
    result = []
    for sticker_set in rows:
        stickers = (await db.execute(
            select(Sticker).where(Sticker.set_id == sticker_set.id).order_by(Sticker.id)
        )).scalars().all()
        result.append({
            "id": sticker_set.id,
            "name": sticker_set.name,
            "title": sticker_set.title,
            "is_public": sticker_set.is_public,
            "stickers": [
                {
                    "id": item.id,
                    "url": static_url(item.file_path),
                    "emoji": item.emoji,
                    "media_type": item.media_type,
                    "duration_seconds": item.duration_seconds,
                    "width": item.width,
                    "height": item.height,
                    "file_size": item.file_size,
                }
                for item in stickers
            ],
        })
    return {"sets": result}

async def handle_get_sticker_set(payload: dict, db: AsyncSession, user: User) -> dict:
    set_id = payload.get("set_id")
    sticker_id = payload.get("sticker_id")
    if (not set_id or int(set_id or 0) == 0) and sticker_id:
        try:
            st = await db.scalar(select(Sticker).where(Sticker.id == int(sticker_id)))
            if st:
                set_id = st.set_id
        except (TypeError, ValueError):
            pass
    try:
        set_id = int(set_id or 0)
    except (TypeError, ValueError):
        return {"error": "Invalid set_id"}
    if not set_id:
        return {"error": "Sticker set not found"}

    sticker_set = await db.get(StickerSet, set_id)
    if not sticker_set:
        return {"error": "Sticker set not found"}

    saved = await db.scalar(select(UserStickerSet.id).where(
        UserStickerSet.user_id == user.id,
        UserStickerSet.set_id == set_id,
    ))
    if not sticker_set.is_public and sticker_set.owner_id != user.id and not saved:
        return {"error": "Sticker set is private"}

    stickers = (await db.execute(
        select(Sticker).where(Sticker.set_id == set_id).order_by(Sticker.id)
    )).scalars().all()

    return {
        "id": sticker_set.id,
        "name": sticker_set.name,
        "title": sticker_set.title,
        "is_public": bool(sticker_set.is_public),
        "is_saved": bool(saved),
        "is_owner": sticker_set.owner_id == user.id,
        "share_url": f"https://ni-os.ru/stickers/{sticker_set.id}",
        "stickers": [
            {
                "id": item.id,
                "set_id": item.set_id,
                "url": static_url(item.file_path),
                "emoji": item.emoji or "",
                "media_type": item.media_type,
                "duration_seconds": item.duration_seconds,
                "width": item.width,
                "height": item.height,
                "file_size": item.file_size,
            }
            for item in stickers
        ],
    }



_EMOJI_SHORTCODE_RE = re.compile(r"[a-z0-9_]{2,64}")


async def handle_create_emoji_set(payload: dict, db: AsyncSession, user: User) -> dict:
    from app.services.plan_svc import user_limits

    name = str(payload.get("name") or "").strip().lower()
    title = str(payload.get("title") or "").strip()
    if not re.fullmatch(r"[a-z0-9_]{3,64}", name):
        return {"error": "Emoji pack name must contain 3-64 Latin letters, digits or underscores"}
    if not 1 <= len(title) <= 128:
        return {"error": "Emoji pack title must contain 1-128 characters"}
    if await db.scalar(select(CustomEmojiSet.id).where(CustomEmojiSet.name == name)):
        return {"error": "Emoji pack name is already taken"}

    owned_packs = await db.scalar(
        select(func.count(UserCustomEmojiSet.id)).where(UserCustomEmojiSet.user_id == user.id)
    ) or 0
    limit = user_limits(user)["emoji_packs_limit"]
    if owned_packs >= limit:
        return {"error": f"Emoji pack limit reached ({limit}). Get Nios+ to raise it."}

    emoji_set = CustomEmojiSet(owner_id=user.id, name=name, title=title, is_public=bool(payload.get("is_public", True)))
    db.add(emoji_set)
    await db.flush()
    db.add(UserCustomEmojiSet(user_id=user.id, set_id=emoji_set.id))
    return {"id": emoji_set.id, "name": name, "title": title, "is_public": emoji_set.is_public}


async def handle_add_custom_emoji(payload: dict, db: AsyncSession, user: User) -> dict:
    try:
        set_id = int(payload.get("set_id", 0))
        width = int(payload.get("width", 0))
        height = int(payload.get("height", 0))
    except (TypeError, ValueError):
        return {"error": "Invalid emoji metadata"}
    emoji_set = await db.scalar(select(CustomEmojiSet).where(CustomEmojiSet.id == set_id, CustomEmojiSet.owner_id == user.id))
    if not emoji_set:
        return {"error": "Emoji pack not found or access denied"}

    shortcode = str(payload.get("shortcode") or "").strip().lower()
    if not _EMOJI_SHORTCODE_RE.fullmatch(shortcode):
        return {"error": "Shortcode must be 2-64 Latin letters, digits or underscores"}
    if await db.scalar(select(CustomEmoji.id).where(CustomEmoji.shortcode == shortcode)):
        return {"error": "Shortcode is already taken"}

    if width <= 0 or height <= 0:
        return {"error": "Invalid emoji dimensions"}
    ratio = max(width, height) / min(width, height)
    if ratio > 2.0:
        return {"error": "Emoji must be square (1:1) up to landscape 2:1"}

    filename = str(payload.get("filename") or "emoji.webp")
    ext = (filename.rsplit(".", 1)[-1] if "." in filename else "webp").lower()
    image_exts = {"png", "webp", "gif"}
    video_exts = {"mp4", "webm"}
    adaptive_exts = {"svg"}
    if ext not in image_exts | video_exts | adaptive_exts:
        return {"error": "Unsupported emoji format"}
    try:
        data = base64.b64decode(str(payload.get("data_base64") or ""), validate=True)
    except Exception:
        return {"error": "Invalid base64"}
    if not data or len(data) > settings.CUSTOM_EMOJI_MAX_BYTES:
        return {"error": f"Emoji file is empty or exceeds {settings.CUSTOM_EMOJI_MAX_BYTES // 1024} KB"}

    from app.services.custom_emojis import validate_image
    from app.services.public_media_uploads import save_public_media
    verified_video = None
    try:
        if ext in video_exts:
            verified_video = await save_public_media(
                payload, db, user, directory=f'emoji/{set_id}',
                limit=settings.CUSTOM_EMOJI_MAX_BYTES,
                max_seconds=settings.CUSTOM_EMOJI_MAX_SECONDS,
                max_dimension=2048, max_aspect_ratio=2, require_video=True,
            )
            width, height = verified_video['width'], verified_video['height']
            actual_animated, actual_duration = True, verified_video['duration']
        else:
            inspected = validate_image(data, ext, settings.CUSTOM_EMOJI_MAX_SECONDS)
            width, height, actual_animated, actual_duration = inspected
    except ValueError as exc:
        return {"error": str(exc)}
    is_adaptive = ext in adaptive_exts or (ext in image_exts and payload.get('is_adaptive') is True)
    if ext in adaptive_exts:
        # Rendered client-side as a CSS mask (recolourable, adapts to theme/accent) —
        # never embedded inline, so no script-execution surface even from untrusted SVG.
        try:
            text_head = data[:512].decode("utf-8", errors="strict").lower()
        except UnicodeDecodeError:
            return {"error": "Adaptive emoji must be a UTF-8 SVG file"}
        if "<svg" not in text_head:
            return {"error": "Adaptive emoji must be a valid SVG file"}

    is_animated = actual_animated
    duration = actual_duration
    if is_animated:
        if not isinstance(duration, (int, float)) or duration <= 0 or duration > settings.CUSTOM_EMOJI_MAX_SECONDS:
            return {"error": f"Animated emoji duration must be 1-{settings.CUSTOM_EMOJI_MAX_SECONDS} seconds"}
    else:
        duration = None

    if verified_video is not None:
        relative, mime = verified_video['path'], verified_video['mime']
    else:
        relative = f"emoji/{set_id}/{uuid.uuid4().hex}.{ext}"
        full_path = os.path.join(settings.UPLOAD_DIR, relative)
        os.makedirs(os.path.dirname(full_path), exist_ok=True)
        async with aiofiles.open(full_path, "wb") as file_handle:
            await file_handle.write(data)
        mime = _guess_mime(filename)
    emoji = CustomEmoji(
        set_id=set_id,
        shortcode=shortcode,
        file_path=relative,
        media_type=mime,
        is_animated=is_animated,
        is_adaptive=is_adaptive,
        duration_seconds=max(1, math.ceil(duration)) if duration else None,
        width=width,
        height=height,
        file_size=len(data),
    )
    db.add(emoji)
    await db.flush()
    return {
        "id": emoji.id,
        "set_id": set_id,
        "shortcode": shortcode,
        "url": static_url(relative),
        "media_type": mime,
        "is_animated": is_animated,
        "is_adaptive": is_adaptive,
        "duration_seconds": emoji.duration_seconds,
        "width": width,
        "height": height,
    }


async def handle_save_emoji_set(payload: dict, db: AsyncSession, user: User) -> dict:
    from app.services.plan_svc import user_limits

    try:
        set_id = int(payload.get("set_id", 0))
    except (TypeError, ValueError):
        return {"error": "Invalid set_id"}
    emoji_set = await db.scalar(select(CustomEmojiSet).where(CustomEmojiSet.id == set_id, CustomEmojiSet.is_public == True))
    if not emoji_set:
        return {"error": "Emoji pack not found"}
    existing = await db.scalar(
        select(UserCustomEmojiSet.id).where(UserCustomEmojiSet.user_id == user.id, UserCustomEmojiSet.set_id == set_id)
    )
    if not existing:
        owned_packs = await db.scalar(
            select(func.count(UserCustomEmojiSet.id)).where(UserCustomEmojiSet.user_id == user.id)
        ) or 0
        limit = user_limits(user)["emoji_packs_limit"]
        if owned_packs >= limit:
            return {"error": f"Emoji pack limit reached ({limit}). Get Nios+ to raise it."}
        db.add(UserCustomEmojiSet(user_id=user.id, set_id=set_id))
    return {"saved": True, "set_id": set_id}


async def handle_remove_emoji_set(payload: dict, db: AsyncSession, user: User) -> dict:
    try:
        set_id = int(payload.get("set_id", 0))
    except (TypeError, ValueError):
        return {"error": "Invalid set_id"}
    emoji_set = await db.get(CustomEmojiSet, set_id)
    if not emoji_set:
        return {"error": "Emoji pack not found"}
    if emoji_set.owner_id == user.id and payload.get("delete_permanently") is True:
        emojis = (await db.execute(select(CustomEmoji).where(CustomEmoji.set_id == set_id))).scalars().all()
        await db.execute(delete(UserCustomEmojiSet).where(UserCustomEmojiSet.set_id == set_id))
        await db.execute(delete(CustomEmoji).where(CustomEmoji.set_id == set_id))
        await db.delete(emoji_set)
        for item in emojis:
            try:
                Path(settings.UPLOAD_DIR, item.file_path).resolve().unlink(missing_ok=True)
            except OSError:
                pass
        return {"deleted": True, "set_id": set_id}
    await db.execute(delete(UserCustomEmojiSet).where(UserCustomEmojiSet.user_id == user.id, UserCustomEmojiSet.set_id == set_id))
    return {"saved": False, "set_id": set_id}


async def handle_delete_custom_emoji(payload: dict, db: AsyncSession, user: User) -> dict:
    try:
        emoji_id = int(payload.get("emoji_id", 0))
    except (TypeError, ValueError):
        return {"error": "Invalid emoji_id"}
    emoji = await db.scalar(
        select(CustomEmoji)
        .join(CustomEmojiSet, CustomEmojiSet.id == CustomEmoji.set_id)
        .where(CustomEmoji.id == emoji_id, CustomEmojiSet.owner_id == user.id)
    )
    if not emoji:
        return {"error": "Emoji not found or access denied"}
    await db.delete(emoji)
    try:
        Path(settings.UPLOAD_DIR, emoji.file_path).resolve().unlink(missing_ok=True)
    except OSError:
        pass
    return {"deleted": True, "emoji_id": emoji_id}


async def handle_list_emoji_sets(payload: dict, db: AsyncSession, user: User) -> dict:
    rows = (await db.execute(
        select(CustomEmojiSet)
        .join(UserCustomEmojiSet, UserCustomEmojiSet.set_id == CustomEmojiSet.id)
        .where(UserCustomEmojiSet.user_id == user.id)
        .order_by(UserCustomEmojiSet.added_at.desc())
    )).scalars().all()
    # Official packs are free and available to everyone, without needing a
    # UserCustomEmojiSet row and without counting against the pack-count limit.
    official_rows = (await db.execute(
        select(CustomEmojiSet).where(CustomEmojiSet.is_official == True)
    )).scalars().all()
    official_ids = {o.id for o in official_rows}
    all_sets = list(official_rows) + [s for s in rows if s.id not in official_ids]
    result = []
    for emoji_set in all_sets:
        emojis = (await db.execute(
            select(CustomEmoji).where(CustomEmoji.set_id == emoji_set.id).order_by(CustomEmoji.id)
        )).scalars().all()
        result.append({
            "id": emoji_set.id,
            "name": emoji_set.name,
            "title": emoji_set.title,
            "owner_id": emoji_set.owner_id,
            "is_public": emoji_set.is_public,
            "is_official": emoji_set.is_official,
            "emojis": [
                {
                    "id": item.id,
                    "shortcode": item.shortcode,
                    "url": static_url(item.file_path),
                    "media_type": item.media_type,
                    "is_animated": item.is_animated,
                    "is_adaptive": item.is_adaptive,
                    "duration_seconds": item.duration_seconds,
                    "width": item.width,
                    "height": item.height,
                    "file_size": item.file_size,
                }
                for item in emojis
            ],
        })
    return {"sets": result}


async def handle_send_sticker(payload: dict, db: AsyncSession, user: User, sender_ws: Optional[WebSocket] = None) -> dict:
    try:
        chat_id = int(payload.get("chat_id", 0))
        sticker_id = int(payload.get("sticker_id", 0))
    except (TypeError, ValueError):
        return {"error": "Invalid chat_id or sticker_id"}
    await _can_send(db, chat_id, user.id)
    from app.services.ordinary_e2ee import required as ordinary_required
    if await ordinary_required(db, chat_id, user):
        return {'error': 'E2E_REQUIRED: Обновите приложение для отправки защищённых стикеров.'}
    sticker = await db.scalar(select(Sticker).where(Sticker.id == sticker_id))
    if not sticker:
        return {"error": "Sticker not found"}
    sticker_set = await db.scalar(select(StickerSet).where(StickerSet.id == sticker.set_id))
    saved = await db.scalar(
        select(UserStickerSet.id).where(UserStickerSet.user_id == user.id, UserStickerSet.set_id == sticker.set_id)
    )
    if not saved and (not sticker_set or not sticker_set.is_public):
        return {"error": "Sticker is unavailable"}
    chat = await db.scalar(select(Chat).where(Chat.id == chat_id))
    if not chat:
        return {"error": "Chat not found"}
    if chat.is_secret:
        return {"error": "SECRET_CIPHERTEXT_REQUIRED"}
    if chat.chat_type == ChatType.DIRECT:
        other_id = chat.user2_id if chat.user1_id == user.id else chat.user1_id
        if other_id:
            omr = await db.execute(select(ChatMember).where(
                ChatMember.chat_id == chat_id,
                ChatMember.user_id == other_id,
            ))
            om = omr.scalar_one_or_none()
            if not om:
                db.add(ChatMember(chat_id=chat_id, user_id=other_id, role=MemberRole.MEMBER))
                await db.flush()
            elif om.is_banned:
                om.is_banned = False
                await db.flush()
    message = Message(
        chat_id=chat_id,
        sender_id=user.id,
        msg_type=MessageType.STICKER,
        media_path=sticker.file_path,
        media_name=f"sticker-{sticker.id}",
        media_type=sticker.media_type,
        media_size=sticker.file_size,
    )
    if chat.auto_delete_seconds:
        message.expires_at = datetime.now(timezone.utc) + timedelta(seconds=chat.auto_delete_seconds)
    db.add(message)
    await db.flush()
    await increment_unread(db, chat_id, user.id, message.id)
    result = await serialise_message(message, db)
    result["sticker"] = {
        "id": sticker.id,
        "set_id": sticker.set_id,
        "url": static_url(sticker.file_path),
        "emoji": sticker.emoji,
        "media_type": sticker.media_type,
        "duration_seconds": sticker.duration_seconds,
        "width": sticker.width,
        "height": sticker.height,
    }
    await push_to_chat(db, chat_id, {"action": "new_message", "payload": result}, exclude_ws=sender_ws)
    return result
