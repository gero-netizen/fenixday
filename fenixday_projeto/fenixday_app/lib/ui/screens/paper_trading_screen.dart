/// FênixDay — Paper Trading
///
/// Simulação completa com dados reais de mercado sem executar ordens.
/// Badge roxo "PAPER" para diferenciar de Demo (âmbar) e Real (verde).
///
/// Funcionalidades:
///   • Grid math real calculando lucros e ciclos simulados
///   • P&L simulado registrado no SQLite separado dos dados reais
///   • Relatório comparativo "se tivesse operado com capital real"
///   • Capital inicial configurável pelo cliente
///   • WebSocket Binance para preços reais em tempo real

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../theme/fenix_theme.dart';

// ── Constantes ────────────────────────────────────────────────────────────────

const _kPaperColor  = Color(0xFF8957E5);
const _kPaperBg     = Color(0x1A8957E5);
const _kPaperBorder = Color(0x4D8957E5);

// ── Modelos ───────────────────────────────────────────────────────────────────

class _PaperRobot {
  final int slot;
  final String symbol;
  final String exchange;
  final double upperBound;
  final double lowerBound;
  final int numGrids;
  final double initialCapital;
  final double currentCapital;
  final double paperProfitUsdt;
  final double paperProfitPct;
  final int closedCycles;
  final String status; // 'running' | 'paused'
  final DateTime startedAt;

  const _PaperRobot({
    required this.slot,
    required this.symbol,
    required this.exchange,
    required this.upperBound,
    required this.lowerBound,
    required this.numGrids,
    required this.initialCapital,
    required this.currentCapital,
    required this.paperProfitUsdt,
    required this.paperProfitPct,
    required this.closedCycles,
    required this.status,
    required this.startedAt,
  });
}

class _PaperStats {
  final double totalPaperProfit;
  final double totalPaperProfitPct;
  final int totalCycles;
  final double initialCapital;
  final double currentCapital;
  final List<FlSpot> equityCurve;

  const _PaperStats({
    required this.totalPaperProfit,
    required this.totalPaperProfitPct,
    required this.totalCycles,
    required this.initialCapital,
    required this.currentCapital,
    required this.equityCurve,
  });
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _paperRobotsProvider = Provider<List<_PaperRobot>>((ref) => [
      _PaperRobot(
        slot: 0, symbol: 'ETH/USDT', exchange: 'Binance',
        upperBound: 2180, lowerBound: 1820, numGrids: 20,
        initialCapital: 1000, currentCapital: 1084.20,
        paperProfitUsdt: 84.20, paperProfitPct: 8.42,
        closedCycles: 198, status: 'running',
        startedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      _PaperRobot(
        slot: 1, symbol: 'SOL/USDT', exchange: 'Bybit',
        upperBound: 174, lowerBound: 142, numGrids: 15,
        initialCapital: 500, currentCapital: 536.75,
        paperProfitUsdt: 36.75, paperProfitPct: 7.35,
        closedCycles: 172, status: 'running',
        startedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
    ]);

final _paperStatsProvider = Provider<_PaperStats>((ref) {
  double cap = 1500;
  final spots = List.generate(31, (i) {
    final y = cap;
    cap *= (1 + 0.004 * 6);
    return FlSpot(i.toDouble(), y);
  });

  return _PaperStats(
    totalPaperProfit: 120.95,
    totalPaperProfitPct: 8.06,
    totalCycles: 370,
    initialCapital: 1500,
    currentCapital: 1620.95,
    equityCurve: spots,
  );
});

// ── Tela principal ────────────────────────────────────────────────────────────

class PaperTradingScreen extends ConsumerWidget {
  const PaperTradingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final robots = ref.watch(_paperRobotsProvider);
    final stats  = ref.watch(_paperStatsProvider);

    return Scaffold(
      backgroundColor: FenixColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────
            SliverToBoxAdapter(child: _PaperHeader()),

            // ── Banner explicativo ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _PaperBanner(),
              ),
            ),

            // ── Cards de métricas ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: _StatsRow(stats: stats),
              ),
            ),

            // ── Gráfico de evolução paper ──────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: _PaperChart(stats: stats),
              ),
            ),

            // ── Robôs paper ativos ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: _PaperRobotsSection(robots: robots),
              ),
            ),

            // ── Relatório comparativo ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                child: _ComparisonCard(stats: stats),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _PaperHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: FenixColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: const Icon(Icons.arrow_back,
                size: 18, color: FenixColors.textMuted),
          ),
          const SizedBox(width: 12),
          const Text('Paper Trading',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: FenixColors.textPrimary)),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _kPaperBg,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _kPaperBorder, width: 0.5),
            ),
            child: const Text('PAPER',
                style: TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _kPaperColor)),
          ),
          const Spacer(),
          // Botão novo robô paper
          GestureDetector(
            onTap: () {
              // TODO: abrir GridConfigScreen em modo paper
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kPaperBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _kPaperBorder, width: 0.5),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add, size: 13, color: _kPaperColor),
                  SizedBox(width: 4),
                  Text('Novo robô paper',
                      style: TextStyle(
                          fontSize: 11,
                          color: _kPaperColor,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Banner explicativo ────────────────────────────────────────────────────────

class _PaperBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kPaperBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kPaperBorder, width: 0.5),
      ),
      child: const Row(
        children: [
          Icon(Icons.science_outlined, size: 18, color: _kPaperColor),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Paper Trading usa preços reais da exchange sem executar ordens. '
              'Ideal para testar estratégias antes de usar capital real.',
              style: TextStyle(
                  fontSize: 11, color: _kPaperColor, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cards de métricas ─────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final _PaperStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: [
        _StatCard(
          label: 'Lucro simulado total',
          value: '+\$${stats.totalPaperProfit.toStringAsFixed(2)}',
          sub: '+${stats.totalPaperProfitPct.toStringAsFixed(2)}%',
          color: _kPaperColor,
        ),
        _StatCard(
          label: 'Capital simulado atual',
          value: '\$${NumberFormat('#,##0.00').format(stats.currentCapital)}',
          sub: 'iniciou com \$${NumberFormat('#,##0.00').format(stats.initialCapital)}',
          color: FenixColors.textPrimary,
        ),
        _StatCard(
          label: 'Ciclos simulados',
          value: '${stats.totalCycles}',
          sub: 'todos os robôs',
          color: _kPaperColor,
        ),
        _StatCard(
          label: 'Robôs ativos',
          value: '2',
          sub: 'sem limite',
          color: _kPaperColor,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FenixColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border(top: BorderSide(color: color, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: FenixColors.textMuted)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: color)),
          Text(sub,
              style: const TextStyle(
                  fontSize: 9, color: FenixColors.textMuted)),
        ],
      ),
    );
  }
}

// ── Gráfico paper ─────────────────────────────────────────────────────────────

class _PaperChart extends StatelessWidget {
  final _PaperStats stats;
  const _PaperChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final spots = stats.equityCurve;
    final minY  = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) * 0.998;
    final maxY  = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.002;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FenixColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FenixColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Evolução do capital simulado',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: FenixColors.textMuted)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _kPaperBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('SIMULADO',
                    style: TextStyle(
                        fontSize: 8,
                        color: _kPaperColor,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: LineChart(
              LineChartData(
                minY: minY, maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: FenixColors.border.withOpacity(0.5),
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (v, _) => Text(
                        '\$${NumberFormat('#,##0').format(v)}',
                        style: const TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 9,
                            color: FenixColors.textMuted),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      getTitlesWidget: (v, _) => Text(
                        'D${v.toInt()}',
                        style: const TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 9,
                            color: FenixColors.textMuted),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: _kPaperColor,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _kPaperBg,
                    ),
                  ),
                  // Linha de referência (capital inicial)
                  LineChartBarData(
                    spots: spots
                        .map((s) =>
                            FlSpot(s.x, stats.initialCapital))
                        .toList(),
                    isCurved: false,
                    color: FenixColors.textMuted.withOpacity(0.4),
                    barWidth: 1,
                    dotData: const FlDotData(show: false),
                    dashArray: [4, 4],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Seção de robôs paper ──────────────────────────────────────────────────────

class _PaperRobotsSection extends StatelessWidget {
  final List<_PaperRobot> robots;
  const _PaperRobotsSection({required this.robots});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Robôs em simulação',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: FenixColors.textMuted,
                  letterSpacing: .4)),
        ),
        ...robots.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PaperRobotCard(robot: r),
            )),
      ],
    );
  }
}

class _PaperRobotCard extends StatelessWidget {
  final _PaperRobot robot;
  const _PaperRobotCard({required this.robot});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FenixColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kPaperBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(robot.symbol,
                  style: const TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: FenixColors.textPrimary)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: _kPaperBg,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text('PAPER',
                    style: TextStyle(
                        fontSize: 8,
                        color: _kPaperColor,
                        fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: FenixColors.greenBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('● simulando',
                    style: TextStyle(
                        fontSize: 9, color: FenixColors.green)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Slot ${robot.slot} · ${robot.exchange} · ${robot.numGrids} grades · '
            '${robot.closedCycles} ciclos simulados',
            style: const TextStyle(
                fontSize: 10, color: FenixColors.textMuted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniStat('Capital inicial',
                  '\$${fmt.format(robot.initialCapital)}'),
              _MiniStat('Capital atual',
                  '\$${fmt.format(robot.currentCapital)}',
                  color: _kPaperColor),
              _MiniStat('Lucro simulado',
                  '+\$${fmt.format(robot.paperProfitUsdt)}',
                  color: _kPaperColor),
              _MiniStat('Rentabilidade',
                  '+${robot.paperProfitPct.toStringAsFixed(2)}%',
                  color: _kPaperColor),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(this.label, this.value,
      {this.color = FenixColors.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9, color: FenixColors.textMuted)),
          Text(value,
              style: TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }
}

// ── Card comparativo ──────────────────────────────────────────────────────────

class _ComparisonCard extends StatelessWidget {
  final _PaperStats stats;
  const _ComparisonCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FenixColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FenixColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('E se fosse capital real?',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: FenixColors.textPrimary)),
          const SizedBox(height: 4),
          const Text(
            'Comparação entre a simulação paper e o resultado real equivalente',
            style: TextStyle(fontSize: 10, color: FenixColors.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kPaperBg,
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: _kPaperBorder, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      const Text('Paper (simulado)',
                          style: TextStyle(
                              fontSize: 10, color: _kPaperColor)),
                      const SizedBox(height: 6),
                      Text(
                        '+\$${fmt.format(stats.totalPaperProfit)}',
                        style: const TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _kPaperColor),
                      ),
                      Text(
                        '+${stats.totalPaperProfitPct.toStringAsFixed(2)}%',
                        style: const TextStyle(
                            fontSize: 10, color: _kPaperColor),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: const [
                    Icon(Icons.compare_arrows,
                        size: 20, color: FenixColors.textMuted),
                    Text('vs',
                        style: TextStyle(
                            fontSize: 9,
                            color: FenixColors.textMuted)),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FenixColors.greenBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: FenixColors.green.withOpacity(0.3),
                        width: 0.5),
                  ),
                  child: Column(
                    children: [
                      const Text('Real (estimado)',
                          style: TextStyle(
                              fontSize: 10,
                              color: FenixColors.green)),
                      const SizedBox(height: 6),
                      Text(
                        '+\$${fmt.format(stats.totalPaperProfit * 0.97)}',
                        style: const TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: FenixColors.green),
                      ),
                      const Text(
                        'após taxas reais',
                        style: TextStyle(
                            fontSize: 9,
                            color: FenixColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Botão migrar para real
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: FenixColors.green,
                side: BorderSide(
                    color: FenixColors.green.withOpacity(0.4),
                    width: 0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: const Icon(Icons.rocket_launch_outlined, size: 14),
              label: const Text('Migrar para Modo Real',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500)),
              onPressed: () {
                // TODO: abrir GridConfigScreen em modo real com mesmos params
              },
            ),
          ),
        ],
      ),
    );
  }
}
