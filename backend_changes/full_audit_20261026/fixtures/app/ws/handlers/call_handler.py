"""Test fixture: verbatim selected source functions; never import production settings."""

async def _finish_call(db: AsyncSession, room_id: str, was_missed: bool = False, duration: int = 0):
    call_info = active_calls.get(room_id)
    if not call_info or call_info.get("status") == "ended":
        return

    call_info["status"] = "ended"
    timeout_task = call_info.get("timeout_task")
    if timeout_task and timeout_task is not asyncio.current_task():
        try:
            timeout_task.cancel()
        except Exception:
            pass

    chat_id = call_info["chat_id"]
    message_id = call_info["message_id"]
    is_video = call_info.get("is_video", False)

    r = await db.execute(select(Message).where(Message.id == message_id, Message.chat_id == chat_id))
    msg = r.scalar_one_or_none()
    if msg:
        call_type = "Видеозвонок" if is_video else "Голосовой звонок"
        if was_missed:
            status_text = "Пропущен"
        else:
            status_text = f"Завершен ({duration} сек.)" if duration > 0 else "Завершен"
        text_content = f"{call_type} — {status_text}"
        enc = encrypt_text(text_content)
        msg.encrypted_content = enc["ciphertext"]
        msg.content_iv = enc["iv"]
        msg.content_tag = enc["tag"]
        msg.system_event_type = "call"
        msg.system_event_json = json.dumps(
            {
                "status": "missed" if was_missed else "ended",
                "call_type": "video" if is_video else "voice",
                "duration": max(0, int(duration or 0)),
                "room_id": room_id,
            },
            ensure_ascii=False,
        )
        msg.edited_at = datetime.now(timezone.utc)
        serialized_msg = await serialise_message(msg, db)

        end_payload = {
            "action": "end_call",
            "payload": {
                "chat_id": chat_id,
                "room_id": room_id,
                "message_id": message_id,
                "was_missed": was_missed,
                "duration": duration,
                "message": serialized_msg,
            },
        }
        await push_to_chat(db, chat_id, {"action": "edit_message", "payload": serialized_msg})
        await push_to_chat(db, chat_id, end_payload)

    await queue_call_cancellation(db, chat_id, room_id)
    active_calls.pop(room_id, None)


async def handle_start_call(payload: dict, db: AsyncSession, user: User) -> dict:
    chat_id = payload.get("chat_id")
    room_id = payload.get("room_id")
    caller_nickname = user.display_name
    is_video = payload.get("is_video", False)

    if user.is_bot:
        return {"error": "Bots cannot make calls"}
    if not chat_id or not isinstance(room_id, str) or not re.fullmatch(r"[a-fA-F0-9]{32}", room_id):
        return {"error": "chat_id and room_id are required"}

    await _can_send(db, chat_id, user.id)
    chat = (await db.execute(select(Chat).where(Chat.id == chat_id))).scalar_one_or_none()
    if chat and chat.chat_type == ChatType.DIRECT:
        other_id = chat.user2_id if chat.user1_id == user.id else chat.user1_id
        if other_id and await blocked_between(db, user.id, other_id):
            return {"error": "Calls are unavailable between these users"}
        if other_id and not await privacy_allows(db, other_id, user.id, "calls"):
            return {"error": "This user does not accept calls from you"}

    human_callees = (await db.execute(
        select(User.id).join(ChatMember, ChatMember.user_id == User.id).where(
            ChatMember.chat_id == chat_id,
            ChatMember.is_banned == False,
            User.id != user.id,
            User.is_bot == False,
            User.is_active == True,
        )
    )).scalars().all()
    if not human_callees:
        return {"error": "Bots cannot receive calls"}
    earned_now = await _award_calls_tester(db, user.id)
    tester_badge = earned_now or bool(await db.scalar(
        select(UserBadge.id).join(Badge, Badge.id == UserBadge.badge_id).where(
            UserBadge.user_id == user.id, Badge.name == "Calls Tester"
        )
    ))
    try:
        call_access_token = _call_access_token(user, room_id, tester_badge, bool(is_video))
    except RuntimeError:
        return {"error": "Calls are temporarily unavailable"}

    if room_id in active_calls:
        active_calls.pop(room_id, None)

    call_type = "Видеозвонок" if is_video else "Голосовой звонок"
    text_content = f"{call_type} — Вызов..."
    enc = encrypt_text(text_content)

    msg = Message(
        chat_id=chat_id,
        sender_id=user.id,
        msg_type=MessageType.CALL_LOG,
        encrypted_content=enc["ciphertext"],
        content_iv=enc["iv"],
        content_tag=enc["tag"],
        system_event_type="call",
        system_event_json=json.dumps(
            {"status": "ringing", "call_type": "video" if is_video else "voice", "duration": 0, "room_id": room_id},
            ensure_ascii=False,
        ),
    )
    db.add(msg)
    await db.flush()

    serialized_msg = await serialise_message(msg, db)
    # Commit before notifying callees: they answer with join_call on their own
    # DB session and must be able to see this call-log message (SQLite isolation).
    await db.commit()
    callee_ids = list(human_callees)

    _busy = [
        other_room
        for other_room, info in list(active_calls.items())
        if info.get("status") in ("ringing", "active")
        and (info.get("initiator_id") == user.id or user.id in info.get("participants", set()))
    ]
    if _busy:
        return {"error": "You are already in a call"}

    active_calls[room_id] = {
        "chat_id": chat_id,
        "initiator_id": user.id,
        "callee_ids": callee_ids,
        "started_at": datetime.now(timezone.utc),
        "message_id": msg.id,
        "is_video": is_video,
        "status": "ringing",
        "participants": {user.id},
        "tester": tester_badge,
        "timeout_task": asyncio.create_task(_call_timeout_worker(room_id)),
    }

    new_call_payload = {
        "action": "new_call",
        "payload": {
            "chat_id": chat_id,
            "room_id": room_id,
            "message_id": msg.id,
            "caller_id": user.id,
            "caller_nickname": caller_nickname,
            "is_video": is_video,
            "message": serialized_msg,
        },
    }

    await push_to_chat(db, chat_id, {"action": "new_message", "payload": serialized_msg}, exclude_user_id=user.id, skip_offline_fcm=True)
    await push_to_chat(db, chat_id, new_call_payload, exclude_user_id=user.id, skip_offline_fcm=True)

    if callee_ids:
        try:
            tokens_req = await db.execute(select(UserFCMToken.fcm_token).where(UserFCMToken.user_id.in_(callee_ids)))
            tokens = list(set([row[0] for row in tokens_req.all() if row[0]]))
            if tokens:
                title = caller_nickname or "NiosMess"
                body = "Видеозвонок" if is_video else "Голосовой звонок"
                data_payload = {
                    "type": "incoming_call",
                    "created_at": datetime.now(timezone.utc).isoformat(),
                    "expires_at": (datetime.now(timezone.utc) + timedelta(seconds=CALL_RINGING_TIMEOUT_SECONDS)).isoformat(),
                    "chat_id": str(chat_id),
                    "room_id": str(room_id),
                    "message_id": str(msg.id),
                    "caller_id": str(user.id),
                    "caller_nickname": str(caller_nickname),
                    "is_video": str(bool(is_video)).lower(),
                }
                chunked_tokens = [tokens[i:i + 500] for i in range(0, len(tokens), 500)]
                for chunk in chunked_tokens:
                    queue_push(db, chunk, title, body, data_payload)
        except Exception:
            logging.getLogger("niosmess.push").exception("Failed to dispatch call push for chat %s", chat_id)

    return {
        "status": "ringing",
        "room_id": room_id,
        "message_id": msg.id,
        "message": serialized_msg,
        "call_access_token": call_access_token,
        "signal_url": settings.CALLS_SIGNAL_URL,
        "max_video_height": 720 if tester_badge else 480,
        "max_duration_seconds": None if tester_badge else 1800,
        "ice_servers": _call_ice_servers(user),
    }


async def handle_decline_call(payload: dict, db: AsyncSession, user: User) -> dict:
    chat_id = payload.get("chat_id")
    room_id = payload.get("room_id")
    if not room_id:
        return {"error": "room_id is required"}
    info = active_calls.get(room_id)
    if not info:
        return {'status': 'ended'}
    if chat_id != info['chat_id']:
        return {'error': 'Call chat mismatch'}
    await _require_member(db, info['chat_id'], user.id)
    await _finish_call(db, room_id, was_missed=True, duration=0)
    return {"status": "declined"}


async def handle_end_call_signaling(payload: dict, db: AsyncSession, user: User) -> dict:
    chat_id = payload.get("chat_id")
    room_id = payload.get("room_id")
    message_id = payload.get("message_id")
    duration = payload.get("duration", 0)
    was_missed = payload.get("was_missed", False)

    if not chat_id or not room_id or not message_id:
        return {"error": "chat_id, room_id, and message_id are required"}

    await _require_member(db, chat_id, user.id)
    await _finish_call(db, room_id, was_missed=was_missed, duration=duration)
    return {"status": "ended"}


async def _log_call_message(db: AsyncSession, call: Call, user_id: int, status_str: str):
    call_type = "📹 Video" if call.is_video else "📞 Voice"
    text_content = f"{call_type} call — {status_str}"
    enc = encrypt_text(text_content)
    msg = Message(
        chat_id=call.chat_id,
        sender_id=user_id,
        msg_type=MessageType.CALL_LOG,
        encrypted_content=enc["ciphertext"],
        content_iv=enc["iv"],
        content_tag=enc["tag"],
    )
    db.add(msg)


async def handle_answer_call(payload: dict, db: AsyncSession, user: User) -> dict:
    call_id = payload.get("call_id")
    accept = payload.get("accept")
    r = await db.execute(select(Call).where(Call.id == call_id))
    call = r.scalar_one_or_none()
    if not call:
        return {"error": "Call not found"}
    if call.status not in (CallStatus.RINGING, CallStatus.ACTIVE):
        return {"error": f"Call is already {call.status.value}"}
    if accept:
        call.status = CallStatus.ACTIVE
        db.add(CallParticipant(call_id=call.id, user_id=user.id))
        return {"call_id": call.id, "status": "active"}
    else:
        call.status = CallStatus.DECLINED
        call.ended_at = datetime.now(timezone.utc)
        await _log_call_message(db, call, user.id, "declined")
        return {"call_id": call.id, "status": "declined"}


async def handle_end_call(payload: dict, db: AsyncSession, user: User) -> dict:
    call_id = payload.get("call_id")
    r = await db.execute(select(Call).where(Call.id == call_id))
    call = r.scalar_one_or_none()
    if not call:
        return {"error": "Call not found"}
    now = datetime.now(timezone.utc)
    was_missed = call.status == CallStatus.RINGING
    call.status = CallStatus.MISSED if was_missed else CallStatus.ENDED
    call.ended_at = now
    if call.started_at and not was_missed:
        started_at = call.started_at.replace(tzinfo=timezone.utc) if call.started_at.tzinfo is None else call.started_at
        delta = now - started_at
        call.duration_seconds = int(delta.total_seconds())
    pr = await db.execute(
        select(CallParticipant).where(CallParticipant.call_id == call.id, CallParticipant.user_id == user.id)
    )
    p = pr.scalar_one_or_none()
    if p:
        p.left_at = now
        p.is_active = False
    status_str = "missed" if was_missed else f"ended ({call.duration_seconds}s)"
    await _log_call_message(db, call, user.id, status_str)
    return {"call_id": call.id, "status": call.status.value, "duration_seconds": call.duration_seconds}


async def handle_get_call(payload: dict, db: AsyncSession, user: User) -> dict:
    call_id = payload.get("call_id")
    r = await db.execute(select(Call).where(Call.id == call_id))
    call = r.scalar_one_or_none()
    if not call:
        return {"error": "Call not found"}
    pr = await db.execute(
        select(CallParticipant).where(CallParticipant.call_id == call_id, CallParticipant.is_active == True)
    )
    participants = [
        {"user_id": p.user_id, "joined_at": p.joined_at.isoformat() if p.joined_at else None}
        for p in pr.scalars().all()
    ]
    return {
        "call_id": call.id,
        "chat_id": call.chat_id,
        "initiator_id": call.initiator_id,
        "is_video": call.is_video,
        "status": call.status.value,
        "started_at": call.started_at.isoformat() if call.started_at else None,
        "ended_at": call.ended_at.isoformat() if call.ended_at else None,
        "duration_seconds": call.duration_seconds,
        "participants": participants,
    }
