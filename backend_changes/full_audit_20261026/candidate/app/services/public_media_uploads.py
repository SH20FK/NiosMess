"""Bounded binary upload adoption for permanent, publicly readable media."""
import asyncio
import base64
import json
import math
import os
from pathlib import Path
import re
import tempfile
import uuid

from sqlalchemy import select

from app.config import settings
from app.models.models import MediaUploadChunk

_probe_slots = asyncio.Semaphore(2)
_save_slots = asyncio.Semaphore(2)


def _read_bounded(path, limit):
    with path.open('rb') as source:
        data = source.read(limit + 1)
    if not data or len(data) > limit:
        raise ValueError('Media file is empty or too large')
    return data


async def _probe(path, extension):
    async with _probe_slots:
        demuxer = {'png': 'png_pipe', 'jpg': 'jpeg_pipe', 'gif': 'gif',
                   'webp': 'webp_pipe', 'mp4': 'mov', 'mov': 'mov',
                   'webm': 'matroska'}[extension]
        process = await asyncio.create_subprocess_exec(
            'ffprobe', '-v', 'error', '-protocol_whitelist', 'file,pipe',
            '-f', demuxer,
            '-select_streams', 'v:0', '-show_entries',
            'format=format_name,duration:stream=codec_type,codec_name,width,height,duration',
            '-of', 'json', '-i', str(path),
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL,
        )
        try:
            try:
                raw = await process.stdout.readexactly(65537)
            except asyncio.IncompleteReadError as end:
                raw = end.partial
            if len(raw) > 65536:
                raise ValueError('Invalid media metadata')
            await process.wait()
            if process.returncode:
                raise ValueError('Unable to read media file')
            result = json.loads(raw)
            stream = result.get('streams', [])[0]
            width, height = int(stream['width']), int(stream['height'])
            if not 1 <= width <= 8192 or not 1 <= height <= 8192:
                raise ValueError('Invalid media dimensions')
            duration = stream.get('duration') or result.get('format', {}).get('duration')
            return width, height, float(duration) if duration not in (None, 'N/A') else None
        except (KeyError, IndexError, TypeError, json.JSONDecodeError) as error:
            raise ValueError('Invalid media metadata') from error
        finally:
            if process.returncode is None:
                process.kill()
                await process.wait()


def _image_extension(data):
    if data.startswith(b'\x89PNG\r\n\x1a\n'):
        return 'png'
    if data.startswith(b'\xff\xd8\xff'):
        return 'jpg'
    if data.startswith((b'GIF87a', b'GIF89a')):
        return 'gif'
    if data.startswith(b'RIFF') and data[8:12] == b'WEBP':
        return 'webp'
    return None


async def save_public_media(payload, db, user, **limits):
    try:
        await asyncio.wait_for(_save_slots.acquire(), timeout=15)
    except TimeoutError as error:
        raise ValueError('Media processing is busy; try again') from error
    try:
        return await _save_public_media(payload, db, user, **limits)
    finally:
        _save_slots.release()


async def _save_public_media(payload, db, user, *, directory, limit, max_seconds,
                            square=False, max_dimension=8192, image_limit=None, consume=True,
                            require_video=False, max_aspect_ratio=None):
    """Validate the owner, bytes and real video metadata before permanent storage.

    Legacy inline uploads remain supported. A caller cannot adopt an arbitrary
    server path, someone else's session or an incomplete upload.
    """
    root = Path(settings.UPLOAD_DIR).resolve()
    upload = None
    upload_id = payload.get('upload_id')
    if upload_id is not None:
        if not isinstance(upload_id, str) or not re.fullmatch(r'[a-f0-9]{32}', upload_id):
            raise ValueError('Invalid upload_id')
        upload = await db.scalar(select(MediaUploadChunk).where(
            MediaUploadChunk.upload_id == upload_id, MediaUploadChunk.user_id == user.id))
        if not upload or upload.received_chunks < upload.total_chunks:
            raise ValueError('Upload not found, incomplete or access denied')
        source = Path(upload.temp_path).resolve()
        if not source.is_relative_to(root / 'media') or not source.is_file():
            raise ValueError('Invalid upload path')
        data = await asyncio.to_thread(_read_bounded, source, limit)
        filename = upload.filename
    else:
        encoded = payload.get('data_base64')
        if not isinstance(encoded, str) or len(encoded) > 4 * math.ceil(limit / 3):
            raise ValueError('Media file is empty or too large')
        try:
            data = await asyncio.to_thread(base64.b64decode, encoded, validate=True)
        except (ValueError, TypeError) as error:
            raise ValueError('Invalid base64') from error
        if not data or len(data) > limit:
            raise ValueError('Media file is empty or too large')
        filename = str(payload.get('filename') or 'image.png')
    extension = _image_extension(data)
    is_video = extension is None
    if is_video:
        if len(data) >= 12 and data[4:8] in {b'ftyp', b'moov', b'mdat', b'wide'}:
            extension = 'mov' if data[8:12] == b'qt  ' else 'mp4'
        elif data.startswith(b'\x1a\x45\xdf\xa3'):
            extension = 'webm'
        else:
            raise ValueError('Unsupported media format')
    elif image_limit is not None and len(data) > image_limit:
        raise ValueError('Image file is too large')
    if require_video and not is_video:
        raise ValueError('Expected a video emoji')
    # Probe only a newly generated local path, never a user-controlled URL.
    temp_dir = root / 'temp'
    temp_dir.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='probe_', suffix='.' + extension, dir=temp_dir)
    os.close(fd)
    temporary = Path(name)
    try:
        await asyncio.to_thread(temporary.write_bytes, data)
        try:
            width, height, duration = await asyncio.wait_for(_probe(temporary, extension), timeout=15)
        except (TimeoutError, FileNotFoundError) as error:
            raise ValueError('Media validation is temporarily unavailable; try again') from error
        if width > max_dimension or height > max_dimension:
            raise ValueError('Media dimensions are too large')
        if max_aspect_ratio is not None and max(width, height) / min(width, height) > max_aspect_ratio:
            raise ValueError('Media aspect ratio exceeds supported limits')
        if is_video:
            if duration is None or not math.isfinite(duration) or not 0 < duration <= max_seconds:
                raise ValueError(f'Video duration must be at most {max_seconds} seconds')
            if square and width != height:
                raise ValueError('Video avatar must be square (1:1)')
        relative = f'{directory}/{uuid.uuid4().hex}.{extension}'
        target = root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if upload and consume:
            # Adopt the completed upload instead of leaving a second full copy
            # behind in the chat-media area. Both paths are under UPLOAD_DIR.
            await asyncio.to_thread(source.replace, target)
        else:
            await asyncio.to_thread(target.write_bytes, data)
        if upload and consume:
            await db.delete(upload)
        mime = {'png': 'image/png', 'jpg': 'image/jpeg', 'gif': 'image/gif',
                'webp': 'image/webp', 'mp4': 'video/mp4', 'webm': 'video/webm',
                'mov': 'video/quicktime'}[extension]
        return {'path': relative, 'width': width, 'height': height,
                'duration': duration if is_video else None, 'is_video': is_video,
                'mime': mime, 'size': len(data)}
    finally:
        temporary.unlink(missing_ok=True)
