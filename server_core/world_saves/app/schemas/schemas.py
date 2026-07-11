from __future__ import annotations
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, EmailStr, field_validator

# Auth
class RegisterRequest(BaseModel):
    email: EmailStr
    username: str
    display_name: str
    password: str
    @field_validator("username")
    @classmethod
    def clean(cls, v):
        v = v.strip().lower()
        if not all(c.isalnum() or c in "_." for c in v): raise ValueError("Bad chars")
        if len(v) < 3 or len(v) > 32: raise ValueError("3-32 chars")
        return v

class SendMessageRequest(BaseModel):
    content: Optional[str] = None
    reply_to_id: Optional[int] = None
    upload_id: Optional[str] = None

class EditMessageRequest(BaseModel):
    content: str

class ResetPasswordRequest(BaseModel):
    email: EmailStr

class ResetPasswordConfirmRequest(BaseModel):
    email: EmailStr
    code: str
    new_password: str
