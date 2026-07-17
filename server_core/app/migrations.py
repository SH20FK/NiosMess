"""Auto-migration helpers for SQLite.
Adds new columns/tables without dropping existing data."""
import asyncio
from sqlalchemy import text, inspect
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import engine, AsyncSessionLocal
from app.models.models import Base

async def run_migrations():
    """Run lightweight auto-migrations for SQLite."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    async with AsyncSessionLocal() as db:
        # Helper to check if a column exists in SQLite
        async def column_exists(table: str, column: str) -> bool:
            result = await db.execute(text(f"PRAGMA table_info({table})"))
            rows = result.all()
            return any(r[1] == column for r in rows)
        
        async def table_exists(table: str) -> bool:
            result = await db.execute(text(f"SELECT name FROM sqlite_master WHERE type='table' AND name='{table}'"))
            return result.scalar_one_or_none() is not None
        
        # Add is_bot to users if missing
        if not await column_exists("users", "is_bot"):
            await db.execute(text("ALTER TABLE users ADD COLUMN is_bot INTEGER DEFAULT 0"))
            print("[MIGRATION] Added is_bot to users")
        
        # Add reply_markup to messages if missing
        if not await column_exists("messages", "reply_markup"):
            await db.execute(text("ALTER TABLE messages ADD COLUMN reply_markup TEXT"))
            print("[MIGRATION] Added reply_markup to messages")
        
        # Ensure bots table exists (create_all should have done it, but handle old schemas)
        if not await table_exists("bots"):
            await db.execute(text("""
                CREATE TABLE IF NOT EXISTS bots (
                    id INTEGER PRIMARY KEY,
                    user_id INTEGER NOT NULL UNIQUE,
                    owner_id INTEGER,
                    token TEXT NOT NULL UNIQUE,
                    name TEXT NOT NULL,
                    username TEXT NOT NULL UNIQUE,
                    description TEXT DEFAULT '',
                    is_active INTEGER DEFAULT 1,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """))
            print("[MIGRATION] Created bots table")
        else:
            if not await column_exists("bots", "owner_id"):
                await db.execute(text("ALTER TABLE bots ADD COLUMN owner_id INTEGER"))
                print("[MIGRATION] Added owner_id to bots")
        
        if not await table_exists("bot_updates"):
            await db.execute(text("""
                CREATE TABLE IF NOT EXISTS bot_updates (
                    id INTEGER PRIMARY KEY,
                    bot_id INTEGER NOT NULL,
                    update_type TEXT NOT NULL,
                    payload TEXT NOT NULL,
                    is_delivered INTEGER DEFAULT 0,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """))
            print("[MIGRATION] Created bot_updates table")

        # Add public_key to users for E2EE
        if not await column_exists("users", "public_key"):
            await db.execute(text("ALTER TABLE users ADD COLUMN public_key TEXT"))
            print("[MIGRATION] Added public_key to users")

        # Add is_secret to chats for secret chats
        if not await column_exists("chats", "is_secret"):
            await db.execute(text("ALTER TABLE chats ADD COLUMN is_secret INTEGER DEFAULT 0"))
            print("[MIGRATION] Added is_secret to chats")

        # Add E2EE fields to messages
        if not await column_exists("messages", "e2ee_content"):
            await db.execute(text("ALTER TABLE messages ADD COLUMN e2ee_content TEXT"))
            print("[MIGRATION] Added e2ee_content to messages")

        if not await column_exists("messages", "is_e2ee"):
            await db.execute(text("ALTER TABLE messages ADD COLUMN is_e2ee INTEGER DEFAULT 0"))
            print("[MIGRATION] Added is_e2ee to messages")
        # Add public_key to sessions for Device-specific E2EE
        if not await column_exists("sessions", "public_key"):
            await db.execute(text("ALTER TABLE sessions ADD COLUMN public_key TEXT"))
            print("[MIGRATION] Added public_key to sessions")
        # --- POSTS AND REACTIONS MIGRATIONS ---
        if not await table_exists("posts"):
            await db.execute(text("""
                CREATE TABLE IF NOT EXISTS posts (
                    id INTEGER PRIMARY KEY,
                    author_id INTEGER NOT NULL,
                    content TEXT,
                    media_path TEXT,
                    likes_count INTEGER DEFAULT 0,
                    dislikes_count INTEGER DEFAULT 0,
                    comments_count INTEGER DEFAULT 0,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY(author_id) REFERENCES users(id)
                )
            """))
            print("[MIGRATION] Created posts table")

        if not await table_exists("post_reactions"):
            await db.execute(text("""
                CREATE TABLE IF NOT EXISTS post_reactions (
                    id INTEGER PRIMARY KEY,
                    post_id INTEGER NOT NULL,
                    user_id INTEGER NOT NULL,
                    is_like INTEGER NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY(post_id) REFERENCES posts(id),
                    FOREIGN KEY(user_id) REFERENCES users(id),
                    UNIQUE(post_id, user_id)
                )
            """))
            print("[MIGRATION] Created post_reactions table")

        if not await table_exists("post_comments"):
            await db.execute(text("""
                CREATE TABLE IF NOT EXISTS post_comments (
                    id INTEGER PRIMARY KEY,
                    post_id INTEGER NOT NULL,
                    author_id INTEGER NOT NULL,
                    content TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY(post_id) REFERENCES posts(id),
                    FOREIGN KEY(author_id) REFERENCES users(id)
                )
            """))
            print("[MIGRATION] Created post_comments table")

        if not await table_exists("subscriptions"):
            await db.execute(text("""
                CREATE TABLE IF NOT EXISTS subscriptions (
                    id INTEGER PRIMARY KEY,
                    follower_id INTEGER NOT NULL,
                    followed_id INTEGER NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY(follower_id) REFERENCES users(id),
                    FOREIGN KEY(followed_id) REFERENCES users(id),
                    UNIQUE(follower_id, followed_id)
                )
            """))
            print("[MIGRATION] Created subscriptions table")

        await db.commit()