"""Real copied handler functions + downloaded ORM models on disposable SQLite.

Only transport/notifications, token generation and opaque fixture encryption are
substituted. Access checks, start/end logic and database operations come from
source AST unchanged; no production imports or connection settings are loaded.
"""
import ast
import asyncio
import importlib.util
import json
import logging
import os
import re
import tempfile
from types import SimpleNamespace
import unittest
from datetime import datetime, timezone, timedelta
from pathlib import Path
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

PROPOSAL = Path(__file__).resolve().parents[1]
SNAPSHOT = PROPOSAL / 'fixtures'
BASELINE = os.environ.get('NIOS_CALL_ACCESS_BASELINE') == '1'
SOURCE = SNAPSHOT/'app/ws/handlers/call_handler.py' if BASELINE else PROPOSAL/'candidate/app/ws/handlers/call_handler.py'
spec = importlib.util.spec_from_file_location('call_access_fixture_models', SNAPSHOT/'app/models/models.py')
models = importlib.util.module_from_spec(spec)
spec.loader.exec_module(models)


def install_functions(path, names, namespace):
    tree = ast.parse(path.read_text(encoding='utf-8'))
    body = [node for node in tree.body if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name in names]
    assert len(body) == len(names), (path, names, [node.name for node in body])
    exec(compile(ast.Module(body=body, type_ignores=[]), str(path), 'exec'), namespace)


class Fixture(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='nios-call-access-')
        self.engine = create_async_engine('sqlite+aiosqlite:///' + str(Path(self.directory.name)/'isolated.db'))
        self.sessions = async_sessionmaker(self.engine, expire_on_commit=False)
        async with self.engine.begin() as connection:
            await connection.run_sync(models.Base.metadata.create_all)
        async with self.sessions() as db:
            db.add_all([models.User(id=i, email=f'{i}@fixture.invalid', username=f'fixture{i}', display_name=f'Fixture {i}', hashed_password='fixture', is_active=True, is_bot=False) for i in (1,2,3,4)])
            db.add_all([models.Chat(id=i, chat_type=models.ChatType.GROUP, created_by=owner) for i,owner in ((10,1),(20,3))])
            db.add_all([models.ChatMember(chat_id=chat, user_id=user) for chat,user in ((10,1),(10,2),(20,3),(20,4))])
            db.add(models.Message(id=100, chat_id=10, sender_id=1, msg_type=models.MessageType.CALL_LOG, encrypted_content='fixture', system_event_type='call', system_event_json='{"status":"active"}'))
            db.add(models.Call(id=200, chat_id=10, initiator_id=1, is_video=False, status=models.CallStatus.RINGING))
            db.add(models.CallParticipant(call_id=200,user_id=1))
            await db.commit()
        self.calls = {'a'*32: {'chat_id':10,'message_id':100,'initiator_id':1,'participants':{1,2},'status':'active','is_video':False}}
        self.events = []
        async def push(*args, **kwargs): self.events.append((args[1] if len(args)>1 else None, args[2] if len(args)>2 else None))
        async def noop(*args, **kwargs): return None
        async def award(*args): return False
        async def serialize(message, db): return {'id':message.id, 'chat_id':message.chat_id}
        async def timeout(room): await asyncio.sleep(3600)
        self.ns = dict(vars(models))
        self.ns.update({'AsyncSession':AsyncSession, 'asyncio':asyncio, 'select':select, 'json':json, 're':re, 'datetime':datetime, 'timezone':timezone, 'timedelta':timedelta,
          'active_calls':self.calls, 'push_to_chat':push, 'queue_call_cancellation':noop, 'queue_push':lambda *args,**kwargs:None,
          'serialise_message':serialize, 'encrypt_text':lambda text:{'ciphertext':'fixture-opaque','iv':'fixture','tag':'fixture'},
          '_award_calls_tester':award, '_call_access_token':lambda *args:'fixture-token', '_call_ice_servers':lambda *args:[],
          '_call_timeout_worker':timeout, 'CALL_RINGING_TIMEOUT_SECONDS':60, 'logging':logging,
          'settings':SimpleNamespace(CALLS_SIGNAL_URL='wss://fixture.invalid/signal'), '_pending_start_rooms':set(), '_pending_start_users':set()})
        install_functions(SNAPSHOT/'app/ws/handlers/chat_handler.py', {'_require_member','_can_send'}, self.ns)
        names = {'_finish_call','handle_start_call','handle_end_call_signaling','handle_decline_call','handle_answer_call','handle_get_call','handle_end_call','_log_call_message'}
        if not BASELINE: names.add('_start_call_reserved')
        install_functions(SOURCE,names,self.ns)

    async def asyncTearDown(self):
        tasks = [info.get('timeout_task') for info in self.calls.values() if info.get('timeout_task')]
        for task in tasks: task.cancel()
        await asyncio.gather(*tasks,return_exceptions=True)
        await self.engine.dispose()
        self.directory.cleanup()

    async def invoke(self, action, payload, user_id):
        async with self.sessions() as db:
            user = await db.get(models.User,user_id)
            result = await self.ns[action](payload,db,user)
            await db.commit()
            return result

    async def count_messages(self):
        async with self.sessions() as db:
            return await db.scalar(select(func.count(models.Message.id)))


class BaselineEvidence(Fixture):
    async def test_current_end_accepts_owned_chat_with_foreign_room(self):
        result = await self.invoke('handle_end_call_signaling',{'chat_id':20,'room_id':'a'*32,'message_id':100},3)
        self.assertEqual(result['status'],'ended')
        self.assertNotIn('a'*32,self.calls)
        async with self.sessions() as db:
            self.assertEqual(json.loads((await db.get(models.Message,100)).system_event_json)['status'],'ended')

    async def test_current_start_replaces_foreign_active_room(self):
        result = await self.invoke('handle_start_call',{'chat_id':20,'room_id':'a'*32},3)
        self.assertEqual(result['status'],'ringing')
        self.assertEqual(self.calls['a'*32]['chat_id'],20)

    async def test_current_legacy_get_discloses_other_chat_participants(self):
        result=await self.invoke('handle_get_call',{'call_id':200},3)
        self.assertEqual(result['chat_id'],10)
        self.assertEqual(result['participants'][0]['user_id'],1)

    async def test_current_legacy_answer_inserts_nonmember_participant(self):
        result=await self.invoke('handle_answer_call',{'call_id':200,'accept':True},3)
        self.assertEqual(result['status'],'active')
        async with self.sessions() as db:
            self.assertIsNotNone(await db.scalar(select(models.CallParticipant).where(models.CallParticipant.call_id==200,models.CallParticipant.user_id==3)))

    async def test_current_legacy_end_changes_other_chat_call(self):
        result=await self.invoke('handle_end_call',{'call_id':200},3)
        self.assertEqual(result['status'],'missed')


class CandidateSecurityRegression(Fixture):
    async def test_reject_foreign_room_without_messages_or_notifications(self):
        result = await self.invoke('handle_end_call_signaling',{'chat_id':20,'room_id':'a'*32,'message_id':100},3)
        self.assertIn('error',result)
        self.assertEqual(self.calls['a'*32]['status'],'active')
        self.assertEqual(self.events,[])
        async with self.sessions() as db:
            self.assertEqual(json.loads((await db.get(models.Message,100)).system_event_json)['status'],'active')

    async def test_actual_room_member_can_end(self):
        result = await self.invoke('handle_end_call_signaling',{'chat_id':10,'room_id':'a'*32,'message_id':100},2)
        self.assertEqual(result['status'],'ended')
        self.assertNotIn('a'*32,self.calls)
        self.assertTrue(self.events)

    async def test_nonmember_cannot_end_with_correct_identifiers(self):
        with self.assertRaises(ValueError):
            await self.invoke('handle_end_call_signaling',{'chat_id':10,'room_id':'a'*32,'message_id':100},3)
        self.assertEqual(self.calls['a'*32]['status'],'active')

    async def test_room_reused_during_membership_await_cannot_change_target(self):
        check=self.ns['_require_member']
        replacement={'chat_id':20,'message_id':101,'initiator_id':3,'participants':{3,4},'status':'active'}
        async def replace_after_check(db,chat_id,user_id):
            await check(db,chat_id,user_id)
            self.calls['a'*32]=replacement
        self.ns['_require_member']=replace_after_check
        result=await self.invoke('handle_end_call_signaling',{'chat_id':10,'room_id':'a'*32,'message_id':100},1)
        self.assertIn('error',result)
        self.assertIs(self.calls['a'*32],replacement)
        self.assertEqual(replacement['status'],'active')
        self.assertEqual(self.events,[])

    async def test_wrong_message_id_does_not_end_same_chat_call(self):
        result = await self.invoke('handle_end_call_signaling',{'chat_id':10,'room_id':'a'*32,'message_id':99},1)
        self.assertIn('error',result)
        self.assertEqual(self.calls['a'*32]['status'],'active')

    async def test_repeated_end_is_idempotent(self):
        payload={'chat_id':10,'room_id':'a'*32,'message_id':100}
        await self.invoke('handle_end_call_signaling',payload,1)
        events=len(self.events)
        result=await self.invoke('handle_end_call_signaling',payload,1)
        self.assertEqual(result['status'],'ended')
        self.assertEqual(len(self.events),events)

    async def test_room_collision_does_not_replace_or_write_message(self):
        before=await self.count_messages()
        result=await self.invoke('handle_start_call',{'chat_id':20,'room_id':'a'*32},3)
        self.assertIn('error',result)
        self.assertEqual(self.calls['a'*32]['chat_id'],10)
        self.assertEqual(await self.count_messages(),before)
        self.assertEqual(self.events,[])

    async def test_simultaneous_same_room_has_one_owner(self):
        self.calls.clear()
        results=await asyncio.gather(self.invoke('handle_start_call',{'chat_id':10,'room_id':'b'*32},1),self.invoke('handle_start_call',{'chat_id':20,'room_id':'b'*32},3))
        self.assertEqual(sum(result.get('status')=='ringing' for result in results),1)
        self.assertEqual(sum('error' in result for result in results),1)
        self.assertEqual(await self.count_messages(),2)
        self.assertEqual(self.ns['_pending_start_rooms'],set())
        self.assertEqual(self.ns['_pending_start_users'],set())

    async def test_simultaneous_same_caller_cannot_create_two_calls(self):
        self.calls.clear()
        results=await asyncio.gather(self.invoke('handle_start_call',{'chat_id':10,'room_id':'b'*32},1),self.invoke('handle_start_call',{'chat_id':10,'room_id':'c'*32},1))
        self.assertEqual(sum(result.get('status')=='ringing' for result in results),1)
        self.assertEqual(await self.count_messages(),2)

    async def test_membership_failure_releases_reservation_for_retry(self):
        with self.assertRaises(ValueError):
            await self.invoke('handle_start_call',{'chat_id':10,'room_id':'b'*32},3)
        self.assertEqual(self.ns['_pending_start_rooms'],set())
        self.assertEqual(self.ns['_pending_start_users'],set())
        result=await self.invoke('handle_start_call',{'chat_id':20,'room_id':'b'*32},3)
        self.assertEqual(result['status'],'ringing')

    async def test_busy_caller_does_not_leave_orphan_message(self):
        before=await self.count_messages()
        result=await self.invoke('handle_start_call',{'chat_id':10,'room_id':'b'*32},1)
        self.assertIn('error',result)
        self.assertEqual(await self.count_messages(),before)

    async def test_decline_keeps_its_existing_identity_check(self):
        result=await self.invoke('handle_decline_call',{'chat_id':20,'room_id':'a'*32},3)
        self.assertIn('error',result)
        self.assertIn('a'*32,self.calls)
        result=await self.invoke('handle_decline_call',{'chat_id':10,'room_id':'a'*32},2)
        self.assertEqual(result['status'],'declined')

    async def test_legacy_get_requires_real_chat_membership(self):
        with self.assertRaises(ValueError):
            await self.invoke('handle_get_call',{'call_id':200},3)
        result=await self.invoke('handle_get_call',{'call_id':200},2)
        self.assertEqual(result['chat_id'],10)
        self.assertEqual(result['participants'][0]['user_id'],1)

    async def test_legacy_answer_requires_membership_before_inserting_participant(self):
        with self.assertRaises(ValueError):
            await self.invoke('handle_answer_call',{'call_id':200,'accept':True},3)
        async with self.sessions() as db:
            self.assertEqual((await db.get(models.Call,200)).status,models.CallStatus.RINGING)
            self.assertIsNone(await db.scalar(select(models.CallParticipant).where(models.CallParticipant.call_id==200,models.CallParticipant.user_id==3)))
        result=await self.invoke('handle_answer_call',{'call_id':200,'accept':True},2)
        self.assertEqual(result['status'],'active')

    async def test_legacy_end_requires_membership_before_status_or_log_change(self):
        before=await self.count_messages()
        with self.assertRaises(ValueError):
            await self.invoke('handle_end_call',{'call_id':200},3)
        self.assertEqual(await self.count_messages(),before)
        result=await self.invoke('handle_end_call',{'call_id':200},2)
        self.assertEqual(result['status'],'missed')


if __name__=='__main__':
    suite=unittest.defaultTestLoader.loadTestsFromTestCase(BaselineEvidence if BASELINE else CandidateSecurityRegression)
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(not result.wasSuccessful())
