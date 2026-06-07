"""initial — cria todas as tabelas

Revision ID: 0001_initial
Revises: 
Create Date: 2026-06-07
"""

from __future__ import annotations
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = '0001_initial'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── users ──────────────────────────────────────────────────────────────
    op.create_table('users',
        sa.Column('id',          postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('email',       sa.String(255), nullable=False),
        sa.Column('hashed_password', sa.String(255), nullable=True),
        sa.Column('google_id',   sa.String(255), nullable=True),
        sa.Column('telegram_chat_id', sa.String(64), nullable=True),
        sa.Column('is_active',   sa.Boolean, nullable=False, server_default='true'),
        sa.Column('is_superuser',sa.Boolean, nullable=False, server_default='false'),
        sa.Column('lgpd_consent',sa.Boolean, nullable=False, server_default='false'),
        sa.Column('lgpd_consent_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('lgpd_consent_ip', sa.String(45), nullable=True),
        sa.Column('lgpd_consent_version', sa.String(20), nullable=True),
        sa.Column('created_at',  sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at',  sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_users_email',     'users', ['email'],     unique=True)
    op.create_index('ix_users_google_id', 'users', ['google_id'], unique=True)

    # ── licenses ───────────────────────────────────────────────────────────
    op.create_table('licenses',
        sa.Column('id',      postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True),
                  sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('status',  sa.String(20), nullable=False, server_default='pending'),
        sa.Column('is_lifetime', sa.Boolean, nullable=False, server_default='false'),
        sa.Column('real_mode_blocked', sa.Boolean, nullable=False, server_default='false'),
        sa.Column('activated_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('expires_at',   sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at',   sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_licenses_user_id', 'licenses', ['user_id'], unique=True)

    # ── subscriptions ──────────────────────────────────────────────────────
    op.create_table('subscriptions',
        sa.Column('id',      postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True),
                  sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('status',        sa.String(20), nullable=False, server_default='pending'),
        sa.Column('current_tier',  sa.String(20), nullable=False, server_default='exempt'),
        sa.Column('pending_tier',  sa.String(20), nullable=True),
        sa.Column('traded_volume_usdt', sa.Float, nullable=False, server_default='0'),
        sa.Column('volume_updated_at',  sa.DateTime(timezone=True), nullable=True),
        sa.Column('expires_at',  sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at',  sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at',  sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_subscriptions_user_id', 'subscriptions', ['user_id'], unique=True)

    # ── payments ───────────────────────────────────────────────────────────
    op.create_table('payments',
        sa.Column('id',      postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True),
                  sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('btcpay_invoice_id', sa.String(128), nullable=True),
        sa.Column('amount',    sa.Float,     nullable=False),
        sa.Column('currency',  sa.String(10), nullable=False, server_default='USDT'),
        sa.Column('status',    sa.String(20), nullable=False, server_default='pending'),
        sa.Column('tier',      sa.String(20), nullable=False, server_default='basic'),
        sa.Column('plan_name', sa.String(50), nullable=False, server_default='Basic'),
        sa.Column('created_at',   sa.DateTime(timezone=True), nullable=False),
        sa.Column('confirmed_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index('ix_payments_user_id',          'payments', ['user_id'])
    op.create_index('ix_payments_btcpay_invoice_id','payments', ['btcpay_invoice_id'], unique=True)

    # ── audit_logs ─────────────────────────────────────────────────────────
    op.create_table('audit_logs',
        sa.Column('id',         sa.Integer, primary_key=True, autoincrement=True),
        sa.Column('event',      sa.String(50), nullable=False),
        sa.Column('actor_id',   sa.String(255), nullable=True),
        sa.Column('user_id',    postgresql.UUID(as_uuid=True),
                  sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('ip_address', sa.String(45),  nullable=True),
        sa.Column('user_agent', sa.String(512), nullable=True),
        sa.Column('success',    sa.Boolean, nullable=False, server_default='true'),
        sa.Column('metadata',   sa.Text, nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_audit_logs_event',      'audit_logs', ['event'])
    op.create_index('ix_audit_logs_actor_id',   'audit_logs', ['actor_id'])
    op.create_index('ix_audit_logs_user_id',    'audit_logs', ['user_id'])
    op.create_index('ix_audit_logs_created_at', 'audit_logs', ['created_at'])


def downgrade() -> None:
    op.drop_table('audit_logs')
    op.drop_table('payments')
    op.drop_table('subscriptions')
    op.drop_table('licenses')
    op.drop_table('users')
