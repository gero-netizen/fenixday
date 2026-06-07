"""
FênixDay — Modelo de Planos por Volume Acumulado
=================================================
Faixas de cobrança baseadas no volume negociado acumulado:

  Faixa 0 — Isento       →  volume < $500         →  gratuito
  Plano Basic             →  $500  – $4.999        →  $10,00/mês
  Plano Pro               →  $5.000 – $34.999      →  $14,99/mês
  Plano Premium           →  ≥ $35.000             →  $29,90/mês

Regras:
  • Mudança de plano sempre na PRÓXIMA renovação
  • Mesmas funcionalidades nos 3 planos pagos
  • Notificação quando próximo da próxima faixa
  • Isenção automática abaixo de $500
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Optional


# ── Definição das faixas ──────────────────────────────────────────────────────

class PlanTier(str, Enum):
    EXEMPT  = "exempt"   # < $500 — gratuito
    BASIC   = "basic"    # $500 – $4.999 — $10/mês
    PRO     = "pro"      # $5.000 – $34.999 — $14,99/mês
    PREMIUM = "premium"  # ≥ $35.000 — $29,90/mês


@dataclass(frozen=True)
class PlanDefinition:
    tier:           PlanTier
    name:           str
    price_monthly:  float         # USD
    volume_min:     float         # volume mínimo para entrar neste plano
    volume_max:     Optional[float]  # None = sem limite superior
    notify_at:      Optional[float]  # volume a partir do qual avisa upgrade
    color_hex:      str           # cor do badge no app


PLANS: dict[PlanTier, PlanDefinition] = {
    PlanTier.EXEMPT: PlanDefinition(
        tier=PlanTier.EXEMPT,
        name='Isento',
        price_monthly=0.0,
        volume_min=0.0,
        volume_max=499.99,
        notify_at=300.0,      # avisa quando faltam $200 para o Basic
        color_hex='#1D9E75',
    ),
    PlanTier.BASIC: PlanDefinition(
        tier=PlanTier.BASIC,
        name='Basic',
        price_monthly=10.00,
        volume_min=500.0,
        volume_max=4_999.99,
        notify_at=4_800.0,    # avisa quando faltam $200 para o Pro
        color_hex='#1E88E5',
    ),
    PlanTier.PRO: PlanDefinition(
        tier=PlanTier.PRO,
        name='Pro',
        price_monthly=14.99,
        volume_min=5_000.0,
        volume_max=34_999.99,
        notify_at=33_000.0,   # avisa quando faltam $2.000 para o Premium
        color_hex='#8957E5',
    ),
    PlanTier.PREMIUM: PlanDefinition(
        tier=PlanTier.PREMIUM,
        name='Premium',
        price_monthly=29.90,
        volume_min=35_000.0,
        volume_max=None,
        notify_at=None,
        color_hex='#F0B90B',
    ),
}


# ── Funções de negócio ────────────────────────────────────────────────────────

def get_tier_for_volume(volume: float) -> PlanTier:
    """Retorna o tier correto para o volume acumulado informado."""
    if volume < 500:
        return PlanTier.EXEMPT
    elif volume < 5_000:
        return PlanTier.BASIC
    elif volume < 35_000:
        return PlanTier.PRO
    else:
        return PlanTier.PREMIUM


def get_next_tier(current: PlanTier) -> Optional[PlanTier]:
    """Retorna o próximo tier acima do atual (None se já for Premium)."""
    order = [PlanTier.EXEMPT, PlanTier.BASIC, PlanTier.PRO, PlanTier.PREMIUM]
    idx = order.index(current)
    if idx < len(order) - 1:
        return order[idx + 1]
    return None


def should_notify_upgrade(volume: float, current_tier: PlanTier) -> bool:
    """
    Retorna True se o cliente está próximo de mudar para o próximo plano
    e deve receber uma notificação.
    """
    plan = PLANS[current_tier]
    if plan.notify_at is None:
        return False
    return volume >= plan.notify_at


def get_upgrade_alert(volume: float, current_tier: PlanTier) -> Optional[dict]:
    """
    Retorna os dados do alerta de upgrade se aplicável, None caso contrário.
    """
    if not should_notify_upgrade(volume, current_tier):
        return None

    next_tier = get_next_tier(current_tier)
    if not next_tier:
        return None

    next_plan   = PLANS[next_tier]
    current_plan = PLANS[current_tier]
    volume_faltante = next_plan.volume_min - volume

    return {
        "type":           "upgrade_warning",
        "current_tier":   current_tier.value,
        "next_tier":      next_tier.value,
        "next_plan_name": next_plan.name,
        "next_price":     next_plan.price_monthly,
        "current_price":  current_plan.price_monthly,
        "volume_faltante": round(volume_faltante, 2),
        "message": (
            f"Você está próximo do plano {next_plan.name}! "
            f"Faltam apenas ${volume_faltante:,.2f} em volume negociado. "
            f"O novo valor será de ${next_plan.price_monthly:.2f}/mês "
            f"na próxima renovação."
        ),
    }


def get_volume_progress(volume: float, current_tier: PlanTier) -> dict:
    """
    Retorna o progresso dentro da faixa atual (0.0 a 1.0) e dados
    para a barra de progresso no app.
    """
    plan = PLANS[current_tier]
    next_tier = get_next_tier(current_tier)

    if next_tier is None:
        # Premium — sem próximo nível
        return {
            "progress": 1.0,
            "volume_atual": volume,
            "volume_min":   plan.volume_min,
            "volume_max":   None,
            "label":        "Plano máximo atingido",
        }

    next_plan = PLANS[next_tier]
    range_size = next_plan.volume_min - plan.volume_min
    progress   = min((volume - plan.volume_min) / range_size, 1.0)
    faltante   = max(next_plan.volume_min - volume, 0)

    return {
        "progress":     round(progress, 4),
        "volume_atual": volume,
        "volume_min":   plan.volume_min,
        "volume_max":   next_plan.volume_min,
        "volume_faltante": round(faltante, 2),
        "label": f"${faltante:,.2f} para o {next_plan.name}",
    }


# ── Endpoint helper (chamado pelo subscriptions.py) ───────────────────────────

def evaluate_plan_change(
    current_volume: float,
    current_tier: PlanTier,
    active_subscription: bool,
) -> dict:
    """
    Avalia se o plano do usuário precisa mudar e retorna as ações necessárias.
    Chamado a cada atualização de volume e na renovação mensal.

    Returns:
        dict com:
          - new_tier: tier correto para o volume atual
          - price_changed: True se o preço mudou
          - apply_now: False (mudança só na renovação)
          - alert: dict de alerta de upgrade se aplicável
          - progress: dict de progresso na faixa atual
    """
    correct_tier = get_tier_for_volume(current_volume)
    price_changed = correct_tier != current_tier

    alert    = get_upgrade_alert(current_volume, current_tier)
    progress = get_volume_progress(current_volume, current_tier)

    return {
        "current_tier":    current_tier.value,
        "new_tier":        correct_tier.value,
        "current_price":   PLANS[current_tier].price_monthly,
        "new_price":       PLANS[correct_tier].price_monthly,
        "price_changed":   price_changed,
        "apply_now":       False,   # sempre na próxima renovação
        "active_sub":      active_subscription,
        "alert":           alert,
        "progress":        progress,
    }
