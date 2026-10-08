import base64
import json
from uuid import uuid4

import pytest
from sqlalchemy import select, func
from test_secret_chat_hardening import db, _user, _session
from app.models.models import Chat, Message, Session
from app.ws.handlers.chat_handler import handle_open_direct
from app.services.secret_chat_v2 import (
    SecretEvent, SecretOperation, handle_secret_control, handle_secret_mutation,
    handle_secret_sync, register_capability,
)

OWNER_KEY = base64.b64encode(bytes(range(32))).decode()
PEER_KEY = base64.b64encode(bytes(range(32, 64))).decode()


async def setup(db):
    owner, peer = _user(1201), _user(1202)
    db.add_all([owner, peer])
    await db.flush()
    session = _session(owner.id, 'owner-token', OWNER_KEY)
    db.add_all([session, _session(peer.id, 'peer-token', PEER_KEY)])
    await db.flush()
    result = await handle_open_direct({'user_id': peer.id, 'is_secret': True,
        'target_public_key': PEER_KEY}, db, owner, session)
    assert 'error' not in result
    await register_capability(db, owner, session, 2)
    peer_session = await db.scalar(select(Session).where(Session.user_id == peer.id))
    await register_capability(db, peer, peer_session, 2)
    await db.commit()
    return owner, peer, session, peer_session, result['chat_id']


def send_payload(chat_id):
    return {'chat_id': chat_id, 'client_message_id': str(uuid4()), 'e2ee_content': 'client-ciphertext'}


@pytest.mark.asyncio
async def test_retry_after_commit_returns_same_message_and_event(db):
    owner, peer, session, peer_session, chat = await setup(db)
    payload = send_payload(chat)
    first = await handle_secret_mutation('send_message', payload, db, owner, session)
    await db.commit()  # the socket disconnects before the client sees the ACK
    retry = await handle_secret_mutation('send_message', payload, db, owner, session)
    await db.commit()
    assert retry == first
    assert await db.scalar(select(func.count()).select_from(Message)) == 1
    assert await db.scalar(select(func.count()).select_from(SecretEvent)) == 1
    row = await db.get(Message, first['id'])
    assert row.encrypted_content is None and row.e2ee_content == 'client-ciphertext'
    assert first['client_message_id'] == payload['client_message_id']
    from app.services.utils import get_unread
    assert await get_unread(db, chat, peer.id) == 1


@pytest.mark.asyncio
async def test_rollback_does_not_leave_a_dedup_record_or_event(db):
    owner, peer, session, peer_session, chat = await setup(db)
    payload = send_payload(chat)
    await handle_secret_mutation('send_message', payload, db, owner, session)
    await db.rollback()
    assert await db.scalar(select(func.count()).select_from(Message)) == 0
    assert await db.scalar(select(func.count()).select_from(SecretOperation)) == 0
    assert await db.scalar(select(func.count()).select_from(SecretEvent)) == 0


@pytest.mark.asyncio
async def test_same_id_cannot_change_ciphertext(db):
    owner, peer, session, peer_session, chat = await setup(db)
    payload = send_payload(chat)
    await handle_secret_mutation('send_message', payload, db, owner, session)
    await db.commit()
    with pytest.raises(ValueError, match='SECRET_ID_REUSED'):
        await handle_secret_mutation('send_message', {**payload, 'e2ee_content': 'different'}, db, owner, session)


@pytest.mark.asyncio
async def test_wrong_device_cannot_send_sync_or_exchange_keys(db):
    owner, peer, session, peer_session, chat = await setup(db)
    session.public_key = base64.b64encode(bytes([88] * 32)).decode()
    for call in (
        lambda: handle_secret_mutation('send_message', send_payload(chat), db, owner, session),
        lambda: handle_secret_sync({'chat_id': chat}, db, owner, session),
        lambda: handle_secret_control({'chat_id': chat}, db, owner, session),
    ):
        with pytest.raises(ValueError, match='SECRET_DEVICE_MISMATCH'):
            await call()


@pytest.mark.asyncio
async def test_control_is_durable_but_not_a_user_message(db):
    owner, peer, session, peer_session, chat = await setup(db)
    control = {'v': 2, 'kind': 'init', 'session_id': str(uuid4()), 'chat_id': chat,
               'from_key': OWNER_KEY, 'to_key': PEER_KEY, 'dh': OWNER_KEY,
               'ed': OWNER_KEY, 'sig': base64.b64encode(bytes(64)).decode()}
    payload = {'chat_id': chat, 'client_operation_id': str(uuid4()), 'control': control}
    first = await handle_secret_control(payload, db, owner, session)
    await db.commit()
    assert await handle_secret_control(payload, db, owner, session) == first
    assert await db.scalar(select(func.count()).select_from(Message)) == 0
    sync = await handle_secret_sync({'chat_id': chat}, db, peer, peer_session)
    assert sync['events'][0]['payload'] == control
    assert sync['peer_protocol_version'] == 2


@pytest.mark.asyncio
async def test_sync_pages_edits_and_deletion_tombstones(db):
    owner, peer, session, peer_session, chat = await setup(db)
    sent = await handle_secret_mutation('send_message', send_payload(chat), db, owner, session)
    edited = await handle_secret_mutation('edit_message', {'chat_id': chat, 'message_id': sent['id'],
        'client_operation_id': str(uuid4()), 'e2ee_content': 'edited-ciphertext'}, db, owner, session)
    await db.commit()
    first = await handle_secret_sync({'chat_id': chat, 'limit': 1}, db, peer, peer_session)
    assert first['has_more'] is True
    second = await handle_secret_sync({'chat_id': chat, 'after_event_id': first['cursor'], 'limit': 1}, db, peer, peer_session)
    assert second['has_more'] is False
    assert second['events'][0]['kind'] == 'edit'
    assert second['events'][0]['payload']['e2ee_content'] == 'edited-ciphertext'
    deleted_payload = {'chat_id': chat, 'message_id': sent['id'], 'client_operation_id': str(uuid4())}
    await handle_secret_mutation('delete_message', deleted_payload, db, owner, session)
    await db.commit()
    await handle_secret_mutation('delete_message', deleted_payload, db, owner, session)
    sync = await handle_secret_sync({'chat_id': chat}, db, peer, peer_session)
    assert len(sync['events']) == 3
    assert all(event['payload']['is_deleted'] for event in sync['events'])
    assert all('e2ee_content' not in event['payload'] for event in sync['events'])


@pytest.mark.asyncio
async def test_plaintext_and_unsupported_blob_attachment_are_rejected(db):
    owner, peer, session, peer_session, chat = await setup(db)
    with pytest.raises(ValueError, match='SECRET_CIPHERTEXT_REQUIRED'):
        await handle_secret_mutation('send_message', {**send_payload(chat), 'content': 'private'}, db, owner, session)


@pytest.mark.asyncio
async def test_control_rejects_extra_fields_and_wrong_device_keys(db):
    owner, peer, session, peer_session, chat = await setup(db)
    with pytest.raises(ValueError, match='SECRET_INVALID_CONTROL'):
        await handle_secret_control({'chat_id': chat, 'client_operation_id': str(uuid4()),
            'control': {'v': 2, 'plaintext': 'not allowed'}}, db, owner, session)


@pytest.mark.asyncio
async def test_encrypted_attachment_retry_consumes_upload_once(db, tmp_path, monkeypatch):
    from app.models.models import MediaUploadChunk
    from app.config import settings
    from app.services.encryption import decrypt_file
    from app.services.secret_chat_v2 import after_commit
    owner, peer, session, peer_session, chat = await setup(db)
    monkeypatch.setattr(settings, 'UPLOAD_DIR', str(tmp_path))
    source = tmp_path / 'encrypted-upload.bin'
    ciphertext = bytes(range(256)) * 3
    source.write_bytes(ciphertext)
    db.add(MediaUploadChunk(upload_id='opaque-upload', user_id=owner.id, filename='encrypted.bin',
        temp_path=str(source), total_chunks=1, received_chunks=1, received_bytes=len(ciphertext)))
    await db.commit()
    payload = {**send_payload(chat), 'upload_id': 'opaque-upload'}
    result = await handle_secret_mutation('send_message', payload, db, owner, session)
    assert source.exists()  # cleanup is forbidden before durable commit
    await db.commit()
    await after_commit(db)
    assert not source.exists()
    assert await handle_secret_mutation('send_message', payload, db, owner, session) == result
    assert await db.scalar(select(func.count()).select_from(MediaUploadChunk)) == 0
    row = await db.get(Message, result['id'])
    assert row.media_name == 'encrypted.bin'
    assert (tmp_path / 'encrypted-upload.bin.enc').exists()


@pytest.mark.asyncio
async def test_duplicate_does_not_repeat_post_commit_wakeups(db, monkeypatch):
    from app.services.secret_chat_v2 import after_commit
    from app.ws import connection_manager
    owner, peer, session, peer_session, chat = await setup(db)
    notifications = []
    async def capture(db, chat_id, payload, **kwargs):
        notifications.append(payload['action'])
    monkeypatch.setattr(connection_manager, 'push_to_chat', capture)
    payload = send_payload(chat)
    await handle_secret_mutation('send_message', payload, db, owner, session)
    assert notifications == []
    await db.commit()
    await after_commit(db)
    await handle_secret_mutation('send_message', payload, db, owner, session)
    await db.commit()
    await after_commit(db)
    assert notifications == ['secret_changed', 'new_message']


@pytest.mark.asyncio
async def test_old_protocol_cannot_receive_new_delivery(db):
    owner, peer, session, peer_session, chat = await setup(db)
    await register_capability(db, peer, peer_session, 0)
    await db.commit()
    with pytest.raises(ValueError, match='SECRET_PROTOCOL_UPGRADE_REQUIRED'):
        await handle_secret_mutation('send_message', send_payload(chat), db, owner, session)
    await db.rollback()
    assert await db.scalar(select(func.count()).select_from(Message)) == 0
