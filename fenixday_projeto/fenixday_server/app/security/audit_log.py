"""
FênixDay — Log de Auditoria Imutável
======================================
Registra todas as operações críticas do sistema.
Linhas de auditoria NUNCA são deletadas — apenas inseridas.

Eventos auditados:
  • Login (sucesso/falha) · Logout
  • Cadastro de conta
  • Ativação/revogação/expiração de licença
  • Pagamento confirmado/expirado
  • Ações administrativas (ativar VIP, banir, etc.)
  • Troca de senha · Revogação de token
  • Webhook recebido (com/sem assinatura válida)
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from enum import Enum as PyEnum
from typing import Optional

from sqlalchemy import String, DateTime, Text, Enum
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID, JSONB

from app.database import Base


# ── Enum de eventos ───────────────────────────────────────────────────────────

class AuditEvent(str, PyEnum):
    # Auth
    LOGIN_SUCCESS      = "login_success"
    LOGIN_FAILED       = "login_failed"
    LOGIN_GOOGLE       = "login_google"
    LOGOUT             = "logout"
    REGISTER           = "register"
    PASSWORD_CHANGED   = "password_changed"
    TOKEN_REVOKED      = "token_revoked"

    # Licença
    LICENSE_ACTIVATED  = "license_activated"
    LICENSE_REVOKED    = "license_revoked"
    LICENSE_EXPIRED    = "license_expired"
    LICENSE_VIP        = "license_vip"

    # Pagamentos
    PAYMENT_CONFIRMED  = "payment_confirmed"
    PAYMENT_EXPIRED    = "payment_expired"
    PAYMENT_INVALID    = "payment_invalid"
    INVOICE_CREATED    = "invoice_created"

    # Admin
    ADMIN_BAN          = "admin_ban"
    ADMIN_UNBAN        = "admin_unban"
    ADMIN_VIP          = "admin_vip"
    ADMIN_ACTION       = "admin_action"

    # Segurança
    BRUTE_FORCE        = "brute_force"
    WEBHOOK_INVALID    = "webhook_invalid"
    SUSPICIOUS_IP      = "suspicious_ip"


# ── Modelo SQLAlchemy ─────────────────────────────────────────────────────────

class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )

    # Evento
    event: Mapped[AuditEvent] = mapped_column(
        Enum(AuditEvent), nullable=False, index=True
    )

    # Quem executou (pode ser None para eventos não autenticados)
    actor_id: Mapped[Optional[str]] = mapped_column(
        String(64), nullable=True, index=True,
        comment="user_id do executor ou 'system' ou 'admin'"
    )

    # Quem foi afetado (pode ser diferente do actor para ações admin)
    target_id: Mapped[Optional[str]] = mapped_column(
        String(64), nullable=True,
        comment="user_id do usuário afetado"
    )

    # Contexto adicional (IP, user agent, detalhes do evento)
    metadata_: Mapped[Optional[dict]] = mapped_column(
        JSONB, nullable=True, name="metadata",
        comment="Dados adicionais do evento em JSON"
    )

    # Timestamp imutável
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        index=True,
    )

    # IP de origem
    ip_address: Mapped[Optional[str]] = mapped_column(
        String(45), nullable=True,
        comment="IPv4 ou IPv6 de origem"
    )

    # Resultado
    success: Mapped[bool] = mapped_column(default=True)

    # Mensagem human-readable
    message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)


# ── Serviço de auditoria ──────────────────────────────────────────────────────

from sqlalchemy.ext.asyncio import AsyncSession


async def log_event(
    db:         AsyncSession,
    event:      AuditEvent,
    actor_id:   Optional[str] = None,
    target_id:  Optional[str] = None,
    ip_address: Optional[str] = None,
    success:    bool = True,
    message:    Optional[str] = None,
    metadata:   Optional[dict] = None,
) -> None:
    """
    Registra um evento de auditoria.
    Operação de insert apenas — nunca atualiza ou deleta.
    Falha silenciosa para não interromper o fluxo principal.
    """
    try:
        entry = AuditLog(
            event=event,
            actor_id=actor_id,
            target_id=target_id,
            ip_address=ip_address,
            success=success,
            message=message,
            metadata_=metadata,
        )
        db.add(entry)
        await db.flush()
    except Exception:
        # Log de auditoria nunca deve derrubar a operação principal
        pass


# ── Queries de consulta (somente leitura) ─────────────────────────────────────

from sqlalchemy import select, desc


async def get_recent_events(
    db:     AsyncSession,
    limit:  int = 50,
    event:  Optional[AuditEvent] = None,
    actor:  Optional[str] = None,
) -> list[AuditLog]:
    """Retorna os eventos mais recentes — usado pelo painel admin."""
    query = select(AuditLog).order_by(desc(AuditLog.created_at)).limit(limit)

    if event:
        query = query.where(AuditLog.event == event)
    if actor:
        query = query.where(AuditLog.actor_id == actor)

    result = await db.execute(query)
    return list(result.scalars().all())


async def get_user_audit_trail(
    db:      AsyncSession,
    user_id: str,
    limit:   int = 100,
) -> list[AuditLog]:
    """Retorna o histórico de auditoria de um usuário específico."""
    result = await db.execute(
        select(AuditLog)
        .where(
            (AuditLog.actor_id == user_id) |
            (AuditLog.target_id == user_id)
        )
        .order_by(desc(AuditLog.created_at))
        .limit(limit)
    )
    return list(result.scalars().all())
