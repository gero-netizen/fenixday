/// FênixDay — Tela do Scanner de IA
///
/// Exibe o ranking Top 20 de pares selecionados pelo scanner:
///   • Score 0–100 (ponderado por ADX, ATR, Bollinger, MM200)
///   • ADX com badge colorido (verde < 15 / amarelo < 20 / vermelho ≥ 20)
///   • ATR% e volume 24h
///   • Botão "Alocar" abre GridConfigScreen com par pré-preenchido
///   • Badge de timestamp da última varredura
///   • Botão para forçar re-varredura

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../theme/fenix_theme.dart';

// ── Modelo ────────────────────────────────────────────────────────────────────

class ScannerEntry {
  final int    rank;
  final String symbol;
  final double score;
  final double adx;
  final double atrPct;
  final double bbWidth;
  final double mm200Slope;
  final double volume24h;

  const ScannerEntry({
    required this.rank,
    required this.symbol,
    required this.score,
    required this.adx,
    required this.atrPct,
    required this.bbWidth,
    required this.mm200Slope,
    required this.volume24h,
  });

  String get volumeLabel {
    if (volume24h >= 1e9) return '\$${(volume24h / 1e9).toStringAsFixed(2)}B';
    if (volume24h >= 1e6) return '\$${(volume24h / 1e6).toStringAsFixed(1)}M';
    return '\$${volume24h.toStringAsFixed(0)}';
  }
}

// ── Provider (mock — trocar por chamada API em produção) ──────────────────────

final _scannerLoadingProvider = StateProvider<bool>((ref) => false);

final _scannerLastUpdateProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

final _scannerResultsProvider = Provider<List<ScannerEntry>>((ref) => const [
  ScannerEntry(rank:1,  symbol:'BNB/USDT',  score:89, adx:12.1, atrPct:0.71, bbWidth:0.82, mm200Slope:0.3, volume24h:98800000),
  ScannerEntry(rank:2,  symbol:'XRP/USDT',  score:87, adx:14.8, atrPct:0.88, bbWidth:0.91, mm200Slope:0.4, volume24h:177700000),
  ScannerEntry(rank:3,  symbol:'DOGE/USDT', score:85, adx:13.5, atrPct:0.93, bbWidth:0.88, mm200Slope:0.5, volume24h:100300000),
  ScannerEntry(rank:4,  symbol:'ADA/USDT',  score:82, adx:16.2, atrPct:0.76, bbWidth:0.79, mm200Slope:0.6, volume24h:44200000),
  ScannerEntry(rank:5,  symbol:'LINK/USDT', score:80, adx:17.1, atrPct:0.82, bbWidth:0.85, mm200Slope:0.7, volume24h:46900000),
  ScannerEntry(rank:6,  symbol:'AVAX/USDT', score:79, adx:15.6, atrPct:0.88, bbWidth:0.94, mm200Slope:0.8, volume24h:64700000),
  ScannerEntry(rank:7,  symbol:'SUI/USDT',  score:77, adx:14.3, atrPct:0.97, bbWidth:1.02, mm200Slope:1.1, volume24h:38300000),
  ScannerEntry(rank:8,  symbol:'PEPE/USDT', score:76, adx:13.9, atrPct:1.05, bbWidth:1.08, mm200Slope:0.9, volume24h:53400000),
  ScannerEntry(rank:9,  symbol:'ZEC/USDT',  score:76, adx:11.8, atrPct:0.69, bbWidth:0.77, mm200Slope:0.4, volume24h:171700000),
  ScannerEntry(rank:10, symbol:'TAO/USDT',  score:75, adx:16.8, atrPct:0.94, bbWidth:0.98, mm200Slope:1.2, volume24h:123200000),
  ScannerEntry(rank:11, symbol:'ETH/USDT',  score:74, adx:18.4, atrPct:0.72, bbWidth:0.81, mm200Slope:1.4, volume24h:1010000000),
  ScannerEntry(rank:12, symbol:'SOL/USDT',  score:72, adx:19.1, atrPct:0.94, bbWidth:0.99, mm200Slope:1.6, volume24h:365200000),
  ScannerEntry(rank:13, symbol:'PAXG/USDT', score:71, adx:10.2, atrPct:0.48, bbWidth:0.52, mm200Slope:0.2, volume24h:51700000),
  ScannerEntry(rank:14, symbol:'MATIC/USDT',score:70, adx:12.3, atrPct:0.70, bbWidth:0.80, mm200Slope:0.3, volume24h:48700000),
  ScannerEntry(rank:15, symbol:'BTC/USDT',  score:68, adx:20.1, atrPct:0.65, bbWidth:0.74, mm200Slope:1.8, volume24h:1700000000),
  ScannerEntry(rank:16, symbol:'XAUT/USDT', score:68, adx:10.5, atrPct:0.46, bbWidth:0.51, mm200Slope:0.2, volume24h:41400000),
  ScannerEntry(rank:17, symbol:'JOE/USDT',  score:65, adx:14.2, atrPct:1.18, bbWidth:1.15, mm200Slope:1.9, volume24h:28400000),
  ScannerEntry(rank:18, symbol:'FTM/USDT',  score:64, adx:16.0, atrPct:0.92, bbWidth:0.95, mm200Slope:1.4, volume24h:32100000),
  ScannerEntry(rank:19, symbol:'CHZ/USDT',  score:63, adx:15.5, atrPct:0.85, bbWidth:0.91, mm200Slope:1.1, volume24h:27600000),
  ScannerEntry(rank:20, symbol:'SAND/USDT', score:61, adx:14.8, atrPct:0.99, bbWidth:1.04, mm200Slope:1.3, volume24h:35200000),
]);

// ── Tela ──────────────────────────────────────────────────────────────────────

class ScannerScreen extends ConsumerWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries   = ref.watch(_scannerResultsProvider);
    final isLoading = ref.watch(_scannerLoadingProvider);
    final lastUpdate = ref.watch(_scannerLastUpdateProvider);
    final fmt = DateFormat('HH:mm:ss');

    return Scaffold(
      backgroundColor: FenixColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────
            Container(
              color: FenixColors.surface,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Scanner de IA',
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: FenixColors.textPrimary)),
                  Row(children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                          color: FenixColors.green, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text('Atualizado às ${fmt.format(lastUpdate)}',
                        style: const TextStyle(fontSize: 9,
                            color: FenixColors.textMuted)),
                  ]),
                ]),
                const Spacer(),
                // Botão re-varrer
                GestureDetector(
                  onTap: isLoading ? null : () => _rescan(ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: FenixColors.yellowBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: FenixColors.yellow.withOpacity(.4), width: .5),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: FenixColors.yellow))
                        : const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.refresh, size: 14,
                                color: FenixColors.yellow),
                            SizedBox(width: 4),
                            Text('Varrer',
                                style: TextStyle(fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: FenixColors.yellow)),
                          ]),
                  ),
                ),
              ]),
            ),

            // ── Cabeçalho da tabela ────────────────────────────────────
            Container(
              color: FenixColors.card2,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              child: Row(children: const [
                SizedBox(width: 24, child: Text('#',
                    style: TextStyle(fontSize: 9, color: FenixColors.textMuted))),
                Expanded(child: Text('Par',
                    style: TextStyle(fontSize: 9, color: FenixColors.textMuted))),
                SizedBox(width: 50, child: Text('ADX',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: FenixColors.textMuted))),
                SizedBox(width: 44, child: Text('ATR%',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 9, color: FenixColors.textMuted))),
                SizedBox(width: 40, child: Text('Score',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 9, color: FenixColors.textMuted))),
                SizedBox(width: 56),   // coluna do botão Alocar
              ]),
            ),

            // ── Lista ──────────────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(
                    height: 0, thickness: .5, color: FenixColors.border),
                itemBuilder: (_, i) => _ScannerRow(entry: entries[i]),
              ),
            ),

            // ── Rodapé explicativo ─────────────────────────────────────
            Container(
              color: FenixColors.surface,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              child: const Text(
                'Score calculado com ADX 35% · ATR 25% · Bollinger 20% · MM200 10% · Volume 10%',
                style: TextStyle(fontSize: 9,
                    color: FenixColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rescan(WidgetRef ref) async {
    ref.read(_scannerLoadingProvider.notifier).state = true;
    await Future.delayed(const Duration(seconds: 2)); // TODO: chamada API real
    ref.read(_scannerLastUpdateProvider.notifier).state = DateTime.now();
    ref.read(_scannerLoadingProvider.notifier).state = false;
  }
}

// ── Linha da tabela ───────────────────────────────────────────────────────────

class _ScannerRow extends StatelessWidget {
  final ScannerEntry entry;
  const _ScannerRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isTop3 = entry.rank <= 3;
    final rankColor = isTop3 ? FenixColors.yellow : FenixColors.textMuted;

    return InkWell(
      onTap: () => _showDetail(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          // Rank
          SizedBox(
            width: 24,
            child: Text('${entry.rank}',
                style: TextStyle(fontFamily: 'RobotoMono',
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: rankColor)),
          ),

          // Par + volume
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.symbol,
                  style: const TextStyle(fontFamily: 'RobotoMono',
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: FenixColors.textPrimary)),
              Text(entry.volumeLabel,
                  style: const TextStyle(
                      fontSize: 9, color: FenixColors.textMuted)),
            ]),
          ),

          // ADX badge
          SizedBox(
            width: 50,
            child: Center(child: _AdxBadge(adx: entry.adx)),
          ),

          // ATR%
          SizedBox(
            width: 44,
            child: Text('${entry.atrPct.toStringAsFixed(2)}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontFamily: 'RobotoMono', fontSize: 11,
                    color: entry.atrPct >= 0.5 && entry.atrPct <= 1.2
                        ? FenixColors.purple
                        : FenixColors.textMuted)),
          ),

          // Score
          SizedBox(
            width: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${entry.score}',
                    style: TextStyle(
                        fontFamily: 'RobotoMono', fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _scoreColor(entry.score))),
                Container(
                  height: 4,
                  width: 32,
                  decoration: BoxDecoration(
                    color: FenixColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: entry.score / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _scoreColor(entry.score),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Botão Alocar
          const SizedBox(width: 6),
          SizedBox(
            width: 50,
            child: GestureDetector(
              onTap: () => context.go('/grids/config'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: FenixColors.yellowBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: FenixColors.yellow.withOpacity(.3), width: .5),
                ),
                child: const Text('Alocar',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: FenixColors.yellow)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Color _scoreColor(double s) {
    if (s >= 85) return FenixColors.green;
    if (s >= 75) return FenixColors.yellow;
    if (s >= 65) return FenixColors.orange;
    return FenixColors.red;
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FenixColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _DetailSheet(entry: entry),
    );
  }
}

// ── Badge ADX ─────────────────────────────────────────────────────────────────

class _AdxBadge extends StatelessWidget {
  final double adx;
  const _AdxBadge({required this.adx});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = adx < 15
        ? (FenixColors.green,  FenixColors.greenBg)
        : adx < 20
            ? (FenixColors.yellow, FenixColors.yellowBg)
            : (FenixColors.red,    FenixColors.redBg);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
      child: Text(adx.toStringAsFixed(1),
          style: TextStyle(fontFamily: 'RobotoMono',
              fontSize: 10, fontWeight: FontWeight.w500, color: color)),
    );
  }
}

// ── Bottom sheet de detalhe ───────────────────────────────────────────────────

class _DetailSheet extends StatelessWidget {
  final ScannerEntry entry;
  const _DetailSheet({required this.entry});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('ADX',         entry.adx.toStringAsFixed(1),           '< 22 = lateral'),
      ('ATR %',       '${entry.atrPct.toStringAsFixed(2)}%',  '0,5%–1,2% ideal'),
      ('BB largura',  entry.bbWidth.toStringAsFixed(2),        'faixa relativa'),
      ('MM200 slope', '${entry.mm200Slope.toStringAsFixed(1)}°', '≈ 0° = plano'),
      ('Volume 24h',  entry.volumeLabel,                       'liquidez'),
    ];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text(entry.symbol,
                style: const TextStyle(fontFamily: 'RobotoMono',
                    fontSize: 16, fontWeight: FontWeight.w500,
                    color: FenixColors.textPrimary)),
            const Spacer(),
            Text('Score ${entry.score}',
                style: TextStyle(fontFamily: 'RobotoMono',
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: entry.score >= 85
                        ? FenixColors.green
                        : FenixColors.yellow)),
          ]),
          const SizedBox(height: 14),
          ...metrics.map((m) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Text(m.$1, style: const TextStyle(
                  fontSize: 11, color: FenixColors.textMuted)),
              const Spacer(),
              Text(m.$2, style: const TextStyle(fontFamily: 'RobotoMono',
                  fontSize: 12, fontWeight: FontWeight.w500,
                  color: FenixColors.textPrimary)),
              const SizedBox(width: 8),
              Text('(${m.$3})', style: const TextStyle(
                  fontSize: 10, color: FenixColors.textMuted)),
            ]),
          )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/grids/config');
              },
              child: Text('Alocar grid em ${entry.symbol}'),
            ),
          ),
        ],
      ),
    );
  }
}
