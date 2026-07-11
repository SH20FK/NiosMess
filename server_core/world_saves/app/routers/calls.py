"""
Call signalling — REST-based.
Real WebRTC signalling should go through WebSockets/TURN server in production.
This API logs call state and provides signalling data exchange.
"""
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.models import Call, CallParticipant, CallStatus, ChatMember, Message, MessageType, Chat, ChatType
from app.services.encryption import encrypt_text
from app.dependencies import get_current_user
from app.models.models import User

router = APIRouter(prefix="/calls", tags=["Calls"])

class InitiateCallRequest(BaseModel):
    chat_id: int
    is_video: bool = False

class AnswerCallRequest(BaseModel):
    call_id: int
    accept: bool

class EndCallRequest(BaseModel):
    call_id: int

@router.post("/initiate")
async def initiate_call(body: InitiateCallRequest,
                        current_user: User = Depends(get_current_user),
                        db: AsyncSession = Depends(get_db)):
    """
    Start a voice or video call in a chat.
    For DMs this rings the other user. For groups it creates a group call.
    """
    mr = await db.execute(select(ChatMember).where(
        ChatMember.chat_id == body.chat_id, ChatMember.user_id == current_user.id,
        ChatMember.is_banned == False))
    if not mr.scalar_one_or_none():
        raise HTTPException(403, "Not a member of this chat")

    call = Call(chat_id=body.chat_id, initiator_id=current_user.id,
                is_video=body.is_video, status=CallStatus.RINGING)
    db.add(call); await db.flush()

    # Add initiator as first participant
    db.add(CallParticipant(call_id=call.id, user_id=current_user.id))

    call_type = "video" if body.is_video else "voice"
    return {"call_id": call.id, "chat_id": body.chat_id,
            "status": "ringing", "call_type": call_type,
            "message": "Call initiated. Waiting for others to join."}

@router.post("/answer")
async def answer_call(body: AnswerCallRequest,
                      current_user: User = Depends(get_current_user),
                      db: AsyncSession = Depends(get_db)):
    """Accept or decline an incoming call."""
    r = await db.execute(select(Call).where(Call.id == body.call_id))
    call = r.scalar_one_or_none()
    if not call: raise HTTPException(404, "Call not found")
    if call.status not in (CallStatus.RINGING, CallStatus.ACTIVE):
        raise HTTPException(400, f"Call is already {call.status.value}")

    if body.accept:
        call.status = CallStatus.ACTIVE
        db.add(CallParticipant(call_id=call.id, user_id=current_user.id))
        return {"call_id": call.id, "status": "active"}
    else:
        # Only decline if you're the only other party (DM)
        call.status = CallStatus.DECLINED
        call.ended_at = datetime.now(timezone.utc)
        await _log_call_message(db, call, current_user.id, "declined")
        return {"call_id": call.id, "status": "declined"}

@router.post("/end")
async def end_call(body: EndCallRequest,
                   current_user: User = Depends(get_current_user),
                   db: AsyncSession = Depends(get_db)):
    """End an active or ringing call."""
    r = await db.execute(select(Call).where(Call.id == body.call_id))
    call = r.scalar_one_or_none()
    if not call: raise HTTPException(404, "Call not found")

    now = datetime.now(timezone.utc)
    was_missed = call.status == CallStatus.RINGING
    call.status = CallStatus.MISSED if was_missed else CallStatus.ENDED
    call.ended_at = now

    if call.started_at and not was_missed:
        delta = now - call.started_at.replace(tzinfo=timezone.utc) if call.started_at.tzinfo is None else now - call.started_at
        call.duration_seconds = int(delta.total_seconds())

    # Mark participant as left
    pr = await db.execute(select(CallParticipant).where(
        CallParticipant.call_id == call.id, CallParticipant.user_id == current_user.id))
    p = pr.scalar_one_or_none()
    if p: p.left_at = now; p.is_active = False

    status_str = "missed" if was_missed else f"ended ({call.duration_seconds}s)"
    await _log_call_message(db, call, current_user.id, status_str)

    return {"call_id": call.id, "status": call.status.value,
            "duration_seconds": call.duration_seconds}

@router.get("/{call_id}")
async def get_call(call_id: int, current_user: User = Depends(get_current_user),
                   db: AsyncSession = Depends(get_db)):
    r = await db.execute(select(Call).where(Call.id == call_id))
    call = r.scalar_one_or_none()
    if not call: raise HTTPException(404, "Call not found")
    pr = await db.execute(select(CallParticipant).where(
        CallParticipant.call_id == call_id, CallParticipant.is_active == True))
    participants = [{"user_id": p.user_id, "joined_at": p.joined_at}
                    for p in pr.scalars().all()]
    return {"call_id": call.id, "chat_id": call.chat_id,
            "initiator_id": call.initiator_id, "is_video": call.is_video,
            "status": call.status.value, "started_at": call.started_at,
            "ended_at": call.ended_at, "duration_seconds": call.duration_seconds,
            "participants": participants}

async def _log_call_message(db, call: Call, user_id: int, status_str: str):
    """Write a system call-log message into the chat."""
    call_type = "📹 Video" if call.is_video else "📞 Voice"
    text = f"{call_type} call — {status_str}"
    enc = encrypt_text(text)
    msg = Message(chat_id=call.chat_id, sender_id=user_id,
                  msg_type=MessageType.CALL_LOG,
                  encrypted_content=enc["ciphertext"],
                  content_iv=enc["iv"], content_tag=enc["tag"])
    db.add(msg)
