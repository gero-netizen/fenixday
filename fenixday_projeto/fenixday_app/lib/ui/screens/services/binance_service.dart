/// FênixDay — Serviço Binance
/// Busca dados reais da Binance usando as chaves salvas no SecureStorage

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

// ── Storage (mesmas chaves do exchange_settings_screen) ───────────────────────

const _kStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

// ── Modelos ───────────────────────────────────────────────────────────────────

class BinanceBalance {
  final String asset;
  final double free;
  final double locked;
  const BinanceBalance({required this.asset, required this.free, required this.locked});
  double get total => free + locked;
}

class BinanceOrder {
  final String symbol;
  final String side;       // BUY | SELL
  final String status;     // FILLED | NEW | PARTIALLY_FILLED
  final double price;
  final double qty;
  final double executedQty;
  final DateTime time;

  const BinanceOrder({
    required this.symbol,
    required this.side,
    required this.status,
    required this.price,
    required this.qty,
    required this.executedQty,
    required this.time,
  });
}

class BinanceTicker {
  final String symbol;
  final double price;
  const BinanceTicker({required this.symbol, required this.price});
}

class BinanceDashboardData {
  // Saldos
  final List<BinanceBalance> balances;
  final double totalUsdtValue;  // valor total em USDT

  // Ordens recentes (últimas 50)
  final List<BinanceOrder> recentOrders;

  // Preços atuais dos ativos com saldo
  final Map<String, double> prices;

  // P&L calculado
  final double unrealizedPnl;   // diferença entre preço médio e preço atual
  final double realizedPnlHoje; // ciclos fechados hoje (SELL - BUY médio)
  final int ciclosFechadosHoje;

  // Status
  final bool isTestnet;
  final DateTime fetchedAt;
  final String? error;

  const BinanceDashboardData({
    required this.balances,
    required this.totalUsdtValue,
    required this.recentOrders,
    required this.prices,
    required this.unrealizedPnl,
    required this.realizedPnlHoje,
    required this.ciclosFechadosHoje,
    required this.isTestnet,
    required this.fetchedAt,
    this.error,
  });

  static BinanceDashboardData empty() => BinanceDashboardData(
    balances: [],
    totalUsdtValue: 0,
    recentOrders: [],
    prices: {},
    unrealizedPnl: 0,
    realizedPnlHoje: 0,
    ciclosFechadosHoje: 0,
    isTestnet: false,
    fetchedAt: DateTime.now(),
  );

  static BinanceDashboardData withError(String error) => BinanceDashboardData(
    balances: [],
    totalUsdtValue: 0,
    recentOrders: [],
    prices: {},
    unrealizedPnl: 0,
    realizedPnlHoje: 0,
    ciclosFechadosHoje: 0,
    isTestnet: false,
    fetchedAt: DateTime.now(),
    error: error,
  );
}

// ── Serviço principal ─────────────────────────────────────────────────────────

class BinanceService {
  static const _mainnet = 'https://api.binance.com';
  static const _testnetUrl = 'https://testnet.binance.vision';

  String? _apiKey;
  String? _secret;
  bool _testnet = false;
  bool _configured = false;

  Future<void> loadCredentials() async {
    _apiKey  = await _kStorage.read(key: 'fenix_binance_api_key');
    _secret  = await _kStorage.read(key: 'fenix_binance_secret');
    _testnet = (await _kStorage.read(key: 'fenix_binance_testnet')) == 'true';
    _configured = (_apiKey?.isNotEmpty == true) && (_secret?.isNotEmpty == true);
  }

  bool get isConfigured => _configured;
  bool get isTestnet    => _testnet;

  String get _base => _testnet ? _testnetUrl : _mainnet;

  // ── Assina requisição ─────────────────────────────────────────────────────
  String _sign(String query) {
    final hmac = Hmac(sha256, utf8.encode(_secret!));
    return hmac.convert(utf8.encode(query)).toString();
  }

  Map<String, String> get _headers => {'X-MBX-APIKEY': _apiKey!};

  Uri _signedUri(String path, [Map<String, String>? params]) {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final p  = {'timestamp': ts, ...?params};
    final query = p.entries.map((e) => '${e.key}=${e.value}').join('&');
    final sig   = _sign(query);
    return Uri.parse('$_base$path?$query&signature=$sig');
  }

  // ── Busca saldos da conta ─────────────────────────────────────────────────
  Future<List<BinanceBalance>> fetchBalances() async {
    final resp = await http.get(_signedUri('/api/v3/account'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('Erro ao buscar saldo: ${resp.body}');
    final data = jsonDecode(resp.body);
    final List balances = data['balances'] ?? [];
    return balances
        .map((b) => BinanceBalance(
              asset:  b['asset'],
              free:   double.tryParse(b['free'].toString())   ?? 0,
              locked: double.tryParse(b['locked'].toString()) ?? 0,
            ))
        .where((b) => b.total > 0)
        .toList();
  }

  // ── Busca preço atual de um par ───────────────────────────────────────────
  Future<double> fetchPrice(String symbol) async {
    try {
      final resp = await http.get(
        Uri.parse('${_testnet ? _testnetUrl : _mainnet}/api/v3/ticker/price?symbol=$symbol'),
      ).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return 0;
      return double.tryParse(jsonDecode(resp.body)['price'].toString()) ?? 0;
    } catch (_) { return 0; }
  }

  // ── Busca preços de múltiplos pares ──────────────────────────────────────
  Future<Map<String, double>> fetchPrices(List<String> symbols) async {
    if (symbols.isEmpty) return {};
    try {
      final symbolsJson = jsonEncode(symbols);
      final resp = await http.get(
        Uri.parse('${_testnet ? _testnetUrl : _mainnet}/api/v3/ticker/price'
            '?symbols=${Uri.encodeComponent(symbolsJson)}'),
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return {};
      final List data = jsonDecode(resp.body);
      return {for (final d in data) d['symbol'] as String: double.tryParse(d['price'].toString()) ?? 0};
    } catch (_) { return {}; }
  }

  // ── Busca ordens recentes de um símbolo ───────────────────────────────────
  Future<List<BinanceOrder>> fetchRecentOrders(String symbol, {int limit = 20}) async {
    final resp = await http.get(
      _signedUri('/api/v3/allOrders', {'symbol': symbol, 'limit': '$limit'}),
      headers: _headers,
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return [];
    final List data = jsonDecode(resp.body);
    return data
        .where((o) => o['status'] == 'FILLED')
        .map((o) => BinanceOrder(
              symbol:      o['symbol'],
              side:        o['side'],
              status:      o['status'],
              price:       double.tryParse(o['price'].toString()) ?? 0,
              qty:         double.tryParse(o['origQty'].toString()) ?? 0,
              executedQty: double.tryParse(o['executedQty'].toString()) ?? 0,
              time: DateTime.fromMillisecondsSinceEpoch(o['time']),
            ))
        .toList()
        .reversed
        .toList();
  }

  // ── Busca todas as ordens recentes (múltiplos pares) ──────────────────────
  Future<List<BinanceOrder>> fetchAllRecentOrders(List<String> symbols) async {
    final allOrders = <BinanceOrder>[];
    for (final symbol in symbols.take(5)) { // limita a 5 pares para não sobrecarregar
      try {
        final orders = await fetchRecentOrders(symbol, limit: 10);
        allOrders.addAll(orders);
      } catch (_) {}
    }
    allOrders.sort((a, b) => b.time.compareTo(a.time));
    return allOrders.take(20).toList();
  }

  // ── Calcula P&L de ciclos de grid ────────────────────────────────────────
  _GridPnl _calcGridPnl(List<BinanceOrder> orders) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    double realizedPnl = 0;
    int ciclos = 0;

    // Agrupa ordens por símbolo e calcula ciclos (BUY → SELL)
    final Map<String, List<BinanceOrder>> bySymbol = {};
    for (final o in orders) {
      bySymbol.putIfAbsent(o.symbol, () => []).add(o);
    }

    for (final symbolOrders in bySymbol.values) {
      final buys  = symbolOrders.where((o) => o.side == 'BUY').toList();
      final sells = symbolOrders.where((o) =>
          o.side == 'SELL' && o.time.isAfter(startOfDay)).toList();

      if (buys.isEmpty || sells.isEmpty) continue;

      final avgBuyPrice = buys.map((o) => o.price).reduce((a, b) => a + b) / buys.length;

      for (final sell in sells) {
        final profit = (sell.price - avgBuyPrice) * sell.executedQty;
        realizedPnl += profit;
        ciclos++;
      }
    }

    return _GridPnl(realizedPnl: realizedPnl, ciclos: ciclos);
  }

  // ── Busca todos os dados do dashboard ────────────────────────────────────
  Future<BinanceDashboardData> fetchDashboardData() async {
    await loadCredentials();

    if (!_configured) {
      return BinanceDashboardData.withError('Binance não configurada. Configure as chaves em Configurações → Corretoras.');
    }

    try {
      // 1. Saldos
      final balances = await fetchBalances();
      final nonUsdtBalances = balances.where((b) => b.asset != 'USDT').toList();
      final usdtBalance = balances.where((b) => b.asset == 'USDT').fold(0.0, (s, b) => s + b.total);

      // 2. Preços dos ativos
      final symbols = nonUsdtBalances.map((b) => '${b.asset}USDT').toList();
      final prices  = await fetchPrices(symbols);

      // 3. Valor total em USDT
      double totalUsdt = usdtBalance;
      for (final b in nonUsdtBalances) {
        final price = prices['${b.asset}USDT'] ?? 0;
        totalUsdt += b.total * price;
      }

      // 4. Ordens recentes
      final recentOrders = await fetchAllRecentOrders(
        nonUsdtBalances.map((b) => '${b.asset}USDT').toList()
      );

      // 5. P&L calculado
      final pnl = _calcGridPnl(recentOrders);

      // 6. P&L não realizado (diferença entre preço atual e preço médio de compra)
      double unrealizedPnl = 0;
      for (final b in nonUsdtBalances) {
        final currentPrice = prices['${b.asset}USDT'] ?? 0;
        if (currentPrice > 0) {
          // Estimativa simples — futuramente usar preço médio real da Binance
          unrealizedPnl += 0; // será implementado com /api/v3/myTrades
        }
      }

      return BinanceDashboardData(
        balances: balances,
        totalUsdtValue: totalUsdt,
        recentOrders: recentOrders,
        prices: prices,
        unrealizedPnl: unrealizedPnl,
        realizedPnlHoje: pnl.realizedPnl,
        ciclosFechadosHoje: pnl.ciclos,
        isTestnet: _testnet,
        fetchedAt: DateTime.now(),
      );
    } catch (e) {
      return BinanceDashboardData.withError('Erro ao buscar dados: $e');
    }
  }
}

class _GridPnl {
  final double realizedPnl;
  final int ciclos;
  const _GridPnl({required this.realizedPnl, required this.ciclos});
}
