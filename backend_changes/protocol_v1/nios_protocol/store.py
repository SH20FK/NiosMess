"""An independent protocol database; legacy message tables are never opened here."""

from __future__ import annotations

import asyncio
from pathlib import Path
import sqlite3
from typing import Callable, TypeVar

T = TypeVar("T")

SCHEMA = """
CREATE TABLE IF NOT EXISTS identities (
 account_id TEXT PRIMARY KEY, identity_key TEXT NOT NULL,
 created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS devices (
 device_id TEXT PRIMARY KEY, account_id TEXT NOT NULL,
 user_id INTEGER NOT NULL, session_id INTEGER UNIQUE, session_fingerprint TEXT,
 identity_key TEXT NOT NULL, mls_key TEXT, link_key TEXT NOT NULL,
 endpoint_key TEXT, legacy_key TEXT, capabilities TEXT NOT NULL,
 revoked INTEGER NOT NULL DEFAULT 0, revision INTEGER NOT NULL DEFAULT 1,
 statement_hash TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
 FOREIGN KEY(account_id) REFERENCES identities(account_id)
);
CREATE INDEX IF NOT EXISTS devices_account ON devices(account_id, revoked);
CREATE TABLE IF NOT EXISTS enrollment_challenges (
 challenge TEXT PRIMARY KEY, account_id TEXT NOT NULL, session_id INTEGER NOT NULL,
 session_fingerprint TEXT,
 device_id TEXT NOT NULL, expires_at INTEGER NOT NULL, consumed INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS device_history (
 id INTEGER PRIMARY KEY AUTOINCREMENT, account_id TEXT NOT NULL,
 device_id TEXT NOT NULL, action TEXT NOT NULL, registration TEXT NOT NULL,
 signature TEXT NOT NULL, created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS envelopes (
 ordinal INTEGER PRIMARY KEY AUTOINCREMENT, digest TEXT NOT NULL UNIQUE,
 sender TEXT NOT NULL, recipient TEXT NOT NULL, session TEXT NOT NULL,
 operation_id TEXT NOT NULL, kind TEXT NOT NULL, envelope TEXT NOT NULL,
 size INTEGER NOT NULL, pending INTEGER NOT NULL DEFAULT 1,
 created_at INTEGER NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS unique_link_operation
 ON envelopes(sender, recipient, session, operation_id) WHERE kind='operation';
CREATE INDEX IF NOT EXISTS inbox_pending ON envelopes(recipient, pending, ordinal);
CREATE TABLE IF NOT EXISTS mailbox_usage (
 device_id TEXT PRIMARY KEY, record_count INTEGER NOT NULL, byte_count INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS protocol_outbox (
 id INTEGER PRIMARY KEY AUTOINCREMENT, device_id TEXT NOT NULL,
 category TEXT NOT NULL, object_id TEXT NOT NULL,
 created_at INTEGER NOT NULL, notified INTEGER NOT NULL DEFAULT 0,
 UNIQUE(device_id, category, object_id)
);
CREATE TABLE IF NOT EXISTS kt_accounts (
 account_id TEXT PRIMARY KEY, revision INTEGER NOT NULL, head_hash TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS kt_identity_pins (
 account_id TEXT PRIMARY KEY, identity_key TEXT NOT NULL, created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS kt_leaves (
 leaf_index INTEGER PRIMARY KEY, account_id TEXT NOT NULL, revision INTEGER NOT NULL,
 statement TEXT NOT NULL, signature TEXT NOT NULL, encoded_entry BLOB NOT NULL,
 leaf_hash TEXT NOT NULL UNIQUE, created_at INTEGER NOT NULL,
 UNIQUE(account_id, revision)
);
CREATE TABLE IF NOT EXISTS kt_nodes (
 start_index INTEGER NOT NULL, node_size INTEGER NOT NULL, hash BLOB NOT NULL,
 PRIMARY KEY(start_index, node_size)
);
CREATE TABLE IF NOT EXISTS kt_checkpoints (
 tree_size INTEGER PRIMARY KEY, checkpoint TEXT NOT NULL,
 signature TEXT NOT NULL
);
"""


class ProtocolStore:
    """Bounded thread execution, independent connections and explicit commits.

    A callable must be synchronous and must not retain its connection. Transaction
    callbacks are deliberately never retried: repeating arbitrary side effects
    on SQLITE_BUSY would be unsafe. Filesystem publication uses its own journal.
    """

    def __init__(self, path: str | Path, data_root: str | Path):
        self.path = Path(path).resolve()
        self.data_root = Path(data_root).resolve()
        self._slots = asyncio.Semaphore(4)
        self._initializing = asyncio.Lock()
        self._ready = False

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.path, timeout=30, isolation_level=None)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys=ON")
        connection.execute("PRAGMA busy_timeout=30000")
        connection.execute("PRAGMA synchronous=FULL")
        return connection

    async def initialize(self) -> None:
        if self._ready:
            return
        async with self._initializing:
            if self._ready:
                return
            self.path.parent.mkdir(parents=True, exist_ok=True)
            self.data_root.mkdir(parents=True, exist_ok=True)

            def initialize() -> None:
                connection = self._connect()
                try:
                    connection.execute("PRAGMA journal_mode=WAL")
                    connection.executescript("BEGIN IMMEDIATE;" + SCHEMA + "COMMIT;")
                finally:
                    connection.close()

            await self._run(initialize)
            self._ready = True

    async def _run(self, callback: Callable[[], T]) -> T:
        async with self._slots:
            task = asyncio.create_task(asyncio.to_thread(callback))
            try:
                return await asyncio.shield(task)
            except asyncio.CancelledError:
                # A cancelled HTTP request does not cancel SQLite's commit. Keep
                # this bounded slot until its worker finishes; retry is deduped.
                try:
                    await task
                finally:
                    raise

    async def transaction(self, callback: Callable[[sqlite3.Connection], T]) -> T:
        await self.initialize()

        def run() -> T:
            connection = self._connect()
            try:
                connection.execute("BEGIN IMMEDIATE")
                result = callback(connection)
                connection.commit()
                return result
            except BaseException:
                connection.rollback()
                raise
            finally:
                connection.close()

        return await self._run(run)

    async def read(self, callback: Callable[[sqlite3.Connection], T]) -> T:
        await self.initialize()

        def run() -> T:
            connection = self._connect()
            try:
                connection.execute("BEGIN")
                return callback(connection)
            finally:
                connection.rollback()
                connection.close()

        return await self._run(run)

    async def ensure_schema(self, ddl: str) -> None:
        await self.initialize()

        def create() -> None:
            connection = self._connect()
            try:
                connection.executescript("BEGIN IMMEDIATE;" + ddl + "COMMIT;")
            finally:
                connection.close()

        await self._run(create)
