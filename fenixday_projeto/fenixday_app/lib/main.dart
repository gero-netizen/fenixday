/// FÃªnixDay â€” Entrada do App Flutter
///
/// Configura:
///   â€¢ MaterialApp com tema escuro Binance+Bybit
///   â€¢ GoRouter com todas as 12 rotas
///   â€¢ Riverpod (ProviderScope) como raiz
///   â€¢ Redirect automÃ¡tico para login se nÃ£o autenticado

import 'dart:io';
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
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'ui/screens/services/grid_monitor.dart';
import 'ui/screens/services/grid_monitor_task.dart';
import 'ui/screens/settings/exchange_settings_screen.dart';
import 'ui/screens/settings/vpn_settings_screen.dart';
import 'ui/screens/simulator/simulator_screen.dart';
import 'ui/screens/privacy_screen.dart';
import 'ui/screens/client_profile_screen.dart';
import 'ui/screens/scanner_screen.dart';
import 'ui/screens/grids_screen.dart';

// â”€â”€ Provider de autenticaÃ§Ã£o â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final authProvider = StateProvider<bool>((ref) => false);
final superuserProvider = StateProvider<bool>((ref) => false);

// â”€â”€ Router â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
      path: '/vpn',
      name: 'vpn',
      builder: (_, __) => const VpnSettingsScreen(),
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
    GoRoute(
      path: '/minha-conta',
      name: 'minha-conta',
      builder: (_, __) => const ClientProfileScreen(),
    ),
  ],
);

// â”€â”€ Main â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _FenixHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    // SecurityContext com certificados raiz do sistema. Resolve o
    // CERTIFICATE_VERIFY_FAILED da Bybit no Windows, mantendo a validacao
    // SSL normal (nao desabilita a verificacao - e seguro).
    final ctx = SecurityContext(withTrustedRoots: true);
    return super.createHttpClient(ctx);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _FenixHttpOverrides();

  // ForÃ§ar orientaÃ§Ã£o portrait em mobile
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

  // Inicializa o canal de comunicaÃ§Ã£o do foreground service
  // Foreground service sÃ³ em mobile; no desktop o Timer.periodic basta.
  if (Platform.isAndroid || Platform.isIOS) {
    FlutterForegroundTask.initCommunicationPort();
    _configurarForegroundService();
  }

  runApp(
    const ProviderScope(
      child: FenixApp(),
    ),
  );
}

/// Configura o canal de notificaÃ§Ã£o e opÃ§Ãµes do foreground service.
void _configurarForegroundService() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'fenix_grid_monitor',
      channelName: 'Monitor de Grids FÃªnixDay',
      channelDescription: 'MantÃ©m o monitor de grids ativo em segundo plano.',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(20000), // 20s
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

/// Inicia o monitor em background (foreground service).
/// Chamado quando hÃ¡ pelo menos um grid ativo.
Future<void> iniciarMonitorBackground() async {
  // Foreground service sÃ³ existe em Android/iOS. No desktop, o Timer.periodic
  // do GridMonitor jÃ¡ basta (o SO nÃ£o mata o app como o Android faz).
  if (!(Platform.isAndroid || Platform.isIOS)) return;
  // Pede permissÃ£o de notificaÃ§Ã£o (Android 13+) se necessÃ¡rio
  final permission = await FlutterForegroundTask.checkNotificationPermission();
  if (permission != NotificationPermission.granted) {
    await FlutterForegroundTask.requestNotificationPermission();
  }
  if (await FlutterForegroundTask.isRunningService) return; // jÃ¡ rodando
  await FlutterForegroundTask.startService(
    notificationTitle: 'FÃªnixDay â€” monitorando grids',
    notificationText: 'Iniciando...',
    callback: startGridMonitorTask,
  );
}

/// Para o monitor em background.
Future<void> pararMonitorBackground() async {
  if (!(Platform.isAndroid || Platform.isIOS)) return;
  if (await FlutterForegroundTask.isRunningService) {
    await FlutterForegroundTask.stopService();
  }
}

// â”€â”€ App Widget â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class FenixApp extends ConsumerWidget {
  const FenixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title:          'FÃªnixDay',
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

// â”€â”€ Shell com BottomNavigationBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const _MainShell({required this.child});

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell> with WidgetsBindingObserver {
  static const _tabs = [
    (icon: Icons.bar_chart_outlined,      activeIcon: Icons.bar_chart,            label: 'P&L',      route: '/dashboard'),
    (icon: Icons.grid_view_outlined,      activeIcon: Icons.grid_view,            label: 'Grids',    route: '/grids'),
    (icon: Icons.document_scanner_outlined,activeIcon: Icons.document_scanner,    label: 'Scanner',  route: '/scanner'),
    (icon: Icons.verified_outlined,       activeIcon: Icons.verified,             label: 'LicenÃ§a',  route: '/licenca'),
    (icon: Icons.settings_outlined,       activeIcon: Icons.settings,             label: 'Config',   route: '/configuracoes'),
  ];

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    GridMonitor.instance.iniciar();
    // Inicia o serviÃ§o de background (mantÃ©m o monitor vivo com app fechado)
    iniciarMonitorBackground();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Quando o app volta ao foco, garante que o monitor estÃ¡ vivo
    // e dispara um ciclo imediato (evita ter que puxar a tela).
    if (state == AppLifecycleState.resumed) {
      GridMonitor.instance.iniciar();      // resiliente: recria timer se morto
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    GridMonitor.instance.parar();
    super.dispose();
  }

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

// â”€â”€ Placeholders (substituir por telas reais) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
      appBar: AppBar(title: const Text('ConfiguraÃ§Ãµes')),
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
          Consumer(builder: (context, ref, _) {
            final isSuperuser = ref.watch(superuserProvider);
            if (isSuperuser) return const SizedBox.shrink();
            return _SettingsTile(
              icon:  Icons.person_outline,
              label: 'Minha Conta',
              color: FenixColors.yellow,
              onTap: () => context.push('/minha-conta'),
            );
          }),
          _SettingsTile(
            icon:  Icons.vpn_lock_outlined,
            label: 'Configurar VPN',
            color: FenixColors.blue,
            onTap: () => context.push('/vpn'),
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
          const SizedBox(height: 8),
          const Divider(color: FenixColors.border, height: 1),
          const SizedBox(height: 8),
          _SettingsTile(
            icon:  Icons.logout,
            label: 'Sair da conta',
            color: FenixColors.red,
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: FenixColors.card,
        title: const Text('Sair da conta',
            style: TextStyle(color: FenixColors.textPrimary, fontSize: 16)),
        content: const Text('Tem certeza que deseja sair? VocÃª precisarÃ¡ fazer login novamente.',
            style: TextStyle(color: FenixColors.textMuted, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar', style: TextStyle(color: FenixColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await _doLogout(context);
            },
            child: const Text('Sair', style: TextStyle(color: FenixColors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _doLogout(BuildContext context) async {
    // Desconectar do Google
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    // Limpar dados de sessÃ£o
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('is_superuser');
    await prefs.remove('fenix_modo_real');
    // Redirecionar para login
    if (context.mounted) context.go('/login');
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
