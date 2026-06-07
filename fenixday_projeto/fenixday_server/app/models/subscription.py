"""
FênixDay — Modelo de Assinatura Mensal
"""

import uuid
from datetime import datetime, timezone
from enum import Enum as PyEnum

from sqlalchemy import String, DateTime, Float, ForeignKey, Enum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID

from app.database import Base


class SubscriptionStatus(str, PyEnum):
    PENDING  = "pending"
    ACTIVE   = "active"
    EXPIRED  = "expired"
    EXEMPT   = "exempt"    # volume < $330


class Subscription(Base):
    __tablename__ = "subscriptions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
    )

    status: Mapped[SubscriptionStatus] = mapped_column(
        Enum(SubscriptionStatus),
        default=SubscriptionStatus.PENDING,
    )

    # Volume negociado acumulado (para verificar isenção < $330)
    traded_volume_usdt: Mapped[float] = mapped_column(
        Float, default=0.0,
        comment="Volume acumulado em USDT — isenção se < $330"
    )
    volume_updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Datas do plano
    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True,
        comment="Data de expiração do plano mensal"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Controle de notificações de vencimento
    notified_7days: Mapped[bool] = mapped_column(default=False)
    notified_3days: Mapped[bool] = mapped_column(default=False)
    notified_1day:  Mapped[bool] = mapped_column(default=False)
