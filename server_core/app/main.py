import os
import json
import sqlite3
import datetime
import secrets
import string
import asyncio
import time
import urllib.parse
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect, Header, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse, StreamingResponse, Response
from pydantic import BaseModel
from sqlalchemy import select
import base64
import httpx

from app.database import init_db, AsyncSessionLocal
from app.config import settings
from app.ws_manager import ws_endpoint
from app.bot_api import router as bot_api_router
from app.services.auth_svc import get_session_by_token, get_user_by_id
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives.serialization import load_pem_private_key

# =======================================================================
#    НАСТРОЙКИ YOOMONEY (ВСТАВЬ СВОИ ДАННЫЕ СЮДА)
# =======================================================================
YOOMONEY_WALLET = os.getenv("YOOMONEY_WALLET", "4100118055534134") # Номер кошелька ЮMoney
YOOMONEY_TOKEN = os.getenv("YOOMONEY_TOKEN", "4100118055534134.DC0949C84C7EFBB17F2A0DBA8E1655E1B634E43684BCF2B346DE7E6A64BC7CBBA7D3B16BE0E4BFA3A82126454F753A4A8F3DD6647EF72F0FCD02DBB5BA8CB4570F7E6A39617519B92832A985C36ED3EFE929A757984A6E43B1CA8AE906E9238EF262DC78B6B6C550B257ACCA3D3E32DE1BB2215439EFC7C2BACE53B32064AE96")   # Токен для API (для проверки платежей)

# Маппинг тиров доната и их цен в рублях (как в плагине)
TIERS = {
    "shield": {"name": "Щит ✦", "price": 25},
    "lightbolt": {"name": "Молния ✦", "price": 40},
    "67": {"name": "67 ✦", "price": 67},
    "fire": {"name": "Огонек ✦", "price": 100},
    "cat": {"name": "Котик ✦", "price": 216}
}

# =======================================================================
#    ИНИЦИАЛИЗАЦИЯ И ФУНКЦИИ БАЗЫ ДАННЫХ PLUGIN.DB
# =======================================================================
try:
    with open("private_key.pem", "rb") as key_file:
        private_key = load_pem_private_key(key_file.read(), password=None)
    print("[Licence] Приватный ключ RSA успешно загружен.")
except Exception as e:
    print(f"[FATAL ERROR] Не удалось загрузить private_key.pem: {e}")
    private_key = None

def sign_data(data_str: str) -> str:
    if not private_key:
        return ""
    signature = private_key.sign(
        data_str.encode('utf-8'),
        padding.PKCS1v15(),
        hashes.SHA256()
    )
    return base64.b64encode(signature).decode('utf-8')

PLUGIN_DB = "PLUGIN.DB"
# Для отправки заявки с сайта
class DecoCraftAppPayload(BaseModel):
    nick: str
    age: str
    telegram: str
    about: str
    ip: str = "user"

# Для запросов от плагина (получение задач)
class DecoCraftGetPayload(BaseModel):
    secret_key: str

# Для создания счета на сайте
class CreateInvoicePayload(BaseModel):
    name: str        # Ник игрока
    group: str       # Префикс / Группа

# Для проверки счета сайтом
class CheckInvoicePayload(BaseModel):
    invoice_id: str
    
invoices = {}
decocraft_queue = []


def init_plugin_db():
    """Создает таблицы лицензий и истории техподдержки"""
    with sqlite3.connect(PLUGIN_DB) as conn:
        cursor = conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS licenses (
                key TEXT PRIMARY KEY,
                bound_address TEXT,
                expires_at TEXT,
                created_at TEXT
            )
        """)
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS support_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                client_ip TEXT,
                text TEXT,
                sender TEXT,
                created_at TEXT
            )
        """)
        conn.commit()

def seed_licenses():
    """Заполняет базу данных начальными лицензиями, если база пустая"""
    with sqlite3.connect(PLUGIN_DB) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM licenses")
        if cursor.fetchone()[0] == 0:
            default_keys = [
                ("sanlsan", "", "2099-12-31 23:59:59"),
                ("UL-KEY-4YJG-OJFS-RJOB", "", "2099-12-31 23:59:59"),
                ("UL-KEY-KLGV-MYLD-EUVS", "", "2099-12-31 23:59:59")
            ]
            cursor.executemany(
                "INSERT INTO licenses (key, bound_address, expires_at, created_at) VALUES (?, ?, ?, datetime('now', 'utc'))",
                default_keys
            )
            conn.commit()

def get_license(key: str):
    with sqlite3.connect(PLUGIN_DB) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT key, bound_address, expires_at FROM licenses WHERE key = ?", (key,))
        row = cursor.fetchone()
        if row:
            return {"key": row[0], "bound_address": row[1], "expires_at": row[2]}
        return None

def update_license_binding(key: str, address: str):
    with sqlite3.connect(PLUGIN_DB) as conn:
        cursor = conn.cursor()
        cursor.execute("UPDATE licenses SET bound_address = ? WHERE key = ?", (address, key))
        conn.commit()

def get_all_licenses():
    with sqlite3.connect(PLUGIN_DB) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT key, bound_address, expires_at, created_at FROM licenses")
        rows = cursor.fetchall()
        return [{"key": row[0], "bound_address": row[1], "expires_at": row[2], "created_at": row[3]} for row in rows]

def add_license_db(key: str, bound_address: str, expires_at: str):
    with sqlite3.connect(PLUGIN_DB) as conn:
        cursor = conn.cursor()
        cursor.execute("INSERT INTO licenses (key, bound_address, expires_at, created_at) VALUES (?, ?, ?, datetime('now', 'utc'))", (key, bound_address, expires_at))
        conn.commit()

def delete_license_db(key: str):
    with sqlite3.connect(PLUGIN_DB) as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM licenses WHERE key = ?", (key,))
        conn.commit()

def save_support_message(client_ip: str, text: str, sender: str):
    with sqlite3.connect(PLUGIN_DB) as conn:
        cursor = conn.cursor()
        cursor.execute("INSERT INTO support_history (client_ip, text, sender, created_at) VALUES (?, ?, ?, datetime('now', 'utc'))", (client_ip, text, sender))
        conn.commit()

def get_support_history(client_ip: str):
    with sqlite3.connect(PLUGIN_DB) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT text, sender FROM support_history WHERE client_ip = ? ORDER BY id ASC", (client_ip,))
        rows = cursor.fetchall()
        return [{"text": row[0], "sender": row[1]} for row in rows]

def get_all_chat_ips():
    with sqlite3.connect(PLUGIN_DB) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT DISTINCT client_ip FROM support_history")
        return [row[0] for row in cursor.fetchall()]

# =======================================================================
#    ИНИЦИАЛИЗАЦИЯ И ФУНКЦИИ БАЗЫ ДАННЫХ SERVERS.DB
# =======================================================================
SERVERS_DB = "SERVERS.db"

def init_servers_db():
    """Создает таблицу для хранения метрик и данных игровых серверов"""
    with sqlite3.connect(SERVERS_DB) as conn:
        cursor = conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS servers (
                server_address TEXT PRIMARY KEY,
                accounts INTEGER,
                usernames TEXT, 
                last_seen TEXT
            )
        """)
        conn.commit()

def upsert_server_stats(server_address: str, accounts: int, usernames: list):
    """Обновляет или добавляет информацию о сервере"""
    usernames_json = json.dumps(usernames)
    with sqlite3.connect(SERVERS_DB) as conn:
        cursor = conn.cursor()
        cursor.execute("""
            INSERT OR REPLACE INTO servers (server_address, accounts, usernames, last_seen)
            VALUES (?, ?, ?, datetime('now', 'utc'))
        """, (server_address, accounts, usernames_json))
        conn.commit()

def get_aggregated_stats():
    """Рассчитывает суммарную статистику из базы данных серверов"""
    with sqlite3.connect(SERVERS_DB) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*), COALESCE(SUM(accounts), 0) FROM servers")
        row = cursor.fetchone()
        return {"total_servers": row[0], "total_accounts": row[1]}

def get_all_servers_db():
    """Возвращает структурированные данные о всех серверах"""
    with sqlite3.connect(SERVERS_DB) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT server_address, accounts, usernames FROM servers")
        rows = cursor.fetchall()
        result = {}
        for row in rows:
            try:
                usernames = json.loads(row[2])
            except Exception:
                usernames = []
            result[row[0]] = {"accounts": row[1], "usernames": usernames}
        return result

# =======================================================================
#    ФОНОВЫЙ ТАСК ДЛЯ ОБРАБОТКИ ОЧЕРЕДИ ПАКЕТОВ JSON
# =======================================================================
PACKETS_FILE = "packets.json"

async def packets_file_watcher():
    """Периодически проверяет packets.json и рассылает новые пакеты в десктопный стрим"""
    print("[Watcher] Фоновый обработчик пакетов запущен.")
    while True:
        try:
            if os.path.exists(PACKETS_FILE):
                modified = False
                with open(PACKETS_FILE, "r", encoding="utf-8") as f:
                    try:
                        packets = json.load(f)
                    except Exception:
                        packets = []

                for packet in packets:
                    if not packet.get("completed", False):
                        await send_to_desktop(packet["username"], packet["text"])
                        packet["completed"] = True
                        modified = True

                if modified:
                    with open(PACKETS_FILE, "w", encoding="utf-8") as f:
                        json.dump(packets, f, indent=4, ensure_ascii=False)
        except Exception as e:
            print(f"[Watcher] Ошибка при проверке пакетов: {e}")
        
        await asyncio.sleep(1.0)

# =======================================================================
#    ИНИЦИАЛИЗАЦИЯ ПРИЛОЖЕНИЯ И LIFESPAN (ИНТЕГРАЦИЯ ТГ БОТА)
# =======================================================================
@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    init_plugin_db()
    init_servers_db()
    seed_licenses()
    for sub in ["avatars", "media", "temp", "voices", "circles"]:
        os.makedirs(os.path.join(settings.UPLOAD_DIR, sub), exist_ok=True)
    os.makedirs(settings.FILES_DIR, exist_ok=True)
    
    print("[EmergencyBot] Запуск Telegram-бота внутри lifespan...")
    bot_task = None
    watcher_task = None
    
    try:
        from emergency_bot import bot, dp, router
        dp.include_router(router)
        await bot.delete_webhook(drop_pending_updates=True)
        bot_task = asyncio.create_task(dp.start_polling(bot))
        print("[Emergency Bot] Бот успешно запущен и слушает обновления.")
    except Exception as e:
        print(f"[Emergency Bot] КРИТИЧЕСКАЯ ОШИБКА старта бота: {e}")

    watcher_task = asyncio.create_task(packets_file_watcher())

    yield
    
    print("[Lifespan] Завершение работы приложения и остановка задач...")
    
    if watcher_task:
        watcher_task.cancel()
        try:
            await watcher_task
        except asyncio.CancelledError:
            pass
        
    if bot_task:
        print("[Emergency Bot] Остановка Telegram-бота...")
        try:
            from emergency_bot import bot, dp
            await dp.stop_polling()
            await bot.session.close()
            print("[Emergency Bot] Сессии бота успешно закрыты.")
        except Exception as e:
            print(f"[Emergency Bot] Ошибка при закрытии сессий бота: {e}")
        
        bot_task.cancel()
        try:
            await bot_task
        except asyncio.CancelledError:
            print("[Emergency Bot] Асинхронная задача бота успешно аннулирована.")

class AdminReplyPayload(BaseModel):
    client_ip: str
    text: str

class GenerateLicensePayload(BaseModel):
    duration_days: int = 30
    custom_key: str | None = None
    bound_address: str = ""

app = FastAPI(
    title="Messenger & License API",
    description="Encrypted async messenger & Plugin Management System v3.0",
    version="3.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware, 
    allow_origins=["*"],
    allow_credentials=True, 
    allow_methods=["*"], 
    allow_headers=["*"]
)

app.include_router(bot_api_router)
@app.post("/decocraft")
async def create_decocraft_application(payload: DecoCraftAppPayload):
    # Превращаем заявку в словарь и добавляем пометку action_type
    app_data = payload.model_dump()
    app_data["action_type"] = "new_application" # Тип действия: новая заявка
    
    decocraft_queue.append(app_data)
    return {"status": "success", "message": "Заявка успешно принята"}


@app.post("/decocraft/get")
async def fetch_new_decocraft_tasks(payload: DecoCraftGetPayload):
    # Проверка секретного ключа плагина
    if payload.secret_key != "deco9ercraftbest":
        raise HTTPException(status_code=403, detail="Forbidden")
    
    # Забираем все накопившиеся задачи (и заявки, и донаты)
    current_tasks = list(decocraft_queue)
    
    # Очищаем очередь на бэкенде
    decocraft_queue.clear()
    
    # Возвращаем плагину список задач для выполнения
    return {"status": "success", "tasks": current_tasks}
    
@app.post("/api/createinvoice")
async def create_invoice(payload: CreateInvoicePayload):
    if not payload.name or not payload.group:
        raise HTTPException(status_code=400, detail="Укажите имя и группу")
        
    group_lower = payload.group.lower()
    if group_lower not in TIERS:
        raise HTTPException(status_code=400, detail="Неверная группа доната")
        
    tier_info = TIERS[group_lower]
    amount = tier_info["price"]
    
    # Генерируем уникальный label для ЮMoney: deco_web_Ник_Группа_Таймстемп
    label = f"deco_web_{payload.name}_{group_lower}_{int(time.time())}"
    
    # Формируем URL для оплаты QuickPay
    params = {
        "receiver": YOOMONEY_WALLET,
        "quickpay-form": "donate",
        "targets": f"Префикс {tier_info['name']} на DecoCraft",
        "paymentType": "AC",
        "sum": amount,
        "label": label
    }
    payment_url = "https://yoomoney.ru/quickpay/confirm.xml?" + urllib.parse.urlencode(params)
    
    # Сохраняем инвойс со статусом PENDING
    invoices[label] = {
        "invoice_id": label,
        "name": payload.name,
        "group": payload.group,
        "amount": amount,
        "status": "PENDING"
    }
    
    return {
        "status": "success",
        "invoice_id": label,
        "amount": amount,
        "payment_url": payment_url
    }


@app.post("/api/checkinvoice")
async def check_invoice(payload: CheckInvoicePayload):
    invoice = invoices.get(payload.invoice_id)
    if not invoice:
        raise HTTPException(status_code=404, detail="Счет не найден")
        
    # Если еще не оплачено, проверяем API ЮMoney
    if invoice["status"] != "PAID":
        try:
            async with httpx.AsyncClient() as client:
                headers = {
                    "Authorization": f"Bearer {YOOMONEY_TOKEN}",
                    "Content-Type": "application/x-www-form-urlencoded"
                }
                data = {"label": invoice["invoice_id"]}
                resp = await client.post(
                    "https://yoomoney.ru/api/operation-history",
                    headers=headers,
                    data=data,
                    timeout=10.0
                )
                
                if resp.status_code == 200:
                    resp_json = resp.json()
                    operations = resp_json.get("operations", [])
                    
                    # ЮMoney берет комиссию, ожидаем хотя бы 80% от суммы
                    expected_min = invoice["amount"] * 0.8
                    
                    for op in operations:
                        direction = op.get("direction", "unknown")
                        status = op.get("status", "unknown")
                        amount = float(op.get("amount", 0.0))
                        op_label = op.get("label", "")
                        
                        is_income = direction in ("in", "income")
                        is_ok = status == "success"
                        enough_money = amount >= expected_min
                        label_matches = op_label == invoice["invoice_id"]
                        
                        if is_income and is_ok and enough_money and label_matches:
                            invoice["status"] = "PAID"
                            break
        except Exception as e:
            print(f"[YooMoney Check Error] {e}")
    
    # Если платеж успешно прошел и мы еще НЕ отправляли эту команду в плагин
    if invoice["status"] == "PAID" and not invoice.get("delivered_to_plugin", False):
        
        # Бэкенд сам создает задачу для плагина!
        plugin_command = {
            "action_type": "give_prefix",  # Тип действия: выдача префикса
            "nick": invoice["name"],       # Ник игрока
            "group": invoice["group"],     # Группа/Префикс
            "invoice_id": invoice["invoice_id"]
        }
        
        # Кидаем команду в очередь, которую слушает плагин
        decocraft_queue.append(plugin_command)
        
        # Помечаем, что команда отправлена в очередь, чтобы избежать дублей при повторных проверках
        invoice["delivered_to_plugin"] = True
    
    return {
        "status": "success",
        "invoice_id": invoice["invoice_id"],
        "payment_status": invoice["status"],
        "name": invoice["name"],
        "group": invoice["group"]
    }


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await ws_endpoint(websocket)

# =======================================================================
#    АВТОРИЗАЦИЯ АДМИНИСТРАТОРА
# =======================================================================
ADMIN_KEY = os.getenv("ADMIN_KEY", "SECRET_ADMIN_KEY_1234")

async def verify_admin_key(x_admin_key: str | None = Header(None, alias="X-Admin-Key")):
    if not x_admin_key or x_admin_key != ADMIN_KEY:
        raise HTTPException(status_code=401, detail="Unauthorized: Invalid admin key")

def generate_random_key() -> str:
    parts = ["".join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(4)) for _ in range(4)]
    return "UL-KEY-" + "-".join(parts)

# =======================================================================
#    СИСТЕМА ЛИЦЕНЗИРОВАНИЯ И ПОДДЕРЖКИ
# =======================================================================
XOR_KEY = 0x77
active_plugin_connections = set()  
active_support_connections = {}    

def xor_crypt(data: bytes, key: int = XOR_KEY) -> bytes:
    return bytes([b ^ key for b in data])

@app.websocket("/ws/gateway")
async def unified_gateway(websocket: WebSocket):
    await websocket.accept()
    active_plugin_connections.add(websocket)
    current_server_address = None

    try:
        while True:
            encrypted_bytes = await websocket.receive_bytes()
            decrypted_str = xor_crypt(encrypted_bytes).decode("utf-8")
            packet = json.loads(decrypted_str)
            
            packet_type = packet.get("type")
            packet_data = packet.get("data", {})

            if packet_type == "license_check":
                license_key = packet_data.get("licenseKey", "")
                server_address = packet_data.get("serverAddress", "unknown")
                total_accounts = packet_data.get("totalAccounts", 0)
                usernames = packet_data.get("usernames", [])

                status = "invalid"
                lic_data = get_license(license_key)
                
                if lic_data:
                    try:
                        expires_at = datetime.datetime.strptime(lic_data["expires_at"], "%Y-%m-%d %H:%M:%S").replace(tzinfo=datetime.timezone.utc)
                    except Exception:
                        expires_at = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(seconds=1)

                    now = datetime.datetime.now(datetime.timezone.utc)
                    if now > expires_at:
                        status = "expired"
                    else:
                        bound_address = lic_data["bound_address"]
                        if not bound_address or bound_address.strip() == "":
                            update_license_binding(license_key, server_address)
                            bound_address = server_address
                            print(f"[Licence] Ключ {license_key} успешно привязан к адресу {server_address}")

                        if bound_address == server_address:
                            status = "valid"
                            current_server_address = server_address
                            upsert_server_stats(server_address, total_accounts, usernames)

                sign_payload = f"status:{status}|address:{server_address}"
                signature = sign_data(sign_payload)

                options_response = {
                    "type": "license_response", 
                    "data": {
                        "status": status,
                        "signature": signature
                    }
                }
                await websocket.send_bytes(xor_crypt(json.dumps(options_response).encode("utf-8")))

            elif packet_type == "ping":
                options_response = {"type": "pong", "data": {}}
                await websocket.send_bytes(xor_crypt(json.dumps(options_response).encode("utf-8")))

    except WebSocketDisconnect:
        if websocket in active_plugin_connections:
            active_plugin_connections.remove(websocket)
        print(f"[Licence] Игровой сервер {current_server_address or 'Unknown'} разорвал соединение.")

@app.websocket("/ws/support")
async def support_chat_gateway(websocket: WebSocket):
    await websocket.accept()
    client_ip = websocket.client.host
    active_support_connections[client_ip] = websocket

    history = get_support_history(client_ip)
    for msg in history:
        await websocket.send_json({"text": msg["text"], "sender": msg["sender"]})

    try:
        while True:
            data = await websocket.receive_json()
            message_text = data.get("text", "").strip()
            if message_text:
                save_support_message(client_ip, message_text, "user")
                print(f"[Support Чат] Пользователь [{client_ip}]: {message_text}")
    except WebSocketDisconnect:
        if client_ip in active_support_connections:
            del active_support_connections[client_ip]
        print(f"[Support Чат] Пользователь {client_ip} отключился.")

@app.get("/api/admin/chats", dependencies=[Depends(verify_admin_key)])
async def get_all_chats():
    chats_list = []
    ips = get_all_chat_ips()
    for ip in ips:
        history = get_support_history(ip)
        chats_list.append({
            "ip": ip,
            "is_online": ip in active_support_connections,
            "last_message": history[-1]["text"] if history else "",
            "history": history
        })
    return chats_list

@app.post("/api/admin/reply", dependencies=[Depends(verify_admin_key)])
async def send_admin_reply(payload: AdminReplyPayload):
    ip = payload.client_ip
    text = payload.text.strip()

    if not text:
        return JSONResponse(status_code=400, content={"message": "Пустой текст"})

    save_support_message(ip, text, "support")

    if ip in active_support_connections:
        user_ws = active_support_connections[ip]
        try:
            await user_ws.send_json({"text": text, "sender": "support"})
            return {"status": "success", "info": "Отправлено пользователю в онлайн"}
        except Exception as e:
            return {"status": "error", "info": f"Не удалось доставить: {str(e)}"}
            
    return {"status": "saved", "info": "Пользователь оффлайн. Сообщение сохранено в историю."}

@app.get("/api/admin/licenses", dependencies=[Depends(verify_admin_key)])
async def list_licenses():
    return get_all_licenses()

@app.post("/api/admin/licenses/generate", dependencies=[Depends(verify_admin_key)])
async def generate_license(payload: GenerateLicensePayload):
    key = payload.custom_key.strip() if payload.custom_key else generate_random_key()
    
    if get_license(key):
        return JSONResponse(status_code=400, content={"message": "Ключ уже существует в базе данных."})
    
    if payload.duration_days < 0:
        expires_at_dt = datetime.datetime(2099, 12, 31, 23, 59, 59, tzinfo=datetime.timezone.utc)
    else:
        expires_at_dt = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=payload.duration_days)
        
    expires_at_str = expires_at_dt.strftime("%Y-%m-%d %H:%M:%S")
    add_license_db(key, payload.bound_address, expires_at_str)
    
    return {
        "status": "success",
        "license": {
            "key": key,
            "bound_address": payload.bound_address,
            "expires_at": expires_at_str
        }
    }

@app.delete("/api/admin/licenses/{key}", dependencies=[Depends(verify_admin_key)])
async def delete_license(key: str):
    if not get_license(key):
        return JSONResponse(status_code=404, content={"message": "Лицензия не найдена"})
    delete_license_db(key)
    return {"status": "success", "message": f"Лицензия {key} была удалена."}

active_desktop_connections = set()

@app.websocket("/api/sanlsan")
async def sanlsan_emergency_gateway(websocket: WebSocket, token: str | None = None):
    EMERGENCY_TOKEN = "SANLSAN-API-KEY-7777"
    if token != EMERGENCY_TOKEN:
        await websocket.close(code=1008)
        return
        
    await websocket.accept()
    active_desktop_connections.add(websocket)
    print("[Emergency] Десктопный клиент Sanlsan успешно подключен по WSS.")
    
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        active_desktop_connections.remove(websocket)
        print("[Emergency] Десктопный клиент Sanlsan отключился.")

async def send_to_desktop(username: str, text: str):
    payload = json.dumps({
        "username": username,
        "text": text,
        "timestamp": datetime.datetime.now().strftime("%H:%M")
    }, ensure_ascii=False)
    
    for ws in list(active_desktop_connections):
        try:
            await ws.send_text(payload)
        except Exception:
            active_desktop_connections.remove(ws)

@app.get("/api/download-core", tags=["Plugin Core"])
async def download_core(request: Request, license_key: str = None, server_address: str = None):
    if not license_key:
        raise HTTPException(status_code=400, detail="Параметр license_key обязателен")

    lic_data = get_license(license_key)
    if not lic_data:
        raise HTTPException(status_code=403, detail="Лицензия не действительна")

    try:
        expires_at = datetime.datetime.strptime(lic_data["expires_at"], "%Y-%m-%d %H:%M:%S").replace(tzinfo=datetime.timezone.utc)
    except Exception:
        expires_at = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(seconds=1)

    now = datetime.datetime.now(datetime.timezone.utc)
    if now > expires_at:
        raise HTTPException(status_code=403, detail="Лицензия не действительна")

    client_ip = server_address or request.client.host
    bound_address = lic_data.get("bound_address")

    if not bound_address or bound_address.strip() == "":
        update_license_binding(license_key, client_ip)
        bound_address = client_ip
        print(f"[Licence] Ключ {license_key} успешно привязан к адресу {client_ip} через HTTP")

    is_valid_address = (bound_address == client_ip) or (bound_address.split(":")[0] == client_ip)
    if not is_valid_address:
        raise HTTPException(status_code=403, detail="Лицензия привязана к другому адресу")

    core_path = "core.enc" 
    if not os.path.exists(core_path):
        raise HTTPException(status_code=404, detail="Файл ядра отсутствует на сервере.")

    return FileResponse(path=core_path, filename="core.enc", media_type="application/octet-stream") 

@app.get("/api/stats")
async def get_stats():
    stats = get_aggregated_stats()
    return {
        "total_servers": stats["total_servers"] + 5,
        "total_accounts": stats["total_accounts"],
        "online_servers": len(active_plugin_connections) 
    }

@app.get("/api/stats_extended_or_database")
async def get_extended_db():
    return get_all_servers_db()

# =======================================================================
#    РАЗДАЧА ОБЩЕДОСТУПНОЙ СТАТИКИ И МЕДИА (АВАТАРКИ И ПОСТЫ)
# =======================================================================
@app.get("/static/{file_path:path}", tags=["Static & Media"])
@app.get("/api/media/{file_path:path}", tags=["Static & Media"])
async def serve_media_files(file_path: str):
    # Очистка путей
    if file_path.startswith("media/media/"):
        file_path = file_path.replace("media/media/", "media/")
        
    full_path = os.path.join(settings.UPLOAD_DIR, file_path)

    # Обработка общедоступных файлов (например, аватарок пользователей/чатов или медиа постов)
    if file_path.startswith("avatars/") or file_path.startswith("posts/"):
        if os.path.exists(full_path):
            return FileResponse(full_path)

    raise HTTPException(status_code=404, detail="File not found")

# =======================================================================
#    СИСТЕМА АВТОРИЗАЦИИ И ИИ-ГЕНЕРАЦИИ ДЛЯ КОНСТРУКТОРА FLOWBUILDER
# =======================================================================
class TokenValidationRequest(BaseModel):
    token: str

class AIFlowRequest(BaseModel):
    token: str
    prompt: str

MISTRAL_API_KEYS = [
    "ydbvYyjwYxYgKsKqxJbGLugedWG1BCju",
    "DPdMuZFMS3pUQDKgVfM1LPvOA5KKD3OG"
]
MISTRAL_API_URL = "https://api.mistral.ai/v1/chat/completions"
MISTRAL_MODEL = "ministral-3b-latest"

async def check_nios_token(db, token: str) -> bool:
    """Проверяет токен сессии или токен бота NiosMess в базе данных"""
    if not token:
        return False
    from app.services.auth_svc import get_session_by_token, get_user_by_id
    from app.models.models import Bot
    
    try:
        session = await get_session_by_token(db, token)
        if session:
            user = await get_user_by_id(db, session.user_id)
            if user and user.is_active and not user.is_banned and not user.is_frozen:
                return True
    except Exception:
        pass

    try:
        r = await db.execute(select(Bot).where(Bot.token == token))
        bot = r.scalar_one_or_none()
        if bot:
            user = await get_user_by_id(db, bot.user_id)
            if user and user.is_active and not user.is_banned and not user.is_frozen:
                return True
    except Exception:
        pass

    return False

async def _call_mistral_direct(prompt: str) -> str:
    """Асинхронный HTTP запрос к API Mistral"""
    async with httpx.AsyncClient() as client:
        for key in MISTRAL_API_KEYS:
            headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
            payload = {
                "model": MISTRAL_MODEL,
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0.2
            }
            try:
                response = await client.post(MISTRAL_API_URL, json=payload, headers=headers, timeout=25.0)
                response.raise_for_status()
                data = response.json()
                return data["choices"][0]["message"]["content"].strip()
            except Exception as e:
                print(f"[Mistral Direct Error] {e}")
                continue
    raise ValueError("Все серверы ИИ сейчас перегружены. Попробуйте еще раз позже.")

@app.post("/api/validate-token")
async def validate_token_endpoint(payload: TokenValidationRequest):
    async with AsyncSessionLocal() as db:
        is_valid = await check_nios_token(db, payload.token)
        return {"valid": is_valid}

@app.post("/api/ai/generate-flow")
async def generate_flow_endpoint(payload: AIFlowRequest):
    async with AsyncSessionLocal() as db:
        is_valid = await check_nios_token(db, payload.token)
        if not is_valid:
            raise HTTPException(status_code=403, detail="Доступ запрещен. Требуется активная учетная запись NiosMess.")

    system_instruction = """CRITICAL EXECUTION RULES

YOU ARE NOT A CHAT ASSISTANT.
YOU ARE A FLOWBUILDER JSON GENERATOR.

Your only task is to create a valid NiosMess FlowBuilder Ultimate JSON configuration.

BROWSER USAGE RULES

* Use web_request action nodes ONLY when the user task explicitly requires:

  * API requests
  * HTTP requests
  * fetching external data
  * website integration
  * webhook calls

* NEVER add web_request nodes on your own.

* NEVER invent external requests.

* NEVER use web_request for simple chatbot logic.

* If external data is not required, build the flow without web_request nodes.

FLOW INTEGRITY RULES

ABSOLUTE REQUIREMENT:

Every generated flow must form a single connected graph.

Forbidden:

* orphan nodes
* isolated nodes
* disconnected branches
* unreachable nodes

MANDATORY START RULE

The first node must always be a trigger.

Example:

Trigger
→ Message
→ Action
→ Message

The trigger must NEVER remain unconnected.

Before output verify:

1. Trigger exists.
2. Trigger has at least one outgoing connection.
3. Every non-trigger node has an incoming connection.
4. Every node is reachable from a trigger.
5. Every connection references existing nodes.
6. Every branch eventually leads to a valid end node.

CONDITION RULES

Every condition must connect BOTH outputs:

true_out
false_out

Bad:

Condition
└─ true_out → Message

Good:

Condition
├─ true_out → Message
└─ false_out → Message

BUTTON RULES

For every button:

{
"id":"buy"
}

Connection must use:

"fromPort":"btn-buy"

Never use "out" for button clicks.

AUTO-REPAIR RULE

If any node becomes disconnected:

* reconnect it automatically
* never output disconnected nodes

FINAL VALIDATION

Before generating JSON perform:

Graph Reachability Check

Starting from every trigger:

* traverse all connections

If any node is not visited:

* regenerate connections

Only output JSON when all nodes are reachable.

OUTPUT RULE

Return ONLY:

{
"nodes":[...],
"connections":[...],
"panOffset":{"x":0,"y":0}
}

FEW-SHOT EXAMPLES

EXAMPLE 1

User Task:
Send "Hello" when flow starts.

Correct Output Structure:

Trigger(start)
→ Message("Hello")

Reasoning:

* Trigger exists.
* Trigger connected.
* No isolated nodes.

---

EXAMPLE 2

User Task:
Ask user if they want support.

Correct Flow:

Trigger(start)
→ Message(
text="Do you need support?",
buttons=[
{"id":"yes","text":"Yes"},
{"id":"no","text":"No"}
]
)

btn-yes
→ Message("Support will contact you")

btn-no
→ Message("Okay, have a nice day")

Important:

Button connections:

fromPort="btn-yes"
fromPort="btn-no"

NOT fromPort="out"

---

EXAMPLE 3

User Task:
Check variable vip.

Correct Flow:

Trigger(start)
→ Condition(
var_name="vip",
operator="==",
value="yes"
)

true_out
→ Message("Welcome VIP")

false_out
→ Message("Regular access")

Important:

Both branches connected.

---

EXAMPLE 4

User Task:
Set variable username then greet.

Correct Flow:

Trigger(start)
→ Action(
action_type="set_var",
key="username",
value="John"
)

→ Message(
text="Hello %username%"
)

---

EXAMPLE 5

User Task:
Fetch weather from API.

Correct Flow:

Trigger(start)
→ Action(
action_type="web_request",
url="https://api.example.com/weather",
save_key="weather"
)

→ Message(
text="Weather: %weather%"
)

Important:

web_request allowed because user requested external data.

---

EXAMPLE 6

User Task:
Simple greeting bot.

BAD:

Trigger(start)

Message("Hello")

The trigger is disconnected.

NEVER DO THIS.

GOOD:

Trigger(start)
→ Message("Hello")

---

EXAMPLE 7

User Task:
Choose language.

Trigger(start)
→ Message(
text="Choose language",
buttons=[
{"id":"ru","text":"Русский"},
{"id":"en","text":"English"}
]
)

btn-ru
→ Action(set_var language=ru)
→ Message("Привет")

btn-en
→ Action(set_var language=en)
→ Message("Hello")

---

EXAMPLE 8

User Task:
Check age.

Trigger(start)
→ Condition(age > 18)

true_out
→ Message("Adult")

false_out
→ Message("Minor")

BAD:

Trigger
→ Condition

true_out
→ Message("Adult")

Condition false_out not connected.

NEVER DO THIS.

---

FINAL EXAMPLE OF VALID GRAPH

Trigger
→ Message
→ Condition

Condition.true_out
→ Action
→ Message

Condition.false_out
→ Message

All nodes reachable.
No isolated nodes.
No orphan nodes.
No missing connections.
No explanations.
No markdown.
No comments.
No analysis.
Only valid JSON.
"""
    try:
        raw_response = await _call_mistral_direct(system_instruction)
        
        # Очистка markdown блоков (если модель случайно их добавила)
        sanitized = raw_response.strip()
        if sanitized.startswith("```"):
            lines = sanitized.splitlines()
            if lines[0].startswith("```"):
                lines = lines[1:]
            if lines[-1].strip() == "```":
                lines = lines[:-1]
            sanitized = "\n".join(lines).strip()

        # Валидируем JSON на сервере
        parsed_flow = json.loads(sanitized)
        return {"status": "success", "flow": parsed_flow}
    except json.JSONDecodeError:
        # Резервная попытка парсинга через регулярные выражения
        import re
        match = re.search(r"\{.*\}", raw_response, re.DOTALL)
        if match:
            try:
                parsed_flow = json.loads(match.group(0))
                return {"status": "success", "flow": parsed_flow}
            except Exception:
                pass
        raise HTTPException(status_code=500, detail="Ошибка синтаксиса: ИИ вернул некорректный формат JSON. Попробуйте еще раз.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка генерации сценария: {str(e)}")

# =======================================================================
#    ОБРАБОТКА МАРШРУТОВ SPA 
# =======================================================================
@app.get("/", include_in_schema=False)
async def serve_index():
    index = os.path.join(settings.FILES_DIR, "index.html")
    if os.path.exists(index):
        return FileResponse(index)
    return JSONResponse({"message": "Messenger API v3.0", "docs": "WebSocket only"})

@app.get("/ul", include_in_schema=False)
@app.get("/UL", include_in_schema=False)
async def serve_site():
    index = os.path.join(settings.FILES_DIR, "site.html")
    if os.path.exists(index):
        return FileResponse(index)
    return JSONResponse({"message": "error"})

@app.get("/cr", include_in_schema=False)
@app.get("/constructor", include_in_schema=False)
async def serve_site():
    index = os.path.join(settings.FILES_DIR, "constructor.html")
    if os.path.exists(index):
        return FileResponse(index)
    return JSONResponse({"message": "error"})
@app.get("/nioscraft", include_in_schema=False)
async def serve_site():
    index = os.path.join(settings.FILES_DIR, "nioscraft.html")
    if os.path.exists(index):
        return FileResponse(index)
    return JSONResponse({"message": "error"})
@app.get("/WEB", include_in_schema=False)
@app.get("/web", include_in_schema=False)
async def serve_site():
    index = os.path.join(settings.FILES_DIR, "index.html")
    if os.path.exists(index):
        return FileResponse(index)
    return JSONResponse({"message": "error"})
@app.get("/apk", include_in_schema=False)
async def serve_site():
    index = os.path.join(settings.FILES_DIR, "niosmess.apk")
    if os.path.exists(index):
        return FileResponse(index)
    return JSONResponse({"message": "error"})
@app.get("/avatar", include_in_schema=False)
async def serve_site():
    index = os.path.join(settings.FILES_DIR, "niosmess.png")
    if os.path.exists(index):
        return FileResponse(index)
    return JSONResponse({"message": "error"})
@app.get("/exe", include_in_schema=False)
async def serve_site():
    index = os.path.join(settings.FILES_DIR, "niosmess.exe")
    if os.path.exists(index):
        return FileResponse(index)
    return JSONResponse({"message": "error"})
# Универсальный обработчик SPA (ДОЛЖЕН БЫТЬ В САМОМ НИЗУ)
@app.get("/{full_path:path}", include_in_schema=False)
async def serve_spa(full_path: str):
    if full_path.startswith("static/"):
        return JSONResponse({"message": "Not found"})
    filepath = os.path.join(settings.FILES_DIR, full_path)
    if os.path.isfile(filepath):
        return FileResponse(filepath)
    index = os.path.join(settings.FILES_DIR, "index_dwn.html")
    if os.path.exists(index):
        return FileResponse(index)
    return JSONResponse({"message": "Messenger API v3.0", "docs": "WebSocket only"})

@app.exception_handler(Exception)
async def global_error(request: Request, exc: Exception):
    return JSONResponse(status_code=500, content={"detail": str(exc)})