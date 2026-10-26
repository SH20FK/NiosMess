import enum
from datetime import datetime, timezone
from sqlalchemy import (
    Column, Integer, String, Boolean, Date, DateTime,
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
    CIRCLE = "circle"
    CALL_LOG = "call_log"
    STICKER = "sticker"


class CallStatus(str, enum.Enum):
    RINGING = "ringing"
    ACTIVE = "active"
    ENDED = "ended"
    MISSED = "missed"
    DECLINED = "declined"


class UserFCMToken(Base):
    notification_preferences = Column(Text, nullable=True)
    __tablename__ = "users_fcm_tokens"
    session_id = Column(Integer, nullable=True)

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    fcm_token = Column(String, unique=True, nullable=False, index=True)
    platform = Column(String, default="unknown")
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class Subscription(Base):
    __tablename__ = "subscriptions"

    id = Column(Integer, primary_key=True, index=True)
    follower_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    followed_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class Post(Base):
    __tablename__ = "posts"

    id = Column(Integer, primary_key=True, index=True)
    author_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    content = Column(String, nullable=True)
    media_path = Column(String, nullable=True)
    media_json = Column(Text, nullable=True)
    ai_tags_json = Column(Text, nullable=True)
    interactive_json = Column(Text, nullable=True)
    likes_count = Column(Integer, default=0)
    dislikes_count = Column(Integer, default=0)
    comments_count = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class PostReaction(Base):
    __tablename__ = "post_reactions"

    id = Column(Integer, primary_key=True, index=True)
    post_id = Column(Integer, ForeignKey("posts.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    is_like = Column(Boolean, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class PostCommentReaction(Base):
    __tablename__ = 'post_comment_reactions'
    comment_id = Column(Integer, ForeignKey('post_comments.id'), primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'), primary_key=True)
    emoji = Column(String(32), nullable=False)


class PostComment(Base):
    __tablename__ = "post_comments"
    reply_to_id = Column(Integer, ForeignKey('post_comments.id'), nullable=True)
    edited_at = Column(DateTime(timezone=True), nullable=True)
    is_deleted = Column(Boolean, nullable=False, default=False)
    ai_source = Column(String(96), nullable=True, unique=True)

    id = Column(Integer, primary_key=True, index=True)
    post_id = Column(Integer, ForeignKey("posts.id"), nullable=False)
    author_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    content = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    nios_id = Column(String(64), unique=True, index=True, nullable=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    username = Column(String(64), unique=True, index=True, nullable=False)
    display_name = Column(String(128), nullable=False)
    bio = Column(Text, default="")
    avatar_path = Column(String(512), nullable=True)
    avatar_is_video = Column(Boolean, default=False)
    avatar_duration = Column(Integer, nullable=True)
    phone_number = Column(String(32), nullable=True)
    birthday = Column(Date, nullable=True)
    working_hours_json = Column(Text, nullable=True)
    ai_chars_used = Column(Integer, nullable=False, default=0)
    ai_window_started_at = Column(DateTime(timezone=True), nullable=True)
    niosai_greeted = Column(Boolean, nullable=False, default=False)
    ai_model = Column(String(16), nullable=True)  # 'qwen' | 'luna'; None = default for the plan
    is_pending_deletion = Column(Boolean, nullable=False, default=False)
    deletion_requested_at = Column(DateTime(timezone=True), nullable=True)
    deletion_scheduled_at = Column(DateTime(timezone=True), nullable=True)
    hashed_password = Column(String(256), nullable=False)
    is_active = Column(Boolean, default=False)
    is_verified = Column(Boolean, default=False)
    is_frozen = Column(Boolean, default=False)
    is_banned = Column(Boolean, default=False)
    spam_block = Column(Boolean, default=False)
    spam_block_until = Column(DateTime(timezone=True), nullable=True)
    spam_block_reason = Column(String(512), nullable=True)
    two_fa_enabled = Column(Boolean, default=False)
    is_bot = Column(Boolean, default=False)
    is_nios_plus = Column(Boolean, nullable=False, default=False)
    nios_plus_expires_at = Column(DateTime(timezone=True), nullable=True)
    nios_plus_trial_used = Column(Boolean, nullable=False, default=False)
    nios_plus_grace_until = Column(DateTime(timezone=True), nullable=True)
    status_emoji_shortcode = Column(String(64), nullable=True)
    public_key = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    sessions = relationship("Session", back_populates="user", cascade="all, delete-orphan")
    sent_messages = relationship("Message", foreign_keys="Message.sender_id", back_populates="sender")
    memberships = relationship("ChatMember", back_populates="user", cascade="all, delete-orphan")
    verification_codes = relationship("VerificationCode", back_populates="user", cascade="all, delete-orphan")
    badges = relationship("UserBadge", back_populates="user", cascade="all, delete-orphan")
    bot = relationship("Bot", back_populates="user", uselist=False, cascade="all, delete-orphan", foreign_keys="Bot.user_id")


class Session(Base):
    __tablename__ = "sessions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    token_hash = Column(String(256), unique=True, index=True, nullable=False)
    device_info = Column(String(512), nullable=True)
    ip_address = Column(String(64), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    last_active = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime(timezone=True), nullable=True)
    oauth_client_id = Column(String(64), nullable=True)
    is_active = Column(Boolean, default=True)
    public_key = Column(Text, nullable=True)

    user = relationship("User", back_populates="sessions")


class VerificationCode(Base):
    __tablename__ = "verification_codes"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    code = Column(String(8), nullable=False)
    purpose = Column(String(32), nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    used = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="verification_codes")


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
    show_on_profile = Column(Boolean, nullable=False, default=True)

    user = relationship("User", foreign_keys=[user_id], back_populates="badges")
    badge = relationship("Badge", back_populates="user_badges")


class PrivacyRule(Base):
    __tablename__ = "privacy_rules"
    __table_args__ = (UniqueConstraint("user_id", "rule_key"),)

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    rule_key = Column(String(32), nullable=False)
    default_policy = Column(String(16), nullable=False, default="everyone")
    allow_user_ids_json = Column(Text, nullable=False, default="[]")
    deny_user_ids_json = Column(Text, nullable=False, default="[]")
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class UserBlock(Base):
    __tablename__ = "user_blocks"
    __table_args__ = (UniqueConstraint("blocker_id", "blocked_id"),)

    id = Column(Integer, primary_key=True)
    blocker_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    blocked_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


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
    is_private = Column(Boolean, default=False)
    invite_token = Column(String(64), unique=True, nullable=True)
    auto_delete_seconds = Column(Integer, nullable=True)
    is_secret = Column(Boolean, default=False)
    user1_public_key = Column(Text, nullable=True)
    user2_public_key = Column(Text, nullable=True)
    comments_chat_id = Column(Integer, ForeignKey("chats.id"), nullable=True)
    has_active_space = Column(Boolean, default=False)
    ai_bot_enabled = Column(Boolean, nullable=False, default=False)
    user1_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    user2_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    pinned_message_id = Column(Integer, ForeignKey("messages.id"), nullable=True)

    members = relationship("ChatMember", back_populates="chat", cascade="all, delete-orphan", foreign_keys="ChatMember.chat_id")
    messages = relationship("Message", back_populates="chat", cascade="all, delete-orphan", foreign_keys="Message.chat_id")
    creator = relationship("User", foreign_keys=[created_by])
    user1 = relationship("User", foreign_keys=[user1_id])
    user2 = relationship("User", foreign_keys=[user2_id])
    pinned_message = relationship("Message", foreign_keys=[pinned_message_id], post_update=True)


class ChatMember(Base):
    __tablename__ = "chat_members"

    id = Column(Integer, primary_key=True, index=True)
    chat_id = Column(Integer, ForeignKey("chats.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    role = Column(SAEnum(MemberRole), default=MemberRole.MEMBER)
    is_muted = Column(Boolean, default=False)
    is_banned = Column(Boolean, default=False)
    muted_until = Column(DateTime(timezone=True), nullable=True)
    moderation_reason = Column(String(512), nullable=True)
    banned_at = Column(DateTime(timezone=True), nullable=True)
    joined_at = Column(DateTime(timezone=True), server_default=func.now())

    chat = relationship("Chat", back_populates="members", foreign_keys=[chat_id])
    user = relationship("User", back_populates="memberships")


class Message(Base):
    __tablename__ = "messages"
    comment_post_id = Column(Integer, nullable=True, index=True)

    id = Column(Integer, primary_key=True, index=True)
    chat_id = Column(Integer, ForeignKey("chats.id"), nullable=False)
    sender_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    reply_to_id = Column(Integer, ForeignKey("messages.id"), nullable=True)
    msg_type = Column(SAEnum(MessageType), default=MessageType.TEXT)
    encrypted_content = Column(Text, nullable=True)
    content_iv = Column(String(64), nullable=True)
    content_tag = Column(String(64), nullable=True)
    client_message_id = Column(String(36), nullable=True)
    e2ee_content = Column(Text, nullable=True)
    is_e2ee = Column(Boolean, default=False)
    media_path = Column(String(512), nullable=True)
    media_type = Column(String(64), nullable=True)
    media_name = Column(String(256), nullable=True)
    media_size = Column(BigInteger, nullable=True)
    media_duration = Column(Integer, nullable=True)
    media_iv = Column(String(64), nullable=True)
    media_tag = Column(String(64), nullable=True)
    comments_count = Column(Integer, default=0)
    is_deleted = Column(Boolean, default=False)
    reply_markup = Column(Text, nullable=True)
    parse_mode = Column(String(16), nullable=True)
    system_event_type = Column(String(32), nullable=True)
    system_event_json = Column(Text, nullable=True)
    sent_at = Column(DateTime(timezone=True), server_default=func.now())
    edited_at = Column(DateTime(timezone=True), nullable=True)
    expires_at = Column(DateTime(timezone=True), nullable=True, index=True)

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
    __tablename__ = "unread_counters"
    __table_args__ = (UniqueConstraint("chat_id", "user_id"),)

    id = Column(Integer, primary_key=True, index=True)
    chat_id = Column(Integer, ForeignKey("chats.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    count = Column(Integer, default=0)
    last_message_id = Column(Integer, ForeignKey("messages.id"), nullable=True)


class MediaUploadChunk(Base):
    __tablename__ = "media_upload_chunks"

    id = Column(Integer, primary_key=True, index=True)
    upload_id = Column(String(64), unique=True, index=True, nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    filename = Column(String(256), nullable=False)
    total_chunks = Column(Integer, nullable=False)
    received_chunks = Column(Integer, default=0)
    received_bytes = Column(Integer, nullable=False, default=0)
    max_bytes = Column(Integer, nullable=False, default=30 * 1024 * 1024)
    temp_path = Column(String(512), nullable=False)
    media_subtype = Column(String(32), default="media")
    created_at = Column(DateTime(timezone=True), server_default=func.now())


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


class Bot(Base):
    __tablename__ = "bots"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True)
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    token = Column(String(64), unique=True, index=True, nullable=False)
    name = Column(String(128), nullable=False)
    username = Column(String(64), unique=True, nullable=False)
    description = Column(Text, default="")
    is_active = Column(Boolean, default=True)
    supports_inline = Column(Boolean, default=False)
    commands_json = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", foreign_keys=[user_id], back_populates="bot")


class StickerSet(Base):
    __tablename__ = "sticker_sets"

    id = Column(Integer, primary_key=True)
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    name = Column(String(64), unique=True, nullable=False)
    title = Column(String(128), nullable=False)
    is_public = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class Sticker(Base):
    __tablename__ = "stickers"

    id = Column(Integer, primary_key=True)
    set_id = Column(Integer, ForeignKey("sticker_sets.id", ondelete="CASCADE"), nullable=False)
    file_path = Column(String(512), nullable=False)
    emoji = Column(String(32), nullable=True)
    width = Column(Integer, nullable=False)
    height = Column(Integer, nullable=False)
    media_type = Column(String(80), nullable=False, default="image/webp")
    duration_seconds = Column(Integer, nullable=True)
    file_size = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class UserStickerSet(Base):
    __tablename__ = "user_sticker_sets"
    __table_args__ = (UniqueConstraint("user_id", "set_id"),)

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    set_id = Column(Integer, ForeignKey("sticker_sets.id", ondelete="CASCADE"), nullable=False)
    added_at = Column(DateTime(timezone=True), server_default=func.now())


class CustomEmojiSet(Base):
    """A pack of custom emoji, mirrors StickerSet. Subject to the per-user pack-count limit,
    except official packs (is_official=True) which are available to every user for free and
    don't count against anyone's quota."""
    __tablename__ = "custom_emoji_sets"

    id = Column(Integer, primary_key=True)
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    name = Column(String(64), unique=True, nullable=False)
    title = Column(String(128), nullable=False)
    is_public = Column(Boolean, default=True)
    is_official = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class CustomEmoji(Base):
    """Small inline emoji, distinct from stickers: rendered inline in message text via
    :shortcode:, up to 8s animation, square (1:1) or landscape up to 2:1 aspect ratio only."""
    __tablename__ = "custom_emojis"

    id = Column(Integer, primary_key=True)
    set_id = Column(Integer, ForeignKey("custom_emoji_sets.id", ondelete="CASCADE"), nullable=False)
    shortcode = Column(String(64), unique=True, nullable=False)
    file_path = Column(String(512), nullable=False)
    media_type = Column(String(80), nullable=False, default="image/webp")
    is_animated = Column(Boolean, nullable=False, default=False)
    is_adaptive = Column(Boolean, nullable=False, default=False)
    duration_seconds = Column(Integer, nullable=True)
    width = Column(Integer, nullable=False)
    height = Column(Integer, nullable=False)
    file_size = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class UserCustomEmojiSet(Base):
    __tablename__ = "user_custom_emoji_sets"
    __table_args__ = (UniqueConstraint("user_id", "set_id"),)

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    set_id = Column(Integer, ForeignKey("custom_emoji_sets.id", ondelete="CASCADE"), nullable=False)
    added_at = Column(DateTime(timezone=True), server_default=func.now())


class BotUpdate(Base):
    __tablename__ = "bot_updates"

    id = Column(Integer, primary_key=True, index=True)
    bot_id = Column(Integer, ForeignKey("bots.id"), nullable=False)
    update_type = Column(String(32), nullable=False)
    payload = Column(Text, nullable=False)
    is_delivered = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class BotInlineQuery(Base):
    __tablename__ = "bot_inline_queries"

    id = Column(String(64), primary_key=True)
    bot_id = Column(Integer, ForeignKey("bots.id", ondelete="CASCADE"), nullable=False)
    requester_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    chat_id = Column(Integer, ForeignKey("chats.id", ondelete="CASCADE"), nullable=False)
    query = Column(String(256), nullable=False)
    results_json = Column(Text, nullable=True)
    answered = Column(Boolean, default=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class Report(Base):
    __tablename__ = "reports"

    id = Column(Integer, primary_key=True, index=True)
    reporter_id = Column(Integer, ForeignKey("users.id"))
    reported_id = Column(Integer, ForeignKey("users.id"))
    chat_id = Column(Integer, ForeignKey("chats.id"))
    reason = Column(String)
    status = Column(String, default="pending")
    automod_verdict = Column(String)
    reported_messages_json = Column(Text)
    created_at = Column(DateTime, default=func.now())


class SupportTicket(Base):
    __tablename__ = "support_tickets"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    ticket_type = Column(String(32), nullable=False, default="support")
    subject = Column(String(160), nullable=False)
    body = Column(Text, nullable=False)
    status = Column(String(24), nullable=False, default="open")
    assigned_admin_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    resolution = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
