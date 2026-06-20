/// FênixDay — Dashboard P&L v3
/// • Abas por exchange (Total | Binance | Bybit)
/// • Badge modo real/demo funcional com toggle
/// • Saldo separado por corretora

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/fenix_theme.dart';
import 'shared_providers.dart';
import 'services/exchange_service.dart';

const _baseUrl = 'https://fenixday.info/api/v1';

// ── Provider de usuário ───────────────────────────────────────────────────────

class _UserInfo {
  final String email;
  final bool realModeAllowed;
  const _UserInfo({required this.email, required this.realModeAllowed});
}

class _UserNotifier extends StateNotifier<AsyncValue<_UserInfo>> {
  _UserNotifier() : super(const AsyncValue.loading()) { load(); }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) { state = AsyncValue.error('Não autenticado', StackTrace.current); return; }
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

// ── Provider Exchange ─────────────────────────────────────────────────────────

class _ExchangeNotifier extends StateNotifier<AsyncValue<ExchangeDashboardData>> {
  final _service = ExchangeService();
  _ExchangeNotifier() : super(const AsyncValue.loading()) { fetch(); }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final data = await _service.fetchAll();
      // Salvar saldo por exchange nas prefs para o grid config usar
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('cached_total_usdt', data.totalUsdtValue);
      for (final entry in data.snapshots.entries) {
        await prefs.setDouble('cached_usdt_${entry.key.toLowerCase()}', entry.value.totalUsdt);
      }
      state = AsyncValue.data(data);
    } catch (e, st) { state = AsyncValue.error(e, st); }
  }
}

final _exchangeProvider =
    StateNotifierProvider<_ExchangeNotifier, AsyncValue<ExchangeDashboardData>>(
  (ref) => _ExchangeNotifier(),
);

// ── Tela ──────────────────────────────────────────────────────────────────────


// ── Provider resumo grids ─────────────────────────────────────────────────────
class _GridSummary {
  final double totalCapital, totalLucro;
  final int totalCiclos, gridsAtivos;
  final List<Map<String, dynamic>> grids;
  const _GridSummary({required this.totalCapital, required this.totalLucro,
      required this.totalCiclos, required this.gridsAtivos, required this.grids});
  static _GridSummary empty() => const _GridSummary(
      totalCapital:0, totalLucro:0, totalCiclos:0, gridsAtivos:0, grids:[]);
}
class _GridSummaryNotifier extends StateNotifier<AsyncValue<_GridSummary>> {
  _GridSummaryNotifier() : super(const AsyncValue.loading()) { fetch(); }
  Future<void> fetch({bool? modoReal}) async {
    state = const AsyncValue.loading();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final modo = modoReal ?? (prefs.getBool('fenix_modo_real') ?? true);
      final r = await http.get(
        Uri.parse('https://fenixday.info/api/v1/grids/summary?modo_real=$modo'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        state = AsyncValue.data(_GridSummary(
          totalCapital: (d['total_capital'] as num).toDouble(),
          totalLucro:   (d['total_lucro']   as num).toDouble(),
          totalCiclos:  d['total_ciclos']  as int,
          gridsAtivos:  d['grids_ativos']  as int,
          grids: List<Map<String,dynamic>>.from(d['grids'] ?? []),
        ));
      } else { state = AsyncValue.data(_GridSummary.empty()); }
    } catch (e,st) { state = AsyncValue.error(e,st); }
  }
}
final _gridSummaryProvider =
    StateNotifierProvider<_GridSummaryNotifier, AsyncValue<_GridSummary>>(
  (ref) => _GridSummaryNotifier());

class DashboardScreenV2 extends ConsumerStatefulWidget {
  const DashboardScreenV2({super.key});

  @override
  ConsumerState<DashboardScreenV2> createState() => _DashboardScreenV2State();
}

class _DashboardScreenV2State extends ConsumerState<DashboardScreenV2>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _tabs = ['Total', 'Binance', 'Bybit'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override

  void _updateTabController(int count) {
    if (count != _tabController.length) {
      final oldIndex = _tabController.index;
      _tabController.dispose();
      _tabController = TabController(
        length: count,
        vsync: this,
        initialIndex: oldIndex.clamp(0, count - 1),
      );
      setState(() {});
    }
  }

  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync     = ref.watch(_userProvider);
    final exchangeAsync = ref.watch(_exchangeProvider);
    final modoReal      = ref.watch(modoRealProvider);
    final now = DateFormat('dd/MM/yyyy · HH:mm:ss').format(DateTime.now());

    return Scaffold(
      backgroundColor: FenixColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.read(_exchangeProvider.notifier).fetch();
            ref.read(_gridSummaryProvider.notifier).fetch();
            ref.read(_userProvider.notifier).load();
          },
          color: FenixColors.yellow,
          child: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Cabeçalho ────────────────────────────────────
                      Row(children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Performance & P&L',
                                style: TextStyle(fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: FenixColors.textPrimary)),
                            const SizedBox(height: 2),
                            userAsync.when(
                              data: (u) => Text(u.email,
                                  style: const TextStyle(
                                      fontFamily: 'RobotoMono',
                                      fontSize: 10,
                                      color: FenixColors.textMuted)),
                              loading: () => const SizedBox(
                                  width: 100, height: 10,
                                  child: LinearProgressIndicator(
                                      color: FenixColors.yellow,
                                      minHeight: 2)),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 2),
                            Text(now,
                                style: const TextStyle(
                                    fontFamily: 'RobotoMono',
                                    fontSize: 10,
                                    color: FenixColors.textMuted)),
                          ],
                        )),
                        // Badge modo real/demo — clicável
                        GestureDetector(
                          onTap: () async {
                            await ref.read(modoRealProvider.notifier).toggle();
                            final novoModo = ref.read(modoRealProvider);
                            ref.read(_gridSummaryProvider.notifier).fetch(modoReal: novoModo);
                          },
                          child: _ModeBadge(realMode: modoReal),
                        ),
                      ]),
                      const SizedBox(height: 12),

                      // ── Abas de exchange ─────────────────────────────
                      exchangeAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (data) {
                          // Monta as abas disponíveis
                          final availableTabs = ['Total'];
                          if (modoReal) {
                            for (final ex in data.activeExchanges) {
                              availableTabs.add(ex);
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Exchange badges/tabs
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(children: [
                                  for (int i = 0; i < availableTabs.length; i++)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: _ExchangeTab(
                                        name: availableTabs[i],
                                        isSelected: _tabController.index == i,
                                        onTap: () => setState(() =>
                                            _tabController.animateTo(i)),
                                        snapshot: availableTabs[i] != 'Total'
                                            ? data.snapshots[availableTabs[i]]
                                            : null,
                                        totalUsdt: availableTabs[i] == 'Total'
                                            ? data.totalUsdtValue
                                            : null,
                                      ),
                                    ),
                                ]),
                              ),
                              const SizedBox(height: 12),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
            body: exchangeAsync.when(
              loading: () => const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(color: FenixColors.yellow),
                  SizedBox(height: 16),
                  Text('Buscando dados das exchanges...',
                      style: TextStyle(fontSize: 12,
                          color: FenixColors.textMuted)),
                ]),
              ),
              error: (e, _) => _ErrorCard(
                message: e.toString(),
                onRetry: () => ref.read(_exchangeProvider.notifier).fetch(),
              ),
              data: (data) {
                final availableTabs = modoReal
                    ? ['Total', ...data.activeExchanges]
                    : ['Total'];
                // Sincroniza controller antes do build para evitar mismatch
                if (_tabController.length != availableTabs.length) {
                  final oldIndex = _tabController.index;
                  _tabController.dispose();
                  _tabController = TabController(
                    length: availableTabs.length,
                    vsync: this,
                    initialIndex: oldIndex.clamp(0, availableTabs.length - 1),
                  );
                }
                return TabBarView(
                  controller: _tabController,
                  children: availableTabs.map((tab) {
                    if (tab == 'Total') {
                      return _TabContent(
                        data: data,
                        exchangeFilter: null,
                        modoReal: modoReal,
                        onRetry: () =>
                            ref.read(_exchangeProvider.notifier).fetch(),
                      );
                    } else {
                      return _TabContent(
                        data: data,
                        exchangeFilter: tab,
                        modoReal: modoReal,
                        onRetry: () =>
                            ref.read(_exchangeProvider.notifier).fetch(),
                      );
                    }
                  }).toList(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tab de exchange ───────────────────────────────────────────────────────────

class _ExchangeTab extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;
  final ExchangeSnapshot? snapshot;
  final double? totalUsdt;

  const _ExchangeTab({
    required this.name,
    required this.isSelected,
    required this.onTap,
    this.snapshot,
    this.totalUsdt,
  });

  @override
  Widget build(BuildContext context) {
    final color   = _color(name);
    final fmt     = NumberFormat('#,##0.00', 'pt_BR');
    final usdtVal = snapshot?.totalUsdt ?? totalUsdt ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(.15) : FenixColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : FenixColors.border,
            width: isSelected ? 1 : .5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (isSelected)
                Icon(Icons.check_circle, size: 10, color: color)
              else
                Icon(Icons.circle_outlined, size: 10, color: FenixColors.textMuted),
              const SizedBox(width: 5),
              Text(name,
                  style: TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : FenixColors.textMuted)),
            ]),
            const SizedBox(height: 2),
            Text('\$${fmt.format(usdtVal)}',
                style: TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? color : FenixColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Color _color(String name) => switch (name) {
    'Binance' => FenixColors.yellow,
    'Bybit'   => FenixColors.orange,
    _         => FenixColors.green,
  };
}

// ── Conteúdo de cada aba ──────────────────────────────────────────────────────

class _TabContent extends ConsumerWidget {
  final ExchangeDashboardData data;
  final String? exchangeFilter; // null = Total
  final bool modoReal;
  final VoidCallback onRetry;

  const _TabContent({
    required this.data,
    required this.exchangeFilter,
    required this.modoReal,
    required this.onRetry,
  });

  List<ExchangeBalance> get _balances => exchangeFilter == null
      ? data.balances
      : data.balances.where((b) => b.exchange == exchangeFilter).toList();

  List<ExchangeOrder> get _orders => exchangeFilter == null
      ? data.recentOrders
      : data.recentOrders.where((o) => o.exchange == exchangeFilter).toList();

  double get _totalUsdt => exchangeFilter == null
      ? data.totalUsdtValue
      : data.snapshots[exchangeFilter]?.totalUsdt ?? 0;

  Map<String, double> get _prices => exchangeFilter == null
      ? data.prices
      : data.snapshots[exchangeFilter]?.prices ?? {};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt              = NumberFormat('#,##0.00', 'pt_BR');
    final gridSummaryAsync = ref.watch(_gridSummaryProvider);
    final usdtBal = _balances
        .where((b) => b.asset == 'USDT')
        .fold(0.0, (s, b) => s + b.total);
    final assetsVal = _totalUsdt - usdtBal;
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(_exchangeProvider.notifier).fetch();
        ref.read(_gridSummaryProvider.notifier).fetch();
        ref.read(_userProvider.notifier).load();
      },
      color: const Color(0xFFF7931A),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
        children: [
          if (!modoReal) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: FenixColors.orangeBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FenixColors.orange.withOpacity(.3), width: .5),
              ),
              child: const Row(children: [
                Icon(Icons.science_outlined, size: 14, color: FenixColors.orange),
                SizedBox(width: 8),
                Expanded(child: Text('MODO DEMO — resultados simulados dos grids',
                    style: TextStyle(fontSize: 11, color: FenixColors.orange))),
              ]),
            ),
            gridSummaryAsync.when(
              loading: () => const Center(child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: FenixColors.yellow, strokeWidth: 2))),
              error: (_, __) => const SizedBox.shrink(),
              data: (gs) => gs.gridsAtivos == 0
                  ? const SizedBox.shrink()
                  : Column(children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: FenixColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: FenixColors.orange, width: 1),
                        ),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Simulação — Grids ativos', style: TextStyle(fontSize: 10, color: FenixColors.textMuted)),
                            const SizedBox(height: 4),
                            Text('\$${fmt.format(gs.totalCapital)}', style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 22, fontWeight: FontWeight.w500, color: FenixColors.yellow)),
                            Text('capital em ${gs.gridsAtivos} grids', style: const TextStyle(fontSize: 10, color: FenixColors.textMuted)),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('+\$${fmt.format(gs.totalLucro)}', style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 18, fontWeight: FontWeight.w600, color: FenixColors.green)),
                            Text('${gs.totalCiclos} ciclos', style: const TextStyle(fontSize: 10, color: FenixColors.textMuted)),
                          ]),
                        ]),
                      ),
                      ...gs.grids.map((g) {
                        final sym    = (g['symbol'] as String).replaceAll('USDT', '/USDT');
                        final cap    = (g['capital'] as num).toDouble();
                        final lucro  = (g['lucro_realizado'] as num).toDouble();
                        final ciclos = g['ciclos_fechados'] as int;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(color: FenixColors.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: FenixColors.border, width: .5)),
                          child: Row(children: [
                            Container(width: 32, height: 32,
                                decoration: BoxDecoration(color: FenixColors.yellowBg,
                                    borderRadius: BorderRadius.circular(6)),
                                child: Center(child: Text(sym.substring(0, 1),
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: FenixColors.yellow)))),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(sym, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: FenixColors.textPrimary)),
                              Text('\$${fmt.format(cap)} capital', style: const TextStyle(fontSize: 10, color: FenixColors.textMuted)),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('+\$${fmt.format(lucro)}', style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 13, fontWeight: FontWeight.w600, color: FenixColors.green)),
                              Text('$ciclos ciclos', style: const TextStyle(fontSize: 10, color: FenixColors.textMuted)),
                            ]),
                          ]),
                        );
                      }).toList(),
                    ]),
            ),
          ],
          if (modoReal) ...[
            for (final entry in data.errors.entries)
              if (entry.value != null && (exchangeFilter == null || entry.key == exchangeFilter))
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FenixColors.redBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: FenixColors.red.withOpacity(.3), width: .5),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_outlined, size: 13, color: FenixColors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${entry.key}: ${entry.value}',
                        style: const TextStyle(fontSize: 10, color: FenixColors.red))),
                  ]),
                ),
            if (_totalUsdt > 0) _SectionTitle('Patrimônio total em operação'),
            if (_totalUsdt > 0) const SizedBox(height: 6),
            if (_totalUsdt > 0) Container(
              padding: const EdgeInsets.all(14),
              decoration: _cardDeco(topColor: FenixColors.yellow),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      exchangeFilter != null
                          ? 'Patrimônio ($exchangeFilter)'
                          : 'Patrimônio total (${data.activeExchanges.join(' + ')})',
                      style: const TextStyle(fontSize: 10, color: FenixColors.textMuted),
                    ),
                    const SizedBox(height: 3),
                    Text('\$${fmt.format(_totalUsdt)}',
                        style: const TextStyle(fontFamily: 'RobotoMono',
                            fontSize: 24, fontWeight: FontWeight.w500, color: FenixColors.yellow)),
                  ])),
                  const Icon(Icons.account_balance_wallet_outlined, size: 28, color: FenixColors.yellow),
                ]),
                const SizedBox(height: 12),
                const Divider(height: 1, thickness: .5, color: FenixColors.border),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _Item(label: 'USDT disponível', value: '\$${fmt.format(usdtBal)}',
                      icon: Icons.attach_money, color: FenixColors.green, sub: 'saldo livre')),
                  Container(width: .5, height: 40, color: FenixColors.border),
                  Expanded(child: _Item(label: 'Em ativos', value: '\$${fmt.format(assetsVal)}',
                      icon: Icons.currency_bitcoin, color: FenixColors.yellow, sub: 'valor atual')),
                  Container(width: .5, height: 40, color: FenixColors.border),
                  Expanded(child: _Item(
                    label: 'P&L hoje',
                    value: '${data.realizedPnlHoje >= 0 ? '+' : ''}\$${fmt.format(data.realizedPnlHoje)}',
                    icon: data.realizedPnlHoje >= 0 ? Icons.trending_up : Icons.trending_down,
                    color: data.realizedPnlHoje >= 0 ? FenixColors.green : FenixColors.red,
                    sub: '${data.ciclosFechadosHoje} ciclos',
                  )),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            if (data.ciclosFechadosHoje > 0) _SectionTitle('Lucro de grid — ciclos fechados hoje'),
            if (data.ciclosFechadosHoje > 0) const SizedBox(height: 6),
            if (data.ciclosFechadosHoje > 0) Container(
              padding: const EdgeInsets.all(14),
              decoration: _cardDeco(topColor: data.realizedPnlHoje >= 0 ? FenixColors.green : FenixColors.red),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    '${data.realizedPnlHoje >= 0 ? '+' : ''}\$${fmt.format(data.realizedPnlHoje)}',
                    style: TextStyle(fontFamily: 'RobotoMono', fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: data.realizedPnlHoje >= 0 ? FenixColors.green : FenixColors.red),
                  ),
                  const SizedBox(height: 4),
                  Text('${data.ciclosFechadosHoje} ciclos fechados hoje',
                      style: const TextStyle(fontSize: 11, color: FenixColors.textMuted)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (data.realizedPnlHoje >= 0 ? FenixColors.green : FenixColors.red).withOpacity(.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(children: [
                    Icon(data.realizedPnlHoje >= 0 ? Icons.trending_up : Icons.trending_down,
                        color: data.realizedPnlHoje >= 0 ? FenixColors.green : FenixColors.red, size: 24),
                    const SizedBox(height: 4),
                    Text(data.realizedPnlHoje >= 0 ? 'LUCRO' : 'PERDA',
                        style: TextStyle(fontFamily: 'RobotoMono', fontSize: 9, fontWeight: FontWeight.w700,
                            color: data.realizedPnlHoje >= 0 ? FenixColors.green : FenixColors.red)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            _SectionTitle('Saldos por ativo'),
            const SizedBox(height: 6),
            _BalancesCard(balances: _balances, prices: _prices, totalUsdt: _totalUsdt),
            const SizedBox(height: 14),
            _SectionTitle('Ordens recentes'),
            const SizedBox(height: 6),
            _OrdensCard(orders: _orders),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              const Icon(Icons.update, size: 11, color: FenixColors.textMuted),
              const SizedBox(width: 4),
              Text('Atualizado: ${DateFormat('HH:mm:ss').format(data.fetchedAt)}',
                  style: const TextStyle(fontFamily: 'RobotoMono',
                      fontSize: 9, color: FenixColors.textMuted)),
            ]),
          ],
        ],
      ),
    );
  }
}

// ── Saldos ────────────────────────────────────────────────────────────────────

class _BalancesCard extends StatelessWidget {
  final List<ExchangeBalance> balances;
  final Map<String, double> prices;
  final double totalUsdt;

  const _BalancesCard({
    required this.balances,
    required this.prices,
    required this.totalUsdt,
  });

  @override
  Widget build(BuildContext context) {
    final fmtUsdt = NumberFormat('#,##0.00', 'pt_BR');

    // Agrupa por ativo
    final Map<String, Map<String, double>> grouped = {};
    for (final b in balances) {
      grouped.putIfAbsent(b.asset, () => {});
      grouped[b.asset]![b.exchange] =
          (grouped[b.asset]![b.exchange] ?? 0) + b.total;
    }

    final assets = grouped.entries.map((e) {
      final total = e.value.values.fold(0.0, (s, v) => s + v);
      final usdt  = e.key == 'USDT'
          ? total
          : (prices['${e.key}USDT'] ?? 0) * total;
      return (asset: e.key, total: total, usdt: usdt, exchanges: e.value);
    }).toList()..sort((a, b) => b.usdt.compareTo(a.usdt));

    if (assets.isEmpty) {
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
        for (int i = 0; i < assets.length; i++) ...[
          _BalanceRow(
            asset:     assets[i].asset,
            total:     assets[i].total,
            usdtValue: assets[i].usdt,
            exchanges: assets[i].exchanges,
            totalUsdt: totalUsdt,
            fmtUsdt:   fmtUsdt,
          ),
          if (i < assets.length - 1)
            const Divider(height: 12, thickness: .5,
                color: FenixColors.border),
        ],
      ]),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String asset;
  final double total, usdtValue, totalUsdt;
  final Map<String, double> exchanges;
  final NumberFormat fmtUsdt;

  const _BalanceRow({
    required this.asset,
    required this.total,
    required this.usdtValue,
    required this.exchanges,
    required this.totalUsdt,
    required this.fmtUsdt,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalUsdt > 0
        ? (usdtValue / totalUsdt).clamp(0.0, 1.0)
        : 0.0;

    return Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: FenixColors.yellowBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(child: Text(asset[0],
            style: const TextStyle(fontSize: 12,
                fontWeight: FontWeight.w700, color: FenixColors.yellow))),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(asset, style: const TextStyle(fontSize: 13,
                fontWeight: FontWeight.w500,
                color: FenixColors.textPrimary)),
            const SizedBox(width: 6),
            // badges por exchange
            for (final ex in exchanges.entries)
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: (ex.key == 'Binance'
                        ? FenixColors.yellow
                        : FenixColors.orange).withOpacity(.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(ex.key[0],
                      style: TextStyle(fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: ex.key == 'Binance'
                              ? FenixColors.yellow
                              : FenixColors.orange)),
                ),
              ),
            const Spacer(),
            Text('\$${fmtUsdt.format(usdtValue)}',
                style: const TextStyle(fontFamily: 'RobotoMono',
                    fontSize: 12, fontWeight: FontWeight.w500,
                    color: FenixColors.textPrimary)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct, minHeight: 3,
              backgroundColor: FenixColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  FenixColors.yellow),
            ),
          ),
          const SizedBox(height: 2),
          Text('${total.toStringAsFixed(6)} $asset  •  ${(pct * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontFamily: 'RobotoMono',
                  fontSize: 9, color: FenixColors.textMuted)),
        ],
      )),
    ]);
  }
}

// ── Ordens ────────────────────────────────────────────────────────────────────

class _OrdensCard extends StatelessWidget {
  final List<ExchangeOrder> orders;
  const _OrdensCard({required this.orders});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'pt_BR');
    if (orders.isEmpty) {
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
        for (int i = 0; i < orders.length; i++) ...[
          _OrdemRow(order: orders[i], fmt: fmt),
          if (i < orders.length - 1)
            const Divider(height: 12, thickness: .5,
                color: FenixColors.border),
        ],
      ]),
    );
  }
}

class _OrdemRow extends StatelessWidget {
  final ExchangeOrder order;
  final NumberFormat fmt;
  const _OrdemRow({required this.order, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final isSell  = order.side == 'SELL';
    final color   = isSell ? FenixColors.green : FenixColors.blue;
    final exColor = order.exchange == 'Binance'
        ? FenixColors.yellow
        : FenixColors.orange;

    return Row(children: [
      Container(
        width: 16, height: 16,
        decoration: BoxDecoration(
          color: exColor.withOpacity(.15),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Center(child: Text(order.exchange[0],
            style: TextStyle(fontSize: 8,
                fontWeight: FontWeight.w700, color: exColor))),
      ),
      const SizedBox(width: 6),
      Expanded(flex: 2, child: Row(children: [
        Text(order.symbol, style: const TextStyle(fontFamily: 'RobotoMono',
            fontSize: 11, fontWeight: FontWeight.w500,
            color: FenixColors.textPrimary)),
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
      Text(DateFormat('HH:mm:ss').format(order.time),
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
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: FenixColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: FenixColors.border, width: .5)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_outlined, size: 32,
            color: FenixColors.textMuted),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12,
                color: FenixColors.textMuted, height: 1.4)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: FenixColors.yellow,
            foregroundColor: const Color(0xFF1A0A00),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Tentar novamente'),
          onPressed: onRetry,
        ),
      ]),
    ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(.3), width: .5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 7, color: color),
        const SizedBox(width: 5),
        Text(realMode ? 'MODO REAL' : 'MODO DEMO',
            style: TextStyle(fontFamily: 'RobotoMono',
                fontSize: 9, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 5),
        Icon(Icons.swap_horiz, size: 12, color: color),
      ]),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

BoxDecoration _cardDeco({Color? topColor}) => BoxDecoration(
  color: FenixColors.card,
  borderRadius: BorderRadius.circular(8),
  border: Border.all(color: topColor ?? FenixColors.border, width: topColor != null ? 1.5 : .5),
);

class _Item extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  const _Item({required this.label, required this.value, required this.sub,
      required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Flexible(child: Text(label, style: const TextStyle(
            fontSize: 9, color: FenixColors.textMuted))),
      ]),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(fontFamily: 'RobotoMono',
          fontSize: 11, fontWeight: FontWeight.w500, color: color)),
      Text(sub, style: const TextStyle(fontSize: 9,
          color: FenixColors.textMuted)),
    ]),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
          color: FenixColors.textMuted, letterSpacing: .3));
}
