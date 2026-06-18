/// FênixDay — Configuração de VPN WireGuard

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../theme/fenix_theme.dart';

const _kStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
);

class _VpnConfig {
  final String server, publicKey, allowedIPs, dns;
  final int port;
  final bool configured;
  const _VpnConfig({
    this.server = '', this.publicKey = '',
    this.allowedIPs = '10.0.0.0/24', this.dns = '8.8.8.8',
    this.port = 13231, this.configured = false,
  });
}

class _VpnNotifier extends StateNotifier<_VpnConfig> {
  _VpnNotifier() : super(const _VpnConfig()) { _load(); }

  Future<void> _load() async {
    final server    = await _kStorage.read(key: 'fenix_wg_server')     ?? '';
    final publicKey = await _kStorage.read(key: 'fenix_wg_pubkey')     ?? '';
    final allowedIPs= await _kStorage.read(key: 'fenix_wg_allowed')    ?? '10.0.0.0/24';
    final dns       = await _kStorage.read(key: 'fenix_wg_dns')        ?? '8.8.8.8';
    final portStr   = await _kStorage.read(key: 'fenix_wg_port')       ?? '13231';
    state = _VpnConfig(
      server: server, publicKey: publicKey, allowedIPs: allowedIPs,
      dns: dns, port: int.tryParse(portStr) ?? 13231,
      configured: server.isNotEmpty && publicKey.isNotEmpty,
    );
  }

  Future<void> save(String server, String publicKey, String allowedIPs,
      String dns, int port) async {
    await Future.wait([
      _kStorage.write(key: 'fenix_wg_server',  value: server.trim()),
      _kStorage.write(key: 'fenix_wg_pubkey',  value: publicKey.trim()),
      _kStorage.write(key: 'fenix_wg_allowed', value: allowedIPs.trim()),
      _kStorage.write(key: 'fenix_wg_dns',     value: dns.trim()),
      _kStorage.write(key: 'fenix_wg_port',    value: port.toString()),
    ]);
    state = _VpnConfig(server: server.trim(), publicKey: publicKey.trim(),
        allowedIPs: allowedIPs.trim(), dns: dns.trim(), port: port,
        configured: true);
  }

  Future<void> clear() async {
    await Future.wait([
      _kStorage.delete(key: 'fenix_wg_server'),
      _kStorage.delete(key: 'fenix_wg_pubkey'),
      _kStorage.delete(key: 'fenix_wg_allowed'),
      _kStorage.delete(key: 'fenix_wg_dns'),
      _kStorage.delete(key: 'fenix_wg_port'),
    ]);
    state = const _VpnConfig();
  }
}

final vpnProvider = StateNotifierProvider<_VpnNotifier, _VpnConfig>(
    (ref) => _VpnNotifier());

class VpnSettingsScreen extends ConsumerStatefulWidget {
  const VpnSettingsScreen({super.key});
  @override
  ConsumerState<VpnSettingsScreen> createState() => _VpnSettingsScreenState();
}

class _VpnSettingsScreenState extends ConsumerState<VpnSettingsScreen> {
  final _serverCtrl     = TextEditingController();
  final _pubkeyCtrl     = TextEditingController();
  final _allowedCtrl    = TextEditingController(text: '10.0.0.0/24');
  final _dnsCtrl        = TextEditingController(text: '8.8.8.8');
  final _portCtrl       = TextEditingController(text: '13231');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cfg = ref.read(vpnProvider);
      if (cfg.configured) {
        _serverCtrl.text  = cfg.server;
        _pubkeyCtrl.text  = cfg.publicKey;
        _allowedCtrl.text = cfg.allowedIPs;
        _dnsCtrl.text     = cfg.dns;
        _portCtrl.text    = cfg.port.toString();
      }
    });
  }

  @override
  void dispose() {
    _serverCtrl.dispose(); _pubkeyCtrl.dispose();
    _allowedCtrl.dispose(); _dnsCtrl.dispose(); _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_serverCtrl.text.trim().isEmpty || _pubkeyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Servidor e Public Key são obrigatórios'),
        backgroundColor: FenixColors.red,
      ));
      return;
    }
    await ref.read(vpnProvider.notifier).save(
      _serverCtrl.text, _pubkeyCtrl.text, _allowedCtrl.text,
      _dnsCtrl.text, int.tryParse(_portCtrl.text) ?? 13231,
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Configurações WireGuard salvas'),
      backgroundColor: FenixColors.green,
    ));
  }

  void _copyConfig() {
    final cfg = ref.read(vpnProvider);
    if (!cfg.configured) return;
    final text = '''[Peer]
PublicKey = ${cfg.publicKey}
Endpoint = ${cfg.server}:${cfg.port}
AllowedIPs = ${cfg.allowedIPs}
PersistentKeepalive = 25''';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Configuração copiada para a área de transferência'),
      backgroundColor: FenixColors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(vpnProvider);
    return Scaffold(
      backgroundColor: FenixColors.bg,
      appBar: AppBar(
        backgroundColor: FenixColors.surface,
        elevation: 0,
        title: const Text('Configurar VPN', style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w500, color: FenixColors.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 18, color: FenixColors.textMuted),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner segurança
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FenixColors.greenBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: FenixColors.green.withOpacity(.3), width: .5),
            ),
            child: const Row(children: [
              Icon(Icons.shield_outlined, size: 16, color: FenixColors.green),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Protocolo WireGuard — mais rápido e seguro que L2TP/IPsec.',
                style: TextStyle(fontSize: 11, color: FenixColors.green),
              )),
            ]),
          ),
          const SizedBox(height: 16),

          // Status
          if (cfg.configured) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FenixColors.yellowBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FenixColors.yellow.withOpacity(.3), width: .5),
              ),
              child: Row(children: [
                const Icon(Icons.vpn_lock, size: 16, color: FenixColors.yellow),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('WireGuard configurado', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: FenixColors.yellow)),
                  Text('Servidor: ${cfg.server}:${cfg.port}',
                      style: const TextStyle(fontSize: 10, color: FenixColors.textMuted)),
                ])),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16, color: FenixColors.yellow),
                  onPressed: _copyConfig,
                  tooltip: 'Copiar config peer',
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Config para copiar no WireGuard
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FenixColors.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FenixColors.border, width: .5),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Configuração [Peer]', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: FenixColors.blue)),
                  GestureDetector(
                    onTap: _copyConfig,
                    child: const Row(children: [
                      Icon(Icons.copy, size: 12, color: FenixColors.blue),
                      SizedBox(width: 4),
                      Text('Copiar', style: TextStyle(fontSize: 10, color: FenixColors.blue)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FenixColors.bg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '[Peer]\nPublicKey = ${cfg.publicKey}\nEndpoint = ${cfg.server}:${cfg.port}\nAllowedIPs = ${cfg.allowedIPs}\nPersistentKeepalive = 25',
                    style: const TextStyle(fontFamily: 'RobotoMono',
                        fontSize: 9, color: FenixColors.textSecondary, height: 1.6),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // Campos
          _label('Servidor (IP do MikroTik)'),
          _field(_serverCtrl, hint: 'Ex: 45.164.135.92', icon: Icons.dns_outlined),
          const SizedBox(height: 12),

          _label('Public Key do servidor MikroTik'),
          _field(_pubkeyCtrl, hint: 'Ex: rwGqmXDb...', icon: Icons.key_outlined),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Porta UDP'),
              _field(_portCtrl, hint: '13231', icon: Icons.router_outlined,
                  keyboard: TextInputType.number),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('DNS'),
              _field(_dnsCtrl, hint: '8.8.8.8', icon: Icons.dns),
            ])),
          ]),
          const SizedBox(height: 12),

          _label('AllowedIPs'),
          _field(_allowedCtrl, hint: '10.0.0.0/24', icon: Icons.route_outlined),
          const SizedBox(height: 8),
          const Text('Use 10.0.0.0/24 para só rotear o FênixDay, ou 0.0.0.0/0 para todo tráfego.',
              style: TextStyle(fontSize: 10, color: FenixColors.textMuted)),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: FenixColors.yellow,
                foregroundColor: const Color(0xFF1A0A00),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('Salvar configuração',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              onPressed: _save,
            ),
          ),
          if (cfg.configured) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: FenixColors.red,
                  side: BorderSide(color: FenixColors.red.withOpacity(.3), width: .5),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Remover configuração', style: TextStyle(fontSize: 13)),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: FenixColors.card,
                      title: const Text('Remover VPN?', style: TextStyle(
                          fontSize: 14, color: FenixColors.textPrimary)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar',
                                style: TextStyle(color: FenixColors.textMuted))),
                        TextButton(onPressed: () => Navigator.pop(context, true),
                            child: const Text('Remover',
                                style: TextStyle(color: FenixColors.red))),
                      ],
                    ),
                  );
                  if (ok == true) await ref.read(vpnProvider.notifier).clear();
                },
              ),
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 12, color: FenixColors.textSecondary)),
  );

  Widget _field(TextEditingController ctrl,
      {required String hint, required IconData icon,
      TextInputType keyboard = TextInputType.text}) =>
      Container(
        decoration: BoxDecoration(
          color: FenixColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FenixColors.border, width: .5),
        ),
        child: TextField(
          controller: ctrl,
          keyboardType: keyboard,
          style: const TextStyle(fontSize: 12, color: FenixColors.textPrimary,
              fontFamily: 'RobotoMono'),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 11, color: FenixColors.textMuted,
                fontFamily: 'RobotoMono'),
            prefixIcon: Icon(icon, size: 16, color: FenixColors.textMuted),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      );
}
