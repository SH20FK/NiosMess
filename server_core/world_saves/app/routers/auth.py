from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, EmailStr, field_validator
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.models import User
from app.services.auth_svc import (validate_password, hash_password, verify_password,
    create_session, get_session_by_token)
from app.services.email_svc import create_code, check_code, send_verify_email, send_2fa_email, send_email
from app.dependencies import get_current_user

router = APIRouter(prefix="/auth", tags=["Auth"])

class RegisterRequest(BaseModel):
    email: EmailStr
    username: str
    display_name: str
    password: str
    @field_validator("username")
    @classmethod
    def clean(cls, v):
        v = v.strip().lower()
        if not all(c.isalnum() or c in "_." for c in v): raise ValueError("Bad chars in username")
        if len(v) < 3 or len(v) > 32: raise ValueError("Username must be 3-32 chars")
        return v

class VerifyEmailRequest(BaseModel):
    email: EmailStr
    code: str

class LoginRequest(BaseModel):
    identifier: str
    password: str

class TwoFARequest(BaseModel):
    identifier: str
    code: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    username: str
    display_name: str

class ResetPasswordRequest(BaseModel):
    email: EmailStr

class ResetPasswordConfirmRequest(BaseModel):
    email: EmailStr
    code: str
    new_password: str

# ── Register ──────────────────────────────────────────────────────────────────

@router.post("/register", status_code=201)
async def register(body: RegisterRequest, db: AsyncSession = Depends(get_db)):
    """Register — sends 6-digit code to email."""
    if not validate_password(body.password):
        raise HTTPException(400, "Password needs ≥8 chars, 1 uppercase letter, 1 digit")
    r = await db.execute(select(User).where(
        (User.email == body.email) | (User.username == body.username)))
    if r.scalar_one_or_none():
        raise HTTPException(400, "Email or username already taken")
    user = User(email=body.email, username=body.username, display_name=body.display_name,
                hashed_password=hash_password(body.password), is_active=False)
    db.add(user); await db.flush()
    code = await create_code(db, user.id, "register", ttl=15)
    await send_verify_email(body.email, body.display_name, code)
    return {"message": "Check your email for the verification code.", "user_id": user.id}

@router.post("/verify-email")
async def verify_email(body: VerifyEmailRequest, db: AsyncSession = Depends(get_db)):
    r = await db.execute(select(User).where(User.email == body.email))
    user = r.scalar_one_or_none()
    if not user: raise HTTPException(404, "User not found")
    if not await check_code(db, user.id, body.code, "register"):
        raise HTTPException(400, "Invalid or expired code")
    user.is_active = True; user.is_verified = True
    return {"message": "Email verified. You can now log in."}

# ── Login ─────────────────────────────────────────────────────────────────────

@router.post("/login")
async def login(body: LoginRequest, request: Request, db: AsyncSession = Depends(get_db)):
    from app.services.auth_svc import get_user_by_identifier
    user = await get_user_by_identifier(db, body.identifier)
    if not user or not verify_password(body.password, user.hashed_password):
        raise HTTPException(401, "Invalid credentials")
    if not user.is_active: raise HTTPException(403, "Account not verified. Check your email.")
    if user.is_banned:    raise HTTPException(403, "Account permanently banned.")
    if user.is_frozen:    raise HTTPException(403, "Account temporarily frozen.")
    if user.two_fa_enabled:
        code = await create_code(db, user.id, "2fa", ttl=10)
        await send_2fa_email(user.email, user.display_name, code)
        return {"two_fa_required": True, "message": "2FA code sent to your email"}
    token = await create_session(db, user.id,
        request.headers.get("User-Agent", "")[:512],
        request.client.host if request.client else "")
    return TokenResponse(access_token=token, user_id=user.id,
                         username=user.username, display_name=user.display_name)

@router.post("/2fa/verify", response_model=TokenResponse)
async def verify_2fa(body: TwoFARequest, request: Request, db: AsyncSession = Depends(get_db)):
    from app.services.auth_svc import get_user_by_identifier
    user = await get_user_by_identifier(db, body.identifier)
    if not user: raise HTTPException(404, "User not found")
    if not await check_code(db, user.id, body.code, "2fa"):
        raise HTTPException(400, "Invalid or expired 2FA code")
    token = await create_session(db, user.id,
        request.headers.get("User-Agent", "")[:512],
        request.client.host if request.client else "")
    return TokenResponse(access_token=token, user_id=user.id,
                         username=user.username, display_name=user.display_name)

@router.post("/logout")
async def logout(request: Request, current_user: User = Depends(get_current_user),
                 db: AsyncSession = Depends(get_db)):
    auth = request.headers.get("Authorization", "")
    if auth.startswith("Bearer "):
        s = await get_session_by_token(db, auth[7:])
        if s: s.is_active = False
    return {"message": "Logged out"}

# ── Password Reset ────────────────────────────────────────────────────────────

@router.post("/reset-password/request")
async def reset_password_request(body: ResetPasswordRequest, db: AsyncSession = Depends(get_db)):
    """
    Step 1 — Request password reset.
    Always returns 200 (don't leak whether email exists).
    """
    r = await db.execute(select(User).where(User.email == body.email))
    user = r.scalar_one_or_none()
    if user and user.is_active:
        code = await create_code(db, user.id, "reset_password", ttl=20)
        html = (f"<html><body style='font-family:sans-serif;max-width:480px;margin:auto'>"
                f"<h2 style='color:#4f46e5'>Password Reset</h2>"
                f"<p>Hi <b>{user.display_name}</b>,</p>"
                f"<p>Your password reset code:</p>"
                f"<div style='font-size:36px;font-weight:bold;letter-spacing:8px;"
                f"color:#ef4444;padding:16px;background:#fef2f2;border-radius:8px;"
                f"text-align:center'>{code}</div>"
                f"<p style='color:#6b7280'>Expires in 20 minutes. If you didn't request this, ignore this email.</p>"
                f"</body></html>")
        await send_email(body.email, "Messenger — Password Reset", html)
    return {"message": "If an account with that email exists, a reset code has been sent."}

@router.post("/reset-password/confirm")
async def reset_password_confirm(body: ResetPasswordConfirmRequest,
                                  db: AsyncSession = Depends(get_db)):
    """
    Step 2 — Submit code + new password to complete reset.
    """
    if not validate_password(body.new_password):
        raise HTTPException(400, "New password needs ≥8 chars, 1 uppercase, 1 digit")
    r = await db.execute(select(User).where(User.email == body.email))
    user = r.scalar_one_or_none()
    if not user:
        raise HTTPException(404, "User not found")
    if not await check_code(db, user.id, body.code, "reset_password"):
        raise HTTPException(400, "Invalid or expired reset code")
    user.hashed_password = hash_password(body.new_password)
    # Revoke all active sessions for security
    from app.models.models import Session
    sr = await db.execute(select(Session).where(Session.user_id == user.id, Session.is_active == True))
    for s in sr.scalars().all():
        s.is_active = False
    return {"message": "Password reset successfully. All sessions have been revoked. Please log in again."}
