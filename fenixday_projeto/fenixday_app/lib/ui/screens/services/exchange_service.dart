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
    // recvWindow ampliado (10s) para tolerar pequeno desvio de relógio/latência,
    // principalmente no desktop. Evita o erro -1021 da Binance.
    final params = {'timestamp': ts, 'recvWindow': '10000', ...?p};
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
    if (body['retCode'] != 0) throw Exception('Bybit retCode:${body["retCode"]} msg:${body["retMsg"]} body:${r.body.substring(0, r.body.length < 200 ? r.body.length : 200)}');
    final List coins = body['result']?['list']?[0]?['coin'] ?? [];
    return coins
        .map((c) {
          // Bybit: walletBalance JÁ é o total da moeda (livre + travado).
          // Para não contar em dobro, free = disponível e locked = travado,
          // de modo que free + locked = walletBalance.
          final wallet = double.tryParse((c['walletBalance'] ?? '0').toString()) ?? 0;
          final locked = double.tryParse((c['locked'] ?? '0').toString()) ?? 0;
          var free = double.tryParse((c['availableToWithdraw'] ?? '0').toString()) ?? 0;
          // Se availableToWithdraw não vier, deriva do total - travado.
          if (free <= 0 && wallet > 0) free = wallet - locked;
          if (free < 0) free = 0;
          return ExchangeBalance(
            exchange: 'Bybit',
            asset:    c['coin'],
            free:     free,
            locked:   locked,
          );
        })
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


// ── Serviço OKX ───────────────────────────────────────────────────────────────

class _OkxService {
  static const _mainnet    = 'https://www.okx.com';
  static const _testnetUrl = 'https://www.okx.com'; // OKX usa header para demo

  String? apiKey, secret, passphrase;
  bool testnet = false, configured = false;

  Future<void> load() async {
    apiKey      = await _kStorage.read(key: 'fenix_okx_api_key');
    secret      = await _kStorage.read(key: 'fenix_okx_secret');
    passphrase  = await _kStorage.read(key: 'fenix_okx_passphrase');
    testnet     = (await _kStorage.read(key: 'fenix_okx_testnet')) == 'true';
    configured  = (apiKey?.isNotEmpty == true) && (secret?.isNotEmpty == true) && (passphrase?.isNotEmpty == true);
  }

  Map<String, String> _headers(String ts, String path, {String body = ''}) {
    final prehash = ts + 'GET' + path + body;
    final sign    = base64.encode(
      Hmac(sha256, utf8.encode(secret!)).convert(utf8.encode(prehash)).bytes);
    return {
      'OK-ACCESS-KEY':        apiKey!,
      'OK-ACCESS-SIGN':       sign,
      'OK-ACCESS-TIMESTAMP':  ts,
      'OK-ACCESS-PASSPHRASE': passphrase!,
      'Content-Type':         'application/json',
      'User-Agent':           'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
      if (testnet) 'x-simulated-trading': '1',
    };
  }

  String _ts() {
    final now = DateTime.now().toUtc();
    final ms  = now.millisecond.toString().padLeft(3, '0');
    final y   = now.year.toString();
    final mo  = now.month.toString().padLeft(2, '0');
    final d   = now.day.toString().padLeft(2, '0');
    final h   = now.hour.toString().padLeft(2, '0');
    final mi  = now.minute.toString().padLeft(2, '0');
    final s   = now.second.toString().padLeft(2, '0');
    return y + '-' + mo + '-' + d + 'T' + h + ':' + mi + ':' + s + '.' + ms + 'Z';
  }

  Future<List<ExchangeBalance>> fetchBalances() async {
    final ts   = _ts();
    final path = '/api/v5/account/balance';
    final r    = await http.get(
      Uri.parse('https://www.okx.com' + path),
      headers: _headers(ts, path),
    ).timeout(const Duration(seconds: 10));
    final body = jsonDecode(r.body);
    if (body['code'] != '0') {
      final code = body['code']?.toString() ?? '?';
      final msg  = body['msg']?.toString()  ?? '?';
      throw Exception('OKX erro $code: $msg');
    }
    final List details = body['data']?[0]?['details'] ?? [];
    return details
        .map((d) => ExchangeBalance(
              exchange: 'OKX',
              asset:    d['ccy'],
              free:     double.tryParse(d['availBal'].toString()) ?? 0,
              locked:   double.tryParse(d['frozenBal'].toString()) ?? 0,
            ))
        .where((b) => b.total > 0.000001)
        .toList();
  }

  Future<Map<String, double>> fetchPrices(List<String> symbols) async {
    final prices = <String, double>{};
    for (final sym in symbols.take(10)) {
      try {
        final instId = sym.replaceAll('USDT', '-USDT');
        final r = await http.get(Uri.parse(
          'https://www.okx.com/api/v5/market/ticker?instId=$instId'),
        ).timeout(const Duration(seconds: 5));
        final body = jsonDecode(r.body);
        if (body['code'] == '0' && body['data'].isNotEmpty) {
          prices[sym] = double.tryParse(body['data'][0]['last'].toString()) ?? 0;
        }
      } catch (_) {}
    }
    return prices;
  }

  Future<List<ExchangeOrder>> fetchOrders(List<String> symbols) async {
    final all = <ExchangeOrder>[];
    for (final sym in symbols.take(5)) {
      try {
        final ts     = _ts();
        final instId = sym.replaceAll('USDT', '-USDT');
        final path   = '/api/v5/trade/orders-history?instType=SPOT&instId=$instId&limit=20';
        final r      = await http.get(
          Uri.parse('https://www.okx.com$path'),
          headers: _headers(ts, path),
        ).timeout(const Duration(seconds: 10));
        final body = jsonDecode(r.body);
        if (body['code'] != '0') continue;
        final List orders = body['data'] ?? [];
        all.addAll(orders
            .where((o) => o['state'] == 'filled')
            .map((o) => ExchangeOrder(
                  exchange:    'OKX',
                  symbol:      sym,
                  side:        o['side'].toString().toUpperCase(),
                  price:       double.tryParse(o['avgPx'].toString()) ?? 0,
                  executedQty: double.tryParse(o['fillSz'].toString()) ?? 0,
                  time: DateTime.fromMillisecondsSinceEpoch(
                      int.tryParse(o['uTime'].toString()) ?? 0),
                )));
      } catch (_) {}
    }
    return all;
  }

  Future<ExchangeSnapshot> fetchSnapshot() async {
    await load();
    if (!configured) {
      return ExchangeSnapshot(name: 'OKX', balances: [], totalUsdt: 0,
        orders: [], prices: {}, error: null, configured: false, isTestnet: false);
    }
    try {
      final balances = await fetchBalances();
      const fiat = {'EUR', 'GBP', 'BRL'};
      final nonUsdt = balances.where((b) => b.asset != 'USDT' && !fiat.contains(b.asset)).toList();
      final usdtBal = balances.where((b) => b.asset == 'USDT').fold(0.0, (s, b) => s + b.total);
      final symbols = nonUsdt.map((b) => '\${b.asset}USDT').toList();
      final prices  = await fetchPrices(symbols);
      double total  = usdtBal;
      for (final b in nonUsdt) total += b.total * (prices['\${b.asset}USDT'] ?? 0);
      final orders = await fetchOrders(symbols);
      return ExchangeSnapshot(name: 'OKX', balances: balances, totalUsdt: total,
        orders: orders, prices: prices, error: null, configured: true, isTestnet: testnet);
    } catch (e) {
      return ExchangeSnapshot(name: 'OKX', balances: [], totalUsdt: 0,
        orders: [], prices: {}, error: e.toString(), configured: true, isTestnet: testnet);
    }
  }
}

// ── Serviço Crypto.com ────────────────────────────────────────────────────────

class _CryptoComService {
  static const _mainnet = 'https://api.crypto.com/exchange/v1';

  String? apiKey, secret;
  bool testnet = false, configured = false;

  Future<void> load() async {
    apiKey     = await _kStorage.read(key: 'fenix_cryptocom_api_key');
    secret     = await _kStorage.read(key: 'fenix_cryptocom_secret');
    testnet    = (await _kStorage.read(key: 'fenix_cryptocom_testnet')) == 'true';
    configured = (apiKey?.isNotEmpty == true) && (secret?.isNotEmpty == true);
  }

  String get _base => testnet
      ? 'https://uat-api.3ona.co/exchange/v1'
      : _mainnet;

  Map<String, dynamic> _signedBody(String method, Map<String, dynamic> params) {
    final nonce = DateTime.now().millisecondsSinceEpoch.toString();
    final id    = int.parse(nonce.substring(0, 13));
    // Crypto.com: sig = method + nonce + apiKey (sem params para requests simples)
    final sigPayload = '\$method\$nonce\${apiKey!}';
    final sig = Hmac(sha256, utf8.encode(secret!))
        .convert(utf8.encode(sigPayload)).toString();
    return {
      'id':      id,
      'method':  method,
      'api_key': apiKey!,
      'params':  params,
      'nonce':   nonce,
      'sig':     sig,
    };
  }

  Future<List<ExchangeBalance>> fetchBalances() async {
    const method = 'private/get-account-summary';
    final body = _signedBody(method, {});
    final r = await http.post(
      Uri.parse('\$_base/\$method'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));
    final data = jsonDecode(r.body);
    if (data['code'] != 0) throw Exception('Crypto.com code:${data["code"]} msg:${data["message"]} body:${r.body.length > 200 ? r.body.substring(0,200) : r.body}');
    final List accounts = data['result']?['accounts'] ?? [];
    final balances = <ExchangeBalance>[];
    for (final acc in accounts) {
      final asset = acc['currency']?.toString() ?? '';
      if (asset.isEmpty) continue;
      balances.add(ExchangeBalance(
        exchange: 'Crypto.com',
        asset:    asset,
        free:     double.tryParse(acc['available'].toString()) ?? 0,
        locked:   double.tryParse(acc['order'].toString()) ?? 0,
      ));
    }
    return balances.where((b) => b.total > 0.000001).toList();
  }

  Future<Map<String, double>> fetchPrices(List<String> symbols) async {
    final prices = <String, double>{};
    for (final sym in symbols.take(10)) {
      try {
        final instId = sym.replaceAll('USDT', '_USDT');
        final r = await http.get(Uri.parse(
          'https://api.crypto.com/exchange/v1/public/get-tickers?instrument_name=\$instId'),
        ).timeout(const Duration(seconds: 5));
        final body = jsonDecode(r.body);
        if (body['code'] == 0 && body['result']?['data'] != null) {
          final List data = body['result']['data'];
          if (data.isNotEmpty) {
            prices[sym] = double.tryParse(data[0]['a'].toString()) ?? 0;
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
        final instId = sym.replaceAll('USDT', '_USDT');
        final body = _signedBody('private/get-order-history', {'instrument_name': instId, 'page_size': 20});
        final r = await http.post(
          Uri.parse('\$_base/private/get-order-history'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 10));
        final data = jsonDecode(r.body);
        if (data['code'] != 0) continue;
        final List orders = data['result']?['data'] ?? [];
        all.addAll(orders
            .where((o) => o['status'] == 'FILLED')
            .map((o) => ExchangeOrder(
                  exchange:    'Crypto.com',
                  symbol:      sym,
                  side:        o['side'].toString().toUpperCase(),
                  price:       double.tryParse(o['avg_price'].toString()) ?? 0,
                  executedQty: double.tryParse(o['cumulative_quantity'].toString()) ?? 0,
                  time: DateTime.fromMillisecondsSinceEpoch(
                      int.tryParse(o['update_time'].toString()) ?? 0),
                )));
      } catch (_) {}
    }
    return all;
  }

  Future<ExchangeSnapshot> fetchSnapshot() async {
    await load();
    if (!configured) {
      return ExchangeSnapshot(name: 'Crypto.com', balances: [], totalUsdt: 0,
        orders: [], prices: {}, error: null, configured: false, isTestnet: false);
    }
    try {
      final balances = await fetchBalances();
      const fiat = {'EUR', 'GBP', 'BRL'};
      final nonUsdt = balances.where((b) => b.asset != 'USDT' && !fiat.contains(b.asset)).toList();
      final usdtBal = balances.where((b) => b.asset == 'USDT').fold(0.0, (s, b) => s + b.total);
      final symbols = nonUsdt.map((b) => '\${b.asset}USDT').toList();
      final prices  = await fetchPrices(symbols);
      double total  = usdtBal;
      for (final b in nonUsdt) total += b.total * (prices['\${b.asset}USDT'] ?? 0);
      final orders = await fetchOrders(symbols);
      return ExchangeSnapshot(name: 'Crypto.com', balances: balances, totalUsdt: total,
        orders: orders, prices: prices, error: null, configured: true, isTestnet: testnet);
    } catch (e) {
      return ExchangeSnapshot(name: 'Crypto.com', balances: [], totalUsdt: 0,
        orders: [], prices: {}, error: e.toString(), configured: true, isTestnet: testnet);
    }
  }
}

// ── Serviço Unificado ─────────────────────────────────────────────────────────

class ExchangeService {
  final _binance   = _BinanceService();
  final _bybit     = _BybitService();
  final _okx       = _OkxService();
  final _cryptocom = _CryptoComService();

  /// Busca o saldo USDT de uma exchange específica
  Future<double> fetchUsdtBalance(String exchange) async {
    try {
      final ex = exchange.toLowerCase();
      ExchangeSnapshot snap;
      if (ex == 'binance')        snap = await _binance.fetchSnapshot();
      else if (ex == 'bybit')     snap = await _bybit.fetchSnapshot();
      else if (ex == 'okx')       snap = await _okx.fetchSnapshot();
      else if (ex == 'crypto.com' || ex == 'cryptocom') snap = await _cryptocom.fetchSnapshot();
      else return 0.0;
      return snap.totalUsdt;
    } catch (e) {
      return 0.0;
    }
  }

  Future<ExchangeDashboardData> fetchAll() async {
    // Busca todas as exchanges em paralelo
    final results = await Future.wait([
      _binance.fetchSnapshot(),
      _bybit.fetchSnapshot(),
      _okx.fetchSnapshot(),
      _cryptocom.fetchSnapshot(),
    ]);

    final binanceSnap   = results[0];
    final bybitSnap     = results[1];
    final okxSnap       = results[2];
    final cryptocomSnap = results[3];

    final snapshots = <String, ExchangeSnapshot>{};
    if (binanceSnap.configured)   snapshots['Binance']    = binanceSnap;
    if (bybitSnap.configured)     snapshots['Bybit']      = bybitSnap;
    if (okxSnap.configured)       snapshots['OKX']        = okxSnap;
    if (cryptocomSnap.configured) snapshots['Crypto.com'] = cryptocomSnap;

    if (snapshots.isEmpty) {
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
      ...okxSnap.balances,
      ...cryptocomSnap.balances,
    ];
    final allOrders = <ExchangeOrder>[
      ...binanceSnap.orders,
      ...bybitSnap.orders,
      ...okxSnap.orders,
      ...cryptocomSnap.orders,
    ]..sort((a, b) => b.time.compareTo(a.time));

    final allPrices = <String, double>{
      ...binanceSnap.prices,
      ...bybitSnap.prices,
      ...okxSnap.prices,
      ...cryptocomSnap.prices,
    };

    final totalUsdt = binanceSnap.totalUsdt + bybitSnap.totalUsdt +
                      okxSnap.totalUsdt + cryptocomSnap.totalUsdt;

    final errors = <String, String?>{};
    if (binanceSnap.error != null)   errors['Binance']    = binanceSnap.error;
    if (bybitSnap.error != null)     errors['Bybit']      = bybitSnap.error;
    if (okxSnap.error != null)       errors['OKX']        = okxSnap.error;
    if (cryptocomSnap.error != null) errors['Crypto.com'] = cryptocomSnap.error;

    final active = <String>[
      if (binanceSnap.configured   && binanceSnap.error == null)   'Binance',
      if (bybitSnap.configured     && bybitSnap.error == null)     'Bybit',
      if (okxSnap.configured       && okxSnap.error == null)       'OKX',
      if (cryptocomSnap.configured && cryptocomSnap.error == null) 'Crypto.com',
    ];

    // P&L do dia: usa o lucro REAL dos ciclos do grid (backend),
    // não o cálculo aproximado SELL-avgBuy que distorcia o resultado.
    double pnlHoje = 0;
    int    ciclos  = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      if (token.isNotEmpty) {
        final rr = await http.get(
          Uri.parse('https://fenixday.info/api/v1/grids/cycles/today'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 10));
        if (rr.statusCode == 200) {
          final d = jsonDecode(rr.body);
          pnlHoje = (d['lucro_hoje'] as num?)?.toDouble() ?? 0.0;
          ciclos  = (d['ciclos_hoje'] as num?)?.toInt() ?? 0;
        }
      }
    } catch (e) {
      // silencioso: se falhar, fica 0 (não quebra o dashboard)
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
