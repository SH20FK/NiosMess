"""Patch active modular handlers; abort if the expected source has drifted."""
from pathlib import Path
import shutil

FILES = ('app/models/models.py', 'app/ws/connection_manager.py',
         'app/ws/handlers/profile_handler.py', 'app/ws/handlers/chat_handler.py',
         'app/ws/handlers/call_handler.py', 'app/ws/handlers/post_handler.py',
         'app/ws/router.py', 'app/services/secret_chat_v2.py')


def replace(source, old, new, count=1):
    if source.count(old) != count:
        raise RuntimeError('notification_patch_precondition:' + old[:70])
    return source.replace(old, new)


def apply(root):
    root = Path(root)
    existing = root/'app/services/notification_delivery.py'
    if existing.exists():
        # A narrowly guarded follow-up on the v2 release. Preserve other live
        # handlers; do not run the original structural patch a second time.
        if existing.read_bytes() != Path(__file__).with_name('notification_delivery.py').read_bytes():
            raise RuntimeError('notification_module_source_drift')
        manager = root/'app/ws/connection_manager.py'
        source = replace(manager.read_text(),
            'channel_id="niosmess_calls" if is_call else "niosmess_messages",',
            'channel_id="niosmess_calls" if is_call else ("niosmess_messages" if sound else "niosmess_messages_silent"),')
        compile(source, str(manager), 'exec')
        manager.write_text(source)
        return ['app/ws/connection_manager.py']
    sources = {f: (root/f).read_text() for f in FILES}
    model = 'app/models/models.py'
    sources[model] = replace(sources[model], 'class UserFCMToken(Base):',
        'class UserFCMToken(Base):\n    notification_preferences = Column(Text, nullable=True)')
    profile = 'app/ws/handlers/profile_handler.py'
    sources[profile] = 'from app.services.notification_delivery import preferences\n' + sources[profile]
    sources[profile] = replace(sources[profile], '        t.platform = platform',
        '        t.platform = platform\n        t.notification_preferences = preferences(payload)')
    sources[profile] = replace(sources[profile],
        'db.add(UserFCMToken(user_id=user.id, fcm_token=fcm_token, platform=platform, updated_at=now))',
        'db.add(UserFCMToken(user_id=user.id, fcm_token=fcm_token, platform=platform, updated_at=now, notification_preferences=preferences(payload)))')
    sources[profile] = replace(sources[profile], '        t.user_id = user.id',
        '        if t.user_id != user.id:\n            t.session_id = None\n        t.user_id = user.id')
    sources[profile] = replace(sources[profile], '    return {"message": "FCM token registered successfully"}',
        '    await db.flush()  # Session binding immediately following registration must see a new token.\n    return {"message": "FCM token registered successfully"}')
    manager = 'app/ws/connection_manager.py'
    sources[manager] = replace(sources[manager], '        message = messaging.MulticastMessage(', '''        is_call = data.get('type') == 'incoming_call'
        cancel = data.get('type') in ('call_ended', 'chat_read')
        call_v2 = is_call and data.get('notification_protocol') == '2'
        sound = data.get('notification_sound') != 'false'
        message = messaging.MulticastMessage(''')
    sources[manager] = replace(sources[manager], '                notification=messaging.AndroidNotification(',
        '                ttl=timedelta(seconds=60 if is_call or cancel else 86400),\n                notification=None if cancel or call_v2 else messaging.AndroidNotification(')
    sources[manager] = replace(sources[manager], '                    sound="default",\n                    channel_id="niosmess_messages",', '''                    sound="default" if sound else None,
                    channel_id="niosmess_calls" if is_call else ("niosmess_messages" if sound else "niosmess_messages_silent"),
                    tag=('call-' + str(data.get('room_id'))) if is_call else ('chat-' + str(data.get('chat_id'))),''')
    sources[manager] = replace(sources[manager],
        'aps=messaging.Aps(alert=messaging.ApsAlert(title=title, body=body), sound="default", badge=1)',
        'aps=messaging.Aps(alert=None if cancel else messaging.ApsAlert(title=title, body=body), sound="default" if sound and not cancel else None, content_available=cancel)')
    sources[manager] = replace(sources[manager], 'headers={"Urgency": "high"},',
        'headers={"Urgency": "high", "TTL": "60" if is_call or cancel else "86400"},')
    sources[manager] = replace(sources[manager],
        'logger.warning("FCM push failed for token %s...: %s", token[:12], resp.exception)',
        'logger.warning("FCM delivery failed: %s", code or "UNKNOWN")')
    sources[manager] = replace(sources[manager], 'logger.exception("send_push failed for %d token(s)", len(tokens))',
        'logger.warning("FCM_BATCH_UNAVAILABLE count=%d", len(tokens))')
    start = sources[manager].index('    """Send a push in a thread, then delete')
    end = sources[manager].index('\n\n\ndef log_suspicious_activity', start)
    sources[manager] = sources[manager][:start] + '''    """Recheck device preferences in a new transaction after message commit."""
    from app.database import AsyncSessionLocal
    from app.models.models import UserFCMToken, Session
    from app.services.notification_delivery import prepare_device_push
    from sqlalchemy import delete as sa_delete
    groups = {}
    async with AsyncSessionLocal() as db:
        rows = (await db.scalars(select(UserFCMToken).outerjoin(Session, Session.id == UserFCMToken.session_id).where(
            UserFCMToken.fcm_token.in_(tokens), or_(UserFCMToken.session_id == None,
                (Session.is_active == True) & (Session.user_id == UserFCMToken.user_id) & (Session.expires_at > datetime.now(timezone.utc)))))).all()
        for row in rows:
            prepared = prepare_device_push(row.user_id, row.notification_preferences, title, body, data)
            if prepared is None:
                continue
            t, b, payload = prepared
            key = (t, b, json.dumps(payload, sort_keys=True))
            groups.setdefault(key, []).append(row.fcm_token)
    stale = []
    for (t, b, payload), batch in groups.items():
        for i in range(0, len(batch), 500):
            stale.extend(await asyncio.to_thread(send_push, batch[i:i+500], t, b, json.loads(payload)))
    if stale:
        async with AsyncSessionLocal() as db:
            await db.execute(sa_delete(UserFCMToken).where(UserFCMToken.fcm_token.in_(stale)))
            await db.commit()
''' + sources[manager][end:]
    chat = 'app/ws/handlers/chat_handler.py'
    sources[chat] = 'from app.services.notification_delivery import queue_push\n' + sources[chat]
    sources[chat] = replace(sources[chat], 'and not m.is_muted and not is_user_online(m.user_id)', '')
    sources[chat] = replace(sources[chat], 'asyncio.create_task(send_push_and_prune(chunk, title, body_text, data_payload))',
        'queue_push(db, chunk, title, body_text, data_payload)')
    sources[chat] = replace(sources[chat], '"sender_name": user.display_name,',
        '"sender_name": user.display_name,\n                    "is_secret": "true" if is_secret or e2ee_content else "false",\n                    "created_at": msg.sent_at.replace(tzinfo=msg.sent_at.tzinfo or timezone.utc).isoformat(),')
    read_start = sources[chat].index('async def handle_mark_read')
    read_end = sources[chat].index('\n\nasync def ', read_start+1)
    read_source = sources[chat][read_start:read_end]
    read_source = replace(read_source, '        exclude_user_id=user.id,\n', '')
    read_source = replace(read_source, '    return {"message": "Marked as read", "unread_count": 0}', "    tokens = (await db.scalars(select(UserFCMToken.fcm_token).where(UserFCMToken.user_id == user.id))).all()\n    queue_push(db, tokens, 'NiosMess', '', {'type': 'chat_read', 'chat_id': str(chat_id), 'user_id': str(user.id)})\n    return {\"message\": \"Marked as read\", \"unread_count\": 0}")
    sources[chat] = sources[chat][:read_start] + read_source + sources[chat][read_end:]
    calls = 'app/ws/handlers/call_handler.py'
    sources[calls] = 'from app.services.notification_delivery import queue_push, queue_call_cancellation, flush_notification_pushes\n' + sources[calls]
    sources[calls] = replace(sources[calls], 'asyncio.create_task(send_push_and_prune(chunk, title, body, data_payload))',
        'queue_push(db, chunk, title, body, data_payload)')
    sources[calls] = replace(sources[calls], '"type": "incoming_call",',
        '"type": "incoming_call",\n                    "created_at": datetime.now(timezone.utc).isoformat(),\n                    "expires_at": (datetime.now(timezone.utc) + timedelta(seconds=CALL_RINGING_TIMEOUT_SECONDS)).isoformat(),')
    sources[calls] = replace(sources[calls], '    active_calls.pop(room_id, None)\n\n\nasync def _call_timeout_worker',
        '    await queue_call_cancellation(db, chat_id, room_id)\n    active_calls.pop(room_id, None)\n\n\nasync def _call_timeout_worker')
    sources[calls] = replace(sources[calls], '            await db.commit()\n        except Exception:',
        '            await db.commit()\n            await flush_notification_pushes(db)\n        except Exception:')
    # Reject expired/mismatched calls before issuing a media access token.
    marker = sources[calls].index('async def handle_join_call')
    before, join = sources[calls][:marker], sources[calls][marker:]
    join = join.replace('    await _require_member(db, chat_id, user.id)\n', '''    await _require_member(db, chat_id, user.id)
    info = active_calls.get(room_id)
    if not info or info.get('status') not in ('ringing', 'active') or info.get('chat_id') != chat_id or info.get('message_id') != message_id:
        return {'error': 'Call is no longer available'}
    await queue_call_cancellation(db, chat_id, room_id)
''', 1)
    sources[calls] = before + join
    sources[calls] = replace(sources[calls], '\n    if timeout_task:\n', '\n    if timeout_task and timeout_task is not asyncio.current_task():\n')
    # Check the actual room's membership, not an unrelated caller-supplied chat.
    sources[calls] = replace(sources[calls], '    if chat_id:\n        await _require_member(db, chat_id, user.id)\n    await _finish_call', "    info = active_calls.get(room_id)\n    if not info:\n        return {'status': 'ended'}\n    if chat_id != info['chat_id']:\n        return {'error': 'Call chat mismatch'}\n    await _require_member(db, info['chat_id'], user.id)\n    await _finish_call")
    sources[calls] = sources[calls].replace('from datetime import datetime, timezone', 'from datetime import datetime, timezone, timedelta')
    secret = 'app/services/secret_chat_v2.py'
    sources[secret] = replace(sources[secret], 'if member and not member.is_muted and not is_user_online(peer_id):',
        'if member and not member.is_banned:')
    router = 'app/ws/router.py'
    sources[router] = 'from app.services.notification_delivery import flush_notification_pushes\n' + sources[router]
    sources[router] = replace(sources[router], '                        await after_commit(db)',
        '                        await after_commit(db)\n                        await flush_notification_pushes(db)')
    posts = 'app/ws/handlers/post_handler.py'
    sources[posts] = 'from app.services.notification_delivery import queue_activity\n' + sources[posts]
    sources[posts] = replace(sources[posts], '    current_reaction = await db.scalar(',
        "    if is_like and action != 'removed':\n        await queue_activity(db, post, user, 'post_like', f'post-like:{post.id}:{user.id}')\n    current_reaction = await db.scalar(")
    sources[posts] = replace(sources[posts], '    return _comment_payload(comment, user)',
        "    await queue_activity(db, post, user, 'post_comment', f'post-comment:{comment.id}')\n    return _comment_payload(comment, user)")
    for f, source in sources.items():
        compile(source, f, 'exec')
    for f, source in sources.items():
        (root/f).write_text(source)
    shutil.copyfile(Path(__file__).with_name('notification_delivery.py'), root/'app/services/notification_delivery.py')
    return list(FILES) + ['app/services/notification_delivery.py']
