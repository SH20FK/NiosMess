import random, string
from datetime import datetime, timedelta, timezone
import aiosmtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.config import settings
from app.models.models import VerificationCode

def _code(n=6): return "".join(random.choices(string.digits, k=n))

async def send_email(to: str, subject: str, html: str):
    if not settings.SMTP_USER:
        print(f"\n[DEV EMAIL] To:{to}\nSubject:{subject}\n{html}\n"); return
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject; msg["From"] = settings.SMTP_FROM; msg["To"] = to
    msg.attach(MIMEText(html, "html"))
    await aiosmtplib.send(msg, hostname=settings.SMTP_HOST, port=settings.SMTP_PORT,
                          username=settings.SMTP_USER, password=settings.SMTP_PASSWORD, start_tls=True)

async def create_code(db: AsyncSession, user_id: int, purpose: str, ttl=15) -> str:
    code = _code()
    db.add(VerificationCode(user_id=user_id, code=code, purpose=purpose,
                            expires_at=datetime.now(timezone.utc) + timedelta(minutes=ttl)))
    await db.flush()
    return code

async def check_code(db: AsyncSession, user_id: int, code: str, purpose: str) -> bool:
    r = await db.execute(select(VerificationCode).where(
        VerificationCode.user_id == user_id, VerificationCode.code == code,
        VerificationCode.purpose == purpose, VerificationCode.used == False,
        VerificationCode.expires_at > datetime.now(timezone.utc)))
    vc = r.scalar_one_or_none()
    if not vc: return False
    vc.used = True
    return True

def _box(c): return f'<div style="font-size:36px;font-weight:bold;letter-spacing:8px;color:#4f46e5;padding:16px;background:#f3f4f6;border-radius:8px;text-align:center">{c}</div>'

async def send_verify_email(email, name, code):
    await send_email(email, "Verify your Messenger account",
        f"<html><body style='font-family:sans-serif;max-width:480px;margin:auto'><h2 style='color:#4f46e5'>Welcome!</h2><p>Hi <b>{name}</b>, your code:</p>{_box(code)}<p style='color:#6b7280'>Expires in 15 min.</p></body></html>")

async def send_2fa_email(email, name, code):
    await send_email(email, "Your Messenger 2FA code",
        f"<html><body style='font-family:sans-serif;max-width:480px;margin:auto'><h2 style='color:#4f46e5'>2FA Login</h2><p>Hi <b>{name}</b>, your code:</p>{_box(code)}<p style='color:#6b7280'>Expires in 10 min.</p></body></html>")
