"""
FênixDay Scanner — binance_fetcher.py
Busca todos os pares USDT da Binance com volume > $20M
e os últimos 200 candles de 1h para cada par elegível.
"""

from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass

import httpx

log = logging.getLogger(__name__)

BINANCE_BASE    = 'https://api.binance.com'
MIN_VOLUME_USDT = 20_000_000   # $20M mínimo
KLINES_LIMIT    = 200
TIMEFRAME       = '1h'
MAX_CONCURRENCY = 30           # máximo de requisições paralelas


@dataclass
class PairData:
    symbol:       str
    price:        float
    volume_24h:   float       # em USDT
    price_change: float       # % em 24h
    klines:       list[list]  # OHLCV — raw da Binance


async def fetch_ticker_24h(client: httpx.AsyncClient) -> list[dict]:
    """Busca o ticker 24h de todos os pares (uma única chamada)."""
    resp = await client.get(f'{BINANCE_BASE}/api/v3/ticker/24hr', timeout=15)
    resp.raise_for_status()
    return resp.json()


async def fetch_klines(
    client: httpx.AsyncClient,
    symbol: str,
    semaphore: asyncio.Semaphore,
) -> list[list] | None:
    """Busca 200 candles de 1h para um par."""
    async with semaphore:
        try:
            resp = await client.get(
                f'{BINANCE_BASE}/api/v3/klines',
                params={'symbol': symbol, 'interval': TIMEFRAME, 'limit': KLINES_LIMIT},
                timeout=10,
            )
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            log.warning('Erro ao buscar klines de %s: %s', symbol, e)
            return None


async def fetch_eligible_pairs() -> list[PairData]:
    """
    1. Busca todos os tickers 24h
    2. Filtra pares USDT com volume > MIN_VOLUME_USDT
    3. Busca klines em paralelo com controle de concorrência
    4. Retorna lista de PairData pronta para análise
    """
    async with httpx.AsyncClient() as client:
        # Ticker geral
        tickers = await fetch_ticker_24h(client)
        log.info('Tickers recebidos: %d pares', len(tickers))

        # Filtrar pares USDT com volume suficiente
        eligible = [
            t for t in tickers
            if t['symbol'].endswith('USDT')
            and float(t['quoteVolume']) >= MIN_VOLUME_USDT
            and not t['symbol'].endswith('DOWNUSDT')
            and not t['symbol'].endswith('UPUSDT')
            and not t['symbol'].endswith('BULLUSDT')
            and not t['symbol'].endswith('BEARUSDT')
        ]
        log.info('Pares elegíveis (vol > $%dM): %d', MIN_VOLUME_USDT // 1_000_000, len(eligible))

        # Buscar klines em paralelo
        semaphore = asyncio.Semaphore(MAX_CONCURRENCY)
        tasks = [
            fetch_klines(client, t['symbol'], semaphore)
            for t in eligible
        ]
        klines_results = await asyncio.gather(*tasks)

        # Montar lista final
        pairs: list[PairData] = []
        for ticker, klines in zip(eligible, klines_results):
            if klines and len(klines) >= 50:
                pairs.append(PairData(
                    symbol       = ticker['symbol'],
                    price        = float(ticker['lastPrice']),
                    volume_24h   = float(ticker['quoteVolume']),
                    price_change = float(ticker['priceChangePercent']),
                    klines       = klines,
                ))

        log.info('Pares com klines suficientes: %d', len(pairs))
        return pairs
