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
from app.security.security_base import decode_access_token
from app.schemas import (
    RegisterRequest, LoginRequest, TokenResponse,
    UserResponse, TelegramUpdateRequest, ChangePasswordRequest,
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
from app.security.security_base import create_access_token
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
    user = await register_user(db, payload.email, payload.password)
    await log_event(
        AuditEvent.REGISTER,
        actor_id=str(user.id),
        ip_address=_get_ip(request),
    )
    from sqlalchemy import select as sa_select
    from app.models.models import License
    lic_result = await db.execute(sa_select(License).where(License.user_id == user.id))
    lic = lic_result.scalar_one_or_none()
    return _build_user_response(user, lic)


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
        user = await authenticate_user(db, payload.email, payload.password)
        if not user:
            raise HTTPException(status_code=401, detail="Credenciais inválidas")
        # Login bem-sucedido — zera contadores
        await record_successful_login(request, payload.email)
        await log_event(
            AuditEvent.LOGIN_SUCCESS,
            actor_id=payload.email,
            ip_address=_get_ip(request),
            success=True,
        )
        access_token = create_access_token({"sub": str(user.id), "email": user.email})
        return TokenResponse(access_token=access_token)

    except HTTPException as e:
        # Login falhou — incrementa contadores
        await record_failed_attempt(request, payload.email)
        await log_event(
            AuditEvent.LOGIN_FAILED,
            actor_id=payload.email,
            ip_address=_get_ip(request),
            success=False,
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
        AuditEvent.LOGOUT,
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
        AuditEvent.PASSWORD_CHANGED,
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

def _build_user_response(user: User, lic=None) -> UserResponse:
    return UserResponse(
        id=str(user.id),
        email=user.email,
        is_active=user.is_active,
        is_superuser=getattr(user, "is_superuser", False),
    )
