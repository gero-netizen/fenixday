"""
FênixDay — Log de Auditoria
Usa o modelo AuditLog centralizado de app.models.models
"""
from __future__ import annotations
from datetime import datetime, timezone
from typing import Optional
from enum import Enum as PyEnum

from app.database import get_db_context


class AuditEvent(str, PyEnum):
    LOGIN_SUCCESS     = "login_success"
    LOGIN_FAILED      = "login_failed"
    LOGIN_GOOGLE      = "login_google"
    LOGOUT            = "logout"
    REGISTER          = "register"
    PASSWORD_CHANGED  = "password_changed"
    TOKEN_REVOKED     = "token_revoked"
    LICENSE_ACTIVATED = "license_activated"
    LICENSE_REVOKED   = "license_revoked"
    LICENSE_EXPIRED   = "license_expired"
    PAYMENT_CONFIRMED = "payment_confirmed"
    PAYMENT_EXPIRED   = "payment_expired"
    INVOICE_CREATED   = "invoice_created"
    ADMIN_BAN         = "admin_ban"
    ADMIN_UNBAN       = "admin_unban"
    ADMIN_VIP         = "admin_vip"
    ADMIN_ACTION      = "admin_action"
    BRUTE_FORCE       = "brute_force"
    WEBHOOK_INVALID   = "webhook_invalid"


async def log_event(
    event: str,
    actor_id: Optional[str] = None,
    ip_address: Optional[str] = None,
    success: bool = True,
    metadata: Optional[str] = None,
) -> None:
    """Registra um evento de auditoria. Nunca propaga exceções."""
    try:
        from app.models.models import AuditLog
        async with get_db_context() as db:
            entry = AuditLog(
                event=event,
                actor_id=actor_id,
                ip_address=ip_address,
                success=success,
                extra_data=metadata,
                created_at=datetime.now(timezone.utc),
            )
            db.add(entry)
            await db.flush()
    except Exception:
        pass
