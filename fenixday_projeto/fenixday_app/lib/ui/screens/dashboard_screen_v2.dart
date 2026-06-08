/// FênixDay — Dashboard P&L v2
///
/// Novas métricas adicionadas:
///   1. Lucro de grid — exclusivamente de ciclos fechados (compra+venda)
///   2. Valor acumulado por período — hoje/semana/mês/total em USDT e %
///   3. Valor geral do portfólio — capital alocado + lucro de grid acumulado
///   4. P&L de desvalorização — variação de preço das posições de compra abertas
///      (sem incluir lucro de grid — apenas marcação a mercado)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../theme/fenix_theme.dart';

// ── Modelos ───────────────────────────────────────────────────────────────────

class _PortfolioData {
  // Capital
  final double capitalAlocado;       // capital colocado nos grids
  final double lucroGridAcumulado;   // soma de todos os ciclos fechados
  final double patrimonioTotal;      // capital + lucro grid

  // Lucro de grid por período
  final double lucroGridHoje;
  final double lucroGridSemana;
  final double lucroGridMes;
  final int    ciclosHoje;
  final int    ciclosSemana;
  final int    ciclosMes;
  final int    ciclosTotal;

  // Desvalorização (P&L não realizado das posições abertas)
  final double plDesvalorizacao;     // negativo = perda, positivo = ganho
  final double plDesvalorizacaoPct;

  // Curva de evolução (juros compostos dos grids)
  final List<FlSpot> curvaGrid;
  final List<FlSpot> curvaDesvalorizacao;

  // Ordens recentes
  final List<_OrdemRecente> ordensRecentes;

  const _PortfolioData({
    required this.capitalAlocado,
    required this.lucroGridAcumulado,
    required this.patrimonioTotal,
    required this.lucroGridHoje,
    required this.lucroGridSemana,
    required this.lucroGridMes,
    required this.ciclosHoje,
    required this.ciclosSemana,
    required this.ciclosMes,
    required this.ciclosTotal,
    required this.plDesvalorizacao,
    required this.plDesvalorizacaoPct,
    required this.curvaGrid,
    required this.curvaDesvalorizacao,
    required this.ordensRecentes,
  });

  double get lucroGridHojePct   => capitalAlocado > 0 ? lucroGridHoje   / capitalAlocado * 100 : 0;
  double get lucroGridSemanaPct => capitalAlocado > 0 ? lucroGridSemana / capitalAlocado * 100 : 0;
  double get lucroGridMesPct    => capitalAlocado > 0 ? lucroGridMes    / capitalAlocado * 100 : 0;
  double get lucroGridTotalPct  => capitalAlocado > 0 ? lucroGridAcumulado / capitalAlocado * 100 : 0;
}

class _OrdemRecente {
  final String symbol;
  final String side;       // 'venda' | 'compra'
  final double price;
  final double profitPct;
  final double profitUsdt;
  final String time;

  const _OrdemRecente({
    required this.symbol,
    required this.side,
    required this.price,
    required this.profitPct,
    required this.profitUsdt,
    required this.time,
  });
}

// ── Provider (mock) ───────────────────────────────────────────────────────────

final _portfolioProvider = Provider<_PortfolioData>((ref) {
  // Curva de lucro de grid (crescimento por ciclos fechados)
  double capital = 3784.50;
  final curvaGrid = List.generate(31, (i) {
    final v = capital;
    capital *= 1.0035;
    return FlSpot(i.toDouble(), v);
  });

  // Curva de desvalorização (oscilação do preço das posições abertas)
  double desval = 0;
  final curvaDesval = List.generate(31, (i) {
    desval += (i % 3 == 0 ? -12 : i % 2 == 0 ? 8 : -5);
    return FlSpot(i.toDouble(), desval);
  });

  return _PortfolioData(
    capitalAlocado:      3784.50,
    lucroGridAcumulado:    342.18,
    patrimonioTotal:     4126.68,
    lucroGridHoje:          14.38,
    lucroGridSemana:        89.20,
    lucroGridMes:          342.18,
    ciclosHoje:    12,
    ciclosSemana:  76,
    ciclosMes:    312,
    ciclosTotal:  1284,
    plDesvalorizacao:      -87.42,
    plDesvalorizacaoPct:    -2.31,
    curvaGrid:      curvaGrid,
    curvaDesvalorizacao: curvaDesval,
    ordensRecentes: const [
      _OrdemRecente(symbol:'ETH/USDT', side:'venda',  price:1997.40, profitPct:.41, profitUsdt:1.03, time:'14:32:01'),
      _OrdemRecente(symbol:'SOL/USDT', side:'venda',  price:158.20,  profitPct:.39, profitUsdt:.97,  time:'14:18:44'),
      _OrdemRecente(symbol:'BNB/USDT', side:'venda',  price:614.80,  profitPct:.43, profitUsdt:1.07, time:'13:55:22'),
      _OrdemRecente(symbol:'MATIC/USDT',side:'venda', price:.793,    profitPct:.38, profitUsdt:.95,  time:'13:41:09'),
      _OrdemRecente(symbol:'ETH/USDT', side:'compra', price:1988.40, profitPct:0,   profitUsdt:0,    time:'13:29:55'),
    ],
  );
});

// ── Tela ──────────────────────────────────────────────────────────────────────

class DashboardScreenV2 extends ConsumerWidget {
  const DashboardScreenV2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_portfolioProvider);
    final fmt  = NumberFormat('#,##0.00', 'pt_BR');

    return Scaffold(
      backgroundColor: FenixColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Cabeçalho ─────────────────────────────────────────────
              Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Performance & P&L',
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: FenixColors.textPrimary)),
                      SizedBox(height: 2),
                      Text('27/05/2026 · 14:35:08',
                          style: TextStyle(fontFamily: 'RobotoMono',
                              fontSize: 10, color: FenixColors.textMuted)),
                    ],
                  ),
                  const Spacer(),
                  // Badge modo
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: FenixColors.greenBg,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                          color: FenixColors.green.withOpacity(.3),
                          width: .5),
                    ),
                    child: const Row(children: [
                      Icon(Icons.circle, size: 7, color: FenixColors.green),
                      SizedBox(width: 5),
                      Text('MODO REAL',
                          style: TextStyle(fontFamily: 'RobotoMono',
                              fontSize: 9, fontWeight: FontWeight.w700,
                              color: FenixColors.green)),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── 1. PATRIMÔNIO TOTAL ────────────────────────────────────
              _SectionTitle('Patrimônio total em operação'),
              const SizedBox(height: 6),
              _PatrimonioCard(data: data),
              const SizedBox(height: 14),

              // ── 2. LUCRO DE GRID ──────────────────────────────────────
              _SectionTitle('Lucro de grid — ciclos fechados'),
              const SizedBox(height: 6),
              _LucroGridSection(data: data),
              const SizedBox(height: 14),

              // ── 3. CURVA DE EVOLUÇÃO ──────────────────────────────────
              _SectionTitle('Evolução do lucro de grid — juros compostos'),
              const SizedBox(height: 6),
              _CurvaGridCard(data: data),
              const SizedBox(height: 14),

              // ── 4. DESVALORIZAÇÃO ─────────────────────────────────────
              _SectionTitle('P&L de desvalorização — posições abertas'),
              const SizedBox(height: 6),
              _DesvalorizacaoCard(data: data),
              const SizedBox(height: 14),

              // ── 5. ORDENS RECENTES ────────────────────────────────────
              _SectionTitle('Ordens recentes'),
              const SizedBox(height: 6),
              _OrdensCard(data: data),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 1. Patrimônio total ───────────────────────────────────────────────────────

class _PatrimonioCard extends StatelessWidget {
  final _PortfolioData data;
  const _PatrimonioCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'pt_BR');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(topColor: FenixColors.yellow),
      child: Column(
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Patrimônio total',
                      style: TextStyle(fontSize: 10, color: FenixColors.textMuted)),
                  const SizedBox(height: 3),
                  Text('\$${fmt.format(data.patrimonioTotal)}',
                      style: const TextStyle(
                          fontFamily: 'RobotoMono', fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: FenixColors.yellow)),
                ],
              ),
            ),
            const Icon(Icons.account_balance_wallet_outlined,
                size: 28, color: FenixColors.yellow),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: .5, color: FenixColors.border),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _PatrimonioItem(
                label: 'Capital alocado',
                value: '\$${fmt.format(data.capitalAlocado)}',
                icon: Icons.input_rounded,
                color: FenixColors.textSecondary,
                sub: 'investimento inicial',
              ),
            ),
            Container(width: .5, height: 40, color: FenixColors.border),
            Expanded(
              child: _PatrimonioItem(
                label: 'Lucro de grid',
                value: '+\$${fmt.format(data.lucroGridAcumulado)}',
                icon: Icons.trending_up,
                color: FenixColors.green,
                sub: '+${data.lucroGridTotalPct.toStringAsFixed(2)}%',
              ),
            ),
            Container(width: .5, height: 40, color: FenixColors.border),
            Expanded(
              child: _PatrimonioItem(
                label: 'P&L desvalorização',
                value: '${data.plDesvalorizacao < 0 ? '' : '+'}\$${fmt.format(data.plDesvalorizacao)}',
                icon: data.plDesvalorizacao < 0
                    ? Icons.trending_down
                    : Icons.trending_up,
                color: data.plDesvalorizacao < 0
                    ? FenixColors.red
                    : FenixColors.green,
                sub: '${data.plDesvalorizacaoPct.toStringAsFixed(2)}%',
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _PatrimonioItem extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  const _PatrimonioItem({
    required this.label, required this.value, required this.sub,
    required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 9, color: FenixColors.textMuted)),
      ]),
      const SizedBox(height: 3),
      Text(value,
          style: TextStyle(
              fontFamily: 'RobotoMono', fontSize: 13,
              fontWeight: FontWeight.w500, color: color)),
      Text(sub,
          style: const TextStyle(fontSize: 9, color: FenixColors.textMuted)),
    ]),
  );
}

// ── 2. Lucro de grid por período ──────────────────────────────────────────────

class _LucroGridSection extends StatelessWidget {
  final _PortfolioData data;
  const _LucroGridSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'pt_BR');
    return Column(children: [
      // Cards 4 períodos
      Row(children: [
        Expanded(child: _PeriodoCard(
          label: 'Hoje',
          valor: '+\$${fmt.format(data.lucroGridHoje)}',
          pct:   '+${data.lucroGridHojePct.toStringAsFixed(2)}%',
          ciclos: data.ciclosHoje,
          color: FenixColors.green,
        )),
        const SizedBox(width: 6),
        Expanded(child: _PeriodoCard(
          label: 'Semana',
          valor: '+\$${fmt.format(data.lucroGridSemana)}',
          pct:   '+${data.lucroGridSemanaPct.toStringAsFixed(2)}%',
          ciclos: data.ciclosSemana,
          color: FenixColors.green,
        )),
        const SizedBox(width: 6),
        Expanded(child: _PeriodoCard(
          label: 'Mês',
          valor: '+\$${fmt.format(data.lucroGridMes)}',
          pct:   '+${data.lucroGridMesPct.toStringAsFixed(2)}%',
          ciclos: data.ciclosMes,
          color: FenixColors.green,
        )),
        const SizedBox(width: 6),
        Expanded(child: _PeriodoCard(
          label: 'Total',
          valor: '+\$${fmt.format(data.lucroGridAcumulado)}',
          pct:   '+${data.lucroGridTotalPct.toStringAsFixed(2)}%',
          ciclos: data.ciclosTotal,
          color: FenixColors.yellow,
        )),
      ]),
      const SizedBox(height: 8),

      // Barra de resumo dos ciclos
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: _cardDeco(),
        child: Row(children: [
          const Icon(Icons.loop_outlined, size: 14, color: FenixColors.textMuted),
          const SizedBox(width: 6),
          const Text('Ciclos fechados hoje:',
              style: TextStyle(fontSize: 11, color: FenixColors.textMuted)),
          const SizedBox(width: 6),
          Text('${data.ciclosHoje} ciclos',
              style: const TextStyle(
                  fontFamily: 'RobotoMono', fontSize: 12,
                  fontWeight: FontWeight.w500, color: FenixColors.green)),
          const Spacer(),
          const Text('Média por ciclo:',
              style: TextStyle(fontSize: 11, color: FenixColors.textMuted)),
          const SizedBox(width: 6),
          Text(
            '+\$${(data.lucroGridHoje / (data.ciclosHoje > 0 ? data.ciclosHoje : 1)).toStringAsFixed(3)}',
            style: const TextStyle(
                fontFamily: 'RobotoMono', fontSize: 12,
                fontWeight: FontWeight.w500, color: FenixColors.green),
          ),
        ]),
      ),
    ]);
  }
}

class _PeriodoCard extends StatelessWidget {
  final String label, valor, pct;
  final int ciclos;
  final Color color;
  const _PeriodoCard({
    required this.label, required this.valor, required this.pct,
    required this.ciclos, required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: FenixColors.card,
      borderRadius: BorderRadius.circular(8),
      border: Border(top: BorderSide(color: color, width: 2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 9, color: FenixColors.textMuted)),
      const SizedBox(height: 4),
      Text(valor,
          style: TextStyle(
              fontFamily: 'RobotoMono', fontSize: 14,
              fontWeight: FontWeight.w500, color: color)),
      Text(pct,
          style: TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: color)),
      const SizedBox(height: 4),
      Text('$ciclos ciclos',
          style: const TextStyle(fontSize: 9, color: FenixColors.textMuted)),
    ]),
  );
}

// ── 3. Curva de evolução ──────────────────────────────────────────────────────

class _CurvaGridCard extends StatelessWidget {
  final _PortfolioData data;
  const _CurvaGridCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = data.curvaGrid;
    final minY  = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) * .998;
    final maxY  = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.002;
    final fmt   = NumberFormat('#,##0', 'pt_BR');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(children: [
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Lucro acumulado de grid',
                style: TextStyle(fontSize: 10, color: FenixColors.textMuted)),
            Text(
              '+\$${NumberFormat('#,##0.00', 'pt_BR').format(data.lucroGridAcumulado)}',
              style: const TextStyle(
                  fontFamily: 'RobotoMono', fontSize: 18,
                  fontWeight: FontWeight.w500, color: FenixColors.green),
            ),
          ]),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: FenixColors.greenBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('APENAS GRIDS',
                style: TextStyle(fontFamily: 'RobotoMono',
                    fontSize: 8, color: FenixColors.green,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 140,
          child: LineChart(LineChartData(
            minY: minY, maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (maxY - minY) / 4,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: FenixColors.border.withOpacity(.5), strokeWidth: .5),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 56,
                getTitlesWidget: (v, _) => Text(
                  '\$${fmt.format(v)}',
                  style: const TextStyle(fontFamily: 'RobotoMono',
                      fontSize: 9, color: FenixColors.textMuted),
                ),
              )),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, interval: 5,
                getTitlesWidget: (v, _) => Text('D${v.toInt()}',
                    style: const TextStyle(fontFamily: 'RobotoMono',
                        fontSize: 9, color: FenixColors.textMuted)),
              )),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots, isCurved: true, curveSmoothness: .3,
                color: FenixColors.green, barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                    show: true, color: FenixColors.greenBg),
              ),
            ],
          )),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Capital inicial: \$${NumberFormat('#,##0.00', 'pt_BR').format(data.capitalAlocado)}',
              style: const TextStyle(fontSize: 9, color: FenixColors.textMuted)),
          Text('Patrimônio atual: \$${NumberFormat('#,##0.00', 'pt_BR').format(data.patrimonioTotal)}',
              style: const TextStyle(fontFamily: 'RobotoMono',
                  fontSize: 9, fontWeight: FontWeight.w500,
                  color: FenixColors.green)),
        ]),
      ]),
    );
  }
}

// ── 4. Desvalorização ─────────────────────────────────────────────────────────

class _DesvalorizacaoCard extends StatelessWidget {
  final _PortfolioData data;
  const _DesvalorizacaoCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final fmt      = NumberFormat('#,##0.00', 'pt_BR');
    final isLoss   = data.plDesvalorizacao < 0;
    final color    = isLoss ? FenixColors.red : FenixColors.green;
    final colorBg  = isLoss ? FenixColors.redBg : FenixColors.greenBg;
    final spots    = data.curvaDesvalorizacao;
    final minY     = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 5;
    final maxY     = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 5;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(topColor: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(
                      isLoss ? Icons.arrow_downward : Icons.arrow_upward,
                      size: 14, color: color,
                    ),
                    const SizedBox(width: 5),
                    const Text('P&L de desvalorização',
                        style: TextStyle(fontSize: 11, color: FenixColors.textMuted)),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    '${isLoss ? '' : '+'}\$${fmt.format(data.plDesvalorizacao)}',
                    style: TextStyle(
                        fontFamily: 'RobotoMono', fontSize: 20,
                        fontWeight: FontWeight.w500, color: color),
                  ),
                  Text(
                    '${data.plDesvalorizacaoPct.toStringAsFixed(2)}% sobre posições abertas',
                    style: TextStyle(fontFamily: 'RobotoMono',
                        fontSize: 10, color: color),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorBg,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: color.withOpacity(.3), width: .5),
              ),
              child: Column(children: [
                Text(
                  isLoss ? 'PERDA NÃO\nREALIZADA' : 'GANHO NÃO\nREALIZADO',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'RobotoMono',
                      fontSize: 8, fontWeight: FontWeight.w700, color: color),
                ),
              ]),
            ),
          ]),

          // Aviso explicativo
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FenixColors.card2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: FenixColors.border, width: .5),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 12,
                  color: FenixColors.textMuted),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Este valor reflete a variação de preço das moedas nas posições de compra abertas. '
                  'Não inclui o lucro dos ciclos de grid fechados. '
                  'Será recuperado quando o preço voltar ao patamar de compra.',
                  style: TextStyle(fontSize: 10,
                      color: FenixColors.textMuted, height: 1.4),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // Mini gráfico da desvalorização
          SizedBox(
            height: 80,
            child: LineChart(LineChartData(
              minY: minY, maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY - minY) / 3,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: v == 0
                      ? FenixColors.textMuted.withOpacity(.4)
                      : FenixColors.border.withOpacity(.4),
                  strokeWidth: v == 0 ? 1 : .5,
                  dashArray: v == 0 ? null : [3, 3],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots, isCurved: true, curveSmoothness: .4,
                  color: color, barWidth: 1.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withOpacity(.06),
                    cutOffY: 0,
                    applyCutOffY: true,
                  ),
                  aboveBarData: BarAreaData(
                    show: true,
                    color: FenixColors.green.withOpacity(.06),
                    cutOffY: 0,
                    applyCutOffY: true,
                  ),
                ),
              ],
            )),
          ),
          const SizedBox(height: 6),

          // Breakdown por robô
          const Divider(height: 12, thickness: .5, color: FenixColors.border),
          const Text('Breakdown por robô',
              style: TextStyle(fontSize: 9, color: FenixColors.textMuted,
                  letterSpacing: .4)),
          const SizedBox(height: 8),
          _DesvalRow('ETH/USDT', -32.15, -1.61),
          _DesvalRow('SOL/USDT', -18.40, -2.92),
          _DesvalRow('BNB/USDT',  -8.22, -0.87),
          _DesvalRow('MATIC/USDT', -28.65, -3.02),
        ],
      ),
    );
  }
}

class _DesvalRow extends StatelessWidget {
  final String symbol;
  final double valor, pct;
  const _DesvalRow(this.symbol, this.valor, this.pct);

  @override
  Widget build(BuildContext context) {
    final fmt   = NumberFormat('#,##0.00', 'pt_BR');
    final color = valor < 0 ? FenixColors.red : FenixColors.green;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(symbol,
            style: const TextStyle(fontFamily: 'RobotoMono',
                fontSize: 11, fontWeight: FontWeight.w500,
                color: FenixColors.textSecondary)),
        const Spacer(),
        // Barra proporcional
        SizedBox(
          width: 80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (valor.abs() / 40).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: FenixColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                  color.withOpacity(.6)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: Text(
            '${valor < 0 ? '' : '+'}\$${fmt.format(valor)}',
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'RobotoMono',
                fontSize: 11, fontWeight: FontWeight.w500, color: color),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 42,
          child: Text('${pct.toStringAsFixed(2)}%',
              textAlign: TextAlign.right,
              style: TextStyle(fontFamily: 'RobotoMono',
                  fontSize: 10, color: color)),
        ),
      ]),
    );
  }
}

// ── 5. Ordens recentes ────────────────────────────────────────────────────────

class _OrdensCard extends StatelessWidget {
  final _PortfolioData data;
  const _OrdensCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.0000', 'pt_BR');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(children: [
        for (final o in data.ordensRecentes) ...[
          Row(children: [
            Expanded(
              flex: 2,
              child: Row(children: [
                Text(o.symbol,
                    style: const TextStyle(fontFamily: 'RobotoMono',
                        fontSize: 11, fontWeight: FontWeight.w500,
                        color: FenixColors.textPrimary)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: o.side == 'venda'
                        ? FenixColors.greenBg
                        : FenixColors.blueBg,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(o.side,
                      style: TextStyle(
                          fontSize: 8,
                          color: o.side == 'venda'
                              ? FenixColors.green
                              : FenixColors.blue)),
                ),
              ]),
            ),
            Expanded(
              child: Text('\$${fmt.format(o.price)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'RobotoMono',
                      fontSize: 10, color: FenixColors.textSecondary)),
            ),
            Expanded(
              child: o.side == 'venda'
                  ? Text(
                      '+${o.profitPct.toStringAsFixed(2)}%  +\$${o.profitUsdt.toStringAsFixed(4)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontFamily: 'RobotoMono',
                          fontSize: 10, fontWeight: FontWeight.w500,
                          color: FenixColors.green))
                  : const Text('em aberto',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontFamily: 'RobotoMono',
                          fontSize: 10, color: FenixColors.blue)),
            ),
            const SizedBox(width: 8),
            Text(o.time,
                style: const TextStyle(fontFamily: 'RobotoMono',
                    fontSize: 9, color: FenixColors.textMuted)),
          ]),
          if (o != data.ordensRecentes.last)
            const Divider(height: 12, thickness: .5,
                color: FenixColors.border),
        ],
      ]),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

BoxDecoration _cardDeco({Color? topColor}) => BoxDecoration(
  color: FenixColors.card,
  borderRadius: topColor != null
      ? const BorderRadius.only(
          topLeft: Radius.zero, topRight: Radius.zero,
          bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8))
      : BorderRadius.circular(8),
  border: topColor != null
      ? Border(
          top: BorderSide(color: topColor, width: 2),
          left: BorderSide(color: FenixColors.border, width: .5),
          right: BorderSide(color: FenixColors.border, width: .5),
          bottom: BorderSide(color: FenixColors.border, width: .5),
        )
      : Border.all(color: FenixColors.border, width: .5),
);

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w500,
        color: FenixColors.textMuted, letterSpacing: .3),
  );
}
