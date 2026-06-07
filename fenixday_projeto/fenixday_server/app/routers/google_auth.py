"""
FênixDay — Endpoint de autenticação com Google OAuth2
=====================================================
POST /api/v1/auth/google
  Recebe o idToken do Google Sign-In (Flutter) e:
    1. Verifica o token com a API do Google
    2. Cria o usuário se não existir (first login)
    3. Retorna JWT FênixDay com license_status embutido

Dependência: pip install google-auth
"""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.config import settings
from app.database import get_db
from app.models.models import User, License, LicenseStatus
from app.security import create_access_token, hash_password
from app.schemas.schemas import TokenResponse

router = APIRouter()

# Client ID do projeto no Google Cloud Console
# Configurar em .env: GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com
GOOGLE_CLIENT_ID = settings.GOOGLE_CLIENT_ID


class GoogleAuthRequest(BaseModel):
    id_token: str     # token retornado pelo google_sign_in Flutter


@router.post("/google", response_model=TokenResponse)
async def google_login(
    payload: GoogleAuthRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Autentica o usuário via Google OAuth2.

    Fluxo:
      1. Flutter chama googleSignIn.signIn() → obtém idToken
      2. Flutter envia idToken para este endpoint
      3. Servidor valida o token com o Google
      4. Cria ou recupera o usuário no banco
      5. Retorna JWT FênixDay
    """
    # ── 1. Verificar token com o Google ──────────────────────────────────
    try:
        id_info = google_id_token.verify_oauth2_token(
            payload.id_token,
            google_requests.Request(),
            GOOGLE_CLIENT_ID,
        )
    except ValueError as e:
        raise HTTPException(status_code=401, detail=f"Token Google inválido: {e}")

    email  = id_info.get("email")
    name   = id_info.get("name", "")
    google_id = id_info.get("sub")

    if not email:
        raise HTTPException(status_code=400, detail="E-mail não disponível no token Google.")

    # ── 2. Buscar ou criar usuário ────────────────────────────────────────
    result = await db.execute(select(User).where(User.email == email))
    user: User | None = result.scalar_one_or_none()

    if not user:
        # Primeiro login com Google — cria conta automaticamente
        user = User(
            email=email,
            hashed_password=hash_password(google_id),  # senha inutilizável
            is_active=True,
            google_id=google_id,
            display_name=name,
        )
        db.add(user)
        await db.flush()

        # Licença PENDING criada automaticamente
        lic = License(user_id=user.id, status=LicenseStatus.PENDING)
        db.add(lic)
        await db.commit()
        await db.refresh(user)
    else:
        # Atualizar google_id se ainda não estiver salvo
        if not getattr(user, 'google_id', None):
            user.google_id = google_id
        user.last_login = datetime.now(timezone.utc)
        await db.commit()

    # ── 3. Gerar JWT FênixDay ─────────────────────────────────────────────
    license_status = user.license.status if user.license else LicenseStatus.PENDING
    is_lifetime    = user.license.is_lifetime if user.license else False

    token = create_access_token(
        subject=str(user.id),
        extra_claims={
            "license_status": license_status.value,
            "is_lifetime":    is_lifetime,
            "auth_provider":  "google",
        },
    )

    return TokenResponse(
        access_token=token,
        license_status=license_status,
        is_lifetime=is_lifetime,
    )
