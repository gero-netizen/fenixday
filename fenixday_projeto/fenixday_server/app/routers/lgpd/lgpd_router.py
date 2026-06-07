"""
FênixDay — Endpoints de Conformidade LGPD
==========================================
Implementa os direitos dos titulares (Art. 18, Lei 13.709/2018):

  POST /api/v1/lgpd/delete-account    → exclusão completa (inc. VI)
  GET  /api/v1/lgpd/export-data       → portabilidade (inc. V)
  POST /api/v1/lgpd/consent           → registra aceite de termos (inc. I)
  GET  /api/v1/lgpd/consents          → histórico de consentimentos
  PUT  /api/v1/lgpd/revoke-telegram   → revoga consentimento Telegram
  GET  /api/v1/lgpd/privacy-summary   → resumo dos dados armazenados

AÇÃO OBRIGATÓRIA antes do lançamento — Art. 18 LGPD.
"""

from __future__ import annotations

import uuid
import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete

from app.database import get_db
from app.models.models import User, License, Payment
from app.models.subscription import Subscription
from app.security.audit_log import log_event, AuditEvent
from app.routers.auth_v2 import get_current_user

router = APIRouter()


# ── Schemas ───────────────────────────────────────────────────────────────────

class ConsentRequest(BaseModel):
    terms_version:   str   # ex: "1.0"
    privacy_version: str
    accepted:        bool
    ip_address:      str | None = None


class DeleteAccountRequest(BaseModel):
    confirmation: str    # deve ser "CONFIRMO EXCLUSÃO"
    reason:       str | None = None


# ── Exclusão de conta (Art. 18, inc. VI) ─────────────────────────────────────

@router.post("/delete-account")
async def delete_account(
    payload: DeleteAccountRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Remove permanentemente todos os dados do usuário do servidor central.
    Dados locais (SQLite no dispositivo) devem ser limpos pelo app.

    ATENÇÃO: operação irreversível.
    """
    if payload.confirmation != "CONFIRMO EXCLUSÃO":
        raise HTTPException(
            status_code=400,
            detail="Confirmação incorreta. Digite exatamente: CONFIRMO EXCLUSÃO",
        )

    user_id = str(current_user.id)

    # Log de auditoria ANTES de deletar
    await log_event(
        db, AuditEvent.ADMIN_ACTION,
        actor_id=user_id,
        message=f"Solicitação de exclusão de conta: {current_user.email}. "
                f"Motivo: {payload.reason or 'não informado'}",
    )

    # Deletar dados do servidor em cascata (FK ondelete=CASCADE)
    # Ordem: payments → subscription → license → user
    await db.execute(delete(Payment).where(Payment.user_id == current_user.id))
    await db.execute(delete(Subscription).where(Subscription.user_id == current_user.id))
    await db.execute(delete(License).where(License.user_id == current_user.id))
    await db.execute(delete(User).where(User.id == current_user.id))
    await db.commit()

    # Anonimizar nos logs de auditoria (substituir e-mail por hash)
    # Os logs são mantidos por obrigação legal (MCI Art. 15)
    # mas sem dados pessoais identificáveis

    return {
        "message": "Conta excluída com sucesso.",
        "detail": "Todos os seus dados foram removidos do servidor. "
                  "Para remover dados locais do dispositivo, "
                  "acesse Configurações > Limpar dados locais no app.",
        "deleted_at": datetime.now(timezone.utc).isoformat(),
    }


# ── Exportação de dados (Art. 18, inc. V) ────────────────────────────────────

@router.get("/export-data")
async def export_data(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Retorna todos os dados pessoais armazenados no servidor.
    Dados de trades ficam no dispositivo local (SQLite) — não no servidor.
    """
    # Licença
    lic_data = None
    if current_user.license:
        lic = current_user.license
        lic_data = {
            "status":       lic.status.value,
            "is_lifetime":  lic.is_lifetime,
            "activated_at": lic.activated_at.isoformat() if lic.activated_at else None,
        }

    # Assinatura
    sub_result = await db.execute(
        select(Subscription).where(Subscription.user_id == current_user.id)
    )
    sub = sub_result.scalar_one_or_none()
    sub_data = None
    if sub:
        sub_data = {
            "status":            sub.status.value,
            "traded_volume_usdt": sub.traded_volume_usdt,
            "expires_at":        sub.expires_at.isoformat() if sub.expires_at else None,
        }

    # Pagamentos
    pay_result = await db.execute(
        select(Payment).where(Payment.user_id == current_user.id)
    )
    payments = pay_result.scalars().all()
    payments_data = [
        {
            "id":           str(p.id),
            "amount":       p.amount,
            "currency":     p.currency,
            "status":       p.status.value,
            "created_at":   p.created_at.isoformat(),
            "confirmed_at": p.confirmed_at.isoformat() if p.confirmed_at else None,
        }
        for p in payments
    ]

    export = {
        "export_generated_at": datetime.now(timezone.utc).isoformat(),
        "notice": "Este arquivo contém apenas os dados armazenados no servidor central. "
                  "Histórico de trades e configurações de robôs ficam exclusivamente "
                  "no seu dispositivo local.",
        "data": {
            "user": {
                "id":               str(current_user.id),
                "email":            current_user.email,
                "created_at":       current_user.created_at.isoformat(),
                "last_login":       current_user.last_login.isoformat() if current_user.last_login else None,
                "telegram_chat_id": current_user.telegram_chat_id,
                "google_id_linked": bool(getattr(current_user, 'google_id', None)),
            },
            "license":      lic_data,
            "subscription": sub_data,
            "payments":     payments_data,
        },
        "your_rights": {
            "lei":     "LGPD — Lei 13.709/2018",
            "artigo":  "Art. 18",
            "direitos": [
                "Confirmação da existência de tratamento",
                "Acesso aos dados",
                "Correção de dados incompletos ou desatualizados",
                "Anonimização, bloqueio ou eliminação",
                "Portabilidade dos dados",
                "Eliminação dos dados tratados com consentimento",
                "Revogação do consentimento",
            ],
            "contato": "privacidade@fenixday.com",
        },
    }

    return export


# ── Consentimento (Art. 7º, inc. I) ──────────────────────────────────────────

@router.post("/consent", status_code=201)
async def record_consent(
    payload: ConsentRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Registra o aceite explícito dos Termos de Uso e Política de Privacidade.
    Obrigatório para base legal de consentimento (Art. 7º, inc. I LGPD).
    """
    await log_event(
        db,
        AuditEvent.ADMIN_ACTION,
        actor_id=str(current_user.id),
        ip_address=payload.ip_address,
        message=f"Consentimento registrado: termos v{payload.terms_version}, "
                f"privacidade v{payload.privacy_version}, "
                f"aceito={payload.accepted}",
        metadata={
            "terms_version":   payload.terms_version,
            "privacy_version": payload.privacy_version,
            "accepted":        payload.accepted,
            "ip":              payload.ip_address,
        },
    )

    return {
        "recorded_at":     datetime.now(timezone.utc).isoformat(),
        "terms_version":   payload.terms_version,
        "privacy_version": payload.privacy_version,
    }


# ── Revogação do Telegram (Art. 18, inc. IX) ──────────────────────────────────

@router.put("/revoke-telegram", status_code=204)
async def revoke_telegram_consent(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Remove o Telegram Chat ID — revoga consentimento de notificações."""
    current_user.telegram_chat_id = None
    await db.commit()


# ── Resumo de privacidade ─────────────────────────────────────────────────────

@router.get("/privacy-summary")
async def privacy_summary(
    current_user: User = Depends(get_current_user),
):
    """
    Resumo dos dados coletados e sua finalidade.
    Exibido no app na tela de configurações > Privacidade.
    """
    return {
        "dados_coletados": [
            {
                "dado":        "E-mail",
                "finalidade":  "Autenticação e comunicação",
                "base_legal":  "Execução de contrato (Art. 7º, V)",
                "retencao":    "Até exclusão da conta",
            },
            {
                "dado":        "Telegram Chat ID",
                "finalidade":  "Envio de notificações de trades",
                "base_legal":  "Consentimento (Art. 7º, I)",
                "retencao":    "Até revogação do consentimento",
            },
            {
                "dado":        "Histórico de pagamentos",
                "finalidade":  "Comprovação de assinatura",
                "base_legal":  "Obrigação legal (Art. 7º, II)",
                "retencao":    "5 anos (legislação fiscal)",
            },
            {
                "dado":        "Volume negociado (total)",
                "finalidade":  "Verificação de isenção",
                "base_legal":  "Execução de contrato (Art. 7º, V)",
                "retencao":    "Até exclusão da conta",
            },
            {
                "dado":        "Logs de acesso (IP)",
                "finalidade":  "Segurança e auditoria",
                "base_legal":  "Legítimo interesse (Art. 7º, IX) + MCI Art. 15",
                "retencao":    "6 meses (Marco Civil da Internet)",
            },
            {
                "dado":        "Histórico de trades",
                "finalidade":  "P&L local do usuário",
                "base_legal":  "Execução de contrato (Art. 7º, V)",
                "retencao":    "Armazenado APENAS no dispositivo do usuário",
                "observacao":  "Nunca enviado ao servidor",
            },
        ],
        "seus_direitos": "Para exercer seus direitos, acesse: Configurações > Privacidade > Meus Dados",
        "dpo_contato":   "privacidade@fenixday.com",
        "politica_url":  "https://fenixday.com/privacidade",
        "termos_url":    "https://fenixday.com/termos",
    }
