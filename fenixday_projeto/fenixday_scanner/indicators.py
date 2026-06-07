"""
FênixDay Scanner — indicadores técnicos
ADX · ATR · Bollinger Bands · MM200 slope
"""

from __future__ import annotations

import math
from dataclasses import dataclass

from binance_fetcher import PairData


@dataclass
class Indicators:
    symbol:     str
    adx:        float    # 0–100  (< 22 = lateral = bom)
    atr_pct:    float    # ATR como % do preço (0,5%–1,2% = ideal)
    bb_width:   float    # largura Bollinger relativa ao preço médio
    mm200_slope: float   # inclinação da MM200 (próximo de 0 = plano = ideal)
    volume_24h: float


# ── Helpers ───────────────────────────────────────────────────────────────────

def _closes(klines: list) -> list[float]:
    return [float(k[4]) for k in klines]

def _highs(klines: list) -> list[float]:
    return [float(k[2]) for k in klines]

def _lows(klines: list) -> list[float]:
    return [float(k[3]) for k in klines]


# ── ATR ───────────────────────────────────────────────────────────────────────

def calc_atr(klines: list, period: int = 14) -> float:
    closes = _closes(klines)
    highs  = _highs(klines)
    lows   = _lows(klines)

    trs = []
    for i in range(1, len(klines)):
        tr = max(
            highs[i] - lows[i],
            abs(highs[i] - closes[i-1]),
            abs(lows[i]  - closes[i-1]),
        )
        trs.append(tr)

    if len(trs) < period:
        return 0.0

    # Wilder smoothing
    atr = sum(trs[:period]) / period
    for tr in trs[period:]:
        atr = (atr * (period - 1) + tr) / period

    return atr


# ── ADX ───────────────────────────────────────────────────────────────────────

def calc_adx(klines: list, period: int = 14) -> float:
    closes = _closes(klines)
    highs  = _highs(klines)
    lows   = _lows(klines)

    plus_dm, minus_dm, trs = [], [], []

    for i in range(1, len(klines)):
        h_diff = highs[i]  - highs[i-1]
        l_diff = lows[i-1] - lows[i]
        plus_dm.append(h_diff if h_diff > l_diff and h_diff > 0 else 0)
        minus_dm.append(l_diff if l_diff > h_diff and l_diff > 0 else 0)
        trs.append(max(
            highs[i] - lows[i],
            abs(highs[i] - closes[i-1]),
            abs(lows[i]  - closes[i-1]),
        ))

    if len(trs) < period * 2:
        return 25.0  # valor neutro se dados insuficientes

    def wilder_smooth(data: list, p: int) -> list:
        result = [sum(data[:p])]
        for v in data[p:]:
            result.append(result[-1] - result[-1]/p + v)
        return result

    sm_tr      = wilder_smooth(trs,      period)
    sm_plus    = wilder_smooth(plus_dm,  period)
    sm_minus   = wilder_smooth(minus_dm, period)

    dx_list = []
    for i in range(len(sm_tr)):
        if sm_tr[i] == 0:
            continue
        plus_di  = 100 * sm_plus[i]  / sm_tr[i]
        minus_di = 100 * sm_minus[i] / sm_tr[i]
        denom    = plus_di + minus_di
        if denom == 0:
            continue
        dx_list.append(100 * abs(plus_di - minus_di) / denom)

    if not dx_list:
        return 25.0

    # ADX = Wilder smooth do DX
    adx = sum(dx_list[:period]) / period
    for dx in dx_list[period:]:
        adx = (adx * (period - 1) + dx) / period

    return round(adx, 2)


# ── Bollinger Bands ───────────────────────────────────────────────────────────

def calc_bollinger_width(klines: list, period: int = 20, mult: float = 2.0) -> float:
    closes = _closes(klines)
    if len(closes) < period:
        return 0.0

    recent = closes[-period:]
    mm     = sum(recent) / period
    std    = math.sqrt(sum((c - mm) ** 2 for c in recent) / period)
    upper  = mm + mult * std
    lower  = mm - mult * std

    # Largura relativa ao preço médio
    width = (upper - lower) / mm if mm > 0 else 0
    return round(width * 100, 4)   # em %


# ── MM200 slope ───────────────────────────────────────────────────────────────

def calc_mm200_slope(klines: list, period: int = 200) -> float:
    closes = _closes(klines)
    if len(closes) < period:
        period = len(closes)

    recent  = closes[-period:]
    mm_now  = sum(recent) / period
    mm_prev = sum(closes[-(period+5):-5]) / period if len(closes) > period + 5 else mm_now

    # Slope em % por período
    slope = ((mm_now - mm_prev) / mm_prev * 100) if mm_prev > 0 else 0
    return round(abs(slope), 4)


# ── Calcular todos os indicadores ─────────────────────────────────────────────

def calc_indicators(pair: PairData) -> Indicators:
    price  = pair.price
    klines = pair.klines

    atr      = calc_atr(klines)
    atr_pct  = (atr / price * 100) if price > 0 else 0
    adx      = calc_adx(klines)
    bb_width = calc_bollinger_width(klines)
    slope    = calc_mm200_slope(klines)

    return Indicators(
        symbol      = pair.symbol,
        adx         = adx,
        atr_pct     = round(atr_pct, 4),
        bb_width    = round(bb_width, 4),
        mm200_slope = slope,
        volume_24h  = pair.volume_24h,
    )
