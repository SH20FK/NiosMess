"""Small reviewed changes to the active handlers; never rewrite legacy files."""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path


def replace_once(source: str, before: str, after: str, label: str) -> str:
    if source.count(before) != 1:
        raise RuntimeError(f"host_patch_precondition:{label}")
    return source.replace(before, after, 1)


def patched_sources(root: Path) -> dict[str, str]:
    paths = ("app/main.py", "app/services/secret_chat_v2.py", "app/services/utils.py",
             "app/ws/handlers/profile_handler.py")
    sources = {path: (root / path).read_text(encoding="utf-8") for path in paths}
    main = sources[paths[0]]
    main = replace_once(main, "@app.get('/health/ready', include_in_schema=False)",
        "# Additive device/mailbox/stream/MLS APIs; legacy handlers stay authoritative.\n"
        "from nios_protocol.production_adapter import install_production\n"
        "install_production(app)\n\n"
        "@app.get('/health/ready', include_in_schema=False)", "main.install")
    main = replace_once(main, 'allow_methods=["GET", "POST", "DELETE", "OPTIONS"],',
        'allow_methods=["GET", "HEAD", "PUT", "POST", "DELETE", "OPTIONS"],', "main.cors_methods")
    main = replace_once(main,
        'allow_headers=["Authorization", "Content-Type", "X-Admin-Key", "X-Nios-Bot-Token"],',
        'allow_headers=["Authorization", "Content-Type", "Range", "X-Admin-Key", "X-Nios-Bot-Token"],\n'
        '    expose_headers=["Content-Range", "Accept-Ranges", "X-Nios-Manifest-Hash", "X-Nios-Ciphertext-Length"],',
        "main.cors_headers")
    sources[paths[0]] = main
    secret = sources[paths[1]]
    secret = replace_once(secret, "    return {'events': events, 'has_more': len(rows) > limit,",
        "    from nios_protocol.production_adapter import peer_stream_versions\n"
        "    stream_versions = await peer_stream_versions(db, peer_id, peer_key)\n"
        "    return {'peer_stream_protocol_versions': stream_versions,\n"
        "            'events': events, 'has_more': len(rows) > limit,", "secret.peer_versions")
    secret = replace_once(secret,
        "            if upload_id:\n                upload = await db.scalar(select(MediaUploadChunk).where(",
        "            if isinstance(upload_id, str) and upload_id.startswith('nios-stream:'):\n"
        "                from nios_protocol.production_adapter import apply_stream_upload\n"
        "                await apply_stream_upload(msg, upload_id, payload.get('media_subtype'),\n"
        "                                          chat, user, session, db)\n"
        "            elif upload_id:\n                upload = await db.scalar(select(MediaUploadChunk).where(",
        "secret.stream_upload")
    sources[paths[1]] = secret
    sources[paths[2]] = replace_once(sources[paths[2]],
        '        media_url = f"https://ni-os.ru/api/media/{msg.media_path}"',
        "        if msg.is_e2ee and msg.media_path.startswith('nios-stream:'):\n"
        "            from nios_protocol.blobs import HASH\n"
        "            digest = msg.media_path.removeprefix('nios-stream:')\n"
        "            media_url = f'https://ni-os.ru/v1/blobs/{digest}' if HASH.fullmatch(digest) else None\n"
        "        else:\n"
        '            media_url = f"https://ni-os.ru/api/media/{msg.media_path}"', "utils.stream_url")
    sources[paths[3]] = replace_once(sources[paths[3]],
        '    return {"message": "Public key set for this device successfully"}',
        "    from nios_protocol.production_adapter import registered_stream_versions\n"
        "    stream_versions = await registered_stream_versions(\n"
        "        user, session, payload.get('stream_protocol_versions'))\n"
        '    return {"message": "Public key set for this device successfully",\n'
        '            "stream_protocol_versions": stream_versions}', "profile.stream_versions")
    for path, source in sources.items():
        compile(source, path, "exec")
    return sources


def apply(root: Path) -> dict[str, str]:
    updates = patched_sources(root)
    for path, source in updates.items():
        (root / path).write_text(source, encoding="utf-8", newline="\n")
    return {path: hashlib.sha256(source.encode()).hexdigest() for path, source in updates.items()}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    for path, digest in apply(args.root).items():
        print(path, digest)
