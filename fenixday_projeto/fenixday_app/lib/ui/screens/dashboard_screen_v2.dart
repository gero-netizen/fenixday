/// FênixDay — Dashboard P&L v2 (dados reais da Binance)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/fenix_theme.dart';
import 'services/binance_service.dart';

const _baseUrl = 'https://fenixday.info/api/v1';

// ── Provider de usuário ───────────────────────────────────────────────────────

class _UserInfo {
  final String email;
  final bool isActive;
  final bool isSuperuser;
  final bool realModeAllowed;
  const _UserInfo({
    required this.email,
    required this.isActive,
    required this.isSuperuser,
    this.realModeAllowed = false,
  });
}

class _UserNotifier extends StateNotifier<AsyncValue<_UserInfo>> {
  _UserNotifier() : super(const AsyncValue.loading()) { load(); }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) {
        state = AsyncValue.error('Não autenticado', StackTrace.current);
        return;
      }
      final meRes  = await http.get(Uri.parse('$_baseUrl/auth/me'),
          headers: {'Authorization': 'Bearer $token'});
      final subRes = await http.get(Uri.parse('$_baseUrl/subscriptions/status'),
          headers: {'Authorization': 'Bearer $token'});
      if (meRes.statusCode == 200) {
        final me = jsonDecode(meRes.body);
        bool realMode = false;
        if (subRes.statusCode == 200) {
          realMode = jsonDecode(subRes.body)['real_mode_allowed'] == true;
        }
        state = AsyncValue.data(_UserInfo(
          email: me['email'] ?? '',
          isActive: me['is_active'] == true,
          isSuperuser: me['is_superuser'] == true,
          realModeAllowed: realMode,
        ));
      } else {
        state = AsyncValue.error('Erro', StackTrace.current);
      }
    } catch (e, st) { state = AsyncValue.error(e, st); }
  }
}

final _userProvider = StateNotifierProvider<_UserNotifier, AsyncValue<_UserInfo>>(
  (ref) => _UserNotifier(),
);

// ── Provider Binance ──────────────────────────────────────────────────────────

class _BinanceNotifier extends StateNotifier<AsyncValue<BinanceDashboardData>> {
  final _service = BinanceService();
  _BinanceNotifier() : super(const AsyncValue.loading()) { fetch(); }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final data = await _service.fetchDashboardData();
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final _binanceProvider =
    StateNotifierProvider<_BinanceNotifier, AsyncValue<BinanceDashboardData>>(
  (ref) => _BinanceNotifier(),
);

// ── Tela ──────────────────────────────────────────────────────────────────────

class DashboardScreenV2 extends ConsumerWidget {
  const DashboardScreenV2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync    = ref.watch(_userProvider);
    final binanceAsync = ref.watch(_binanceProvider);
    final now = DateFormat('dd/MM/yyyy · HH:mm:ss').format(DateTime.now());

    return Scaffold(
      backgroundColor: FenixColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.read(_binanceProvider.notifier).fetch();
            ref.read(_userProvider.notifier).load();
          },
          color: FenixColors.yellow,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Cabeçalho ──────────────────────────────────────────
                Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Performance & P&L',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500,
                              color: FenixColors.textPrimary)),
                      const SizedBox(height: 2),
                      userAsync.when(
                        data: (u) => Text(u.email,
                            style: const TextStyle(fontFamily: 'RobotoMono',
                                fontSize: 10, color: FenixColors.textMuted)),
                        loading: () => const SizedBox(width: 100, height: 10,
                            child: LinearProgressIndicator(color: FenixColors.yellow, minHeight: 2)),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 2),
                      Text(now, style: const TextStyle(fontFamily: 'RobotoMono',
                          fontSize: 10, color: FenixColors.textMuted)),
                    ],
                  )),
                  userAsync.when(
                    data: (u) => _ModeBadge(realMode: u.realModeAllowed),
                    loading: () => const SizedBox(width: 80, height: 26,
                        child: Center(child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: FenixColors.yellow))),
                    error: (_, __) => const _ModeBadge(realMode: false),
                  ),
                ]),
                const SizedBox(height: 14),

                // ── Conteúdo Binance ────────────────────────────────────
                binanceAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(children: [
                        CircularProgressIndicator(color: FenixColors.yellow),
                        SizedBox(height: 16),
                        Text('Buscando dados da Binance...',
                            style: TextStyle(fontSize: 12, color: FenixColors.textMuted)),
                      ]),
                    ),
                  ),
                  error: (e, _) => _ErrorCard(message: e.toString(),
                      onRetry: () => ref.read(_binanceProvider.notifier).fetch()),
                  data: (data) => data.error != null
                      ? _ErrorCard(message: data.error!,
                          onRetry: () => ref.read(_binanceProvider.notifier).fetch())
                      : _DashboardContent(data: data),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Conteúdo do dashboard ─────────────────────────────────────────────────────

class _DashboardContent extends StatelessWidget {
  final BinanceDashboardData data;
  const _DashboardContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'pt_BR');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Badge testnet
        if (data.isTestnet)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: FenixColors.orangeBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: FenixColors.orange.withOpacity(.3), width: .5),
            ),
            child: const Row(children: [
              Icon(Icons.science_outlined, size: 13, color: FenixColors.orange),
              SizedBox(width: 6),
              Text('TESTNET — dados simulados',
                  style: TextStyle(fontSize: 11, color: FenixColors.orange,
                      fontWeight: FontWeight.w500)),
            ]),
          ),

        // ── 1. PATRIMÔNIO TOTAL ──────────────────────────────────────
        _SectionTitle('Patrimônio total em operação'),
        const SizedBox(height: 6),
        _PatrimonioCard(data: data),
        const SizedBox(height: 14),

        // ── 2. P&L HOJE ─────────────────────────────────────────────
        _SectionTitle('Lucro de grid — ciclos fechados hoje'),
        const SizedBox(height: 6),
        _PnlHojeCard(data: data),
        const SizedBox(height: 14),

        // ── 3. SALDOS POR ATIVO ─────────────────────────────────────
        _SectionTitle('Saldos por ativo'),
        const SizedBox(height: 6),
        _BalancesCard(data: data),
        const SizedBox(height: 14),

        // ── 4. ORDENS RECENTES ───────────────────────────────────────
        _SectionTitle('Ordens recentes'),
        const SizedBox(height: 6),
        _OrdensCard(data: data),
        const SizedBox(height: 8),

        // Última atualização
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          const Icon(Icons.update, size: 11, color: FenixColors.textMuted),
          const SizedBox(width: 4),
          Text(
            'Atualizado: ${DateFormat('HH:mm:ss').format(data.fetchedAt)}',
            style: const TextStyle(fontFamily: 'RobotoMono',
                fontSize: 9, color: FenixColors.textMuted),
          ),
        ]),
      ],
    );
  }
}

// ── 1. Patrimônio ─────────────────────────────────────────────────────────────

class _PatrimonioCard extends StatelessWidget {
  final BinanceDashboardData data;
  const _PatrimonioCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'pt_BR');
    final usdtBalance = data.balances
        .where((b) => b.asset == 'USDT')
        .fold(0.0, (s, b) => s + b.total);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(topColor: FenixColors.yellow),
      child: Column(children: [
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Patrimônio total (Binance)',
                  style: TextStyle(fontSize: 10, color: FenixColors.textMuted)),
              const SizedBox(height: 3),
              Text('\$${fmt.format(data.totalUsdtValue)}',
                  style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 24,
                      fontWeight: FontWeight.w500, color: FenixColors.yellow)),
            ],
          )),
          const Icon(Icons.account_balance_wallet_outlined,
              size: 28, color: FenixColors.yellow),
        ]),
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: .5, color: FenixColors.border),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _PatrimonioItem(
            label: 'USDT disponível',
            value: '\$${fmt.format(usdtBalance)}',
            icon: Icons.attach_money,
            color: FenixColors.green,
            sub: 'saldo livre',
          )),
          Container(width: .5, height: 40, color: FenixColors.border),
          Expanded(child: _PatrimonioItem(
            label: 'Em ativos',
            value: '\$${fmt.format(data.totalUsdtValue - usdtBalance)}',
            icon: Icons.currency_bitcoin,
            color: FenixColors.yellow,
            sub: 'valor atual',
          )),
          Container(width: .5, height: 40, color: FenixColors.border),
          Expanded(child: _PatrimonioItem(
            label: 'P&L hoje',
            value: '${data.realizedPnlHoje >= 0 ? '+' : ''}\$${fmt.format(data.realizedPnlHoje)}',
            icon: data.realizedPnlHoje >= 0 ? Icons.trending_up : Icons.trending_down,
            color: data.realizedPnlHoje >= 0 ? FenixColors.green : FenixColors.red,
            sub: '${data.ciclosFechadosHoje} ciclos',
          )),
        ]),
      ]),
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
        Flexible(child: Text(label,
            style: const TextStyle(fontSize: 9, color: FenixColors.textMuted))),
      ]),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(fontFamily: 'RobotoMono', fontSize: 12,
          fontWeight: FontWeight.w500, color: color)),
      Text(sub, style: const TextStyle(fontSize: 9, color: FenixColors.textMuted)),
    ]),
  );
}

// ── 2. P&L Hoje ──────────────────────────────────────────────────────────────

class _PnlHojeCard extends StatelessWidget {
  final BinanceDashboardData data;
  const _PnlHojeCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final fmt   = NumberFormat('#,##0.00', 'pt_BR');
    final color = data.realizedPnlHoje >= 0 ? FenixColors.green : FenixColors.red;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(topColor: color),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${data.realizedPnlHoje >= 0 ? '+' : ''}\$${fmt.format(data.realizedPnlHoje)}',
                style: TextStyle(fontFamily: 'RobotoMono', fontSize: 22,
                    fontWeight: FontWeight.w500, color: color)),
            const SizedBox(height: 4),
            Text('${data.ciclosFechadosHoje} ciclos fechados hoje',
                style: const TextStyle(fontSize: 11, color: FenixColors.textMuted)),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            Icon(data.realizedPnlHoje >= 0 ? Icons.trending_up : Icons.trending_down,
                color: color, size: 24),
            const SizedBox(height: 4),
            Text(data.realizedPnlHoje >= 0 ? 'LUCRO' : 'PERDA',
                style: TextStyle(fontFamily: 'RobotoMono', fontSize: 9,
                    fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      ]),
    );
  }
}

// ── 3. Saldos ─────────────────────────────────────────────────────────────────

class _BalancesCard extends StatelessWidget {
  final BinanceDashboardData data;
  const _BalancesCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00000', 'pt_BR');
    final fmtUsdt = NumberFormat('#,##0.00', 'pt_BR');

    // Ordena por valor em USDT
    final balances = [...data.balances];
    balances.sort((a, b) {
      final aUsdt = a.asset == 'USDT' ? a.total : (data.prices['${a.asset}USDT'] ?? 0) * a.total;
      final bUsdt = b.asset == 'USDT' ? b.total : (data.prices['${b.asset}USDT'] ?? 0) * b.total;
      return bUsdt.compareTo(aUsdt);
    });

    if (balances.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDeco(),
        child: const Text('Nenhum saldo encontrado',
            style: TextStyle(fontSize: 12, color: FenixColors.textMuted)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(children: [
        for (int i = 0; i < balances.length; i++) ...[
          _BalanceRow(
            balance: balances[i],
            usdtValue: balances[i].asset == 'USDT'
                ? balances[i].total
                : (data.prices['${balances[i].asset}USDT'] ?? 0) * balances[i].total,
            totalUsdt: data.totalUsdtValue,
            fmt: fmt,
            fmtUsdt: fmtUsdt,
          ),
          if (i < balances.length - 1)
            const Divider(height: 12, thickness: .5, color: FenixColors.border),
        ],
      ]),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final BinanceBalance balance;
  final double usdtValue;
  final double totalUsdt;
  final NumberFormat fmt;
  final NumberFormat fmtUsdt;

  const _BalanceRow({
    required this.balance,
    required this.usdtValue,
    required this.totalUsdt,
    required this.fmt,
    required this.fmtUsdt,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalUsdt > 0 ? usdtValue / totalUsdt : 0.0;

    return Row(children: [
      // Ativo
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: FenixColors.yellowBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(child: Text(balance.asset[0],
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: FenixColors.yellow))),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(balance.asset,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                    color: FenixColors.textPrimary)),
            const Spacer(),
            Text('\$${fmtUsdt.format(usdtValue)}',
                style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 12,
                    fontWeight: FontWeight.w500, color: FenixColors.textPrimary)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: FenixColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(FenixColors.yellow),
              ),
            )),
            const SizedBox(width: 8),
            Text('${(pct * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontFamily: 'RobotoMono',
                    fontSize: 9, color: FenixColors.textMuted)),
          ]),
          const SizedBox(height: 2),
          Text('${fmt.format(balance.total)} ${balance.asset}',
              style: const TextStyle(fontFamily: 'RobotoMono',
                  fontSize: 9, color: FenixColors.textMuted)),
        ],
      )),
    ]);
  }
}

// ── 4. Ordens recentes ────────────────────────────────────────────────────────

class _OrdensCard extends StatelessWidget {
  final BinanceDashboardData data;
  const _OrdensCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'pt_BR');

    if (data.recentOrders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDeco(),
        child: const Text('Nenhuma ordem recente',
            style: TextStyle(fontSize: 12, color: FenixColors.textMuted)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(children: [
        for (int i = 0; i < data.recentOrders.take(10).length; i++) ...[
          _OrdemRow(order: data.recentOrders[i], fmt: fmt),
          if (i < data.recentOrders.length - 1 && i < 9)
            const Divider(height: 12, thickness: .5, color: FenixColors.border),
        ],
      ]),
    );
  }
}

class _OrdemRow extends StatelessWidget {
  final BinanceOrder order;
  final NumberFormat fmt;
  const _OrdemRow({required this.order, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final isSell  = order.side == 'SELL';
    final color   = isSell ? FenixColors.green : FenixColors.blue;
    final timeStr = DateFormat('HH:mm:ss').format(order.time);

    return Row(children: [
      Expanded(flex: 2, child: Row(children: [
        Text(order.symbol,
            style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 11,
                fontWeight: FontWeight.w500, color: FenixColors.textPrimary)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: color.withOpacity(.15),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(isSell ? 'venda' : 'compra',
              style: TextStyle(fontSize: 8, color: color)),
        ),
      ])),
      Expanded(child: Text('\$${fmt.format(order.price)}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'RobotoMono',
              fontSize: 10, color: FenixColors.textSecondary))),
      Expanded(child: Text(fmt.format(order.executedQty),
          textAlign: TextAlign.right,
          style: const TextStyle(fontFamily: 'RobotoMono',
              fontSize: 10, color: FenixColors.textSecondary))),
      const SizedBox(width: 8),
      Text(timeStr,
          style: const TextStyle(fontFamily: 'RobotoMono',
              fontSize: 9, color: FenixColors.textMuted)),
    ]);
  }
}

// ── Error card ────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: FenixColors.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: FenixColors.border, width: .5),
    ),
    child: Column(children: [
      const Icon(Icons.wifi_off_outlined, size: 32, color: FenixColors.textMuted),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: FenixColors.textMuted, height: 1.4)),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: FenixColors.yellow,
          foregroundColor: const Color(0xFF1A0A00),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Tentar novamente'),
        onPressed: onRetry,
      ),
    ]),
  );
}

// ── Badge modo ────────────────────────────────────────────────────────────────

class _ModeBadge extends StatelessWidget {
  final bool realMode;
  const _ModeBadge({required this.realMode});

  @override
  Widget build(BuildContext context) {
    final color   = realMode ? FenixColors.green : FenixColors.orange;
    final colorBg = realMode ? FenixColors.greenBg : FenixColors.orangeBg;
    final label   = realMode ? 'MODO REAL' : 'MODO DEMO';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorBg, borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(.3), width: .5),
      ),
      child: Row(children: [
        Icon(Icons.circle, size: 7, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontFamily: 'RobotoMono',
            fontSize: 9, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

BoxDecoration _cardDeco({Color? topColor}) => BoxDecoration(
  color: FenixColors.card,
  borderRadius: topColor != null
      ? const BorderRadius.only(
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
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
          color: FenixColors.textMuted, letterSpacing: .3));
}
