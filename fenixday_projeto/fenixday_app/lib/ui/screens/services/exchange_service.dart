/// FênixDay — Serviço Unificado de Exchanges v2
/// Binance + Bybit com dados separados por exchange

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _kStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

// ── Modelos ───────────────────────────────────────────────────────────────────

class ExchangeBalance {
  final String exchange;
  final String asset;
  final double free;
  final double locked;
  const ExchangeBalance({
    required this.exchange,
    required this.asset,
    required this.free,
    required this.locked,
  });
  double get total => free + locked;
}

class ExchangeOrder {
  final String exchange;
  final String symbol;
  final String side;
  final double price;
  final double executedQty;
  final DateTime time;
  const ExchangeOrder({
    required this.exchange,
    required this.symbol,
    required this.side,
    required this.price,
    required this.executedQty,
    required this.time,
  });
}

// Dados por exchange individual
class ExchangeSnapshot {
  final String name;
  final List<ExchangeBalance> balances;
  final double totalUsdt;
  final List<ExchangeOrder> orders;
  final Map<String, double> prices;
  final String? error;
  final bool configured;
  final bool isTestnet;

  const ExchangeSnapshot({
    required this.name,
    required this.balances,
    required this.totalUsdt,
    required this.orders,
    required this.prices,
    this.error,
    required this.configured,
    required this.isTestnet,
  });

  bool get hasData => balances.isNotEmpty;
}

class ExchangeDashboardData {
  final List<ExchangeBalance> balances;
  final double totalUsdtValue;
  final List<ExchangeOrder> recentOrders;
  final Map<String, double> prices;
  final double realizedPnlHoje;
  final int ciclosFechadosHoje;
  final List<String> activeExchanges;
  final DateTime fetchedAt;
  final Map<String, String?> errors;
  final Map<String, ExchangeSnapshot> snapshots; // dados por exchange
  final bool modoReal; // lido do SecureStorage

  const ExchangeDashboardData({
    required this.balances,
    required this.totalUsdtValue,
    required this.recentOrders,
    required this.prices,
    required this.realizedPnlHoje,
    required this.ciclosFechadosHoje,
    required this.activeExchanges,
    required this.fetchedAt,
    required this.errors,
    required this.snapshots,
    required this.modoReal,
  });

  bool get hasError => errors.values.any((e) => e != null);
  bool get hasData  => balances.isNotEmpty;

  static ExchangeDashboardData empty() => ExchangeDashboardData(
    balances: [], totalUsdtValue: 0, recentOrders: [],
    prices: {}, realizedPnlHoje: 0, ciclosFechadosHoje: 0,
    activeExchanges: [], fetchedAt: DateTime.now(), errors: {},
    snapshots: {}, modoReal: false,
  );
}

// ── Helper HMAC ───────────────────────────────────────────────────────────────

String _hmac(String secret, String data) =>
    Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(data)).toString();

// ── Serviço Binance ───────────────────────────────────────────────────────────

class _BinanceService {
  static const _mainnet    = 'https://api.binance.com';
  static const _testnetUrl = 'https://testnet.binance.vision';

  String? apiKey, secret;
  bool testnet = false, configured = false;

  Future<void> load() async {
    apiKey     = await _kStorage.read(key: 'fenix_binance_api_key');
    secret     = await _kStorage.read(key: 'fenix_binance_secret');
    testnet    = (await _kStorage.read(key: 'fenix_binance_testnet')) == 'true';
    configured = (apiKey?.isNotEmpty == true) && (secret?.isNotEmpty == true);
  }

  String get _base => testnet ? _testnetUrl : _mainnet;

  Uri _signed(String path, [Map<String, String>? p]) {
    final ts     = DateTime.now().millisecondsSinceEpoch.toString();
    final params = {'timestamp': ts, ...?p};
    final query  = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return Uri.parse('$_base$path?$query&signature=${_hmac(secret!, query)}');
  }

  Map<String, String> get _h => {'X-MBX-APIKEY': apiKey!};

  Future<List<ExchangeBalance>> fetchBalances() async {
    final r = await http.get(_signed('/api/v3/account'), headers: _h)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw Exception(r.body);
    final List bs = jsonDecode(r.body)['balances'] ?? [];
    return bs
        .map((b) => ExchangeBalance(
              exchange: 'Binance',
              asset:    b['asset'],
              free:     double.tryParse(b['free'].toString())   ?? 0,
              locked:   double.tryParse(b['locked'].toString()) ?? 0,
            ))
        .where((b) => b.total > 0.000001)
        .toList();
  }

  Future<Map<String, double>> fetchPrices(List<String> symbols) async {
    if (symbols.isEmpty) return {};
    try {
      final r = await http.get(Uri.parse(
        '$_base/api/v3/ticker/price?symbols=${Uri.encodeComponent(jsonEncode(symbols))}'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return {};
      final List data = jsonDecode(r.body);
      return {for (final d in data)
        d['symbol'] as String: double.tryParse(d['price'].toString()) ?? 0};
    } catch (_) { return {}; }
  }

  Future<List<ExchangeOrder>> fetchOrders(List<String> symbols) async {
    final all = <ExchangeOrder>[];
    for (final sym in symbols.take(5)) {
      try {
        final r = await http.get(
          _signed('/api/v3/allOrders', {'symbol': sym, 'limit': '20'}),
          headers: _h,
        ).timeout(const Duration(seconds: 10));
        if (r.statusCode != 200) continue;
        final List data = jsonDecode(r.body);
        all.addAll(data
            .where((o) => o['status'] == 'FILLED')
            .map((o) => ExchangeOrder(
                  exchange:    'Binance',
                  symbol:      o['symbol'],
                  side:        o['side'],
                  price:       double.tryParse(o['price'].toString()) ?? 0,
                  executedQty: double.tryParse(o['executedQty'].toString()) ?? 0,
                  time: DateTime.fromMillisecondsSinceEpoch(o['time']),
                )));
      } catch (_) {}
    }
    return all;
  }

  Future<ExchangeSnapshot> fetchSnapshot() async {
    await load();
    if (!configured) {
      return ExchangeSnapshot(
        name: 'Binance', balances: [], totalUsdt: 0,
        orders: [], prices: {}, error: null,
        configured: false, isTestnet: false,
      );
    }
    try {
      final balances = await fetchBalances();
      final nonUsdt  = balances.where((b) => b.asset != 'USDT').toList();
      final usdtBal  = balances.where((b) => b.asset == 'USDT').fold(0.0, (s, b) => s + b.total);
      final symbols  = nonUsdt.map((b) => '${b.asset}USDT').toList();
      final prices   = await fetchPrices(symbols);
      double total   = usdtBal;
      for (final b in nonUsdt) {
        total += b.total * (prices['${b.asset}USDT'] ?? 0);
      }
      final orders = await fetchOrders(symbols);
      return ExchangeSnapshot(
        name: 'Binance', balances: balances, totalUsdt: total,
        orders: orders, prices: prices, error: null,
        configured: true, isTestnet: testnet,
      );
    } catch (e) {
      return ExchangeSnapshot(
        name: 'Binance', balances: [], totalUsdt: 0,
        orders: [], prices: {}, error: e.toString(),
        configured: true, isTestnet: testnet,
      );
    }
  }
}

// ── Serviço Bybit ─────────────────────────────────────────────────────────────

class _BybitService {
  static const _mainnet    = 'https://api.bybit.com';
  static const _testnetUrl = 'https://api-testnet.bybit.com';

  String? apiKey, secret;
  bool testnet = false, configured = false;

  Future<void> load() async {
    apiKey     = await _kStorage.read(key: 'fenix_bybit_api_key');
    secret     = await _kStorage.read(key: 'fenix_bybit_secret');
    testnet    = (await _kStorage.read(key: 'fenix_bybit_testnet')) == 'true';
    configured = (apiKey?.isNotEmpty == true) && (secret?.isNotEmpty == true);
  }

  String get _base => testnet ? _testnetUrl : _mainnet;

  Map<String, String> _headers(String ts, {String queryString = ''}) => {
    'X-BAPI-API-KEY':     apiKey!,
    'X-BAPI-TIMESTAMP':   ts,
    'X-BAPI-SIGN':        _hmac(secret!, '$ts${apiKey!}5000$queryString'),
    'X-BAPI-RECV-WINDOW': '5000',
  };

  Future<List<ExchangeBalance>> fetchBalances() async {
    final ts  = DateTime.now().millisecondsSinceEpoch.toString();
    final qs  = 'accountType=UNIFIED';
    final r   = await http.get(
      Uri.parse('$_base/v5/account/wallet-balance?$qs'),
      headers: _headers(ts, queryString: qs),
    ).timeout(const Duration(seconds: 10));
    final body = jsonDecode(r.body);
    if (body['retCode'] != 0) throw Exception('Bybit retCode:\${body["retCode"]} msg:\${body["retMsg"]} body:\${r.body.substring(0, r.body.length < 200 ? r.body.length : 200)}');
    final List coins = body['result']?['list']?[0]?['coin'] ?? [];
    return coins
        .map((c) => ExchangeBalance(
              exchange: 'Bybit',
              asset:    c['coin'],
              free:     double.tryParse((c['walletBalance'] ?? c['availableToWithdraw'] ?? '0').toString()) ?? 0,
              locked:   double.tryParse(c['locked'].toString()) ?? 0,
            ))
        .where((b) => b.total > 0.000001)
        .toList();
  }

  Future<Map<String, double>> fetchPrices(List<String> symbols) async {
    final prices = <String, double>{};
    for (final sym in symbols.take(10)) {
      try {
        final r = await http.get(
          Uri.parse('$_base/v5/market/tickers?category=spot&symbol=$sym'),
        ).timeout(const Duration(seconds: 5));
        final body = jsonDecode(r.body);
        if (body['retCode'] == 0) {
          final list = body['result']?['list'] ?? [];
          if (list.isNotEmpty) {
            prices[sym] = double.tryParse(list[0]['lastPrice'].toString()) ?? 0;
          }
        }
      } catch (_) {}
    }
    return prices;
  }

  Future<List<ExchangeOrder>> fetchOrders(List<String> symbols) async {
    final all = <ExchangeOrder>[];
    for (final sym in symbols.take(5)) {
      try {
        final ts = DateTime.now().millisecondsSinceEpoch.toString();
        final qs = 'category=spot&symbol=$sym&limit=20';
        final r  = await http.get(
          Uri.parse('$_base/v5/order/history?$qs'),
          headers: _headers(ts, queryString: qs),
        ).timeout(const Duration(seconds: 10));
        final body = jsonDecode(r.body);
        if (body['retCode'] != 0) continue;
        final List orders = body['result']?['list'] ?? [];
        all.addAll(orders
            .where((o) => o['orderStatus'] == 'Filled')
            .map((o) => ExchangeOrder(
                  exchange:    'Bybit',
                  symbol:      o['symbol'],
                  side:        o['side'].toString().toUpperCase(),
                  price:       double.tryParse(o['avgPrice'].toString()) ?? 0,
                  executedQty: double.tryParse(o['cumExecQty'].toString()) ?? 0,
                  time: DateTime.fromMillisecondsSinceEpoch(
                      int.tryParse(o['updatedTime'].toString()) ?? 0),
                )));
      } catch (_) {}
    }
    return all;
  }

  Future<ExchangeSnapshot> fetchSnapshot() async {
    await load();
    if (!configured) {
      return ExchangeSnapshot(
        name: 'Bybit', balances: [], totalUsdt: 0,
        orders: [], prices: {}, error: null,
        configured: false, isTestnet: false,
      );
    }
    try {
      final balances = await fetchBalances();
      final nonUsdt  = balances.where((b) => b.asset != 'USDT').toList();
      final usdtBal  = balances.where((b) => b.asset == 'USDT').fold(0.0, (s, b) => s + b.total);
      final symbols  = nonUsdt.map((b) => '${b.asset}USDT').toList();
      final prices   = await fetchPrices(symbols);
      double total   = usdtBal;
      for (final b in nonUsdt) {
        total += b.total * (prices['${b.asset}USDT'] ?? 0);
      }
      final orders = await fetchOrders(symbols);
      return ExchangeSnapshot(
        name: 'Bybit', balances: balances, totalUsdt: total,
        orders: orders, prices: prices, error: null,
        configured: true, isTestnet: testnet,
      );
    } catch (e) {
      return ExchangeSnapshot(
        name: 'Bybit', balances: [], totalUsdt: 0,
        orders: [], prices: {}, error: e.toString(),
        configured: true, isTestnet: testnet,
      );
    }
  }
}

// ── Serviço Unificado ─────────────────────────────────────────────────────────

class ExchangeService {
  final _binance = _BinanceService();
  final _bybit   = _BybitService();

  Future<ExchangeDashboardData> fetchAll() async {
    // Busca as duas exchanges em paralelo
    final results = await Future.wait([
      _binance.fetchSnapshot(),
      _bybit.fetchSnapshot(),
    ]);

    final binanceSnap = results[0];
    final bybitSnap   = results[1];

    final snapshots = <String, ExchangeSnapshot>{};
    if (binanceSnap.configured) snapshots['Binance'] = binanceSnap;
    if (bybitSnap.configured)   snapshots['Bybit']   = bybitSnap;

    if (!binanceSnap.configured && !bybitSnap.configured) {
      return ExchangeDashboardData(
        balances: [], totalUsdtValue: 0, recentOrders: [],
        prices: {}, realizedPnlHoje: 0, ciclosFechadosHoje: 0,
        activeExchanges: [], fetchedAt: DateTime.now(),
        errors: {'geral': 'Nenhuma exchange configurada.'},
        snapshots: {}, modoReal: false,
      );
    }

    // Agrega tudo
    final allBalances = <ExchangeBalance>[
      ...binanceSnap.balances,
      ...bybitSnap.balances,
    ];
    final allOrders = <ExchangeOrder>[
      ...binanceSnap.orders,
      ...bybitSnap.orders,
    ]..sort((a, b) => b.time.compareTo(a.time));

    final allPrices = <String, double>{
      ...binanceSnap.prices,
      ...bybitSnap.prices,
    };

    final totalUsdt = binanceSnap.totalUsdt + bybitSnap.totalUsdt;

    final errors = <String, String?>{};
    if (binanceSnap.error != null) errors['Binance'] = binanceSnap.error;
    if (bybitSnap.error != null)   errors['Bybit']   = bybitSnap.error;

    final active = <String>[
      if (binanceSnap.configured && binanceSnap.error == null) 'Binance',
      if (bybitSnap.configured   && bybitSnap.error == null)   'Bybit',
    ];

    // P&L do dia
    final today      = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final bySymbol   = <String, List<ExchangeOrder>>{};
    for (final o in allOrders) {
      bySymbol.putIfAbsent('${o.exchange}:${o.symbol}', () => []).add(o);
    }
    double pnlHoje = 0;
    int    ciclos  = 0;
    for (final orders in bySymbol.values) {
      final buys  = orders.where((o) => o.side == 'BUY').toList();
      final sells = orders.where((o) =>
          o.side == 'SELL' && o.time.isAfter(startOfDay)).toList();
      if (buys.isEmpty || sells.isEmpty) continue;
      final avgBuy = buys.map((o) => o.price).reduce((a, b) => a + b) / buys.length;
      for (final sell in sells) {
        pnlHoje += (sell.price - avgBuy) * sell.executedQty;
        ciclos++;
      }
    }

    // Lê modo real do storage
    final prefs    = await SharedPreferences.getInstance();
    final modoReal = prefs.getBool('fenix_modo_real') ?? true;

    return ExchangeDashboardData(
      balances:           allBalances,
      totalUsdtValue:     totalUsdt,
      recentOrders:       allOrders.take(20).toList(),
      prices:             allPrices,
      realizedPnlHoje:    pnlHoje,
      ciclosFechadosHoje: ciclos,
      activeExchanges:    active,
      fetchedAt:          DateTime.now(),
      errors:             errors,
      snapshots:          snapshots,
      modoReal:           modoReal,
    );
  }
}
