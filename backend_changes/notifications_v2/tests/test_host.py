"""Run against a staged host with a disposable SQLite database only."""
import os
import tempfile
import unittest
from pathlib import Path


@unittest.skipUnless(os.environ.get('NIOS_NOTIFICATION_HOST_TEST') == '1', 'requires staged host')
class HostNotificationTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
        from app.models.models import Base, User
        self.directory = tempfile.TemporaryDirectory(prefix='nios-notification-test-')
        self.engine = create_async_engine('sqlite+aiosqlite:///' + str(Path(self.directory.name)/'isolated.db'))
        self.sessions = async_sessionmaker(self.engine, expire_on_commit=False)
        async with self.engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        async with self.sessions() as db:
            db.add_all([User(id=i, email=f'{i}@fixture.invalid', username=f'fixture{i}',
                display_name=f'Fixture {i}', hashed_password='fixture', is_active=True) for i in [1, 2]])
            await db.commit()

    async def asyncTearDown(self):
        await self.engine.dispose()
        self.directory.cleanup()

    async def test_real_registration_rebind_and_rollback(self):
        from sqlalchemy import select
        from app.models.models import User, UserFCMToken
        from app.ws.handlers.profile_handler import handle_register_fcm_token, handle_unregister_fcm_token
        async with self.sessions() as db:
            one, two = await db.get(User, 1), await db.get(User, 2)
            await handle_register_fcm_token({'fcm_token': 'fixture-device', 'notification_protocol': 2,
                'notification_preferences': {'messages': False}}, db, one)
            await db.commit()
            token = await db.scalar(select(UserFCMToken))
            self.assertEqual(token.user_id, 1)
            self.assertIn('"messages":false', token.notification_preferences)
            await handle_register_fcm_token({'fcm_token': 'fixture-device'}, db, two)
            await db.commit()
            self.assertEqual(token.user_id, 2)
            await handle_unregister_fcm_token({'fcm_token': 'fixture-device'}, db, one)
            await db.commit()
            self.assertIsNotNone(await db.scalar(select(UserFCMToken)))
            await handle_unregister_fcm_token({'fcm_token': 'fixture-device'}, db, two)
            await db.rollback()
            self.assertIsNotNone(await db.scalar(select(UserFCMToken)))

    async def test_real_dispatch_separates_accounts_and_honors_device_preferences(self):
        from unittest.mock import patch
        from app.models.models import UserFCMToken
        from app.ws import connection_manager as manager
        from app.services.notification_delivery import preferences
        async with self.sessions() as db:
            for token, user, options in [('visible-other-client', 1, {}), ('muted-device', 1, {'muted_chat_ids':[42]}),
                                         ('other-account', 2, {'preview': False})]:
                db.add(UserFCMToken(user_id=user, fcm_token=token,
                    notification_preferences=preferences({'notification_protocol':2, 'notification_preferences':options})))
            await db.commit()
        calls = []
        def fake_send(tokens, title, body, data):
            calls.append((tokens, body, data)); return []
        with patch('app.database.AsyncSessionLocal', self.sessions), patch.object(manager, 'send_push', fake_send):
            # Account-level online state must not suppress another device's push.
            with patch.object(manager, 'is_user_online', return_value=True):
                await manager.send_push_and_prune(['visible-other-client', 'muted-device', 'other-account'],
                    'Fixture', 'private text', {'chat_id':'42', 'message_id':'9', 'type':'new_message'})
        self.assertEqual(len(calls), 2)
        self.assertEqual({c[2]['account_id'] for c in calls}, {'1', '2'})
        self.assertNotIn('muted-device', [t for c in calls for t in c[0]])
        self.assertEqual(next(c[1] for c in calls if c[2]['account_id']=='2'), 'New message')

    async def test_native_payload_keeps_normal_messages_automatic_and_uses_data_only_for_v2_calls(self):
        from unittest.mock import patch
        from types import SimpleNamespace
        from app.ws import connection_manager as manager
        captured = []
        def capture(message):
            captured.append(message)
            return SimpleNamespace(responses=[SimpleNamespace(success=True)])
        with patch.object(manager, 'firebase_app', object()), patch.object(manager.messaging, 'send_each_for_multicast', capture):
            manager.send_push(['fixture'], 'Title', 'Body', {'type':'new_message', 'chat_id':'42'})
            manager.send_push(['fixture'], 'Title', 'Body', {'type':'incoming_call', 'notification_protocol':'2'})
            manager.send_push(['fixture'], 'Title', 'Body', {'type':'incoming_call', 'notification_protocol':'1'})
            manager.send_push(['fixture'], 'Title', '', {'type':'call_ended'})
            manager.send_push(['fixture'], 'Title', 'Body', {'type':'new_message', 'notification_sound':'false'})
        self.assertEqual(captured[0].android.notification.channel_id, 'niosmess_messages')
        self.assertIsNone(captured[1].android.notification)
        self.assertEqual(captured[2].android.notification.channel_id, 'niosmess_calls')
        self.assertIsNone(captured[3].android.notification)
        self.assertEqual(captured[4].android.notification.channel_id, 'niosmess_messages_silent')

    async def test_read_receipt_reaches_own_devices_and_is_queued_after_commit(self):
        from unittest.mock import patch, AsyncMock
        from app.models.models import Chat, ChatMember, ChatType, User, UserFCMToken
        from app.ws.handlers import chat_handler
        async with self.sessions() as db:
            db.add(Chat(id=42, chat_type=ChatType.DIRECT, user1_id=1, user2_id=2, name='Fixture'))
            db.add_all([ChatMember(chat_id=42,user_id=i) for i in [1,2]])
            db.add(UserFCMToken(user_id=1, fcm_token='fixture-device'))
            await db.commit()
            with patch.object(chat_handler, 'push_to_chat', AsyncMock()) as push:
                result = await chat_handler.handle_mark_read({'chat_id':42}, db, await db.get(User,1))
            self.assertEqual(result['unread_count'],0)
            self.assertNotIn('exclude_user_id', push.call_args.kwargs)
            self.assertEqual(db.info['notification_pushes'][0][3]['type'],'chat_read')
            await db.rollback()

    async def test_expired_call_cannot_issue_a_new_media_token(self):
        from unittest.mock import patch, AsyncMock
        from app.models.models import User
        from app.ws.handlers import call_handler
        async with self.sessions() as db:
            with patch.object(call_handler, '_require_member', AsyncMock()), patch.object(call_handler, 'active_calls', {}):
                result = await call_handler.handle_join_call({'chat_id':42,'room_id':'ended-room','message_id':9}, db, await db.get(User,1))
            self.assertEqual(result['error'],'Call is no longer available')

    async def test_first_registration_can_immediately_bind_secret_device_session(self):
        from sqlalchemy import select
        from datetime import datetime, timedelta, timezone
        from app.models.models import User, UserFCMToken, Session
        from app.ws.handlers.profile_handler import handle_register_fcm_token
        from app.services.secret_chat_v2 import bind_fcm_session
        async with self.sessions() as db:
            user = await db.get(User,1)
            session = Session(user_id=1,token_hash='fixture-session',public_key='fixture-device-key',
                expires_at=datetime.now(timezone.utc)+timedelta(days=1))
            db.add(session); await db.flush()
            payload={'fcm_token':'fixture-new-device'}
            await handle_register_fcm_token(payload,db,user)
            await bind_fcm_session(payload,db,user,session)
            token=await db.scalar(select(UserFCMToken))
            self.assertEqual(token.session_id,session.id)

    async def test_niosgram_comment_is_queued_once_and_not_sent_to_the_author_themself(self):
        from app.models.models import User, Post
        from app.ws.handlers.post_handler import handle_comment_post
        async with self.sessions() as db:
            db.add(Post(id=9,author_id=1,content='fixture',comments_count=0))
            await db.commit()
            await handle_comment_post({'post_id':9,'content':'fixture reply'},db,await db.get(User,2))
            events=db.info['notification_activity']
            self.assertEqual(len(events),1)
            self.assertEqual(events[0][1]['type'],'post_comment')
            self.assertEqual(events[0][1]['route'],'/niosgram/post/9/comments')
            await handle_comment_post({'post_id':9,'content':'own reply'},db,await db.get(User,1))
            self.assertEqual(len(events),1)
