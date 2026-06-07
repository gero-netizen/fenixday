"""
FênixDay Scanner — scanner_runner.py
Ponto de entrada principal do Scanner de IA.

Modos:
  python scanner_runner.py --test   # dados mockados (CI/CD)
  python scanner_runner.py --once   # varredura única e encerra
  python scanner_runner.py --serve  # loop a cada 15 minutos
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import sys
import time
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s — %(message)s',
    datefmt='%H:%M:%S',
)
log = logging.getLogger('scanner')

RESCAN_INTERVAL = 15 * 60   # 15 minutos
OUTPUT_FILE     = Path('/tmp/fenixday_scanner_top20.json')


# ── Dados mockados para --test ────────────────────────────────────────────────

def _mock_top20() -> list[dict]:
    return [
        {'rank':1,  'symbol':'BNB/USDT',  'score':89, 'adx':12.1, 'atr_pct':0.71, 'bb_width':0.82, 'mm200_slope':0.3, 'volume_24h':98_800_000},
        {'rank':2,  'symbol':'XRP/USDT',  'score':87, 'adx':14.8, 'atr_pct':0.88, 'bb_width':0.91, 'mm200_slope':0.4, 'volume_24h':177_700_000},
        {'rank':3,  'symbol':'DOGE/USDT', 'score':85, 'adx':13.5, 'atr_pct':0.93, 'bb_width':0.88, 'mm200_slope':0.5, 'volume_24h':100_300_000},
        {'rank':4,  'symbol':'ADA/USDT',  'score':82, 'adx':16.2, 'atr_pct':0.76, 'bb_width':0.79, 'mm200_slope':0.6, 'volume_24h':44_200_000},
        {'rank':5,  'symbol':'LINK/USDT', 'score':80, 'adx':17.1, 'atr_pct':0.82, 'bb_width':0.85, 'mm200_slope':0.7, 'volume_24h':46_900_000},
    ]


# ── Varredura real ────────────────────────────────────────────────────────────

async def run_scan() -> list[dict]:
    from binance_fetcher import fetch_eligible_pairs
    from indicators import calc_indicators
    from top20_selector import select_top20

    start = time.perf_counter()
    log.info('Iniciando varredura...')

    # 1. Buscar pares elegíveis (paralelo)
    pairs = await fetch_eligible_pairs()
    log.info('Pares com dados: %d', len(pairs))

    # 2. Calcular indicadores (CPU — rápido)
    indicators = [calc_indicators(p) for p in pairs]

    # 3. Filtrar e ranquear
    top20 = select_top20(indicators)

    elapsed = time.perf_counter() - start
    log.info('Varredura concluída em %.1fs — top20 selecionados', elapsed)

    # Imprimir ranking
    print(f'\n{"═"*62}')
    print(f'  FênixDay Scanner — Top 20 — {datetime.now(timezone.utc).strftime("%d/%m/%Y %H:%M")} UTC')
    print(f'{"═"*62}')
    print(f'  {"#":<4} {"Par":<14} {"Score":>5} {"ADX":>6} {"ATR%":>6} {"BB":>6} {"Slope":>7}')
    print(f'  {"─"*4} {"─"*14} {"─"*5} {"─"*6} {"─"*6} {"─"*6} {"─"*7}')
    for p in top20:
        print(
            f'  {p.rank:<4} {p.symbol:<14} {p.score:>5} '
            f'{p.adx:>6.1f} {p.atr_pct:>6.2f} {p.bb_width:>6.2f} {p.mm200_slope:>7.2f}'
        )
    print(f'{"═"*62}\n')

    return [asdict(p) for p in top20]


def save_results(results: list[dict]) -> None:
    """Salva o resultado em JSON para o backend consumir via endpoint."""
    OUTPUT_FILE.write_text(json.dumps({
        'timestamp': datetime.now(timezone.utc).isoformat(),
        'top20':     results,
    }, ensure_ascii=False, indent=2))
    log.info('Resultado salvo em %s', OUTPUT_FILE)


# ── Modos ─────────────────────────────────────────────────────────────────────

async def mode_test() -> None:
    log.info('Modo TEST — usando dados mockados')
    results = _mock_top20()
    for r in results:
        print(f"  #{r['rank']:>2} {r['symbol']:<14} score={r['score']}")
    save_results(results)
    log.info('Teste OK')


async def mode_once() -> None:
    results = await run_scan()
    save_results(results)


async def mode_serve() -> None:
    log.info('Modo SERVE — re-varredura a cada %d minutos', RESCAN_INTERVAL // 60)
    while True:
        try:
            results = await run_scan()
            save_results(results)
        except Exception as e:
            log.error('Erro na varredura: %s', e, exc_info=True)
        await asyncio.sleep(RESCAN_INTERVAL)


# ── Entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description='FênixDay IA Scanner')
    group  = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--test',  action='store_true', help='Modo teste (mock)')
    group.add_argument('--once',  action='store_true', help='Varredura única')
    group.add_argument('--serve', action='store_true', help='Loop contínuo')
    args = parser.parse_args()

    try:
        if args.test:
            asyncio.run(mode_test())
        elif args.once:
            asyncio.run(mode_once())
        elif args.serve:
            asyncio.run(mode_serve())
    except KeyboardInterrupt:
        log.info('Scanner encerrado.')
        sys.exit(0)


if __name__ == '__main__':
    main()
