import os
import uuid
import aiofiles
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, Form
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.dependencies import get_current_user, get_current_user_allow_frozen
from app.models.models import (
    Chat, ChatMember, ChatType, MediaUploadChunk, MemberRole,
    Message, MessageReaction, MessageType, User, UnreadCounter,
)
from app.schemas.schemas import EditMessageRequest, SendMessageRequest
from app.services.encryption import encrypt_text
from app.services.utils import serialise_message, increment_unread, _guess_mime

router = APIRouter(prefix="/messages", tags=["Messages"])


async def _can_send(db, chat_id, user_id):
    """Returns member or raises 403."""
    r = await db.execute(
        select(ChatMember).where(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == user_id,
            ChatMember.is_banned == False,
            ChatMember.is_muted == False,
        )
    )
    m = r.scalar_one_or_none()
    if not m:
        raise HTTPException(403, "Cannot post here (not member, banned, or muted)")

    cr = await db.execute(select(Chat).where(Chat.id == chat_id))
    chat = cr.scalar_one_or_none()
    if chat and chat.is_banned:
        raise HTTPException(403, "Chat is banned by admins")
    if chat and chat.chat_type == ChatType.CHANNEL and m.role == MemberRole.MEMBER:
        raise HTTPException(403, "Only admins can post in channels")
    return m


async def _require_member(db, chat_id, user_id):
    r = await db.execute(
        select(ChatMember).where(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == user_id,
            ChatMember.is_banned == False,
        )
    )
    if not r.scalar_one_or_none():
        raise HTTPException(403, "Not a member")


# ── Send ──────────────────────────────────────────────────────────────────────

@router.post("/{chat_id}/send")
async def send_message(
    chat_id: int,
    body: SendMessageRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Send a text message (content is encrypted AES-256-GCM before storage).
    Optionally attach a completed chunked upload via upload_id.
    """
    await _can_send(db, chat_id, current_user.id)
    if not body.content and not body.upload_id:
        raise HTTPException(400, "Message must have content or media")

    msg = Message(
        chat_id=chat_id,
        sender_id=current_user.id,
        reply_to_id=body.reply_to_id,
        msg_type=MessageType.TEXT,
    )

    # Encrypt text content with AES-256-GCM
    if body.content:
        enc = encrypt_text(body.content)
        msg.encrypted_content = enc["ciphertext"]
        msg.content_iv        = enc["iv"]
        msg.content_tag       = enc["tag"]

    # Attach completed upload
    if body.upload_id:
        r = await db.execute(
            select(MediaUploadChunk).where(
                MediaUploadChunk.upload_id == body.upload_id,
                MediaUploadChunk.user_id == current_user.id,
            )
        )
        up = r.scalar_one_or_none()
        if not up:
            raise HTTPException(404, "Upload session not found")
        if up.received_chunks < up.total_chunks:
            raise HTTPException(400, f"Upload incomplete ({up.received_chunks}/{up.total_chunks} chunks)")
        rel_path = up.temp_path.replace(settings.UPLOAD_DIR + "/", "")
        msg.media_path = rel_path
        msg.media_name = up.filename
        msg.media_type = _guess_mime(up.filename)
        try:
            msg.media_size = os.path.getsize(up.temp_path)
        except Exception:
            pass
        # Map subtype to MessageType
        subtype_map = {
            "voice":  MessageType.VOICE,
            "circle": MessageType.CIRCLE,
        }
        msg.msg_type = subtype_map.get(up.media_subtype, MessageType.MEDIA)
        await db.delete(up)

    db.add(msg)
    await db.flush()

    # Bump unread counters for other members
    await increment_unread(db, chat_id, current_user.id, msg.id)

    return await serialise_message(msg, db)


# ── History ───────────────────────────────────────────────────────────────────

@router.get("/{chat_id}/history")
async def history(
    chat_id: int,
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    before_id: int = Query(None, description="Cursor: load messages older than this id"),
    current_user: User = Depends(get_current_user_allow_frozen),
    db: AsyncSession = Depends(get_db),
):
    await _require_member(db, chat_id, current_user.id)

    q = select(Message).where(Message.chat_id == chat_id)
    if before_id:
        q = q.where(Message.id < before_id)

    total_r = await db.execute(
        select(func.count()).select_from(Message).where(Message.chat_id == chat_id)
    )
    total = total_r.scalar()

    q = q.order_by(Message.sent_at.desc()).limit(page_size).offset((page - 1) * page_size)
    r = await db.execute(q)
    msgs = list(reversed(r.scalars().all()))

    result = []
    for msg in msgs:
        result.append(await serialise_message(msg, db))

    return {"messages": result, "total": total, "page": page, "page_size": page_size}


# ── Edit / Delete ─────────────────────────────────────────────────────────────

@router.patch("/{chat_id}/{message_id}")
async def edit_message(
    chat_id: int, message_id: int,
    body: EditMessageRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    r = await db.execute(
        select(Message).where(
            Message.id == message_id,
            Message.chat_id == chat_id,
            Message.sender_id == current_user.id,
        )
    )
    msg = r.scalar_one_or_none()
    if not msg:
        raise HTTPException(404, "Message not found or not yours")
    if msg.is_deleted:
        raise HTTPException(400, "Cannot edit deleted message")
    enc = encrypt_text(body.content)
    msg.encrypted_content = enc["ciphertext"]
    msg.content_iv        = enc["iv"]
    msg.content_tag       = enc["tag"]
    msg.edited_at = datetime.now(timezone.utc)
    return await serialise_message(msg, db)


@router.delete("/{chat_id}/{message_id}")
async def delete_message(
    chat_id: int, message_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    r = await db.execute(
        select(Message).where(Message.id == message_id, Message.chat_id == chat_id)
    )
    msg = r.scalar_one_or_none()
    if not msg:
        raise HTTPException(404, "Message not found")
    if msg.sender_id != current_user.id:
        # Admins/owners may delete any message
        mr = await db.execute(
            select(ChatMember).where(ChatMember.chat_id == chat_id,
                                     ChatMember.user_id == current_user.id)
        )
        m = mr.scalar_one_or_none()
        if not m or m.role == MemberRole.MEMBER:
            raise HTTPException(403, "Not allowed to delete this message")
    msg.is_deleted = True
    msg.encrypted_content = None
    msg.content_iv  = None
    msg.content_tag = None
    return {"message": "Deleted"}


# ── Reactions ─────────────────────────────────────────────────────────────────

@router.post("/{chat_id}/{message_id}/react")
async def react(
    chat_id: int, message_id: int,
    emoji: str = Query(..., max_length=8),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _require_member(db, chat_id, current_user.id)
    # Toggle: if exists → delete; else → add
    r = await db.execute(
        select(MessageReaction).where(
            MessageReaction.message_id == message_id,
            MessageReaction.user_id == current_user.id,
            MessageReaction.emoji == emoji,
        )
    )
    existing = r.scalar_one_or_none()
    if existing:
        await db.delete(existing)
        return {"action": "removed", "emoji": emoji}
    db.add(MessageReaction(message_id=message_id,
                           user_id=current_user.id, emoji=emoji))
    return {"action": "added", "emoji": emoji}


# ── Channel comments ──────────────────────────────────────────────────────────

@router.post("/{channel_id}/posts/{post_id}/comment")
async def post_comment(
    channel_id: int, post_id: int,
    body: SendMessageRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Post a comment under a channel post (uses the linked comments chat)."""
    # Fetch the channel
    cr = await db.execute(select(Chat).where(Chat.id == channel_id))
    channel = cr.scalar_one_or_none()
    if not channel or channel.chat_type != ChatType.CHANNEL:
        raise HTTPException(404, "Channel not found")
    if not channel.comments_chat_id:
        raise HTTPException(400, "Comments are not enabled for this channel")
    # Verify the post belongs to the channel
    pr = await db.execute(
        select(Message).where(Message.id == post_id, Message.chat_id == channel_id)
    )
    post = pr.scalar_one_or_none()
    if not post:
        raise HTTPException(404, "Post not found")
    # Auto-join the comments chat
    comments_chat_id = channel.comments_chat_id
    ex = await db.execute(
        select(ChatMember).where(ChatMember.chat_id == comments_chat_id,
                                 ChatMember.user_id == current_user.id)
    )
    if not ex.scalar_one_or_none():
        db.add(ChatMember(chat_id=comments_chat_id, user_id=current_user.id))
        await db.flush()
    # Send as a reply to the original post in comments chat
    if not body.content and not body.upload_id:
        raise HTTPException(400, "Comment must have content")
    msg = Message(
        chat_id=comments_chat_id,
        sender_id=current_user.id,
        reply_to_id=post_id,
        msg_type=MessageType.TEXT,
    )
    if body.content:
        enc = encrypt_text(body.content)
        msg.encrypted_content = enc["ciphertext"]
        msg.content_iv        = enc["iv"]
        msg.content_tag       = enc["tag"]
    db.add(msg)
    await db.flush()
    # Increment comments_count on original post
    post.comments_count = (post.comments_count or 0) + 1
    await increment_unread(db, comments_chat_id, current_user.id, msg.id)
    return await serialise_message(msg, db)


@router.get("/{channel_id}/posts/{post_id}/comments")
async def get_comments(
    channel_id: int, post_id: int,
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    current_user: User = Depends(get_current_user_allow_frozen),
    db: AsyncSession = Depends(get_db),
):
    cr = await db.execute(select(Chat).where(Chat.id == channel_id))
    channel = cr.scalar_one_or_none()
    if not channel or not channel.comments_chat_id:
        raise HTTPException(404, "Channel or comments not found")
    comments_chat_id = channel.comments_chat_id
    q = select(Message).where(
        Message.chat_id == comments_chat_id,
        Message.reply_to_id == post_id,
        Message.is_deleted == False,
    ).order_by(Message.sent_at.asc()).limit(page_size).offset((page - 1) * page_size)
    r = await db.execute(q)
    result = [await serialise_message(m, db) for m in r.scalars().all()]
    return {"comments": result, "page": page, "page_size": page_size}


# ── Chunked upload ────────────────────────────────────────────────────────────

@router.post("/upload/init")
async def init_upload(
    filename: str = Form(...),
    total_chunks: int = Form(...),
    file_size: int = Form(...),
    media_subtype: str = Form("media"),  # media | voice | circle
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if media_subtype not in ("media", "voice", "circle"):
        raise HTTPException(400, "media_subtype must be media, voice, or circle")
    upload_id = uuid.uuid4().hex
    ext = filename.rsplit(".", 1)[-1] if "." in filename else "bin"
    subdir = media_subtype if media_subtype in ("voice", "circles") else "media"
    temp_name = f"{subdir}/{current_user.id}_{upload_id}.{ext}"
    temp_path = os.path.join(settings.UPLOAD_DIR, temp_name)
    os.makedirs(os.path.dirname(temp_path), exist_ok=True)
    async with aiofiles.open(temp_path, "wb") as f:
        pass  # create empty file
    db.add(MediaUploadChunk(
        upload_id=upload_id, user_id=current_user.id,
        filename=filename, media_subtype=media_subtype,
        total_chunks=total_chunks, received_chunks=0,
        temp_path=temp_path,
    ))
    await db.flush()
    return {"upload_id": upload_id, "chunk_size": settings.CHUNK_SIZE}


@router.post("/upload/chunk")
async def upload_chunk(
    upload_id: str = Form(...),
    chunk_index: int = Form(...),
    chunk: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    r = await db.execute(
        select(MediaUploadChunk).where(
            MediaUploadChunk.upload_id == upload_id,
            MediaUploadChunk.user_id == current_user.id,
        )
    )
    up = r.scalar_one_or_none()
    if not up:
        raise HTTPException(404, "Upload session not found")
    data = await chunk.read()
    # Write at the exact byte offset for this chunk (128 KB chunks)
    async with aiofiles.open(up.temp_path, "r+b") as f:
        await f.seek(chunk_index * settings.CHUNK_SIZE)
        await f.write(data)
    up.received_chunks += 1
    complete = up.received_chunks >= up.total_chunks
    return {
        "upload_id": upload_id,
        "chunk_index": chunk_index,
        "received": up.received_chunks,
        "total": up.total_chunks,
        "complete": complete,
    }
