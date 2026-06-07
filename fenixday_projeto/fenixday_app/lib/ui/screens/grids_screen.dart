/// FênixDay — Tela de Grids Ativos
///
/// Lista todos os robôs de grid em execução com:
///   • Barra de range visual (inferior ↔ preço atual ↔ superior)
///   • P&L do dia e total por robô
///   • Status: ativo / pausado / reconectando
///   • Ações: pausar / retomar / editar / encerrar
///   • Badge de modo (REAL / DEMO / PAPER)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../theme/fenix_theme.dart';

// ── Modelos ───────────────────────────────────────────────────────────────────

enum GridStatus { active, paused, reconnecting, stopped }

enum GridMode   { real, demo, paper }

class GridRobot {
  final String   id;
  final String   symbol;
  final String   exchange;
  final GridMode mode;
  final GridStatus status;
  final double   capital;
  final double   lowerPrice;
  final double   upperPrice;
  final double   currentPrice;
  final int      numGrids;
  final int      closedCycles;
  final double   profitToday;
  final double   profitTotal;
  final double?  takeProfitPrice;
  final double?  stopLossPrice;
  final bool     trailingUp;

  const GridRobot({
    required this.id,
    required this.symbol,
    required this.exchange,
    required this.mode,
    required this.status,
    required this.capital,
    required this.lowerPrice,
    required this.upperPrice,
    required this.currentPrice,
    required this.numGrids,
    required this.closedCycles,
    required this.profitToday,
    required this.profitTotal,
    this.takeProfitPrice,
    this.stopLossPrice,
    this.trailingUp = false,
  });

  double get priceProgress =>
      ((currentPrice - lowerPrice) / (upperPrice - lowerPrice)).clamp(0.0, 1.0);

  bool get isPriceInRange =>
      currentPrice >= lowerPrice && currentPrice <= upperPrice;
}

// ── Provider (mock — substituir por Drift local) ──────────────────────────────

final _gridRobotsProvider = Provider<List<GridRobot>>((ref) => [
  const GridRobot(
    id: '1', symbol: 'ETH/USDT', exchange: 'Binance',
    mode: GridMode.real, status: GridStatus.active,
    capital: 946.0, lowerPrice: 1820, upperPrice: 2180,
    currentPrice: 1997.40, numGrids: 10, closedCycles: 47,
    profitToday: 3.87, profitTotal: 42.18, trailingUp: true,
  ),
  const GridRobot(
    id: '2', symbol: 'SOL/USDT', exchange: 'Bybit',
    mode: GridMode.real, status: GridStatus.active,
    capital: 938.0, lowerPrice: 142, upperPrice: 174,
    currentPrice: 158.20, numGrids: 8, closedCycles: 39,
    profitToday: 3.21, profitTotal: 28.90,
    stopLossPrice: 140.0,
  ),
  const GridRobot(
    id: '3', symbol: 'MATIC/USDT', exchange: 'OKX',
    mode: GridMode.real, status: GridStatus.reconnecting,
    capital: 947.0, lowerPrice: 0.65, upperPrice: 0.95,
    currentPrice: 0.793, numGrids: 12, closedCycles: 34,
    profitToday: 0.0, profitTotal: 19.42,
  ),
  const GridRobot(
    id: '4', symbol: 'BNB/USDT', exchange: 'Binance',
    mode: GridMode.demo, status: GridStatus.active,
    capital: 500.0, lowerPrice: 580, upperPrice: 660,
    currentPrice: 621.0, numGrids: 15, closedCycles: 22,
    profitToday: 2.10, profitTotal: 14.55,
  ),
]);

final _totalProfitTodayProvider = Provider<double>((ref) {
  return ref.watch(_gridRobotsProvider)
      .fold(0.0, (sum, r) => sum + r.profitToday);
});

// ── Tela ──────────────────────────────────────────────────────────────────────

class GridsScreen extends ConsumerWidget {
  const GridsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final robots      = ref.watch(_gridRobotsProvider);
    final totalToday  = ref.watch(_totalProfitTodayProvider);
    final fmt         = NumberFormat('#,##0.00', 'pt_BR');
    final activeCount = robots.where((r) => r.status == GridStatus.active).length;

    return Scaffold(
      backgroundColor: FenixColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Resumo do dia ──────────────────────────────────────────
            Container(
              color: FenixColors.surface,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Grids ativos',
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: FenixColors.textPrimary)),
                  Text('$activeCount robôs · ${robots.fold(0, (s, r) => s + r.closedCycles)} ciclos hoje',
                      style: const TextStyle(fontSize: 10,
                          color: FenixColors.textMuted)),
                ]),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('Lucro hoje',
                      style: TextStyle(fontSize: 9, color: FenixColors.textMuted)),
                  Text('+\$${fmt.format(totalToday)}',
                      style: const TextStyle(fontFamily: 'RobotoMono',
                          fontSize: 16, fontWeight: FontWeight.w500,
                          color: FenixColors.green)),
                ]),
                const SizedBox(width: 12),
                // Botão novo grid
                GestureDetector(
                  onTap: () => context.go('/grids/config'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: FenixColors.yellowBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: FenixColors.yellow.withOpacity(.4), width: .5),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add, size: 14, color: FenixColors.yellow),
                      SizedBox(width: 4),
                      Text('Novo Grid',
                          style: TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: FenixColors.yellow)),
                    ]),
                  ),
                ),
              ]),
            ),

            // ── Lista de robôs ─────────────────────────────────────────
            Expanded(
              child: robots.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                      itemCount: robots.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) =>
                          _GridCard(robot: robots[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card de robô ──────────────────────────────────────────────────────────────

class _GridCard extends StatelessWidget {
  final GridRobot robot;
  const _GridCard({required this.robot});

  @override
  Widget build(BuildContext context) {
    final fmt      = NumberFormat('#,##0.00###', 'pt_BR');
    final fmtMoney = NumberFormat('#,##0.00', 'pt_BR');
    final (statusColor, statusLabel) = _statusStyle(robot.status);
    final borderColor = robot.status == GridStatus.active
        ? FenixColors.green.withOpacity(.25)
        : robot.status == GridStatus.reconnecting
            ? FenixColors.orange.withOpacity(.25)
            : FenixColors.border;

    return Container(
      decoration: BoxDecoration(
        color: FenixColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: .5),
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(children: [
              // Símbolo + exchange
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(robot.symbol,
                      style: const TextStyle(fontFamily: 'RobotoMono',
                          fontSize: 14, fontWeight: FontWeight.w500,
                          color: FenixColors.textPrimary)),
                  const SizedBox(width: 7),
                  _ModeBadge(mode: robot.mode),
                ]),
                Row(children: [
                  Text(robot.exchange,
                      style: const TextStyle(fontSize: 9,
                          color: FenixColors.textMuted)),
                  const Text(' · ',
                      style: TextStyle(color: FenixColors.textMuted)),
                  Text('Slot ${robot.id} · \$${fmtMoney.format(robot.capital)}',
                      style: const TextStyle(fontSize: 9,
                          color: FenixColors.textMuted)),
                ]),
              ]),
              const Spacer(),

              // Status + ciclos
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                        color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(statusLabel,
                      style: TextStyle(fontSize: 10, color: statusColor)),
                ]),
                Text('${robot.closedCycles} ciclos',
                    style: const TextStyle(fontFamily: 'RobotoMono',
                        fontSize: 10, color: FenixColors.textMuted)),
              ]),
            ]),
          ),

          // ── Barra de range ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(fmt.format(robot.lowerPrice),
                      style: const TextStyle(fontFamily: 'RobotoMono',
                          fontSize: 9, color: FenixColors.green)),
                  Text(fmt.format(robot.currentPrice),
                      style: TextStyle(fontFamily: 'RobotoMono',
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: robot.isPriceInRange
                              ? FenixColors.green
                              : FenixColors.red)),
                  Text(fmt.format(robot.upperPrice),
                      style: const TextStyle(fontFamily: 'RobotoMono',
                          fontSize: 9, color: FenixColors.red)),
                ],
              ),
              const SizedBox(height: 4),
              // Barra visual do range
              LayoutBuilder(
                builder: (ctx, constraints) => Stack(
                  children: [
                    // Fundo
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: FenixColors.greenBg,
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                            color: FenixColors.green.withOpacity(.3),
                            width: .5),
                      ),
                    ),
                    // Marcador do preço atual
                    Positioned(
                      left: (robot.priceProgress *
                              constraints.maxWidth)
                          .clamp(0, constraints.maxWidth - 3),
                      top: 0,
                      child: Container(
                        width: 3, height: 10,
                        decoration: BoxDecoration(
                          color: robot.isPriceInRange
                              ? FenixColors.green
                              : FenixColors.red,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                    // TP/SL markers
                    if (robot.takeProfitPrice != null)
                      Positioned(
                        right: 0, top: -1,
                        child: Container(
                          width: 2, height: 12,
                          color: FenixColors.green,
                        ),
                      ),
                    if (robot.stopLossPrice != null)
                      Positioned(
                        left: 0, top: -1,
                        child: Container(
                          width: 2, height: 12,
                          color: FenixColors.red,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ]),
          ),

          // ── P&L + tags ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Row(children: [
              // P&L hoje
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Hoje',
                    style: TextStyle(fontSize: 9, color: FenixColors.textMuted)),
                Text('+\$${fmtMoney.format(robot.profitToday)}',
                    style: const TextStyle(fontFamily: 'RobotoMono',
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: FenixColors.green)),
              ]),
              const SizedBox(width: 16),
              // P&L total
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total',
                    style: TextStyle(fontSize: 9, color: FenixColors.textMuted)),
                Text('+\$${fmtMoney.format(robot.profitTotal)}',
                    style: const TextStyle(fontFamily: 'RobotoMono',
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: FenixColors.green)),
              ]),
              const Spacer(),
              // Tags
              Wrap(spacing: 4, children: [
                if (robot.trailingUp)
                  _Tag('Trailing ↑', FenixColors.green),
                if (robot.takeProfitPrice != null)
                  _Tag('TP', FenixColors.green),
                if (robot.stopLossPrice != null)
                  _Tag('SL', FenixColors.red),
              ]),
              const SizedBox(width: 8),
              // Menu de ações
              _ActionsMenu(robot: robot),
            ]),
          ),
        ],
      ),
    );
  }

  (Color, String) _statusStyle(GridStatus s) => switch (s) {
    GridStatus.active       => (FenixColors.green,  'ativo'),
    GridStatus.paused       => (FenixColors.textMuted, 'pausado'),
    GridStatus.reconnecting => (FenixColors.orange, 'reconect.'),
    GridStatus.stopped      => (FenixColors.red,    'encerrado'),
  };
}

class _Tag extends StatelessWidget {
  final String label;
  final Color  color;
  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(.1),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: color.withOpacity(.3), width: .5),
    ),
    child: Text(label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500,
            color: color)),
  );
}

class _ModeBadge extends StatelessWidget {
  final GridMode mode;
  const _ModeBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (mode) {
      GridMode.real  => (FenixColors.green,  'REAL'),
      GridMode.demo  => (FenixColors.orange, 'DEMO'),
      GridMode.paper => (FenixColors.purple, 'PAPER'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(label,
          style: TextStyle(fontFamily: 'RobotoMono', fontSize: 7,
              fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  final GridRobot robot;
  const _ActionsMenu({required this.robot});

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    color: FenixColors.card,
    icon: const Icon(Icons.more_vert,
        size: 16, color: FenixColors.textMuted),
    onSelected: (action) => _handle(context, action),
    itemBuilder: (_) => [
      if (robot.status == GridStatus.active)
        _item('pause', 'Pausar grid', FenixColors.textMuted)
      else
        _item('resume', 'Retomar grid', FenixColors.green),
      _item('edit',  'Editar parâmetros', FenixColors.blue),
      _item('close', 'Encerrar grid',     FenixColors.red),
    ],
  );

  PopupMenuItem<String> _item(String v, String label, Color color) =>
      PopupMenuItem<String>(
        value: v,
        child: Text(label,
            style: TextStyle(fontSize: 12, color: color)),
      );

  void _handle(BuildContext ctx, String action) {
    switch (action) {
      case 'edit':
        ctx.go('/grids/config');
      case 'close':
        showDialog(
          context: ctx,
          builder: (_) => AlertDialog(
            backgroundColor: FenixColors.card,
            title: Text('Encerrar ${robot.symbol}?',
                style: const TextStyle(fontSize: 14,
                    color: FenixColors.textPrimary)),
            content: const Text(
              'Todas as ordens abertas serão canceladas.',
              style: TextStyle(fontSize: 12, color: FenixColors.textMuted),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar')),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Encerrar',
                    style: TextStyle(color: FenixColors.red,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
    }
  }
}

// ── Estado vazio ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.grid_view_outlined,
            size: 48, color: FenixColors.textMuted),
        const SizedBox(height: 12),
        const Text('Nenhum grid ativo',
            style: TextStyle(fontSize: 14,
                color: FenixColors.textSecondary)),
        const SizedBox(height: 6),
        const Text('Crie seu primeiro grid bot para começar',
            style: TextStyle(fontSize: 12, color: FenixColors.textMuted)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => context.go('/grids/config'),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Criar Grid Bot'),
        ),
      ],
    ),
  );
}
