/// FênixDay — Banco de dados local para Paper Trading (Drift/SQLite)

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'paper_trading_db.g.dart';

// ── Tabelas ───────────────────────────────────────────────────────────────────

class PaperRobots extends Table {
  IntColumn get id          => integer().autoIncrement()();
  TextColumn get symbol     => text()();
  TextColumn get exchange   => text()();
  RealColumn get upperBound => real()();
  RealColumn get lowerBound => real()();
  IntColumn  get numGrids   => integer()();
  RealColumn get capital    => real()();
  TextColumn get status     => text().withDefault(const Constant('running'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class PaperCycles extends Table {
  IntColumn  get id        => integer().autoIncrement()();
  IntColumn  get robotId   => integer().references(PaperRobots, #id)();
  RealColumn get buyPrice  => real()();
  RealColumn get sellPrice => real()();
  RealColumn get profit    => real()();
  RealColumn get qty       => real()();
  DateTimeColumn get closedAt => dateTime().withDefault(currentDateAndTime)();
}

// ── Database ──────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [PaperRobots, PaperCycles])
class PaperTradingDatabase extends _$PaperTradingDatabase {
  PaperTradingDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ── Robôs ──────────────────────────────────────────────────────────────────

  Future<List<PaperRobot>> getAllRobots() =>
      (select(paperRobots)..orderBy([(r) => OrderingTerm.desc(r.createdAt)])).get();

  Future<int> insertRobot(PaperRobotsCompanion robot) =>
      into(paperRobots).insert(robot);

  Future<void> updateRobotStatus(int id, String status) =>
      (update(paperRobots)..where((r) => r.id.equals(id)))
          .write(PaperRobotsCompanion(status: Value(status)));

  Future<void> deleteRobot(int id) async {
    await (delete(paperCycles)..where((c) => c.robotId.equals(id))).go();
    await (delete(paperRobots)..where((r) => r.id.equals(id))).go();
  }

  // ── Ciclos ─────────────────────────────────────────────────────────────────

  Future<List<PaperCycle>> getCyclesForRobot(int robotId) =>
      (select(paperCycles)
        ..where((c) => c.robotId.equals(robotId))
        ..orderBy([(c) => OrderingTerm.desc(c.closedAt)]))
          .get();

  Future<List<PaperCycle>> getAllCycles() =>
      (select(paperCycles)..orderBy([(c) => OrderingTerm.desc(c.closedAt)])).get();

  Future<int> insertCycle(PaperCyclesCompanion cycle) =>
      into(paperCycles).insert(cycle);

  Future<double> getTotalProfit() async {
    final cycles = await getAllCycles();
    return cycles.fold<double>(0.0, (sum, c) => sum + c.profit);
  }

  Future<double> getRobotProfit(int robotId) async {
    final cycles = await getCyclesForRobot(robotId);
    return cycles.fold<double>(0.0, (sum, c) => sum + c.profit);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir  = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'paper_trading.db'));
    return NativeDatabase.createInBackground(file);
  });
}
