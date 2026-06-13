"""
FênixDay — Google OAuth2 Router
Valida o idToken do Google e cria/autentica o usuário.
"""
from __future__ import annotations
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timezone
import uuid, httpx

from app.database import get_db
from app.models.models import User, License, LicenseStatus, Subscription
from app.security.security_base import create_access_token
from app.config import settings

router = APIRouter()


async def verify_google_token(id_token: str) -> dict:
    """Verifica o idToken com a API do Google."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"https://oauth2.googleapis.com/tokeninfo?id_token={id_token}"
        )
        if resp.status_code != 200:
            raise HTTPException(status_code=401, detail="Token Google inválido.")
        data = resp.json()
        if data.get("aud") != settings.GOOGLE_CLIENT_ID and settings.GOOGLE_CLIENT_ID:
            raise HTTPException(status_code=401, detail="Token não pertence a este app.")
        return data


@router.post("/google")
async def google_login(
    payload: dict,
    db: AsyncSession = Depends(get_db),
):
    id_token = payload.get("id_token", "")
    if not id_token:
        raise HTTPException(status_code=400, detail="id_token obrigatório.")

    info = await verify_google_token(id_token)
    email     = info.get("email")
    google_id = info.get("sub")

    if not email or not google_id:
        raise HTTPException(status_code=401, detail="Dados insuficientes do Google.")

    # Buscar ou criar usuário
    result = await db.execute(select(User).where(User.email == email))
    user   = result.scalar_one_or_none()

    if not user:
        user = User(
            id=uuid.uuid4(), email=email, google_id=google_id,
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        db.add(user)
        db.add(License(id=uuid.uuid4(), user_id=user.id,
                       status=LicenseStatus.PENDING,
                       created_at=datetime.now(timezone.utc)))
        db.add(Subscription(id=uuid.uuid4(), user_id=user.id,
                            current_tier='exempt',
                            created_at=datetime.now(timezone.utc),
                            updated_at=datetime.now(timezone.utc)))
        await db.flush()

    token = create_access_token({"sub": str(user.id), "email": user.email})
    return {"access_token": token, "token_type": "bearer"}
