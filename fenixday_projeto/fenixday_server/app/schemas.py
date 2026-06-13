"""
FênixDay — Schemas Pydantic para request/response da API
"""
from pydantic import BaseModel, EmailStr
from typing import Optional


# ── Auth ──────────────────────────────────────────────────────────────────────

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

class GoogleAuthRequest(BaseModel):
    id_token: str

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

class TelegramRequest(BaseModel):
    chat_id: str


# ── Subscription ──────────────────────────────────────────────────────────────

class VolumeUpdate(BaseModel):
    volume_usdt: float


# ── User ──────────────────────────────────────────────────────────────────────

class UserResponse(BaseModel):
    id: str
    email: str
    is_active: bool
    is_superuser: bool

    class Config:
        from_attributes = True


class TelegramUpdateRequest(BaseModel):
    chat_id: str

class RefreshTokenRequest(BaseModel):
    refresh_token: str

class PasswordResetRequest(BaseModel):
    email: EmailStr

class UserUpdateRequest(BaseModel):
    telegram_chat_id: Optional[str] = None

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

class GoogleLoginRequest(BaseModel):
    id_token: str
