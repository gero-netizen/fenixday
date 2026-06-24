/// FênixDay — Monitor de Grids (Peça 3 do motor)
/// Etapa 3.1: DETECÇÃO apenas. Roda no app enquanto aberto, detecta
/// quais ordens executaram na corretora. Ainda NÃO age (só debugPrint).
///
/// Segurança: as chaves ficam no dispositivo. O monitor lê o estado das
/// ordens do backend (dados não-sensíveis) e consulta a corretora
/// localmente com as chaves do Keystore.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _baseUrl = 'https://fenixday.info/api/v1';

class GridMonitor {
  Timer? _timer;
  bool _rodando = false;
  static const _intervalo = Duration(seconds: 15);

  // Singleton simples
  static final GridMonitor instance = GridMonitor._();
  GridMonitor._();

  void iniciar() {
    if (_timer != null) return;            // já rodando
    debugPrint('GRID_MONITOR: iniciado (ciclo ${_intervalo.inSeconds}s)');
    _ciclo();                              // roda uma vez já
    _timer = Timer.periodic(_intervalo, (_) => _ciclo());
  }

  void parar() {
    _timer?.cancel();
    _timer = null;
    debugPrint('GRID_MONITOR: parado');
  }

  Future<void> _ciclo() async {
    if (_rodando) return;                  // evita sobreposição
    _rodando = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      if (token.isEmpty) { _rodando = false; return; }

      final grids = await _buscarGridsAtivos(token);
      if (grids.isEmpty) { _rodando = false; return; }

      for (final grid in grids) {
        await _verificarGrid(grid, token);
      }
    } catch (e) {
      debugPrint('GRID_MONITOR_ERR: $e');
    } finally {
      _rodando = false;
    }
  }

  Future<List<Map<String, dynamic>>> _buscarGridsAtivos(String token) async {
    try {
      final r = await http.get(
        Uri.parse('$_baseUrl/grids'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return [];
      final lista = (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
      return lista.where((g) =>
          g['status'] == 'active' && g['modo_real'] == true).toList();
    } catch (e) {
      debugPrint('GRID_MONITOR: erro ao buscar grids: $e');
      return [];
    }
  }

  Future<void> _verificarGrid(Map<String, dynamic> grid, String token) async {
    final gridId   = grid['id']?.toString() ?? '';
    final symbol   = grid['symbol']?.toString() ?? '';
    final exchange = grid['exchange']?.toString() ?? '';
    if (gridId.isEmpty || symbol.isEmpty) return;

    final ordensOpen = await _buscarOrdensOpen(gridId, token);
    if (ordensOpen.isEmpty) return;

    // Mapa orderId -> status REAL na corretora (Filled / Cancelled / New ...).
    // Distingue execução de cancelamento — crucial para não vender o que
    // não foi comprado.
    final statusReais = await _statusOrdensNaCorretora(exchange, symbol);
    if (statusReais == null) return;   // erro de rede, tenta no próximo ciclo

    for (final o in ordensOpen) {
      final oid = o['exchange_order_id']?.toString() ?? '';
      if (oid.isEmpty) continue;
      final st = statusReais[oid];
      if (st == null) continue;          // ordem não apareceu no histórico ainda
      final stl = st.toLowerCase();
      if (stl == 'filled') {
        debugPrint('GRID_MONITOR: $symbol ordem $oid FILLED -> agindo');
        await _processarExecucao(grid, o, token);
      } else if (stl == 'cancelled' || stl == 'canceled' || stl == 'rejected') {
        debugPrint('GRID_MONITOR: $symbol ordem $oid $st -> marcando cancelada (sem agir)');
        await _marcarStatus(o['id']?.toString() ?? '', token, 'cancelled');
      }
      // 'new', 'partiallyfilled', 'untriggered' etc: ainda aberta, ignora
    }
  }

  /// Processa UMA execução: marca filled (idempotência) e cria a ordem oposta.
  Future<void> _processarExecucao(
      Map<String, dynamic> grid, Map<String, dynamic> ordem, String token) async {
    final orderDbId = ordem['id']?.toString() ?? '';
    final gridId    = grid['id']?.toString() ?? '';
    final symbol    = grid['symbol']?.toString() ?? '';
    final exchange  = grid['exchange']?.toString() ?? '';
    final side      = (ordem['side']?.toString() ?? '').toUpperCase();
    final nivel     = ordem['nivel'] ?? 0;
    final price     = (ordem['price'] as num?)?.toDouble() ?? 0;
    final qty       = (ordem['qty'] as num?)?.toDouble() ?? 0;
    final parPrice  = (ordem['par_price'] as num?)?.toDouble() ?? 0;
    if (orderDbId.isEmpty || parPrice <= 0) return;

    // Preparar precisão e chaves ANTES de criar a ordem oposta.
    final prec = await _precisaoPar(exchange, symbol);
    final tickSize = prec['tickSize'] ?? 0;
    final qtyStep  = prec['qtyStep'] ?? 0;

    final chaves = await _chaves(exchange);
    if (chaves == null) {
      debugPrint('GRID_MONITOR: sem chaves para $exchange');
      return;
    }
    final apiKey = chaves[0], secret = chaves[1];

    // ESTRATÉGIA: criar a ordem oposta PRIMEIRO. Só marcar filled se a
    // criação teve sucesso — assim um ciclo nunca é perdido por falha.

    if (side == 'BUY') {
      // BUY executou -> criar SELL no par_price (nível acima)
      var sellPrice = parPrice;
      var sellQty   = qty;
      if (tickSize > 0) {
        sellPrice = (sellPrice / tickSize).round() * tickSize;
        sellPrice = double.parse(sellPrice.toStringAsFixed(_decFromStep(tickSize)));
      }
      if (qtyStep > 0) {
        sellQty = (sellQty / qtyStep).floor() * qtyStep;
        sellQty = double.parse(sellQty.toStringAsFixed(_decFromStep(qtyStep)));
      }
      try {
        final novoId = await _criarOrdem(exchange, apiKey, secret, symbol,
            'Sell', sellPrice, sellQty, tickSize, qtyStep);
        debugPrint('GRID_MONITOR: SELL criada @ $sellPrice (de BUY nivel $nivel) id=$novoId');
        // Registrar a nova SELL: par_price aponta de volta para a compra original
        await _registrarOrdem(gridId, token, {
          'exchange_order_id': novoId,
          'nivel': nivel,
          'side': 'SELL',
          'price': sellPrice,
          'qty': sellQty,
          'par_price': price,   // quando a SELL executar, recolocar BUY aqui
          'status': 'open',
        });
        // SÓ AGORA marca a BUY como filled (venda criada com sucesso)
        await _marcarFilled(orderDbId, token);
      } catch (e) {
        debugPrint('GRID_MONITOR: erro ao criar SELL: $e (ordem fica open, retenta)');
      }
    } else if (side == 'SELL') {
      // SELL executou -> ciclo fechado! Recolocar BUY no par_price (nível abaixo)
      var buyPrice = parPrice;
      var buyQty   = qty;
      if (tickSize > 0) {
        buyPrice = (buyPrice / tickSize).round() * tickSize;
        buyPrice = double.parse(buyPrice.toStringAsFixed(_decFromStep(tickSize)));
      }
      if (qtyStep > 0) {
        buyQty = (buyQty / qtyStep).floor() * qtyStep;
        buyQty = double.parse(buyQty.toStringAsFixed(_decFromStep(qtyStep)));
      }
      try {
        final novoId = await _criarOrdem(exchange, apiKey, secret, symbol,
            'Buy', buyPrice, buyQty, tickSize, qtyStep);
        debugPrint('GRID_MONITOR: ciclo FECHADO. BUY recolocada @ $buyPrice id=$novoId');
        await _registrarOrdem(gridId, token, {
          'exchange_order_id': novoId,
          'nivel': nivel,
          'side': 'BUY',
          'price': buyPrice,
          'qty': buyQty,
          'par_price': price,   // quando a BUY executar, vender aqui de novo
          'status': 'open',
        });
        // SÓ AGORA marca a SELL como filled (compra recolocada com sucesso)
        await _marcarFilled(orderDbId, token);

        // PEÇA 4: contabilizar lucro do ciclo.
        // precoVenda = price (a SELL que executou); precoCompra = parPrice
        final precoVenda  = price;
        final precoCompra = parPrice;
        final lucroBruto  = (precoVenda - precoCompra) * qty;
        final taxas       = (precoVenda + precoCompra) * qty * 0.001; // ~0,1%/ponta
        final lucroLiq    = lucroBruto - taxas;
        final volume      = (precoVenda + precoCompra) * qty;
        await _registrarCicloFechado(gridId, token, lucroLiq, volume);
        debugPrint('GRID_MONITOR: lucro do ciclo = \$${lucroLiq.toStringAsFixed(4)}');
      } catch (e) {
        debugPrint('GRID_MONITOR: erro ao recolocar BUY: $e (ordem fica open, retenta)');
      }
    }
  }

  int _decFromStep(double step) {
    if (step <= 0) return 8;
    final s = step.toStringAsFixed(12).replaceAll(RegExp(r'0+$'), '');
    final dot = s.indexOf('.');
    if (dot < 0) return 0;
    return s.length - dot - 1;
  }

  Future<List<Map<String, dynamic>>> _buscarOrdensOpen(String gridId, String token) async {
    try {
      final r = await http.get(
        Uri.parse('$_baseUrl/grids/$gridId/orders?status=open'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return [];
      return (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Retorna o conjunto de orderIds AINDA ABERTOS na corretora.
  /// null = erro (não dá pra concluir nada neste ciclo).
  Future<Set<String>?> _ordensAbertasNaCorretora(String exchange, String symbol) async {
    const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true));
    final apiKey = await storage.read(key: 'fenix_${exchange}_api_key') ?? '';
    final secret = await storage.read(key: 'fenix_${exchange}_secret')  ?? '';
    if (apiKey.isEmpty || secret.isEmpty) return null;

    try {
      if (exchange == 'bybit') {
        return await _bybitOrdensAbertas(apiKey, secret, symbol);
      } else if (exchange == 'binance') {
        return await _binanceOrdensAbertas(apiKey, secret, symbol);
      }
    } catch (e) {
      debugPrint('GRID_MONITOR: erro consultar corretora: $e');
    }
    return null;
  }

  /// Retorna mapa orderId -> status combinando ordens ABERTAS (status 'New')
  /// e o HISTÓRICO recente (Filled/Cancelled/...). null em caso de erro.
  Future<Map<String, String>?> _statusOrdensNaCorretora(String exchange, String symbol) async {
    final chaves = await _chaves(exchange);
    if (chaves == null) return null;
    final apiKey = chaves[0], secret = chaves[1];
    try {
      if (exchange == 'bybit') {
        return await _bybitStatusMap(apiKey, secret, symbol);
      } else if (exchange == 'binance') {
        return await _binanceStatusMap(apiKey, secret, symbol);
      }
    } catch (e) {
      debugPrint('GRID_MONITOR: erro status corretora: $e');
    }
    return null;
  }

  Future<Map<String, String>> _bybitStatusMap(String apiKey, String secret, String symbol) async {
    final mapa = <String, String>{};
    // 1) Ordens abertas (realtime) -> status 'New'/'PartiallyFilled'
    final tsA = DateTime.now().millisecondsSinceEpoch.toString();
    final qA = 'category=spot&symbol=$symbol';
    final signA = _hmac(secret, '$tsA${apiKey}5000$qA');
    final rA = await http.get(
      Uri.parse('https://api.bybit.com/v5/order/realtime?$qA'),
      headers: {
        'X-BAPI-API-KEY': apiKey, 'X-BAPI-TIMESTAMP': tsA,
        'X-BAPI-SIGN': signA, 'X-BAPI-RECV-WINDOW': '5000',
      },
    ).timeout(const Duration(seconds: 10));
    for (final o in ((jsonDecode(rA.body)['result']?['list']) as List?) ?? []) {
      final id = o['orderId']?.toString() ?? '';
      final st = o['orderStatus']?.toString() ?? 'New';
      if (id.isNotEmpty) mapa[id] = st;
    }
    // 2) Histórico recente -> Filled/Cancelled (últimas 50)
    final tsH = DateTime.now().millisecondsSinceEpoch.toString();
    final qH = 'category=spot&symbol=$symbol&limit=50';
    final signH = _hmac(secret, '$tsH${apiKey}5000$qH');
    final rH = await http.get(
      Uri.parse('https://api.bybit.com/v5/order/history?$qH'),
      headers: {
        'X-BAPI-API-KEY': apiKey, 'X-BAPI-TIMESTAMP': tsH,
        'X-BAPI-SIGN': signH, 'X-BAPI-RECV-WINDOW': '5000',
      },
    ).timeout(const Duration(seconds: 10));
    for (final o in ((jsonDecode(rH.body)['result']?['list']) as List?) ?? []) {
      final id = o['orderId']?.toString() ?? '';
      final st = o['orderStatus']?.toString() ?? '';
      // histórico tem prioridade (estado final). Só sobrescreve se não estiver aberta.
      if (id.isNotEmpty && !mapa.containsKey(id)) mapa[id] = st;
    }
    return mapa;
  }

  Future<Map<String, String>> _binanceStatusMap(String apiKey, String secret, String symbol) async {
    final mapa = <String, String>{};
    // Binance: allOrders traz status de todas (NEW/FILLED/CANCELED)
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final q = 'symbol=$symbol&limit=50&timestamp=$ts';
    final sig = _hmac(secret, q);
    final r = await http.get(
      Uri.parse('https://api.binance.com/api/v3/allOrders?$q&signature=$sig'),
      headers: {'X-MBX-APIKEY': apiKey},
    ).timeout(const Duration(seconds: 10));
    for (final o in (jsonDecode(r.body) as List?) ?? []) {
      final id = o['orderId']?.toString() ?? '';
      final st = o['status']?.toString() ?? '';
      if (id.isNotEmpty) mapa[id] = st;
    }
    return mapa;
  }

  Future<Set<String>> _bybitOrdensAbertas(String apiKey, String secret, String symbol) async {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final query = 'category=spot&symbol=$symbol';
    final sign = _hmac(secret, '$ts${apiKey}5000$query');
    final r = await http.get(
      Uri.parse('https://api.bybit.com/v5/order/realtime?$query'),
      headers: {
        'X-BAPI-API-KEY': apiKey, 'X-BAPI-TIMESTAMP': ts,
        'X-BAPI-SIGN': sign, 'X-BAPI-RECV-WINDOW': '5000',
      },
    ).timeout(const Duration(seconds: 10));
    final resp = jsonDecode(r.body);
    final lista = (resp['result']?['list'] as List?) ?? [];
    return lista.map((o) => o['orderId']?.toString() ?? '')
        .where((s) => s.isNotEmpty).toSet();
  }

  Future<Set<String>> _binanceOrdensAbertas(String apiKey, String secret, String symbol) async {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final query = 'symbol=$symbol&timestamp=$ts';
    final sig = _hmac(secret, query);
    final r = await http.get(
      Uri.parse('https://api.binance.com/api/v3/openOrders?$query&signature=$sig'),
      headers: {'X-MBX-APIKEY': apiKey},
    ).timeout(const Duration(seconds: 10));
    final lista = (jsonDecode(r.body) as List?) ?? [];
    return lista.map((o) => o['orderId']?.toString() ?? '')
        .where((s) => s.isNotEmpty).toSet();
  }

  // ── Auxiliares de ação ──────────────────────────────────────────────────

  /// Marca uma ordem como filled no backend. Retorna true se ok.
  Future<bool> _marcarFilled(String orderDbId, String token) async {
    try {
      final r = await http.patch(
        Uri.parse('$_baseUrl/grids/orders/$orderDbId'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'status': 'filled'}),
      ).timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Marca uma ordem com um status arbitrário (ex: 'cancelled').
  Future<bool> _marcarStatus(String orderDbId, String token, String status) async {
    if (orderDbId.isEmpty) return false;
    try {
      final r = await http.patch(
        Uri.parse('$_baseUrl/grids/orders/$orderDbId'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      ).timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Registra uma nova ordem no backend.
  Future<void> _registrarOrdem(String gridId, String token, Map<String, dynamic> ordem) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/grids/$gridId/orders'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode([ordem]),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('GRID_MONITOR: erro ao registrar nova ordem: $e');
    }
  }

  /// Registra um ciclo fechado (lucro realizado) no backend.
  Future<void> _registrarCicloFechado(
      String gridId, String token, double lucro, double volume) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/grids/$gridId/cycle-closed'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'lucro': lucro, 'volume': volume}),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('GRID_MONITOR: erro ao registrar ciclo: $e');
    }
  }

  /// Lê as chaves do Keystore. Retorna [apiKey, secret] ou null.
  Future<List<String>?> _chaves(String exchange) async {
    const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true));
    final apiKey = await storage.read(key: 'fenix_${exchange}_api_key') ?? '';
    final secret = await storage.read(key: 'fenix_${exchange}_secret')  ?? '';
    if (apiKey.isEmpty || secret.isEmpty) return null;
    return [apiKey, secret];
  }

  /// Busca tickSize e qtyStep do par.
  Future<Map<String, double>> _precisaoPar(String exchange, String symbol) async {
    double tickSize = 0, qtyStep = 0;
    try {
      if (exchange == 'bybit') {
        final ri = await http.get(Uri.parse(
            'https://api.bybit.com/v5/market/instruments-info?category=spot&symbol=$symbol'));
        final info = jsonDecode(ri.body)['result']?['list']?[0];
        tickSize = double.tryParse(info?['priceFilter']?['tickSize']?.toString() ?? '0') ?? 0;
        qtyStep  = double.tryParse(info?['lotSizeFilter']?['basePrecision']?.toString() ?? '0') ?? 0;
      } else if (exchange == 'binance') {
        final ri = await http.get(Uri.parse(
            'https://api.binance.com/api/v3/exchangeInfo?symbol=$symbol'));
        final filters = (jsonDecode(ri.body)['symbols']?[0]?['filters'] as List?) ?? [];
        for (final f in filters) {
          if (f['filterType'] == 'PRICE_FILTER') {
            tickSize = double.tryParse(f['tickSize']?.toString() ?? '0') ?? 0;
          } else if (f['filterType'] == 'LOT_SIZE') {
            qtyStep = double.tryParse(f['stepSize']?.toString() ?? '0') ?? 0;
          }
        }
      }
    } catch (e) {
      debugPrint('GRID_MONITOR: erro precisao $symbol: $e');
    }
    return {'tickSize': tickSize, 'qtyStep': qtyStep};
  }

  /// Cria uma ordem limit na corretora. Retorna o orderId.
  Future<String> _criarOrdem(String exchange, String apiKey, String secret,
      String symbol, String side, double price, double qty,
      double tickSize, double qtyStep) async {
    final priceDec = tickSize > 0 ? _decFromStep(tickSize) : 8;
    final qtyDec   = qtyStep  > 0 ? _decFromStep(qtyStep)  : 8;
    final priceStr = price.toStringAsFixed(priceDec);
    final qtyStr   = qty.toStringAsFixed(qtyDec);

    if (exchange == 'bybit') {
      final ts = DateTime.now().millisecondsSinceEpoch.toString();
      final bodyStr = jsonEncode({
        'category': 'spot', 'symbol': symbol, 'side': side,
        'orderType': 'Limit', 'qty': qtyStr, 'price': priceStr, 'timeInForce': 'GTC',
      });
      final sign = _hmac(secret, '$ts${apiKey}5000$bodyStr');
      final r = await http.post(
        Uri.parse('https://api.bybit.com/v5/order/create'),
        headers: {
          'X-BAPI-API-KEY': apiKey, 'X-BAPI-TIMESTAMP': ts,
          'X-BAPI-SIGN': sign, 'X-BAPI-RECV-WINDOW': '5000',
          'Content-Type': 'application/json',
        },
        body: bodyStr,
      ).timeout(const Duration(seconds: 10));
      final resp = jsonDecode(r.body);
      if (resp['retCode'] != 0) {
        throw Exception('Bybit: ${resp['retMsg']}');
      }
      return resp['result']?['orderId']?.toString() ?? '';
    } else if (exchange == 'binance') {
      final ts = DateTime.now().millisecondsSinceEpoch.toString();
      final sideUp = side.toUpperCase();
      final query = 'symbol=$symbol&side=$sideUp&type=LIMIT&timeInForce=GTC'
          '&quantity=$qtyStr&price=$priceStr&timestamp=$ts';
      final sig = _hmac(secret, query);
      final r = await http.post(
        Uri.parse('https://api.binance.com/api/v3/order?$query&signature=$sig'),
        headers: {'X-MBX-APIKEY': apiKey},
      ).timeout(const Duration(seconds: 10));
      final body = jsonDecode(r.body);
      if (body['code'] != null && body['code'] != 0) {
        throw Exception('Binance: ${body["msg"]}');
      }
      return body['orderId']?.toString() ?? '';
    }
    throw Exception('Exchange $exchange não suportada no monitor');
  }

  String _hmac(String secret, String msg) {
    return Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(msg)).toString();
  }
}
