"""Bot HTTP API — Telegram-like endpoints for bots."""
import json
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import AsyncSessionLocal
from app.models.models import Bot, User, Chat, ChatMember, ChatType, BotUpdate
from app.services.bot_svc import (
    get_bot_by_token, send_bot_message, edit_bot_message_reply_markup,
    delete_bot_message, get_bot_updates, queue_bot_update, bot_get_chat, bot_get_chat_member
)
from app.services.utils import serialise_message

router = APIRouter(prefix="/bot-api")

async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def _bot_auth(db: AsyncSession, token: str) -> Bot:
    bot = await get_bot_by_token(db, token)
    if not bot:
        raise HTTPException(status_code=401, detail="Unauthorized")
    return bot


class SendMessageBody(BaseModel):
    chat_id: int
    text: str
    reply_markup: Optional[dict] = None
    reply_to_message_id: Optional[int] = None


class EditMessageBody(BaseModel):
    chat_id: int
    message_id: int
    reply_markup: Optional[dict] = None


class DeleteMessageBody(BaseModel):
    chat_id: int
    message_id: int


class GetUpdatesBody(BaseModel):
    offset: int = 0
    limit: int = 100


class AnswerCallbackQueryBody(BaseModel):
    callback_query_id: str
    text: Optional[str] = None


class SetWebhookBody(BaseModel):
    url: Optional[str] = None


@router.post("/{token}/getMe")
async def get_me(token: str, db: AsyncSession = Depends(get_db)):
    bot = await get_bot_by_token(db, token)
    if not bot:
        return {"ok": False, "error_code": 401, "description": "Unauthorized"}
    return {
        "ok": True,
        "result": {
            "id": bot.user_id,
            "is_bot": True,
            "first_name": bot.name,
            "username": bot.username,
        }
    }


@router.post("/{token}/sendMessage")
async def send_message_api(token: str, body: SendMessageBody, db: AsyncSession = Depends(get_db)):
    bot = await get_bot_by_token(db, token)
    if not bot:
        return {"ok": False, "error_code": 401, "description": "Unauthorized"}
    result = await send_bot_message(db, bot, body.chat_id, body.text, body.reply_markup)
    if result.get("error"):
        return {"ok": False, "description": result["error"]}
    return {"ok": True, "result": result}


@router.post("/{token}/editMessageReplyMarkup")
async def edit_message_reply_markup_api(token: str, body: EditMessageBody, db: AsyncSession = Depends(get_db)):
    bot = await get_bot_by_token(db, token)
    if not bot:
        return {"ok": False, "error_code": 401, "description": "Unauthorized"}
    result = await edit_bot_message_reply_markup(db, bot, body.chat_id, body.message_id, body.reply_markup)
    if result.get("error"):
        return {"ok": False, "description": result["error"]}
    return {"ok": True, "result": result}


@router.post("/{token}/deleteMessage")
async def delete_message_api(token: str, body: DeleteMessageBody, db: AsyncSession = Depends(get_db)):
    bot = await get_bot_by_token(db, token)
    if not bot:
        return {"ok": False, "error_code": 401, "description": "Unauthorized"}
    result = await delete_bot_message(db, bot, body.chat_id, body.message_id)
    if result.get("error"):
        return {"ok": False, "description": result["error"]}
    return {"ok": True, "result": True}


@router.post("/{token}/getUpdates")
async def get_updates_api(token: str, body: GetUpdatesBody, db: AsyncSession = Depends(get_db)):
    bot = await get_bot_by_token(db, token)
    if not bot:
        return {"ok": False, "error_code": 401, "description": "Unauthorized"}
    
    from sqlalchemy import select
    from app.models.models import BotUpdate
    import json

    # Запрашиваем обновления напрямую из БД
    stmt = select(BotUpdate).where(BotUpdate.bot_id == bot.id).order_by(BotUpdate.id.asc())
    
    if body.offset:
        stmt = stmt.where(BotUpdate.id > body.offset)
    if body.limit:
        stmt = stmt.limit(body.limit)
        
    res = await db.execute(stmt)
    db_updates = res.scalars().all()
    
    result = []
    for u in db_updates:
        payload_data = u.payload
        
        # Безопасно парсим payload, если в базе он сохранился как строка
        if isinstance(payload_data, str):
            try:
                payload_data = json.loads(payload_data)
            except Exception:
                pass
                
        # 1. Динамически определяем имя поля типа обновления для защиты от AttributeError
        u_type = "message"
        for attr in ['type', 'update_type', 'event_type', 'action', 'kind']:
            if hasattr(u, attr):
                u_type = getattr(u, attr)
                break
        else:
            # Если стандартные атрибуты не найдены, инспектируем колонки SQLAlchemy-модели
            if hasattr(u, '__table__'):
                for col in u.__table__.columns.keys():
                    if col not in ['id', 'bot_id', 'payload', 'created_at', 'timestamp']:
                        u_type = getattr(u, col, "message")
                        break
                        
        # 2. Если значение типа — это Enum, безопасно извлекаем его строку (.value)
        if u_type and not isinstance(u_type, str):
            if hasattr(u_type, 'value'):
                u_type = u_type.value
            else:
                u_type = str(u_type)
                
        # Формируем универсальный словарь, совместимый со всеми версиями nios_bot.py
        update_dict = {
            "update_id": u.id,
            "type": u_type,
            "payload": payload_data,
            u_type: payload_data
        }
        result.append(update_dict)
        
    return {"ok": True, "result": result}


@router.post("/{token}/answerCallbackQuery")
async def answer_callback_query_api(token: str, body: AnswerCallbackQueryBody, db: AsyncSession = Depends(get_db)):
    bot = await get_bot_by_token(db, token)
    if not bot:
        return {"ok": False, "error_code": 401, "description": "Unauthorized"}
    return {"ok": True, "result": True}


@router.post("/{token}/getChat")
async def get_chat_api(token: str, chat_id: int, db: AsyncSession = Depends(get_db)):
    bot = await get_bot_by_token(db, token)
    if not bot:
        return {"ok": False, "error_code": 401, "description": "Unauthorized"}
    chat = await bot_get_chat(db, bot, chat_id)
    if not chat:
        return {"ok": False, "description": "Chat not found"}
    return {"ok": True, "result": chat}


@router.post("/{token}/getChatMember")
async def get_chat_member_api(token: str, chat_id: int, user_id: int, db: AsyncSession = Depends(get_db)):
    bot = await get_bot_by_token(db, token)
    if not bot:
        return {"ok": False, "error_code": 401, "description": "Unauthorized"}
    member = await bot_get_chat_member(db, bot, chat_id, user_id)
    if not member:
        return {"ok": False, "description": "Member not found"}
    return {"ok": True, "result": member}
