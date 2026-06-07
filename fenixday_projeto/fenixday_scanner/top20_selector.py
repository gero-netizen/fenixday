"""
FênixDay Scanner — top20_selector.py
Aplica os filtros e calcula o score ponderado para ranquear pares.

Pesos:
  ADX (lateralidade)   35%
  ATR (vol. ideal)     25%
  Bollinger (largura)  20%
  MM200 slope          10%
  Volume 24h           10%
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

from indicators import Indicators

log = logging.getLogger(__name__)

# ── Limites dos filtros ───────────────────────────────────────────────────────

ADX_MAX       = 22.0    # acima disso = tendência = descarta
ATR_MIN       = 0.50    # % mínimo — oscilação suficiente
ATR_MAX       = 1.20    # % máximo — não muito volátil
BB_WIDTH_MIN  = 0.40    # Bollinger não muito estreito
BB_WIDTH_MAX  = 2.50    # Bollinger não muito largo
MM200_MAX     = 3.0     # slope máximo (graus/%) — acima = tendência

# ── Pesos ─────────────────────────────────────────────────────────────────────

WEIGHTS = {
    'adx':     0.35,
    'atr':     0.25,
    'bb':      0.20,
    'mm200':   0.10,
    'volume':  0.10,
}

# Volume de referência para score máximo ($500M)
VOLUME_REF = 500_000_000


@dataclass
class ScoredPair:
    symbol:      str
    score:       int        # 0–100
    adx:         float
    atr_pct:     float
    bb_width:    float
    mm200_slope: float
    volume_24h:  float
    rank:        int = 0


def _score_adx(adx: float) -> float:
    """ADX baixo = score alto. ADX >= ADX_MAX = 0."""
    if adx >= ADX_MAX:
        return 0.0
    return max(0, 1 - adx / ADX_MAX)


def _score_atr(atr_pct: float) -> float:
    """Nota máxima quando ATR está no centro da faixa ideal."""
    if atr_pct < ATR_MIN or atr_pct > ATR_MAX:
        return max(0, 1 - abs(atr_pct - (ATR_MIN + ATR_MAX) / 2) / ATR_MAX)
    mid = (ATR_MIN + ATR_MAX) / 2
    return max(0, 1 - abs(atr_pct - mid) / (ATR_MAX - ATR_MIN))


def _score_bb(bb_width: float) -> float:
    """Nota máxima quando Bollinger está na faixa ideal."""
    if bb_width < BB_WIDTH_MIN:
        return bb_width / BB_WIDTH_MIN * 0.5
    if bb_width > BB_WIDTH_MAX:
        return max(0, 1 - (bb_width - BB_WIDTH_MAX) / BB_WIDTH_MAX)
    mid = (BB_WIDTH_MIN + BB_WIDTH_MAX) / 2
    return max(0, 1 - abs(bb_width - mid) / (BB_WIDTH_MAX - BB_WIDTH_MIN))


def _score_mm200(slope: float) -> float:
    """Slope próximo de zero = nota máxima."""
    return max(0, 1 - slope / MM200_MAX)


def _score_volume(volume: float) -> float:
    """Volume maior = score maior (cap no volume de referência)."""
    return min(1.0, volume / VOLUME_REF)


def apply_filters(ind: Indicators) -> bool:
    """Retorna True se o par passa em todos os filtros."""
    if ind.adx >= ADX_MAX:
        return False
    if not (ATR_MIN * 0.7 <= ind.atr_pct <= ATR_MAX * 1.5):
        return False
    if not (BB_WIDTH_MIN * 0.5 <= ind.bb_width <= BB_WIDTH_MAX * 1.5):
        return False
    if ind.mm200_slope > MM200_MAX * 1.5:
        return False
    return True


def calc_score(ind: Indicators) -> int:
    raw = (
        _score_adx(ind.adx)        * WEIGHTS['adx']   +
        _score_atr(ind.atr_pct)    * WEIGHTS['atr']   +
        _score_bb(ind.bb_width)    * WEIGHTS['bb']     +
        _score_mm200(ind.mm200_slope) * WEIGHTS['mm200'] +
        _score_volume(ind.volume_24h) * WEIGHTS['volume']
    )
    return min(100, max(0, round(raw * 100)))


def select_top20(indicators: list[Indicators]) -> list[ScoredPair]:
    """
    1. Aplica filtros
    2. Calcula score de cada par
    3. Retorna os top 20 ordenados por score
    """
    passed = [ind for ind in indicators if apply_filters(ind)]
    log.info('Pares que passaram nos filtros: %d', len(passed))

    scored = [
        ScoredPair(
            symbol      = ind.symbol,
            score       = calc_score(ind),
            adx         = ind.adx,
            atr_pct     = ind.atr_pct,
            bb_width    = ind.bb_width,
            mm200_slope = ind.mm200_slope,
            volume_24h  = ind.volume_24h,
        )
        for ind in passed
    ]

    scored.sort(key=lambda p: p.score, reverse=True)
    top20 = scored[:20]

    for i, pair in enumerate(top20, 1):
        pair.rank = i

    return top20
