"""
FênixDay — Simulador Realista de Spot Grid Bot
===============================================
Regras reais do mercado Spot aplicadas:

  1. Capital fragmentado pelo nº de grids → valor por ordem
  2. Lucro por ciclo = margem% × valor_por_ordem (NÃO sobre capital total)
  3. Reinvestimento (juros compostos) só ocorre quando caixa acumulado
     atingir >= 1% do capital operacional → recalcula ordens uniformemente
  4. Respeita Min Notional Binance: $10 por ordem mínima

Resultado: crescimento realista por degraus, não exponencial irreal.
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Optional
import math


# ── Constantes da Binance Spot ────────────────────────────────────────────────

MIN_NOTIONAL    = 10.0   # Tamanho mínimo de ordem em USDT
REINVEST_GATILHO = 0.01  # Caixa deve atingir 1% do capital operacional


# ── Modelo de estado ──────────────────────────────────────────────────────────

@dataclass
class DaySnapshot:
    dia:               int
    capital_operando:  float   # capital efetivamente alocado nos grids
    caixa_retido:      float   # lucro acumulado aguardando reinvestimento
    patrimonio_total:  float   # capital_operando + caixa_retido
    valor_por_ordem:   float   # capital_operando / num_grids
    ciclos_dia:        int
    lucro_dia:         float
    lucro_acumulado:   float
    reinvestiu:        bool    # True se houve reinjeção de caixa hoje
    rentab_total_pct:  float   # ((patrimônio_total / capital_inicial) - 1) × 100


@dataclass
class SimulacaoResultado:
    capital_inicial:    float
    margem_pct:         float
    num_grids:          int
    ciclos_dia:         int
    dias:               int
    snapshots:          list[DaySnapshot] = field(default_factory=list)

    @property
    def patrimonio_final(self) -> float:
        return self.snapshots[-1].patrimonio_total if self.snapshots else self.capital_inicial

    @property
    def lucro_total(self) -> float:
        return self.patrimonio_final - self.capital_inicial

    @property
    def rentab_total_pct(self) -> float:
        return (self.lucro_total / self.capital_inicial) * 100

    @property
    def num_reinvestimentos(self) -> int:
        return sum(1 for s in self.snapshots if s.reinvestiu)

    @property
    def resumo(self) -> dict:
        s = self.snapshots
        return {
            "capital_inicial":    self.capital_inicial,
            "patrimonio_final":   round(self.patrimonio_final, 2),
            "lucro_total":        round(self.lucro_total, 2),
            "rentabilidade_pct":  round(self.rentab_total_pct, 2),
            "ciclos_totais":      self.ciclos_dia * self.dias,
            "reinvestimentos":    sum(1 for d in s if d.reinvestiu),
            "valor_ordem_inicial": round(self.capital_inicial / self.num_grids, 2),
            "valor_ordem_final":  round(s[-1].valor_por_ordem, 2) if s else 0,
            "lucro_7d":           round(s[6].lucro_acumulado, 2)  if len(s) >= 7   else 0,
            "lucro_30d":          round(s[29].lucro_acumulado, 2) if len(s) >= 30  else 0,
            "lucro_90d":          round(s[89].lucro_acumulado, 2) if len(s) >= 90  else 0,
            "lucro_180d":         round(s[179].lucro_acumulado, 2)if len(s) >= 180 else 0,
            "lucro_365d":         round(s[364].lucro_acumulado, 2)if len(s) >= 365 else 0,
        }


# ── Função principal ──────────────────────────────────────────────────────────

def simular_grid_spot(
    capital_inicial:  float = 300.0,   # USDT alocados no grid
    margem_pct:       float = 0.28,    # % de lucro por ciclo (após taxas)
    num_grids:        int   = 25,      # número de grades (ordens de compra+venda)
    ciclos_dia:       int   = 6,       # ciclos fechados por dia (par buy+sell)
    dias:             int   = 365,     # horizonte da simulação
    gatilho_reinvest: float = REINVEST_GATILHO,  # caixa/capital para reinjetar
    min_notional:     float = MIN_NOTIONAL,       # tamanho mínimo por ordem
) -> SimulacaoResultado:
    """
    Simula o crescimento realista de um Spot Grid Bot com reinvestimento
    por degraus — não exponencial puro.

    Lógica:
      • Lucro diário = (margem% / 100) × valor_por_ordem × ciclos_dia
      • Lucro vai para caixa_retido (não composto imediatamente)
      • Reinvestimento ocorre quando: caixa_retido >= gatilho × capital_operando
        E o novo valor_por_ordem >= min_notional
      • No reinvestimento: capital_operando += caixa_retido; caixa_retido = 0;
        valor_por_ordem = capital_operando / num_grids (recalculado)
    """

    resultado = SimulacaoResultado(
        capital_inicial = capital_inicial,
        margem_pct      = margem_pct,
        num_grids       = num_grids,
        ciclos_dia      = ciclos_dia,
        dias            = dias,
    )

    capital_operando = capital_inicial
    caixa_retido     = 0.0
    lucro_acumulado  = 0.0

    valor_por_ordem  = capital_operando / num_grids

    # Verificar viabilidade do capital inicial
    if valor_por_ordem < min_notional:
        raise ValueError(
            f"Capital insuficiente: ${capital_inicial:.2f} / {num_grids} grids = "
            f"${valor_por_ordem:.2f} por ordem, abaixo do mínimo ${min_notional:.2f}. "
            f"Capital mínimo necessário: ${num_grids * min_notional:.2f}."
        )

    for dia in range(1, dias + 1):
        reinvestiu = False

        # ── Lucro do dia ────────────────────────────────────────────────────
        # Calculado sobre o VALOR DA ORDEM, não sobre o capital total
        lucro_dia    = (margem_pct / 100) * valor_por_ordem * ciclos_dia
        caixa_retido += lucro_dia
        lucro_acumulado += lucro_dia

        # ── Verificar gatilho de reinvestimento ─────────────────────────────
        # O caixa só é reinjetado quando atingir 1% do capital operando
        # E o novo valor_por_ordem ainda respeitar o min_notional
        gatilho_valor       = gatilho_reinvest * capital_operando
        novo_capital_teste  = capital_operando + caixa_retido
        novo_valor_ordem    = novo_capital_teste / num_grids

        if caixa_retido >= gatilho_valor and novo_valor_ordem >= min_notional:
            capital_operando = novo_capital_teste
            caixa_retido     = 0.0
            valor_por_ordem  = capital_operando / num_grids
            reinvestiu       = True

        patrimonio_total = capital_operando + caixa_retido
        rentab_total_pct = ((patrimonio_total / capital_inicial) - 1) * 100

        resultado.snapshots.append(DaySnapshot(
            dia              = dia,
            capital_operando = round(capital_operando, 4),
            caixa_retido     = round(caixa_retido, 4),
            patrimonio_total = round(patrimonio_total, 4),
            valor_por_ordem  = round(valor_por_ordem, 4),
            ciclos_dia       = ciclos_dia,
            lucro_dia        = round(lucro_dia, 4),
            lucro_acumulado  = round(lucro_acumulado, 4),
            reinvestiu       = reinvestiu,
            rentab_total_pct = round(rentab_total_pct, 2),
        ))

    return resultado


# ── Relatório formatado ───────────────────────────────────────────────────────

def imprimir_relatorio(r: SimulacaoResultado, mostrar_dias: bool = False) -> None:
    sep = "─" * 60

    print(f"\n{'═'*60}")
    print(f"  FênixDay — Simulação Spot Grid Bot")
    print(f"{'═'*60}")
    print(f"  Capital inicial : ${r.capital_inicial:,.2f}")
    print(f"  Nº de grids     : {r.num_grids}")
    print(f"  Margem/ciclo    : {r.margem_pct:.2f}%")
    print(f"  Ciclos/dia      : {r.ciclos_dia}")
    print(f"  Período         : {r.dias} dias")
    print(sep)

    res = r.resumo
    print(f"  Valor por ordem inicial : ${res['valor_ordem_inicial']:,.2f}")
    print(f"  Valor por ordem final   : ${res['valor_ordem_final']:,.2f}")
    print(sep)

    marcos = [
        ("7 dias",   "lucro_7d"),
        ("30 dias",  "lucro_30d"),
        ("90 dias",  "lucro_90d"),
        ("180 dias", "lucro_180d"),
        ("365 dias", "lucro_365d"),
    ]
    for label, key in marcos:
        if res[key] > 0:
            rentab = (res[key] / r.capital_inicial) * 100
            print(f"  Lucro {label:<8}: ${res[key]:>9,.2f}  ({rentab:.2f}%)")

    print(sep)
    print(f"  Patrimônio final  : ${res['patrimonio_final']:,.2f}")
    print(f"  Lucro total       : ${res['lucro_total']:,.2f}")
    print(f"  Rentabilidade     : {res['rentabilidade_pct']:.2f}%")
    print(f"  Reinvestimentos   : {res['reinvestimentos']}x")
    print(f"  Ciclos totais     : {res['ciclos_totais']:,}")
    print(f"{'═'*60}\n")

    if mostrar_dias:
        print(f"  {'Dia':<5} {'Capital Op.':<14} {'Caixa':<12} {'Patrimônio':<14} {'Lucro Dia':<12} {'Reinvest.'}")
        print(f"  {'─'*5} {'─'*14} {'─'*12} {'─'*14} {'─'*12} {'─'*10}")
        for s in r.snapshots:
            reinv = "✓ REINVESTIU" if s.reinvestiu else ""
            print(f"  {s.dia:<5} ${s.capital_operando:<13,.2f} ${s.caixa_retido:<11,.2f} "
                  f"${s.patrimonio_total:<13,.2f} ${s.lucro_dia:<11,.4f} {reinv}")


# ── Cenários de comparação ────────────────────────────────────────────────────

def comparar_cenarios() -> None:
    """
    Compara 4 cenários reais com diferentes capitais e configurações.
    """
    cenarios = [
        dict(capital_inicial=300,   num_grids=25, margem_pct=0.25, ciclos_dia=6,  dias=365, label="Conservador $300  · 0,25% · 6 ciclos"),
        dict(capital_inicial=300,   num_grids=25, margem_pct=0.38, ciclos_dia=8,  dias=365, label="Otimista    $300  · 0,38% · 8 ciclos"),
        dict(capital_inicial=1000,  num_grids=25, margem_pct=0.28, ciclos_dia=6,  dias=365, label="Médio      $1.000 · 0,28% · 6 ciclos"),
        dict(capital_inicial=5000,  num_grids=30, margem_pct=0.35, ciclos_dia=8,  dias=365, label="Avançado   $5.000 · 0,35% · 8 ciclos"),
    ]

    print(f"\n{'═'*72}")
    print(f"  COMPARATIVO DE CENÁRIOS — 365 dias")
    print(f"{'═'*72}")
    print(f"  {'Cenário':<42} {'Lucro':>10} {'Rentab.':>10} {'Reinvest.':>10}")
    print(f"  {'─'*42} {'─'*10} {'─'*10} {'─'*10}")

    for c in cenarios:
        label = c.pop("label")
        r = simular_grid_spot(**c)
        res = r.resumo
        print(f"  {label:<42} ${res['lucro_total']:>9,.2f} {res['rentabilidade_pct']:>9.2f}% {res['reinvestimentos']:>10}x")

    print(f"{'═'*72}\n")


# ── Execução ──────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    # Cenário padrão do simulador do app
    r = simular_grid_spot(
        capital_inicial = 300.0,
        margem_pct      = 0.25,
        num_grids       = 25,
        ciclos_dia      = 6,
        dias            = 365,
    )
    imprimir_relatorio(r, mostrar_dias=False)

    # Comparativo de cenários
    comparar_cenarios()

    # Mostrar os primeiros 30 dias com detalhe
    r30 = simular_grid_spot(
        capital_inicial = 300.0,
        margem_pct      = 0.25,
        num_grids       = 25,
        ciclos_dia      = 6,
        dias            = 30,
    )
    imprimir_relatorio(r30, mostrar_dias=True)
