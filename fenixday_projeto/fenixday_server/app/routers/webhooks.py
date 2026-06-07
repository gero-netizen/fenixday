"""
FênixDay — Webhook BTCPay Server
Recebe InvoiceSettled e ativa a licença do usuário.
Verifica assinatura HMAC-SHA256 antes de processar.
"""

from __future__ import annotations

import hashlib
import hmac
import json
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.config import settings
from app.database import get_db_context
from app.models.models import Payment, PaymentStatus, User
from app.routers.subscriptions_v2 import activate_after_payment
from app.security.audit_log import log_event

router = APIRouter()


@router.post('/btcpay')
async def btcpay_webhook(request: Request) -> dict:
    """
    Recebe notificações do BTCPay Server.
    Valida HMAC-SHA256 → ativa licença se InvoiceSettled.
    """
    body = await request.body()

    # ── Verificar assinatura HMAC-SHA256 ──────────────────────────────────
    sig_header = request.headers.get('BTCPay-Sig1', '')
    if not sig_header or not settings.BTCPAY_WEBHOOK_SECRET:
        await log_event('WEBHOOK_INVALID', actor_id='btcpay',
                         success=False, metadata='Missing signature or secret')
        raise HTTPException(status_code=401, detail='Webhook não autorizado.')

    expected = hmac.new(
        settings.BTCPAY_WEBHOOK_SECRET.encode(),
        body,
        hashlib.sha256,
    ).hexdigest()
    received = sig_header.removeprefix('sha256=')

    if not hmac.compare_digest(expected, received):
        await log_event('WEBHOOK_INVALID', actor_id='btcpay',
                         success=False, metadata='Invalid HMAC signature')
        raise HTTPException(status_code=401, detail='Assinatura inválida.')

    # ── Processar evento ──────────────────────────────────────────────────
    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail='JSON inválido.')

    event_type  = payload.get('type', '')
    invoice_id  = payload.get('invoiceId', '')
    metadata    = payload.get('metadata', {})
    user_id_str = metadata.get('user_id', '')
    tier        = metadata.get('tier', 'basic')

    if event_type != 'InvoiceSettled':
        return {'status': 'ignored', 'event': event_type}

    if not user_id_str or not invoice_id:
        raise HTTPException(status_code=400, detail='Dados insuficientes no webhook.')

    # ── Ativar licença ────────────────────────────────────────────────────
    async with get_db_context() as db:
        # Verificar se este invoice já foi processado
        result = await db.execute(
            select(Payment).where(Payment.btcpay_invoice_id == invoice_id)
        )
        existing = result.scalar_one_or_none()

        if existing and existing.status == PaymentStatus.CONFIRMED:
            return {'status': 'already_processed', 'invoice_id': invoice_id}

        import uuid
        try:
            user_id = uuid.UUID(user_id_str)
        except ValueError:
            raise HTTPException(status_code=400, detail='user_id inválido.')

        # Atualizar ou criar registro de pagamento
        if existing:
            existing.status       = PaymentStatus.CONFIRMED
            existing.confirmed_at = datetime.now(timezone.utc)
        else:
            amount    = float(payload.get('amount', 0))
            plan_name = metadata.get('plan_name', tier.capitalize())
            payment   = Payment(
                user_id=user_id,
                btcpay_invoice_id=invoice_id,
                amount=amount,
                currency='USDT',
                status=PaymentStatus.CONFIRMED,
                tier=tier,
                plan_name=plan_name,
                confirmed_at=datetime.now(timezone.utc),
            )
            db.add(payment)

        # Ativar licença e plano
        await activate_after_payment(db, user_id, tier)

        await log_event(
            'PAYMENT_CONFIRMED',
            actor_id=user_id_str,
            metadata=json.dumps({'invoice_id': invoice_id, 'tier': tier}),
        )

    return {'status': 'activated', 'invoice_id': invoice_id, 'tier': tier}
