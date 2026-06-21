/// FênixDay — Tela de Configuração do Grid Bot v2
///
/// Reprodução fiel da referência visual:
///   • Toolbar horizontal estilo TradingView (timeframes + indicadores + botões)
///   • Toolbar vertical esquerda com todas as ferramentas de desenho
///   • Gráfico candlestick com overlay das linhas do grid
///   • Layout responsivo: desktop/tablet = lado a lado | mobile = coluna única
///   • Em mobile: sem toolbars laterais

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../theme/fenix_theme.dart';
import '../widgets/chart/candlestick_chart.dart';

// ── Breakpoints ──────────────────────────────────────────────────────────────
const double _kTablet  = 768.0;
const double _kDesktop = 1100.0;

// ── Providers ────────────────────────────────────────────────────────────────
final _tfProvider    = StateProvider<String>((ref) => '1h');

// ── Provider de candles reais ─────────────────────────────────────────────────
final _symbolProvider   = StateProvider<String>((ref) => 'BTCUSDT');
final _exchangeProvider = StateProvider<String>((ref) => 'Binance');

const _kPopularPairs = [
  'BTCUSDT','ETHUSDT','BNBUSDT','SOLUSDT','XRPUSDT',
  'ADAUSDT','DOGEUSDT','AVAXUSDT','DOTUSDT','LINKUSDT',
  'MATICUSDT','LTCUSDT','UNIUSDT','ATOMUSDT','TRXUSDT',
];

const _kExchanges = ['Binance', 'Bybit', 'OKX', 'Bitget', 'MEXC'];

final _candlesProvider = FutureProvider.family<List<CandleData>, String>((ref, key) async {
  final parts    = key.split('|');
  final symbol   = parts[0];
  final interval = parts[1];
  try {
    final r = await http.get(Uri.parse(
      'https://api.binance.com/api/v3/klines?symbol=$symbol&interval=$interval&limit=80',
    )).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) return _generateMockCandles();
    final List data = jsonDecode(r.body);
    return data.map((k) => CandleData(
      time:   DateTime.fromMillisecondsSinceEpoch(k[0] as int),
      open:   double.parse(k[1].toString()),
      high:   double.parse(k[2].toString()),
      low:    double.parse(k[3].toString()),
      close:  double.parse(k[4].toString()),
      volume: double.parse(k[5].toString()),
    )).toList();
  } catch (_) {
    return _generateMockCandles();
  }
});
final _toolProvider  = StateProvider<String>((ref) => 'crosshair');
final _modeProvider = StateProvider<String>((ref) => 'manual'); // 'ia' | 'manual'

final _paramsProvider = StateNotifierProvider<_GridParamsNotifier, _GridParams>(
  (ref) => _GridParamsNotifier(),
);

// ── Tela ─────────────────────────────────────────────────────────────────────
class GridConfigScreenV2 extends ConsumerStatefulWidget {
  final String? initialSymbol;
  final String? initialExchange;
  final double? initialUpper;
  final double? initialLower;
  final int? initialGrids;

  const GridConfigScreenV2({
    super.key,
    this.initialSymbol,
    this.initialExchange,
    this.initialUpper,
    this.initialLower,
    this.initialGrids,
  });

  @override
  ConsumerState<GridConfigScreenV2> createState() => _GridConfigScreenV2State();
}

class _GridConfigScreenV2State extends ConsumerState<GridConfigScreenV2> {
  @override
  void initState() {
    super.initState();
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final symbol   = prefs.getString('grid_init_symbol');
    final exchange = prefs.getString('grid_init_exchange');
    final upper    = prefs.getDouble('grid_init_upper');
    final lower    = prefs.getDouble('grid_init_lower');
    final grids    = prefs.getInt   ('grid_init_grids');

    if (!mounted) return;

    if (symbol != null) {
      ref.read(_symbolProvider.notifier).state = symbol;
      // Limpar após usar
      await prefs.remove('grid_init_symbol');
    }
    if (exchange != null) {
      ref.read(_exchangeProvider.notifier).state = exchange;
      await prefs.remove('grid_init_exchange');
    }
    if (upper != null && lower != null) {
      ref.read(_paramsProvider.notifier).setFromIa(lower, upper, grids ?? 20);
      await prefs.remove('grid_init_upper');
      await prefs.remove('grid_init_lower');
      await prefs.remove('grid_init_grids');
    }
    // Carregar saldo real da exchange
    final balance = prefs.getDouble('grid_init_balance');
    debugPrint('FENIX_BALANCE: grid_init_balance=$balance');
    if (balance != null && balance > 0) {
      ref.read(_paramsProvider.notifier).setBalance(balance);
      await prefs.remove('grid_init_balance');
    }
  }

  @override
  Widget build(BuildContext context) {
    final w         = MediaQuery.of(context).size.width;
    final isTablet  = w >= _kTablet;
    final isDesktop = w >= _kDesktop;

    return Scaffold(
      backgroundColor: FenixColors.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _PairHeader(),
            _HorizontalToolbar(),
            Expanded(
              child: isTablet
                  ? Row(children: [
                      _VerticalToolbar(),
                      Expanded(child: _ChartArea()),
                      Container(width: .5, color: FenixColors.border),
                      SizedBox(width: isDesktop ? 300 : 240, child: _ParamsPanel()),
                    ])
                  : Column(children: [
                      Expanded(child: _ChartArea(showVerticalToolbar: false)),
                      _ParamsPanel(mobile: true),
                    ]),
            ),
            // Esconder SummaryBar quando teclado está aberto
            if (MediaQuery.of(context).viewInsets.bottom == 0) _SummaryBar(),
          ],
        ),
      ),
    );
  }
}

// ── Cabeçalho do par ─────────────────────────────────────────────────────────
class _PairHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbol   = ref.watch(_symbolProvider);
    final exchange = ref.watch(_exchangeProvider);
    final tf       = ref.watch(_tfProvider);
    final asyncCandles = ref.watch(_candlesProvider('$symbol|$tf|$exchange'));
    final displayPair  = symbol.replaceAll('USDT', '/USDT');

    double? price, chgPct;
    asyncCandles.whenData((candles) {
      if (candles.length >= 2) {
        price   = candles.last.close;
        final prev = candles[candles.length - 2];
        chgPct  = prev.close > 0 ? (candles.last.close - prev.close) / prev.close * 100 : 0;
      }
    });

    return Container(
      color: FenixColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(children: [
        // Seletor de par
        GestureDetector(
          onTap: () => _showPairSelector(context, ref),
          child: Row(children: [
            Container(
              width: 26, height: 26,
              decoration: const BoxDecoration(color: FenixColors.yellow, shape: BoxShape.circle),
              child: Center(child: Text(
                symbol.substring(0, 1),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A0A00)),
              )),
            ),
            const SizedBox(width: 6),
            Text(displayPair, style: const TextStyle(
                fontFamily: 'RobotoMono', fontSize: 13,
                fontWeight: FontWeight.w500, color: FenixColors.textPrimary)),
            const Icon(Icons.arrow_drop_down, size: 16, color: FenixColors.yellow),
          ]),
        ),
        const SizedBox(width: 10),

        // Preço atual
        if (price != null) ...[
          Text(NumberFormat('#,##0.00').format(price),
              style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 16,
                  fontWeight: FontWeight.w500, color: FenixColors.green)),
          const SizedBox(width: 6),
          Text('${(chgPct ?? 0) >= 0 ? "+" : ""}${(chgPct ?? 0).toStringAsFixed(2)}%',
              style: TextStyle(fontFamily: 'RobotoMono', fontSize: 11,
                  color: (chgPct ?? 0) >= 0 ? FenixColors.green : FenixColors.red)),
        ] else
          const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: FenixColors.yellow)),

        const Spacer(),

        // Seletor de exchange
        GestureDetector(
          onTap: () => _showExchangeSelector(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: FenixColors.yellowBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: FenixColors.yellow.withOpacity(.3), width: .5),
            ),
            child: Row(children: [
              Text(exchange, style: const TextStyle(
                  fontSize: 11, color: FenixColors.yellow, fontWeight: FontWeight.w500)),
              const Icon(Icons.arrow_drop_down, size: 14, color: FenixColors.yellow),
            ]),
          ),
        ),
      ]),
    );
  }

  void _showPairSelector(BuildContext ctx, WidgetRef ref) {
    final current = ref.read(_symbolProvider);
    showModalBottomSheet(
      context: ctx,
      backgroundColor: FenixColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Selecionar par', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: FenixColors.textPrimary)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: _kPopularPairs.map((p) {
            final selected = p == current;
            return GestureDetector(
              onTap: () {
                ref.read(_symbolProvider.notifier).state = p;
                Navigator.pop(ctx);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? FenixColors.yellowBg : FenixColors.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? FenixColors.yellow : FenixColors.border,
                    width: selected ? 1 : 0.5,
                  ),
                ),
                child: Text(p.replaceAll('USDT', '/USDT'), style: TextStyle(
                    fontSize: 12,
                    color: selected ? FenixColors.yellow : FenixColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
              ),
            );
          }).toList()),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  void _showExchangeSelector(BuildContext ctx, WidgetRef ref) {
    final current = ref.read(_exchangeProvider);
    showModalBottomSheet(
      context: ctx,
      backgroundColor: FenixColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Selecionar corretora', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: FenixColors.textPrimary)),
          const SizedBox(height: 12),
          ..._kExchanges.map((e) => ListTile(
            onTap: () { ref.read(_exchangeProvider.notifier).state = e; Navigator.pop(ctx); },
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: e == current ? FenixColors.yellowBg : FenixColors.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: e == current ? FenixColors.yellow : FenixColors.border),
              ),
              child: Center(child: Text(e[0], style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: e == current ? FenixColors.yellow : FenixColors.textMuted))),
            ),
            title: Text(e, style: TextStyle(
                fontSize: 13,
                color: e == current ? FenixColors.yellow : FenixColors.textPrimary)),
            trailing: e == current ? const Icon(Icons.check, color: FenixColors.yellow, size: 16) : null,
          )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String label, value;
  const _StatMini(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 9, color: FenixColors.textMuted)),
      Text(value,
          style: const TextStyle(
              fontFamily: 'RobotoMono', fontSize: 11,
              fontWeight: FontWeight.w500, color: FenixColors.textPrimary)),
    ],
  );
}

// ── Toolbar horizontal ────────────────────────────────────────────────────────
class _HorizontalToolbar extends ConsumerWidget {
  static const _tfs = ['15m', '1h', '4h', '1D'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_tfProvider);
    return Container(
      color: FenixColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
        children: [
          // Timeframes
          ..._tfs.map((tf) => _TfBtn(
                label: tf,
                active: tf == selected,
                onTap: () => ref.read(_tfProvider.notifier).state = tf,
              )),

          // Divisor
          _vDivider(),

          // Comparar
          _IconBtn(icon: Icons.compare_arrows, tooltip: 'Comparar'),
          // Tipo de gráfico
          _IconBtn(icon: Icons.candlestick_chart_outlined, tooltip: 'Tipo de gráfico'),

          // Divisor
          _vDivider(),

          // Indicadores
          _TextBtn(
            icon: Icons.functions,
            label: 'Indicadores',
            onTap: () {},
          ),

          const SizedBox(width: 8),

          // Trading View
          _OutlineBtn(label: 'Trading View', onTap: () {}),
          const SizedBox(width: 5),
          // Profundidade
          _OutlineBtn(label: 'Profundidade', onTap: () {}),
          const SizedBox(width: 8),
          // Tela cheia
          _IconBtn(icon: Icons.fullscreen, tooltip: 'Tela cheia'),
          // Configurações
          _IconBtn(icon: Icons.settings_outlined, tooltip: 'Configurações'),
        ],
        ),
      ),
    );
  }

  Widget _vDivider() => Container(
      width: .5, height: 18, color: FenixColors.border,
      margin: const EdgeInsets.symmetric(horizontal: 6));
}

class _TfBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TfBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? FenixColors.yellowBg : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: active
            ? Border.all(color: FenixColors.yellow.withOpacity(.3), width: .5)
            : null,
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w500,
              color: active ? FenixColors.yellow : FenixColors.textMuted)),
    ),
  );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _IconBtn({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(icon, size: 15, color: FenixColors.textMuted),
      ),
    ),
  );
}

class _TextBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _TextBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(children: [
        Icon(icon, size: 13, color: FenixColors.textMuted),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: FenixColors.textMuted)),
      ]),
    ),
  );
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: FenixColors.border, width: .5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 11, color: FenixColors.textSecondary)),
    ),
  );
}

// ── Toolbar vertical esquerda (desktop/tablet) ────────────────────────────────
class _VerticalToolbar extends ConsumerWidget {
  // Ferramentas agrupadas exatamente como na imagem de referência
  static final _groups = [
    // Grupo 1: cursor
    [_VTool('crosshair', Icons.add, 'Cursor / Crosshair')],
    // Grupo 2: linhas
    [
      _VTool('line',      Icons.show_chart,            'Linha de tendência'),
      _VTool('hline',     Icons.horizontal_rule,        'Linha horizontal'),
      _VTool('hlines',    Icons.format_line_spacing,    'Linhas paralelas'),
      _VTool('arrow',     Icons.arrow_right_alt,        'Seta'),
    ],
    // Grupo 3: texto
    [_VTool('text', Icons.text_fields, 'Texto')],
    // Grupo 4: padrões
    [
      _VTool('elliott',   Icons.timeline,               'Ondas de Elliott'),
      _VTool('fib',       Icons.compress,               'Fibonacci Retracement'),
      _VTool('ruler',     Icons.straighten,             'Régua / Medidor'),
    ],
    // Grupo 5: formas
    [
      _VTool('brush',     Icons.brush_outlined,         'Pincel livre'),
      _VTool('zoom',      Icons.zoom_in,                'Zoom'),
    ],
    // Grupo 6: extras
    [
      _VTool('magnet',    Icons.adjust,                 'Imã'),
      _VTool('layers',    Icons.layers_outlined,        'Camadas / Visibilidade'),
      _VTool('lock',      Icons.lock_outline,           'Bloquear objetos'),
      _VTool('eye_cfg',   Icons.visibility_outlined,    'Configurar visibilidade'),
    ],
    // Grupo 7: lixeira
    [_VTool('delete', Icons.delete_outline, 'Excluir objetos')],
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_toolProvider);
    return Container(
      width: 42,
      color: FenixColors.surface,
      child: Column(
        children: [
          const SizedBox(height: 6),
          ..._groups.expand((group) => [
            ...group.map((t) => _VToolBtn(
                  tool: t,
                  selected: selected == t.id,
                  onTap: () => ref.read(_toolProvider.notifier).state = t.id,
                )),
            // Separador entre grupos
            if (group != _groups.last)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Divider(height: 1, thickness: .5, color: FenixColors.border),
              ),
          ]),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _VTool {
  final String id, tooltip;
  final IconData icon;
  const _VTool(this.id, this.icon, this.tooltip);
}

class _VToolBtn extends StatelessWidget {
  final _VTool tool;
  final bool selected;
  final VoidCallback onTap;
  const _VToolBtn({required this.tool, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tool.tooltip,
    preferBelow: false,
    child: InkWell(
      onTap: onTap,
      child: Container(
        width: 42, height: 34,
        decoration: selected
            ? BoxDecoration(
                color: FenixColors.yellowBg,
                border: Border(
                  left: BorderSide(color: FenixColors.yellow, width: 2),
                ),
              )
            : null,
        child: Icon(
          tool.icon,
          size: 16,
          color: selected ? FenixColors.yellow : FenixColors.textMuted,
        ),
      ),
    ),
  );
}

// ── Área do gráfico ───────────────────────────────────────────────────────────
class _ChartArea extends ConsumerWidget {
  final bool showVerticalToolbar;
  const _ChartArea({this.showVerticalToolbar = true});

  @override
   Widget build(BuildContext context, WidgetRef ref) {
    final params  = ref.watch(_paramsProvider);
    final tf      = ref.watch(_tfProvider);
    final symbol  = ref.watch(_symbolProvider);
    final exchange = ref.watch(_exchangeProvider);
    final asyncCandles = ref.watch(_candlesProvider('$symbol|$tf|$exchange'));

    return Container(
      color: FenixColors.bg,
      child: ClipRect(
        child: Column(
        children: [
          // Info OHLC
          asyncCandles.when(
            loading: () => Container(
              color: FenixColors.bg,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: const Text('Carregando...', style: TextStyle(
                  fontFamily: 'RobotoMono', fontSize: 10, color: FenixColors.textMuted)),
            ),
            error: (_, __) => const SizedBox(height: 22),
            data: (candles) {
              if (candles.isEmpty) return const SizedBox(height: 22);
              final last   = candles.last;
              final prev   = candles.length > 1 ? candles[candles.length - 2] : last;
              final chg    = last.close - prev.close;
              final chgPct = prev.close > 0 ? chg / prev.close * 100 : 0.0;
              final fmt    = (double v) => v >= 1000 ? v.toStringAsFixed(2) : v.toStringAsFixed(4);
              return Container(
                color: FenixColors.bg,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                  Text('${symbol.replaceAll('USDT', '/USDT')} · $tf · BINANCE',
                      style: const TextStyle(fontFamily: 'RobotoMono',
                          fontSize: 10, color: FenixColors.textMuted)),
                  const SizedBox(width: 10),
                  _ohlc('Abr', fmt(last.open)),
                  _ohlc('Máx', fmt(last.high), color: FenixColors.green),
                  _ohlc('Mín', fmt(last.low),  color: FenixColors.red),
                  _ohlc('Fch', fmt(last.close)),
                  Text(' ${chg >= 0 ? "+" : ""}${chg.toStringAsFixed(2)} (${chgPct.toStringAsFixed(2)}%)',
                      style: TextStyle(fontFamily: 'RobotoMono', fontSize: 10,
                          color: chg >= 0 ? FenixColors.green : FenixColors.red)),
                  ]),
                ),
              );
            },
          ),

          // Gráfico
          Expanded(
            child: asyncCandles.when(
              loading: () => const Center(child: CircularProgressIndicator(
                  color: FenixColors.yellow, strokeWidth: 2)),
              error: (_, __) => CandlestickChart(
                candles: _generateMockCandles(),
                upperBound: params.upperPrice,
                lowerBound: params.lowerPrice,
                currentPrice: null,
                visibleCandles: 60,
              ),
              data: (candles) {
                // Auto-inicializar range se ainda está no default
                if (candles.isNotEmpty && params.upperPrice == 68000 && params.lowerPrice == 62000) {
                  final price = candles.last.close;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(_paramsProvider.notifier).updateFromPrice(price);
                  });
                }
                return CandlestickChart(
                  candles: candles,
                  upperBound:   params.upperPrice,
                  lowerBound:   params.lowerPrice,
                  currentPrice: candles.isNotEmpty ? candles.last.close : null,
                  gridLevels:   params.computedLevels,
                  visibleCandles: 60,
                );
              },
            ),
          ),

          // Barra de períodos e info rodapé
          _PeriodBar(),
        ],
        ),
      ),
    );
  }

  Widget _ohlc(String label, String value, {Color color = FenixColors.textSecondary}) =>
      Padding(
        padding: const EdgeInsets.only(right: 10),
        child: RichText(
          text: TextSpan(children: [
            TextSpan(
                text: '$label ',
                style: const TextStyle(
                    fontFamily: 'RobotoMono', fontSize: 10,
                    color: FenixColors.textMuted)),
            TextSpan(
                text: value,
                style: TextStyle(
                    fontFamily: 'RobotoMono', fontSize: 10, color: color)),
          ]),
        ),
      );
}

// ── Barra de períodos (rodapé do gráfico) ────────────────────────────────────
class _PeriodBar extends StatelessWidget {
  static const _periods = ['1D', '5D', '1M', '3M', '6M', 'YTD', '1A', '5A', 'Todos'];

  @override
  Widget build(BuildContext context) => Container(
    color: FenixColors.surface,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
      ..._periods.map((p) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(p,
                style: const TextStyle(fontSize: 10, color: FenixColors.textMuted)),
          )),
      const SizedBox(width: 4),
      const Icon(Icons.compare_arrows, size: 12, color: FenixColors.textMuted),
      const SizedBox(width: 8),
      Text(
        DateFormat('HH:mm:ss').format(DateTime.now()) + ' (UTC-3)',
        style: const TextStyle(
            fontFamily: 'RobotoMono', fontSize: 10, color: FenixColors.textMuted),
      ),
      const SizedBox(width: 10),
      const Text('%', style: TextStyle(fontSize: 10, color: FenixColors.textMuted)),
      const SizedBox(width: 8),
      const Text('log', style: TextStyle(fontSize: 10, color: FenixColors.textMuted)),
      const SizedBox(width: 8),
      const Text('auto',
          style: TextStyle(
              fontSize: 10, color: FenixColors.yellow,
              fontWeight: FontWeight.w500)),
      ]),
    ),
  );
}

// ── Painel de parâmetros ──────────────────────────────────────────────────────
class _ParamsPanel extends ConsumerStatefulWidget {
  final bool mobile;
  const _ParamsPanel({this.mobile = false});

  @override
  ConsumerState<_ParamsPanel> createState() => _ParamsPanelState();
}

class _ParamsPanelState extends ConsumerState<_ParamsPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  bool _showAdvanced = false;

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final params  = ref.watch(_paramsProvider);
    final notifier = ref.read(_paramsProvider.notifier);

    Widget content = Column(
      children: [
        // Abas
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: FenixColors.border, width: .5)),
          ),
          child: TabBar(
            controller: _tab,
            labelColor: FenixColors.yellow,
            unselectedLabelColor: FenixColors.textMuted,
            indicatorColor: FenixColors.yellow,
            indicatorWeight: 2,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            tabs: const [Tab(text: 'Parâmetros do Grid'), Tab(text: 'Sobre o Bot')],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              // ── Aba parâmetros ──────────────────────────────────────────
              SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Toggle IA / Manual
                    Consumer(builder: (ctx, ref, _) {
                      final mode = ref.watch(_modeProvider);
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          decoration: BoxDecoration(
                            color: FenixColors.bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: FenixColors.border, width: .5),
                          ),
                          child: Row(children: [
                            _ToggleTab(label: '🤖 Indicação IA', active: mode == 'ia',
                                onTap: () => ref.read(_modeProvider.notifier).state = 'ia'),
                            _ToggleTab(label: 'Manual', active: mode == 'manual',
                                onTap: () => ref.read(_modeProvider.notifier).state = 'manual'),
                          ]),
                        ),
                        if (mode == 'ia') ...[
                          const SizedBox(height: 10),
                          _IaRecommendation(),
                        ],
                      ]);
                    }),
                    const SizedBox(height: 12),

                    // Intervalo de preço
                    _FieldLabel('Intervalo de preço (USDT)',
                        trailing: TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero),
                          child: const Text('🗑 Limpar tudo',
                              style: TextStyle(fontSize: 10,
                                  color: FenixColors.textMuted)),
                        )),
                    Row(children: [
                      Expanded(
                        child: _PriceField(
                          value: params.lowerPrice,
                          onMinus: () => notifier.adjustLower(-1),
                          onPlus:  () => notifier.adjustLower(1),
                          onEdit: (v) => notifier.setLower(v),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('–', style: TextStyle(color: FenixColors.textMuted)),
                      ),
                      Expanded(
                        child: _PriceField(
                          value: params.upperPrice,
                          onMinus: () => notifier.adjustUpper(-1),
                          onPlus:  () => notifier.adjustUpper(1),
                          onEdit: (v) => notifier.setUpper(v),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      'Margem de lucro por grid ${params.marginMin.toStringAsFixed(2)}% – ${params.marginMax.toStringAsFixed(2)}% (–)',
                      style: const TextStyle(fontSize: 10, color: FenixColors.textMuted),
                    ),
                    const SizedBox(height: 12),

                    // Quantidade de grids
                    _FieldLabel('Quantidade de grids (2 a 230)'),
                    _PriceField(
                      value: params.numGrids.toDouble(),
                      isInt: true,
                      onMinus: () => notifier.adjustGrids(-1),
                      onPlus:  () => notifier.adjustGrids(1),
                      onEdit: (v) => notifier.adjustGrids(v.toInt() - params.numGrids),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Margem de lucro por grade ${params.currentMargin.toStringAsFixed(2)}% – ${params.marginMax.toStringAsFixed(2)}% (–)',
                      style: const TextStyle(fontSize: 10, color: FenixColors.textMuted),
                    ),
                    const SizedBox(height: 12),

                    // Valor do investimento
                    _FieldLabel('Valor do investimento'),
                    Container(
                      decoration: BoxDecoration(
                        color: FenixColors.card,
                        border: Border.all(color: FenixColors.border, width: .5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            '≥ ${NumberFormat('#,##0.00', 'pt_BR').format(params.allocatedUsdt)}',
                            style: const TextStyle(
                                fontFamily: 'RobotoMono',
                                fontSize: 13, color: FenixColors.textPrimary),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            border: Border.all(color: FenixColors.border, width: .5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(children: [
                            Text('USDT',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: FenixColors.textSecondary)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down,
                                size: 14, color: FenixColors.textMuted),
                          ]),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    SliderTheme(
                      data: _sliderTheme,
                      child: Slider(
                        value: params.allocationPct,
                        onChanged: notifier.setAllocationPct,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: ['0', '25%', '50%', '75%', '100%'].map((s) =>
                          Text(s, style: const TextStyle(
                              fontSize: 9, color: FenixColors.textMuted))).toList(),
                    ),
                    const SizedBox(height: 4),
                    Consumer(builder: (ctx, ref, _) {
                      final params = ref.watch(_paramsProvider);
                      return Text('Disponível ${NumberFormat('#,##0.00', 'pt_BR').format(ref.read(_paramsProvider.notifier)._balanceUsdt)} USDT',
                        style: const TextStyle(
                            fontSize: 10, color: FenixColors.textMuted));
                    }),
                    const SizedBox(height: 12),

                    // Reinvestir lucros
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Reinvestir lucros',
                            style: TextStyle(
                                fontSize: 13, color: FenixColors.textSecondary)),
                        Switch(
                          value: params.reinvest,
                          onChanged: notifier.setReinvest,
                          activeColor: FenixColors.green,
                          inactiveThumbColor: FenixColors.textMuted,
                          inactiveTrackColor: FenixColors.border,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Configurações avançadas
                    InkWell(
                      onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          const Text('Configurações avançadas',
                              style: TextStyle(
                                  fontSize: 13, color: FenixColors.textSecondary)),
                          const Spacer(),
                          Icon(
                            _showAdvanced
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 18, color: FenixColors.textMuted,
                          ),
                        ]),
                      ),
                    ),

                    if (_showAdvanced) ...[
                      const Divider(height: 1, thickness: .5, color: FenixColors.border),
                      const SizedBox(height: 10),
                      // Trailing
                      const Text('Configurações de trailing',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500,
                              color: FenixColors.textPrimary)),
                      const SizedBox(height: 8),
                      _CheckRow(
                        label: 'Trailing up',
                        value: params.trailingUp,
                        onChanged: notifier.setTrailingUp,
                      ),
                      _CheckRow(
                        label: 'Trailing down',
                        value: params.trailingDown,
                        onChanged: notifier.setTrailingDown,
                      ),
                      const SizedBox(height: 10),

                      // Condição de início
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Condição de início',
                              style: TextStyle(
                                  fontSize: 12, color: FenixColors.textSecondary)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: FenixColors.border, width: .5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(children: [
                              Text('Instantâneo',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: FenixColors.textSecondary)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down,
                                  size: 14, color: FenixColors.textMuted),
                            ]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // TP/SL
                      _CheckRow(
                        label: 'TP/SL',
                        value: params.tpsl,
                        onChanged: notifier.setTpSl,
                      ),

                      if (params.tpsl) ...[
                        const SizedBox(height: 8),
                        // Take profit
                        const Text('Take profit',
                            style: TextStyle(
                                fontSize: 11, color: FenixColors.textMuted)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 9),
                              decoration: BoxDecoration(
                                color: FenixColors.card,
                                border: Border.all(
                                    color: FenixColors.border, width: .5),
                                borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(5)),
                              ),
                              child: const Text('Preço TP',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: FenixColors.textMuted)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 9),
                            decoration: BoxDecoration(
                              color: FenixColors.card2,
                              border: Border.all(
                                  color: FenixColors.border, width: .5),
                              borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(5)),
                            ),
                            child: const Row(children: [
                              Text('USDT',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: FenixColors.textSecondary)),
                              SizedBox(width: 3),
                              Icon(Icons.arrow_drop_down,
                                  size: 13, color: FenixColors.textMuted),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        // Stop loss
                        const Text('Stop loss',
                            style: TextStyle(
                                fontSize: 11, color: FenixColors.textMuted)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 9),
                              decoration: BoxDecoration(
                                color: FenixColors.card,
                                border: Border.all(
                                    color: FenixColors.border, width: .5),
                                borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(5)),
                              ),
                              child: const Text('Preço SL',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: FenixColors.textMuted)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 9),
                            decoration: BoxDecoration(
                              color: FenixColors.card2,
                              border: Border.all(
                                  color: FenixColors.border, width: .5),
                              borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(5)),
                            ),
                            child: const Row(children: [
                              Text('USDT',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: FenixColors.textSecondary)),
                              SizedBox(width: 3),
                              Icon(Icons.arrow_drop_down,
                                  size: 13, color: FenixColors.textMuted),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        // Início tardio
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                            color: FenixColors.card,
                            border: Border.all(
                                color: FenixColors.border, width: .5),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Row(children: [
                            Expanded(
                              child: Text('Início tardio',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: FenixColors.textMuted)),
                            ),
                            Text('5 – 30 S',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: FenixColors.textSecondary)),
                          ]),
                        ),
                        const SizedBox(height: 6),
                        // Cripto devolvida
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                            color: FenixColors.card,
                            border: Border.all(
                                color: FenixColors.border, width: .5),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Row(children: [
                            Expanded(
                              child: Text('Cripto devolvida',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: FenixColors.textSecondary)),
                            ),
                            Text('USDT',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: FenixColors.textSecondary)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down,
                                size: 13, color: FenixColors.textMuted),
                          ]),
                        ),
                      ],

                      const SizedBox(height: 10),
                      // Modo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Modo',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: FenixColors.textSecondary)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: FenixColors.border, width: .5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(children: [
                              Text('Geométrico',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: FenixColors.textSecondary)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down,
                                  size: 14, color: FenixColors.textMuted),
                            ]),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Botão Criar
                    Consumer(builder: (ctx, ref, _) {
                      final symbol   = ref.watch(_symbolProvider);
                      final exchange = ref.watch(_exchangeProvider);
                      final params   = ref.watch(_paramsProvider);
                      return _CreateButton(
                        symbol: symbol, exchange: exchange, params: params);
                    }),
                  ],
                ),
              ),

              // ── Aba sobre o bot ────────────────────────────────────────────
              const Center(
                child: Text('Informações sobre o bot',
                    style: TextStyle(color: FenixColors.textMuted)),
              ),
            ],
          ),
        ),
      ],
    );

    return widget.mobile
        ? SizedBox(height: 400, child: content)
        : content;
  }
}

// ── SliderTheme compartilhado ─────────────────────────────────────────────────
final _sliderTheme = SliderThemeData(
  activeTrackColor: FenixColors.yellow,
  inactiveTrackColor: FenixColors.border,
  thumbColor: FenixColors.yellow,
  trackHeight: 3,
  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
);

// ── Barra de resumo inferior ──────────────────────────────────────────────────
class _SummaryBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(_paramsProvider);
    final fmt    = NumberFormat('#,##0.00', 'pt_BR');
    const rate   = 5.49;

    return Container(
      decoration: const BoxDecoration(
        color: FenixColors.surface,
        border: Border(top: BorderSide(color: FenixColors.border, width: .5)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _SumCard('Preço Atual',
              '${fmt.format(ref.watch(_candlesProvider('${ref.watch(_symbolProvider)}|${ref.watch(_tfProvider)}|${ref.watch(_exchangeProvider)}')).value?.isNotEmpty == true ? ref.watch(_candlesProvider('${ref.watch(_symbolProvider)}|${ref.watch(_tfProvider)}|${ref.watch(_exchangeProvider)}')).value!.last.close : 0)} USDT',
              '≈ R\$ ${fmt.format((ref.watch(_candlesProvider('${ref.watch(_symbolProvider)}|${ref.watch(_tfProvider)}|${ref.watch(_exchangeProvider)}')).value?.isNotEmpty == true ? ref.watch(_candlesProvider('${ref.watch(_symbolProvider)}|${ref.watch(_tfProvider)}|${ref.watch(_exchangeProvider)}')).value!.last.close : 0) * rate)}',
              FenixColors.green),
          _divider(),
          _SumCard('Investimento Total',
              '${fmt.format(params.allocatedUsdt)} USDT',
              '${(params.allocationPct * 100).toStringAsFixed(0)}% do saldo',
              FenixColors.textPrimary),
          _divider(),
          _SumCard('Lucro Estimado (7d)',
              '${fmt.format(params.allocatedUsdt * .0124)} ~ ${fmt.format(params.allocatedUsdt * .0187)} USDT',
              '1,24% ~ 1,87%',
              FenixColors.green),
          _divider(),
          _SumCard('Nº de Ordens',
              '${params.totalOrders} ordens',
              '${params.numGrids} compras + ${params.numGrids} vendas',
              FenixColors.textPrimary),
          _divider(),
          _SumCard('Margem por Grade',
              '${params.currentMargin.toStringAsFixed(2)}%',
              'Entre 0,35% e 0,48%',
              FenixColors.green),
        ]),
      ),
    );
  }

  Widget _divider() =>
      Container(width: .5, height: 50, color: FenixColors.border);
}

class _SumCard extends StatelessWidget {
  final String label, value, sub;
  final Color valueColor;
  const _SumCard(this.label, this.value, this.sub, this.valueColor);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: FenixColors.textMuted)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontFamily: 'RobotoMono', fontSize: 12,
                fontWeight: FontWeight.w500, color: valueColor)),
        Text(sub, style: const TextStyle(fontSize: 10, color: FenixColors.textMuted)),
      ],
    ),
  );
}

// ── Widgets de formulário ─────────────────────────────────────────────────────
// ── Recomendação IA ──────────────────────────────────────────────────────────
class _IaRecommendation extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbol   = ref.watch(_symbolProvider);
    final exchange = ref.watch(_exchangeProvider);
    // Parâmetros sugeridos pela IA (baseados no par selecionado)
    final suggestions = _getIaSuggestion(symbol);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1F12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FenixColors.green.withOpacity(.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome, size: 14, color: FenixColors.green),
          const SizedBox(width: 6),
          const Text('Sugestão da IA', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: FenixColors.green)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: FenixColors.green.withOpacity(.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('ADX ${suggestions['adx']}', style: const TextStyle(
                fontSize: 9, color: FenixColors.green, fontFamily: 'RobotoMono')),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _IaStat('Range sugerido', (suggestions['lower'] ?? '—') + ' – ' + (suggestions['upper'] ?? '—')),
          _IaStat('Grids', suggestions['grids'] ?? '—'),
          _IaStat('Margem/ciclo', (suggestions['margin'] ?? '—') + '%'),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: FenixColors.green,
              side: BorderSide(color: FenixColors.green.withOpacity(.4), width: .5),
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.download_outlined, size: 14),
            label: const Text('Aplicar sugestão da IA', style: TextStyle(fontSize: 11)),
            onPressed: () {
              final notifier = ref.read(_paramsProvider.notifier);
              notifier.setFromIa(
                double.parse(suggestions['lower']!.replaceAll(',','.')),
                double.parse(suggestions['upper']!.replaceAll(',','.')),
                int.parse(suggestions['grids']!),
              );
            },
          ),
        ),
      ]),
    );
  }

  Map<String, String> _getIaSuggestion(String symbol) {
    // Sugestões baseadas no par (em produção viria do scanner backend)
    final base = switch (symbol) {
      'BTCUSDT'  => {'lower': '62000', 'upper': '72000', 'grids': '25', 'margin': '0.38', 'adx': '28.4'},
      'ETHUSDT'  => {'lower': '3100',  'upper': '3800',  'grids': '20', 'margin': '0.35', 'adx': '31.2'},
      'BNBUSDT'  => {'lower': '550',   'upper': '680',   'grids': '20', 'margin': '0.40', 'adx': '25.8'},
      'SOLUSDT'  => {'lower': '140',   'upper': '185',   'grids': '18', 'margin': '0.42', 'adx': '33.1'},
      'XRPUSDT'  => {'lower': '0.52',  'upper': '0.65',  'grids': '15', 'margin': '0.37', 'adx': '22.5'},
      _          => {'lower': '—',     'upper': '—',     'grids': '20', 'margin': '0.38', 'adx': '—'},
    };
    return base;
  }
}

class _IaStat extends StatelessWidget {
  final String label, value;
  const _IaStat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 9, color: FenixColors.textMuted)),
      Text(value, style: const TextStyle(fontSize: 11, color: FenixColors.green,
          fontFamily: 'RobotoMono', fontWeight: FontWeight.w500)),
    ],
  ));
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? FenixColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: active
              ? Border.all(color: FenixColors.border, width: .5)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w500,
                color: active
                    ? FenixColors.textPrimary
                    : FenixColors.textMuted)),
      ),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final Widget? trailing;
  const _FieldLabel(this.label, {this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12, color: FenixColors.textSecondary)),
      const Spacer(),
      if (trailing != null) trailing!,
    ]),
  );
}

class _PriceField extends StatefulWidget {
  final double value;
  final bool isInt;
  final VoidCallback onMinus, onPlus;
  final ValueChanged<double>? onEdit;
  const _PriceField({
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.isInt = false,
    this.onEdit,
  });
  @override
  State<_PriceField> createState() => _PriceFieldState();
}

class _PriceFieldState extends State<_PriceField> {
  bool _editing = false;
  late TextEditingController _ctrl;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _focus = FocusNode();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) _commitEdit();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEdit() {
    if (widget.onEdit == null) return;
    final raw = widget.isInt
        ? widget.value.toInt().toString()
        : widget.value.toStringAsFixed(widget.value >= 1 ? 4 : 6);
    _ctrl.text = raw;
    _ctrl.selection = TextSelection(baseOffset: 0, extentOffset: raw.length);
    setState(() => _editing = true);
    Future.microtask(() => _focus.requestFocus());
  }

  void _commitEdit() {
    final text = _ctrl.text.replaceAll(',', '.');
    final parsed = double.tryParse(text);
    if (parsed != null && parsed > 0) widget.onEdit?.call(parsed);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.isInt
        ? widget.value.toInt().toString()
        : NumberFormat('#,##0.00####', 'pt_BR').format(widget.value);

    return Container(
      decoration: BoxDecoration(
        color: FenixColors.card,
        border: Border.all(color: FenixColors.border, width: .5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: _startEdit,
            child: _editing
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                          fontFamily: 'RobotoMono', fontSize: 13,
                          color: FenixColors.textPrimary),
                      decoration: const InputDecoration(
                          border: InputBorder.none, isDense: true,
                          contentPadding: EdgeInsets.zero),
                      onSubmitted: (_) => _commitEdit(),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    child: Text(text,
                        style: const TextStyle(
                            fontFamily: 'RobotoMono', fontSize: 13,
                            color: FenixColors.textPrimary)),
                  ),
          ),
        ),
        InkWell(
          onTap: widget.onMinus,
          child: Container(
            width: 36, height: 40,
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: FenixColors.border, width: .5)),
            ),
            child: const Icon(Icons.remove, size: 14, color: FenixColors.textMuted),
          ),
        ),
        InkWell(
          onTap: widget.onPlus,
          child: Container(
            width: 36, height: 40,
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: FenixColors.border, width: .5)),
            ),
            child: const Icon(Icons.add, size: 14, color: FenixColors.yellow),
          ),
        ),
      ]),
    );
  }
}
class _CheckRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _CheckRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(
      width: 20, height: 20,
      child: Checkbox(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        activeColor: FenixColors.yellow,
        side: const BorderSide(color: FenixColors.border, width: .5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
    ),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(fontSize: 12, color: FenixColors.textSecondary)),
  ]);
}

// ── State ─────────────────────────────────────────────────────────────────────
class _GridParams {
  final double upperPrice, lowerPrice;
  final int numGrids;
  final double marginMin, marginMax;
  final double allocatedUsdt, allocationPct;
  final bool reinvest, trailingUp, trailingDown, tpsl;

  const _GridParams({
    this.upperPrice    = 68000,
    this.lowerPrice    = 62000,
    this.numGrids      = 25,
    this.marginMin     = 0.35,
    this.marginMax     = 0.48,
    this.allocatedUsdt = 0.0,
    this.allocationPct = 0.0,
    this.reinvest      = true,
    this.trailingUp    = false,
    this.trailingDown  = false,
    this.tpsl          = false,
  });

  // Margem real: espaçamento entre grades menos taxa Binance (0.2%)
  double get currentMargin {
    if (numGrids <= 0 || upperPrice <= lowerPrice) return 0.0;
    final spacing = ((upperPrice - lowerPrice) / lowerPrice) / numGrids * 100;
    return (spacing - 0.2).clamp(0.0, 99.0);
  }
  int    get totalOrders    => numGrids * 2;
  List<double> get computedLevels {
    if (numGrids <= 1) return [];
    final step = (upperPrice - lowerPrice) / numGrids;
    return List.generate(numGrids - 1, (i) => lowerPrice + step * (i + 1));
  }

  _GridParams copyWith({
    double? upperPrice, double? lowerPrice, int? numGrids,
    double? allocatedUsdt, double? allocationPct,
    bool? reinvest, bool? trailingUp, bool? trailingDown, bool? tpsl,
  }) => _GridParams(
    upperPrice:    upperPrice    ?? this.upperPrice,
    lowerPrice:    lowerPrice    ?? this.lowerPrice,
    numGrids:      numGrids      ?? this.numGrids,
    allocatedUsdt: allocatedUsdt ?? this.allocatedUsdt,
    allocationPct: allocationPct ?? this.allocationPct,
    reinvest:      reinvest      ?? this.reinvest,
    trailingUp:    trailingUp    ?? this.trailingUp,
    trailingDown:  trailingDown  ?? this.trailingDown,
    tpsl:          tpsl          ?? this.tpsl,
  );
}

class _GridParamsNotifier extends StateNotifier<_GridParams> {
  double _balanceUsdt = 1000.0;
  _GridParamsNotifier() : super(const _GridParams());
  void setBalance(double v) { _balanceUsdt = v; }
  double _step(double v, {double? ref}) {
    // Se v é zero ou muito pequeno, usa ref (upperPrice) como base
    final base = (v > 0.000001) ? v : (ref ?? 1.0);
    if (base >= 10000) return 100;
    if (base >= 1000)  return 10;
    if (base >= 100)   return 1;
    if (base >= 10)    return 0.1;
    if (base >= 1)     return 0.01;
    if (base >= 0.1)   return 0.001;
    if (base >= 0.01)  return 0.0001;
    return 0.00001;
  }
  void adjustUpper(double d) {
    final step = _step(state.upperPrice) * d.sign;
    final newVal = (state.upperPrice + step).clamp(state.lowerPrice + step, 1e8);
    state = state.copyWith(upperPrice: newVal);
  }
  void adjustLower(double d) {
    final step = _step(state.lowerPrice, ref: state.upperPrice) * d.sign;
    final newVal = (state.lowerPrice + step).clamp(0.000001, state.upperPrice - step);
    state = state.copyWith(lowerPrice: newVal);
  }
  void adjustGrids(int d)    => state = state.copyWith(numGrids: (state.numGrids + d).clamp(2, 230));
  void setUpper(double v)    => state = state.copyWith(upperPrice: v.clamp(0, 1e8));
  void setLower(double v)    => state = state.copyWith(lowerPrice: v.clamp(0, 1e8));
  void setAllocationPct(double v) => state = state.copyWith(allocationPct: v, allocatedUsdt: _balanceUsdt * v);
  void setReinvest(bool v)   => state = state.copyWith(reinvest: v);
  void setTrailingUp(bool v) => state = state.copyWith(trailingUp: v);
  void setTrailingDown(bool v) => state = state.copyWith(trailingDown: v);
  void setTpSl(bool v)       => state = state.copyWith(tpsl: v);
  void updateFromPrice(double price) {
    // Ajusta range automaticamente: ±8% do preço atual
    final upper = price * 1.08;
    final lower = price * 0.92;
    state = state.copyWith(upperPrice: upper, lowerPrice: lower, numGrids: 25);
  }
  void setFromIa(double lower, double upper, int grids) => state = state.copyWith(
    lowerPrice: lower, upperPrice: upper, numGrids: grids);
}

// ── Botão Criar Grid ─────────────────────────────────────────────────────────

class _CreateButton extends ConsumerStatefulWidget {
  final String symbol, exchange;
  final _GridParams params;
  const _CreateButton({required this.symbol, required this.exchange, required this.params});
  @override
  ConsumerState<_CreateButton> createState() => _CreateButtonState();
}

class _CreateButtonState extends ConsumerState<_CreateButton> {
  bool _loading = false;

  Future<void> _create(bool modoReal) async {
    setState(() => _loading = true);
    try {
      final prefs    = await SharedPreferences.getInstance();
      final token    = prefs.getString('access_token') ?? '';
      final capital  = widget.params.allocatedUsdt > 0 ? widget.params.allocatedUsdt : 100.0;
      final niveis   = widget.params.numGrids;
      final upper    = widget.params.upperPrice;
      final lower    = widget.params.lowerPrice;
      final exchange = widget.exchange.toLowerCase();

      // 1. Registrar grid no backend
      final payload = {
        'symbol':             widget.symbol,
        'exchange':           exchange,
        'capital_usdt':       capital,
        'niveis':             niveis,
        'limite_superior':    upper,
        'limite_inferior':    lower,
        'espacamento_pct':    widget.params.currentMargin,
        'margem_liquida_pct': widget.params.currentMargin,
        'modo_real':          modoReal,
      };
      final r = await http.post(
        Uri.parse('https://fenixday.info/api/v1/grids'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (r.statusCode != 201) {
        final err = jsonDecode(r.body)['detail'] ?? r.body;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao registrar grid: $err'),
          backgroundColor: FenixColors.red,
        ));
        return;
      }

      // 2. Se modo real, criar ordens na exchange
      if (modoReal) {
        try {
          await _createExchangeOrders(exchange, capital, niveis, upper, lower);
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Grid criado mas erro nas ordens: $e'),
            backgroundColor: FenixColors.orange,
            duration: const Duration(seconds: 5),
          ));
          Navigator.maybePop(context);
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Grid ${widget.symbol} criado${modoReal ? " — ordens enviadas!" : " em modo DEMO"}'),
          backgroundColor: FenixColors.green,
        ));
        Navigator.maybePop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erro: $e'),
        backgroundColor: FenixColors.red,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createExchangeOrders(String exchange, double capital,
      int niveis, double upper, double lower) async {
    const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true));
    final apiKey = await storage.read(key: 'fenix_${exchange}_api_key') ?? '';
    final secret = await storage.read(key: 'fenix_${exchange}_secret')  ?? '';

    if (apiKey.isEmpty || secret.isEmpty) {
      throw Exception('API Key da ${widget.exchange} não configurada. Vá em Configurações → Corretoras.');
    }

    final step         = (upper - lower) / niveis;
    final capitalOrdem = capital / niveis;
    final symbol       = widget.symbol;

    // Buscar preço atual
    double currentPrice = 0;
    if (exchange == 'binance') {
      final rp = await http.get(Uri.parse(
          'https://api.binance.com/api/v3/ticker/price?symbol=$symbol'));
      currentPrice = double.tryParse(jsonDecode(rp.body)['price'].toString()) ?? 0;
    } else if (exchange == 'bybit') {
      final rp = await http.get(Uri.parse(
          'https://api.bybit.com/v5/market/tickers?category=spot&symbol=$symbol'));
      currentPrice = double.tryParse(
          jsonDecode(rp.body)['result']?['list']?[0]?['lastPrice']?.toString() ?? '0') ?? 0;
    }

    if (currentPrice <= 0) throw Exception('Não foi possível obter preço de $symbol');

    final ordensEnviadas = <String>[];
    String lastError = 'desconhecido';
    for (int i = 1; i <= niveis; i++) {
      final price = lower + step * i;
      if (price >= currentPrice) continue;
      final qty = capitalOrdem / price;
      try {
        if (exchange == 'binance') {
          await _binanceOrder(apiKey, secret, symbol, 'BUY', price, qty);
        } else if (exchange == 'bybit') {
          await _bybitOrder(apiKey, secret, symbol, 'Buy', price, qty);
        } else {
          throw Exception('${widget.exchange} não suporta ordens automáticas ainda.');
        }
        ordensEnviadas.add(price.toStringAsFixed(4));
      } catch (e) {
        lastError = e.toString();
      }
    }

    if (ordensEnviadas.isEmpty) {
      throw Exception('Nenhuma ordem enviada. Último erro: $lastError');
    }
  }

  Future<void> _binanceOrder(String apiKey, String secret, String symbol,
      String side, double price, double qty) async {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final int priceDec = price >= 1000 ? 2 : price >= 10 ? 3 : price >= 1 ? 4 : price >= 0.1 ? 5 : price >= 0.01 ? 6 : 8;
    final int qtyDec   = qty >= 100 ? 2 : qty >= 1 ? 4 : 6;
    final priceStr = price.toStringAsFixed(priceDec);
    final qtyStr   = qty.toStringAsFixed(qtyDec);
    final query    = 'symbol=$symbol&side=$side&type=LIMIT&timeInForce=GTC'
        '&quantity=$qtyStr&price=$priceStr&timestamp=$ts';
    final sig = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(query)).toString();
    final r = await http.post(
      Uri.parse('https://api.binance.com/api/v3/order?$query&signature=$sig'),
      headers: {'X-MBX-APIKEY': apiKey},
    ).timeout(const Duration(seconds: 10));
    final body = jsonDecode(r.body);
    if (body['code'] != null && body['code'] != 0) throw Exception('Binance: ${body["msg"]}');
  }

  Future<void> _bybitOrder(String apiKey, String secret, String symbol,
      String side, double price, double qty) async {
    final ts  = DateTime.now().millisecondsSinceEpoch.toString();
    // Precisão do preço baseada no valor (Bybit exige precisão correta)
    final int priceDec = price >= 1000 ? 2 : price >= 10 ? 3 : price >= 1 ? 4 : price >= 0.1 ? 5 : price >= 0.01 ? 6 : 8;
    final int qtyDec   = qty >= 100 ? 2 : qty >= 1 ? 4 : 6;
    final priceStr = price.toStringAsFixed(priceDec);
    final qtyStr   = qty.toStringAsFixed(qtyDec);
    final bodyStr  = jsonEncode({
      'category': 'spot', 'symbol': symbol, 'side': side,
      'orderType': 'Limit', 'qty': qtyStr, 'price': priceStr, 'timeInForce': 'GTC',
    });
    final sign = Hmac(sha256, utf8.encode(secret))
        .convert(utf8.encode('$ts${apiKey}5000$bodyStr')).toString();
    final r = await http.post(
      Uri.parse('https://api.bybit.com/v5/order/create'),
      headers: {
        'X-BAPI-API-KEY': apiKey, 'X-BAPI-TIMESTAMP': ts,
        'X-BAPI-SIGN': sign, 'X-BAPI-RECV-WINDOW': '5000',
        'Content-Type': 'application/json',
      },
      body: bodyStr,
    ).timeout(const Duration(seconds: 10));
    final resp = jsonDecode(r.body);
    debugPrint('BYBIT RESPONSE: \${r.body}');
    if (resp['retCode'] != 0) throw Exception('Bybit: ' + (resp['retMsg'] ?? 'erro desconhecido').toString());
  }

  void _showModeDialog() {

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: FenixColors.card,
        title: const Text('Modo de operação', style: TextStyle(
            fontSize: 15, color: FenixColors.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${widget.symbol} · ${widget.exchange}',
              style: const TextStyle(fontSize: 12, color: FenixColors.textMuted)),
          const SizedBox(height: 4),
          Text(
            'Range: \$${widget.params.lowerPrice.toStringAsFixed(2)} – \$${widget.params.upperPrice.toStringAsFixed(2)}  |  ${widget.params.numGrids} grids',
            style: const TextStyle(fontSize: 11, color: FenixColors.textMuted)),
          const SizedBox(height: 16),
          // Modo Demo
          GestureDetector(
            onTap: () { Navigator.of(dialogCtx).pop(); _create(false); },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: FenixColors.yellowBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FenixColors.yellow.withOpacity(.3)),
              ),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.science_outlined, size: 16, color: FenixColors.yellow),
                  SizedBox(width: 8),
                  Text('Modo Demo (Testnet)', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: FenixColors.yellow)),
                ]),
                SizedBox(height: 4),
                Text('Usa a Testnet da exchange. Sem capital real.',
                    style: TextStyle(fontSize: 11, color: FenixColors.textMuted)),
              ]),
            ),
          ),
          // Modo Real
          GestureDetector(
            onTap: () { Navigator.of(dialogCtx).pop(); _create(true); },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FenixColors.greenBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FenixColors.green.withOpacity(.3)),
              ),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.rocket_launch_outlined, size: 16, color: FenixColors.green),
                  SizedBox(width: 8),
                  Text('Modo Real', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: FenixColors.green)),
                ]),
                SizedBox(height: 4),
                Text('Executa ordens reais na exchange. Requer licença ativa.',
                    style: TextStyle(fontSize: 11, color: FenixColors.textMuted)),
              ]),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: FenixColors.textMuted)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: FenixColors.yellow,
        foregroundColor: const Color(0xFF1A0A00),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 0,
      ),
      onPressed: _loading ? null : _showModeDialog,
      child: _loading
          ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A0A00)))
          : const Text('Criar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    ),
  );
}

// ── Mock de candles ───────────────────────────────────────────────────────────
List<CandleData> _generateMockCandles() {
  double price = 66800;
  return List.generate(80, (i) {
    final seed   = (DateTime.now().millisecondsSinceEpoch + i * 1234567) % 1000;
    final change = (seed / 1000 - 0.5) * 400;
    final open   = price;
    final close  = price + change;
    final high   = [open, close].reduce((a, b) => a > b ? a : b) + seed % 120;
    final low    = [open, close].reduce((a, b) => a < b ? a : b) - seed % 100;
    price = close;
    return CandleData(
      time: DateTime.now().subtract(Duration(hours: 80 - i)),
      open: open, high: high, low: low, close: close,
      volume: 500 + seed * 20.0,
    );
  });
}
