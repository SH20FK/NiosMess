import sqlite3

import uvicorn

import uuid

import datetime

import time
import re
import base64
from urllib.parse import urlparse

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

        c.execute("""CREATE TABLE IF NOT EXISTS avatars (
            username TEXT PRIMARY KEY,
            filename TEXT,
            updated_at REAL
        )""")
        
        c.execute("""CREATE TABLE IF NOT EXISTS reactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chat_id TEXT,
            message_id INTEGER,
            username TEXT,
            emoji TEXT,
            updated_at REAL
        )""")
        c.execute("""CREATE TABLE IF NOT EXISTS badges (
            id TEXT PRIMARY KEY,
            title TEXT,
            description TEXT,
            icon TEXT,
            created_at REAL
        )""")

        c.execute("""CREATE TABLE IF NOT EXISTS user_badges (
            username TEXT PRIMARY KEY,
            badge_id TEXT,
            assigned_at REAL
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
        add_col("users", "verified", "INTEGER DEFAULT 0")
        add_col("users", "about", "TEXT DEFAULT ''")
        add_col("users", "social", "INTEGER")
        conn.commit()
        conn.close()
    logger.info("База данных успешно обновлена. Ошибок с колонками быть не должно.")

init_db()



def format_last_seen(ts: float | None) -> str:
    if not ts or ts == 0:
        return "давно не в сети"
    
    now = time.time()
    try:
        ts = float(ts)
    except:
        return "неизвестно"
        
    delta = max(0, now - ts)
    
    if delta < 60:
        return "в сети"
    if delta < 3600:
        mins = int(delta // 60)
        return f"был(а) {mins} мин. назад"
    if delta < 86400:
        hours = int(delta // 3600)
        return f"был(а) {hours} ч. назад"
        
    # ИСПРАВЛЕНО: Вместо переменной byl_a пишем текст напрямую
    date_str = datetime.datetime.fromtimestamp(ts).strftime('%d.%m.%Y %H:%M')
    return f"был(а) {date_str}"
def verify_token(owner: str, token: str) -> bool:
    return is_valid_session(token, owner)


BADGE_DEFAULT_TEXT = "Этот человек является разработчиком или спонсором NiosMessa"


def get_user_badge(conn, username: str):
    row = conn.execute(
        """
        SELECT b.id, b.title, b.description, b.icon
        FROM user_badges ub
        JOIN badges b ON b.id = ub.badge_id
        WHERE ub.username = ?
        """
        , (username,)
    ).fetchone()
    if not row:
        return None
    return {
        "badge_id": row[0],
        "badge_title": row[1],
        "badge_text": row[2],
        "badge_icon": row[3],
    }




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
                now = time.time()
                conn.execute("UPDATE sessions SET last_activity=? WHERE token=?", (now, token))
                conn.execute("UPDATE users SET last_seen=? WHERE username=?", (now, username))
                conn.commit()
                return True

            return False

        finally:

            conn.close()


            
            
            
            
            
            
            
            
            
AVATAR_DIR = "avatars"
ALLOWED_EXT = {"png", "jpg", "jpeg"}

os.makedirs(AVATAR_DIR, exist_ok=True)

@app.post("/set_av")
async def set_avatar(
    token: str = Form(...),
    username: str = Form(...),
    file: UploadFile = File(...)
):
    if not is_valid_session(token, username):
        raise HTTPException(status_code=401, detail="Invalid session")

    ext = file.filename.split(".")[-1].lower()
    if ext not in ALLOWED_EXT:
        raise HTTPException(status_code=400, detail="Only png/jpg/jpeg allowed")

    filename = f"{username}_{uuid.uuid4().hex}.{ext}"
    path = os.path.join(AVATAR_DIR, filename)

    with open(path, "wb") as f:
        f.write(await file.read())

    with db_lock:
        conn = get_db()
        conn.execute("""
            INSERT INTO avatars (username, filename, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(username) DO UPDATE SET
                filename=excluded.filename,
                updated_at=excluded.updated_at
        """, (username, filename, time.time()))
        conn.commit()
        conn.close()

    return {"status": "ok", "avatar": filename}
            
from fastapi.responses import FileResponse

DEFAULT_AVATAR = "avatars/default.png"

@app.post("/get_av")
async def get_avatar(other: str = Form(...)):
    with db_lock:
        conn = get_db()
        row = conn.execute(
            "SELECT filename FROM avatars WHERE username=?",
            (other,)
        ).fetchone()
        conn.close()

    if row:
        path = os.path.join(AVATAR_DIR, row[0])
        if os.path.exists(path):
            return FileResponse(path)

    return FileResponse(DEFAULT_AVATAR)     
            
            
            
            
            
            
            
active_connections: Dict[str, List[WebSocket]] = {}

from fastapi import WebSocket, WebSocketDisconnect
import os
import uuid
import time

UPLOAD_DIR = "uploads"
MAX_FILE_SIZE = 50 * 1024 * 1024  # 50 MB

os.makedirs(UPLOAD_DIR, exist_ok=True)
active_connections = {}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, token: str, username: str):
    # --- Проверка сессии ---
    if not is_valid_session(token, username):
        await websocket.close(code=1008)
        return

    await websocket.accept()
    if username not in active_connections:
        active_connections[username] = []
    active_connections[username].append(websocket)

    try:
        while True:
            data = await websocket.receive_json()

            # --- 1. typing уведомление ---
            if data.get("type") == "typing":
                recipient = data.get("receiver")
                if recipient in active_connections:
                    for conn in active_connections[recipient]:
                        await conn.send_json({
                            "type": "typing",
                            "sender": username
                        })

            # --- 2. upload файла ---
            elif data.get("type") == "file_start":
                filename = data.get("filename")
                safe_filename = f"{uuid.uuid4().hex}{os.path.splitext(filename)[1]}"
                file_path = os.path.join(UPLOAD_DIR, safe_filename)

                websocket.current_file = {
                    "path": file_path,
                    "size": 0,
                    "safe_name": safe_filename
                }

                await websocket.send_json({
                    "type": "file_ready",
                    "filename": safe_filename
                })

            elif data.get("type") == "file_chunk":
                file_info = getattr(websocket, "current_file", None)
                if not file_info:
                    await websocket.send_json({
                        "type": "error",
                        "message": "No file initialized"
                    })
                    continue

                chunk_b64 = data.get("chunk")
                chunk_bytes = base64.b64decode(chunk_b64)

                new_size = file_info["size"] + len(chunk_bytes)
                if new_size > MAX_FILE_SIZE:
                    await websocket.send_json({
                        "type": "error",
                        "message": "File too large"
                    })
                    os.remove(file_info["path"])
                    del websocket.current_file
                    continue

                with open(file_info["path"], "ab") as f:
                    f.write(chunk_bytes)

                file_info["size"] = new_size

            elif data.get("type") == "file_end":
                file_info = getattr(websocket, "current_file", None)
                if file_info:
                    await websocket.send_json({
                        "type": "file_saved",
                        "filename": file_info["safe_name"],
                        "size": file_info["size"]
                    })
                    del websocket.current_file

            # --- 3. download файла ---
            elif data.get("type") == "download_start":
                filename = data.get("filename")
                safe_name = os.path.basename(filename)
                path = os.path.join(UPLOAD_DIR, safe_name)

                if not os.path.exists(path):
                    await websocket.send_json({
                        "type": "error",
                        "message": "File not found"
                    })
                    continue

                # читаем файл чанками
                with open(path, "rb") as f:
                    while chunk := f.read(1024 * 1024):  # 1MB
                        await websocket.send_json({
                            "type": "file_chunk",
                            "chunk": base64.b64encode(chunk).decode()
                        })
                await websocket.send_json({
                    "type": "download_end",
                    "filename": safe_name
                })

    except WebSocketDisconnect:
        if websocket in active_connections.get(username, []):
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
async def create_poll(token: str = Form(...), username: str = Form(...), chat_id: str = Form(...), question: str = Form(...), options: str = Form(...), multiple: bool = Form(False)):
    if not is_valid_session(token, username): raise HTTPException(401)
    poll_id = str(uuid.uuid4())
    with db_lock:
        conn = get_db()
        conn.execute("INSERT INTO polls (id, question, options, results, multiple) VALUES (?,?,?,?,?)", 
                     (poll_id, question, options, json.dumps([0]*len(json.loads(options))), 1 if multiple else 0))
        conn.commit()
    return {"status": "ok", "poll_id": poll_id}

@app.post("/polls/vote")
async def vote_poll(request: Request):
    """M11: Голосование в опросе - поддержка одиночного и множественного выбора"""
    data = await request.json()
    token = data.get("token")
    username = data.get("username")
    poll_id = data.get("poll_id")
    option_ids = data.get("option_ids", [])
    
    if not is_valid_session(token, username): 
        raise HTTPException(401, "Unauthorized")
    
    # Нормализуем option_ids в список индексов
    if isinstance(option_ids, int):
        option_indices = [option_ids]
    elif isinstance(option_ids, list):
        option_indices = [int(x) for x in option_ids if isinstance(x, (int, str)) and str(x).isdigit()]
    else:
        option_indices = []
    
    with db_lock:
        conn = get_db()
        poll = conn.execute("SELECT * FROM polls WHERE id=?", (poll_id,)).fetchone()
        if not poll:
            raise HTTPException(404, "Poll not found")
        
        results = json.loads(poll['results'])
        
        # Удаляем все старые голоса пользователя
        old_votes = conn.execute(
            "SELECT option_index FROM poll_votes WHERE poll_id=? AND username=?", 
            (poll_id, username)
        ).fetchall()
        
        for old_vote in old_votes:
            old_index = old_vote['option_index']
            if 0 <= old_index < len(results):
                results[old_index] = max(0, results[old_index] - 1)
        
        conn.execute("DELETE FROM poll_votes WHERE poll_id=? AND username=?", (poll_id, username))
        
        # Добавляем новые голоса
        for option_index in option_indices:
            if 0 <= option_index < len(results):
                conn.execute(
                    "INSERT INTO poll_votes (poll_id, username, option_index, voted_at) VALUES (?, ?, ?, ?)",
                    (poll_id, username, option_index, time.time())
                )
                results[option_index] = results[option_index] + 1
        
        conn.execute("UPDATE polls SET results=? WHERE id=?", (json.dumps(results), poll_id))
        conn.commit()
        
        # Получаем актуальные голоса пользователя
        my_votes = [r['option_index'] for r in conn.execute(
            "SELECT option_index FROM poll_votes WHERE poll_id=? AND username=?", 
            (poll_id, username)
        ).fetchall()]
        
        total = sum(results)
        conn.close()
        
    return {"status": "ok", "counts": results, "my_votes": my_votes, "total": total}


@app.get("/polls/{poll_id}")
async def get_poll(poll_id: str, username: str, token: str):
    """M11: Получение информации об опросе"""
    if not is_valid_session(token, username): raise HTTPException(401)
    with db_lock:
        conn = get_db()
        poll = conn.execute("SELECT * FROM polls WHERE id=?", (poll_id,)).fetchone()
        if not poll:
            raise HTTPException(404, "Poll not found")
        
        results = json.loads(poll['results'])
        options = json.loads(poll['options'])
        
        my_votes = [r['option_index'] for r in conn.execute(
            "SELECT option_index FROM poll_votes WHERE poll_id=? AND username=?", 
            (poll_id, username)
        ).fetchall()]
        
        total = sum(results)
        conn.close()
        
    return {
        "id": poll_id,
        "question": poll['question'],
        "options": [{"id": i, "text": opt} for i, opt in enumerate(options)],
        "multiple": bool(poll['multiple']),
        "counts": results,
        "my_votes": my_votes,
        "total": total
    }

@app.get("/messages/scheduled")
async def get_scheduled_messages(username: str, token: str, chat_id: str = None):
    """M09: Получение списка запланированных сообщений"""
    if not is_valid_session(token, username): raise HTTPException(401)
    with db_lock:
        conn = get_db()
        if chat_id:
            rows = conn.execute(
                "SELECT * FROM scheduled_messages WHERE sender=? AND chat_id=? ORDER BY send_at ASC",
                (username, chat_id)
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM scheduled_messages WHERE sender=? ORDER BY send_at ASC",
                (username,)
            ).fetchall()
        conn.close()
        
    return {
        "status": "ok",
        "scheduled": [dict(r) for r in rows]
    }

@app.post("/messages/scheduled/cancel")
async def cancel_scheduled_message(token: str = Form(...), username: str = Form(...), schedule_id: int = Form(...)):
    """M09: Отмена запланированного сообщения"""
    if not is_valid_session(token, username): raise HTTPException(401)
    with db_lock:
        conn = get_db()
        # Проверяем, что сообщение принадлежит пользователю
        msg = conn.execute(
            "SELECT * FROM scheduled_messages WHERE id=? AND sender=?", 
            (schedule_id, username)
        ).fetchone()
        if not msg:
            conn.close()
            raise HTTPException(404, "Scheduled message not found")
        
        conn.execute("DELETE FROM scheduled_messages WHERE id=?", (schedule_id,))
        conn.commit()
        conn.close()
        
    return {"status": "ok", "cancelled_id": schedule_id}

@app.post("/forward_message")
async def forward_message(
    token: str = Form(...),
    username: str = Form(...),
    chat_id: str = Form(...),
    chat_type: str = Form(...),
    forward_from: str = Form(...),
    forward_message_id: int = Form(...),
    forward_chat_type: str = Form(None)
):
    """M06: Пересылка сообщения с метаданными"""
    if not is_valid_session(token, username): raise HTTPException(401)
    
    with db_lock:
        conn = get_db()
        
        # Получаем исходное сообщение
        if forward_chat_type in ['group', 'channel']:
            source_msg = conn.execute(
                "SELECT * FROM group_messages WHERE id=? AND chat_id=?", 
                (forward_message_id, forward_from)
            ).fetchone()
        else:
            source_msg = conn.execute(
                "SELECT * FROM messages WHERE id=? AND (sender=? OR receiver=?)", 
                (forward_message_id, forward_from, forward_from)
            ).fetchone()
        
        if not source_msg:
            conn.close()
            raise HTTPException(404, "Source message not found")
        
        # Формируем текст с метаданными пересылки
        forward_text = f"Forwarded from {forward_from}:\n{source_msg['text']}"
        
        # Отправляем в целевой чат
        if chat_type in ['group', 'channel']:
            conn.execute(
                "INSERT INTO group_messages (chat_id, sender, text, time, reply_to, forward_from, forward_message_id) VALUES (?,?,?,?,?,?,?)",
                (chat_id, username, forward_text, str(time.time()), None, forward_from, forward_message_id)
            )
        else:
            conn.execute(
                "INSERT INTO messages (sender, receiver, text, time, reply_to, forward_from, forward_message_id) VALUES (?,?,?,?,?,?,?)",
                (username, chat_id, forward_text, str(time.time()), None, forward_from, forward_message_id)
            )
        
        conn.commit()
        conn.close()
        
    return {"status": "ok", "message": "Message forwarded"}

@app.get("/search_messages")
async def search_messages(
    chat_id: str, 
    q: str, 
    username: str, 
    token: str, 
    chat_type: str = None,
    limit: int = 50,
    offset: int = 0
):
    """M14: Поиск сообщений с пагинацией"""
    if not is_valid_session(token, username): raise HTTPException(401)
    
    table = "group_messages" if chat_type in ["group", "channel"] else "messages"
    
    with db_lock:
        conn = get_db()
        
        # Получаем общее количество результатов
        if chat_type in ["group", "channel"]:
            count_row = conn.execute(
                f"SELECT COUNT(*) as total FROM {table} WHERE chat_id=? AND text LIKE ?", 
                (chat_id, f"%{q}%")
            ).fetchone()
            results = conn.execute(
                f"SELECT * FROM {table} WHERE chat_id=? AND text LIKE ? ORDER BY id DESC LIMIT ? OFFSET ?", 
                (chat_id, f"%{q}%", limit, offset)
            ).fetchall()
        else:
            count_row = conn.execute(
                f"SELECT COUNT(*) as total FROM {table} WHERE ((sender=? AND receiver=?) OR (sender=? AND receiver=?)) AND text LIKE ?", 
                (username, chat_id, chat_id, username, f"%{q}%")
            ).fetchone()
            results = conn.execute(
                f"SELECT * FROM {table} WHERE ((sender=? AND receiver=?) OR (sender=? AND receiver=?)) AND text LIKE ? ORDER BY id DESC LIMIT ? OFFSET ?", 
                (username, chat_id, chat_id, username, f"%{q}%", limit, offset)
            ).fetchall()
        
        total = count_row['total'] if count_row else 0
        conn.close()
        
    return {
        "results": [dict(r) for r in results],
        "total": total,
        "has_more": (offset + len(results)) < total
    }




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


UPLOAD_DIR = "uploads"

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


# --- Новые endpoints для совместимости с frontend ---

@app.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    sender: str = Form(...),
    receiver: str = Form(...),
    token: str = Form(...),
    reply_to: str = Form(None),
    ttl_seconds: str = Form(None)
):
    """Endpoint для загрузки файлов (совместимость с frontend)"""
    if not is_valid_session(token, sender):
        raise HTTPException(status_code=401, detail="Invalid session")
    
    # Генерируем уникальное имя файла
    file_ext = os.path.splitext(file.filename)[1]
    safe_filename = f"{uuid.uuid4().hex}{file_ext}"
    file_path = os.path.join(UPLOAD_DIR, safe_filename)
    
    # Сохраняем файл
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    return {
        "status": "ok",
        "filename": safe_filename,
        "original_name": file.filename,
        "size": os.path.getsize(file_path)
    }


@app.get("/download/{file_name}")
async def download_file(
    file_name: str,
    token: str = None,
    username: str = None
):
    """Endpoint для скачивания файлов (совместимость с frontend)"""
    # Проверяем токен если передан
    if token and username:
        if not is_valid_session(token, username):
            raise HTTPException(status_code=401, detail="Invalid session")
    
    # Безопасное имя файла
    safe_name = os.path.basename(file_name)
    file_path = os.path.join(UPLOAD_DIR, safe_name)
    
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="File not found")
    
    return FileResponse(file_path, filename=safe_name)







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
BANNED_WORDS = ["чит", "cheat", "hack", "exploit", "crack", "bypass"]

def check_username_safe(username: str, name: str) -> bool:
    """
    Проверяет username и name на запрещённые слова.
    Возвращает True, если оба поля безопасны, False если есть нарушение.
    """
    combined = f"{username} {name or ''}".lower()
    for word in BANNED_WORDS:
        if word in combined:
            return False
    return True

@app.post("/register")
async def register(u: AuthModel):
    email_clean = u.email.lower().strip()


    if not u.username or not u.email or not u.password:
        raise HTTPException(status_code=400, detail="Заполните все поля")


    with db_lock:
        conn = get_db()
        existing = conn.execute(
            "SELECT email, username FROM users WHERE email=? OR username=?",
            (email_clean, u.username)
        ).fetchone()
        conn.close()

    if existing:
        if existing['email'] == email_clean:
            raise HTTPException(status_code=400, detail="Пользователь с таким Email уже есть")
        if existing['username'] == u.username:
            raise HTTPException(status_code=400, detail="Это имя пользователя уже занято")


    if u.code:
        saved = pending_regs.get(email_clean)
        if not saved or saved['code'] != u.code:
            raise HTTPException(status_code=400, detail="Неверный код подтверждения")

        data = saved['data']


        is_safe = check_username_safe(data.username, data.name)

        with db_lock:
            conn = get_db()
            try:
                conn.execute(
                    """INSERT INTO users 
                       (email, username, name, password, reg_date, last_seen, is_frozen, frozen_rule, verified) 
                       VALUES (?,?,?,?,?,?,?,?,?)""",
                    (
                        email_clean,
                        data.username,
                        data.name or data.username,
                        data.password,
                        datetime.datetime.now().strftime("%d.%m.%Y"),
                        time.time(),
                        0 if is_safe else 1, 
                        None if is_safe else "Нарушение п. 4.1.3 и 4.1.7 Условий использования (упоминание читов в имени или нике)",
                        1,
                    )
                )
                conn.commit()
                if email_clean in pending_regs:
                    del pending_regs[email_clean]
                logger.info(f"New user registered: {data.username}")
                return {
                    "status": "ok",
                    "message": "User created",
                    "frozen": not is_safe
                }
            finally:
                conn.close()


    gen_code = str(random.randint(100000, 999999))
    pending_regs[email_clean] = {"code": gen_code, "data": u}

    if send_email(u.email, gen_code):
        logger.info(f"Verification code sent to {u.email}")
        return {"status": "wait_code", "message": "Код отправлен на почту"}
    else:
        raise HTTPException(status_code=500, detail="Ошибка почтового сервера")


def check_username_safes(username: str, name: str) -> (bool, list):
    """
    Проверяет username и name на запрещённые слова.
    Возвращает кортеж: (True если безопасно, False если нарушение, список найденных слов)
    """
    combined = f"{username} {name or ''}".lower()
    found = [word for word in BANNED_WORDS if word in combined]
    return (len(found) == 0, found)
@app.post("/login")
async def login(request: Request, username: str = Form(...), password: str = Form(...)):
    with db_lock:
        conn = get_db()
        user = conn.execute("SELECT * FROM users WHERE username=?", (username,)).fetchone()

        if not user or user["password"] != password:
            if not user:
                raise HTTPException(404, detail="Account is invalid")
            raise HTTPException(401, detail="Invalid credentials")


        if not user["is_frozen"]:
            is_safe, found_words = check_username_safes(user["username"], user["name"])
            if not is_safe:
                frozen_reason = (
                    f"Нарушение п. 4.1.3 и 4.1.7 Условий использования: "
                    f"упоминание запрещённых слов в имени или нике: {', '.join(found_words)}"
                )

                conn.execute(
                    "UPDATE users SET is_frozen=1, frozen_rule=? WHERE id=?",
                    (frozen_reason, user["id"])
                )
                conn.commit()
                conn.close()
                raise HTTPException(401, detail=f"Account frozen: {frozen_reason}")

        if user["is_frozen"]:
            conn.close()
            raise HTTPException(401, detail=f"Account frozen: {user['frozen_rule']}")


        new_token = str(uuid.uuid4())
        ip = request.client.host
        ua = request.headers.get("user-agent", "Unknown Device")

        conn.execute(
            "INSERT INTO sessions (token, username, last_activity, device, ip) VALUES (?, ?, ?, ?, ?)",
            (new_token, username, time.time(), ua, ip)
        )
        conn.commit()
        conn.close()

        return {
            "status": "ok",
            "token": new_token,
            "username": username,
            "name": user["name"]
        }


    

    

    

    


mc_cache = {}





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




@app.post("/badges/create")
async def badges_create(request: Request):
    data = await request.json()
    root_token = data.get("root_token")
    badge_id = data.get("badge_id") or data.get("id")
    title = data.get("title") or badge_id
    description = data.get("description") or BADGE_DEFAULT_TEXT
    icon = data.get("icon") or "fox"
    if root_token != ROOT_TOKEN:
        raise HTTPException(status_code=401, detail="Unauthorized")
    if not badge_id:
        raise HTTPException(status_code=422, detail="Missing badge_id")
    with db_lock:
        conn = get_db()
        conn.execute("""
            INSERT INTO badges (id, title, description, icon, created_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                title=excluded.title,
                description=excluded.description,
                icon=excluded.icon
            """,
            (badge_id, title, description, icon, time.time()),
        )
        conn.commit()
        conn.close()
    return {"status": "ok", "badge_id": badge_id}


@app.post("/badges/assign")
async def badges_assign(request: Request):
    data = await request.json()
    root_token = data.get("root_token")
    username = data.get("username")
    badge_id = data.get("badge_id")
    if root_token != ROOT_TOKEN:
        raise HTTPException(status_code=401, detail="Unauthorized")
    if not username or not badge_id:
        raise HTTPException(status_code=422, detail="Missing fields")
    with db_lock:
        conn = get_db()
        badge = conn.execute("SELECT id FROM badges WHERE id=?", (badge_id,)).fetchone()
        if not badge:
            conn.close()
            raise HTTPException(status_code=404, detail="Badge not found")
        conn.execute("""
            INSERT INTO user_badges (username, badge_id, assigned_at)
            VALUES (?, ?, ?)
            ON CONFLICT(username) DO UPDATE SET
                badge_id=excluded.badge_id,
                assigned_at=excluded.assigned_at
            """,
            (username, badge_id, time.time()),
        )
        conn.commit()
        conn.close()
    return {"status": "ok"}


@app.post("/badges/remove")
async def badges_remove(request: Request):
    data = await request.json()
    root_token = data.get("root_token")
    username = data.get("username")
    if root_token != ROOT_TOKEN:
        raise HTTPException(status_code=401, detail="Unauthorized")
    if not username:
        raise HTTPException(status_code=422, detail="Missing username")
    with db_lock:
        conn = get_db()
        conn.execute("DELETE FROM user_badges WHERE username=?", (username,))
        conn.commit()
        conn.close()
    return {"status": "ok"}


@app.get("/get_user_info")
async def get_user_info(username: str, token: str, my_username: str):
    if not is_valid_session(token, my_username):
        raise HTTPException(status_code=401, detail="Invalid session")

    with db_lock:
        conn = get_db()
        row = conn.execute(
            """
              SELECT
                  name,
                  username,
                  email,
                  reg_date,
                  last_seen,
                  is_frozen,
                  verified,
                  about
            FROM users
            WHERE username=?
            """,
            (username,)
        ).fetchone()
        badge = get_user_badge(conn, username)
        conn.close()

    if row:
        res = dict(row)
        last_seen = row["last_seen"] or 0
        is_online = (time.time() - last_seen) < 60

        res["is_online"] = is_online
        res["isonline"] = is_online
        res["isfrozen"] = res.get("is_frozen")
        res["last_seen_ts"] = last_seen
        res["last_seen_text"] = format_last_seen(last_seen)

        if badge:
            res.update(badge)

        if "reg_date" in res and "regdate" not in res:
            res["regdate"] = res.get("reg_date")

        return res

    return {"error": "User not found"}

@app.post("/set_about")
async def set_about(
    token: str = Form(...),
    username: str = Form(...),
    about: str = Form(...)
):
    if not is_valid_session(token, username):
        raise HTTPException(status_code=401, detail="Invalid session")

    about = about.strip()

    if len(about) > 500:
        raise HTTPException(status_code=400, detail="About is too long")

    with db_lock:
        conn = get_db()
        conn.execute(
            "UPDATE users SET about = ? WHERE username = ?",
            (about, username)
        )
        conn.commit()
        conn.close()

    return {"status": "ok"}



from typing import Optional



@app.get("/get_chats")
async def get_chats(username: str | None = None, user: str | None = None, token: str = ""):
    username = username or user
    if not username:
        raise HTTPException(422, detail="Missing username")
    if not is_valid_session(token, username):
        raise HTTPException(401)

    with db_lock:
        conn = get_db()
        try:
            # -------- ЛИЧНЫЕ ЧАТЫ --------
            # Используем алиас "m" для messages, чтобы не было конфликта с b.id (badges)
            direct_rows = conn.execute("""
                SELECT
                    CASE
                        WHEN m.sender = :username THEN m.receiver
                        ELSE m.sender
                    END AS chat_id,
                    u.name AS name,
                    u.username AS username,
                    u.last_seen AS last_seen,
                    u.is_frozen AS is_frozen,
                    b.id AS badge_id,
                    b.title AS badge_title,
                    b.description AS badge_text,
                    b.icon AS badge_icon,
                    SUM(
                        CASE
                            WHEN m.receiver = :username AND m.is_read = 0 THEN 1
                            ELSE 0
                        END
                    ) AS unread_count,
                    MAX(m.id) AS last_message_id
                FROM messages m
                LEFT JOIN users u
                    ON u.username = CASE
                        WHEN m.sender = :username THEN m.receiver
                        ELSE m.sender
                    END
                LEFT JOIN user_badges ub ON ub.username = u.username
                LEFT JOIN badges b ON b.id = ub.badge_id
                WHERE m.sender = :username OR m.receiver = :username
                GROUP BY chat_id
                ORDER BY last_message_id DESC
            """, {"username": username}).fetchall()

            direct = []
            for row in direct_rows:
                ls_ts = row["last_seen"] or 0
                online_status = (time.time() - ls_ts) < 60
                
                direct.append({
                    "chat_id": row["chat_id"],
                    "name": row["name"] or row["chat_id"],
                    "type": "user",
                    "is_online": online_status,
                    "last_seen_ts": ls_ts,
                    "last_seen_text": format_last_seen(ls_ts),
                    "unread_count": row["unread_count"] or 0,
                    "badge_id": row["badge_id"],
                    "badge_title": row["badge_title"],
                    "badge_text": row["badge_text"],
                    "badge_icon": row["badge_icon"],
                })

            # -------- ГРУППЫ / КАНАЛЫ --------
            collective_rows = conn.execute("""
                SELECT c.id as chat_id, c.name, c.type, c.owner, m.last_read_id
                FROM collective_chats c
                JOIN chat_members m ON m.chat_id = c.id
                WHERE m.username = ?
                ORDER BY c.updated_at DESC
            """, (username,)).fetchall()

            collective = []
            for row in collective_rows:
                last_read = row["last_read_id"] or 0

                # Считаем непрочитанные в группе
                unread_res = conn.execute(
                    "SELECT COUNT(*) FROM group_messages WHERE chat_id=? AND id > ?",
                    (row["chat_id"], last_read),
                ).fetchone()
                
                unread_count = unread_res[0] if unread_res else 0

                collective.append({
                    "chat_id": row["chat_id"],
                    "name": row["name"],
                    "type": row["type"], # 'group' или 'channel'
                    "owner": row["owner"],
                    "unread_count": unread_count,
                })

            return {
                "status": "ok",
                "chats": direct + collective
            }
            
        except Exception as e:
            logger.error(f"Critical Error in get_chats: {e}")
            raise HTTPException(status_code=500, detail="Internal Server Error")
        finally:
            conn.close()

    
    
    
    
    
@app.post("/groups/create")
async def create_group(name: str = Form(...), owner: str = Form(...), token: str = Form(...)):

    if not is_valid_session(token, owner): 
        raise HTTPException(401, "Unauthorized")
    
    chat_id = f"group_{uuid.uuid4().hex[:8]}"
    now = str(time.time())
    
    with db_lock:
        conn = get_db()

        conn.execute(
            "INSERT INTO collective_chats (id, name, owner, type, created_at, updated_at) VALUES (?, ?, ?, 'group', ?, ?)", 
            (chat_id, name, owner, now, now)
        )

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

    # Системный промпт
    system_instructions = f"""
Ты — агент техподдержки мессенджера 'NiosMess'.
ДАННЫЕ ПОЛЬЗОВАТЕЛЯ:
Имя: {name}
Username: {username}
Статус | Причина: {frozen_info}
Твой тон: вежливый, четкий, отвечай одной строкой, максимально коротко.
База знаний для ответов:
Проблема: 'Когда релиз?' -> Ответ: Еще не известно, вы в beta версии, подождите.
Проблема: 'Нет чатов / пропали чаты' -> Ответ: Проверьте интернет, потяните список вниз. Возможно, аккаунт заморожен. Попробуйте обновить. ссылка: https://nioscraft.ru/niosmess.exe
Вопрос: 'Почему только 1 чат?' -> Ответ: Аккаунт заморожен или устаревшая версия. Обновите. ссылка: https://nioscraft.ru/niosmess.exe
Вопрос: 'За что заморозили аккаунт?' -> Ответ: Причина блокировки: {frozen_rule}. Для обжалования пишите нам.
Вопрос: 'Когда будут звонки/голосовые сообщения?' -> Ответ: Разрабатываем звонки и голосовые сообщения, 1 разработчик.
Общие баги: Если не описано выше, пришлите скриншот и модель устройства.
ПРАВИЛО: Не выдумывай функции, если не знаешь ответа — передай разработчикам.
ПРАВИЛО 2: Будь вежлив, если оскорбляют — предупреди, что передадим администрации.
ПРАВИЛО 3: Пиши одной строкой, без переносов.
ПРАВИЛО СМЕНЫ ИМЕНИ: Если пользователь просит сменить ник/имя, генерируй строго в формате: name:юзернейм:новый_ник. ".
"""

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
            elif "result" in data and len(data["result"]) > 0:
                ai_content = data["result"][0]["message"]["content"]
            else:
                raw_error = json.dumps(data, ensure_ascii=False)
                await save_to_log(raw_error)
                return raw_error

            # --- Проверка на смену имени ---
            if ai_content.startswith("name:"):
                # Формат: name:username:новый_ник
                parts = ai_content.split(":", 2)
                if len(parts) == 3:
                    target_username = parts[1].strip()
                    new_nick = parts[2].strip()
                    # Обновляем в базе
                    with db_lock:
                        conn = get_db()
                        conn.execute("UPDATE users SET name=? WHERE username=?", (new_nick, target_username))
                        conn.commit()
                        conn.close()
                    # Переопределяем ответ для пользователя
                    ai_content = f"Сотрудник поддержки поменял вам имя на: {new_nick}"

            await save_to_log(ai_content)
            return ai_content

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







@app.get("/search_users")

async def search_users(q: str, token: str, my_username: str):

    if not is_valid_session(token, my_username):

        return []

    with db_lock:

        conn = get_db()

        rows = conn.execute(

            """SELECT username, name, last_seen, is_frozen 

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


@app.get("/link_preview")
async def link_preview(url: str, username: str, token: str):
    if not is_valid_session(token, username):
        raise HTTPException(401)
    if not url or not (url.startswith("http://") or url.startswith("https://")):
        raise HTTPException(422, "Invalid url")

    # Лимиты для экономии ОЗУ
    CHUNK_FOR_META = 256 * 1024  # 256 КБ хватит для любых мета-тегов
    MAX_VIDEO_PHOTO_SIZE = 5 * 1024 * 1024 # 5 МБ лимит на "прощупывание"

    result = {
        "url": url, 
        "title": "", 
        "description": "", 
        "image": "", 
        "site_name": "", 
        "type": "link"
    }

    def _clean(val: str) -> str:
        if not val: return ""
        return re.sub(r"\s+", " ", val).strip()[:500]

    def _pick(meta, key):
        return meta.get(key) or meta.get(key.lower()) or meta.get(key.upper())

    try:
        async with httpx.AsyncClient(follow_redirects=True, timeout=10.0) as client:
            # Используем stream=True, чтобы не загружать всё тело сразу
            async with client.stream("GET", url, headers={"User-Agent": "NiosMessPreview/1.0"}) as resp:
                ctype = resp.headers.get("Content-Type", "").lower()
                
                # 1. Если это ИЗОБРАЖЕНИЕ
                if "image/" in ctype:
                    result.update({
                        "type": "image",
                        "image": url,
                        "title": f"Фото: {urlparse(url).path.split('/')[-1] or 'image'}"
                    })
                    return result

                # 2. Если это ВИДЕО (имитируем ограничение в 5 секунд через лимит данных)
                if "video/" in ctype:
                    result.update({
                        "type": "video",
                        "title": f"Видео: {urlparse(url).path.split('/')[-1] or 'video'}",
                        "description": "Предпросмотр видео доступен по прямой ссылке"
                    })
                    # Не качаем видео совсем, просто отдаем тип
                    return result

                # 3. Если это HTML (Сайт)
                if "text/html" in ctype:
                    body_content = b""
                    async for chunk in resp.aiter_bytes(chunk_size=8192):
                        body_content += chunk
                        # Читаем только верхушку сайта (мета-теги всегда в начале)
                        if len(body_content) > CHUNK_FOR_META:
                            break
                    html = body_content.decode("utf-8", errors="ignore")
                else:
                    # Любой другой тип файла — не качаем
                    return result

    except Exception as e:
        logger.error(f"Link preview error: {e}")
        return result

    # --- ПАРСИНГ META (только для HTML) ---
    meta = {}
    # Ищем мета-теги
    for m in re.findall(r"<meta[^>]+>", html, flags=re.IGNORECASE):
        prop = re.search(r'(property|name)=["\']([^"\']+)["\']', m, flags=re.IGNORECASE)
        content = re.search(r'content=["\']([^"\']*)["\']', m, flags=re.IGNORECASE)
        if prop and content:
            meta[prop.group(2).strip()] = content.group(1).strip()

    # Извлекаем данные
    title = _pick(meta, "og:title") or _pick(meta, "twitter:title")
    if not title:
        t = re.search(r"<title[^>]*>(.*?)</title>", html, flags=re.IGNORECASE | re.DOTALL)
        title = t.group(1).strip() if t else ""

    description = _pick(meta, "og:description") or _pick(meta, "twitter:description") or _pick(meta, "description")
    image = _pick(meta, "og:image") or _pick(meta, "twitter:image")
    site_name = _pick(meta, "og:site_name") or urlparse(url).netloc

    result.update({
        "title": _clean(title),
        "description": _clean(description),
        "image": _clean(image),
        "site_name": _clean(site_name),
        "type": _clean(_pick(meta, "og:type") or "link")
    })

    return result

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
