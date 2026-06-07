"""
FênixDay — Subscriptions v2 (3 planos por volume)
===================================================
Planos:
  Isento  →  < $500         →  gratuito
  Basic   →  $500–$4.999    →  $10,00/mês
  Pro     →  $5.000–$34.999 →  $14,99/mês
  Premium →  ≥ $35.000      →  $29,90/mês

Mudança de plano: sempre na próxima renovação.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database import get_db
from app.models.models import User, License, LicenseStatus
from app.models.subscription import Subscription, SubscriptionStatus
from app.models.plan_tiers import (
    PlanTier, PLANS, get_tier_for_volume,
    evaluate_plan_change, get_upgrade_alert,
)
from app.routers.auth_v2 import get_current_user
from app.config import settings

router = APIRouter()

PLAN_DURATION_DAYS = 30


# ── Schemas ───────────────────────────────────────────────────────────────────

class SubscriptionStatusResponse(BaseModel):
    user_id:           str
    current_tier:      str
    plan_name:         str
    price_monthly:     float
    next_tier:         str | None
    next_price:        float | None
    is_exempt:         bool
    traded_volume:     float
    volume_progress:   float        # 0.0 a 1.0 na faixa atual
    volume_faltante:   float | None # para próximo plano
    days_remaining:    int | None
    expires_at:        str | None
    real_mode_allowed: bool
    upgrade_alert:     dict | None  # alerta de mudança de faixa


class VolumeUpdateRequest(BaseModel):
    volume_usdt: float


class RenewalResponse(BaseModel):
    invoice_id:   str
    checkout_url: str
    amount:       float
    tier:         str
    plan_name:    str
    expires_at:   str


# ── Endpoints ────────────────────────────────────────────────────────────────

@router.get("/status", response_model=SubscriptionStatusResponse)
async def get_subscription_status(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    sub = await _get_or_create_subscription(db, current_user.id)
    volume   = sub.traded_volume_usdt
    tier     = PlanTier(sub.current_tier) if sub.current_tier else get_tier_for_volume(volume)
    plan     = PLANS[tier]
    is_exempt = tier == PlanTier.EXEMPT

    # Avaliação de mudança de plano
    evaluation = evaluate_plan_change(
        current_volume=volume,
        current_tier=tier,
        active_subscription=sub.status == SubscriptionStatus.ACTIVE,
    )
    progress = evaluation["progress"]

    # Dias restantes
    days_remaining = None
    if sub.expires_at and not is_exempt:
        delta = sub.expires_at - datetime.now(timezone.utc)
        days_remaining = max(0, delta.days)

    # Modo Real permitido se isento ou assinatura ativa
    real_mode = is_exempt or sub.status == SubscriptionStatus.ACTIVE

    # Próximo tier
    from app.models.plan_tiers import get_next_tier
    next_tier = get_next_tier(tier)
    next_plan = PLANS[next_tier] if next_tier else None

    return SubscriptionStatusResponse(
        user_id=str(current_user.id),
        current_tier=tier.value,
        plan_name=plan.name,
        price_monthly=plan.price_monthly,
        next_tier=next_tier.value if next_tier else None,
        next_price=next_plan.price_monthly if next_plan else None,
        is_exempt=is_exempt,
        traded_volume=volume,
        volume_progress=progress["progress"],
        volume_faltante=progress.get("volume_faltante"),
        days_remaining=days_remaining,
        expires_at=sub.expires_at.isoformat() if sub.expires_at else None,
        real_mode_allowed=real_mode,
        upgrade_alert=evaluation.get("alert"),
    )


@router.post("/renew", response_model=RenewalResponse)
async def renew_subscription(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Cria invoice BTCPay para renovação.
    O valor cobrado é baseado no tier ATUAL do usuário.
    Se o volume mudou de faixa, o novo preço já se aplica aqui.
    """
    import httpx

    sub = await _get_or_create_subscription(db, current_user.id)
    volume = sub.traded_volume_usdt

    # Calcular tier correto para renovação
    correct_tier = get_tier_for_volume(volume)
    plan         = PLANS[correct_tier]

    # Isentos não precisam renovar
    if correct_tier == PlanTier.EXEMPT:
        raise HTTPException(
            status_code=400,
            detail=f"Conta isenta — volume ${volume:.2f} abaixo de $500. "
                   f"Nenhum pagamento necessário.",
        )

    if not settings.BTCPAY_SERVER_URL:
        raise HTTPException(status_code=503, detail="Gateway não configurado.")

    # Criar invoice BTCPay com o valor do plano correto
    payload = {
        "amount":   str(plan.price_monthly),
        "currency": "USDT",
        "metadata": {
            "user_id":   str(current_user.id),
            "email":     current_user.email,
            "type":      "monthly_renewal",
            "tier":      correct_tier.value,
            "plan_name": plan.name,
        },
        "checkout": {
            "expirationMinutes": 30,
            "redirectURL": "fenixday://payment-success",
        },
    }

    headers = {
        "Authorization": f"token {settings.BTCPAY_API_KEY}",
        "Content-Type":  "application/json",
    }

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{settings.BTCPAY_SERVER_URL}/api/v1/stores/"
            f"{settings.BTCPAY_STORE_ID}/invoices",
            json=payload, headers=headers, timeout=10.0,
        )

    if resp.status_code not in (200, 201):
        raise HTTPException(status_code=502, detail="Erro ao criar invoice.")

    invoice  = resp.json()
    expires  = datetime.now(timezone.utc) + timedelta(minutes=30)

    return RenewalResponse(
        invoice_id=invoice["id"],
        checkout_url=invoice["checkoutLink"],
        amount=plan.price_monthly,
        tier=correct_tier.value,
        plan_name=plan.name,
        expires_at=expires.isoformat(),
    )


@router.post("/volume")
async def update_volume(
    payload: VolumeUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Atualiza volume acumulado. Avalia mudança de faixa (aplicada na renovação).
    """
    sub = await _get_or_create_subscription(db, current_user.id)
    sub.traded_volume_usdt = payload.volume_usdt
    sub.volume_updated_at  = datetime.now(timezone.utc)

    # Calcular tier correto para o novo volume
    new_tier = get_tier_for_volume(payload.volume_usdt)
    sub.pending_tier = new_tier.value   # salva para aplicar na renovação

    # Se for isento, liberar Modo Real imediatamente
    if new_tier == PlanTier.EXEMPT:
        if current_user.license:
            current_user.license.status = LicenseStatus.ACTIVE

    await db.commit()

    # Montar resposta com alerta se necessário
    current_tier = PlanTier(sub.current_tier) if sub.current_tier else new_tier
    alert = get_upgrade_alert(payload.volume_usdt, current_tier)

    return {
        "traded_volume":  sub.traded_volume_usdt,
        "current_tier":   current_tier.value,
        "pending_tier":   new_tier.value,
        "tier_changed":   new_tier != current_tier,
        "apply_on":       "next_renewal",
        "upgrade_alert":  alert,
    }


@router.get("/plans")
async def list_plans():
    """Lista todos os planos disponíveis — endpoint público (sem auth)."""
    return [
        {
            "tier":          p.tier.value,
            "name":          p.name,
            "price_monthly": p.price_monthly,
            "volume_min":    p.volume_min,
            "volume_max":    p.volume_max,
            "color_hex":     p.color_hex,
            "features": [
                "Grids ilimitados",
                "Scanner de IA Top 20",
                "Integração Binance, Bybit e OKX",
                "Notificações Telegram",
                "Operação 24/7 com reconexão automática",
                "Paper Trading e Modo Demo",
                "Relatório diário de P&L",
            ],
        }
        for p in PLANS.values()
    ]


@router.get("/history")
async def get_history(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from app.models.payment import Payment
    result = await db.execute(
        select(Payment)
        .where(Payment.user_id == current_user.id)
        .order_by(Payment.created_at.desc())
        .limit(24)
    )
    payments = result.scalars().all()
    return [
        {
            "id":           str(p.id),
            "amount":       p.amount,
            "currency":     p.currency,
            "status":       p.status.value,
            "tier":         getattr(p, "tier", "basic"),
            "plan_name":    getattr(p, "plan_name", "Basic"),
            "created_at":   p.created_at.isoformat(),
            "confirmed_at": p.confirmed_at.isoformat() if p.confirmed_at else None,
        }
        for p in payments
    ]


# ── Ativação pós-pagamento ────────────────────────────────────────────────────

async def activate_after_payment(
    db: AsyncSession,
    user_id: uuid.UUID,
    tier: str = "basic",
) -> None:
    """Ativa/renova o plano após confirmação BTCPay."""
    sub = await _get_or_create_subscription(db, user_id)
    now = datetime.now(timezone.utc)

    # Aplicar o tier pendente (ou o informado pelo webhook)
    applied_tier = PlanTier(tier) if tier in [t.value for t in PlanTier] else PlanTier.BASIC
    sub.current_tier = applied_tier.value
    sub.pending_tier  = None

    if sub.status == SubscriptionStatus.ACTIVE and sub.expires_at and sub.expires_at > now:
        sub.expires_at = sub.expires_at + timedelta(days=PLAN_DURATION_DAYS)
    else:
        sub.expires_at = now + timedelta(days=PLAN_DURATION_DAYS)

    sub.status     = SubscriptionStatus.ACTIVE
    sub.updated_at = now

    # Atualizar licença
    result = await db.execute(
        select(License).where(License.user_id == user_id)
    )
    lic = result.scalar_one_or_none()
    if lic:
        lic.status       = LicenseStatus.ACTIVE
        lic.activated_at = now

    await db.commit()


# ── Helper ────────────────────────────────────────────────────────────────────

async def _get_or_create_subscription(
    db: AsyncSession, user_id: uuid.UUID,
) -> Subscription:
    result = await db.execute(
        select(Subscription).where(Subscription.user_id == user_id)
    )
    sub = result.scalar_one_or_none()

    if not sub:
        sub = Subscription(
            user_id=user_id,
            status=SubscriptionStatus.PENDING,
            traded_volume_usdt=0.0,
            current_tier=PlanTier.EXEMPT.value,
        )
        db.add(sub)
        await db.flush()

    # Verificar expiração automática
    if (sub.expires_at and
            sub.expires_at < datetime.now(timezone.utc) and
            sub.status == SubscriptionStatus.ACTIVE):
        sub.status = SubscriptionStatus.EXPIRED
        await db.flush()

    return sub
