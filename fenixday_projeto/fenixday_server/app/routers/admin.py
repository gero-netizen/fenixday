"""
FênixDay — Router Admin
Todos os endpoints requerem is_superuser=True.

GET  /admin/metrics          — métricas gerais do painel
GET  /admin/users            — lista usuários com filtros
PATCH /admin/users/{id}/license — ativa/revoga/bane manualmente
POST /admin/notify           — envia notificação por segmento
GET  /admin/logs             — logs de auditoria com filtros
GET  /admin/top-grids        — grids pendentes e aprovados
PATCH /admin/top-grids/{id} — aprovar/rejeitar/remover grid
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.models import (
    AuditLog, License, LicenseStatus, Payment,
    Subscription, User,
)
from app.routers.auth_v2 import get_current_user
from app.security.audit_log import log_event

router = APIRouter()


# ── Guard superuser ───────────────────────────────────────────────────────────

async def require_superuser(
    current_user: User = Depends(get_current_user),
) -> User:
    if not current_user.is_superuser:
        raise HTTPException(status_code=403, detail='Acesso restrito a administradores.')
    return current_user


# ── Schemas ───────────────────────────────────────────────────────────────────

class LicenseAction(BaseModel):
    action: Literal['activate', 'revoke', 'ban', 'unban', 'lifetime',
                    'basic', 'pro', 'premium']
    reason: str = ''


class NotifyPayload(BaseModel):
    title:    str
    message:  str
    segment:  Literal['all', 'active', 'exempt', 'expired'] = 'all'
    channel:  Literal['push', 'telegram', 'both'] = 'push'


class TopGridAction(BaseModel):
    action: Literal['approve', 'reject', 'remove', 'verify', 'unverify']


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get('/metrics')
async def get_metrics(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_superuser),
):
    total_users   = (await db.execute(select(func.count(User.id)))).scalar_one()
    active_users  = (await db.execute(
        select(func.count(License.id)).where(License.status == LicenseStatus.ACTIVE)
    )).scalar_one()
    exempt_users  = (await db.execute(
        select(func.count(Subscription.id)).where(
            Subscription.current_tier == 'exempt')
    )).scalar_one()
    expired_users = (await db.execute(
        select(func.count(License.id)).where(License.status == LicenseStatus.EXPIRED)
    )).scalar_one()
    banned_users  = (await db.execute(
        select(func.count(User.id)).where(User.is_active == False)  # noqa
    )).scalar_one()
    new_today = (await db.execute(
        select(func.count(User.id)).where(
            func.date(User.created_at) == func.current_date()
        )
    )).scalar_one()

    # Receita mensal
    from datetime import timedelta
    month_start = datetime.now(timezone.utc).replace(day=1, hour=0, minute=0, second=0)
    revenue_monthly = (await db.execute(
        select(func.sum(Payment.amount)).where(
            Payment.confirmed_at >= month_start
        )
    )).scalar_one() or 0.0
    revenue_total = (await db.execute(
        select(func.sum(Payment.amount))
    )).scalar_one() or 0.0

    # Contagem por plano
    for tier in ['basic', 'pro', 'premium']:
        count = (await db.execute(
            select(func.count(Subscription.id)).where(
                Subscription.current_tier == tier)
        )).scalar_one()
        locals()[f'{tier}_count'] = count

    return {
        'total_users':    total_users,
        'active_users':   active_users,
        'exempt_users':   exempt_users,
        'expired_users':  expired_users,
        'banned_users':   banned_users,
        'new_today':      new_today,
        'revenue_monthly': round(revenue_monthly, 2),
        'revenue_total':   round(revenue_total, 2),
        'basic_count':    locals().get('basic_count', 0),
        'pro_count':      locals().get('pro_count', 0),
        'premium_count':  locals().get('premium_count', 0),
    }


@router.get('/users')
async def list_users(
    search:   str | None = Query(None),
    status:   str | None = Query(None),
    limit:    int = Query(50, le=200),
    offset:   int = Query(0),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_superuser),
):
    q = select(User).order_by(User.created_at.desc())
    if search:
        q = q.where(User.email.ilike(f'%{search}%'))
    if status == 'banned':
        q = q.where(User.is_active == False)  # noqa
    q = q.limit(limit).offset(offset)
    result = await db.execute(q)
    users  = result.scalars().all()

    return [
        {
            'id':          str(u.id),
            'email':       u.email,
            'is_active':   u.is_active,
            'is_superuser': u.is_superuser,
            'created_at':  u.created_at.isoformat(),
            'last_login':  None,  # TODO: adicionar campo ao model
        }
        for u in users
    ]


@router.patch('/users/{user_id}/license')
async def update_user_license(
    user_id: uuid.UUID,
    payload: LicenseAction,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(require_superuser),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user   = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail='Usuário não encontrado.')

    action = payload.action

    if action == 'ban':
        user.is_active = False
        event = 'ADMIN_BAN'

    elif action == 'unban':
        user.is_active = True
        event = 'ADMIN_UNBAN'

    elif action == 'activate':
        if user.license:
            user.license.status = LicenseStatus.ACTIVE
        event = 'LICENSE_ACTIVATED'

    elif action == 'revoke':
        if user.license:
            user.license.status = LicenseStatus.REVOKED
        event = 'LICENSE_REVOKED'

    elif action == 'lifetime':
        if user.license:
            user.license.status      = LicenseStatus.LIFETIME
            user.license.is_lifetime = True
        event = 'ADMIN_VIP'

    elif action in ('basic', 'pro', 'premium'):
        if user.subscription:
            user.subscription.current_tier = action
            user.subscription.pending_tier  = None
        if user.license:
            user.license.status = LicenseStatus.ACTIVE
        event = 'ADMIN_ACTION'

    else:
        raise HTTPException(status_code=400, detail='Ação inválida.')

    await db.commit()
    await log_event(event, actor_id=str(admin.id),
                    metadata=f'target={user_id} action={action} reason={payload.reason}')

    return {'status': 'ok', 'action': action, 'user_id': str(user_id)}


@router.post('/notify')
async def send_notification(
    payload: NotifyPayload,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(require_superuser),
):
    """
    Envia notificação push e/ou Telegram para o segmento selecionado.
    TODO: integrar com serviço de push (Firebase FCM) e Telegram Bot API.
    """
    # Calcular destinatários
    q = select(func.count(User.id)).where(User.is_active == True)  # noqa
    if payload.segment == 'active':
        q = q.join(License).where(License.status == LicenseStatus.ACTIVE)
    elif payload.segment == 'exempt':
        q = q.join(Subscription).where(Subscription.current_tier == 'exempt')
    elif payload.segment == 'expired':
        q = q.join(License).where(License.status == LicenseStatus.EXPIRED)

    count = (await db.execute(q)).scalar_one()

    # TODO: disparar job assíncrono de envio (Celery / BackgroundTasks)
    await log_event(
        'ADMIN_ACTION',
        actor_id=str(admin.id),
        metadata=(
            f'notify segment={payload.segment} channel={payload.channel} '
            f'recipients={count} title={payload.title[:50]}'
        ),
    )

    return {
        'status':     'queued',
        'recipients': count,
        'segment':    payload.segment,
        'channel':    payload.channel,
    }


@router.get('/logs')
async def get_audit_logs(
    event:   str | None = Query(None),
    search:  str | None = Query(None),
    limit:   int = Query(50, le=500),
    offset:  int = Query(0),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_superuser),
):
    q = select(AuditLog).order_by(AuditLog.created_at.desc())
    if event:
        q = q.where(AuditLog.event == event)
    if search:
        q = q.where(AuditLog.actor_id.ilike(f'%{search}%'))
    q = q.limit(limit).offset(offset)
    result = await db.execute(q)
    logs   = result.scalars().all()

    return [
        {
            'id':         l.id,
            'event':      l.event,
            'actor_id':   l.actor_id,
            'ip_address': l.ip_address,
            'success':    l.success,
            'metadata':   l.metadata,
            'created_at': l.created_at.isoformat(),
        }
        for l in logs
    ]


# ── Top Grids (tabela futura) ─────────────────────────────────────────────────

_TOP_GRIDS_MOCK: list[dict] = []   # substituir por tabela real quando implementar


@router.get('/top-grids')
async def get_top_grids(
    status: str | None = Query(None),
    _: User = Depends(require_superuser),
):
    if status:
        return [g for g in _TOP_GRIDS_MOCK if g.get('status') == status]
    return _TOP_GRIDS_MOCK


@router.patch('/top-grids/{grid_id}')
async def update_top_grid(
    grid_id: str,
    payload: TopGridAction,
    admin: User = Depends(require_superuser),
):
    await log_event(
        'ADMIN_ACTION',
        actor_id=str(admin.id),
        metadata=f'top_grid={grid_id} action={payload.action}',
    )
    return {'status': 'ok', 'grid_id': grid_id, 'action': payload.action}
