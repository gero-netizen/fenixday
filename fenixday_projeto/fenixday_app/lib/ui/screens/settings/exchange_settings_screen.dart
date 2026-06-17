/// FênixDay — Configuração de APIs das Corretoras
///
/// Exchanges suportadas:
///   • Binance  (Mainnet + Testnet)
///   • Bybit    (Mainnet + Testnet)
///   • OKX      (Live + Demo Trading)
///   • Bitget   (Mainnet + Testnet)
///   • MEXC     (Mainnet)
///   • Crypto.com (Live + Sandbox)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

import '../../theme/fenix_theme.dart';

// ── Constantes de storage ─────────────────────────────────────────────────────

const _kStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

String _keyApiKey(String exchange)  => 'fenix_${exchange}_api_key';
String _keySecret(String exchange)  => 'fenix_${exchange}_secret';
String _keyEnabled(String exchange) => 'fenix_${exchange}_enabled';
String _keyTestnet(String exchange) => 'fenix_${exchange}_testnet';
// OKX e Crypto.com precisam de passphrase
String _keyPassphrase(String exchange) => 'fenix_${exchange}_passphrase';

// ── Modelos ───────────────────────────────────────────────────────────────────

enum ExchangeId { binance, bybit, okx, bitget, mexc, cryptocom }

enum ConnectionStatus { idle, testing, ok, error }

class ExchangeConfig {
  final ExchangeId id;
  final String name;
  final Color color;
  final Color colorBg;
  final String apiKeyLabel;
  final String secretLabel;
  final String apiKeyHint;
  final String testnetLabel;
  final bool hasPassphrase;
  final String docsUrl;

  const ExchangeConfig({
    required this.id,
    required this.name,
    required this.color,
    required this.colorBg,
    required this.apiKeyLabel,
    required this.secretLabel,
    required this.apiKeyHint,
    required this.testnetLabel,
    this.hasPassphrase = false,
    required this.docsUrl,
  });
}

const _exchanges = {
  ExchangeId.binance: ExchangeConfig(
    id: ExchangeId.binance,
    name: 'Binance',
    color: FenixColors.yellow,
    colorBg: FenixColors.yellowBg,
    apiKeyLabel: 'API Key',
    secretLabel: 'Secret Key',
    apiKeyHint: 'Ex: AbCdEfGhIjKlMnOpQrStUvWxYz0123456789AbCd',
    testnetLabel: 'Usar Testnet (Modo Demo)',
    docsUrl: 'https://www.binance.com/pt-BR/support/faq/api',
  ),
  ExchangeId.bybit: ExchangeConfig(
    id: ExchangeId.bybit,
    name: 'Bybit',
    color: FenixColors.orange,
    colorBg: FenixColors.orangeBg,
    apiKeyLabel: 'API Key',
    secretLabel: 'API Secret',
    apiKeyHint: 'Ex: aBcDeFgHiJkLmNoPqRsT',
    testnetLabel: 'Usar Testnet',
    docsUrl: 'https://www.bybit.com/pt-BR/help-center/article/How-to-create-your-API-key',
  ),
  ExchangeId.okx: ExchangeConfig(
    id: ExchangeId.okx,
    name: 'OKX',
    color: FenixColors.blue,
    colorBg: FenixColors.blueBg,
    apiKeyLabel: 'API Key',
    secretLabel: 'Secret Key',
    apiKeyHint: 'Ex: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
    testnetLabel: 'Usar Demo Trading',
    hasPassphrase: true,
    docsUrl: 'https://www.okx.com/pt-br/account/my-api',
  ),
  ExchangeId.bitget: ExchangeConfig(
    id: ExchangeId.bitget,
    name: 'Bitget',
    color: FenixColors.green,
    colorBg: FenixColors.greenBg,
    apiKeyLabel: 'API Key',
    secretLabel: 'Secret Key',
    apiKeyHint: 'Ex: bg_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    testnetLabel: 'Usar Simulação',
    hasPassphrase: true,
    docsUrl: 'https://www.bitget.com/pt-BR/support/articles/10000007488',
  ),
  ExchangeId.mexc: ExchangeConfig(
    id: ExchangeId.mexc,
    name: 'MEXC',
    color: FenixColors.purple,
    colorBg: FenixColors.purpleBg,
    apiKeyLabel: 'Access Key',
    secretLabel: 'Secret Key',
    apiKeyHint: 'Ex: mx0vABCDEFGHIJKLMNOP',
    testnetLabel: 'Modo Demo',
    docsUrl: 'https://www.mexc.com/pt-BR/support/articles/360028112531',
  ),
  ExchangeId.cryptocom: ExchangeConfig(
    id: ExchangeId.cryptocom,
    name: 'Crypto.com',
    color: FenixColors.blue,
    colorBg: FenixColors.blueBg,
    apiKeyLabel: 'API Key',
    secretLabel: 'Secret Key',
    apiKeyHint: 'Ex: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
    testnetLabel: 'Usar Sandbox',
    docsUrl: 'https://exchange-docs.crypto.com/exchange/v1/rest-ws/index.html',
  ),
};

class _ExchangeState {
  final String apiKey;
  final String secret;
  final String passphrase;
  final bool enabled;
  final bool testnet;
  final ConnectionStatus status;
  final String? statusMessage;
  final DateTime? lastTested;

  const _ExchangeState({
    this.apiKey = '',
    this.secret = '',
    this.passphrase = '',
    this.enabled = false,
    this.testnet = false,
    this.status = ConnectionStatus.idle,
    this.statusMessage,
    this.lastTested,
  });

  bool get hasKeys => apiKey.isNotEmpty && secret.isNotEmpty;

  _ExchangeState copyWith({
    String? apiKey, String? secret, String? passphrase,
    bool? enabled, bool? testnet,
    ConnectionStatus? status, String? statusMessage, DateTime? lastTested,
  }) => _ExchangeState(
    apiKey: apiKey ?? this.apiKey,
    secret: secret ?? this.secret,
    passphrase: passphrase ?? this.passphrase,
    enabled: enabled ?? this.enabled,
    testnet: testnet ?? this.testnet,
    status: status ?? this.status,
    statusMessage: statusMessage ?? this.statusMessage,
    lastTested: lastTested ?? this.lastTested,
  );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _exchangeProvider = StateNotifierProvider.family<
    _ExchangeNotifier, _ExchangeState, ExchangeId>(
  (ref, id) => _ExchangeNotifier(id),
);

class _ExchangeNotifier extends StateNotifier<_ExchangeState> {
  final ExchangeId _id;
  _ExchangeNotifier(this._id) : super(const _ExchangeState()) {
    _loadFromStorage();
  }

  String get _name => _id.name;

  Future<void> _loadFromStorage() async {
    final apiKey     = await _kStorage.read(key: _keyApiKey(_name))     ?? '';
    final secret     = await _kStorage.read(key: _keySecret(_name))     ?? '';
    final passphrase = await _kStorage.read(key: _keyPassphrase(_name)) ?? '';
    final enabled    = (await _kStorage.read(key: _keyEnabled(_name)))  == 'true';
    final testnet    = (await _kStorage.read(key: _keyTestnet(_name)))  == 'true';
    state = state.copyWith(
      apiKey: apiKey, secret: secret, passphrase: passphrase,
      enabled: enabled, testnet: testnet,
    );
  }

  Future<void> saveKeys(String apiKey, String secret, {String passphrase = ''}) async {
    await Future.wait([
      _kStorage.write(key: _keyApiKey(_name),     value: apiKey.trim()),
      _kStorage.write(key: _keySecret(_name),     value: secret.trim()),
      _kStorage.write(key: _keyPassphrase(_name), value: passphrase.trim()),
    ]);
    state = state.copyWith(
      apiKey: apiKey.trim(), secret: secret.trim(),
      passphrase: passphrase.trim(),
      status: ConnectionStatus.idle, statusMessage: null,
    );
  }

  Future<void> setEnabled(bool v) async {
    await _kStorage.write(key: _keyEnabled(_name), value: v.toString());
    state = state.copyWith(enabled: v);
  }

  Future<void> setTestnet(bool v) async {
    await _kStorage.write(key: _keyTestnet(_name), value: v.toString());
    state = state.copyWith(testnet: v, status: ConnectionStatus.idle);
  }

  Future<void> deleteKeys() async {
    await Future.wait([
      _kStorage.delete(key: _keyApiKey(_name)),
      _kStorage.delete(key: _keySecret(_name)),
      _kStorage.delete(key: _keyPassphrase(_name)),
      _kStorage.delete(key: _keyEnabled(_name)),
      _kStorage.delete(key: _keyTestnet(_name)),
    ]);
    state = const _ExchangeState();
  }

  Future<void> testConnection() async {
    if (!state.hasKeys) return;
    state = state.copyWith(
      status: ConnectionStatus.testing,
      statusMessage: 'Testando conexão...',
    );
    try {
      final ok = await _testApi(
          _id, state.apiKey, state.secret, state.testnet,
          passphrase: state.passphrase);
      state = state.copyWith(
        status: ok ? ConnectionStatus.ok : ConnectionStatus.error,
        statusMessage: ok
            ? 'Conexão estabelecida com sucesso!'
            : 'Chave inválida ou sem permissão.',
        lastTested: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        status: ConnectionStatus.error,
        statusMessage: 'Erro de rede: $e',
      );
    }
  }
}

// ── Testa a API de cada exchange ──────────────────────────────────────────────

Future<bool> _testApi(ExchangeId id, String apiKey, String secret, bool testnet,
    {String passphrase = ''}) async {
  switch (id) {
    case ExchangeId.binance:  return _testBinance(apiKey, secret, testnet);
    case ExchangeId.bybit:    return _testBybit(apiKey, secret, testnet);
    case ExchangeId.okx:      return _testOkx(apiKey, secret, testnet, passphrase);
    case ExchangeId.bitget:   return _testBitget(apiKey, secret, testnet, passphrase);
    case ExchangeId.mexc:     return _testMexc(apiKey, secret);
    case ExchangeId.cryptocom: return _testCryptoCom(apiKey, secret, testnet);
  }
}

Future<bool> _testBinance(String apiKey, String secret, bool testnet) async {
  final base  = testnet ? 'https://testnet.binance.vision' : 'https://api.binance.com';
  final ts    = DateTime.now().millisecondsSinceEpoch.toString();
  final query = 'timestamp=$ts';
  final sig   = _hmacSha256(secret, query);
  try {
    final resp = await http.get(
      Uri.parse('$base/api/v3/account?$query&signature=$sig'),
      headers: {'X-MBX-APIKEY': apiKey},
    ).timeout(const Duration(seconds: 8));
    return resp.statusCode == 200;
  } catch (_) { return false; }
}

Future<bool> _testBybit(String apiKey, String secret, bool testnet) async {
  final base = testnet ? 'https://api-testnet.bybit.com' : 'https://api.bybit.com';
  final ts   = DateTime.now().millisecondsSinceEpoch.toString();
  final qs   = 'accountType=UNIFIED';
  final sig  = _hmacSha256(secret, '${ts}${apiKey}5000$qs');
  try {
    final resp = await http.get(
      Uri.parse('$base/v5/account/wallet-balance?accountType=UNIFIED'),
      headers: {
        'X-BAPI-API-KEY': apiKey, 'X-BAPI-TIMESTAMP': ts,
        'X-BAPI-SIGN': sig, 'X-BAPI-RECV-WINDOW': '5000',
      },
    ).timeout(const Duration(seconds: 8));
    return jsonDecode(resp.body)['retCode'] == 0;
  } catch (_) { return false; }
}

Future<bool> _testOkx(String apiKey, String secret, bool demo, String passphrase) async {
  final now = DateTime.now().toUtc();
  final ms  = now.millisecond.toString().padLeft(3, '0');
  final ts  = now.year.toString() + '-' + now.month.toString().padLeft(2, '0') + '-' + now.day.toString().padLeft(2, '0') + 'T' + now.hour.toString().padLeft(2, '0') + ':' + now.minute.toString().padLeft(2, '0') + ':' + now.second.toString().padLeft(2, '0') + '.' + ms + 'Z';
  final msg = '${ts}GET/api/v5/account/balance';
  final sig = base64.encode(
    Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(msg)).bytes,
  );
  try {
    final resp = await http.get(
      Uri.parse('https://www.okx.com/api/v5/account/balance'),
      headers: {
        'OK-ACCESS-KEY': apiKey, 'OK-ACCESS-SIGN': sig,
        'OK-ACCESS-TIMESTAMP': ts, 'OK-ACCESS-PASSPHRASE': passphrase,
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
        if (demo) 'x-simulated-trading': '1',
      },
    ).timeout(const Duration(seconds: 8));
    return jsonDecode(resp.body)['code'] == '0';
  } catch (_) { return false; }
}

Future<bool> _testBitget(String apiKey, String secret, bool demo, String passphrase) async {
  final ts  = DateTime.now().millisecondsSinceEpoch.toString();
  final msg = '${ts}GET/api/v2/account/info';
  final sig = base64.encode(
    Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(msg)).bytes,
  );
  try {
    final resp = await http.get(
      Uri.parse('https://api.bitget.com/api/v2/account/info'),
      headers: {
        'ACCESS-KEY': apiKey, 'ACCESS-SIGN': sig,
        'ACCESS-TIMESTAMP': ts, 'ACCESS-PASSPHRASE': passphrase,
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 8));
    final body = jsonDecode(resp.body);
    return body['code'] == '00000';
  } catch (_) { return false; }
}

Future<bool> _testMexc(String apiKey, String secret) async {
  final ts    = DateTime.now().millisecondsSinceEpoch.toString();
  final query = 'timestamp=$ts';
  final sig   = _hmacSha256(secret, query);
  try {
    final resp = await http.get(
      Uri.parse('https://api.mexc.com/api/v3/account?$query&signature=$sig'),
      headers: {'X-MEXC-APIKEY': apiKey},
    ).timeout(const Duration(seconds: 8));
    return resp.statusCode == 200;
  } catch (_) { return false; }
}

Future<bool> _testCryptoCom(String apiKey, String secret, bool sandbox) async {
  final base   = sandbox
      ? 'https://uat-api.3ona.co/exchange/v1'
      : 'https://api.crypto.com/exchange/v1';
  final nonce  = DateTime.now().millisecondsSinceEpoch.toString();
  final method = 'private/get-account-summary';
  final sigStr = '${method}${nonce}${apiKey}';
  final sig    = _hmacSha256(secret, sigStr);
  try {
    final resp = await http.post(
      Uri.parse('$base/$method'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': 1, 'method': method, 'api_key': apiKey,
        'params': {}, 'nonce': nonce, 'sig': sig,
      }),
    ).timeout(const Duration(seconds: 8));
    final body = jsonDecode(resp.body);
    return body['code'] == 0;
  } catch (_) { return false; }
}

String _hmacSha256(String secret, String data) {
  final hmac = Hmac(sha256, utf8.encode(secret));
  return hmac.convert(utf8.encode(data)).toString();
}

// ── Tela principal ────────────────────────────────────────────────────────────

class ExchangeSettingsScreen extends ConsumerWidget {
  const ExchangeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: FenixColors.bg,
      appBar: AppBar(
        backgroundColor: FenixColors.surface,
        elevation: 0,
        title: const Text('Configurar Corretoras',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500,
                color: FenixColors.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 18, color: FenixColors.textMuted),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SecurityBanner(),
            const SizedBox(height: 16),
            for (final id in ExchangeId.values) ...[
              _ExchangeCard(exchangeId: id),
              const SizedBox(height: 12),
            ],
            _PermissionsTip(),
          ],
        ),
      ),
    );
  }
}

// ── Banner de segurança ───────────────────────────────────────────────────────

class _SecurityBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: FenixColors.greenBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: FenixColors.green.withOpacity(.3), width: .5),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.security, size: 18, color: FenixColors.green),
        SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Armazenamento 100% seguro',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                    color: FenixColors.green)),
            SizedBox(height: 3),
            Text(
              'Suas chaves são criptografadas pelo hardware do dispositivo '
              '(Android Keystore / iOS Keychain) e NUNCA são enviadas ao servidor.',
              style: TextStyle(fontSize: 11, color: FenixColors.textMuted, height: 1.4),
            ),
          ],
        )),
      ],
    ),
  );
}

// ── Card de exchange ──────────────────────────────────────────────────────────

class _ExchangeCard extends ConsumerStatefulWidget {
  final ExchangeId exchangeId;
  const _ExchangeCard({required this.exchangeId});

  @override
  ConsumerState<_ExchangeCard> createState() => _ExchangeCardState();
}

class _ExchangeCardState extends ConsumerState<_ExchangeCard> {
  final _apiCtrl        = TextEditingController();
  final _secretCtrl     = TextEditingController();
  final _passphraseCtrl = TextEditingController();
  bool _showSecret  = false;
  bool _editing     = false;

  @override
  void dispose() {
    _apiCtrl.dispose();
    _secretCtrl.dispose();
    _passphraseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(_exchangeProvider(widget.exchangeId));
    final notifier = ref.read(_exchangeProvider(widget.exchangeId).notifier);
    final cfg      = _exchanges[widget.exchangeId]!;

    if (_editing) {
      if (_apiCtrl.text.isEmpty && state.apiKey.isNotEmpty)
        _apiCtrl.text = state.apiKey;
      if (_secretCtrl.text.isEmpty && state.secret.isNotEmpty)
        _secretCtrl.text = state.secret;
      if (_passphraseCtrl.text.isEmpty && state.passphrase.isNotEmpty)
        _passphraseCtrl.text = state.passphrase;
    }

    return Container(
      decoration: BoxDecoration(
        color: FenixColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: state.enabled ? cfg.color.withOpacity(.3) : FenixColors.border,
          width: .5,
        ),
      ),
      child: Column(children: [
        // ── Header ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: cfg.colorBg, borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Text(cfg.name[0],
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: cfg.color))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cfg.name, style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w500, color: FenixColors.textPrimary)),
                const SizedBox(height: 2),
                if (state.hasKeys)
                  _StatusChip(status: state.status, message: state.statusMessage)
                else
                  const Text('Chaves não configuradas',
                      style: TextStyle(fontSize: 10, color: FenixColors.textMuted)),
              ],
            )),
            if (state.hasKeys)
              Switch(
                value: state.enabled, onChanged: notifier.setEnabled,
                activeColor: cfg.color,
                inactiveThumbColor: FenixColors.textMuted,
                inactiveTrackColor: FenixColors.border,
              ),
          ]),
        ),

        // ── Formulário ──────────────────────────────────────────────
        if (_editing || !state.hasKeys) ...[
          const Divider(height: 0, thickness: .5, color: FenixColors.border),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // API Key
                Text(cfg.apiKeyLabel,
                    style: const TextStyle(fontSize: 11, color: FenixColors.textMuted)),
                const SizedBox(height: 5),
                TextField(
                  controller: _apiCtrl,
                  style: const TextStyle(fontFamily: 'RobotoMono',
                      fontSize: 12, color: FenixColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: cfg.apiKeyHint,
                    hintStyle: const TextStyle(fontSize: 11, color: FenixColors.textMuted),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.content_paste_outlined,
                          size: 16, color: FenixColors.textMuted),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) _apiCtrl.text = data!.text!.trim();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Secret Key
                Text(cfg.secretLabel,
                    style: const TextStyle(fontSize: 11, color: FenixColors.textMuted)),
                const SizedBox(height: 5),
                TextField(
                  controller: _secretCtrl,
                  obscureText: !_showSecret,
                  style: const TextStyle(fontFamily: 'RobotoMono',
                      fontSize: 12, color: FenixColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '••••••••••••••••••••••••',
                    hintStyle: const TextStyle(fontSize: 11, color: FenixColors.textMuted),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showSecret ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 16, color: FenixColors.textMuted,
                      ),
                      onPressed: () => setState(() => _showSecret = !_showSecret),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Passphrase (OKX, Bitget, Crypto.com)
                if (cfg.hasPassphrase) ...[
                  const Text('Passphrase',
                      style: TextStyle(fontSize: 11, color: FenixColors.textMuted)),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _passphraseCtrl,
                    style: const TextStyle(fontFamily: 'RobotoMono',
                        fontSize: 12, color: FenixColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Sua passphrase da API',
                      hintStyle: TextStyle(fontSize: 11, color: FenixColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Testnet toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(cfg.testnetLabel,
                        style: const TextStyle(fontSize: 12,
                            color: FenixColors.textSecondary)),
                    Switch(
                      value: state.testnet, onChanged: notifier.setTestnet,
                      activeColor: FenixColors.orange,
                      inactiveThumbColor: FenixColors.textMuted,
                      inactiveTrackColor: FenixColors.border,
                    ),
                  ],
                ),
                if (state.testnet)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: FenixColors.orangeBg,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Row(children: [
                      Icon(Icons.science_outlined, size: 13, color: FenixColors.orange),
                      SizedBox(width: 6),
                      Text('Modo Demo ativo — nenhuma ordem real será executada',
                          style: TextStyle(fontSize: 10, color: FenixColors.orange)),
                    ]),
                  ),
                const SizedBox(height: 14),

                // Botões
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FenixColors.textMuted,
                        side: const BorderSide(color: FenixColors.border, width: .5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => setState(() => _editing = false),
                      child: const Text('Cancelar', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cfg.color,
                        foregroundColor: FenixColors.bg,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.save_outlined, size: 15),
                      label: const Text('Salvar com segurança',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      onPressed: () async {
                        if (_apiCtrl.text.isEmpty || _secretCtrl.text.isEmpty) return;
                        await notifier.saveKeys(
                          _apiCtrl.text, _secretCtrl.text,
                          passphrase: _passphraseCtrl.text,
                        );
                        setState(() => _editing = false);
                      },
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],

        // ── Ações ───────────────────────────────────────────────────
        if (state.hasKeys && !_editing) ...[
          const Divider(height: 0, thickness: .5, color: FenixColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              if (state.testnet)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: FenixColors.orangeBg, borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('DEMO / TESTNET',
                      style: TextStyle(fontFamily: 'RobotoMono',
                          fontSize: 8, fontWeight: FontWeight.w700,
                          color: FenixColors.orange)),
                )
              else
                Text(
                  '${state.apiKey.substring(0, state.apiKey.length.clamp(0, 6))}••••••',
                  style: const TextStyle(fontFamily: 'RobotoMono',
                      fontSize: 11, color: FenixColors.textMuted),
                ),
              const Spacer(),
              if (state.status == ConnectionStatus.testing)
                const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5,
                        color: FenixColors.textMuted))
              else
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  icon: const Icon(Icons.wifi_tethering, size: 14, color: FenixColors.textMuted),
                  label: const Text('Testar',
                      style: TextStyle(fontSize: 11, color: FenixColors.textMuted)),
                  onPressed: notifier.testConnection,
                ),
              const SizedBox(width: 4),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
                icon: const Icon(Icons.edit_outlined, size: 14, color: FenixColors.textMuted),
                label: const Text('Editar',
                    style: TextStyle(fontSize: 11, color: FenixColors.textMuted)),
                onPressed: () => setState(() => _editing = true),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
                icon: const Icon(Icons.delete_outline, size: 14, color: FenixColors.red),
                label: const Text('Excluir',
                    style: TextStyle(fontSize: 11, color: FenixColors.red)),
                onPressed: () => _confirmDelete(context, notifier, cfg),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Future<void> _confirmDelete(BuildContext context, _ExchangeNotifier notifier,
      ExchangeConfig cfg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: FenixColors.card,
        title: Text('Excluir chaves da ${cfg.name}?',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                color: FenixColors.textPrimary)),
        content: const Text(
          'As chaves serão removidas permanentemente do armazenamento seguro do dispositivo.',
          style: TextStyle(fontSize: 12, color: FenixColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: FenixColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir',
                style: TextStyle(color: FenixColors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm == true) await notifier.deleteKeys();
  }
}

// ── Chip de status ────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final ConnectionStatus status;
  final String? message;
  const _StatusChip({required this.status, this.message});

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (status) {
      ConnectionStatus.idle    => (FenixColors.textMuted, Icons.circle_outlined,   'Não testado'),
      ConnectionStatus.testing => (FenixColors.yellow,    Icons.hourglass_top,     'Testando...'),
      ConnectionStatus.ok      => (FenixColors.green,     Icons.check_circle_outline, 'Conectado'),
      ConnectionStatus.error   => (FenixColors.red,       Icons.error_outline,     'Erro'),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 4),
      Text(
        status == ConnectionStatus.error && message != null
            ? message!.length > 30 ? '${message!.substring(0, 30)}...' : message!
            : label,
        style: TextStyle(fontSize: 10, color: color),
      ),
    ]);
  }
}

// ── Dica sobre permissões ─────────────────────────────────────────────────────

class _PermissionsTip extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: FenixColors.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: FenixColors.border, width: .5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [
          Icon(Icons.shield_outlined, size: 14, color: FenixColors.yellow),
          SizedBox(width: 6),
          Text('Permissões recomendadas para a API Key',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                  color: FenixColors.textPrimary)),
        ]),
        const SizedBox(height: 10),
        ...const [
          ('Leitura de conta', true),
          ('Spot Trading', true),
          ('Futuros', false),
          ('Saque', false),
          ('Transferência interna', false),
        ].map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(
              item.$2 ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 14,
              color: item.$2 ? FenixColors.green : FenixColors.red,
            ),
            const SizedBox(width: 8),
            Text(item.$1,
                style: const TextStyle(fontSize: 12, color: FenixColors.textSecondary)),
            if (!item.$2)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text('NÃO ativar',
                    style: TextStyle(fontSize: 10, color: FenixColors.red)),
              ),
          ]),
        )),
        const SizedBox(height: 8),
        const Text(
          '⚠ Nunca ative permissão de SAQUE. O bot só precisa de Spot Trading.',
          style: TextStyle(fontSize: 10, color: FenixColors.orange, height: 1.4),
        ),
      ],
    ),
  );
}
