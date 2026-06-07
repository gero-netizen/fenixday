"""
FênixDay — Auth Router v2 (com segurança completa)
====================================================
Integra:
  • Brute force protection (check antes + record após falha)
  • JWT Blacklist (logout invalida o token)
  • Audit log (todos os eventos críticos registrados)
  • Troca de senha (invalida todos os tokens anteriores)
"""

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from jose import JWTError
import uuid

from app.database import get_db
from app.security_base import decode_access_token
from app.schemas.schemas import (
    RegisterRequest, LoginRequest, TokenResponse,
    UserResponse, TelegramUpdateRequest,
)
from app.services.auth_service import register_user, authenticate_user
from app.models.models import User, LicenseStatus
from app.security.jwt_blacklist import (
    revoke_token, verify_not_revoked, revoke_all_user_tokens
)
from app.security.brute_force import (
    check_brute_force, record_failed_attempt, record_successful_login
)
from app.security.audit_log import log_event, AuditEvent
from sqlalchemy import select
from pydantic import BaseModel

router = APIRouter()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


# ── Dependency: usuário atual autenticado ────────────────────────────────────

async def get_current_user(
    request: Request,
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token inválido ou expirado.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = decode_access_token(token)
        user_id: str = payload.get("sub")
        if not user_id:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    # Verificar blacklist
    await verify_not_revoked(token, payload)

    result = await db.execute(select(User).where(User.id == uuid.UUID(user_id)))
    user = result.scalar_one_or_none()

    if not user or not user.is_active:
        raise credentials_exception
    return user


async def get_current_superuser(
    current_user: User = Depends(get_current_user),
) -> User:
    if not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso restrito a administradores.",
        )
    return current_user


# ── Endpoints ────────────────────────────────────────────────────────────────

@router.post("/register", response_model=UserResponse, status_code=201)
async def register(
    request: Request,
    payload: RegisterRequest,
    db: AsyncSession = Depends(get_db),
):
    """Cadastro com brute force check e audit log."""
    from app.security.brute_force import _get_ip
    user = await register_user(db, payload)
    await log_event(
        db, AuditEvent.REGISTER,
        actor_id=str(user.id),
        ip_address=_get_ip(request),
        message=f"Novo cadastro: {user.email}",
    )
    return _build_user_response(user)


@router.post("/login", response_model=TokenResponse)
async def login(
    request: Request,
    payload: LoginRequest,
    db: AsyncSession = Depends(get_db),
):
    """Login com brute force protection e audit log."""
    from app.security.brute_force import _get_ip

    # Verifica bloqueio ANTES de qualquer operação no banco
    await check_brute_force(request, payload.email)

    try:
        result = await authenticate_user(db, payload)
        # Login bem-sucedido — zera contadores
        await record_successful_login(request, payload.email)
        await log_event(
            db, AuditEvent.LOGIN_SUCCESS,
            actor_id=payload.email,
            ip_address=_get_ip(request),
            success=True,
        )
        return result

    except HTTPException as e:
        # Login falhou — incrementa contadores
        await record_failed_attempt(request, payload.email)
        await log_event(
            db, AuditEvent.LOGIN_FAILED,
            actor_id=payload.email,
            ip_address=_get_ip(request),
            success=False,
            message=str(e.detail),
        )
        raise


@router.post("/logout", status_code=204)
async def logout(
    request: Request,
    token: str = Depends(oauth2_scheme),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Logout — invalida o token via blacklist Redis."""
    from app.security.brute_force import _get_ip
    try:
        payload = decode_access_token(token)
        await revoke_token(token, payload)
    except Exception:
        pass  # Token já inválido — logout silencioso

    await log_event(
        db, AuditEvent.LOGOUT,
        actor_id=str(current_user.id),
        ip_address=_get_ip(request),
    )


@router.post("/change-password", status_code=204)
async def change_password(
    request: Request,
    payload: 'ChangePasswordRequest',
    token: str = Depends(oauth2_scheme),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Troca de senha — revoga TODOS os tokens do usuário."""
    from app.security_base import hash_password, verify_password
    from app.security.brute_force import _get_ip

    if not verify_password(payload.current_password, current_user.hashed_password):
        raise HTTPException(status_code=400, detail="Senha atual incorreta.")

    current_user.hashed_password = hash_password(payload.new_password)
    await db.commit()

    # Revoga todos os tokens (força novo login)
    await revoke_all_user_tokens(str(current_user.id))

    await log_event(
        db, AuditEvent.PASSWORD_CHANGED,
        actor_id=str(current_user.id),
        ip_address=_get_ip(request),
    )


@router.get("/me", response_model=UserResponse)
async def me(current_user: User = Depends(get_current_user)):
    return _build_user_response(current_user)


@router.put("/telegram", status_code=204)
async def update_telegram(
    payload: TelegramUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    current_user.telegram_chat_id = payload.telegram_chat_id
    await db.commit()


# ── Schemas adicionais ────────────────────────────────────────────────────────

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

    class Config:
        pass


# ── Helper ────────────────────────────────────────────────────────────────────

def _build_user_response(user: User) -> UserResponse:
    lic = user.license
    return UserResponse(
        id=user.id,
        email=user.email,
        is_active=user.is_active,
        created_at=user.created_at,
        license_status=lic.status if lic else LicenseStatus.PENDING,
        is_lifetime=lic.is_lifetime if lic else False,
        telegram_chat_id=user.telegram_chat_id,
    )
