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
import secrets
import hashlib
from collections import defaultdict

from passlib.hash import argon2
from dotenv import load_dotenv
try:
    import jwt
except Exception:
    jwt = None
from google.oauth2 import service_account
from google.auth.transport.requests import Request as GoogleRequest

import random, obresfucate

from typing import List, Optional, Dict, Any

from email.mime.text import MIMEText

from email.mime.multipart import MIMEMultipart



from fastapi import FastAPI, File, UploadFile, Form, HTTPException, Header, Request

from fastapi.middleware.cors import CORSMiddleware

from fastapi.responses import JSONResponse, FileResponse, HTMLResponse

from fastapi.exceptions import RequestValidationError

from starlette.exceptions import HTTPException as StarletteHTTPException

from pydantic import BaseModel, validator, EmailStr





logging.basicConfig(

    level=logging.INFO,

    format='%(asctime)s [%(levelname)s] %(message)s',

    handlers=[

        logging.FileHandler("nios_server.log"),

        logging.StreamHandler()

    ]

)

logger = logging.getLogger("NiosMessCore")

load_dotenv()

app = FastAPI(title="NiosMess Ultimate Backend", version="2.6.0")



DATABASE_URL = os.getenv("DATABASE_URL")
if DATABASE_URL:
    if DATABASE_URL.startswith("sqlite:///"):
        DB_FILE = DATABASE_URL.replace("sqlite:///", "")
    else:
        DB_FILE = DATABASE_URL
else:
    DB_FILE = "users.db"

UPLOAD_DIR = "uploads"

ROOT_TOKEN = os.getenv("ROOT_TOKEN")
if not ROOT_TOKEN:
    raise ValueError("ROOT_TOKEN must be set in .env file")

CLEANUP_INTERVAL = 3600





SMTP_SERVER = "smtp.gmail.com"

SMTP_PORT = 587

SMTP_USER = os.getenv("SMTP_USER")

SMTP_PWD = os.getenv("SMTP_PWD")
JWT_SECRET = os.getenv("JWT_SECRET", secrets.token_urlsafe(32))
API_BASE_URL = os.getenv("API_BASE_URL", "https://web.sa2rn.fun")

FCM_SERVER_KEY = os.getenv("FCM_SERVER_KEY", "")
FCM_ENDPOINT = "https://fcm.googleapis.com/fcm/send"
FCM_SERVICE_ACCOUNT = os.getenv("FCM_SERVICE_ACCOUNT", "niosmess_service_account.json")

if not FCM_SERVER_KEY and not os.path.exists(FCM_SERVICE_ACCOUNT):
    logger.warning("No FCM credentials found (FCM_SERVER_KEY or service account JSON). Push notifications are disabled.")




pending_regs = {}
mc_cache = {}




if not os.path.exists(UPLOAD_DIR):

    os.makedirs(UPLOAD_DIR)





ALLOWED_ORIGINS = ["https://web.sa2rn.fun"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["Content-Disposition"],
)



db_lock = threading.Lock()



ALLOWED_TABLES = {
    "messages": "messages",
    "group_messages": "group_messages",
    "collective_chats": "collective_chats",
}


def validate_table_name(table: str) -> str:
    if table not in ALLOWED_TABLES:
        raise ValueError(f"Invalid table name: {table}")
    return ALLOWED_TABLES[table]


class PasswordManager:
    @staticmethod
    def hash_password(password: str) -> str:
        return argon2.hash(password)

    @staticmethod
    def verify_password(password: str, hashed: str) -> bool:
        try:
            return argon2.verify(password, hashed)
        except Exception:
            return False

    @staticmethod
    def needs_rehash(hashed: str) -> bool:
        return argon2.needs_update(hashed)


class SessionManager:
    @staticmethod
    def generate_token() -> str:
        return secrets.token_urlsafe(32)

    @staticmethod
    def hash_token(token: str) -> str:
        return hashlib.sha256(token.encode()).hexdigest()

    @staticmethod
    def create_session(username: str, device: str, ip: str) -> dict:
        token = SessionManager.generate_token()
        return {
            "token": token,
            "username": username,
            "device": device,
            "ip": ip,
            "created_at": time.time(),
            "expires_at": time.time() + (30 * 24 * 60 * 60),
        }


class JWTManager:
    def __init__(self, secret: str):
        self.secret = secret

    def create_token(self, username: str, expires_delta: datetime.timedelta = datetime.timedelta(days=30)) -> str:
        if jwt is None:
            raise RuntimeError("PyJWT is not installed")
        expire = datetime.datetime.utcnow() + expires_delta
        payload = {
            "username": username,
            "exp": expire,
            "iat": datetime.datetime.utcnow(),
        }
        return jwt.encode(payload, self.secret, algorithm="HS256")

    def verify_token(self, token: str) -> Optional[dict]:
        if jwt is None:
            return None
        try:
            return jwt.decode(token, self.secret, algorithms=["HS256"])
        except Exception:
            return None


jwt_manager = JWTManager(JWT_SECRET) if jwt else None


class RateLimiter:
    def __init__(self, max_attempts: int = 5, window_minutes: int = 15):
        self.max_attempts = max_attempts
        self.window = datetime.timedelta(minutes=window_minutes)
        self.attempts = defaultdict(list)

    def is_allowed(self, identifier: str) -> bool:
        now = datetime.datetime.now()
        self.attempts[identifier] = [
            ts for ts in self.attempts[identifier]
            if now - ts < self.window
        ]
        if len(self.attempts[identifier]) >= self.max_attempts:
            return False
        self.attempts[identifier].append(now)
        return True

    def reset(self, identifier: str):
        self.attempts.pop(identifier, None)


login_limiter = RateLimiter(max_attempts=5, window_minutes=15)


def sanitize_search_query(query: str) -> str:
    query = query.replace("%", r"\%").replace("_", r"\_")
    return query[:100]


ALLOWED_EXTENSIONS = {
    "image": {".jpg", ".jpeg", ".png", ".gif", ".webp"},
    "video": {".mp4", ".mov", ".avi", ".mkv"},
    "audio": {".mp3", ".wav", ".ogg", ".m4a", ".webm"},
    "document": {".pdf", ".doc", ".docx", ".txt", ".md"},
}

MAX_FILE_SIZES = {
    "image": 10 * 1024 * 1024,
    "video": 100 * 1024 * 1024,
    "audio": 20 * 1024 * 1024,
    "document": 50 * 1024 * 1024,
}

MAX_FILE_SIZE = max(MAX_FILE_SIZES.values())


def validate_file_upload(filename: str, content_type: str, size: int) -> tuple[str, bool]:
    ext = os.path.splitext(filename or "")[1].lower()
    file_type = None
    for ftype, extensions in ALLOWED_EXTENSIONS.items():
        if ext in extensions:
            file_type = ftype
            break
    if not file_type:
        return "File type not allowed", False
    if size > MAX_FILE_SIZES[file_type]:
        max_mb = MAX_FILE_SIZES[file_type] // 1024 // 1024
        return f"File too large (max {max_mb}MB)", False
    return file_type, True




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
    msg_type: Optional[str] = None


class NotificationRegisterModel(BaseModel):
    username: str
    session_token: str
    token: str
    platform: Optional[str] = "android"


class NotificationUnregisterModel(BaseModel):
    username: str
    session_token: str
    token: str


class SettingsGetModel(BaseModel):
    username: str
    session_token: str


class SettingsSetModel(BaseModel):
    username: str
    session_token: str
    settings: Dict[str, Any]


class SettingsResetModel(BaseModel):
    username: str
    session_token: str


class WeeklyRolesRequest(BaseModel):
    token: str
    username: str
    chat_id: str



class UserRegistration(BaseModel):
    username: str
    email: EmailStr
    password: str
    name: str
    code: Optional[str] = None

    @validator("username")
    def validate_username(cls, v):
        if not v or len(v) < 3 or len(v) > 20:
            raise ValueError("Username must be 3-20 characters")
        if not re.match(r"^[a-zA-Z0-9_]+$", v):
            raise ValueError("Username can only contain letters, numbers, and underscores")
        return v

    @validator("password")
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain uppercase letter")
        if not re.search(r"[a-z]", v):
            raise ValueError("Password must contain lowercase letter")
        if not re.search(r"[0-9]", v):
            raise ValueError("Password must contain number")
        return v

    @validator("name")
    def validate_name(cls, v):
        if not v or len(v) < 2 or len(v) > 50:
            raise ValueError("Name must be 2-50 characters")
        return v



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
        logger.error(f"Critical Error processing request from {client_ip}: {e}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content={"detail": "Internal server error"}
        )





@app.exception_handler(StarletteHTTPException)

async def http_exception_handler(request, exc):

    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})



@app.exception_handler(RequestValidationError)

async def validation_exception_handler(request, exc):

    return JSONResponse(status_code=422, content={"detail": str(exc)})





class _PooledConnection:
    def __init__(self, conn: sqlite3.Connection, pool: "DatabasePool"):
        self._conn = conn
        self._pool = pool
        self._released = False

    def close(self):
        if self._released:
            return
        self._released = True
        self._pool.release(self._conn)

    def __getattr__(self, name):
        return getattr(self._conn, name)


class DatabasePool:
    def __init__(self, db_path: str, pool_size: int = 10):
        self.db_path = db_path
        self.pool_size = pool_size
        self.pool: List[sqlite3.Connection] = []
        self._lock = threading.Lock()

    def _create_conn(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path, timeout=30, check_same_thread=False)
        conn.execute("PRAGMA journal_mode=WAL;")
        conn.execute("PRAGMA synchronous=NORMAL;")
        conn.row_factory = sqlite3.Row
        return conn

    def acquire(self) -> _PooledConnection:
        with self._lock:
            if self.pool:
                conn = self.pool.pop()
            else:
                conn = self._create_conn()
        return _PooledConnection(conn, self)

    def release(self, conn: sqlite3.Connection):
        try:
            conn.rollback()
        except Exception:
            pass
        with self._lock:
            if len(self.pool) < self.pool_size:
                self.pool.append(conn)
            else:
                conn.close()


db_pool = DatabasePool(DB_FILE, pool_size=10)


def get_db():
    return db_pool.acquire()


def _get_device_tokens(username: str) -> List[str]:
    with db_lock:
        conn = get_db()
        rows = conn.execute("SELECT token FROM device_tokens WHERE username=?", (username,)).fetchall()
        conn.close()
    return [r[0] for r in rows]


def _send_fcm(tokens: List[str], title: str, body: str, data: Optional[dict] = None):
    if not tokens:
        return
    if FCM_SERVER_KEY:
        headers = {
            "Authorization": f"key={FCM_SERVER_KEY}",
            "Content-Type": "application/json",
        }
        payload = {
            "registration_ids": tokens,
            "notification": {"title": title, "body": body},
            "data": data or {},
            "priority": "high",
        }
        try:
            httpx.post(FCM_ENDPOINT, headers=headers, json=payload, timeout=5.0)
        except Exception as e:
            logger.error(f"FCM legacy send failed: {e}")
        return
    if not os.path.exists(FCM_SERVICE_ACCOUNT):
        return
    try:
        creds = service_account.Credentials.from_service_account_file(
            FCM_SERVICE_ACCOUNT,
            scopes=["https://www.googleapis.com/auth/firebase.messaging"],
        )
        creds.refresh(GoogleRequest())
        access_token = creds.token
        project_id = creds.project_id
        if not access_token or not project_id:
            return
        url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        }
        for token in tokens:
            payload = {
                "message": {
                    "token": token,
                    "notification": {"title": title, "body": body},
                    "data": data or {},
                }
            }
            httpx.post(url, headers=headers, json=payload, timeout=5.0)
    except Exception as e:
        logger.error(f"FCM v1 send failed: {e}")


def _notify_user(username: str, title: str, body: str, data: Optional[dict] = None):
    tokens = _get_device_tokens(username)
    _send_fcm(tokens, title, body, data=data)


DEFAULT_SETTINGS = {
    "theme_mode": "system",
    "seed_color": 0xFF4F46E5,
    "use_dynamic_color": False,
    "text_scale": 1.0,
    "bubble_radius": 16.0,
    "bubble_padding": 12.0,
    "bubble_use_gradient": True,
    "bubble_show_tail": True,
    "bubble_outgoing_color": None,
    "bubble_incoming_color": None,
    "wallpaper_url": None,
    "wallpaper_local_path": None,
    "wallpaper_parallax": True,
    "wallpaper_blur": 0.0,
    "wallpaper_opacity": 1.0,
    "notify_sound": True,
    "notify_preview": True,
    "notify_group": True,
    "notify_mentions": True,
    "notify_calls": True,
    "notify_reactions": True,
    "notify_vibrate": True,
    "quiet_hours_start": None,
    "quiet_hours_end": None,
    "last_seen_visibility": "Все",
    "photo_visibility": "Все",
    "message_privacy": "Все",
    "call_privacy": "Все",
    "show_typing": True,
    "read_receipts": True,
    "who_can_write": "all",
    "ghost_mode": False,
    "passcode_lock": False,
    "compact_messages": False,
    "link_preview": True,
    "trim_spaces": False,
    "autosave_drafts": True,
    "enter_to_send": False,
    "auto_download_media": True,
    "auto_download_docs": False,
    "wifi_only_downloads": False,
    "data_saver": False,
    "reduce_motion": False,
    "experimental_features": False,
    "app_icon": "Классика",
}

_VISIBILITY_VALUES = {"Все", "Контакты", "Никто"}


def _normalize_visibility(value: str | None) -> Optional[str]:
    if value is None:
        return None
    if value == "Мои контакты":
        return "Контакты"
    if value in _VISIBILITY_VALUES:
        return value
    return None


def _normalize_who_can_write(value: str | None) -> Optional[str]:
    if value in {"all", "contacts", "nobody"}:
        return value
    return None


def _filter_settings(data: Dict[str, Any]) -> Dict[str, Any]:
    filtered: Dict[str, Any] = {}
    for key, value in data.items():
        if key not in DEFAULT_SETTINGS:
            continue
        if key in {"last_seen_visibility", "photo_visibility", "message_privacy", "call_privacy"}:
            norm = _normalize_visibility(str(value))
            if norm is None:
                continue
            filtered[key] = norm
            continue
        if key == "who_can_write":
            norm = _normalize_who_can_write(str(value))
            if norm is None:
                continue
            filtered[key] = norm
            continue
        if key in {"theme_mode"}:
            if value in {"system", "light", "dark"}:
                filtered[key] = value
            continue
        if key in {"seed_color", "bubble_outgoing_color", "bubble_incoming_color"}:
            if value is None:
                filtered[key] = None
            elif isinstance(value, int):
                filtered[key] = value
            continue
        if isinstance(DEFAULT_SETTINGS[key], bool):
            if isinstance(value, bool):
                filtered[key] = value
            continue
        if isinstance(DEFAULT_SETTINGS[key], (int, float)):
            if isinstance(value, (int, float)):
                filtered[key] = float(value) if isinstance(DEFAULT_SETTINGS[key], float) else int(value)
            continue
        if isinstance(DEFAULT_SETTINGS[key], str) or DEFAULT_SETTINGS[key] is None:
            if value is None or isinstance(value, str):
                filtered[key] = value
            continue
    if "text_scale" in filtered:
        filtered["text_scale"] = max(0.8, min(1.3, float(filtered["text_scale"])))
    if "bubble_radius" in filtered:
        filtered["bubble_radius"] = max(8.0, min(24.0, float(filtered["bubble_radius"])))
    if "bubble_padding" in filtered:
        filtered["bubble_padding"] = max(4.0, min(24.0, float(filtered["bubble_padding"])))
    if "wallpaper_blur" in filtered:
        filtered["wallpaper_blur"] = max(0.0, min(20.0, float(filtered["wallpaper_blur"])))
    if "wallpaper_opacity" in filtered:
        filtered["wallpaper_opacity"] = max(0.1, min(1.0, float(filtered["wallpaper_opacity"])))
    return filtered


def _get_user_settings(conn, username: str) -> Dict[str, Any]:
    row = conn.execute(
        "SELECT settings_json FROM user_settings WHERE username=?",
        (username,),
    ).fetchone()
    settings = dict(DEFAULT_SETTINGS)
    if row and row[0]:
        try:
            stored = json.loads(row[0])
            if isinstance(stored, dict):
                settings.update(stored)
        except Exception:
            pass
    return settings


def _save_user_settings(conn, username: str, settings: Dict[str, Any]) -> None:
    payload = json.dumps(settings)
    conn.execute(
        "INSERT OR REPLACE INTO user_settings (username, settings_json, updated_at) VALUES (?, ?, ?)",
        (username, payload, time.time()),
    )


def _is_contact(conn, a: str, b: str) -> bool:
    if a == b:
        return True
    row = conn.execute(
        "SELECT 1 FROM messages WHERE (sender=? AND receiver=?) OR (sender=? AND receiver=?) LIMIT 1",
        (a, b, b, a),
    ).fetchone()
    if row:
        return True
    row = conn.execute(
        """
        SELECT 1
        FROM chat_members m1
        JOIN chat_members m2 ON m1.chat_id = m2.chat_id
        WHERE m1.username=? AND m2.username=?
        LIMIT 1
        """,
        (a, b),
    ).fetchone()
    return row is not None


def _seed_welcome_chat(conn, username: str) -> None:
    row = conn.execute(
        "SELECT 1 FROM messages WHERE sender='supports' AND receiver=? LIMIT 1",
        (username,),
    ).fetchone()
    if row:
        return
    now = time.time()
    support_pw = PasswordManager.hash_password("support")
    conn.execute(
        "INSERT OR IGNORE INTO users (email, username, name, password, verified, reg_date) VALUES (?, ?, ?, ?, ?, ?)",
        ("support@niosmess.local", "supports", "Support", support_pw, 1, datetime.datetime.now().strftime("%d.%m.%Y")),
    )
    messages = [
        ("supports", username, "Добро пожаловать в NiosMess!", str(now), "text"),
        ("supports", username, "Здесь вы можете общаться, создавать группы и делиться файлами.", str(now + 1), "text"),
        ("supports", username, "Настройки профиля доступны в разделе «Настройки».", str(now + 2), "text"),
    ]
    conn.executemany(
        "INSERT INTO messages (sender, receiver, text, time, type) VALUES (?, ?, ?, ?, ?)",
        messages,
    )



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

        c.execute("""CREATE TABLE IF NOT EXISTS password_resets (
            email TEXT PRIMARY KEY,
            code TEXT,
            expires_at REAL,
            attempts INTEGER DEFAULT 0
        )""")

        c.execute("""CREATE TABLE IF NOT EXISTS call_logs (
            id TEXT PRIMARY KEY,
            caller TEXT,
            callee TEXT,
            status TEXT,
            started_at REAL,
            ended_at REAL,
            duration INTEGER
        )""")

        c.execute("""CREATE TABLE IF NOT EXISTS data_usage (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT,
            direction TEXT,
            bytes INTEGER,
            kind TEXT,
            ts REAL
        )""")

        c.execute("""CREATE TABLE IF NOT EXISTS downloads (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT,
            filename TEXT,
            size INTEGER,
            ts REAL
        )""")

        c.execute("""CREATE TABLE IF NOT EXISTS device_tokens (
            username TEXT,
            token TEXT,
            platform TEXT,
            created_at REAL,
            PRIMARY KEY (username, token)
        )""")

        c.execute("""CREATE TABLE IF NOT EXISTS user_settings (
            username TEXT PRIMARY KEY,
            settings_json TEXT,
            updated_at REAL
        )""")

        c.execute("""CREATE TABLE IF NOT EXISTS weekly_roles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chat_id TEXT,
            username TEXT,
            role TEXT,
            week_start REAL
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

        add_col("group_messages", "type", "TEXT DEFAULT 'text'")
        add_col("group_messages", "lat", "REAL DEFAULT NULL")
        add_col("group_messages", "lon", "REAL DEFAULT NULL")
        add_col("group_messages", "contact_data", "TEXT DEFAULT NULL")
        add_col("messages", "type", "TEXT DEFAULT 'text'")


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
        try:
            ip = websocket.client.host if websocket.client else "unknown"
        except Exception:
            ip = "unknown"
        logger.info(f"WS reject: user={username} token=***{str(token)[-6:]} ip={ip}")
        raise HTTPException(status_code=401, detail="Invalid session")

    ext = file.filename.split(".")[-1].lower()
    if ext not in ALLOWED_EXT:
        raise HTTPException(status_code=400, detail="Only png/jpg/jpeg allowed")

    data = await file.read()
    if len(data) > MAX_FILE_SIZES["image"]:
        raise HTTPException(status_code=400, detail="Avatar too large")

    filename = f"{username}_{uuid.uuid4().hex}.{ext}"
    path = os.path.join(AVATAR_DIR, filename)

    with open(path, "wb") as f:
        f.write(data)

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
MAX_FILE_SIZE = max(MAX_FILE_SIZES.values())

os.makedirs(UPLOAD_DIR, exist_ok=True)

async def _ws_send(username: str, payload: dict):
    conns = active_connections.get(username)
    if not conns:
        return
    dead = []
    for conn in conns:
        try:
            await conn.send_json(payload)
        except Exception:
            dead.append(conn)
    if dead:
        active_connections[username] = [c for c in conns if c not in dead]
        if not active_connections[username]:
            active_connections.pop(username, None)

async def _ws_broadcast(usernames, payload: dict):
    if not usernames:
        return
    for username in set(usernames):
        if username:
            await _ws_send(username, payload)

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, token: str, username: str):
    # --- Проверка сессии ---
    if not is_valid_session(token, username):
        try:
            ip = websocket.client.host if websocket.client else "unknown"
        except Exception:
            ip = "unknown"
        logger.info(f"WS reject: user={username} token=***{str(token)[-6:]} ip={ip}")
        await websocket.close(code=1008)
        return

    await websocket.accept()
    try:
        ip = websocket.client.host if websocket.client else "unknown"
    except Exception:
        ip = "unknown"
    logger.info(f"WS connect: user={username} token=***{str(token)[-6:]} ip={ip}")
    if username not in active_connections:
        active_connections[username] = []
    active_connections[username].append(websocket)

    try:
        while True:
            data = await websocket.receive_json()

            # --- 1. typing уведомление ---
            if data.get("type") == "typing":
                recipient = data.get("receiver")
                if recipient:
                    await _ws_send(recipient, {
                        "type": "typing",
                        "sender": username,
                        "receiver": recipient,
                    })

            # --- 2. upload файла ---
            elif data.get("type") == "file_start":
                filename = data.get("filename")
                existing = getattr(websocket, "current_file", None)
                if existing:
                    try:
                        os.remove(existing.get("path", ""))
                    except Exception:
                        pass
                    try:
                        del websocket.current_file
                    except Exception:
                        pass
                file_type, is_valid = validate_file_upload(filename, data.get("content_type") or "", 0)
                if not is_valid:
                    await websocket.send_json({
                        "type": "error",
                        "message": file_type
                    })
                    continue

                safe_filename = f"{uuid.uuid4().hex}{os.path.splitext(filename)[1]}"
                file_path = os.path.join(UPLOAD_DIR, safe_filename)

                websocket.current_file = {
                    "path": file_path,
                    "size": 0,
                    "safe_name": safe_filename,
                    "max_size": MAX_FILE_SIZES[file_type],
                    "file_type": file_type,
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
                if not isinstance(chunk_b64, str) or not chunk_b64:
                    await websocket.send_json({
                        "type": "error",
                        "message": "Invalid chunk"
                    })
                    continue
                try:
                    chunk_bytes = base64.b64decode(chunk_b64)
                except Exception:
                    await websocket.send_json({
                        "type": "error",
                        "message": "Invalid chunk"
                    })
                    try:
                        os.remove(file_info.get("path", ""))
                    except Exception:
                        pass
                    try:
                        del websocket.current_file
                    except Exception:
                        pass
                    continue

                new_size = file_info["size"] + len(chunk_bytes)
                if new_size > file_info.get("max_size", MAX_FILE_SIZE):
                    await websocket.send_json({
                        "type": "error",
                        "message": "File too large"
                    })
                    try:
                        os.remove(file_info["path"])
                    except Exception:
                        pass
                    try:
                        del websocket.current_file
                    except Exception:
                        pass
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
                    _log_data_usage(username, "upload", file_info["size"], "ws")
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
                try:
                    size = os.path.getsize(path)
                    _log_data_usage(username, "download", size, "ws")
                    _log_download(username, safe_name, size)
                except Exception:
                    pass

    except WebSocketDisconnect:
        if websocket in active_connections.get(username, []):
            active_connections[username].remove(websocket)
        if not active_connections.get(username):
            active_connections.pop(username, None)
        file_info = getattr(websocket, "current_file", None)
        if file_info:
            try:
                os.remove(file_info.get("path", ""))
            except Exception:
                pass
            try:
                del websocket.current_file
            except Exception:
                pass
        logger.info(f"WS disconnect: user={username}")
    except Exception as e:
        if websocket in active_connections.get(username, []):
            active_connections[username].remove(websocket)
        if not active_connections.get(username):
            active_connections.pop(username, None)
        file_info = getattr(websocket, "current_file", None)
        if file_info:
            try:
                os.remove(file_info.get("path", ""))
            except Exception:
                pass
            try:
                del websocket.current_file
            except Exception:
                pass
        logger.error(f"WS error: user={username} err={e}")
        try:
            await websocket.close()
        except Exception:
            pass

            
            
            
            
@app.post("/mark_read")
async def mark_read(chat_id: str = Form(...), username: str = Form(...), token: str = Form(...)):
    if not is_valid_session(token, username): raise HTTPException(401)
    with db_lock:
        conn = get_db()
        conn.execute("UPDATE messages SET is_read=1 WHERE sender=? AND receiver=?", (chat_id, username))
        conn.commit()
    await _ws_send(chat_id, {'type': 'read_receipt', 'chat_id': username, 'status': 'read'})
    return {"status": "ok"}

@app.post("/collective/mark_read")
async def mark_collective_read(chat_id: str = Form(...), username: str = Form(...), token: str = Form(...)):
    if not is_valid_session(token, username): raise HTTPException(401)
    with db_lock:
        conn = get_db()
        last_id = conn.execute("SELECT MAX(id) FROM group_messages WHERE chat_id=?", (chat_id,)).fetchone()[0]
        conn.execute("UPDATE chat_members SET last_read_id=? WHERE chat_id=? AND username=?", (last_id, chat_id, username))
        conn.commit()
    # Notify collective chat members
    with db_lock:
        conn = get_db()
        members = [r[0] for r in conn.execute("SELECT username FROM chat_members WHERE chat_id=?", (chat_id,)).fetchall()]
        conn.close()
    await _ws_broadcast(members, {"type": "read_receipt", "chat_id": chat_id, "username": username, "status": "read", "collective": True})

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
    table = validate_table_name(table)
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
        
    
        # Broadcast poll update
        # We try to find which chat this poll belongs to by looking at messages
        with db_lock:
            conn = get_db()
            # Try messages and group_messages
            msg = conn.execute("SELECT receiver as chat_id FROM messages WHERE text LIKE ? LIMIT 1", (f"%{poll_id}%",)).fetchone()
            if not msg:
                msg = conn.execute("SELECT chat_id FROM group_messages WHERE text LIKE ? LIMIT 1", (f"%{poll_id}%",)).fetchone()
            
            chat_to_notify = msg[0] if msg else None
            if chat_to_notify:
                # If it's a group, get all members
                members = [r[0] for r in conn.execute("SELECT username FROM chat_members WHERE chat_id=?", (chat_to_notify,)).fetchall()]
                if not members: members = [chat_to_notify, username] # Direct chat fallback
                
                await _ws_broadcast(members, {
                    "type": "poll_update",
                    "poll_id": poll_id,
                    "counts": results,
                    "total": total
                })
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
    safe_query = sanitize_search_query(q)
    is_group = chat_type in ["group", "channel"]
    table = validate_table_name("group_messages" if is_group else "messages")
    
    with db_lock:
        conn = get_db()
        
        # Получаем общее количество результатов
        if is_group:
            count_row = conn.execute(
                f"SELECT COUNT(*) as total FROM {table} WHERE chat_id=? AND text LIKE ? ESCAPE '\\'", 
                (chat_id, f"%{safe_query}%")
            ).fetchone()
            results = conn.execute(
                f"SELECT * FROM {table} WHERE chat_id=? AND text LIKE ? ESCAPE '\\' ORDER BY id DESC LIMIT ? OFFSET ?", 
                (chat_id, f"%{safe_query}%", limit, offset)
            ).fetchall()
        else:
            count_row = conn.execute(
                f"SELECT COUNT(*) as total FROM {table} WHERE ((sender=? AND receiver=?) OR (sender=? AND receiver=?)) AND text LIKE ? ESCAPE '\\'", 
                (username, chat_id, chat_id, username, f"%{safe_query}%")
            ).fetchone()
            results = conn.execute(
                f"SELECT * FROM {table} WHERE ((sender=? AND receiver=?) OR (sender=? AND receiver=?)) AND text LIKE ? ESCAPE '\\' ORDER BY id DESC LIMIT ? OFFSET ?", 
                (username, chat_id, chat_id, username, f"%{safe_query}%", limit, offset)
            ).fetchall()
        
        total = count_row['total'] if count_row else 0
        conn.close()
        
    return {
        "results": [dict(r) for r in results],
        "total": total,
        "has_more": (offset + len(results)) < total
    }


@app.get("/channels/weekly_moment")
async def channels_weekly_moment(
    chat_id: str,
    username: str,
    token: str,
    limit: int = 5,
):
    """Weekly Moment digest for channel: top posts by reactions for last 7 days."""
    if not is_valid_session(token, username):
        raise HTTPException(401)
    since = time.time() - 7 * 86400
    with db_lock:
        conn = get_db()
        chat = conn.execute(
            "SELECT type FROM collective_chats WHERE id=?",
            (chat_id,),
        ).fetchone()
        if not chat or chat["type"] != "channel":
            conn.close()
            raise HTTPException(404, "Channel not found")
        member = conn.execute(
            "SELECT 1 FROM chat_members WHERE chat_id=? AND username=?",
            (chat_id, username),
        ).fetchone()
        if not member:
            conn.close()
            raise HTTPException(403, "Not a channel member")
        rows = conn.execute(
            """
            SELECT m.id, m.text, m.time, m.type,
                   COALESCE(r.cnt, 0) as reactions
            FROM group_messages m
            LEFT JOIN (
                SELECT message_id, COUNT(*) as cnt
                FROM reactions
                WHERE chat_id=?
                GROUP BY message_id
            ) r ON r.message_id = m.id
            WHERE m.chat_id=? AND CAST(m.time AS REAL) >= ?
            ORDER BY reactions DESC, CAST(m.time AS REAL) DESC
            LIMIT ?
            """,
            (chat_id, chat_id, since, limit),
        ).fetchall()
        total = conn.execute(
            "SELECT COUNT(*) as total FROM group_messages WHERE chat_id=? AND CAST(time AS REAL) >= ?",
            (chat_id, since),
        ).fetchone()
        conn.close()
    return {
        "status": "ok",
        "since": since,
        "total": total["total"] if total else 0,
        "items": [dict(r) for r in rows],
    }


@app.post("/groups/weekly_roles")
async def groups_weekly_roles(payload: WeeklyRolesRequest):
    if not is_valid_session(payload.token, payload.username):
        raise HTTPException(401, "Unauthorized")
    week_start = int(time.time() // (7 * 86400) * (7 * 86400))
    with db_lock:
        conn = get_db()
        chat = conn.execute(
            "SELECT type FROM collective_chats WHERE id=?",
            (payload.chat_id,),
        ).fetchone()
        if not chat or chat["type"] != "group":
            conn.close()
            raise HTTPException(404, "Group not found")
        member = conn.execute(
            "SELECT 1 FROM chat_members WHERE chat_id=? AND username=?",
            (payload.chat_id, payload.username),
        ).fetchone()
        if not member:
            conn.close()
            raise HTTPException(403, "Not a group member")
        roles = conn.execute(
            "SELECT username, role FROM weekly_roles WHERE chat_id=? AND week_start=?",
            (payload.chat_id, week_start),
        ).fetchall()
        if not roles:
            candidates = conn.execute(
                "SELECT username FROM chat_members WHERE chat_id=?",
                (payload.chat_id,),
            ).fetchall()
            members = [r["username"] for r in candidates]
            random.seed(f"{payload.chat_id}:{week_start}")
            random.shuffle(members)
            if members:
                chosen = {
                    "editor": members[0],
                    "moderator": members[1 % len(members)] if len(members) > 1 else members[0],
                }
                for role, user in chosen.items():
                    conn.execute(
                        "INSERT INTO weekly_roles (chat_id, username, role, week_start) VALUES (?, ?, ?, ?)",
                        (payload.chat_id, user, role, week_start),
                    )
                roles = conn.execute(
                    "SELECT username, role FROM weekly_roles WHERE chat_id=? AND week_start=?",
                    (payload.chat_id, week_start),
                ).fetchall()
            conn.commit()
        conn.close()
    return {
        "status": "ok",
        "week_start": week_start,
        "roles": [dict(r) for r in roles],
    }




 

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
        try:
            ip = websocket.client.host if websocket.client else "unknown"
        except Exception:
            ip = "unknown"
        logger.info(f"WS reject: user={username} token=***{str(token)[-6:]} ip={ip}")
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
        try:
            ip = websocket.client.host if websocket.client else "unknown"
        except Exception:
            ip = "unknown"
        logger.info(f"WS reject: user={username} token=***{str(token)[-6:]} ip={ip}")
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


# --- Файлы передаются только через WebSocket (/ws) ---
# HTTP endpoints /upload и /download удалены - используйте WebSocket








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
BANNED_WORDS = ["С‡РёС‚", "cheat", "hack", "exploit", "crack", "bypass"]

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
async def register(u: UserRegistration):
    email_clean = u.email.strip().lower()
    username_clean = u.username.strip()
    name_clean = u.name.strip()

    if not u.username or not u.email or not u.password:
        raise HTTPException(status_code=400, detail="Заполните все поля")

    if u.code:
        saved = pending_regs.get(email_clean)
        if not saved or saved["code"] != u.code:
            raise HTTPException(status_code=400, detail="Неверный код подтверждения")

        data = saved["data"]
        is_safe = check_username_safe(data["username"], data["name"])

        with db_lock:
            conn = get_db()
            try:
                conn.execute("BEGIN EXCLUSIVE")
                existing = conn.execute(
                    "SELECT email, username FROM users WHERE email=? OR username=?",
                    (email_clean, data["username"])
                ).fetchone()

                if existing:
                    conn.execute("ROLLBACK")
                    if existing["email"] == email_clean:
                        raise HTTPException(status_code=400, detail="Email already registered")
                    raise HTTPException(status_code=400, detail="Username already taken")

                conn.execute(
                    """INSERT INTO users 
                       (email, username, name, password, reg_date, last_seen, is_frozen, frozen_rule, verified) 
                       VALUES (?,?,?,?,?,?,?,?,?)""",
                    (
                        email_clean,
                        data["username"],
                        data["name"] or data["username"],
                        data["password_hash"],
                        datetime.datetime.now().strftime("%d.%m.%Y"),
                        time.time(),
                        0 if is_safe else 1,
                        None if is_safe else "Нарушение п. 4.1.3 и 4.1.7 Условий использования (упоминание читов в имени или нике)",
                        1,
                    )
                )
                conn.execute("COMMIT")
            except HTTPException:
                raise
            except Exception as e:
                conn.execute("ROLLBACK")
                logger.error(f"Registration error: {e}", exc_info=True)
                raise HTTPException(status_code=500, detail="Registration failed")
            finally:
                conn.close()

        if email_clean in pending_regs:
            del pending_regs[email_clean]
        logger.info(f"New user registered: {data['username']}")
        return {
            "status": "ok",
            "message": "User created",
            "frozen": not is_safe
        }

    with db_lock:
        conn = get_db()
        existing = conn.execute(
            "SELECT email, username FROM users WHERE email=? OR username=?",
            (email_clean, username_clean)
        ).fetchone()
        conn.close()

    if existing:
        if existing['email'] == email_clean:
            raise HTTPException(status_code=400, detail="Пользователь с таким Email уже есть")
        if existing['username'] == username_clean:
            raise HTTPException(status_code=400, detail="Это имя пользователя уже занято")

    gen_code = str(random.randint(100000, 999999))
    pending_regs[email_clean] = {
        "code": gen_code,
        "data": {
            "username": username_clean,
            "name": name_clean or username_clean,
            "password_hash": PasswordManager.hash_password(u.password),
        },
    }

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
async def login(request: Request, username: str = Form(...), password: str = Form(...), device: str = Form(None), ip: str = Form(None)):
    if not login_limiter.is_allowed(username):
        raise HTTPException(
            status_code=429,
            detail="Too many login attempts. Please try again in 15 minutes."
        )

    with db_lock:
        conn = get_db()
        user = conn.execute("SELECT * FROM users WHERE username=?", (username,)).fetchone()

        if not user:
            conn.close()
            raise HTTPException(401, detail="Invalid credentials")

        stored_password = user["password"] or ""
        if stored_password.startswith("$argon2"):
            if not PasswordManager.verify_password(password, stored_password):
                conn.close()
                raise HTTPException(401, detail="Invalid credentials")
            if PasswordManager.needs_rehash(stored_password):
                new_hash = PasswordManager.hash_password(password)
                conn.execute("UPDATE users SET password=? WHERE id=?", (new_hash, user["id"]))
                conn.commit()
        else:
            if stored_password != password:
                conn.close()
                raise HTTPException(401, detail="Invalid credentials")
            new_hash = PasswordManager.hash_password(password)
            conn.execute("UPDATE users SET password=? WHERE id=?", (new_hash, user["id"]))
            conn.commit()

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

        ua = device or request.headers.get("user-agent", "Unknown Device")
        ip_addr = ip or (request.client.host if request.client else "unknown")
        session_data = SessionManager.create_session(username=username, device=ua, ip=ip_addr)
        new_token = session_data["token"]

        conn.execute(
            "INSERT INTO sessions (token, username, last_activity, device, ip) VALUES (?, ?, ?, ?, ?)",
            (new_token, username, time.time(), ua, ip_addr)
        )
        conn.commit()
        conn.close()

        login_limiter.reset(username)

        return {
            "status": "ok",
            "token": new_token,
            "username": username,
            "name": user["name"]
        }



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
        settings = _get_user_settings(conn, username)
        is_contact = _is_contact(conn, my_username, username)
        conn.close()

    if row:
        res = dict(row)
        last_seen = row["last_seen"] or 0
        is_online = (time.time() - last_seen) < 60

        is_self = my_username == username
        allow_last_seen = True
        if not is_self:
            if settings.get("ghost_mode"):
                allow_last_seen = False
            else:
                vis = settings.get("last_seen_visibility", "Все")
                if vis == "Никто":
                    allow_last_seen = False
                elif vis == "Контакты" and not is_contact:
                    allow_last_seen = False

        res["is_online"] = is_online if allow_last_seen else False
        res["isonline"] = is_online if allow_last_seen else False
        res["isfrozen"] = res.get("is_frozen")
        res["last_seen_ts"] = last_seen if allow_last_seen else 0
        res["last_seen_text"] = format_last_seen(last_seen) if allow_last_seen else "скрыто"

        photo_vis = settings.get("photo_visibility", "Все")
        allow_photo = True
        if not is_self:
            if photo_vis == "Никто":
                allow_photo = False
            elif photo_vis == "Контакты" and not is_contact:
                allow_photo = False
        res["photo_hidden"] = not allow_photo

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
        try:
            ip = websocket.client.host if websocket.client else "unknown"
        except Exception:
            ip = "unknown"
        logger.info(f"WS reject: user={username} token=***{str(token)[-6:]} ip={ip}")
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
    # Broadcast profile update to contacts/groups
    with db_lock:
        conn = get_db()
        # Get all users who share a chat or are in contacts
        # Simplified: broadcast to all active connections? No, let's try to find relevant people.
        # For now, let's just broadcast a 'profile_update' event. 
        # The frontend can decide if they care about this user.
        # But we need to know WHO is connected.
        import __main__
        all_users = list(getattr(__main__, 'active_connections', {}).keys())
        conn.close()
    await _ws_broadcast(all_users, {"type": "profile_update", "username": username, "about": about})

        conn.close()

    return {"status": "ok"}



from typing import Optional



@app.get("/get_chats")
async def get_chats(username: str | None = None, user: str | None = None, token: str = ""):
    username = username or user
    if not username:
        raise HTTPException(422, detail="Missing username")
    if not is_valid_session(token, username):
        try:
            ip = websocket.client.host if websocket.client else "unknown"
        except Exception:
            ip = "unknown"
        logger.info(f"WS reject: user={username} token=***{str(token)[-6:]} ip={ip}")
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
    attachments: str = Form(None), # JSON list of filenames
    ttl_seconds: int = Form(None),
    msg_type: str = Form(None),
    lat: float = Form(None),
    lon: float = Form(None),
    contact_data: str = Form(None)
):
    if not is_valid_session(token, sender):
        raise HTTPException(status_code=401, detail="Invalid session")

    expires_at = (time.time() + ttl_seconds) if ttl_seconds else None

    with db_lock:
        conn = get_db()

        chat_row = conn.execute("SELECT type, owner FROM collective_chats WHERE id=?", (chat_id,)).fetchone()
        if not chat_row:
            conn.close()
            raise HTTPException(status_code=404, detail="Chat not found")

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

        cursor = conn.execute(
            """INSERT INTO group_messages 
               (chat_id, sender, text, time, reply_to, attachments, expires_at, type, lat, lon, contact_data) 
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (chat_id, sender, text, str(time.time()), reply_to, attachments, expires_at, msg_type or "text", lat, lon, contact_data)
        )
        msg_id = cursor.lastrowid

        preview = text[:50] + ("..." if len(text) > 50 else "")
        conn.execute(
            "UPDATE collective_chats SET updated_at=?, last_message_preview=? WHERE id=?",
            (str(time.time()), preview, chat_id)
        )

        conn.commit()
        conn.close()

    try:
        with db_lock:
            conn = get_db()
            members = conn.execute("SELECT username FROM chat_members WHERE chat_id=?", (chat_id,)).fetchall()
            conn.close()
        usernames_all = [m[0] for m in members]
        usernames = [m for m in usernames_all if m != sender]
        try:
            preview_text = obresfucate.deobresfucate(text) if isinstance(text, str) else ""
        except Exception:
            preview_text = text if isinstance(text, str) else ""
        for username in usernames:
            mention = 1 if f"@{username}" in preview_text else 0
            _notify_user(
                username,
                title=f"{chat_info.get('name', chat_id)}",
                body=preview_text[:140],
                data={
                    "chat_type": chat_info.get("type", "group"),
                    "sender": sender,
                    "chat_id": chat_id,
                    "mention": str(mention),
                },
            )
        await _ws_broadcast(
            usernames_all,
            {
                "type": "message",
                "chat_type": chat_info.get("type", "group"),
                "chat_id": chat_id,
                "sender": sender,
                "message_id": msg_id,
            },
        )
    except Exception as e:
        logger.error(f"Collective notify failed: {e}")

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
        try:
            ip = websocket.client.host if websocket.client else "unknown"
        except Exception:
            ip = "unknown"
        logger.info(f"WS reject: user={username} token=***{str(token)[-6:]} ip={ip}")
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
        try:
            ip = websocket.client.host if websocket.client else "unknown"
        except Exception:
            ip = "unknown"
        logger.info(f"WS reject: user={username} token=***{str(token)[-6:]} ip={ip}")
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
        try:
            ip = websocket.client.host if websocket.client else "unknown"
        except Exception:
            ip = "unknown"
        logger.info(f"WS reject: user={username} token=***{str(token)[-6:]} ip={ip}")
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
        try:
            ip = websocket.client.host if websocket.client else "unknown"
        except Exception:
            ip = "unknown"
        logger.info(f"WS reject: user={username} token=***{str(token)[-6:]} ip={ip}")
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
        try:
            ip = websocket.client.host if websocket.client else "unknown"
        except Exception:
            ip = "unknown"
        logger.info(f"WS reject: user={username} token=***{str(token)[-6:]} ip={ip}")
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


@app.post("/reactions/list")
async def reactions_list(payload: dict):
    token = payload.get("token")
    username = payload.get("username")
    message_ids = payload.get("message_ids") or []
    chat_id = payload.get("chat_id")
    collective = payload.get("collective") is True
    if not is_valid_session(token, username):
        try:
            ip = websocket.client.host if websocket.client else "unknown"
        except Exception:
            ip = "unknown"
        logger.info(f"WS reject: user={username} token=***{str(token)[-6:]} ip={ip}")
        raise HTTPException(401, "Unauthorized")
    if not isinstance(message_ids, list) or not message_ids:
        return {"status": "ok", "data": {}}
    if collective and not chat_id:
        raise HTTPException(422, "Missing chat_id")
    target_chat = chat_id if collective else "__direct__"
    ids = []
    for raw in message_ids:
        try:
            ids.append(int(raw))
        except Exception:
            continue
    if not ids:
        return {"status": "ok", "data": {}}
    placeholders = ",".join(["?"] * len(ids))
    with db_lock:
        conn = get_db()
        rows = conn.execute(
            f"""
            SELECT message_id, emoji, COUNT(*) as cnt
            FROM reactions
            WHERE chat_id=? AND message_id IN ({placeholders})
            GROUP BY message_id, emoji
            """,
            (target_chat, *ids),
        ).fetchall()
        mine_rows = conn.execute(
            f"""
            SELECT message_id, emoji
            FROM reactions
            WHERE chat_id=? AND message_id IN ({placeholders}) AND username=?
            """,
            (target_chat, *ids, username),
        ).fetchall()
        conn.commit()
    data: Dict[str, Any] = {}
    for row in rows:
        msg_id = str(row["message_id"])
        bucket = data.setdefault(msg_id, {"counts": {}, "mine": {}})
        bucket["counts"][row["emoji"]] = int(row["cnt"])
    for row in mine_rows:
        msg_id = str(row["message_id"])
        bucket = data.setdefault(msg_id, {"counts": {}, "mine": {}})
        bucket["mine"][row["emoji"]] = True
    return {"status": "ok", "data": data}



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

@app.post("/notifications/register")
async def notifications_register(payload: NotificationRegisterModel):
    if not is_valid_session(payload.session_token, payload.username):
        raise HTTPException(status_code=401, detail="Invalid session")
    with db_lock:
        conn = get_db()
        conn.execute(
            "INSERT OR REPLACE INTO device_tokens (username, token, platform, created_at) VALUES (?, ?, ?, ?)",
            (payload.username, payload.token, payload.platform or "android", time.time()),
        )
        conn.commit()
        conn.close()
    return {"status": "ok"}


@app.post("/notifications/unregister")
async def notifications_unregister(payload: NotificationUnregisterModel):
    if not is_valid_session(payload.session_token, payload.username):
        raise HTTPException(status_code=401, detail="Invalid session")
    with db_lock:
        conn = get_db()
        conn.execute("DELETE FROM device_tokens WHERE username=? AND token=?", (payload.username, payload.token))
        conn.commit()
        conn.close()
    return {"status": "ok"}


@app.post("/settings/get")
async def settings_get(payload: SettingsGetModel):
    if not is_valid_session(payload.session_token, payload.username):
        raise HTTPException(status_code=401, detail="Invalid session")
    with db_lock:
        conn = get_db()
        settings = _get_user_settings(conn, payload.username)
        conn.close()
    return {"status": "ok", "settings": settings}


@app.post("/settings/set")
async def settings_set(payload: SettingsSetModel):
    if not is_valid_session(payload.session_token, payload.username):
        raise HTTPException(status_code=401, detail="Invalid session")
    updates = _filter_settings(payload.settings or {})
    with db_lock:
        conn = get_db()
        current = _get_user_settings(conn, payload.username)
        if updates:
            current.update(updates)
            _save_user_settings(conn, payload.username, current)
            conn.commit()
        conn.close()
    return {"status": "ok", "settings": current}


@app.post("/settings/reset")
async def settings_reset(payload: SettingsResetModel):
    if not is_valid_session(payload.session_token, payload.username):
        raise HTTPException(status_code=401, detail="Invalid session")
    with db_lock:
        conn = get_db()
        conn.execute("DELETE FROM user_settings WHERE username=?", (payload.username,))
        conn.commit()
        conn.close()
    return {"status": "ok", "settings": dict(DEFAULT_SETTINGS)}



@app.post("/send_message")
async def send_message(m: MessageModel):
    # Проверка сессии
    if not is_valid_session(m.token, m.sender):
        raise HTTPException(status_code=401)

    if m.receiver != "supports" and m.sender != m.receiver:
        with db_lock:
            conn = get_db()
            recv_settings = _get_user_settings(conn, m.receiver)
            is_contact = _is_contact(conn, m.sender, m.receiver)
            conn.close()
        who = recv_settings.get("who_can_write", "all")
        if who == "nobody":
            raise HTTPException(status_code=403, detail="Recipient does not accept messages")
        if who == "contacts" and not is_contact:
            raise HTTPException(status_code=403, detail="Recipient accepts messages from contacts only")
        msg_vis = recv_settings.get("message_privacy", "Все")
        if msg_vis == "Никто":
            raise HTTPException(status_code=403, detail="Recipient does not accept messages")
        if msg_vis == "Контакты" and not is_contact:
            raise HTTPException(status_code=403, detail="Recipient accepts messages from contacts only")


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
        msg_type = getattr(m, 'msg_type', None) or "text"
        cursor = conn.execute(
            """INSERT INTO messages 
               (sender, receiver, text, time, reply_to, expires_at, lat, lon, contact_data, type) 
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (m.sender, m.receiver, m.text, str(time.time()), 
             getattr(m, 'reply_to', None), expires_at, 
             getattr(m, 'lat', None), getattr(m, 'lon', None), 
             getattr(m, 'contact_data', None), msg_type)
        )
        msg_id = cursor.lastrowid
        
        # Получаем данные отправителя для ИИ
        user_row = conn.execute(
            "SELECT username, name, is_frozen, frozen_rule FROM users WHERE username = ?", 
            (m.sender,)
        ).fetchone()
        
        conn.commit()
        conn.close()

    try:
        await _ws_broadcast(
            [m.sender, m.receiver],
            {
                "type": "message",
                "sender": m.sender,
                "receiver": m.receiver,
                "message_id": msg_id,
            },
        )
    except Exception as e:
        logger.error(f"WS notify failed (direct): {e}")

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
            cursor = conn.execute(
                "INSERT INTO messages (sender, receiver, text, time, reply_to, type) VALUES (?, ?, ?, ?, ?, ?)",
                ("supports", m.sender, ai_text, str(time.time()), msg_id, "text")
            )
            ai_msg_id = cursor.lastrowid
            conn.commit()
            conn.close()
        try:
            await _ws_broadcast(
                [m.sender],
                {
                    "type": "message",
                    "sender": "supports",
                    "receiver": m.sender,
                    "message_id": ai_msg_id,
                },
            )
        except Exception as e:
            logger.error(f"WS notify failed (ai): {e}")

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
        try:
            ip = websocket.client.host if websocket.client else "unknown"
        except Exception:
            ip = "unknown"
        logger.info(f"WS reject: user={username} token=***{str(token)[-6:]} ip={ip}")
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

ADMIN_HTML_PATH = os.path.join("webui", "admin.html")


def _require_root(root_token: Optional[str], request: Optional[Request] = None) -> str:
    token = root_token
    if not token and request is not None:
        token = request.query_params.get("root_token")
    if token != ROOT_TOKEN:
        raise HTTPException(status_code=403, detail="Access denied")
    return token


@app.get("/admin", response_class=HTMLResponse)
async def admin_page():
    if os.path.exists(ADMIN_HTML_PATH):
        with open(ADMIN_HTML_PATH, "r", encoding="utf-8") as f:
            return HTMLResponse(f.read())
    return HTMLResponse("<html><body><h2>NiosMess Admin</h2><p>admin.html not found.</p></body></html>")


@app.get("/admin/stats")
async def admin_stats(request: Request, root_token: Optional[str] = Header(None, alias="X-Root-Token")):
    _require_root(root_token, request)
    with db_lock:
        conn = get_db()
        users = conn.execute("SELECT COUNT(*) as c FROM users").fetchone()["c"]
        frozen = conn.execute("SELECT COUNT(*) as c FROM users WHERE is_frozen=1").fetchone()["c"]
        sessions = conn.execute("SELECT COUNT(*) as c FROM sessions").fetchone()["c"]
        messages = conn.execute("SELECT COUNT(*) as c FROM messages").fetchone()["c"]
        group_messages = conn.execute("SELECT COUNT(*) as c FROM group_messages").fetchone()["c"]
        groups = conn.execute("SELECT COUNT(*) as c FROM collective_chats").fetchone()["c"]
        conn.close()
    return {
        "users": users,
        "frozen": frozen,
        "sessions": sessions,
        "messages": messages,
        "group_messages": group_messages,
        "groups": groups,
    }


@app.get("/admin/users")
async def admin_users(
    request: Request,
    root_token: Optional[str] = Header(None, alias="X-Root-Token"),
    q: str = "",
    limit: int = 50,
    offset: int = 0,
):
    _require_root(root_token, request)
    safe_q = sanitize_search_query(q or "")
    with db_lock:
        conn = get_db()
        if safe_q:
            like = f"%{safe_q}%"
            total = conn.execute(
                "SELECT COUNT(*) as c FROM users WHERE username LIKE ? ESCAPE '\\' OR email LIKE ? ESCAPE '\\' OR name LIKE ? ESCAPE '\\'",
                (like, like, like),
            ).fetchone()["c"]
            rows = conn.execute(
                "SELECT id, username, email, name, verified, is_frozen, frozen_rule, last_seen, reg_date FROM users "
                "WHERE username LIKE ? ESCAPE '\\' OR email LIKE ? ESCAPE '\\' OR name LIKE ? ESCAPE '\\' "
                "ORDER BY id DESC LIMIT ? OFFSET ?",
                (like, like, like, limit, offset),
            ).fetchall()
        else:
            total = conn.execute("SELECT COUNT(*) as c FROM users").fetchone()["c"]
            rows = conn.execute(
                "SELECT id, username, email, name, verified, is_frozen, frozen_rule, last_seen, reg_date FROM users "
                "ORDER BY id DESC LIMIT ? OFFSET ?",
                (limit, offset),
            ).fetchall()
        conn.close()
    return {"total": total, "items": [dict(r) for r in rows]}


@app.post("/admin/user/freeze")
async def admin_user_freeze(
    request: Request,
    root_token: Optional[str] = Header(None, alias="X-Root-Token"),
    payload: dict = None,
):
    _require_root(root_token, request)
    payload = payload or {}
    username = payload.get("username")
    frozen = bool(payload.get("frozen"))
    reason = payload.get("reason") or "Frozen by admin"
    if not username:
        raise HTTPException(status_code=400, detail="Missing username")
    with db_lock:
        conn = get_db()
        conn.execute(
            "UPDATE users SET is_frozen=?, frozen_rule=? WHERE username=?",
            (1 if frozen else 0, reason if frozen else None, username),
        )
        conn.commit()
        conn.close()
    return {"status": "ok"}


@app.post("/admin/user/reset_password")
async def admin_user_reset_password(
    request: Request,
    root_token: Optional[str] = Header(None, alias="X-Root-Token"),
    payload: dict = None,
):
    _require_root(root_token, request)
    payload = payload or {}
    username = payload.get("username")
    new_password = payload.get("new_password")
    if not username or not new_password:
        raise HTTPException(status_code=400, detail="Missing username or password")
    hashed = PasswordManager.hash_password(new_password)
    with db_lock:
        conn = get_db()
        conn.execute("UPDATE users SET password=? WHERE username=?", (hashed, username))
        conn.commit()
        conn.close()
    return {"status": "ok"}


@app.delete("/admin/user/{username}")
async def admin_user_delete(
    username: str,
    request: Request,
    root_token: Optional[str] = Header(None, alias="X-Root-Token"),
):
    _require_root(root_token, request)
    with db_lock:
        conn = get_db()
        row = conn.execute("SELECT email FROM users WHERE username=?", (username,)).fetchone()
        email = row["email"] if row else None

        owned = conn.execute("SELECT id FROM collective_chats WHERE owner=?", (username,)).fetchall()
        owned_ids = [r["id"] for r in owned] if owned else []

        if owned_ids:
            for chat_id in owned_ids:
                conn.execute("DELETE FROM group_messages WHERE chat_id=?", (chat_id,))
                conn.execute("DELETE FROM chat_members WHERE chat_id=?", (chat_id,))
                conn.execute("DELETE FROM weekly_roles WHERE chat_id=?", (chat_id,))
            conn.execute("DELETE FROM collective_chats WHERE owner=?", (username,))

        conn.execute("DELETE FROM sessions WHERE username=?", (username,))
        conn.execute("DELETE FROM messages WHERE sender=? OR receiver=?", (username, username))
        conn.execute("DELETE FROM group_messages WHERE sender=?", (username,))
        conn.execute("DELETE FROM chat_members WHERE username=?", (username,))
        conn.execute("DELETE FROM reactions WHERE username=?", (username,))
        conn.execute("DELETE FROM user_badges WHERE username=?", (username,))
        conn.execute("DELETE FROM avatars WHERE username=?", (username,))
        conn.execute("DELETE FROM device_tokens WHERE username=?", (username,))
        conn.execute("DELETE FROM user_settings WHERE username=?", (username,))
        conn.execute("DELETE FROM call_logs WHERE caller=? OR callee=?", (username, username))
        conn.execute("DELETE FROM data_usage WHERE username=?", (username,))
        conn.execute("DELETE FROM downloads WHERE username=?", (username,))
        conn.execute("DELETE FROM scheduled_messages WHERE sender=?", (username,))
        conn.execute("DELETE FROM weekly_roles WHERE username=?", (username,))
        if email:
            conn.execute("DELETE FROM password_resets WHERE email=?", (email,))
        conn.execute("DELETE FROM users WHERE username=?", (username,))
        conn.commit()
        conn.close()
    return {"status": "ok"}


@app.get("/admin/messages")
async def admin_messages(
    request: Request,
    root_token: Optional[str] = Header(None, alias="X-Root-Token"),
    username: Optional[str] = None,
    chat_id: Optional[str] = None,
    chat_type: str = "user",
    q: str = "",
    limit: int = 50,
    offset: int = 0,
):
    _require_root(root_token, request)
    safe_q = sanitize_search_query(q or "")
    with db_lock:
        conn = get_db()
        items = []
        total = 0
        if chat_type in ["group", "channel"] or chat_id:
            like = f"%{safe_q}%" if safe_q else None
            if like:
                count_row = conn.execute(
                    "SELECT COUNT(*) as c FROM group_messages WHERE chat_id=? AND text LIKE ? ESCAPE '\\'",
                    (chat_id, like),
                ).fetchone()
                rows = conn.execute(
                    "SELECT id, chat_id, sender, text, time, reply_to, type FROM group_messages "
                    "WHERE chat_id=? AND text LIKE ? ESCAPE '\\' ORDER BY id DESC LIMIT ? OFFSET ?",
                    (chat_id, like, limit, offset),
                ).fetchall()
            else:
                count_row = conn.execute(
                    "SELECT COUNT(*) as c FROM group_messages WHERE chat_id=?",
                    (chat_id,),
                ).fetchone()
                rows = conn.execute(
                    "SELECT id, chat_id, sender, text, time, reply_to, type FROM group_messages "
                    "WHERE chat_id=? ORDER BY id DESC LIMIT ? OFFSET ?",
                    (chat_id, limit, offset),
                ).fetchall()
            total = count_row["c"] if count_row else 0
            for r in rows:
                d = dict(r)
                d["scope"] = "group"
                items.append(d)
        else:
            like = f"%{safe_q}%" if safe_q else None
            if username and chat_id:
                if like:
                    count_row = conn.execute(
                        "SELECT COUNT(*) as c FROM messages WHERE ((sender=? AND receiver=?) OR (sender=? AND receiver=?)) AND text LIKE ? ESCAPE '\\'",
                        (username, chat_id, chat_id, username, like),
                    ).fetchone()
                    rows = conn.execute(
                        "SELECT id, sender, receiver, text, time, reply_to, type FROM messages "
                        "WHERE ((sender=? AND receiver=?) OR (sender=? AND receiver=?)) AND text LIKE ? ESCAPE '\\' "
                        "ORDER BY id DESC LIMIT ? OFFSET ?",
                        (username, chat_id, chat_id, username, like, limit, offset),
                    ).fetchall()
                else:
                    count_row = conn.execute(
                        "SELECT COUNT(*) as c FROM messages WHERE (sender=? AND receiver=?) OR (sender=? AND receiver=?)",
                        (username, chat_id, chat_id, username),
                    ).fetchone()
                    rows = conn.execute(
                        "SELECT id, sender, receiver, text, time, reply_to, type FROM messages "
                        "WHERE (sender=? AND receiver=?) OR (sender=? AND receiver=?) "
                        "ORDER BY id DESC LIMIT ? OFFSET ?",
                        (username, chat_id, chat_id, username, limit, offset),
                    ).fetchall()
            elif username:
                if like:
                    count_row = conn.execute(
                        "SELECT COUNT(*) as c FROM messages WHERE (sender=? OR receiver=?) AND text LIKE ? ESCAPE '\\'",
                        (username, username, like),
                    ).fetchone()
                    rows = conn.execute(
                        "SELECT id, sender, receiver, text, time, reply_to, type FROM messages "
                        "WHERE (sender=? OR receiver=?) AND text LIKE ? ESCAPE '\\' "
                        "ORDER BY id DESC LIMIT ? OFFSET ?",
                        (username, username, like, limit, offset),
                    ).fetchall()
                else:
                    count_row = conn.execute(
                        "SELECT COUNT(*) as c FROM messages WHERE sender=? OR receiver=?",
                        (username, username),
                    ).fetchone()
                    rows = conn.execute(
                        "SELECT id, sender, receiver, text, time, reply_to, type FROM messages "
                        "WHERE sender=? OR receiver=? ORDER BY id DESC LIMIT ? OFFSET ?",
                        (username, username, limit, offset),
                    ).fetchall()
            else:
                rows = []
                count_row = {"c": 0}

            total = count_row["c"] if count_row else 0
            for r in rows:
                d = dict(r)
                d["scope"] = "direct"
                items.append(d)
        conn.close()
    return {"total": total, "items": items}


@app.get("/admin/sessions")
async def admin_sessions(
    request: Request,
    root_token: Optional[str] = Header(None, alias="X-Root-Token"),
    username: Optional[str] = None,
):
    _require_root(root_token, request)
    with db_lock:
        conn = get_db()
        if username:
            rows = conn.execute(
                "SELECT token, username, last_activity, device, ip FROM sessions WHERE username=? ORDER BY last_activity DESC",
                (username,),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT token, username, last_activity, device, ip FROM sessions ORDER BY last_activity DESC LIMIT 200",
            ).fetchall()
        conn.close()
    return {"items": [dict(r) for r in rows]}



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



# ==================== PASSWORD RESET / PROFILE / CALLS / DATA ====================

class PasswordResetRequest(BaseModel):
    email: Optional[str] = None
    username: Optional[str] = None

class PasswordResetConfirm(BaseModel):
    email: Optional[str] = None
    username: Optional[str] = None
    code: str
    new_password: str

class CallRequestModel(BaseModel):
    token: str
    caller: str
    callee: str

class CallRespondModel(BaseModel):
    token: str
    username: str
    call_id: str
    status: str

class UsageItem(BaseModel):
    direction: str
    bytes: int
    kind: Optional[str] = "api"
    ts: Optional[float] = None

class UsageSync(BaseModel):
    username: str
    token: str
    items: List[UsageItem]

class WeeklyRolesRequest(BaseModel):
    username: str
    token: str
    chat_id: str


def _log_data_usage(username: str, direction: str, bytes_count: int, kind: str = "api"):
    if not username or bytes_count <= 0:
        return
    with db_lock:
        conn = get_db()
        conn.execute(
            "INSERT INTO data_usage (username, direction, bytes, kind, ts) VALUES (?, ?, ?, ?, ?)",
            (username, direction, int(bytes_count), kind, time.time()),
        )
        conn.commit()
        conn.close()


def _log_download(username: str, filename: str, size: int):
    if not username or not filename:
        return
    with db_lock:
        conn = get_db()
        conn.execute(
            "INSERT INTO downloads (username, filename, size, ts) VALUES (?, ?, ?, ?)",
            (username, filename, int(size), time.time()),
        )
        conn.commit()
        conn.close()


def _resolve_user_email(username: Optional[str], email: Optional[str]):
    if email:
        return email.strip().lower(), None
    if not username:
        return None, "Missing username or email"
    with db_lock:
        conn = get_db()
        row = conn.execute("SELECT email FROM users WHERE username=?", (username,)).fetchone()
        conn.close()
    if not row:
        return None, "User not found"
    return row[0].strip().lower(), None


@app.post("/password_reset/request")
async def password_reset_request(payload: PasswordResetRequest):
    email, err = _resolve_user_email(payload.username, payload.email)
    if err:
        raise HTTPException(status_code=404, detail=err)
    if not email:
        raise HTTPException(status_code=400, detail="Missing email")

    code = str(random.randint(100000, 999999))
    expires_at = time.time() + 900

    with db_lock:
        conn = get_db()
        conn.execute(
            "INSERT OR REPLACE INTO password_resets (email, code, expires_at, attempts) VALUES (?, ?, ?, 0)",
            (email, code, expires_at),
        )
        conn.commit()
        conn.close()

    if not send_email(email, code):
        raise HTTPException(status_code=500, detail="Email send failed")

    return {"status": "ok"}


@app.post("/password_reset/confirm")
async def password_reset_confirm(payload: PasswordResetConfirm):
    email, err = _resolve_user_email(payload.username, payload.email)
    if err:
        raise HTTPException(status_code=404, detail=err)
    if not email:
        raise HTTPException(status_code=400, detail="Missing email")

    with db_lock:
        conn = get_db()
        row = conn.execute(
            "SELECT code, expires_at, attempts FROM password_resets WHERE email=?",
            (email,),
        ).fetchone()
        if not row:
            conn.close()
            raise HTTPException(status_code=400, detail="No reset request")

        code, expires_at, attempts = row[0], row[1], row[2]
        if time.time() > float(expires_at):
            conn.execute("DELETE FROM password_resets WHERE email=?", (email,))
            conn.commit()
            conn.close()
            raise HTTPException(status_code=400, detail="Code expired")

        if payload.code != str(code):
            attempts = (attempts or 0) + 1
            conn.execute("UPDATE password_resets SET attempts=? WHERE email=?", (attempts, email))
            conn.commit()
            conn.close()
            raise HTTPException(status_code=400, detail="Invalid code")

        hashed = PasswordManager.hash_password(payload.new_password)
        conn.execute("UPDATE users SET password=? WHERE email=?", (hashed, email))
        conn.execute("DELETE FROM password_resets WHERE email=?", (email,))
        conn.commit()
        conn.close()

    return {"status": "ok"}


@app.post("/profile/set_name")
async def profile_set_name(token: str = Form(...), username: str = Form(...), name: str = Form(...)):
    if not is_valid_session(token, username):
        try:
            ip = websocket.client.host if websocket.client else "unknown"
        except Exception:
            ip = "unknown"
        logger.info(f"WS reject: user={username} token=***{str(token)[-6:]} ip={ip}")
        raise HTTPException(status_code=401, detail="Invalid session")

    clean = name.strip()
    if len(clean) < 2:
        raise HTTPException(status_code=400, detail="Name too short")

    if not check_username_safe(username, clean):
        raise HTTPException(status_code=400, detail="Name contains forbidden words")

    with db_lock:
        conn = get_db()
        conn.execute("UPDATE users SET name=? WHERE username=?", (clean, username))
        conn.commit()
    # Broadcast profile update to contacts/groups
    with db_lock:
        conn = get_db()
        # Get all users who share a chat or are in contacts
        # Simplified: broadcast to all active connections? No, let's try to find relevant people.
        # For now, let's just broadcast a 'profile_update' event. 
        # The frontend can decide if they care about this user.
        # But we need to know WHO is connected.
        import __main__
        all_users = list(getattr(__main__, 'active_connections', {}).keys())
        conn.close()
    await _ws_broadcast(all_users, {"type": "profile_update", "username": username, "name": clean})

        conn.close()

    return {"status": "ok"}


@app.post("/profile/set_username")
async def profile_set_username(token: str = Form(...), username: str = Form(...), new_username: str = Form(...)):
    if not is_valid_session(token, username):
        try:
            ip = websocket.client.host if websocket.client else "unknown"
        except Exception:
            ip = "unknown"
        logger.info(f"WS reject: user={username} token=***{str(token)[-6:]} ip={ip}")
        raise HTTPException(status_code=401, detail="Invalid session")

    new_username = new_username.strip()
    if len(new_username) < 3:
        raise HTTPException(status_code=400, detail="Username too short")

    if not check_username_safe(new_username, new_username):
        raise HTTPException(status_code=400, detail="Username contains forbidden words")

    with db_lock:
        conn = get_db()
        exists = conn.execute("SELECT 1 FROM users WHERE username=?", (new_username,)).fetchone()
        if exists:
            conn.close()
            raise HTTPException(status_code=400, detail="Username already taken")

        conn.execute("UPDATE users SET username=? WHERE username=?", (new_username, username))
        conn.execute("UPDATE sessions SET username=? WHERE username=?", (new_username, username))
        conn.execute("UPDATE messages SET sender=? WHERE sender=?", (new_username, username))
        conn.execute("UPDATE messages SET receiver=? WHERE receiver=?", (new_username, username))
        conn.execute("UPDATE group_messages SET sender=? WHERE sender=?", (new_username, username))
        conn.execute("UPDATE chat_members SET username=? WHERE username=?", (new_username, username))
        conn.execute("UPDATE reactions SET username=? WHERE username=?", (new_username, username))
        conn.execute("UPDATE user_badges SET username=? WHERE username=?", (new_username, username))
        conn.execute("UPDATE avatars SET username=? WHERE username=?", (new_username, username))
        conn.execute("UPDATE collective_chats SET owner=? WHERE owner=?", (new_username, username))
        conn.execute("UPDATE scheduled_messages SET sender=? WHERE sender=?", (new_username, username))
        conn.execute("UPDATE call_logs SET caller=? WHERE caller=?", (new_username, username))
        conn.execute("UPDATE call_logs SET callee=? WHERE callee=?", (new_username, username))
        conn.execute("UPDATE data_usage SET username=? WHERE username=?", (new_username, username))
        conn.execute("UPDATE downloads SET username=? WHERE username=?", (new_username, username))
        conn.commit()
        conn.close()

    return {"status": "ok", "username": new_username}


@app.post("/profile/set_avatar")
async def profile_set_avatar(token: str = Form(...), username: str = Form(...), file: UploadFile = File(...)):
    return await set_avatar(token=token, username=username, file=file)


@app.get("/calls/list")
async def calls_list(username: str, token: str):
    if not is_valid_session(token, username):
        try:
            ip = websocket.client.host if websocket.client else "unknown"
        except Exception:
            ip = "unknown"
        logger.info(f"WS reject: user={username} token=***{str(token)[-6:]} ip={ip}")
        raise HTTPException(status_code=401, detail="Invalid session")
    with db_lock:
        conn = get_db()
        rows = conn.execute(
            "SELECT * FROM call_logs WHERE caller=? OR callee=? ORDER BY started_at DESC",
            (username, username),
        ).fetchall()
        conn.close()
    return {"status": "ok", "data": [dict(r) for r in rows]}


@app.post("/calls/request")
async def calls_request(payload: CallRequestModel):
    if not is_valid_session(payload.token, payload.caller):
        raise HTTPException(status_code=401, detail="Invalid session")

    with db_lock:
        conn = get_db()
        callee_settings = _get_user_settings(conn, payload.callee)
        is_contact = _is_contact(conn, payload.caller, payload.callee)
        conn.close()
    call_vis = callee_settings.get("call_privacy", "Все")
    if call_vis == "Никто":
        raise HTTPException(status_code=403, detail="Recipient does not accept calls")
    if call_vis == "Контакты" and not is_contact:
        raise HTTPException(status_code=403, detail="Recipient accepts calls from contacts only")


    call_id = str(uuid.uuid4())
    now = time.time()
    status = "requested"
    body = json.dumps({
        "call_id": call_id,
        "status": status,
        "caller": payload.caller,
        "callee": payload.callee,
    })

    with db_lock:
        conn = get_db()
        conn.execute(
            "INSERT INTO call_logs (id, caller, callee, status, started_at, ended_at, duration) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (call_id, payload.caller, payload.callee, status, now, None, None),
        )
        conn.execute(
            "INSERT INTO messages (sender, receiver, text, time, type) VALUES (?, ?, ?, ?, ?)",
            (payload.caller, payload.callee, body, str(now), "call"),
        )
        conn.commit()
        conn.close()

    _notify_user(
        payload.callee,
        title=f"Call from {payload.caller}",
        body="Call request",
        data={"event": "call", "call_id": call_id, "chat_type": "call", "sender": payload.caller},
    )

    return {"status": "ok", "call_id": call_id}


@app.post("/calls/respond")
async def calls_respond(payload: CallRespondModel):
    if not is_valid_session(payload.token, payload.username):
        raise HTTPException(status_code=401, detail="Invalid session")

    allowed = {"accepted", "declined", "ended", "missed"}
    if payload.status not in allowed:
        raise HTTPException(status_code=400, detail="Invalid status")

    with db_lock:
        conn = get_db()
        row = conn.execute("SELECT caller, callee, started_at FROM call_logs WHERE id=?", (payload.call_id,)).fetchone()
        if not row:
            conn.close()
            raise HTTPException(status_code=404, detail="Call not found")

        caller, callee, started_at = row[0], row[1], row[2]
        now = time.time()
        duration = None
        ended_at = None
        if payload.status in {"ended", "declined", "missed"}:
            ended_at = now
            if started_at:
                duration = int(max(0, now - float(started_at)))

        conn.execute(
            "UPDATE call_logs SET status=?, ended_at=?, duration=? WHERE id=?",
            (payload.status, ended_at, duration, payload.call_id),
        )

        other = callee if payload.username == caller else caller
        body = json.dumps({
            "call_id": payload.call_id,
            "status": payload.status,
            "caller": caller,
            "callee": callee,
        })
        conn.execute(
            "INSERT INTO messages (sender, receiver, text, time, type) VALUES (?, ?, ?, ?, ?)",
            (payload.username, other, body, str(now), "call"),
        )
        conn.commit()
        conn.close()

    return {"status": "ok"}


@app.get("/data/usage")
async def data_usage(username: str, token: str):
    if not is_valid_session(token, username):
        try:
            ip = websocket.client.host if websocket.client else "unknown"
        except Exception:
            ip = "unknown"
        logger.info(f"WS reject: user={username} token=***{str(token)[-6:]} ip={ip}")
        raise HTTPException(status_code=401, detail="Invalid session")

    now = time.time()
    day = now - 86400
    week = now - 86400 * 7
    month = now - 86400 * 30

    def _sum(conn, since):
        up = conn.execute(
            "SELECT COALESCE(SUM(bytes), 0) FROM data_usage WHERE username=? AND direction='upload' AND ts>=?",
            (username, since),
        ).fetchone()[0]
        down = conn.execute(
            "SELECT COALESCE(SUM(bytes), 0) FROM data_usage WHERE username=? AND direction='download' AND ts>=?",
            (username, since),
        ).fetchone()[0]
        return int(up or 0), int(down or 0)

    with db_lock:
        conn = get_db()
        day_up, day_down = _sum(conn, day)
        week_up, week_down = _sum(conn, week)
        month_up, month_down = _sum(conn, month)
        conn.close()

    return {
        "status": "ok",
        "day": {"upload": day_up, "download": day_down},
        "week": {"upload": week_up, "download": week_down},
        "month": {"upload": month_up, "download": month_down},
    }


@app.post("/data/usage")
async def data_usage_sync(payload: UsageSync):
    if not is_valid_session(payload.token, payload.username):
        raise HTTPException(status_code=401, detail="Invalid session")

    with db_lock:
        conn = get_db()
        for item in payload.items:
            ts = item.ts or time.time()
            conn.execute(
                "INSERT INTO data_usage (username, direction, bytes, kind, ts) VALUES (?, ?, ?, ?, ?)",
                (payload.username, item.direction, int(item.bytes), item.kind or "api", ts),
            )
        conn.commit()
        conn.close()

    return {"status": "ok"}


@app.get("/data/downloads")
async def data_downloads(username: str, token: str, limit: int = 50):
    if not is_valid_session(token, username):
        try:
            ip = websocket.client.host if websocket.client else "unknown"
        except Exception:
            ip = "unknown"
        logger.info(f"WS reject: user={username} token=***{str(token)[-6:]} ip={ip}")
        raise HTTPException(status_code=401, detail="Invalid session")
    with db_lock:
        conn = get_db()
        rows = conn.execute(
            "SELECT * FROM downloads WHERE username=? ORDER BY ts DESC LIMIT ?",
            (username, limit),
        ).fetchall()
        conn.close()
    return {"status": "ok", "data": [dict(r) for r in rows]}


@app.post("/upload")
async def upload_file(
    sender: str = Form(...),
    receiver: str = Form(...),
    token: str = Form(...),
    file: UploadFile = File(...),
    reply_to: int = Form(None),
    ttl_seconds: int = Form(None),
):
    if not is_valid_session(token, sender):
        raise HTTPException(status_code=401, detail="Invalid session")

    try:
        file.file.seek(0, os.SEEK_END)
        size = file.file.tell()
        file.file.seek(0)
    except Exception:
        size = 0

    file_type, is_valid = validate_file_upload(file.filename, file.content_type or "", size)
    if not is_valid:
        raise HTTPException(status_code=400, detail=file_type)

    try:
        file.file.seek(0, os.SEEK_END)
        size = file.file.tell()
        file.file.seek(0)
    except Exception:
        size = 0

    file_type, is_valid = validate_file_upload(file.filename, file.content_type or "", size)
    if not is_valid or file_type != "image":
        raise HTTPException(status_code=400, detail="Invalid image upload")

    file_ext = os.path.splitext(file.filename)[1]
    safe_name = f"{uuid.uuid4().hex}{file_ext}"
    path = os.path.join(UPLOAD_DIR, safe_name)

    with open(path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    expires_at = (time.time() + ttl_seconds) if ttl_seconds else None
    is_collective = receiver.startswith("group_") or receiver.startswith("channel_")

    with db_lock:
        conn = get_db()
        if is_collective:
            conn.execute(
                "INSERT INTO group_messages (chat_id, sender, text, time, reply_to, attachments, expires_at, type) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (receiver, sender, safe_name, str(time.time()), reply_to, None, expires_at, "file"),
            )
        else:
            conn.execute(
                "INSERT INTO messages (sender, receiver, text, time, reply_to, expires_at, type) VALUES (?, ?, ?, ?, ?, ?, ?)",
                (sender, receiver, safe_name, str(time.time()), reply_to, expires_at, "file"),
            )
        conn.commit()
        conn.close()

    _log_data_usage(sender, "upload", os.path.getsize(path), "file")

    return {"status": "ok", "file": safe_name}


@app.get("/download/{file_name}")
async def download_file(file_name: str, request: Request, username: Optional[str] = None, token: Optional[str] = None):
    path = os.path.join(UPLOAD_DIR, os.path.basename(file_name))
    if not os.path.exists(path):
        return JSONResponse(status_code=404, content={"ok": False, "error": "File not found"})

    # Support auth via headers (preferred) or query params (legacy)
    hdr_username = request.headers.get("x-username") or username
    hdr_token = request.headers.get("x-session-token") or token

    if hdr_username and hdr_token and is_valid_session(hdr_token, hdr_username):
        size = os.path.getsize(path)
        _log_data_usage(hdr_username, "download", size, "file")
        _log_download(hdr_username, os.path.basename(file_name), size)

    return FileResponse(path)

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

