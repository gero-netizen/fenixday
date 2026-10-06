/// FênixDay — Banco de dados local para Grids reais (Drift/SQLite)
///
/// Substitui o antigo backend (fenixday.info) por armazenamento 100% local
/// no PC. Guarda os grids e suas ordens individuais, espelhando o que o
/// servidor guardava. Segue o mesmo padrão do paper_trading_db.dart.

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'grid_db.g.dart';

// ── Tabelas ───────────────────────────────────────────────────────────────────

/// Um grid real — espelha os campos do antigo GridModel do servidor.
class Grids extends Table {
  TextColumn get id            => text()();              // uuid gerado no app
  TextColumn get symbol        => text()();
  TextColumn get exchange      => text()();
  RealColumn get capitalUsdt   => real()();
  IntColumn  get niveis        => integer()();
  RealColumn get limiteSuperior => real()();
  RealColumn get limiteInferior => real()();
  RealColumn get espacamentoPct => real()();
  RealColumn get margemLiquidaPct => real()();
  RealColumn get adxEntrada    => real().nullable()();
  RealColumn get atrPctEntrada => real().nullable()();
  TextColumn get gradeEntrada  => text().nullable()();
  RealColumn get lucroRealizado => real().withDefault(const Constant(0))();
  IntColumn  get ciclosFechados => integer().withDefault(const Constant(0))();
  RealColumn get volumeNegociado => real().withDefault(const Constant(0))();
  TextColumn get status        => text().withDefault(const Constant('active'))();
  BoolColumn get modoReal      => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Uma ordem individual (BUY/SELL) de um grid, registrada ao ser criada
/// na corretora e atualizada quando executa.
class GridOrders extends Table {
  IntColumn  get id             => integer().autoIncrement()();
  TextColumn get gridId         => text().references(Grids, #id)();
  TextColumn get exchangeOrderId => text().nullable()();  // id da ordem na corretora
  IntColumn  get nivel          => integer()();
  TextColumn get lado           => text()();              // 'buy' | 'sell'
  RealColumn get preco          => real()();
  RealColumn get quantidade     => real()();
  TextColumn get status         => text().withDefault(const Constant('open'))(); // open|filled|cancelled
  DateTimeColumn get createdAt  => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get filledAt   => dateTime().nullable()();
}

// ── Database ──────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [Grids, GridOrders])
class GridDatabase extends _$GridDatabase {
  GridDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ── Grids ──────────────────────────────────────────────────────────────────

  /// Lista todos os grids, mais recentes primeiro.
  Future<List<Grid>> getAllGrids() =>
      (select(grids)..orderBy([(g) => OrderingTerm.desc(g.createdAt)])).get();

  /// Lista grids filtrando por modo (real ou demo).
  Future<List<Grid>> getGridsByMode(bool modoReal) =>
      (select(grids)
            ..where((g) => g.modoReal.equals(modoReal))
            ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]))
          .get();

  /// Busca um grid pelo id.
  Future<Grid?> getGrid(String id) =>
      (select(grids)..where((g) => g.id.equals(id))).getSingleOrNull();

  /// Insere um grid novo.
  Future<void> insertGrid(GridsCompanion grid) => into(grids).insert(grid);

  /// Atualiza um grid existente (usar GridsCompanion com os campos a mudar).
  Future<void> updateGrid(String id, GridsCompanion changes) =>
      (update(grids)..where((g) => g.id.equals(id))).write(changes);

  /// Atualiza só o status de um grid (active/paused/stopped).
  Future<void> updateGridStatus(String id, String status) =>
      (update(grids)..where((g) => g.id.equals(id)))
          .write(GridsCompanion(status: Value(status)));

  /// Acumula resultado de um ciclo fechado no grid (lucro, contagem, volume).
  Future<void> registrarCiclo(String id, {
    required double lucro,
    required double volume,
  }) async {
    final g = await getGrid(id);
    if (g == null) return;
    await (update(grids)..where((x) => x.id.equals(id))).write(GridsCompanion(
      lucroRealizado:  Value(g.lucroRealizado + lucro),
      ciclosFechados:  Value(g.ciclosFechados + 1),
      volumeNegociado: Value(g.volumeNegociado + volume),
    ));
  }

  /// Remove um grid e todas as suas ordens.
  Future<void> deleteGrid(String id) async {
    await (delete(gridOrders)..where((o) => o.gridId.equals(id))).go();
    await (delete(grids)..where((g) => g.id.equals(id))).go();
  }

  // ── Ordens ─────────────────────────────────────────────────────────────────

  /// Lista as ordens de um grid.
  Future<List<GridOrder>> getOrders(String gridId) =>
      (select(gridOrders)
            ..where((o) => o.gridId.equals(gridId))
            ..orderBy([(o) => OrderingTerm.asc(o.nivel)]))
          .get();

  /// Lista as ordens abertas de um grid (para checar execução).
  Future<List<GridOrder>> getOpenOrders(String gridId) =>
      (select(gridOrders)
            ..where((o) => o.gridId.equals(gridId) & o.status.equals('open')))
          .get();

  /// Registra uma ordem nova.
  Future<int> insertOrder(GridOrdersCompanion order) =>
      into(gridOrders).insert(order);

  /// Marca uma ordem como executada (filled).
  Future<void> markOrderFilled(int id) =>
      (update(gridOrders)..where((o) => o.id.equals(id))).write(GridOrdersCompanion(
        status:   const Value('filled'),
        filledAt: Value(DateTime.now()),
      ));

  /// Atualiza o status de uma ordem.
  Future<void> updateOrderStatus(int id, String status) =>
      (update(gridOrders)..where((o) => o.id.equals(id)))
          .write(GridOrdersCompanion(status: Value(status)));

  // ── Resumo / Dashboard ───────────────────────────────────────────────────────

  /// Resumo agregado para o dashboard (P&L total, nº de grids ativos, etc.).
  Future<GridSummary> getSummary(bool modoReal) async {
    final lista = await getGridsByMode(modoReal);
    double lucroTotal = 0, capitalTotal = 0, volumeTotal = 0;
    int ciclosTotal = 0, ativos = 0;
    for (final g in lista) {
      lucroTotal   += g.lucroRealizado;
      capitalTotal += g.capitalUsdt;
      volumeTotal  += g.volumeNegociado;
      ciclosTotal  += g.ciclosFechados;
      if (g.status == 'active') ativos++;
    }
    return GridSummary(
      totalGrids:    lista.length,
      gridsAtivos:   ativos,
      lucroTotal:    lucroTotal,
      capitalTotal:  capitalTotal,
      volumeTotal:   volumeTotal,
      ciclosTotal:   ciclosTotal,
    );
  }
}

/// Resumo agregado dos grids, para o dashboard.
class GridSummary {
  final int totalGrids;
  final int gridsAtivos;
  final double lucroTotal;
  final double capitalTotal;
  final double volumeTotal;
  final int ciclosTotal;

  const GridSummary({
    required this.totalGrids,
    required this.gridsAtivos,
    required this.lucroTotal,
    required this.capitalTotal,
    required this.volumeTotal,
    required this.ciclosTotal,
  });

  double get lucroPercent =>
      capitalTotal > 0 ? (lucroTotal / capitalTotal) * 100 : 0;
}

// ── Conexão ───────────────────────────────────────────────────────────────────

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'fenix_grids.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
