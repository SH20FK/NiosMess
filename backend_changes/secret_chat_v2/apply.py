"""Apply additive secret-chat changes to a COPY of the active server release.

Usage: python apply.py /path/to/staged-release
No credentials, database access, service operations or deployment in this file.
"""
import shutil
import sys
from pathlib import Path


def patch(root, name, old, new, count=1):
    path = root / name
    source = path.read_text(encoding='utf-8')
    if new in source:
        return
    if source.count(old) != count:
        raise RuntimeError(f'Unexpected baseline: {name}, matches={source.count(old)}')
    path.write_text(source.replace(old, new, count), encoding='utf-8', newline='\n')


def apply(root):
    patch(root, 'app/models/models.py',
          '    __tablename__ = "users_fcm_tokens"',
          '    __tablename__ = "users_fcm_tokens"\n    session_id = Column(Integer, nullable=True)')
    patch(root, 'app/models/models.py',
          '    e2ee_content = Column(Text, nullable=True)',
          '    client_message_id = Column(String(36), nullable=True)\n    e2ee_content = Column(Text, nullable=True)')
    patch(root, 'app/services/utils.py',
          '        "id": msg.id,',
          '        "id": msg.id,\n        "client_message_id": msg.client_message_id,')
    patch(root, 'app/migrations.py',
          'from app.models.models import Base',
          'from app.models.models import Base\nfrom app.services import secret_chat_v2  # register additive tables')
    patch(root, 'app/migrations.py',
          '        # Add reply_markup to messages if missing',
          '''        if not await column_exists("users_fcm_tokens", "session_id"):
            await db.execute(text("ALTER TABLE users_fcm_tokens ADD COLUMN session_id INTEGER"))
        if not await column_exists("messages", "client_message_id"):
            await db.execute(text("ALTER TABLE messages ADD COLUMN client_message_id VARCHAR(36)"))
        await db.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS ix_secret_message_client_id ON messages (chat_id, sender_id, client_message_id)"))

        # Add reply_markup to messages if missing''')
    patch(root, 'app/ws/handlers/profile_handler.py',
          '    session.public_key = public_key\n    await db.flush()',
          '''    session.public_key = public_key
    await db.flush()
    from app.services.secret_chat_v2 import register_capability
    await register_capability(db, user, session, payload.get('secret_protocol_version', 0))''')
    patch(root, 'app/ws/router.py',
          'from app.database import AsyncSessionLocal',
          '''from app.database import AsyncSessionLocal
from app.services.secret_chat_v2 import (
    handle_secret_control, handle_secret_sync, handle_secret_mutation,
    guard_secret_access, after_commit, record_secret_metadata, bind_fcm_session, guard_legacy_secret_send,
)''')
    patch(root, 'app/ws/router.py',
          '                    elif action == "send_message":\n                        if not user: raise ValueError("Unauthorized")\n                        result = await handle_send_message(payload, db, user, websocket)',
          '''                    elif action == "secret_control":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_secret_control(payload, db, user, current_session)
                    elif action == "secret_sync":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_secret_sync(payload, db, user, current_session)
                    elif action == "send_message":
                        if not user: raise ValueError("Unauthorized")
                        await guard_secret_access(payload, db, user, current_session)
                        if payload.get('client_message_id'):
                            result = await handle_secret_mutation(action, payload, db, user, current_session)
                        else:
                            await guard_legacy_secret_send(payload, db)
                            result = await handle_send_message(payload, db, user, websocket)''')
    for action in ('edit_message', 'delete_message'):
        patch(root, 'app/ws/router.py',
              f'                        result = await handle_{action}(payload, db, user)',
              f'''                        await guard_secret_access(payload, db, user, current_session)
                        if payload.get('client_operation_id'):
                            result = await handle_secret_mutation(action, payload, db, user, current_session)
                        else:
                            result = await handle_{action}(payload, db, user)''')
    for action in ('history', 'mark_read', 'react', 'pin_message', 'unpin_message', 'im_writing'):
        marker = f'                        result = await handle_{action}('
        path = root / 'app/ws/router.py'
        source = path.read_text(encoding='utf-8')
        target = next(line for line in source.splitlines() if line.startswith(marker))
        patch(root, 'app/ws/router.py', target,
              '                        await guard_secret_access(payload, db, user, current_session)\n' + target)
    for action in ('mark_read', 'react'):
        source = (root / 'app/ws/router.py').read_text(encoding='utf-8')
        target = next(line for line in source.splitlines() if line.startswith(
            f'                        result = await handle_{action}('))
        patch(root, 'app/ws/router.py', target,
              target + f"\n                        await record_secret_metadata('{action}', payload, result, db, user)")
    patch(root, 'app/ws/router.py',
          '                        result = await handle_register_fcm_token(payload, db, user)',
          '''                        result = await handle_register_fcm_token(payload, db, user)
                        if not result.get('error'):
                            await bind_fcm_session(payload, db, user, current_session)''')
    patch(root, 'app/ws/router.py',
          '                        result = await handle_set_public_key(payload, db, user, current_session)',
          '''                        result = await handle_set_public_key(payload, db, user, current_session)
                        if not result.get('error'):
                            remember_ws_session(websocket, current_session.public_key)''')
    patch(root, 'app/ws/router.py',
          '                    err = result.get("error") if isinstance(result, dict) else None\n                    await _send(',
          '''                    err = result.get("error") if isinstance(result, dict) else None
                    if err:
                        await db.rollback()
                        db.info.clear()
                    else:
                        await db.commit()
                        await after_commit(db)
                    await _send(''')
    patch(root, 'app/ws/router.py',
          '                    await db.commit()\n                except Exception as e:',
          '                except Exception as e:')
    patch(root, 'app/ws/router.py',
          '{"action": action, "payload": {}, "request_id": req_id, "error": str(e)},',
          '''{"action": action, "payload": {}, "request_id": req_id,
                         "error": (str(e) if isinstance(e, ValueError) and str(e).startswith('SECRET_')
                                   else 'SECRET_TRANSIENT_ERROR')
                         if action in ('secret_control', 'secret_sync') or payload.get('client_message_id') or payload.get('client_operation_id')
                         else str(e)},''')
    patch(root, 'app/ws/connection_manager.py',
          '    if public_key:\n        ws_session_keys[_ws_id(ws)] = public_key',
          '''    if public_key:
        ws_session_keys[_ws_id(ws)] = public_key
    else:
        ws_session_keys.pop(_ws_id(ws), None)''')
    patch(root, 'app/ws/connection_manager.py',
          '                if ws_key not in secret_keys:',
          '''                expected_key = chat_row.user1_public_key if uid == chat_row.user1_id else chat_row.user2_public_key
                if not expected_key or ws_key != expected_key:''')
    # Legacy actions may not expose plaintext stickers/media in a secret chat.
    patch(root, 'app/ws/handlers/media_handler.py',
          '    chat = await db.scalar(select(Chat).where(Chat.id == chat_id))\n    if not chat:\n        return {"error": "Chat not found"}',
          '''    chat = await db.scalar(select(Chat).where(Chat.id == chat_id))
    if not chat:
        return {"error": "Chat not found"}
    if chat.is_secret:
        return {"error": "SECRET_CIPHERTEXT_REQUIRED"}''')
    shutil.copyfile(Path(__file__).with_name('secret_chat_v2.py'), root / 'app/services/secret_chat_v2.py')


if __name__ == '__main__':
    apply(Path(sys.argv[1]).resolve())
