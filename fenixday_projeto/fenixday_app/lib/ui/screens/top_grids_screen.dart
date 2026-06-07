/// FênixDay — Grids de Maior Lucro
///
/// Ranking das melhores configurações de grid da plataforma.
/// Dados anonimizados — nenhum dado pessoal é exposto.
///
/// Ao clicar "Copiar Grid", os parâmetros são pré-preenchidos
/// na tela de configuração do grid para o usuário ajustar e confirmar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../theme/fenix_theme.dart';

// ── Modelos ───────────────────────────────────────────────────────────────────

enum GridPeriod { day, week, month, allTime }

class _TopGrid {
  final int rank;
  final String symbol;
  final String exchange;
  final double profitPct;
  final double profitUsdt;
  final int closedCycles;
  final double upperBound;
  final double lowerBound;
  final int numGrids;
  final bool isGeometric;
  final double marginPct;
  final int activeDays;
  final int copiedBy;     // quantos usuários copiaram
  final bool isVerified;  // grid verificado pelo admin

  const _TopGrid({
    required this.rank,
    required this.symbol,
    required this.exchange,
    required this.profitPct,
    required this.profitUsdt,
    required this.closedCycles,
    required this.upperBound,
    required this.lowerBound,
    required this.numGrids,
    required this.isGeometric,
    required this.marginPct,
    required this.activeDays,
    required this.copiedBy,
    required this.isVerified,
  });
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _periodProvider = StateProvider<GridPeriod>((ref) => GridPeriod.week);
final _searchProvider  = StateProvider<String>((ref) => '');

final _topGridsProvider = Provider.family<List<_TopGrid>, GridPeriod>((ref, period) {
  // Mock — substituir por GET /api/v1/top-grids?period=week
  return [
    _TopGrid(rank: 1,  symbol: 'ETH/USDT',   exchange: 'Binance', profitPct: 8.42,  profitUsdt: 84.20,  closedCycles: 198, upperBound: 2180, lowerBound: 1820, numGrids: 20, isGeometric: true,  marginPct: 0.42, activeDays: 7,  copiedBy: 1243, isVerified: true),
    _TopGrid(rank: 2,  symbol: 'BTC/USDT',   exchange: 'Binance', profitPct: 7.81,  profitUsdt: 781.0,  closedCycles: 164, upperBound: 68000,lowerBound: 64000,numGrids: 17, isGeometric: true,  marginPct: 0.41, activeDays: 7,  copiedBy: 987,  isVerified: true),
    _TopGrid(rank: 3,  symbol: 'SOL/USDT',   exchange: 'Bybit',   profitPct: 7.35,  profitUsdt: 73.50,  closedCycles: 172, upperBound: 174,  lowerBound: 142,  numGrids: 15, isGeometric: true,  marginPct: 0.43, activeDays: 7,  copiedBy: 756,  isVerified: true),
    _TopGrid(rank: 4,  symbol: 'BNB/USDT',   exchange: 'Binance', profitPct: 6.98,  profitUsdt: 69.80,  closedCycles: 158, upperBound: 650,  lowerBound: 575,  numGrids: 12, isGeometric: false, marginPct: 0.40, activeDays: 7,  copiedBy: 534,  isVerified: false),
    _TopGrid(rank: 5,  symbol: 'AVAX/USDT',  exchange: 'OKX',     profitPct: 6.54,  profitUsdt: 65.40,  closedCycles: 145, upperBound: 34,   lowerBound: 28,   numGrids: 10, isGeometric: true,  marginPct: 0.45, activeDays: 7,  copiedBy: 421,  isVerified: false),
    _TopGrid(rank: 6,  symbol: 'MATIC/USDT', exchange: 'Binance', profitPct: 6.12,  profitUsdt: 61.20,  closedCycles: 138, upperBound: 0.86, lowerBound: 0.72, numGrids: 14, isGeometric: true,  marginPct: 0.39, activeDays: 7,  copiedBy: 389,  isVerified: false),
    _TopGrid(rank: 7,  symbol: 'LINK/USDT',  exchange: 'Binance', profitPct: 5.87,  profitUsdt: 58.70,  closedCycles: 131, upperBound: 15.5, lowerBound: 12.8, numGrids: 12, isGeometric: false, marginPct: 0.41, activeDays: 7,  copiedBy: 312,  isVerified: false),
    _TopGrid(rank: 8,  symbol: 'DOT/USDT',   exchange: 'Bybit',   profitPct: 5.43,  profitUsdt: 54.30,  closedCycles: 122, upperBound: 6.8,  lowerBound: 5.6,  numGrids: 10, isGeometric: true,  marginPct: 0.38, activeDays: 7,  copiedBy: 278,  isVerified: false),
    _TopGrid(rank: 9,  symbol: 'ADA/USDT',   exchange: 'Binance', profitPct: 5.10,  profitUsdt: 51.00,  closedCycles: 114, upperBound: 0.46, lowerBound: 0.38, numGrids: 8,  isGeometric: true,  marginPct: 0.40, activeDays: 7,  copiedBy: 245,  isVerified: false),
    _TopGrid(rank: 10, symbol: 'ATOM/USDT',  exchange: 'OKX',     profitPct: 4.78,  profitUsdt: 47.80,  closedCycles: 106, upperBound: 7.8,  lowerBound: 6.2,  numGrids: 10, isGeometric: false, marginPct: 0.39, activeDays: 7,  copiedBy: 198,  isVerified: false),
  ];
});

// ── Tela principal ────────────────────────────────────────────────────────────

class TopGridsScreen extends ConsumerWidget {
  const TopGridsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(_periodProvider);
    final grids  = ref.watch(_topGridsProvider(period));
    final search = ref.watch(_searchProvider).toLowerCase();

    final filtered = search.isEmpty
        ? grids
        : grids.where((g) => g.symbol.toLowerCase().contains(search)).toList();

    return Scaffold(
      backgroundColor: FenixColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────
            _Header(),

            // ── Filtro de período ──────────────────────────────────────
            _PeriodFilter(),

            // ── Busca ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: TextField(
                onChanged: (v) =>
                    ref.read(_searchProvider.notifier).state = v,
                style: const TextStyle(
                    fontSize: 13, color: FenixColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Buscar por par (ex: ETH, BTC)...',
                  hintStyle:
                      TextStyle(color: FenixColors.textMuted, fontSize: 12),
                  prefixIcon: Icon(Icons.search,
                      size: 16, color: FenixColors.textMuted),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Cabeçalho da tabela ────────────────────────────────────
            _TableHeader(),

            // ── Lista ──────────────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('Nenhum grid encontrado.',
                          style: TextStyle(color: FenixColors.textMuted)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(
                          height: 0,
                          thickness: 0.5,
                          color: FenixColors.border),
                      itemBuilder: (context, i) => _GridRow(
                        grid: filtered[i],
                        onCopy: () =>
                            _showCopySheet(context, filtered[i]),
                      ),
                    ),
            ),

            // ── Disclaimer ─────────────────────────────────────────────
            _Disclaimer(),
          ],
        ),
      ),
    );
  }

  void _showCopySheet(BuildContext context, _TopGrid grid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FenixColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => _CopyGridSheet(grid: grid),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Grids de Maior Lucro',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: FenixColors.textPrimary)),
              Text('Configurações com melhor desempenho — copie e adapte',
                  style: TextStyle(
                      fontSize: 10, color: FenixColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Filtro de período ─────────────────────────────────────────────────────────

class _PeriodFilter extends ConsumerWidget {
  static const _options = [
    (GridPeriod.day,     '24h'),
    (GridPeriod.week,    '7 dias'),
    (GridPeriod.month,   '30 dias'),
    (GridPeriod.allTime, 'Todos'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(_periodProvider);

    return Container(
      color: FenixColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Row(
        children: _options.map((o) {
          final active = o.$1 == current;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () =>
                  ref.read(_periodProvider.notifier).state = o.$1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color:
                      active ? FenixColors.yellowBg : FenixColors.card,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: active
                        ? FenixColors.yellow.withOpacity(0.4)
                        : FenixColors.border,
                    width: 0.5,
                  ),
                ),
                child: Text(o.$2,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: active
                          ? FenixColors.yellow
                          : FenixColors.textMuted,
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Cabeçalho da tabela ───────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: FenixColors.border, width: 0.5),
        ),
      ),
      child: const Row(
        children: [
          SizedBox(width: 28,
              child: Text('#', style: TextStyle(fontSize: 10, color: FenixColors.textMuted))),
          Expanded(flex: 3,
              child: Text('Par', style: TextStyle(fontSize: 10, color: FenixColors.textMuted))),
          SizedBox(width: 60,
              child: Text('Lucro', style: TextStyle(fontSize: 10, color: FenixColors.textMuted), textAlign: TextAlign.right)),
          SizedBox(width: 50,
              child: Text('Ciclos', style: TextStyle(fontSize: 10, color: FenixColors.textMuted), textAlign: TextAlign.right)),
          SizedBox(width: 50,
              child: Text('Cópias', style: TextStyle(fontSize: 10, color: FenixColors.textMuted), textAlign: TextAlign.right)),
          SizedBox(width: 70),
        ],
      ),
    );
  }
}

// ── Linha de grid ─────────────────────────────────────────────────────────────

class _GridRow extends StatelessWidget {
  final _TopGrid grid;
  final VoidCallback onCopy;

  const _GridRow({required this.grid, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final rankColor = grid.rank <= 3 ? FenixColors.yellow : FenixColors.textMuted;
    final exchColor = switch (grid.exchange) {
      'Binance' => FenixColors.yellow,
      'Bybit'   => FenixColors.orange,
      'OKX'     => FenixColors.blue,
      _         => FenixColors.textMuted,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 28,
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: grid.rank <= 3
                    ? FenixColors.yellowBg
                    : FenixColors.card,
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                '${grid.rank}',
                style: TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: rankColor),
              ),
            ),
          ),

          // Par + exchange + verified
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(grid.symbol,
                        style: const TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: FenixColors.textPrimary)),
                    if (grid.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified,
                          size: 11, color: FenixColors.blue),
                    ],
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: exchColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(grid.exchange,
                          style: TextStyle(
                              fontSize: 9, color: exchColor)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${grid.activeDays}d · ${grid.numGrids} grades · ${grid.isGeometric ? 'Geom.' : 'Arit.'}',
                      style: const TextStyle(
                          fontSize: 9, color: FenixColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lucro
          SizedBox(
            width: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${grid.profitPct.toStringAsFixed(2)}%',
                  style: const TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: FenixColors.green),
                ),
                Text(
                  '+\$${grid.profitUsdt.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 9,
                      color: FenixColors.textMuted),
                ),
              ],
            ),
          ),

          // Ciclos
          SizedBox(
            width: 50,
            child: Text(
              '${grid.closedCycles}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 11,
                  color: FenixColors.textSecondary),
            ),
          ),

          // Cópias
          SizedBox(
            width: 50,
            child: Text(
              '${grid.copiedBy}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 11,
                  color: FenixColors.textMuted),
            ),
          ),

          // Botão copiar
          SizedBox(
            width: 70,
            child: GestureDetector(
              onTap: onCopy,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: FenixColors.yellowBg,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: FenixColors.yellow.withOpacity(0.3),
                      width: 0.5),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Copiar ↗',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: FenixColors.yellow),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom sheet de cópia ─────────────────────────────────────────────────────

class _CopyGridSheet extends StatelessWidget {
  final _TopGrid grid;
  const _CopyGridSheet({super.key, required this.grid});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.0000');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Copiar grid — ${grid.symbol}',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: FenixColors.textPrimary),
                        ),
                        if (grid.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified,
                              size: 13, color: FenixColors.blue),
                        ],
                      ],
                    ),
                    Text(
                      'Rank #${grid.rank} · ${grid.copiedBy} cópias · ${grid.exchange}',
                      style: const TextStyle(
                          fontSize: 11, color: FenixColors.textMuted),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close,
                    size: 18, color: FenixColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Parâmetros que serão copiados
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FenixColors.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: FenixColors.border, width: 0.5),
            ),
            child: Column(
              children: [
                _SheetRow('Preço Superior',
                    '\$${fmt.format(grid.upperBound)}'),
                _SheetRow('Preço Inferior',
                    '\$${fmt.format(grid.lowerBound)}'),
                _SheetRow('Quantidade de grades',
                    '${grid.numGrids} grades'),
                _SheetRow('Modo',
                    grid.isGeometric ? 'Geométrico' : 'Aritmético'),
                _SheetRow('Margem por grade',
                    '${(grid.marginPct * 100).toStringAsFixed(2)}%'),
                _SheetRow('Exchange', grid.exchange),
                _SheetRow('Lucro histórico (${grid.activeDays}d)',
                    '+${grid.profitPct.toStringAsFixed(2)}%',
                    valueColor: FenixColors.green),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Aviso
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FenixColors.orangeBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    size: 13, color: FenixColors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Os parâmetros serão pré-preenchidos na tela de configuração. '
                    'Você poderá ajustar antes de confirmar. '
                    'Resultados passados não garantem resultados futuros.',
                    style: TextStyle(
                        fontSize: 10,
                        color: FenixColors.orange,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Botão confirmar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: FenixColors.yellow,
                foregroundColor: const Color(0xFF1A0A00),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              icon: const Icon(Icons.copy_outlined, size: 16),
              label: const Text('Confirmar e ir para configuração',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              onPressed: () {
                Navigator.pop(context);
                // TODO: navegar para GridConfigScreen com params pré-preenchidos
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _SheetRow(this.label, this.value,
      {this.valueColor = FenixColors.textPrimary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: FenixColors.textMuted)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: valueColor)),
        ],
      ),
    );
  }
}

// ── Disclaimer ────────────────────────────────────────────────────────────────

class _Disclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
            top: BorderSide(color: FenixColors.border, width: 0.5)),
      ),
      child: const Text(
        '⚠ Rankings baseados em desempenho histórico anonimizado. '
        'Resultados passados não garantem resultados futuros. '
        'Opere com responsabilidade.',
        style: TextStyle(
            fontSize: 10, color: FenixColors.textMuted, height: 1.4),
        textAlign: TextAlign.center,
      ),
    );
  }
}
