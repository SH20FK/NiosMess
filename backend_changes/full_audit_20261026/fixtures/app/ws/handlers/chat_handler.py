"""Test fixture: verbatim selected source functions; never import production settings."""

async def _require_member(db: AsyncSession, chat_id: int, user_id: int) -> None:
    r = await db.execute(
        select(ChatMember).where(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == user_id,
            ChatMember.is_banned == False,
        )
    )
    if not r.scalar_one_or_none():
        raise ValueError("Not a member")


async def _can_send(db: AsyncSession, chat_id: int, user_id: int) -> ChatMember:
    r = await db.execute(
        select(ChatMember).where(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == user_id,
            ChatMember.is_banned == False,
        )
    )
    m = r.scalar_one_or_none()
    if not m:
        raise ValueError("Cannot post here (not member or banned)")
    if m.is_muted and m.muted_until:
        until = m.muted_until.replace(tzinfo=m.muted_until.tzinfo or timezone.utc)
        if until <= datetime.now(timezone.utc):
            m.is_muted = False
            m.muted_until = None
    if m.is_muted:
        raise ValueError("Cannot post here while muted")
    cr = await db.execute(select(Chat).where(Chat.id == chat_id))
    chat = cr.scalar_one_or_none()
    if chat and chat.is_banned:
        raise ValueError("Chat is banned by admins")
    if chat and chat.chat_type == ChatType.CHANNEL and m.role == MemberRole.MEMBER:
        raise ValueError("Only admins can post in channels")
    return m
