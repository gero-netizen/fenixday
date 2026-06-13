"""
FênixDay — Modelos SQLAlchemy
User · License · Subscription · Payment · AuditLog
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from enum import Enum as PyEnum

from sqlalchemy import (
    Boolean, DateTime, Float, ForeignKey,
    Integer, String, Text, UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


# ── Enums ─────────────────────────────────────────────────────────────────────

class LicenseStatus(str, PyEnum):
    PENDING  = 'pending'
    ACTIVE   = 'active'
    EXPIRED  = 'expired'
    LIFETIME = 'lifetime'
    REVOKED  = 'revoked'


class SubscriptionStatus(str, PyEnum):
    PENDING  = 'pending'
    ACTIVE   = 'active'
    EXPIRED  = 'expired'
    CANCELED = 'canceled'


class PaymentStatus(str, PyEnum):
    PENDING   = 'pending'
    CONFIRMED = 'confirmed'
    EXPIRED   = 'expired'
    INVALID   = 'invalid'


# ── User ──────────────────────────────────────────────────────────────────────

class User(Base):
    __tablename__ = 'users'

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    email: Mapped[str] = mapped_column(
        String(255), unique=True, nullable=False, index=True
    )
    hashed_password: Mapped[str | None] = mapped_column(
        String(255), nullable=True   # None quando login via Google
    )
    google_id: Mapped[str | None] = mapped_column(
        String(255), unique=True, nullable=True, index=True
    )
    telegram_chat_id: Mapped[str | None] = mapped_column(
        String(64), nullable=True
    )
    is_active:     Mapped[bool] = mapped_column(Boolean, default=True)
    is_superuser:  Mapped[bool] = mapped_column(Boolean, default=False)
    lgpd_consent:  Mapped[bool] = mapped_column(Boolean, default=False)
    lgpd_consent_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    lgpd_consent_ip: Mapped[str | None] = mapped_column(String(45), nullable=True)
    lgpd_consent_version: Mapped[str | None] = mapped_column(String(20), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # Relacionamentos
    license:      Mapped[License | None]      = relationship(back_populates='user', uselist=False, cascade='all, delete-orphan')
    subscription: Mapped[Subscription | None] = relationship(back_populates='user', uselist=False, cascade='all, delete-orphan')
    payments:     Mapped[list[Payment]]       = relationship(back_populates='user', cascade='all, delete-orphan')
    audit_logs:   Mapped[list[AuditLog]]      = relationship(back_populates='user', cascade='all, delete-orphan')


# ── License ───────────────────────────────────────────────────────────────────

class License(Base):
    __tablename__ = 'licenses'

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey('users.id', ondelete='CASCADE'),
        unique=True, nullable=False, index=True
    )
    status: Mapped[LicenseStatus] = mapped_column(
        String(20), default=LicenseStatus.PENDING, nullable=False
    )
    is_lifetime:  Mapped[bool]          = mapped_column(Boolean, default=False)
    activated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    expires_at:   Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    real_mode_blocked: Mapped[bool]     = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    # Relacionamento
    user: Mapped[User] = relationship(back_populates='license')


# ── Subscription ──────────────────────────────────────────────────────────────

class Subscription(Base):
    __tablename__ = 'subscriptions'

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey('users.id', ondelete='CASCADE'),
        unique=True, nullable=False, index=True
    )
    status:       Mapped[SubscriptionStatus] = mapped_column(String(20), default=SubscriptionStatus.PENDING)
    current_tier: Mapped[str] = mapped_column(String(20), default='exempt')
    pending_tier: Mapped[str | None] = mapped_column(String(20), nullable=True)

    traded_volume_usdt: Mapped[float] = mapped_column(Float, default=0.0)
    volume_updated_at:  Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    expires_at:  Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at:  Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at:  Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # Relacionamento
    user: Mapped[User] = relationship(back_populates='subscription')


# ── Payment ───────────────────────────────────────────────────────────────────

class Payment(Base):
    __tablename__ = 'payments'

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey('users.id', ondelete='CASCADE'),
        nullable=False, index=True
    )
    btcpay_invoice_id: Mapped[str | None] = mapped_column(
        String(128), unique=True, nullable=True, index=True
    )
    amount:    Mapped[float]      = mapped_column(Float, nullable=False)
    currency:  Mapped[str]        = mapped_column(String(10), default='USDT')
    status:    Mapped[PaymentStatus] = mapped_column(String(20), default=PaymentStatus.PENDING)
    tier:      Mapped[str]        = mapped_column(String(20), default='basic')
    plan_name: Mapped[str]        = mapped_column(String(50), default='Basic')

    created_at:   Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    confirmed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Relacionamento
    user: Mapped[User] = relationship(back_populates='payments')


# ── AuditLog ──────────────────────────────────────────────────────────────────

class AuditLog(Base):
    """Tabela append-only — nunca deletar registros."""

    __tablename__ = 'audit_logs'

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    event: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    actor_id: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)

    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey('users.id', ondelete='SET NULL'),
        nullable=True, index=True
    )
    ip_address: Mapped[str | None] = mapped_column(String(45), nullable=True)
    user_agent: Mapped[str | None] = mapped_column(String(512), nullable=True)
    success:    Mapped[bool]       = mapped_column(Boolean, default=True)
    extra_data: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime]   = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        index=True,
    )

    # Relacionamento (opcional)
    user: Mapped[User | None] = relationship(back_populates='audit_logs')
