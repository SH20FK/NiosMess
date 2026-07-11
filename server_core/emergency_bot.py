import os
import json
import asyncio
import logging
from datetime import datetime, timezone, timedelta
from aiogram import Bot, Dispatcher, Router, F
from aiogram.types import Message
from aiogram.filters import Command
from aiogram.client.default import DefaultBotProperties

# Настройка логирования
logging.basicConfig(level=logging.INFO)

API_TOKEN = "8700309014:AAHKAYOJyORfAqC2SwR_1Cm9bHfoBV4TRYA"
ADMIN_TG_ID = 5079149312  # Твой настоящий Telegram ID
DATA_FILE = "emergency_chats.json"
PACKETS_FILE = "packets.json"  # Очередь пакетов для сервера

# Часовой пояс Москвы (UTC+3)
MOSCOW_TZ = timezone(timedelta(hours=3))

bot = Bot(token=API_TOKEN, default=DefaultBotProperties(parse_mode="HTML"))
dp = Dispatcher()
router = Router()

def load_data():
    if not os.path.exists(DATA_FILE):
        return {"chats": {}, "stats": {"total_cases": 100, "success_cases": 98}}
    with open(DATA_FILE, "r", encoding="utf-8") as f:
        return json.load(f)

def save_data(data):
    with open(DATA_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4, ensure_ascii=False)

db = load_data()

def is_night_time() -> bool:
    """Проверяет, находится ли текущее время по МСК в промежутке с 22:00 до 13:00."""
    now_moscow = datetime.now(MOSCOW_TZ)
    current_hour = now_moscow.hour
    
    # С 22 вечера (включая 22:00) до 13 дня (не включая 13:00)
    if current_hour >= 22 or current_hour < 13:
        return True
    return False

def push_packet_to_json(username: str, text: str):
    """Добавляет пакет в packets.json для последующей обработки сервером"""
    packets = []
    if os.path.exists(PACKETS_FILE):
        try:
            with open(PACKETS_FILE, "r", encoding="utf-8") as f:
                packets = json.load(f)
        except Exception:
            packets = []
            
    new_packet = {
        "id": int(datetime.now().timestamp() * 1000),
        "username": username,
        "text": text,
        "completed": False,
        "timestamp": datetime.now().strftime("%H:%M")
    }
    packets.append(new_packet)
    
    try:
        with open(PACKETS_FILE, "w", encoding="utf-8") as f:
            json.dump(packets, f, indent=4, ensure_ascii=False)
        logging.info(f"Пакет сохранен в {PACKETS_FILE} для {username}")
    except Exception as e:
        logging.error(f"Не удалось сохранить пакет в JSON: {e}")

@router.message(Command("start"))
async def cmd_start(message: Message):
    stats = db.get("stats", {"total_cases": 100, "success_cases": 95})
    percent = int((stats["success_cases"] / stats["total_cases"]) * 100) if stats["total_cases"] > 0 else 95
    
    welcome_text = (
        f"Привет! Это бот экстренной связи с @hello_sanlsan.\n\n"
        f"Отвечаю в течение минуты в <b>{percent}%</b> случаев.\n"
        f"— <b>Лимит:</b> 1 сообщение. Повторно написать нельзя, пока админ не ответит.\n"
        f"— <b>Часы приема заявок:</b> с 13:00 до 22:00 по МСК.\n"
        f"Пишите полно, одним сообщением."
    )
    await message.answer(welcome_text)

@router.message(Command("admin"))
async def cmd_admin(message: Message):
    if message.from_user.id != ADMIN_TG_ID:
        return
        
    chats = db.get("chats", {})
    if not chats:
        await message.answer("Список экстренных чатов пуст.")
        return
        
    report = "<b>Список активных чатов:</b>\n\n"
    for uid, info in chats.items():
        status = "🔴 Ожидает ответа" if info.get("locked", False) else "🟢 Свободен"
        username = info.get("username", f"id{uid}")
        last_msg = info['messages'][-1]['text'][:30] if info['messages'] else "Нет сообщений"
        report += f"• @{username} (ID: {uid}) — {status}\n Последнее: {last_msg}...\n\n"
    
    await message.answer(report)

@router.message(F.chat.id == ADMIN_TG_ID, F.reply_to_message)
async def admin_reply(message: Message):
    chats = db.get("chats", {})
    target_user_id = None
    
    for uid, info in chats.items():
        if info.get("locked") and info["messages"]:
            target_user_id = uid
            break
            
    if not target_user_id:
        await message.answer("Не удалось определить адресата для сброса лимита.")
        return

    db["chats"][target_user_id]["locked"] = False
    db["chats"][target_user_id]["messages"].append({
        "sender": "admin",
        "text": message.text
    })
    save_data(db)
    
    try:
        await bot.send_message(int(target_user_id), f"<b>Ответ от @hello_sanlsan:</b>\n\n{message.text}")
        await message.answer("Ответ отправлен. Лимит пользователя успешно сброшен.")
    except Exception as e:
        await message.answer(f"Ошибка доставки: {e}")

@router.message(F.chat.id != ADMIN_TG_ID)
async def handle_user_message(message: Message):
    if is_night_time():
        await message.answer("<b>Связь недоступна.</b> Прием экстренных сообщений закрыт с 22:00 до 13:00 по МСК. Напишите в рабочее время.")
        return

    user_id = str(message.from_user.id)
    username = message.from_user.username or f"id_{user_id}"
    
    if user_id not in db["chats"]:
        db["chats"][user_id] = {"username": username, "locked": False, "messages": []}
        
    if db["chats"][user_id].get("locked", False):
        await message.answer("<b>Ошибка:</b> Вы уже отправили сообщение. Дождитесь ответа, чтобы снять лимит.")
        return

    db["chats"][user_id]["locked"] = True
    db["chats"][user_id]["messages"].append({
        "sender": "user",
        "text": message.text
    })
    db["stats"]["total_cases"] = db.get("stats", {}).get("total_cases", 100) + 1
    save_data(db)
    
    await bot.send_message(
        ADMIN_TG_ID, 
        f"🚨 <b>Экстренное сообщение</b> от @{username} (ID: {user_id}):\n\n{message.text}"
    )
    
    # Сохраняем в файл вместо отправки по WS
    push_packet_to_json(f"@{username}", message.text)