"""
FênixDay — JWT Blacklist via Redis
====================================
Invalida tokens JWT ao:
  • Logout do usuário
  • Troca de senha
  • Revogação manual pelo admin
  • Banimento de conta

Estratégia:
  O token é adicionado ao Redis com TTL igual ao tempo restante de
  expiração. Após o TTL natural, o Redis remove automaticamente a
  entrada — sem acúmulo infinito de tokens revogados.

Dependência: pip install redis[asyncio]
Configurar em .env: REDIS_URL=redis://localhost:6379/0
"""

from __future__ import annotations

import hashlib
from datetime import datetime, timezone
from typing import Optional

import redis.asyncio as aioredis
from fastapi import HTTPException, status

from app.config import settings

# ── Prefixo das chaves no Redis ───────────────────────────────────────────────
_PREFIX = "fenix:blacklist:"

# ── Conexão Redis (singleton) ─────────────────────────────────────────────────
_redis: Optional[aioredis.Redis] = None


async def get_redis() -> aioredis.Redis:
    global _redis
    if _redis is None:
        _redis = await aioredis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=True,
        )
    return _redis


# ── API pública ───────────────────────────────────────────────────────────────

async def revoke_token(token: str, payload: dict) -> None:
    """
    Adiciona o token à blacklist com TTL igual ao tempo restante.
    Após expirar naturalmente, o Redis remove a entrada sozinho.
    """
    r = await get_redis()

    exp = payload.get("exp")
    if not exp:
        return

    ttl = int(exp - datetime.now(timezone.utc).timestamp())
    if ttl <= 0:
        return  # token já expirado — não precisa revogar

    # Usamos o hash SHA-256 do token como chave para não expor o JWT
    key = _PREFIX + _token_hash(token)
    await r.setex(key, ttl, "revoked")


async def is_revoked(token: str) -> bool:
    """Retorna True se o token está na blacklist."""
    r = await get_redis()
    key = _PREFIX + _token_hash(token)
    return await r.exists(key) > 0


async def revoke_all_user_tokens(user_id: str) -> None:
    """
    Marca todos os tokens de um usuário como revogados.
    Usado ao banir ou ao forçar logout global.
    Armazena timestamp no Redis — qualquer token emitido ANTES
    desse timestamp é considerado inválido.
    """
    r = await get_redis()
    key = f"fenix:revoke_before:{user_id}"
    now = int(datetime.now(timezone.utc).timestamp())
    # Mantém por 8 dias (tempo máximo de vida de um token)
    await r.setex(key, 60 * 60 * 24 * 8, str(now))


async def is_user_token_revoked(user_id: str, issued_at: int) -> bool:
    """
    Verifica se o token foi emitido antes da revogação global do usuário.
    """
    r = await get_redis()
    key = f"fenix:revoke_before:{user_id}"
    val = await r.get(key)
    if val is None:
        return False
    return issued_at < int(val)


def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


# ── Dependency para injetar nos endpoints ─────────────────────────────────────

async def verify_not_revoked(token: str, payload: dict) -> None:
    """
    Lança HTTPException 401 se o token estiver revogado.
    Injetado pelo get_current_user() do auth.py.
    """
    if await is_revoked(token):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token revogado. Faça login novamente.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id = payload.get("sub")
    iat     = payload.get("iat", 0)
    if user_id and await is_user_token_revoked(user_id, iat):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Sessão encerrada. Faça login novamente.",
            headers={"WWW-Authenticate": "Bearer"},
        )
