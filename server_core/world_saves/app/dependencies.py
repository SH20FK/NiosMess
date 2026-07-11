from datetime import datetime, timezone
from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.services.auth_svc import get_session_by_token, get_user_by_id
from app.models.models import User

security = HTTPBearer()

async def get_current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Every protected endpoint requires: Authorization: Bearer <session_token>"""
    session = await get_session_by_token(db, credentials.credentials)
    if not session:
        raise HTTPException(401, "Invalid or expired session token")
    user = await get_user_by_id(db, session.user_id)
    if not user:
        raise HTTPException(401, "User not found")
    if not user.is_active:
        raise HTTPException(403, "Account not verified. Check your email.")
    if user.is_banned:
        raise HTTPException(403, "Your account has been permanently banned.")
    if user.is_frozen:
        raise HTTPException(403, "Your account is temporarily frozen.")
    session.last_active = datetime.now(timezone.utc)
    return user

async def get_current_user_allow_frozen(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Like get_current_user but allows frozen accounts to read."""
    session = await get_session_by_token(db, credentials.credentials)
    if not session:
        raise HTTPException(401, "Invalid or expired session token")
    user = await get_user_by_id(db, session.user_id)
    if not user or not user.is_active:
        raise HTTPException(401, "Unauthorized")
    if user.is_banned:
        raise HTTPException(403, "Your account has been permanently banned.")
    session.last_active = datetime.now(timezone.utc)
    return user

async def get_optional_user(request: Request, db: AsyncSession = Depends(get_db)):
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "): return None
    session = await get_session_by_token(db, auth[7:])
    if not session: return None
    return await get_user_by_id(db, session.user_id)
