import enum
from sqlalchemy import (
    Column, Integer, String, Boolean, DateTime,
    ForeignKey, Text, BigInteger, Enum as SAEnum, UniqueConstraint
)
from sqlalchemy.orm import relationship, declarative_base
from sqlalchemy.sql import func

Base = declarative_base()

class ChatType(str, enum.Enum):
    DIRECT = "direct"
    GROUP = "group"
    CHANNEL = "channel"

class MemberRole(str, enum.Enum):
    OWNER = "owner"
    ADMIN = "admin"
    MEMBER = "member"

class MessageType(str, enum.Enum):
    TEXT = "text"
    MEDIA = "media"
    VOICE = "voice"
    CIRCLE = "circle"      # round video ≤ 30 s
    CALL_LOG = "call_log"

class CallStatus(str, enum.Enum):
    RINGING = "ringing"
    ACTIVE = "active"
    ENDED = "ended"
    MISSED = "missed"
    DECLINED = "declined"

# ── Users ─────────────────────────────────────────────────────────────────────
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    username = Column(String(64), unique=True, index=True, nullable=False)
    display_name = Column(String(128), nullable=False)
    bio = Column(Text, default="")
    avatar_path = Column(String(512), nullable=True)
    hashed_password = Column(String(256), nullable=False)
    is_active = Column(Boolean, default=False)
    is_verified = Column(Boolean, default=False)
    is_frozen = Column(Boolean, default=False)
    is_banned = Column(Boolean, default=False)
    spam_block = Column(Boolean, default=False)
    two_fa_enabled = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    sessions = relationship("Session", back_populates="user", cascade="all, delete-orphan")
    sent_messages = relationship("Message", foreign_keys="Message.sender_id", back_populates="sender")
    memberships = relationship("ChatMember", back_populates="user", cascade="all, delete-orphan")
    verification_codes = relationship("VerificationCode", back_populates="user", cascade="all, delete-orphan")
    badges = relationship("UserBadge", back_populates="user", cascade="all, delete-orphan")

class Session(Base):
    __tablename__ = "sessions"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    token_hash = Column(String(256), unique=True, index=True, nullable=False)
    device_info = Column(String(512), nullable=True)
    ip_address = Column(String(64), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    last_active = Column(DateTime(timezone=True), server_default=func.now())
    is_active = Column(Boolean, default=True)
    user = relationship("User", back_populates="sessions")

class VerificationCode(Base):
    __tablename__ = "verification_codes"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    code = Column(String(8), nullable=False)
    purpose = Column(String(32), nullable=False)   # register | 2fa | reset_password
    expires_at = Column(DateTime(timezone=True), nullable=False)
    used = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    user = relationship("User", back_populates="verification_codes")

# ── Badges ────────────────────────────────────────────────────────────────────
class Badge(Base):
    __tablename__ = "badges"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(64), unique=True, nullable=False)
    description = Column(Text, default="")
    icon = Column(String(256), nullable=True)
    color = Column(String(16), default="#4f46e5")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    user_badges = relationship("UserBadge", back_populates="badge", cascade="all, delete-orphan")

class UserBadge(Base):
    __tablename__ = "user_badges"
    __table_args__ = (UniqueConstraint("user_id", "badge_id"),)
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    badge_id = Column(Integer, ForeignKey("badges.id"), nullable=False)
    awarded_at = Column(DateTime(timezone=True), server_default=func.now())
    user = relationship("User", foreign_keys=[user_id], back_populates="badges")
    badge = relationship("Badge", back_populates="user_badges")

# ── Chats ─────────────────────────────────────────────────────────────────────
class Chat(Base):
    __tablename__ = "chats"
    id = Column(Integer, primary_key=True, index=True)
    chat_type = Column(SAEnum(ChatType), nullable=False)
    name = Column(String(128), nullable=True)
    description = Column(Text, nullable=True)
    username = Column(String(64), unique=True, index=True, nullable=True)
    avatar_path = Column(String(512), nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    is_banned = Column(Boolean, default=False)
    comments_enabled = Column(Boolean, default=True)
    # For channels: linked comments group chat id
    comments_chat_id = Column(Integer, ForeignKey("chats.id"), nullable=True)
    # Direct chat user pair
    user1_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    user2_id = Column(Integer, ForeignKey("users.id"), nullable=True)

    members = relationship("ChatMember", back_populates="chat", cascade="all, delete-orphan",
                           foreign_keys="ChatMember.chat_id")
    messages = relationship("Message", back_populates="chat", cascade="all, delete-orphan",
                            foreign_keys="Message.chat_id")
    creator = relationship("User", foreign_keys=[created_by])
    user1 = relationship("User", foreign_keys=[user1_id])
    user2 = relationship("User", foreign_keys=[user2_id])

class ChatMember(Base):
    __tablename__ = "chat_members"
    id = Column(Integer, primary_key=True, index=True)
    chat_id = Column(Integer, ForeignKey("chats.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    role = Column(SAEnum(MemberRole), default=MemberRole.MEMBER)
    is_muted = Column(Boolean, default=False)
    is_banned = Column(Boolean, default=False)
    joined_at = Column(DateTime(timezone=True), server_default=func.now())
    chat = relationship("Chat", back_populates="members", foreign_keys=[chat_id])
    user = relationship("User", back_populates="memberships")

# ── Messages ──────────────────────────────────────────────────────────────────
class Message(Base):
    __tablename__ = "messages"
    id = Column(Integer, primary_key=True, index=True)
    chat_id = Column(Integer, ForeignKey("chats.id"), nullable=False)
    sender_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    reply_to_id = Column(Integer, ForeignKey("messages.id"), nullable=True)
    msg_type = Column(SAEnum(MessageType), default=MessageType.TEXT)
    # AES-256-GCM encrypted text
    encrypted_content = Column(Text, nullable=True)
    content_iv = Column(String(64), nullable=True)
    content_tag = Column(String(64), nullable=True)
    # Media / voice / circle
    media_path = Column(String(512), nullable=True)
    media_type = Column(String(64), nullable=True)
    media_name = Column(String(256), nullable=True)
    media_size = Column(BigInteger, nullable=True)
    media_duration = Column(Integer, nullable=True)   # seconds
    # Comments counter (for channel posts)
    comments_count = Column(Integer, default=0)
    is_deleted = Column(Boolean, default=False)
    sent_at = Column(DateTime(timezone=True), server_default=func.now())
    edited_at = Column(DateTime(timezone=True), nullable=True)

    sender = relationship("User", foreign_keys=[sender_id], back_populates="sent_messages")
    chat = relationship("Chat", back_populates="messages", foreign_keys=[chat_id])
    reply_to = relationship("Message", remote_side=[id], foreign_keys=[reply_to_id])
    reactions = relationship("MessageReaction", back_populates="message", cascade="all, delete-orphan")

class MessageReaction(Base):
    __tablename__ = "message_reactions"
    __table_args__ = (UniqueConstraint("message_id", "user_id", "emoji"),)
    id = Column(Integer, primary_key=True, index=True)
    message_id = Column(Integer, ForeignKey("messages.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    emoji = Column(String(16), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    message = relationship("Message", back_populates="reactions")

class UnreadCounter(Base):
    """Per-user per-chat unread message count."""
    __tablename__ = "unread_counters"
    __table_args__ = (UniqueConstraint("chat_id", "user_id"),)
    id = Column(Integer, primary_key=True, index=True)
    chat_id = Column(Integer, ForeignKey("chats.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    count = Column(Integer, default=0)
    last_message_id = Column(Integer, ForeignKey("messages.id"), nullable=True)

# ── Media uploads ─────────────────────────────────────────────────────────────
class MediaUploadChunk(Base):
    __tablename__ = "media_upload_chunks"
    id = Column(Integer, primary_key=True, index=True)
    upload_id = Column(String(64), unique=True, index=True, nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    filename = Column(String(256), nullable=False)
    total_chunks = Column(Integer, nullable=False)
    received_chunks = Column(Integer, default=0)
    temp_path = Column(String(512), nullable=False)
    media_subtype = Column(String(32), default="media")  # media | voice | circle
    created_at = Column(DateTime(timezone=True), server_default=func.now())

# ── Calls ─────────────────────────────────────────────────────────────────────
class Call(Base):
    __tablename__ = "calls"
    id = Column(Integer, primary_key=True, index=True)
    chat_id = Column(Integer, ForeignKey("chats.id"), nullable=False)
    initiator_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    is_video = Column(Boolean, default=False)
    status = Column(SAEnum(CallStatus), default=CallStatus.RINGING)
    started_at = Column(DateTime(timezone=True), server_default=func.now())
    ended_at = Column(DateTime(timezone=True), nullable=True)
    duration_seconds = Column(Integer, nullable=True)
    participants = relationship("CallParticipant", back_populates="call", cascade="all, delete-orphan")

class CallParticipant(Base):
    __tablename__ = "call_participants"
    id = Column(Integer, primary_key=True, index=True)
    call_id = Column(Integer, ForeignKey("calls.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    joined_at = Column(DateTime(timezone=True), server_default=func.now())
    left_at = Column(DateTime(timezone=True), nullable=True)
    is_active = Column(Boolean, default=True)
    call = relationship("Call", back_populates="participants")
