# ===================================================================
# BACKEND SECURITY FIXES FOR NiosMess
# ===================================================================
# This file contains code snippets to fix critical security issues
# Apply these changes to api.py and messenger.py
# ===================================================================

import os
import secrets
import hashlib
import time
from passlib.hash import argon2
from typing import Optional

# ===================================================================
# FIX 1: PASSWORD HASHING (CRITICAL)
# ===================================================================
# Replace plaintext password storage with Argon2 hashing

class PasswordManager:
    """Secure password hashing using Argon2"""

    @staticmethod
    def hash_password(password: str) -> str:
        """Hash password using Argon2"""
        return argon2.hash(password)

    @staticmethod
    def verify_password(password: str, hashed: str) -> bool:
        """Verify password against hash"""
        try:
            return argon2.verify(password, hashed)
        except:
            return False

    @staticmethod
    def needs_rehash(hashed: str) -> bool:
        """Check if password needs rehashing (security upgrade)"""
        return argon2.needs_update(hashed)

# USAGE IN api.py:
#
# Line 1939 - Registration:
# BEFORE:
#   conn.execute("INSERT INTO users ... VALUES (?, ?, ?, ?)",
#                (username, email, data.password, name))
#
# AFTER:
#   hashed_password = PasswordManager.hash_password(data.password)
#   conn.execute("INSERT INTO users ... VALUES (?, ?, ?, ?)",
#                (username, email, hashed_password, name))
#
# Line 1984 - Login:
# BEFORE:
#   if not user or user["password"] != password:
#
# AFTER:
#   if not user or not PasswordManager.verify_password(password, user["password"]):

# ===================================================================
# FIX 2: ENVIRONMENT VARIABLES FOR SECRETS (CRITICAL)
# ===================================================================

# Create .env file with:
# ROOT_TOKEN=<generate-secure-token-here>
# SMTP_USER=your-email@gmail.com
# SMTP_PWD=your-app-password
# JWT_SECRET=<generate-secure-secret>
# DATABASE_URL=sqlite:///./niosmess.db
# API_BASE_URL=https://web.sa2rn.fun

from dotenv import load_dotenv

load_dotenv()

# REPLACE in api.py line 85-99:
ROOT_TOKEN = os.getenv("ROOT_TOKEN")
if not ROOT_TOKEN:
    raise ValueError("ROOT_TOKEN must be set in .env file")

SMTP_USER = os.getenv("SMTP_USER")
SMTP_PWD = os.getenv("SMTP_PWD")
JWT_SECRET = os.getenv("JWT_SECRET", secrets.token_urlsafe(32))

# ===================================================================
# FIX 3: SQL INJECTION PREVENTION (HIGH)
# ===================================================================

# Create whitelist for table names
ALLOWED_TABLES = {
    'messages': 'messages',
    'group_messages': 'group_messages',
    'collective_chats': 'collective_chats'
}

def validate_table_name(table: str) -> str:
    """Validate and sanitize table name"""
    if table not in ALLOWED_TABLES:
        raise ValueError(f"Invalid table name: {table}")
    return ALLOWED_TABLES[table]

# USAGE in api.py line 1127:
# BEFORE:
#   conn.execute(f"UPDATE {table} SET is_pinned=? WHERE id=?", ...)
#
# AFTER:
#   safe_table = validate_table_name(table)
#   conn.execute(f"UPDATE {safe_table} SET is_pinned=? WHERE id=?", ...)

# ===================================================================
# FIX 4: SECURE SESSION TOKEN GENERATION
# ===================================================================

class SessionManager:
    """Secure session token management"""

    @staticmethod
    def generate_token() -> str:
        """Generate cryptographically secure token"""
        return secrets.token_urlsafe(32)

    @staticmethod
    def hash_token(token: str) -> str:
        """Hash token for storage (optional extra security)"""
        return hashlib.sha256(token.encode()).hexdigest()

    @staticmethod
    def create_session(username: str, device: str, ip: str) -> dict:
        """Create new session with secure token"""
        token = SessionManager.generate_token()
        session = {
            'token': token,
            'username': username,
            'device': device,
            'ip': ip,
            'created_at': time.time(),
            'expires_at': time.time() + (30 * 24 * 60 * 60)  # 30 days
        }
        return session

# USAGE in api.py line 2016:
# REPLACE:
#   new_token = str(uuid.uuid4())
# WITH:
#   session_data = SessionManager.create_session(username, ua, ip)
#   new_token = session_data['token']

# ===================================================================
# FIX 5: RATE LIMITING FOR AUTHENTICATION
# ===================================================================

from collections import defaultdict
from datetime import datetime, timedelta

class RateLimiter:
    """Simple in-memory rate limiter"""

    def __init__(self, max_attempts: int = 5, window_minutes: int = 15):
        self.max_attempts = max_attempts
        self.window = timedelta(minutes=window_minutes)
        self.attempts = defaultdict(list)

    def is_allowed(self, identifier: str) -> bool:
        """Check if request is allowed"""
        now = datetime.now()
        # Clean old attempts
        self.attempts[identifier] = [
            ts for ts in self.attempts[identifier]
            if now - ts < self.window
        ]

        if len(self.attempts[identifier]) >= self.max_attempts:
            return False

        self.attempts[identifier].append(now)
        return True

    def reset(self, identifier: str):
        """Reset attempts for identifier"""
        self.attempts.pop(identifier, None)

# Global rate limiter
login_limiter = RateLimiter(max_attempts=5, window_minutes=15)

# USAGE in api.py login endpoint (line 1970):
# ADD BEFORE authentication:
#   if not login_limiter.is_allowed(username):
#       raise HTTPException(status_code=429, detail="Too many login attempts")

# ===================================================================
# FIX 6: SECURE CORS CONFIGURATION
# ===================================================================

# REPLACE in api.py line 128:
# BEFORE:
#   allow_origins=["*"],
#
# AFTER:
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "https://web.sa2rn.fun").split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
    expose_headers=["Content-Disposition"]
)

# ===================================================================
# FIX 7: INPUT VALIDATION
# ===================================================================

import re
from pydantic import BaseModel, validator, EmailStr

class UserRegistration(BaseModel):
    username: str
    email: EmailStr
    password: str
    name: str

    @validator('username')
    def validate_username(cls, v):
        if not v or len(v) < 3 or len(v) > 20:
            raise ValueError('Username must be 3-20 characters')
        if not re.match(r'^[a-zA-Z0-9_]+$', v):
            raise ValueError('Username can only contain letters, numbers, and underscores')
        return v

    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        if not re.search(r'[A-Z]', v):
            raise ValueError('Password must contain uppercase letter')
        if not re.search(r'[a-z]', v):
            raise ValueError('Password must contain lowercase letter')
        if not re.search(r'[0-9]', v):
            raise ValueError('Password must contain number')
        return v

    @validator('name')
    def validate_name(cls, v):
        if not v or len(v) < 2 or len(v) > 50:
            raise ValueError('Name must be 2-50 characters')
        return v

# USAGE: Replace line 1899 UserReg model with UserRegistration

# ===================================================================
# FIX 8: SEARCH QUERY SANITIZATION
# ===================================================================

def sanitize_search_query(query: str) -> str:
    """Sanitize search query to prevent LIKE injection"""
    # Remove or escape special SQL LIKE characters
    query = query.replace('%', r'\%').replace('_', r'\_')
    # Limit length
    query = query[:100]
    return query

# USAGE in api.py line 1378:
# BEFORE:
#   c.execute(f"SELECT ... WHERE text LIKE ?", (chat_id, f"%{q}%"))
#
# AFTER:
#   safe_query = sanitize_search_query(q)
#   c.execute(f"SELECT ... WHERE text LIKE ? ESCAPE '\\'",
#             (chat_id, f"%{safe_query}%"))

# ===================================================================
# FIX 9: PREVENT RACE CONDITIONS IN USER REGISTRATION
# ===================================================================

# REPLACE in api.py line 1906-1920:
# Use transaction with proper locking

def register_user_safe(conn, username, email, password, name):
    """Thread-safe user registration"""
    conn.execute("BEGIN EXCLUSIVE")  # Lock database
    try:
        # Check if exists
        existing = conn.execute(
            "SELECT email, username FROM users WHERE email=? OR username=?",
            (email, username)
        ).fetchone()

        if existing:
            conn.execute("ROLLBACK")
            if existing["email"] == email:
                raise ValueError("Email already registered")
            else:
                raise ValueError("Username already taken")

        # Hash password
        hashed = PasswordManager.hash_password(password)

        # Insert user
        conn.execute(
            "INSERT INTO users (username, email, password, name) VALUES (?, ?, ?, ?)",
            (username, email, hashed, name)
        )

        conn.execute("COMMIT")
        return {"status": "ok", "username": username}

    except Exception as e:
        conn.execute("ROLLBACK")
        raise e

# ===================================================================
# FIX 10: FILE UPLOAD SECURITY
# ===================================================================

ALLOWED_EXTENSIONS = {
    'image': {'.jpg', '.jpeg', '.png', '.gif', '.webp'},
    'video': {'.mp4', '.mov', '.avi', '.mkv'},
    'audio': {'.mp3', '.wav', '.ogg', '.m4a'},
    'document': {'.pdf', '.doc', '.docx', '.txt', '.md'}
}

MAX_FILE_SIZES = {
    'image': 10 * 1024 * 1024,   # 10 MB
    'video': 100 * 1024 * 1024,  # 100 MB
    'audio': 20 * 1024 * 1024,   # 20 MB
    'document': 50 * 1024 * 1024 # 50 MB
}

def validate_file_upload(filename: str, content_type: str, size: int) -> tuple[str, bool]:
    """Validate file upload"""
    ext = os.path.splitext(filename)[1].lower()

    # Determine file type
    file_type = None
    for ftype, extensions in ALLOWED_EXTENSIONS.items():
        if ext in extensions:
            file_type = ftype
            break

    if not file_type:
        return "File type not allowed", False

    if size > MAX_FILE_SIZES[file_type]:
        return f"File too large (max {MAX_FILE_SIZES[file_type] // 1024 // 1024}MB)", False

    return file_type, True

# USAGE in api.py line 939:
# ADD BEFORE saving file:
#   file_type, is_valid = validate_file_upload(filename, content_type, size)
#   if not is_valid:
#       raise HTTPException(status_code=400, detail=file_type)

# ===================================================================
# FIX 11: SECURE ERROR HANDLING
# ===================================================================

import logging
from fastapi import Request
from fastapi.responses import JSONResponse

# Setup logger
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('niosmess.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

@app.middleware("http")
async def error_handler_middleware(request: Request, call_next):
    """Global error handler - don't expose internal errors"""
    try:
        return await call_next(request)
    except Exception as e:
        # Log full error internally
        logger.error(f"Error processing {request.url}: {str(e)}", exc_info=True)

        # Return generic error to client
        return JSONResponse(
            status_code=500,
            content={"detail": "Internal server error"}
        )

# REPLACE line 240 in api.py

# ===================================================================
# FIX 12: DATABASE CONNECTION POOLING
# ===================================================================

import sqlite3
from contextlib import contextmanager

class DatabasePool:
    """Simple SQLite connection pool"""

    def __init__(self, db_path: str, pool_size: int = 5):
        self.db_path = db_path
        self.pool = []
        self.pool_size = pool_size
        self._lock = threading.Lock()

    @contextmanager
    def get_connection(self):
        """Get connection from pool"""
        conn = None
        with self._lock:
            if self.pool:
                conn = self.pool.pop()
            else:
                conn = sqlite3.connect(self.db_path, check_same_thread=False)
                conn.row_factory = sqlite3.Row

        try:
            yield conn
        finally:
            with self._lock:
                if len(self.pool) < self.pool_size:
                    self.pool.append(conn)
                else:
                    conn.close()

# Create global pool
db_pool = DatabasePool("niosmess.db", pool_size=10)

# USAGE:
# REPLACE get_db() with:
def get_db():
    with db_pool.get_connection() as conn:
        yield conn

# ===================================================================
# FIX 13: JWT TOKEN AUTHENTICATION (OPTIONAL ENHANCEMENT)
# ===================================================================

import jwt
from datetime import datetime, timedelta

class JWTManager:
    """JWT token management"""

    def __init__(self, secret: str):
        self.secret = secret

    def create_token(self, username: str, expires_delta: timedelta = timedelta(days=30)) -> str:
        """Create JWT token"""
        expire = datetime.utcnow() + expires_delta
        payload = {
            'username': username,
            'exp': expire,
            'iat': datetime.utcnow()
        }
        return jwt.encode(payload, self.secret, algorithm='HS256')

    def verify_token(self, token: str) -> Optional[dict]:
        """Verify and decode JWT token"""
        try:
            payload = jwt.decode(token, self.secret, algorithms=['HS256'])
            return payload
        except jwt.ExpiredSignatureError:
            return None
        except jwt.InvalidTokenError:
            return None

jwt_manager = JWTManager(JWT_SECRET)

# ===================================================================
# INSTALLATION REQUIREMENTS
# ===================================================================

# Add to requirements.txt:
# passlib[argon2]>=1.7.4
# python-dotenv>=1.0.0
# PyJWT>=2.8.0
# email-validator>=2.1.0

# ===================================================================
# DATABASE MIGRATION SCRIPT
# ===================================================================

def migrate_passwords():
    """One-time migration: hash existing plaintext passwords"""
    conn = sqlite3.connect("niosmess.db")
    conn.row_factory = sqlite3.Row

    # Get all users
    users = conn.execute("SELECT id, username, password FROM users").fetchall()

    for user in users:
        # Check if already hashed (argon2 starts with $argon2)
        if not user['password'].startswith('$argon2'):
            hashed = PasswordManager.hash_password(user['password'])
            conn.execute(
                "UPDATE users SET password=? WHERE id=?",
                (hashed, user['id'])
            )
            print(f"Migrated password for user: {user['username']}")

    conn.commit()
    conn.close()
    print("Password migration completed!")

# Run once: migrate_passwords()

# ===================================================================
# END OF BACKEND FIXES
# ===================================================================
