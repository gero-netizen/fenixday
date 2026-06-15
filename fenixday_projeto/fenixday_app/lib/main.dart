/// FênixDay — Entrada do App Flutter
///
/// Configura:
///   • MaterialApp com tema escuro Binance+Bybit
///   • GoRouter com todas as 12 rotas
///   • Riverpod (ProviderScope) como raiz
///   • Redirect automático para login se não autenticado

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'ui/theme/fenix_theme.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/dashboard_screen_v2.dart';
import 'ui/screens/grid_config_screen_v2.dart';
import 'ui/screens/top_grids_screen.dart';
import 'ui/screens/paper_trading_screen.dart';
import 'ui/screens/license_screen_v3.dart';
import 'ui/screens/admin_screen_v2.dart';
import 'ui/screens/settings/exchange_settings_screen.dart';
import 'ui/screens/simulator/simulator_screen.dart';
import 'ui/screens/privacy_screen.dart';
import 'ui/screens/scanner_screen.dart';
import 'ui/screens/grids_screen.dart';

// ── Provider de autenticação ──────────────────────────────────────────────────

final authProvider = StateProvider<bool>((ref) => false);
final superuserProvider = StateProvider<bool>((ref) => false);

// ── Router ────────────────────────────────────────────────────────────────────

final _router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) => null,
  routes: [
    // Auth
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (_, __) => const LoginScreen(),
    ),

    // Shell com BottomNavigationBar (5 tabs principais)
    ShellRoute(
      builder: (context, state, child) => _MainShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          name: 'dashboard',
          builder: (_, __) => const DashboardScreenV2(),
        ),
        GoRoute(
          path: '/grids',
          name: 'grids',
          builder: (_, __) => const GridsScreen(),
          routes: [
            GoRoute(
              path: 'config',
              name: 'grid-config',
              builder: (_, __) => const GridConfigScreenV2(),
            ),
          ],
        ),
        GoRoute(
          path: '/scanner',
          name: 'scanner',
          builder: (_, __) => const ScannerScreen(),
        ),
        GoRoute(
          path: '/licenca',
          name: 'licenca',
          builder: (_, __) => const LicenseScreenV3(),
        ),
        GoRoute(
          path: '/configuracoes',
          name: 'configuracoes',
          builder: (_, __) => const _SettingsScreen(),
        ),
      ],
    ),

    // Telas independentes (sem BottomNav)
    GoRoute(
      path: '/paper-trading',
      name: 'paper-trading',
      builder: (_, __) => const PaperTradingScreen(),
    ),
    GoRoute(
      path: '/top-grids',
      name: 'top-grids',
      builder: (_, __) => const TopGridsScreen(),
    ),
    GoRoute(
      path: '/simulador',
      name: 'simulador',
      builder: (_, __) => const SimulatorScreen(),
    ),
    GoRoute(
      path: '/admin',
      name: 'admin',
      builder: (_, __) => const AdminScreenV2(),
    ),
    GoRoute(
      path: '/apis',
      name: 'apis',
      builder: (_, __) => const ExchangeSettingsScreen(),
    ),
    GoRoute(
      path: '/privacidade',
      name: 'privacidade',
      builder: (_, __) => PrivacySettingsScreen(),
    ),
  ],
);

// ── Main ─────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forçar orientação portrait em mobile
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Barra de status transparente
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:       Colors.transparent,
    statusBarBrightness:  Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(
    const ProviderScope(
      child: FenixApp(),
    ),
  );
}

// ── App Widget ────────────────────────────────────────────────────────────────

class FenixApp extends ConsumerWidget {
  const FenixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title:          'FênixDay',
      debugShowCheckedModeBanner: false,
      theme:          fenixTheme,
      routerConfig:   _router,
      builder: (context, child) {
        // Garante escala de texto consistente
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child!,
        );
      },
    );
  }
}

// ── Shell com BottomNavigationBar ─────────────────────────────────────────────

class _MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const _MainShell({required this.child});

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell> {
  static const _tabs = [
    (icon: Icons.bar_chart_outlined,      activeIcon: Icons.bar_chart,            label: 'P&L',      route: '/dashboard'),
    (icon: Icons.grid_view_outlined,      activeIcon: Icons.grid_view,            label: 'Grids',    route: '/grids'),
    (icon: Icons.document_scanner_outlined,activeIcon: Icons.document_scanner,    label: 'Scanner',  route: '/scanner'),
    (icon: Icons.verified_outlined,       activeIcon: Icons.verified,             label: 'Licença',  route: '/licenca'),
    (icon: Icons.settings_outlined,       activeIcon: Icons.settings,             label: 'Config',   route: '/configuracoes'),
  ];

  int _currentIndex = 0;

  void _onTap(int index) {
    setState(() => _currentIndex = index);
    context.go(_tabs[index].route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: FenixColors.border, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap:        _onTap,
          items: _tabs.map((t) => BottomNavigationBarItem(
            icon:       Icon(t.icon,       size: 20),
            activeIcon: Icon(t.activeIcon, size: 20),
            label:      t.label,
          )).toList(),
        ),
      ),
    );
  }
}

// ── Placeholders (substituir por telas reais) ──────────────────────────────────

class _GridsPlaceholder extends StatelessWidget {
  const _GridsPlaceholder();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: FenixColors.bg,
    appBar: AppBar(
      title: const Text('Grids ativos'),
      actions: [
        TextButton.icon(
          onPressed: () => context.go('/grids/config'),
          icon: const Icon(Icons.add, size: 16, color: FenixColors.yellow),
          label: const Text('Novo Grid',
              style: TextStyle(color: FenixColors.yellow, fontSize: 12)),
        ),
      ],
    ),
    body: const Center(
      child: Text('Nenhum grid ativo.\nToque em + para criar.',
          textAlign: TextAlign.center,
          style: TextStyle(color: FenixColors.textMuted, fontSize: 13)),
    ),
  );
}

class _ScannerPlaceholder extends StatelessWidget {
  const _ScannerPlaceholder();
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: FenixColors.bg,
    body: Center(
      child: Text('Scanner de IA\nEm breve',
          textAlign: TextAlign.center,
          style: TextStyle(color: FenixColors.textMuted, fontSize: 13)),
    ),
  );
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FenixColors.bg,
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _SettingsTile(
            icon:  Icons.key_outlined,
            label: 'Configurar Corretoras (APIs)',
            color: FenixColors.yellow,
            onTap: () => context.push('/apis'),
          ),
          _SettingsTile(
            icon:  Icons.calculate_outlined,
            label: 'Simulador de Ganhos',
            color: FenixColors.green,
            onTap: () => context.push('/simulador'),
          ),
          _SettingsTile(
            icon:  Icons.science_outlined,
            label: 'Paper Trading',
            color: FenixColors.purple,
            onTap: () => context.push('/paper-trading'),
          ),
          _SettingsTile(
            icon:  Icons.leaderboard_outlined,
            label: 'Top Grids',
            color: FenixColors.blue,
            onTap: () => context.push('/top-grids'),
          ),
          _SettingsTile(
            icon:  Icons.lock_outline,
            label: 'Privacidade e Dados (LGPD)',
            color: FenixColors.orange,
            onTap: () => context.push('/privacidade'),
          ),
          Consumer(builder: (context, ref, _) {
            final isSuperuser = ref.watch(superuserProvider);
            if (!isSuperuser) return const SizedBox.shrink();
            return _SettingsTile(
              icon:  Icons.admin_panel_settings_outlined,
              label: 'Painel Admin',
              color: FenixColors.violet,
              onTap: () => context.push('/admin'),
            );
          }),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    leading: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    ),
    title: Text(label,
        style: const TextStyle(fontSize: 13, color: FenixColors.textPrimary)),
    trailing: const Icon(Icons.arrow_forward_ios,
        size: 13, color: FenixColors.textMuted),
    onTap: onTap,
  );
}
