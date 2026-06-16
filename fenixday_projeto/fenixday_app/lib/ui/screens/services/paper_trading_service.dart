/// FênixDay — Serviço de Paper Trading
/// Busca preços reais e simula ciclos de grid

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'paper_trading_db.dart';

// ── Provider do banco ─────────────────────────────────────────────────────────

final paperDbProvider = Provider<PaperTradingDatabase>((ref) {
  final db = PaperTradingDatabase();
  ref.onDispose(db.close);
  return db;
});

// ── Provider de robôs ─────────────────────────────────────────────────────────

final paperRobotsProvider = StreamProvider<List<PaperRobot>>((ref) {
  final db = ref.watch(paperDbProvider);
  return db.select(db.paperRobots).watch();
});

// ── Provider de ciclos por robô ───────────────────────────────────────────────

final paperCyclesProvider = FutureProvider.family<List<PaperCycle>, int>((ref, robotId) {
  final db = ref.watch(paperDbProvider);
  return db.getCyclesForRobot(robotId);
});

// ── Provider de stats totais ──────────────────────────────────────────────────

class PaperStats {
  final double totalProfit;
  final int totalCycles;
  final double totalCapital;
  final List<MapEntry<DateTime, double>> equityCurve;

  const PaperStats({
    required this.totalProfit,
    required this.totalCycles,
    required this.totalCapital,
    required this.equityCurve,
  });
}

final paperStatsProvider = FutureProvider<PaperStats>((ref) async {
  final db     = ref.watch(paperDbProvider);
  final cycles = await db.getAllCycles();
  final robots = await db.getAllRobots();

  double totalCapital = robots.fold(0.0, (s, r) => s + r.capital);
  double totalProfit  = cycles.fold(0.0, (s, c) => s + c.profit);

  // Curva de equity — acumula lucro por dia
  final Map<DateTime, double> byDay = {};
  for (final c in cycles) {
    final day = DateTime(c.closedAt.year, c.closedAt.month, c.closedAt.day);
    byDay[day] = (byDay[day] ?? 0) + c.profit;
  }
  double acc = totalCapital;
  final curve = byDay.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final equityCurve = curve.map((e) {
    acc += e.value;
    return MapEntry(e.key, acc);
  }).toList();

  return PaperStats(
    totalProfit:  totalProfit,
    totalCycles:  cycles.length,
    totalCapital: totalCapital,
    equityCurve:  equityCurve,
  );
});

// ── Serviço de simulação ──────────────────────────────────────────────────────

class PaperTradingService {
  final PaperTradingDatabase db;
  final Map<int, Timer> _timers = {};

  PaperTradingService(this.db);

  // Busca preço atual do par
  Future<double?> fetchPrice(String symbol, String exchange) async {
    try {
      final sym = symbol.replaceAll('/', '');
      if (exchange == 'Binance') {
        final r = await http.get(Uri.parse(
          'https://api.binance.com/api/v3/ticker/price?symbol=$sym'));
        if (r.statusCode == 200) {
          return double.tryParse(jsonDecode(r.body)['price'].toString());
        }
      } else if (exchange == 'Bybit') {
        final r = await http.get(Uri.parse(
          'https://api.bybit.com/v5/market/tickers?category=spot&symbol=$sym'));
        if (r.statusCode == 200) {
          final list = jsonDecode(r.body)['result']?['list'] ?? [];
          if (list.isNotEmpty) {
            return double.tryParse(list[0]['lastPrice'].toString());
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // Simula um ciclo de grid baseado no preço atual
  Future<void> simulateCycle(PaperRobot robot) async {
    final price = await fetchPrice(robot.symbol, robot.exchange);
    if (price == null) return;

    // Verifica se preço está dentro do range
    if (price < robot.lowerBound || price > robot.upperBound) return;

    // Calcula parâmetros do grid
    final gridStep    = (robot.upperBound - robot.lowerBound) / robot.numGrids;
    final orderSize   = robot.capital / robot.numGrids;
    final qty         = orderSize / price;

    // Simula compra na grade abaixo e venda na grade acima
    final gridLevel   = ((price - robot.lowerBound) / gridStep).floor();
    final buyPrice    = robot.lowerBound + (gridLevel * gridStep);
    final sellPrice   = buyPrice + gridStep;

    // Lucro por ciclo (0.1% de fee em cada lado)
    final profit = qty * (sellPrice - buyPrice) - (orderSize * 0.002);
    if (profit <= 0) return;

    await db.insertCycle(PaperCyclesCompanion(
      robotId:   Value(robot.id),
      buyPrice:  Value(buyPrice),
      sellPrice: Value(sellPrice),
      profit:    Value(profit),
      qty:       Value(qty),
      closedAt:  Value(DateTime.now()),
    ));
  }

  // Inicia simulação periódica para um robô
  void startSimulation(PaperRobot robot, {Duration interval = const Duration(minutes: 5)}) {
    _timers[robot.id]?.cancel();
    _timers[robot.id] = Timer.periodic(interval, (_) => simulateCycle(robot));
    // Simula imediatamente ao iniciar
    simulateCycle(robot);
  }

  // Para simulação
  void stopSimulation(int robotId) {
    _timers[robotId]?.cancel();
    _timers.remove(robotId);
  }

  void dispose() {
    for (final t in _timers.values) { t.cancel(); }
    _timers.clear();
  }
}

final paperServiceProvider = Provider<PaperTradingService>((ref) {
  final db      = ref.watch(paperDbProvider);
  final service = PaperTradingService(db);
  ref.onDispose(service.dispose);
  return service;
});
