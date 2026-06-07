"""
FênixDay — Proteção contra Brute Force
========================================
Bloqueia temporariamente IPs e contas após tentativas de login falhas.

Regras:
  • 5 tentativas falhas por e-mail → bloqueio de 15 minutos
  • 10 tentativas falhas por IP → bloqueio de 30 minutos
  • 20 tentativas por IP em 1h → bloqueio de 24h (possível ataque)
  • Tentativa bem-sucedida → zera os contadores do e-mail/IP

Armazenamento: Redis (TTL automático)
"""

from __future__ import annotations

from datetime import timedelta

from fastapi import HTTPException, Request, status

from app.security.jwt_blacklist import get_redis

# ── Configuração ──────────────────────────────────────────────────────────────

MAX_ATTEMPTS_EMAIL   = 5
MAX_ATTEMPTS_IP      = 10
MAX_ATTEMPTS_IP_HOUR = 20

BLOCK_EMAIL_MINUTES  = 15
BLOCK_IP_MINUTES     = 30
BLOCK_IP_HOURS       = 24

_PFX_EMAIL  = "fenix:bf:email:"
_PFX_IP     = "fenix:bf:ip:"
_PFX_BLOCK  = "fenix:bf:block:"


# ── API pública ───────────────────────────────────────────────────────────────

async def check_brute_force(request: Request, email: str) -> None:
    """
    Verifica se o IP ou o e-mail estão bloqueados.
    Lança HTTPException 429 se bloqueado.
    Deve ser chamado ANTES de verificar a senha.
    """
    ip = _get_ip(request)
    r  = await get_redis()

    # Verificar bloqueio do e-mail
    if await r.exists(_PFX_BLOCK + f"email:{email}"):
        ttl = await r.ttl(_PFX_BLOCK + f"email:{email}")
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Conta temporariamente bloqueada. "
                   f"Tente novamente em {ttl // 60} minutos.",
        )

    # Verificar bloqueio do IP
    if await r.exists(_PFX_BLOCK + f"ip:{ip}"):
        ttl = await r.ttl(_PFX_BLOCK + f"ip:{ip}")
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Muitas tentativas deste endereço. "
                   f"Tente novamente em {ttl // 60} minutos.",
        )


async def record_failed_attempt(request: Request, email: str) -> None:
    """
    Registra uma tentativa de login malsucedida.
    Bloqueia automaticamente ao atingir os limites.
    """
    ip = _get_ip(request)
    r  = await get_redis()

    # ── Contador por e-mail ───────────────────────────────────────────
    email_key = _PFX_EMAIL + email
    email_count = await r.incr(email_key)
    if email_count == 1:
        await r.expire(email_key, int(timedelta(minutes=BLOCK_EMAIL_MINUTES).total_seconds()))

    if email_count >= MAX_ATTEMPTS_EMAIL:
        block_key = _PFX_BLOCK + f"email:{email}"
        await r.setex(
            block_key,
            int(timedelta(minutes=BLOCK_EMAIL_MINUTES).total_seconds()),
            "blocked",
        )
        await r.delete(email_key)

    # ── Contador por IP (janela de 30 min) ────────────────────────────
    ip_key = _PFX_IP + f"30m:{ip}"
    ip_count = await r.incr(ip_key)
    if ip_count == 1:
        await r.expire(ip_key, int(timedelta(minutes=BLOCK_IP_MINUTES).total_seconds()))

    if ip_count >= MAX_ATTEMPTS_IP:
        block_key = _PFX_BLOCK + f"ip:{ip}"
        await r.setex(
            block_key,
            int(timedelta(minutes=BLOCK_IP_MINUTES).total_seconds()),
            "blocked",
        )
        await r.delete(ip_key)

    # ── Contador por IP (janela de 1h — ataque mais intenso) ──────────
    ip_hour_key = _PFX_IP + f"1h:{ip}"
    ip_hour_count = await r.incr(ip_hour_key)
    if ip_hour_count == 1:
        await r.expire(ip_hour_key, 3600)

    if ip_hour_count >= MAX_ATTEMPTS_IP_HOUR:
        block_key = _PFX_BLOCK + f"ip:{ip}"
        await r.setex(
            block_key,
            int(timedelta(hours=BLOCK_IP_HOURS).total_seconds()),
            "blocked_24h",
        )
        await r.delete(ip_hour_key)


async def record_successful_login(request: Request, email: str) -> None:
    """Zera contadores após login bem-sucedido."""
    ip = _get_ip(request)
    r  = await get_redis()

    await r.delete(
        _PFX_EMAIL + email,
        _PFX_IP + f"30m:{ip}",
        _PFX_IP + f"1h:{ip}",
    )


def _get_ip(request: Request) -> str:
    """Extrai o IP real (considera X-Forwarded-For do Nginx)."""
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"
