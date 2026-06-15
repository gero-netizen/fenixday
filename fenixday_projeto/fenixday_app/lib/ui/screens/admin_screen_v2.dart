/// FênixDay — Área de Administração Completa v2
///
/// Acesso restrito a is_superuser=True (verificado no JWT).
///
/// Abas:
///   1. Visão Geral   — métricas, gráfico receita, distribuição de planos
///   2. Usuários      — busca, filtro, ações (ativar/revogar/banir/VIP)
///   3. Licenças      — gestão de planos, upgrade manual, vitalício
///   4. Receita       — receita por plano, histórico mensal, projeção
///   5. Logs          — auditoria com filtro por tipo de evento
///   6. Notificações  — enviar aviso para todos ou por segmento
///   7. Top Grids     — aprovar/verificar/remover grids do ranking

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/fenix_theme.dart';

const _adminBase = 'https://fenixday.info/api/v1/admin';

Future<Map<String, String>> _authHeader() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('access_token') ?? '';
  return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
}

// ── Modelos ───────────────────────────────────────────────────────────────────

class _AdminUser {
  final String id, email, planName;
  final String licenseStatus;   // active | pending | expired | exempt | lifetime
  final double tradedVolume;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final bool isBanned;
  const _AdminUser({
    required this.id, required this.email, required this.planName,
    required this.licenseStatus, required this.tradedVolume,
    required this.createdAt, this.lastLogin, this.isBanned = false,
  });
}

class _AdminMetrics {
  final int totalUsers, activeUsers, exemptUsers, expiredUsers, bannedUsers;
  final double revenueMonthly, revenueTotal;
  final int newToday, basicCount, proCount, premiumCount;
  const _AdminMetrics({
    required this.totalUsers, required this.activeUsers,
    required this.exemptUsers, required this.expiredUsers,
    required this.bannedUsers, required this.revenueMonthly,
    required this.revenueTotal, required this.newToday,
    required this.basicCount, required this.proCount,
    required this.premiumCount,
  });
}

class _TopGridEntry {
  final int rank;
  final String symbol, exchange;
  final double profitPct;
  final int cycles, copiedBy;
  final bool isVerified;
  final String status; // 'pending' | 'approved' | 'rejected'
  const _TopGridEntry({
    required this.rank, required this.symbol, required this.exchange,
    required this.profitPct, required this.cycles, required this.copiedBy,
    required this.isVerified, required this.status,
  });
}

class _LogEntry {
  final String type, message, actorId, time;
  final bool success;
  const _LogEntry({
    required this.type, required this.message,
    required this.actorId, required this.time,
    required this.success,
  });
}

// ── Providers (mock) ──────────────────────────────────────────────────────────

final _tabProvider    = StateProvider<int>((ref) => 0);
final _searchProvider = StateProvider<String>((ref) => '');
final _filterProvider = StateProvider<String>((ref) => 'todos');

final _metricsProvider = FutureProvider<_AdminMetrics>((ref) async {
  final headers = await _authHeader();
  final r = await http.get(Uri.parse('$_adminBase/metrics'), headers: headers);
  if (r.statusCode != 200) throw Exception('Erro ao carregar métricas');
  final d = jsonDecode(r.body);
  return _AdminMetrics(
    totalUsers:     d['total_users']     ?? 0,
    activeUsers:    d['active_users']    ?? 0,
    exemptUsers:    d['exempt_users']    ?? 0,
    expiredUsers:   d['expired_users']   ?? 0,
    bannedUsers:    d['banned_users']    ?? 0,
    revenueMonthly: (d['revenue_monthly'] ?? 0).toDouble(),
    revenueTotal:   (d['revenue_total']   ?? 0).toDouble(),
    newToday:       d['new_today']       ?? 0,
    basicCount:     d['basic_count']     ?? 0,
    proCount:       d['pro_count']       ?? 0,
    premiumCount:   d['premium_count']   ?? 0,
  );
});

final _usersRefreshProvider = StateProvider<int>((ref) => 0);
final _usersProvider = FutureProvider<List<_AdminUser>>((ref) async {
  ref.watch(_usersRefreshProvider);
  final headers = await _authHeader();
  final r = await http.get(Uri.parse('$_adminBase/users?limit=100'), headers: headers);
  if (r.statusCode != 200) throw Exception('Erro ao carregar usuários');
  final List data = jsonDecode(r.body);
  return data.map((u) => _AdminUser(
    id:            u['id'] ?? '',
    email:         u['email'] ?? '',
    planName:      u['current_tier'] ?? 'isento',
    licenseStatus: u['license_status'] ?? 'pending',
    tradedVolume:  (u['traded_volume'] ?? 0).toDouble(),
    createdAt:     DateTime.tryParse(u['created_at'] ?? '') ?? DateTime.now(),
    lastLogin:     u['last_login'] != null ? DateTime.tryParse(u['last_login']) : null,
    isBanned:      u['is_active'] == false,
  )).toList();
});

final _topGridsProvider = Provider<List<_TopGridEntry>>((ref) => [
  _TopGridEntry(rank:1, symbol:'ETH/USDT', exchange:'Binance', profitPct:8.42, cycles:198, copiedBy:1243, isVerified:true,  status:'approved'),
  _TopGridEntry(rank:2, symbol:'BTC/USDT', exchange:'Binance', profitPct:7.81, cycles:164, copiedBy:987,  isVerified:true,  status:'approved'),
  _TopGridEntry(rank:3, symbol:'SOL/USDT', exchange:'Bybit',   profitPct:7.35, cycles:172, copiedBy:756,  isVerified:true,  status:'approved'),
  _TopGridEntry(rank:4, symbol:'BNB/USDT', exchange:'Binance', profitPct:6.98, cycles:158, copiedBy:534,  isVerified:false, status:'pending'),
  _TopGridEntry(rank:5, symbol:'AVAX/USDT',exchange:'OKX',     profitPct:6.54, cycles:145, copiedBy:421,  isVerified:false, status:'pending'),
]);

final _logsProvider = Provider<List<_LogEntry>>((ref) => [
  _LogEntry(type:'auth',    message:'joao@email.com fez login via Google',            actorId:'joao@email.com',   time:'14:35:01', success:true),
  _LogEntry(type:'payment', message:'Pagamento confirmado — Pro — pedro@email.com',   actorId:'pedro@email.com',  time:'14:20:18', success:true),
  _LogEntry(type:'license', message:'Licença ativada — Pro — pedro@email.com',        actorId:'pedro@email.com',  time:'14:20:19', success:true),
  _LogEntry(type:'auth',    message:'maria@email.com fez login via e-mail',           actorId:'maria@email.com',  time:'13:58:42', success:true),
  _LogEntry(type:'warn',    message:'Webhook BTCPay com assinatura inválida',          actorId:'sistema',          time:'13:45:00', success:false),
  _LogEntry(type:'admin',   message:'Admin ativou conta lifetime — vip@fenixday.com', actorId:'admin',            time:'11:20:05', success:true),
  _LogEntry(type:'auth',    message:'spam@bad.com — conta banida detectada',          actorId:'spam@bad.com',     time:'10:15:33', success:false),
  _LogEntry(type:'upgrade', message:'ana@email.com — plano expirado, Modo Real bloqueado', actorId:'sistema',    time:'09:00:00', success:true),
]);

// ── Tela principal ────────────────────────────────────────────────────────────

class AdminScreenV2 extends ConsumerWidget {
  const AdminScreenV2({super.key});

  static const _tabs = [
    (Icons.dashboard_outlined,       'Visão Geral'),
    (Icons.people_outline,           'Usuários'),
    (Icons.person_add_outlined,      'Add User'),
    (Icons.verified_outlined,        'Licenças'),
    (Icons.attach_money,             'Receita'),
    (Icons.receipt_long_outlined,    'Logs'),
    (Icons.notifications_outlined,   'Notif.'),
    (Icons.leaderboard_outlined,     'Top Grids'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_tabProvider);

    return Scaffold(
      backgroundColor: FenixColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _AdminTopBar(),
            _TabBar(tabs: _tabs),
            Expanded(
              child: IndexedStack(
                index: tab,
                children: [
                  _OverviewTab(),
                  _UsersTab(),
                  _AddUserTab(),
                  _LicensesTab(),
                  _RevenueTab(),
                  _LogsTab(),
                  _NotificationsTab(),
                  _TopGridsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── TopBar ────────────────────────────────────────────────────────────────────

class _AdminTopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: FenixColors.surface,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.maybePop(context),
        child: const Icon(Icons.arrow_back, size: 18, color: FenixColors.textMuted),
      ),
      const SizedBox(width: 12),
      const Text('Painel de Administração',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500,
              color: FenixColors.textPrimary)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: FenixColors.violetBg,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: FenixColors.violet.withOpacity(.3), width: .5),
        ),
        child: const Text('ADMIN', style: TextStyle(
            fontFamily: 'RobotoMono', fontSize: 9, fontWeight: FontWeight.w700,
            color: FenixColors.violet)),
      ),
      const Spacer(),
      Text(DateFormat('dd/MM/yyyy  HH:mm').format(DateTime.now()),
          style: const TextStyle(fontFamily: 'RobotoMono',
              fontSize: 10, color: FenixColors.textMuted)),
    ]),
  );
}

class _TabBar extends ConsumerWidget {
  final List<(IconData, String)> tabs;
  const _TabBar({required this.tabs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(_tabProvider);
    return Container(
      color: FenixColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.asMap().entries.map((e) {
            final active = e.key == current;
            return GestureDetector(
              onTap: () => ref.read(_tabProvider.notifier).state = e.key,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(
                    color: active ? FenixColors.violet : Colors.transparent,
                    width: 1.5,
                  )),
                ),
                child: Row(children: [
                  Icon(e.value.$1, size: 14,
                      color: active ? FenixColors.violet : FenixColors.textMuted),
                  const SizedBox(width: 5),
                  Text(e.value.$2, style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: active ? FenixColors.violet : FenixColors.textMuted)),
                ]),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── 1. VISÃO GERAL ────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_metricsProvider).when(
      loading: () => const Center(child: CircularProgressIndicator(color: FenixColors.yellow)),
      error:   (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: FenixColors.red))),
      data:    (m) => _build(context, m),
    );
  }

  Widget _build(BuildContext context, _AdminMetrics m) {
    final fmt = NumberFormat('#,##0.00', 'pt_BR');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        // Grid de métricas
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8,
          childAspectRatio: 2.3,
          children: [
            _MetricCard('Total usuários', m.totalUsers.toString(), '+${m.newToday} hoje', FenixColors.green),
            _MetricCard('Ativos (pagos)', m.activeUsers.toString(), '${(m.activeUsers/m.totalUsers*100).toStringAsFixed(1)}%', FenixColors.green),
            _MetricCard('Receita mensal', '\$${fmt.format(m.revenueMonthly)}', '${m.basicCount}B + ${m.proCount}P + ${m.premiumCount}Pr', FenixColors.yellow),
            _MetricCard('Isentos', m.exemptUsers.toString(), 'vol < \$500', FenixColors.orange),
            _MetricCard('Expirados', m.expiredUsers.toString(), 'sem renovação', FenixColors.red),
            _MetricCard('Receita total', '\$${fmt.format(m.revenueTotal)}', 'desde o início', FenixColors.yellow),
          ],
        ),
        const SizedBox(height: 14),

        // Distribuição por plano
        _SectionTitle('Distribuição por plano'),
        const SizedBox(height: 8),
        _PlanDistributionCard(m: m),
        const SizedBox(height: 14),

        // Distribuição geral
        _SectionTitle('Status dos usuários'),
        const SizedBox(height: 8),
        _BarChartCard(m: m),
      ]),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  const _MetricCard(this.label, this.value, this.sub, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: FenixColors.card,
      borderRadius: BorderRadius.circular(0),
      border: Border(top: BorderSide(color: color, width: 2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(label, style: const TextStyle(fontSize: 9, color: FenixColors.textMuted)),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(fontFamily: 'RobotoMono',
          fontSize: 18, fontWeight: FontWeight.w500, color: color)),
      Text(sub, style: const TextStyle(fontSize: 9, color: FenixColors.textMuted)),
    ]),
  );
}

class _PlanDistributionCard extends StatelessWidget {
  final _AdminMetrics m;
  const _PlanDistributionCard({required this.m});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'pt_BR');
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: _cardDeco(),
      child: Column(children: [
        _PlanRow('Basic',   m.basicCount,   '\$${fmt.format(m.basicCount * 10.0)}',   FenixColors.blue),
        _PlanRow('Pro',     m.proCount,     '\$${fmt.format(m.proCount * 14.99)}',    FenixColors.purple),
        _PlanRow('Premium', m.premiumCount, '\$${fmt.format(m.premiumCount * 29.90)}', FenixColors.yellow),
        _PlanRow('Isento',  m.exemptUsers,  '\$0,00',                                 FenixColors.green),
      ]),
    );
  }
}

class _PlanRow extends StatelessWidget {
  final String label;
  final int count;
  final String revenue;
  final Color color;
  const _PlanRow(this.label, this.count, this.revenue, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      SizedBox(width: 56, child: Text(label,
          style: const TextStyle(fontSize: 11, color: FenixColors.textSecondary))),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: count / 1300,
          minHeight: 8,
          backgroundColor: FenixColors.border,
          valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(.7)),
        ),
      )),
      const SizedBox(width: 8),
      SizedBox(width: 32, child: Text('$count',
          textAlign: TextAlign.right,
          style: TextStyle(fontFamily: 'RobotoMono',
              fontSize: 11, color: color))),
      const SizedBox(width: 10),
      SizedBox(width: 80, child: Text(revenue,
          textAlign: TextAlign.right,
          style: const TextStyle(fontFamily: 'RobotoMono',
              fontSize: 10, color: FenixColors.textMuted))),
    ]),
  );
}

class _BarChartCard extends StatelessWidget {
  final _AdminMetrics m;
  const _BarChartCard({required this.m});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: _cardDeco(),
    child: Column(children: [
      _BarRow('Ativos',    m.activeUsers,  m.totalUsers, FenixColors.green),
      _BarRow('Isentos',   m.exemptUsers,  m.totalUsers, FenixColors.orange),
      _BarRow('Expirados', m.expiredUsers, m.totalUsers, FenixColors.red),
      _BarRow('Banidos',   m.bannedUsers,  m.totalUsers, FenixColors.textMuted),
    ]),
  );
}

class _BarRow extends StatelessWidget {
  final String label;
  final int value, total;
  final Color color;
  const _BarRow(this.label, this.value, this.total, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      SizedBox(width: 64, child: Text(label,
          style: const TextStyle(fontSize: 10, color: FenixColors.textMuted))),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: total > 0 ? value / total : 0,
          minHeight: 10, backgroundColor: FenixColors.border,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      )),
      SizedBox(width: 36, child: Text('$value',
          textAlign: TextAlign.right,
          style: TextStyle(fontFamily: 'RobotoMono',
              fontSize: 10, color: color))),
    ]),
  );
}

// ── 2. USUÁRIOS ───────────────────────────────────────────────────────────────

class _UsersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(_searchProvider).toLowerCase();
    final filter = ref.watch(_filterProvider);
    return ref.watch(_usersProvider).when(
      loading: () => const Center(child: CircularProgressIndicator(color: FenixColors.yellow)),
      error:   (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: FenixColors.red))),
      data:    (users) {
        var filtered = users.where((u) {
          if (search.isNotEmpty && !u.email.toLowerCase().contains(search)) return false;
          if (filter != 'todos' && u.licenseStatus != filter) return false;
          return true;
        }).toList();
        return Column(children: [
      // Filtros
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Row(children: [
          Expanded(
            child: TextField(
              onChanged: (v) =>
                  ref.read(_searchProvider.notifier).state = v,
              style: const TextStyle(fontSize: 12,
                  color: FenixColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Buscar por e-mail...',
                hintStyle: TextStyle(fontSize: 11,
                    color: FenixColors.textMuted),
                prefixIcon: Icon(Icons.search, size: 15,
                    color: FenixColors.textMuted),
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _FilterDropdown(),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const Divider(
              height: 0, thickness: .5, color: FenixColors.border),
          itemBuilder: (_, i) => _UserRow(user: filtered[i]),
        ),
      ),
    ]);
      },
    );
  }
}

class _FilterDropdown extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(_filterProvider);
    return DropdownButton<String>(
      value: current,
      dropdownColor: FenixColors.card,
      style: const TextStyle(fontSize: 11, color: FenixColors.textSecondary),
      underline: const SizedBox.shrink(),
      items: const [
        DropdownMenuItem(value: 'todos',    child: Text('Todos')),
        DropdownMenuItem(value: 'active',   child: Text('Ativos')),
        DropdownMenuItem(value: 'exempt',   child: Text('Isentos')),
        DropdownMenuItem(value: 'expired',  child: Text('Expirados')),
        DropdownMenuItem(value: 'lifetime', child: Text('Lifetime')),
      ],
      onChanged: (v) {
        if (v != null) ref.read(_filterProvider.notifier).state = v;
      },
    );
  }
}

class _UserRow extends ConsumerWidget {
  final _AdminUser user;
  const _UserRow({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (color, label) = _statusStyle(user.licenseStatus);
    final fmt = NumberFormat('#,##0.00', 'pt_BR');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        // Avatar
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(.12), shape: BoxShape.circle,
          ),
          child: Center(child: Text(user.email[0].toUpperCase(),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: color))),
        ),
        const SizedBox(width: 10),

        // Info
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(user.email, style: const TextStyle(
                  fontSize: 12, color: FenixColors.textPrimary)),
              if (user.isBanned) ...[
                const SizedBox(width: 6),
                const Icon(Icons.block, size: 12, color: FenixColors.red),
              ],
            ]),
            Row(children: [
              Text('\$${fmt.format(user.tradedVolume)} vol',
                  style: const TextStyle(fontFamily: 'RobotoMono',
                      fontSize: 10, color: FenixColors.textMuted)),
              const Text(' · ', style: TextStyle(color: FenixColors.textMuted)),
              Text(user.planName,
                  style: const TextStyle(fontSize: 10,
                      color: FenixColors.textMuted)),
            ]),
          ],
        )),

        // Status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(.1), borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label, style: TextStyle(fontSize: 9, color: color)),
        ),
        const SizedBox(width: 6),

        // Menu de ações
        PopupMenuButton<String>(
          color: FenixColors.card,
          icon: const Icon(Icons.more_vert,
              size: 16, color: FenixColors.textMuted),
          onSelected: (action) => _handleAction(context, action, user),
          itemBuilder: (_) => [
            _menuItem('activate',  'Ativar licença',       FenixColors.green),
            _menuItem('basic',     'Definir como Basic',   FenixColors.blue),
            _menuItem('pro',       'Definir como Pro',     FenixColors.purple),
            _menuItem('premium',   'Definir como Premium', FenixColors.yellow),
            _menuItem('lifetime',  'Tornar vitalício',     FenixColors.violet),
            const PopupMenuDivider(),
            _menuItem('revoke',    'Revogar licença',      FenixColors.orange),
            _menuItem('ban',       user.isBanned ? 'Desbanir conta' : 'Banir conta', FenixColors.red),
          ],
        ),
      ]),
    );
  }

  PopupMenuItem<String> _menuItem(String value, String label, Color color) =>
      PopupMenuItem<String>(
        value: value,
        child: Text(label, style: TextStyle(fontSize: 12, color: color)),
      );

  void _handleAction(BuildContext ctx, String action, _AdminUser user) async {
    final headers = await _authHeader();
    final r = await http.patch(
      Uri.parse('$_adminBase/users/${user.id}/license'),
      headers: headers,
      body: jsonEncode({'action': action, 'reason': 'admin manual'}),
    );
    if (!ctx.mounted) return;
    final ok = r.statusCode == 200;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Ação "$action" aplicada a ${user.email}'
          : 'Erro: ${jsonDecode(r.body)['detail'] ?? r.body}'),
      backgroundColor: ok ? FenixColors.green : FenixColors.red,
      duration: const Duration(seconds: 2),
    ));
    if (ok) {
      ProviderScope.containerOf(ctx).read(_usersRefreshProvider.notifier).state++;
      ProviderScope.containerOf(ctx).refresh(_metricsProvider);
    }
  }

  (Color, String) _statusStyle(String status) => switch (status) {
    'active'   => (FenixColors.green,  'ativo'),
    'exempt'   => (FenixColors.orange, 'isento'),
    'expired'  => (FenixColors.red,    'expirado'),
    'lifetime' => (FenixColors.violet, 'lifetime'),
    'pending'  => (FenixColors.textMuted, 'pendente'),
    _          => (FenixColors.textMuted, status),
  };
}

// ── 3. LICENÇAS ───────────────────────────────────────────────────────────────

class _LicensesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt   = NumberFormat('#,##0.00', 'pt_BR');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        // Ações em massa
        Container(
          padding: const EdgeInsets.all(13),
          decoration: _cardDeco(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ações em massa',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                      color: FenixColors.textMuted, letterSpacing: .4)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _ActionBtn('Notificar expirados', FenixColors.orange, Icons.notifications_outlined, () {}),
                _ActionBtn('Reativar expirados', FenixColors.green, Icons.refresh, () {}),
                _ActionBtn('Exportar CSV', FenixColors.blue, Icons.download_outlined, () {}),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Lista de licenças
        _SectionTitle('Todas as licenças'),
        const SizedBox(height: 8),
        Container(
          decoration: _cardDeco(),
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(
                      color: FenixColors.border, width: .5))),
              child: const Row(children: [
                Expanded(flex:3, child: Text('Usuário', style: TextStyle(
                    fontSize: 9, color: FenixColors.textMuted))),
                Expanded(child: Text('Plano', style: TextStyle(
                    fontSize: 9, color: FenixColors.textMuted))),
                Expanded(child: Text('Volume', style: TextStyle(
                    fontSize: 9, color: FenixColors.textMuted))),
                Expanded(child: Text('Status', style: TextStyle(
                    fontSize: 9, color: FenixColors.textMuted))),
                SizedBox(width: 32),
              ]),
            ),
            ...ref.watch(_usersProvider).valueOrNull?.map((u) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(
                      color: FenixColors.border, width: .5))),
              child: Row(children: [
                Expanded(flex:3, child: Text(u.email,
                    style: const TextStyle(fontSize: 11,
                        color: FenixColors.textPrimary),
                    overflow: TextOverflow.ellipsis)),
                Expanded(child: Text(u.planName,
                    style: const TextStyle(fontSize: 10,
                        color: FenixColors.textSecondary))),
                Expanded(child: Text('\$${fmt.format(u.tradedVolume)}',
                    style: const TextStyle(fontFamily: 'RobotoMono',
                        fontSize: 10, color: FenixColors.textMuted))),
                Expanded(child: _LicenseBadge(status: u.licenseStatus)),
                PopupMenuButton<String>(
                  color: FenixColors.card,
                  icon: const Icon(Icons.more_vert, size: 14,
                      color: FenixColors.textMuted),
                  itemBuilder: (_) => [
                    _pmi('Ativar',       FenixColors.green),
                    _pmi('Pro',          FenixColors.purple),
                    _pmi('Premium',      FenixColors.yellow),
                    _pmi('Lifetime',     FenixColors.violet),
                    _pmi('Revogar',      FenixColors.red),
                  ],
                  onSelected: (_) {},
                ),
              ]),
            )) ?? [],
          ]),
        ),
      ]),
    );
  }

  PopupMenuItem<String> _pmi(String label, Color color) =>
      PopupMenuItem<String>(value: label,
          child: Text(label, style: TextStyle(fontSize: 12, color: color)));
}

class _LicenseBadge extends StatelessWidget {
  final String status;
  const _LicenseBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'active'   => (FenixColors.green,  'ativo'),
      'exempt'   => (FenixColors.orange, 'isento'),
      'expired'  => (FenixColors.red,    'expirado'),
      'lifetime' => (FenixColors.violet, 'lifetime'),
      _          => (FenixColors.textMuted, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(.1), borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, color: color)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionBtn(this.label, this.color, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(.3), width: .5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ]),
    ),
  );
}

// ── 4. RECEITA ────────────────────────────────────────────────────────────────

class _RevenueTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_metricsProvider).when(
      loading: () => const Center(child: CircularProgressIndicator(color: FenixColors.yellow)),
      error:   (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: FenixColors.red))),
      data:    (m) => _build(context, m),
    );
  }

  Widget _build(BuildContext context, _AdminMetrics m) {
    final fmt = NumberFormat('#,##0.00', 'pt_BR');
    final months = [
      ('Jan/26', 6420.0), ('Fev/26', 7030.0), ('Mar/26', 7540.0),
      ('Abr/26', 7980.0), ('Mai/26', 9200.0), ('Jun/26', 9821.13),
    ];
    final maxRev = months.map((m) => m.$2).reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        // Resumo
        Row(children: [
          Expanded(child: _MetricCard('Receita mensal',
              '\$${fmt.format(m.revenueMonthly)}',
              '${m.basicCount}B + ${m.proCount}P + ${m.premiumCount}Pr',
              FenixColors.yellow)),
          const SizedBox(width: 8),
          Expanded(child: _MetricCard('Receita total',
              '\$${fmt.format(m.revenueTotal)}',
              'desde o início', FenixColors.green)),
        ]),
        const SizedBox(height: 14),

        // Gráfico mensal
        _SectionTitle('Receita mensal'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: _cardDeco(),
          child: Column(children: [
            ...months.map((month) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(width: 52, child: Text(month.$1,
                    style: const TextStyle(fontFamily: 'RobotoMono',
                        fontSize: 10, color: FenixColors.textMuted))),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: month.$2 / (maxRev * 1.1),
                    minHeight: 14,
                    backgroundColor: FenixColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        FenixColors.yellow),
                  ),
                )),
                const SizedBox(width: 8),
                Text('\$${fmt.format(month.$2)}',
                    style: const TextStyle(fontFamily: 'RobotoMono',
                        fontSize: 10, color: FenixColors.yellow)),
              ]),
            )),
          ]),
        ),
        const SizedBox(height: 14),

        // Projeção
        _SectionTitle('Projeção próximo mês'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: _cardDeco(topColor: FenixColors.green),
          child: Row(children: [
            const Icon(Icons.trending_up, size: 20, color: FenixColors.green),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Projeção Jul/2026',
                  style: TextStyle(fontSize: 11, color: FenixColors.textMuted)),
              Text('\$${fmt.format(m.revenueMonthly * 1.08)}',
                  style: const TextStyle(fontFamily: 'RobotoMono',
                      fontSize: 18, fontWeight: FontWeight.w500,
                      color: FenixColors.green)),
            ]),
            const Spacer(),
            Text('+8% vs mês anterior',
                style: const TextStyle(fontSize: 11, color: FenixColors.green)),
          ]),
        ),
      ]),
    );
  }
}

// ── 5. LOGS ───────────────────────────────────────────────────────────────────

class _LogsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs   = ref.watch(_logsProvider);
    final search = ref.watch(_searchProvider).toLowerCase();

    final filtered = search.isEmpty
        ? logs
        : logs.where((l) =>
            l.message.toLowerCase().contains(search) ||
            l.actorId.toLowerCase().contains(search)).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: TextField(
          onChanged: (v) => ref.read(_searchProvider.notifier).state = v,
          style: const TextStyle(fontSize: 12, color: FenixColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Filtrar logs por e-mail ou mensagem...',
            hintStyle: TextStyle(fontSize: 11, color: FenixColors.textMuted),
            prefixIcon: Icon(Icons.search, size: 15, color: FenixColors.textMuted),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const Divider(
              height: 0, thickness: .5, color: FenixColors.border),
          itemBuilder: (_, i) => _LogRow(log: filtered[i]),
        ),
      ),
    ]);
  }
}

class _LogRow extends StatelessWidget {
  final _LogEntry log;
  const _LogRow({required this.log});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (log.type) {
      'auth'    => (Icons.login_outlined,                 FenixColors.blue),
      'payment' => (Icons.payments_outlined,              FenixColors.green),
      'license' => (Icons.verified_outlined,              FenixColors.green),
      'admin'   => (Icons.admin_panel_settings_outlined,  FenixColors.violet),
      'warn'    => (Icons.warning_amber_outlined,         FenixColors.red),
      'upgrade' => (Icons.upgrade_outlined,               FenixColors.orange),
      _         => (Icons.info_outline,                   FenixColors.textMuted),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(.1), borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(log.message, style: const TextStyle(
                fontSize: 11, color: FenixColors.textSecondary)),
            Text(log.actorId, style: const TextStyle(
                fontSize: 9, color: FenixColors.textMuted)),
          ],
        )),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(log.time, style: const TextStyle(fontFamily: 'RobotoMono',
              fontSize: 9, color: FenixColors.textMuted)),
          Icon(
            log.success ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 11,
            color: log.success ? FenixColors.green : FenixColors.red,
          ),
        ]),
      ]),
    );
  }
}

// ── 6. NOTIFICAÇÕES ───────────────────────────────────────────────────────────

class _NotificationsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends ConsumerState<_NotificationsTab> {
  final _msgCtrl    = TextEditingController();
  final _titleCtrl  = TextEditingController();
  String _segment   = 'todos';
  String _channel   = 'push';
  bool   _sending   = false;

  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(_metricsProvider);
    final metrics = metricsAsync.valueOrNull;
    final targetCount = switch (_segment) {
      'active'  => metrics?.activeUsers  ?? 0,
      'exempt'  => metrics?.exemptUsers  ?? 0,
      'expired' => metrics?.expiredUsers ?? 0,
      _         => metrics?.totalUsers   ?? 0,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        // Segmento
        _SectionTitle('Destinatários'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: _cardDeco(),
          child: Column(children: [
            for (final (value, label, sub) in [
              ('todos',   'Todos os usuários',       '${metrics == null ? 0 : metrics.totalUsers} destinatários'),
              ('active',  'Apenas assinantes ativos','${metrics == null ? 0 : metrics.activeUsers} destinatários'),
              ('exempt',  'Apenas isentos',          '${metrics == null ? 0 : metrics.exemptUsers} destinatários'),
              ('expired', 'Apenas expirados',        '${metrics == null ? 0 : metrics.expiredUsers} destinatários — reconquistar'),
            ])
              RadioListTile<String>(
                value: value, groupValue: _segment,
                onChanged: (v) => setState(() => _segment = v!),
                activeColor: FenixColors.violet,
                title: Text(label, style: const TextStyle(
                    fontSize: 12, color: FenixColors.textPrimary)),
                subtitle: Text(sub, style: const TextStyle(
                    fontSize: 10, color: FenixColors.textMuted)),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
          ]),
        ),
        const SizedBox(height: 14),

        // Canal
        _SectionTitle('Canal de envio'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: _cardDeco(),
          child: Row(children: [
            for (final (value, label, icon) in [
              ('push',     'Push + app',    Icons.notifications_outlined),
              ('telegram', 'Telegram',      Icons.send_outlined),
              ('ambos',    'Ambos',         Icons.broadcast_on_personal_outlined),
            ])
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _channel = value),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _channel == value
                          ? FenixColors.violetBg
                          : FenixColors.bg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _channel == value
                            ? FenixColors.violet.withOpacity(.4)
                            : FenixColors.border,
                        width: .5,
                      ),
                    ),
                    child: Column(children: [
                      Icon(icon, size: 16,
                          color: _channel == value
                              ? FenixColors.violet
                              : FenixColors.textMuted),
                      const SizedBox(height: 4),
                      Text(label, style: TextStyle(fontSize: 10,
                          color: _channel == value
                              ? FenixColors.violet
                              : FenixColors.textMuted)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 14),

        // Mensagem
        _SectionTitle('Mensagem'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: _cardDeco(),
          child: Column(children: [
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(fontSize: 13, color: FenixColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Título da notificação',
                hintStyle: TextStyle(color: FenixColors.textMuted),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _msgCtrl,
              maxLines: 4,
              style: const TextStyle(fontSize: 12, color: FenixColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Mensagem para os usuários...',
                hintStyle: TextStyle(color: FenixColors.textMuted),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // Resumo + botão enviar
        Container(
          padding: const EdgeInsets.all(13),
          decoration: _cardDeco(topColor: FenixColors.violet),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Destinatários:',
                  style: TextStyle(fontSize: 12, color: FenixColors.textMuted)),
              Text('$targetCount usuários',
                  style: const TextStyle(fontFamily: 'RobotoMono',
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: FenixColors.violet)),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Canal:',
                  style: TextStyle(fontSize: 12, color: FenixColors.textMuted)),
              Text(_channel,
                  style: const TextStyle(fontSize: 12,
                      color: FenixColors.textSecondary)),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FenixColors.violet,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: _sending
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: Colors.white))
                    : const Icon(Icons.send, size: 16),
                label: Text(_sending ? 'Enviando...' : 'Enviar notificação',
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600)),
                onPressed: _sending ? null : _send,
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _send() async {
    if (_titleCtrl.text.isEmpty || _msgCtrl.text.isEmpty) return;
    setState(() => _sending = true);
    await Future.delayed(const Duration(seconds: 2)); // TODO: POST /admin/notify
    if (mounted) {
      setState(() => _sending = false);
      _titleCtrl.clear();
      _msgCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Notificação enviada com sucesso!'),
        backgroundColor: FenixColors.green,
      ));
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }
}

// ── 7. TOP GRIDS ──────────────────────────────────────────────────────────────

class _TopGridsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grids = ref.watch(_topGridsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        // Pendentes de aprovação
        _SectionTitle('Pendentes de aprovação (${grids.where((g) => g.status == "pending").length})'),
        const SizedBox(height: 8),
        ...grids.where((g) => g.status == 'pending').map((g) =>
            _TopGridCard(grid: g)),

        const SizedBox(height: 14),

        // Aprovados
        _SectionTitle('Grids aprovados e ativos'),
        const SizedBox(height: 8),
        ...grids.where((g) => g.status == 'approved').map((g) =>
            _TopGridCard(grid: g)),
      ]),
    );
  }
}

class _TopGridCard extends StatelessWidget {
  final _TopGridEntry grid;
  const _TopGridCard({required this.grid});

  @override
  Widget build(BuildContext context) {
    final isPending = grid.status == 'pending';
    final color     = isPending ? FenixColors.orange : FenixColors.green;
    final fmt       = NumberFormat('#,##0.00', 'pt_BR');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: FenixColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPending
              ? FenixColors.orange.withOpacity(.3)
              : FenixColors.border,
          width: .5,
        ),
      ),
      child: Column(children: [
        Row(children: [
          // Rank
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: FenixColors.yellowBg,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(child: Text('${grid.rank}',
                style: const TextStyle(fontFamily: 'RobotoMono',
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: FenixColors.yellow))),
          ),
          const SizedBox(width: 10),

          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(grid.symbol, style: const TextStyle(
                    fontFamily: 'RobotoMono', fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: FenixColors.textPrimary)),
                if (grid.isVerified) ...[
                  const SizedBox(width: 5),
                  const Icon(Icons.verified, size: 13, color: FenixColors.blue),
                ],
                const SizedBox(width: 6),
                Text(grid.exchange, style: const TextStyle(
                    fontSize: 10, color: FenixColors.textMuted)),
              ]),
              Text('${grid.cycles} ciclos · ${grid.copiedBy} cópias',
                  style: const TextStyle(fontSize: 10,
                      color: FenixColors.textMuted)),
            ],
          )),

          Text('+${grid.profitPct.toStringAsFixed(2)}%',
              style: const TextStyle(fontFamily: 'RobotoMono',
                  fontSize: 13, fontWeight: FontWeight.w500,
                  color: FenixColors.green)),
        ]),
        const SizedBox(height: 10),

        // Ações
        Row(children: [
          if (isPending) ...[
            Expanded(child: _ActionBtn('Aprovar', FenixColors.green,
                Icons.check_outlined, () {})),
            const SizedBox(width: 8),
            Expanded(child: _ActionBtn('Rejeitar', FenixColors.red,
                Icons.close, () {})),
          ] else ...[
            Expanded(child: _ActionBtn(
              grid.isVerified ? 'Remover verificação' : 'Verificar',
              grid.isVerified ? FenixColors.textMuted : FenixColors.blue,
              grid.isVerified
                  ? Icons.gpp_bad
                  : Icons.verified_outlined,
              () {},
            )),
            const SizedBox(width: 8),
            Expanded(child: _ActionBtn('Remover do ranking',
                FenixColors.red, Icons.delete_outline, () {})),
          ],
        ]),
      ]),
    );
  }
}


// ── ADD USER ─────────────────────────────────────────────────────────────────

class _AddUserTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddUserTab> createState() => _AddUserTabState();
}

class _AddUserTabState extends ConsumerState<_AddUserTab> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  String _plan     = 'exempt';
  bool _isSu       = false;
  bool _loading    = false;
  String? _msg;
  bool _success    = false;

  @override
  void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _create() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() { _msg = 'Preencha e-mail e senha.'; _success = false; });
      return;
    }
    setState(() { _loading = true; _msg = null; });
    final headers = await _authHeader();
    final r = await http.post(
      Uri.parse('$_adminBase/users/create'),
      headers: headers,
      body: jsonEncode({
        'email': _emailCtrl.text.trim(),
        'password': _passCtrl.text,
        'plan': _plan,
        'is_superuser': _isSu,
      }),
    );
    setState(() {
      _loading = false;
      _success = r.statusCode == 200;
      _msg = _success
          ? 'Usuário criado: ${_emailCtrl.text}'
          : jsonDecode(r.body)['detail'] ?? 'Erro ao criar usuário.';
      if (_success) {
        _emailCtrl.clear(); _passCtrl.clear();
        _plan = 'exempt'; _isSu = false;
        ref.read(_usersRefreshProvider.notifier).state++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionTitle('Criar usuário manualmente'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDeco(topColor: FenixColors.violet),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('E-mail', style: TextStyle(fontSize: 11, color: FenixColors.textMuted)),
            const SizedBox(height: 4),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 13, color: FenixColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'usuario@email.com',
                hintStyle: TextStyle(color: FenixColors.textMuted),
                prefixIcon: Icon(Icons.mail_outline, size: 16, color: FenixColors.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Senha', style: TextStyle(fontSize: 11, color: FenixColors.textMuted)),
            const SizedBox(height: 4),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              style: const TextStyle(fontSize: 13, color: FenixColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Senha inicial',
                hintStyle: TextStyle(color: FenixColors.textMuted),
                prefixIcon: Icon(Icons.lock_outline, size: 16, color: FenixColors.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Plano', style: TextStyle(fontSize: 11, color: FenixColors.textMuted)),
            const SizedBox(height: 4),
            DropdownButton<String>(
              value: _plan, isExpanded: true,
              dropdownColor: FenixColors.card,
              style: const TextStyle(fontSize: 13, color: FenixColors.textPrimary),
              underline: Container(height: .5, color: FenixColors.border),
              items: const [
                DropdownMenuItem(value: 'exempt',  child: Text('Isento (grátis)')),
                DropdownMenuItem(value: 'basic',   child: Text('Basic')),
                DropdownMenuItem(value: 'pro',     child: Text('Pro')),
                DropdownMenuItem(value: 'premium', child: Text('Premium')),
              ],
              onChanged: (v) => setState(() => _plan = v!),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Switch(value: _isSu, onChanged: (v) => setState(() => _isSu = v),
                  activeColor: FenixColors.violet),
              const SizedBox(width: 8),
              const Expanded(child: Text('Conceder acesso admin (superuser)',
                  style: TextStyle(fontSize: 12, color: FenixColors.textSecondary))),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FenixColors.violet,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: _loading
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                    : const Icon(Icons.person_add, size: 16),
                label: Text(_loading ? 'Criando...' : 'Criar usuário',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                onPressed: _loading ? null : _create,
              ),
            ),
            if (_msg != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_success ? FenixColors.green : FenixColors.red).withOpacity(.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: (_success ? FenixColors.green : FenixColors.red).withOpacity(.3)),
                ),
                child: Row(children: [
                  Icon(_success ? Icons.check_circle_outline : Icons.error_outline,
                      size: 14, color: _success ? FenixColors.green : FenixColors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_msg!, style: TextStyle(fontSize: 11,
                      color: _success ? FenixColors.green : FenixColors.red))),
                ]),
              ),
            ],
          ]),
        ),
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
          top:    BorderSide(color: topColor,           width: 2),
          left:   BorderSide(color: FenixColors.border, width: .5),
          right:  BorderSide(color: FenixColors.border, width: .5),
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
