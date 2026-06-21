/// FênixDay — Scanner de IA v4
/// Funil: Volume > 20M → Blacklist → ADX < 25 → MA200 slope < 1.5% → ATR > 0.15%
/// Margem líquida alvo: 0,35%–0,48% por ciclo

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/fenix_theme.dart';

// ── Blacklist ─────────────────────────────────────────────────────────────────

const _blacklist = {
  'USDC', 'BUSD', 'DAI', 'FDUSD', 'TUSD', 'USDP', 'USDE',
  'EUR', 'GBP', 'BRZ', 'XAUT', 'PAXG', 'USD1', 'USDM',
  'AEUR', 'BFUSD', 'LDUSDT', 'SUSDT', 'WBTC', 'WETH',
};

// ── Modelos ───────────────────────────────────────────────────────────────────

class GridConfig {
  final double espacamentoPct;
  final double margemLiquidaPct;
  final int niveis;
  final double limiteSuperior;
  final double limiteInferior;
  final List<double> ordensCompra;
  final List<double> ordensVenda;

  const GridConfig({
    required this.espacamentoPct,
    required this.margemLiquidaPct,
    required this.niveis,
    required this.limiteSuperior,
    required this.limiteInferior,
    required this.ordensCompra,
    required this.ordensVenda,
  });
}

class ScannerPair {
  final String symbol;
  final double price;
  final double priceChange24h;
  final double volume24h;
  final double atrPct;
  final double adx;
  final double ma200slope;
  final double bbUpper;
  final double bbLower;
  final String grade;
  final GridConfig grid;

  const ScannerPair({
    required this.symbol,
    required this.price,
    required this.priceChange24h,
    required this.volume24h,
    required this.atrPct,
    required this.adx,
    required this.ma200slope,
    required this.bbUpper,
    required this.bbLower,
    required this.grade,
    required this.grid,
  });
}

// ── Serviço ───────────────────────────────────────────────────────────────────

class _ScannerService {
  static const _base = 'https://api.binance.com';

  Future<List<Map<String, dynamic>>> _fetchTickers() async {
    final r = await http.get(Uri.parse('$_base/api/v3/ticker/24hr'))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('Erro ao buscar tickers');
    final List data = jsonDecode(r.body);
    return data.where((t) {
      final sym  = t['symbol'].toString();
      final base = sym.replaceAll('USDT', '');
      final vol  = double.tryParse(t['quoteVolume'].toString()) ?? 0;
      return sym.endsWith('USDT') &&
          !sym.contains('DOWN') && !sym.contains('UP') &&
          !sym.contains('BEAR') && !sym.contains('BULL') &&
          !_blacklist.contains(base) &&
          vol >= 20000000;
    }).map((t) => t as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>?> _analyzeSymbol(String symbol) async {
    try {
      final r = await http.get(
        Uri.parse('$_base/api/v3/klines?symbol=$symbol&interval=1h&limit=300'),
      ).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final List klines = jsonDecode(r.body);
      if (klines.length < 220) return null;

      final highs  = klines.map((k) => double.tryParse(k[2].toString()) ?? 0.0).toList();
      final lows   = klines.map((k) => double.tryParse(k[3].toString()) ?? 0.0).toList();
      final closes = klines.map((k) => double.tryParse(k[4].toString()) ?? 0.0).toList();
      final n      = closes.length;
      final price  = closes.last;
      if (price <= 0) return null;

      // ── ATR 14 ──────────────────────────────────────────────────
      double atrSum = 0;
      for (int i = n - 14; i < n; i++) {
        final tr = [
          highs[i] - lows[i],
          (highs[i] - closes[i - 1]).abs(),
          (lows[i]  - closes[i - 1]).abs(),
        ].reduce(max);
        atrSum += tr;
      }
      final atr    = atrSum / 14;
      final atrPct = (atr / price) * 100;

      // Filtro ATR mínimo 0,15%
      if (atrPct < 0.15) return null;

      // ── ADX 14 ──────────────────────────────────────────────────
      final List<double> trList = [], dmP = [], dmM = [];
      for (int i = 1; i < n; i++) {
        final tr = [
          highs[i] - lows[i],
          (highs[i] - closes[i - 1]).abs(),
          (lows[i]  - closes[i - 1]).abs(),
        ].reduce(max);
        trList.add(tr);
        final up   = highs[i] - highs[i - 1];
        final down = lows[i - 1] - lows[i];
        dmP.add(up > down && up > 0 ? up : 0);
        dmM.add(down > up && down > 0 ? down : 0);
      }
      double smTr = trList.take(14).reduce((a, b) => a + b);
      double smP  = dmP.take(14).reduce((a, b) => a + b);
      double smM  = dmM.take(14).reduce((a, b) => a + b);
      final List<double> dxList = [];
      for (int i = 14; i < trList.length; i++) {
        smTr = smTr - smTr / 14 + trList[i];
        smP  = smP  - smP  / 14 + dmP[i];
        smM  = smM  - smM  / 14 + dmM[i];
        if (smTr == 0) continue;
        final diP = (smP / smTr) * 100;
        final diM = (smM / smTr) * 100;
        final sum = diP + diM;
        if (sum == 0) continue;
        dxList.add(((diP - diM).abs() / sum) * 100);
      }
      final adx = dxList.length >= 14
          ? dxList.skip(dxList.length - 14).reduce((a, b) => a + b) / 14
          : 50.0;

      // Filtro ADX < 25 (relaxado de 22 para pegar mais moedas)
      if (adx >= 25) return null;

      // ── MA200 slope ──────────────────────────────────────────────
      if (n < 220) return null;
      final ma200a = closes.skip(n - 200).take(200).reduce((a, b) => a + b) / 200;
      final ma200b = closes.skip(n - 220).take(200).reduce((a, b) => a + b) / 200;
      final slope  = ma200b > 0 ? ((ma200a - ma200b) / ma200b * 100).abs() : 0.0;

      // Filtro MA200 horizontal — relaxado para 1,5%
      if (slope > 1.5) return null;

      // ── Bandas de Bollinger 20,2 ─────────────────────────────────
      final bb20   = closes.skip(n - 20).take(20).toList();
      final bbMa   = bb20.reduce((a, b) => a + b) / 20;
      final bbVar  = bb20.map((c) => pow(c - bbMa, 2)).reduce((a, b) => a + b) / 20;
      final bbStd  = sqrt(bbVar.toDouble());
      final bbUpper = bbMa + 2 * bbStd;
      final bbLower = bbMa - 2 * bbStd;

      return {
        'atr': atr, 'atrPct': atrPct, 'adx': adx,
        'slope': slope, 'bbUpper': bbUpper, 'bbLower': bbLower,
      };
    } catch (_) { return null; }
  }

  GridConfig _calcGrid({
    required double price,
    required double bbUpper,
    required double bbLower,
    required double atrPct,
  }) {
    double espacBruto;
    if (atrPct > 0.8)      { espacBruto = 0.68; }
    else if (atrPct < 0.4) { espacBruto = 0.55; }
    else                   { espacBruto = 0.60; }

    final margemLiquida = espacBruto - 0.20;
    final amplitudePct  = price > 0 ? ((bbUpper - bbLower) / price) * 100 : 0.0;
    int niveis          = amplitudePct > 0 ? (amplitudePct / espacBruto).floor() : 10;
    niveis              = niveis.clamp(10, 40);

    final passo = (bbUpper - bbLower) / niveis;
    final compras = <double>[], vendas = <double>[];
    for (int i = 1; i <= niveis ~/ 2; i++) {
      final c = price - i * passo;
      if (c >= bbLower) compras.add(double.parse(c.toStringAsFixed(6)));
      final v = price + i * passo;
      if (v <= bbUpper) vendas.add(double.parse(v.toStringAsFixed(6)));
    }

    return GridConfig(
      espacamentoPct:   espacBruto,
      margemLiquidaPct: margemLiquida,
      niveis:           niveis,
      limiteSuperior:   bbUpper,
      limiteInferior:   bbLower,
      ordensCompra:     compras,
      ordensVenda:      vendas,
    );
  }

  String _grade(double atrPct, double adx, double slope) {
    if (atrPct >= 0.4 && adx < 15 && slope < 0.5) return 'A+';
    if (atrPct >= 0.3 && adx < 20) return 'A';
    if (atrPct >= 0.2 && adx < 25) return 'B';
    return 'C';
  }

  Future<List<ScannerPair>> scan() async {
    final tickers = await _fetchTickers();
    tickers.sort((a, b) {
      final va = double.tryParse(a['quoteVolume'].toString()) ?? 0;
      final vb = double.tryParse(b['quoteVolume'].toString()) ?? 0;
      return vb.compareTo(va);
    });

    // Analisa os top 100 por volume
    final top100 = tickers.take(100).toList();
    final pairs  = <ScannerPair>[];

    for (int i = 0; i < top100.length; i += 5) {
      final batch   = top100.skip(i).take(5).toList();
      final results = await Future.wait(
        batch.map((t) => _analyzeSymbol(t['symbol'].toString())),
      );
      for (int j = 0; j < batch.length; j++) {
        final analysis = results[j];
        if (analysis == null) continue;
        final t      = batch[j];
        final sym    = t['symbol'].toString();
        final price  = double.tryParse(t['lastPrice'].toString()) ?? 0;
        final vol    = double.tryParse(t['quoteVolume'].toString()) ?? 0;
        final chg    = double.tryParse(t['priceChangePercent'].toString()) ?? 0;
        final atrPct = (analysis['atrPct'] as num).toDouble();
        final adx    = (analysis['adx'] as num).toDouble();
        final slope  = (analysis['slope'] as num).toDouble();
        final bbU    = (analysis['bbUpper'] as num).toDouble();
        final bbL    = (analysis['bbLower'] as num).toDouble();
        final grid   = _calcGrid(price: price, bbUpper: bbU, bbLower: bbL, atrPct: atrPct);
        pairs.add(ScannerPair(
          symbol: sym, price: price, priceChange24h: chg,
          volume24h: vol, atrPct: atrPct, adx: adx,
          ma200slope: slope, bbUpper: bbU, bbLower: bbL,
          grade: _grade(atrPct, adx, slope), grid: grid,
        ));
      }
      if (pairs.length >= 20) break; // para quando tiver 20
    }

    pairs.sort((a, b) => b.atrPct.compareTo(a.atrPct));
    return pairs.take(20).toList();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

class _ScannerNotifier extends StateNotifier<AsyncValue<List<ScannerPair>>> {
  final _service = _ScannerService();
  _ScannerNotifier() : super(const AsyncValue.loading()) { scan(); }
  Future<void> scan() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _service.scan());
    } catch (e, st) { state = AsyncValue.error(e, st); }
  }
}

final _scannerProvider =
    StateNotifierProvider<_ScannerNotifier, AsyncValue<List<ScannerPair>>>(
  (ref) => _ScannerNotifier(),
);

// ── Tela ──────────────────────────────────────────────────────────────────────

class ScannerScreen extends ConsumerWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scannerAsync = ref.watch(_scannerProvider);

    return Scaffold(
      backgroundColor: FenixColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Row(children: [
                const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Scanner de IA',
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: FenixColors.textPrimary)),
                    SizedBox(height: 2),
                    Text('Top 20 altcoins · Margem 0,35%–0,48%/ciclo',
                        style: TextStyle(fontSize: 10,
                            color: FenixColors.textMuted)),
                  ],
                )),
                scannerAsync.when(
                  loading: () => const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: FenixColors.yellow)),
                  error: (_, __) => IconButton(
                    icon: const Icon(Icons.refresh, color: FenixColors.yellow),
                    onPressed: () => ref.read(_scannerProvider.notifier).scan(),
                  ),
                  data: (_) => IconButton(
                    icon: const Icon(Icons.refresh,
                        color: FenixColors.yellow, size: 20),
                    onPressed: () => ref.read(_scannerProvider.notifier).scan(),
                  ),
                ),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Wrap(spacing: 5, runSpacing: 5, children: const [
                _FilterChip(label: 'Vol > \$20M',  color: FenixColors.blue),
                _FilterChip(label: 'Sem stable',   color: FenixColors.red),
                _FilterChip(label: 'ADX < 25',     color: FenixColors.green),
                _FilterChip(label: 'MA200 flat',   color: FenixColors.purple),
                _FilterChip(label: 'ATR > 0,15%', color: FenixColors.yellow),
              ]),
            ),

            Expanded(
              child: scannerAsync.when(
                loading: () => const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(color: FenixColors.yellow),
                    SizedBox(height: 16),
                    Text('Varrendo 100 altcoins...',
                        style: TextStyle(fontSize: 12,
                            color: FenixColors.textMuted)),
                    SizedBox(height: 4),
                    Text('Vol → Blacklist → ADX → MA200 → ATR',
                        style: TextStyle(fontFamily: 'RobotoMono',
                            fontSize: 9, color: FenixColors.textMuted)),
                  ]),
                ),
                error: (e, _) => Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.wifi_off_outlined,
                        size: 32, color: FenixColors.textMuted),
                    const SizedBox(height: 12),
                    Text(e.toString(), textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11,
                            color: FenixColors.textMuted)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FenixColors.yellow,
                        foregroundColor: const Color(0xFF1A0A00),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Tentar novamente'),
                      onPressed: () =>
                          ref.read(_scannerProvider.notifier).scan(),
                    ),
                  ]),
                ),
                data: (pairs) => pairs.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nenhuma altcoin passou nos filtros.\n'
                            'Tente novamente em alguns minutos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12,
                                color: FenixColors.textMuted, height: 1.5),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(_scannerProvider.notifier).scan(),
                        color: FenixColors.yellow,
                        child: ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(14, 0, 14, 24),
                          itemCount: pairs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (ctx, i) =>
                              _PairCard(pair: pairs[i], rank: i + 1),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _PairCard extends StatefulWidget {
  final ScannerPair pair;
  final int rank;
  const _PairCard({required this.pair, required this.rank});
  @override
  State<_PairCard> createState() => _PairCardState();
}

class _PairCardState extends State<_PairCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p          = widget.pair;
    final gradeColor = _gradeColor(p.grade);
    final isUp       = p.priceChange24h >= 0;
    final priceColor = isUp ? FenixColors.green : FenixColors.red;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FenixColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.rank <= 3
              ? gradeColor.withOpacity(.5)
              : FenixColors.border,
          width: widget.rank <= 3 ? 1 : .5,
        ),
      ),
      child: Column(children: [
        // ── Linha 1: rank + symbol + grade + margem ────────────────
        Row(children: [
          SizedBox(
            width: 28,
            child: Text('#${widget.rank}',
                style: TextStyle(fontFamily: 'RobotoMono',
                    fontSize: widget.rank <= 3 ? 13 : 11,
                    fontWeight: widget.rank <= 3
                        ? FontWeight.w700 : FontWeight.w400,
                    color: widget.rank <= 3
                        ? gradeColor : FenixColors.textMuted)),
          ),
          Expanded(
            child: Text(p.symbol.replaceAll('USDT', '/USDT'),
                style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: FenixColors.textPrimary)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: gradeColor.withOpacity(.15),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: gradeColor.withOpacity(.4), width: .5),
            ),
            child: Text(p.grade,
                style: TextStyle(fontFamily: 'RobotoMono',
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: gradeColor)),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: FenixColors.greenBg,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text('+${p.grid.margemLiquidaPct.toStringAsFixed(2)}%',
                style: const TextStyle(fontFamily: 'RobotoMono',
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: FenixColors.green)),
          ),
        ]),
        const SizedBox(height: 8),

        // ── Métricas ───────────────────────────────────────────────
        Row(children: [
          _Metrica(label: 'Preço',
              value: '\$${_fmtPrice(p.price)}',
              sub: '${isUp ? '+' : ''}${p.priceChange24h.toStringAsFixed(2)}%',
              subColor: priceColor),
          _Metrica(label: 'ADX',
              value: p.adx.toStringAsFixed(1),
              sub: p.adx < 15 ? 'muito flat' : 'flat ✓',
              subColor: FenixColors.green),
          _Metrica(label: 'ATR%',
              value: '${p.atrPct.toStringAsFixed(2)}%',
              sub: _atrLabel(p.atrPct),
              subColor: _atrColor(p.atrPct)),
          _Metrica(label: 'Vol 24h',
              value: _fmtVolume(p.volume24h),
              sub: 'USDT',
              subColor: FenixColors.blue),
        ]),
        const SizedBox(height: 8),

        // ── Range BB ───────────────────────────────────────────────
        Row(children: [
          Text('\$${_fmtPrice(p.bbLower)}',
              style: const TextStyle(fontFamily: 'RobotoMono',
                  fontSize: 9, color: FenixColors.textMuted)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: p.bbUpper > p.bbLower
                      ? ((p.price - p.bbLower) / (p.bbUpper - p.bbLower))
                          .clamp(0.0, 1.0)
                      : 0.5,
                  minHeight: 4,
                  backgroundColor: FenixColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
                ),
              ),
            ),
          ),
          Text('\$${_fmtPrice(p.bbUpper)}',
              style: const TextStyle(fontFamily: 'RobotoMono',
                  fontSize: 9, color: FenixColors.textMuted)),
        ]),
        const SizedBox(height: 10),

        // ── Botões ─────────────────────────────────────────────────
        Row(children: [
          // Expandir/recolher detalhes
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: FenixColors.textMuted,
                side: const BorderSide(color: FenixColors.border, width: .5),
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  size: 14),
              label: Text(_expanded ? 'Recolher' : 'Detalhes',
                  style: const TextStyle(fontSize: 11)),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
          ),
          const SizedBox(width: 8),
          // Botão configurar grid
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: gradeColor,
                foregroundColor: const Color(0xFF1A0A00),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.grid_view, size: 14),
              label: const Text('Configurar Grid',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              onPressed: () => _showGridConfig(context, p),
            ),
          ),
        ]),

        // ── Detalhes expandidos ────────────────────────────────────
        if (_expanded) ...[
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: .5, color: FenixColors.border),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _DetalheItem(
                label: 'MA200 slope',
                value: '${p.ma200slope.toStringAsFixed(3)}%',
                ok: p.ma200slope < 0.5)),
            Expanded(child: _DetalheItem(
                label: 'BB Superior',
                value: '\$${_fmtPrice(p.bbUpper)}',
                ok: true)),
            Expanded(child: _DetalheItem(
                label: 'BB Inferior',
                value: '\$${_fmtPrice(p.bbLower)}',
                ok: true)),
          ]),
        ],
      ]),
    );
  }

  void _showGridConfig(BuildContext context, ScannerPair p) async {
    // Salvar params nas prefs para GridConfig ler no initState
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('grid_init_symbol',   p.symbol);
    await prefs.setString('grid_init_exchange',  'Binance');
    await prefs.setDouble('grid_init_upper',     p.bbUpper);
    await prefs.setDouble('grid_init_lower',     p.bbLower);
    await prefs.setInt   ('grid_init_grids',     p.grid.niveis);
    // Passar saldo total de todas as exchanges
    final balance = prefs.getDouble('cached_total_usdt') ?? 0.0;
    await prefs.setDouble('grid_init_balance', balance);
    if (context.mounted) context.push('/grids/config');
  }

  Color _gradeColor(String grade) => switch (grade) {
    'A+' => FenixColors.yellow,
    'A'  => FenixColors.green,
    'B'  => FenixColors.blue,
    _    => FenixColors.textMuted,
  };

  Color _atrColor(double v) {
    if (v >= 0.4) return FenixColors.green;
    if (v >= 0.2) return FenixColors.yellow;
    return FenixColors.textMuted;
  }

  String _atrLabel(double v) {
    if (v >= 0.8) return 'explosivo';
    if (v >= 0.4) return 'ideal ✓';
    if (v >= 0.2) return 'moderado';
    return 'baixo';
  }

  String _fmtPrice(double p) {
    if (p >= 1000) return NumberFormat('#,##0.00', 'pt_BR').format(p);
    if (p >= 1)    return p.toStringAsFixed(4);
    if (p >= 0.01) return p.toStringAsFixed(5);
    return p.toStringAsFixed(6);
  }

  String _fmtVolume(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    return '${(v / 1e3).toStringAsFixed(0)}K';
  }
}

// ── Bottom Sheet: Configuração do Grid ───────────────────────────────────────

class _GridConfigSheet extends StatefulWidget {
  final ScannerPair pair;
  const _GridConfigSheet({required this.pair});
  @override
  State<_GridConfigSheet> createState() => _GridConfigSheetState();
}

class _GridConfigSheetState extends State<_GridConfigSheet> {
  late double _capital;
  late int    _niveis;
  late double _limSup;
  late double _limInf;

  final _capitalCtrl = TextEditingController(text: '500');

  @override
  void initState() {
    super.initState();
    _capital = 500;
    _niveis  = widget.pair.grid.niveis;
    _limSup  = widget.pair.grid.limiteSuperior;
    _limInf  = widget.pair.grid.limiteInferior;
  }

  @override
  void dispose() {
    _capitalCtrl.dispose();
    super.dispose();
  }

  double get _ordemSize => _niveis > 0 ? _capital / _niveis : 0;
  double get _lucroEstimado => _ordemSize * (widget.pair.grid.margemLiquidaPct / 100);
  double get _lucroMensal => _lucroEstimado * 8 * 30; // ~8 ciclos/dia

  @override
  Widget build(BuildContext context) {
    final p          = widget.pair;
    final gradeColor = _gradeColor(p.grade);
    final fmt        = NumberFormat('#,##0.00', 'pt_BR');

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => SingleChildScrollView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: FenixColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            )),

            // Título
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: gradeColor.withOpacity(.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(p.grade,
                    style: TextStyle(fontFamily: 'RobotoMono',
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: gradeColor)),
              ),
              const SizedBox(width: 10),
              Text(p.symbol.replaceAll('USDT', '/USDT'),
                  style: const TextStyle(fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: FenixColors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: FenixColors.greenBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('+${p.grid.margemLiquidaPct.toStringAsFixed(2)}%/ciclo',
                    style: const TextStyle(fontFamily: 'RobotoMono',
                        fontSize: 11, color: FenixColors.green,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 16),

            // Capital
            const Text('Capital a investir (USDT)',
                style: TextStyle(fontSize: 12, color: FenixColors.textMuted)),
            const SizedBox(height: 6),
            TextField(
              controller: _capitalCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontFamily: 'RobotoMono',
                  fontSize: 14, color: FenixColors.textPrimary),
              decoration: InputDecoration(
                prefixText: '\$ ',
                prefixStyle: const TextStyle(color: FenixColors.yellow),
                suffixText: 'USDT',
                suffixStyle: const TextStyle(
                    fontSize: 11, color: FenixColors.textMuted),
              ),
              onChanged: (v) =>
                  setState(() => _capital = double.tryParse(v) ?? 500),
            ),
            const SizedBox(height: 16),

            // Nº de níveis
            Row(children: [
              const Text('Nº de ordens',
                  style: TextStyle(fontSize: 12, color: FenixColors.textMuted)),
              const Spacer(),
              Text('$_niveis níveis',
                  style: const TextStyle(fontFamily: 'RobotoMono',
                      fontSize: 13, fontWeight: FontWeight.w500,
                      color: FenixColors.yellow)),
            ]),
            Slider(
              value: _niveis.toDouble(),
              min: 10, max: 40, divisions: 30,
              activeColor: FenixColors.yellow,
              inactiveColor: FenixColors.border,
              label: '$_niveis',
              onChanged: (v) => setState(() => _niveis = v.round()),
            ),
            const SizedBox(height: 8),

            // Canal do grid
            const Text('Canal do Grid (Bandas de Bollinger)',
                style: TextStyle(fontSize: 12, color: FenixColors.textMuted)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FenixColors.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FenixColors.border, width: .5),
              ),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Limite inferior',
                          style: TextStyle(fontSize: 9,
                              color: FenixColors.textMuted)),
                      Text('\$${_fmtPrice(_limInf)}',
                          style: const TextStyle(fontFamily: 'RobotoMono',
                              fontSize: 13, color: FenixColors.red)),
                    ],
                  )),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Preço atual',
                          style: TextStyle(fontSize: 9,
                              color: FenixColors.textMuted)),
                      Text('\$${_fmtPrice(p.price)}',
                          style: const TextStyle(fontFamily: 'RobotoMono',
                              fontSize: 13, color: FenixColors.yellow)),
                    ],
                  )),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Limite superior',
                          style: TextStyle(fontSize: 9,
                              color: FenixColors.textMuted)),
                      Text('\$${_fmtPrice(_limSup)}',
                          style: const TextStyle(fontFamily: 'RobotoMono',
                              fontSize: 13, color: FenixColors.green)),
                    ],
                  )),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: _limSup > _limInf
                        ? ((p.price - _limInf) / (_limSup - _limInf))
                            .clamp(0.0, 1.0)
                        : 0.5,
                    minHeight: 6,
                    backgroundColor: FenixColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        FenixColors.yellow),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Resumo financeiro
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FenixColors.greenBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: FenixColors.green.withOpacity(.3), width: .5),
              ),
              child: Column(children: [
                const Row(children: [
                  Icon(Icons.analytics_outlined,
                      size: 14, color: FenixColors.green),
                  SizedBox(width: 6),
                  Text('Projeção de lucro',
                      style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: FenixColors.green)),
                ]),
                const SizedBox(height: 10),
                _ResumoRow('Capital total', '\$${fmt.format(_capital)}'),
                _ResumoRow('Por ordem',
                    '\$${fmt.format(_ordemSize)} (~${_niveis} ordens)'),
                _ResumoRow('Espaçamento bruto',
                    '${p.grid.espacamentoPct.toStringAsFixed(2)}%'),
                _ResumoRow('Margem líquida/ciclo',
                    '+${p.grid.margemLiquidaPct.toStringAsFixed(2)}%'),
                _ResumoRow('Lucro estimado/ciclo',
                    '+\$${fmt.format(_lucroEstimado)}'),
                const Divider(color: FenixColors.green, height: 16),
                _ResumoRow('Projeção mensal (~8 ciclos/dia)',
                    '+\$${fmt.format(_lucroMensal)}',
                    highlight: true),
              ]),
            ),
            const SizedBox(height: 16),

            // Botão iniciar grid
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FenixColors.yellow,
                  foregroundColor: const Color(0xFF1A0A00),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.rocket_launch_outlined, size: 18),
                label: const Text('Iniciar Grid com este par',
                    style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w700)),
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Grid para ${p.symbol.replaceAll('USDT', '/USDT')} configurado! '
                        'Funcionalidade de execução em breve.',
                      ),
                      backgroundColor: FenixColors.green,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _gradeColor(String grade) => switch (grade) {
    'A+' => FenixColors.yellow,
    'A'  => FenixColors.green,
    'B'  => FenixColors.blue,
    _    => FenixColors.textMuted,
  };

  String _fmtPrice(double p) {
    if (p >= 1000) return NumberFormat('#,##0.00', 'pt_BR').format(p);
    if (p >= 1)    return p.toStringAsFixed(4);
    if (p >= 0.01) return p.toStringAsFixed(5);
    return p.toStringAsFixed(6);
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _Metrica extends StatelessWidget {
  final String label, value, sub;
  final Color subColor;
  const _Metrica({required this.label, required this.value,
      required this.sub, required this.subColor});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 9, color: FenixColors.textMuted)),
      Text(value,
          style: const TextStyle(fontFamily: 'RobotoMono',
              fontSize: 11, color: FenixColors.textPrimary)),
      Text(sub, style: TextStyle(fontSize: 8, color: subColor)),
    ]),
  );
}

class _DetalheItem extends StatelessWidget {
  final String label, value;
  final bool ok;
  const _DetalheItem({required this.label, required this.value,
      required this.ok});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(fontSize: 9, color: FenixColors.textMuted)),
      Row(children: [
        Icon(ok ? Icons.check_circle_outline : Icons.warning_amber_outlined,
            size: 11,
            color: ok ? FenixColors.green : FenixColors.orange),
        const SizedBox(width: 3),
        Text(value,
            style: const TextStyle(fontFamily: 'RobotoMono',
                fontSize: 10, color: FenixColors.textSecondary)),
      ]),
    ],
  );
}

class _ResumoRow extends StatelessWidget {
  final String label, value;
  final bool highlight;
  const _ResumoRow(this.label, this.value, {this.highlight = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(label,
          style: TextStyle(
              fontSize: highlight ? 12 : 10,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
              color: FenixColors.textMuted))),
      Text(value,
          style: TextStyle(fontFamily: 'RobotoMono',
              fontSize: highlight ? 13 : 11,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              color: highlight ? FenixColors.green : FenixColors.textPrimary)),
    ]),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  const _FilterChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(.1),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withOpacity(.3), width: .5),
    ),
    child: Text(label,
        style: TextStyle(fontSize: 9, color: color,
            fontWeight: FontWeight.w500)),
  );
}
