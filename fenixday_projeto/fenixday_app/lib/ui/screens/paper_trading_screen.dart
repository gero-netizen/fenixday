/// FênixDay — Paper Trading v2
/// Simulação com preços reais, SQLite local, gráfico de evolução

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;

import 'package:go_router/go_router.dart';
import '../theme/fenix_theme.dart';
import 'services/paper_trading_db.dart';
import 'services/paper_trading_service.dart';

const _kPaperColor  = Color(0xFF8957E5);
const _kPaperBg     = Color(0x1A8957E5);
const _kPaperBorder = Color(0x4D8957E5);

// ── Provider de preço atual ───────────────────────────────────────────────────

final _priceProvider = FutureProvider.family<double?, String>((ref, symbolExchange) async {
  final parts    = symbolExchange.split('|');
  final symbol   = parts[0];
  final exchange = parts[1];
  final service  = ref.watch(paperServiceProvider);
  return service.fetchPrice(symbol, exchange);
});

// ── Tela principal ────────────────────────────────────────────────────────────

class PaperTradingScreen extends ConsumerStatefulWidget {
  const PaperTradingScreen({super.key});

  @override
  ConsumerState<PaperTradingScreen> createState() => _PaperTradingScreenState();
}

class _PaperTradingScreenState extends ConsumerState<PaperTradingScreen> {
  @override
  void initState() {
    super.initState();
    // Inicia simulação para robôs ativos
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSimulations());
  }

  void _startSimulations() async {
    final db      = ref.read(paperDbProvider);
    final service = ref.read(paperServiceProvider);
    final robots  = await db.getAllRobots();
    for (final r in robots) {
      if (r.status == 'running') service.startSimulation(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final robotsAsync = ref.watch(paperRobotsProvider);
    final statsAsync  = ref.watch(paperStatsProvider);

    return Scaffold(
      backgroundColor: FenixColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _PaperHeader(onAdd: () => _showAddRobotDialog(context))),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: _PaperBanner(),
            )),

            // Stats
            SliverToBoxAdapter(child: statsAsync.when(
              loading: () => const SizedBox(height: 80,
                  child: Center(child: CircularProgressIndicator(color: _kPaperColor))),
              error:   (e, _) => const SizedBox.shrink(),
              data:    (stats) => Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: _StatsRow(stats: stats),
              ),
            )),

            // Gráfico
            SliverToBoxAdapter(child: statsAsync.when(
              loading: () => const SizedBox.shrink(),
              error:   (e, _) => const SizedBox.shrink(),
              data:    (stats) => stats.equityCurve.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: _PaperChart(stats: stats),
                    )
                  : const SizedBox.shrink(),
            )),

            // Robôs
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: robotsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: _kPaperColor)),
                error:   (e, _) => Text('Erro: $e', style: const TextStyle(color: FenixColors.red)),
                data:    (robots) => robots.isEmpty
                    ? _EmptyState(onAdd: () => _showAddRobotDialog(context))
                    : _RobotsSection(robots: robots),
              ),
            )),

            // Comparativo
            SliverToBoxAdapter(child: statsAsync.when(
              loading: () => const SizedBox.shrink(),
              error:   (e, _) => const SizedBox.shrink(),
              data:    (stats) => stats.totalProfit > 0
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                      child: _ComparisonCard(stats: stats),
                    )
                  : const SizedBox(height: 24),
            )),
          ],
        ),
      ),
    );
  }

  void _showAddRobotDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FenixColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _AddRobotSheet(onCreated: () {
        ref.invalidate(paperRobotsProvider);
        ref.invalidate(paperStatsProvider);
        _startSimulations();
      }),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _PaperHeader extends StatelessWidget {
  final VoidCallback onAdd;
  const _PaperHeader({required this.onAdd});

  @override
  Widget build(BuildContext context) => Container(
    color: FenixColors.surface,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.maybePop(context),
        child: const Icon(Icons.arrow_back, size: 18, color: FenixColors.textMuted),
      ),
      const SizedBox(width: 12),
      const Text('Paper Trading', style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w500, color: FenixColors.textPrimary)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _kPaperBg, borderRadius: BorderRadius.circular(5),
          border: Border.all(color: _kPaperBorder, width: 0.5),
        ),
        child: const Text('PAPER', style: TextStyle(
            fontFamily: 'RobotoMono', fontSize: 10,
            fontWeight: FontWeight.w700, color: _kPaperColor)),
      ),
      const Spacer(),
      GestureDetector(
        onTap: onAdd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _kPaperBg, borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kPaperBorder, width: 0.5),
          ),
          child: const Row(children: [
            Icon(Icons.add, size: 13, color: _kPaperColor),
            SizedBox(width: 4),
            Text('Novo robô', style: TextStyle(
                fontSize: 11, color: _kPaperColor, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    ]),
  );
}

// ── Banner ────────────────────────────────────────────────────────────────────

class _PaperBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _kPaperBg, borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _kPaperBorder, width: 0.5),
    ),
    child: const Row(children: [
      Icon(Icons.science_outlined, size: 18, color: _kPaperColor),
      SizedBox(width: 10),
      Expanded(child: Text(
        'Preços reais da exchange, sem executar ordens. '
        'Ideal para testar estratégias antes de usar capital real.',
        style: TextStyle(fontSize: 11, color: _kPaperColor, height: 1.4),
      )),
    ]),
  );
}

// ── Stats ─────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final PaperStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: [
        _StatCard('Lucro simulado total',
            '+\$${fmt.format(stats.totalProfit)}',
            stats.totalCapital > 0
                ? '+${(stats.totalProfit / stats.totalCapital * 100).toStringAsFixed(2)}%'
                : '0%',
            _kPaperColor),
        _StatCard('Capital em simulação',
            '\$${fmt.format(stats.totalCapital + stats.totalProfit)}',
            'iniciou \$${fmt.format(stats.totalCapital)}',
            FenixColors.textPrimary),
        _StatCard('Ciclos simulados',
            '${stats.totalCycles}', 'todos os robôs', _kPaperColor),
        _StatCard('Dias simulados',
            '${stats.equityCurve.length}', 'com dados reais', _kPaperColor),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  const _StatCard(this.label, this.value, this.sub, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: FenixColors.card, borderRadius: BorderRadius.circular(8),
      border: Border(top: BorderSide(color: color, width: 2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: FenixColors.textMuted)),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(fontFamily: 'RobotoMono',
          fontSize: 15, fontWeight: FontWeight.w500, color: color)),
      Text(sub, style: const TextStyle(fontSize: 9, color: FenixColors.textMuted)),
    ]),
  );
}

// ── Gráfico ───────────────────────────────────────────────────────────────────

class _PaperChart extends StatelessWidget {
  final PaperStats stats;
  const _PaperChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final spots = stats.equityCurve.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();
    if (spots.isEmpty) return const SizedBox.shrink();
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) * 0.998;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.002;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FenixColors.card, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FenixColors.border, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Evolução do capital simulado', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w500, color: FenixColors.textMuted)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: _kPaperBg, borderRadius: BorderRadius.circular(4)),
            child: const Text('SIMULADO', style: TextStyle(
                fontSize: 8, color: _kPaperColor, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 12),
        SizedBox(height: 130, child: LineChart(LineChartData(
          minY: minY, maxY: maxY,
          gridData: FlGridData(
            show: true, drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 4,
            getDrawingHorizontalLine: (_) => FlLine(
                color: FenixColors.border.withOpacity(0.5), strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 52,
              getTitlesWidget: (v, _) => Text('\$${NumberFormat('#,##0').format(v)}',
                  style: const TextStyle(fontFamily: 'RobotoMono',
                      fontSize: 9, color: FenixColors.textMuted)),
            )),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, interval: 1,
              getTitlesWidget: (v, _) => Text('D${v.toInt() + 1}',
                  style: const TextStyle(fontFamily: 'RobotoMono',
                      fontSize: 9, color: FenixColors.textMuted)),
            )),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots, isCurved: true, curveSmoothness: 0.3,
              color: _kPaperColor, barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: _kPaperBg),
            ),
            LineChartBarData(
              spots: spots.map((s) => FlSpot(s.x, stats.totalCapital)).toList(),
              isCurved: false,
              color: FenixColors.textMuted.withOpacity(0.4),
              barWidth: 1,
              dotData: const FlDotData(show: false),
              dashArray: [4, 4],
            ),
          ],
        ))),
      ]),
    );
  }
}

// ── Lista de robôs ────────────────────────────────────────────────────────────

class _RobotsSection extends ConsumerWidget {
  final List<PaperRobot> robots;
  const _RobotsSection({required this.robots});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text('Robôs em simulação', style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w500,
            color: FenixColors.textMuted, letterSpacing: .4)),
      ),
      ...robots.map((r) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _RobotCard(robot: r),
      )),
    ],
  );
}

class _RobotCard extends ConsumerWidget {
  final PaperRobot robot;
  const _RobotCard({required this.robot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt      = NumberFormat('#,##0.00');
    final priceKey = '${robot.symbol}|${robot.exchange}';
    final priceAsync = ref.watch(_priceProvider(priceKey));
    final cyclesAsync = ref.watch(paperCyclesProvider(robot.id));

    final profit = cyclesAsync.valueOrNull?.fold(0.0, (s, c) => s + c.profit) ?? 0.0;
    final cycles = cyclesAsync.valueOrNull?.length ?? 0;
    final isRunning = robot.status == 'running';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FenixColors.card, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kPaperBorder, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(robot.symbol, style: const TextStyle(
              fontFamily: 'RobotoMono', fontSize: 13,
              fontWeight: FontWeight.w500, color: FenixColors.textPrimary)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: _kPaperBg, borderRadius: BorderRadius.circular(3)),
            child: const Text('PAPER', style: TextStyle(
                fontSize: 8, color: _kPaperColor, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          // Preço atual
          priceAsync.when(
            loading: () => const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: _kPaperColor)),
            error:   (_, __) => const SizedBox.shrink(),
            data:    (price) => price != null
                ? Text('\$${fmt.format(price)}', style: const TextStyle(
                    fontFamily: 'RobotoMono', fontSize: 11, color: FenixColors.textMuted))
                : const SizedBox.shrink(),
          ),
          const Spacer(),
          // Status + toggle
          GestureDetector(
            onTap: () async {
              final db      = ref.read(paperDbProvider);
              final service = ref.read(paperServiceProvider);
              final newStatus = isRunning ? 'paused' : 'running';
              await db.updateRobotStatus(robot.id, newStatus);
              if (newStatus == 'running') {
                service.startSimulation(robot);
              } else {
                service.stopSimulation(robot.id);
              }
              ref.invalidate(paperRobotsProvider);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isRunning ? FenixColors.greenBg : FenixColors.yellowBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isRunning ? '● simulando' : '⏸ pausado',
                style: TextStyle(
                    fontSize: 9,
                    color: isRunning ? FenixColors.green : FenixColors.yellow),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Menu
          PopupMenuButton<String>(
            color: FenixColors.card,
            icon: const Icon(Icons.more_vert, size: 16, color: FenixColors.textMuted),
            onSelected: (v) async {
              if (v == 'copy_real') {
              if (context.mounted) {
                context.push('/grids/config');
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Parâmetros copiados! Configure e inicie o grid real.'),
                  backgroundColor: FenixColors.green,
                  duration: Duration(seconds: 3),
                ));
              }
              return;
            }
            if (v == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: FenixColors.card,
                    title: const Text('Excluir robô paper?',
                        style: TextStyle(fontSize: 14, color: FenixColors.textPrimary)),
                    content: Text('Isso apagará ${robot.symbol} e todos os ciclos simulados.',
                        style: const TextStyle(fontSize: 12, color: FenixColors.textMuted)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: FenixColors.red),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Excluir', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(paperServiceProvider).stopSimulation(robot.id);
                  await ref.read(paperDbProvider).deleteRobot(robot.id);
                  ref.invalidate(paperRobotsProvider);
                  ref.invalidate(paperStatsProvider);
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'copy_real',
                  child: Text('Copiar para operação real', style: TextStyle(color: FenixColors.green, fontSize: 12))),
              const PopupMenuItem(value: 'delete',
                  child: Text('Excluir robô', style: TextStyle(color: FenixColors.red, fontSize: 12))),
            ],
          ),
        ]),

        const SizedBox(height: 6),
        Text(
          '${robot.exchange} · ${robot.numGrids} grades · '
          '\$${fmt.format(robot.lowerBound)} – \$${fmt.format(robot.upperBound)}',
          style: const TextStyle(fontSize: 10, color: FenixColors.textMuted),
        ),
        const SizedBox(height: 10),

        Row(children: [
          _Mini('Capital', '\$${fmt.format(robot.capital)}'),
          _Mini('Lucro', '+\$${fmt.format(profit)}', color: _kPaperColor),
          _Mini('Ciclos', '$cycles', color: _kPaperColor),
          _Mini('Rentab.', robot.capital > 0
              ? '+${(profit / robot.capital * 100).toStringAsFixed(2)}%'
              : '0%', color: _kPaperColor),
        ]),
      ]),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Mini(this.label, this.value, {this.color = FenixColors.textSecondary});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 9, color: FenixColors.textMuted)),
      Text(value, style: TextStyle(fontFamily: 'RobotoMono',
          fontSize: 11, fontWeight: FontWeight.w500, color: color)),
    ],
  ));
}

// ── Estado vazio ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [
        const Icon(Icons.science_outlined, size: 48, color: _kPaperColor),
        const SizedBox(height: 12),
        const Text('Nenhum robô paper ativo',
            style: TextStyle(fontSize: 14, color: FenixColors.textMuted)),
        const SizedBox(height: 6),
        const Text('Crie um robô para simular estratégias com preços reais',
            style: TextStyle(fontSize: 11, color: FenixColors.textMuted),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPaperColor, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Criar primeiro robô paper'),
          onPressed: onAdd,
        ),
      ]),
    ),
  );
}

// ── Sheet criar robô ──────────────────────────────────────────────────────────

class _AddRobotSheet extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _AddRobotSheet({required this.onCreated});

  @override
  ConsumerState<_AddRobotSheet> createState() => _AddRobotSheetState();
}

class _AddRobotSheetState extends ConsumerState<_AddRobotSheet> {
  final _symbolCtrl  = TextEditingController(text: 'BTC/USDT');
  final _capitalCtrl = TextEditingController(text: '1000');
  final _upperCtrl   = TextEditingController();
  final _lowerCtrl   = TextEditingController();
  final _gridsCtrl   = TextEditingController(text: '20');
  String _exchange   = 'Binance';
  bool _loading      = false;
  double? _currentPrice;

  static const _popularPairs = [
    'BTC/USDT', 'ETH/USDT', 'BNB/USDT', 'SOL/USDT', 'XRP/USDT',
    'ADA/USDT', 'DOGE/USDT', 'AVAX/USDT', 'DOT/USDT', 'LINK/USDT',
    'MATIC/USDT', 'LTC/USDT', 'UNI/USDT', 'ATOM/USDT', 'TRX/USDT',
  ];

  @override
  void initState() {
    super.initState();
    _fetchPrice();
  }

  @override
  void dispose() {
    _symbolCtrl.dispose(); _capitalCtrl.dispose();
    _upperCtrl.dispose();  _lowerCtrl.dispose(); _gridsCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPrice() async {
    final service = ref.read(paperServiceProvider);
    final price   = await service.fetchPrice(_symbolCtrl.text, _exchange);
    if (price != null && mounted) {
      setState(() {
        _currentPrice = price;
        _upperCtrl.text = (price * 1.1).toStringAsFixed(2);
        _lowerCtrl.text = (price * 0.9).toStringAsFixed(2);
      });
    }
  }

  Future<void> _create() async {
    final symbol  = _symbolCtrl.text.trim().toUpperCase();
    final capital = double.tryParse(_capitalCtrl.text) ?? 0;
    final upper   = double.tryParse(_upperCtrl.text)   ?? 0;
    final lower   = double.tryParse(_lowerCtrl.text)   ?? 0;
    final grids   = int.tryParse(_gridsCtrl.text)      ?? 20;

    if (symbol.isEmpty || capital <= 0 || upper <= lower || grids < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Verifique os parâmetros.'),
        backgroundColor: FenixColors.red,
      ));
      return;
    }

    setState(() => _loading = true);
    final db = ref.read(paperDbProvider);
    await db.insertRobot(PaperRobotsCompanion(
      symbol:     Value(symbol),
      exchange:   Value(_exchange),
      upperBound: Value(upper),
      lowerBound: Value(lower),
      numGrids:   Value(grids),
      capital:    Value(capital),
      status:     const Value('running'),
    ));

    if (mounted) {
      Navigator.pop(context);
      widget.onCreated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16,
          MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Novo robô paper', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: FenixColors.textPrimary)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: FenixColors.textMuted),
            onPressed: () => Navigator.pop(context),
          ),
        ]),

        if (_currentPrice != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _kPaperBg, borderRadius: BorderRadius.circular(6)),
            child: Row(children: [
              const Icon(Icons.show_chart, size: 14, color: _kPaperColor),
              const SizedBox(width: 8),
              Text('Preço atual: \$${fmt.format(_currentPrice!)}',
                  style: const TextStyle(fontSize: 12, color: _kPaperColor)),
            ]),
          ),
        ],

        // Exchange
        Row(children: [
          const Text('Exchange', style: TextStyle(fontSize: 11, color: FenixColors.textMuted)),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _exchange,
            dropdownColor: FenixColors.card,
            style: const TextStyle(fontSize: 13, color: FenixColors.textPrimary),
            underline: const SizedBox.shrink(),
            items: ['Binance', 'Bybit'].map((e) =>
                DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) {
              setState(() => _exchange = v!);
              _fetchPrice();
            },
          ),
        ]),

        // Pares populares
        const Text('Pares populares',
            style: TextStyle(fontSize: 11, color: FenixColors.textMuted)),
        const SizedBox(height: 6),
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _popularPairs.map((pair) {
              final selected = _symbolCtrl.text == pair;
              return GestureDetector(
                onTap: () {
                  setState(() => _symbolCtrl.text = pair);
                  _fetchPrice();
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? _kPaperBg : FenixColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? _kPaperColor : FenixColors.border,
                      width: selected ? 1 : 0.5,
                    ),
                  ),
                  child: Text(pair.replaceAll('/USDT', ''),
                      style: TextStyle(
                          fontSize: 11,
                          color: selected ? _kPaperColor : FenixColors.textMuted,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),

        // Par (campo manual)
        TextField(
          controller: _symbolCtrl,
          style: const TextStyle(fontSize: 13, color: FenixColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Par (ex: BTC/USDT)',
            labelStyle: TextStyle(color: FenixColors.textMuted),
          ),
          onSubmitted: (_) => _fetchPrice(),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 8),

        // Capital
        TextField(
          controller: _capitalCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 13, color: FenixColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Capital simulado (USDT)',
            labelStyle: TextStyle(color: FenixColors.textMuted),
          ),
        ),
        const SizedBox(height: 8),

        // Limites
        Row(children: [
          Expanded(child: TextField(
            controller: _upperCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13, color: FenixColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Limite superior',
              labelStyle: TextStyle(color: FenixColors.textMuted),
            ),
          )),
          const SizedBox(width: 12),
          Expanded(child: TextField(
            controller: _lowerCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13, color: FenixColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Limite inferior',
              labelStyle: TextStyle(color: FenixColors.textMuted),
            ),
          )),
        ]),
        const SizedBox(height: 8),

        // Grades
        TextField(
          controller: _gridsCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 13, color: FenixColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Número de grades',
            labelStyle: TextStyle(color: FenixColors.textMuted),
          ),
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPaperColor, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            icon: _loading
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                : const Icon(Icons.rocket_launch_outlined, size: 16),
            label: Text(_loading ? 'Criando...' : 'Iniciar simulação'),
            onPressed: _loading ? null : _create,
          ),
        ),
      ]),
    );
  }
}

// ── Card comparativo ──────────────────────────────────────────────────────────

class _ComparisonCard extends StatelessWidget {
  final PaperStats stats;
  const _ComparisonCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FenixColors.card, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FenixColors.border, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('E se fosse capital real?', style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, color: FenixColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('Comparação entre simulação e resultado real estimado',
            style: TextStyle(fontSize: 10, color: FenixColors.textMuted)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kPaperBg, borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _kPaperBorder, width: 0.5),
            ),
            child: Column(children: [
              const Text('Paper (simulado)',
                  style: TextStyle(fontSize: 10, color: _kPaperColor)),
              const SizedBox(height: 6),
              Text('+\$${fmt.format(stats.totalProfit)}',
                  style: const TextStyle(fontFamily: 'RobotoMono',
                      fontSize: 16, fontWeight: FontWeight.w500, color: _kPaperColor)),
              Text('+${stats.totalCapital > 0 ? (stats.totalProfit / stats.totalCapital * 100).toStringAsFixed(2) : "0"}%',
                  style: const TextStyle(fontSize: 10, color: _kPaperColor)),
            ]),
          )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(children: const [
              Icon(Icons.compare_arrows, size: 20, color: FenixColors.textMuted),
              Text('vs', style: TextStyle(fontSize: 9, color: FenixColors.textMuted)),
            ]),
          ),
          Expanded(child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FenixColors.greenBg, borderRadius: BorderRadius.circular(6),
              border: Border.all(color: FenixColors.green.withOpacity(0.3), width: 0.5),
            ),
            child: Column(children: [
              const Text('Real (estimado)',
                  style: TextStyle(fontSize: 10, color: FenixColors.green)),
              const SizedBox(height: 6),
              Text('+\$${fmt.format(stats.totalProfit * 0.97)}',
                  style: const TextStyle(fontFamily: 'RobotoMono',
                      fontSize: 16, fontWeight: FontWeight.w500, color: FenixColors.green)),
              const Text('após taxas reais',
                  style: TextStyle(fontSize: 9, color: FenixColors.textMuted)),
            ]),
          )),
        ]),
      ]),
    );
  }
}
