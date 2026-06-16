// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paper_trading_db.dart';

// ignore_for_file: type=lint
class $PaperRobotsTable extends PaperRobots
    with TableInfo<$PaperRobotsTable, PaperRobot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PaperRobotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
      'symbol', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _exchangeMeta =
      const VerificationMeta('exchange');
  @override
  late final GeneratedColumn<String> exchange = GeneratedColumn<String>(
      'exchange', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _upperBoundMeta =
      const VerificationMeta('upperBound');
  @override
  late final GeneratedColumn<double> upperBound = GeneratedColumn<double>(
      'upper_bound', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _lowerBoundMeta =
      const VerificationMeta('lowerBound');
  @override
  late final GeneratedColumn<double> lowerBound = GeneratedColumn<double>(
      'lower_bound', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _numGridsMeta =
      const VerificationMeta('numGrids');
  @override
  late final GeneratedColumn<int> numGrids = GeneratedColumn<int>(
      'num_grids', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _capitalMeta =
      const VerificationMeta('capital');
  @override
  late final GeneratedColumn<double> capital = GeneratedColumn<double>(
      'capital', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('running'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        symbol,
        exchange,
        upperBound,
        lowerBound,
        numGrids,
        capital,
        status,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'paper_robots';
  @override
  VerificationContext validateIntegrity(Insertable<PaperRobot> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('symbol')) {
      context.handle(_symbolMeta,
          symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta));
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('exchange')) {
      context.handle(_exchangeMeta,
          exchange.isAcceptableOrUnknown(data['exchange']!, _exchangeMeta));
    } else if (isInserting) {
      context.missing(_exchangeMeta);
    }
    if (data.containsKey('upper_bound')) {
      context.handle(
          _upperBoundMeta,
          upperBound.isAcceptableOrUnknown(
              data['upper_bound']!, _upperBoundMeta));
    } else if (isInserting) {
      context.missing(_upperBoundMeta);
    }
    if (data.containsKey('lower_bound')) {
      context.handle(
          _lowerBoundMeta,
          lowerBound.isAcceptableOrUnknown(
              data['lower_bound']!, _lowerBoundMeta));
    } else if (isInserting) {
      context.missing(_lowerBoundMeta);
    }
    if (data.containsKey('num_grids')) {
      context.handle(_numGridsMeta,
          numGrids.isAcceptableOrUnknown(data['num_grids']!, _numGridsMeta));
    } else if (isInserting) {
      context.missing(_numGridsMeta);
    }
    if (data.containsKey('capital')) {
      context.handle(_capitalMeta,
          capital.isAcceptableOrUnknown(data['capital']!, _capitalMeta));
    } else if (isInserting) {
      context.missing(_capitalMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PaperRobot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PaperRobot(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      symbol: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}symbol'])!,
      exchange: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}exchange'])!,
      upperBound: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}upper_bound'])!,
      lowerBound: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}lower_bound'])!,
      numGrids: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}num_grids'])!,
      capital: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}capital'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $PaperRobotsTable createAlias(String alias) {
    return $PaperRobotsTable(attachedDatabase, alias);
  }
}

class PaperRobot extends DataClass implements Insertable<PaperRobot> {
  final int id;
  final String symbol;
  final String exchange;
  final double upperBound;
  final double lowerBound;
  final int numGrids;
  final double capital;
  final String status;
  final DateTime createdAt;
  const PaperRobot(
      {required this.id,
      required this.symbol,
      required this.exchange,
      required this.upperBound,
      required this.lowerBound,
      required this.numGrids,
      required this.capital,
      required this.status,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['symbol'] = Variable<String>(symbol);
    map['exchange'] = Variable<String>(exchange);
    map['upper_bound'] = Variable<double>(upperBound);
    map['lower_bound'] = Variable<double>(lowerBound);
    map['num_grids'] = Variable<int>(numGrids);
    map['capital'] = Variable<double>(capital);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PaperRobotsCompanion toCompanion(bool nullToAbsent) {
    return PaperRobotsCompanion(
      id: Value(id),
      symbol: Value(symbol),
      exchange: Value(exchange),
      upperBound: Value(upperBound),
      lowerBound: Value(lowerBound),
      numGrids: Value(numGrids),
      capital: Value(capital),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory PaperRobot.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PaperRobot(
      id: serializer.fromJson<int>(json['id']),
      symbol: serializer.fromJson<String>(json['symbol']),
      exchange: serializer.fromJson<String>(json['exchange']),
      upperBound: serializer.fromJson<double>(json['upperBound']),
      lowerBound: serializer.fromJson<double>(json['lowerBound']),
      numGrids: serializer.fromJson<int>(json['numGrids']),
      capital: serializer.fromJson<double>(json['capital']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'symbol': serializer.toJson<String>(symbol),
      'exchange': serializer.toJson<String>(exchange),
      'upperBound': serializer.toJson<double>(upperBound),
      'lowerBound': serializer.toJson<double>(lowerBound),
      'numGrids': serializer.toJson<int>(numGrids),
      'capital': serializer.toJson<double>(capital),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PaperRobot copyWith(
          {int? id,
          String? symbol,
          String? exchange,
          double? upperBound,
          double? lowerBound,
          int? numGrids,
          double? capital,
          String? status,
          DateTime? createdAt}) =>
      PaperRobot(
        id: id ?? this.id,
        symbol: symbol ?? this.symbol,
        exchange: exchange ?? this.exchange,
        upperBound: upperBound ?? this.upperBound,
        lowerBound: lowerBound ?? this.lowerBound,
        numGrids: numGrids ?? this.numGrids,
        capital: capital ?? this.capital,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
      );
  PaperRobot copyWithCompanion(PaperRobotsCompanion data) {
    return PaperRobot(
      id: data.id.present ? data.id.value : this.id,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      exchange: data.exchange.present ? data.exchange.value : this.exchange,
      upperBound:
          data.upperBound.present ? data.upperBound.value : this.upperBound,
      lowerBound:
          data.lowerBound.present ? data.lowerBound.value : this.lowerBound,
      numGrids: data.numGrids.present ? data.numGrids.value : this.numGrids,
      capital: data.capital.present ? data.capital.value : this.capital,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PaperRobot(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('exchange: $exchange, ')
          ..write('upperBound: $upperBound, ')
          ..write('lowerBound: $lowerBound, ')
          ..write('numGrids: $numGrids, ')
          ..write('capital: $capital, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, symbol, exchange, upperBound, lowerBound,
      numGrids, capital, status, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PaperRobot &&
          other.id == this.id &&
          other.symbol == this.symbol &&
          other.exchange == this.exchange &&
          other.upperBound == this.upperBound &&
          other.lowerBound == this.lowerBound &&
          other.numGrids == this.numGrids &&
          other.capital == this.capital &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class PaperRobotsCompanion extends UpdateCompanion<PaperRobot> {
  final Value<int> id;
  final Value<String> symbol;
  final Value<String> exchange;
  final Value<double> upperBound;
  final Value<double> lowerBound;
  final Value<int> numGrids;
  final Value<double> capital;
  final Value<String> status;
  final Value<DateTime> createdAt;
  const PaperRobotsCompanion({
    this.id = const Value.absent(),
    this.symbol = const Value.absent(),
    this.exchange = const Value.absent(),
    this.upperBound = const Value.absent(),
    this.lowerBound = const Value.absent(),
    this.numGrids = const Value.absent(),
    this.capital = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PaperRobotsCompanion.insert({
    this.id = const Value.absent(),
    required String symbol,
    required String exchange,
    required double upperBound,
    required double lowerBound,
    required int numGrids,
    required double capital,
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : symbol = Value(symbol),
        exchange = Value(exchange),
        upperBound = Value(upperBound),
        lowerBound = Value(lowerBound),
        numGrids = Value(numGrids),
        capital = Value(capital);
  static Insertable<PaperRobot> custom({
    Expression<int>? id,
    Expression<String>? symbol,
    Expression<String>? exchange,
    Expression<double>? upperBound,
    Expression<double>? lowerBound,
    Expression<int>? numGrids,
    Expression<double>? capital,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (symbol != null) 'symbol': symbol,
      if (exchange != null) 'exchange': exchange,
      if (upperBound != null) 'upper_bound': upperBound,
      if (lowerBound != null) 'lower_bound': lowerBound,
      if (numGrids != null) 'num_grids': numGrids,
      if (capital != null) 'capital': capital,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PaperRobotsCompanion copyWith(
      {Value<int>? id,
      Value<String>? symbol,
      Value<String>? exchange,
      Value<double>? upperBound,
      Value<double>? lowerBound,
      Value<int>? numGrids,
      Value<double>? capital,
      Value<String>? status,
      Value<DateTime>? createdAt}) {
    return PaperRobotsCompanion(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      exchange: exchange ?? this.exchange,
      upperBound: upperBound ?? this.upperBound,
      lowerBound: lowerBound ?? this.lowerBound,
      numGrids: numGrids ?? this.numGrids,
      capital: capital ?? this.capital,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (exchange.present) {
      map['exchange'] = Variable<String>(exchange.value);
    }
    if (upperBound.present) {
      map['upper_bound'] = Variable<double>(upperBound.value);
    }
    if (lowerBound.present) {
      map['lower_bound'] = Variable<double>(lowerBound.value);
    }
    if (numGrids.present) {
      map['num_grids'] = Variable<int>(numGrids.value);
    }
    if (capital.present) {
      map['capital'] = Variable<double>(capital.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaperRobotsCompanion(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('exchange: $exchange, ')
          ..write('upperBound: $upperBound, ')
          ..write('lowerBound: $lowerBound, ')
          ..write('numGrids: $numGrids, ')
          ..write('capital: $capital, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PaperCyclesTable extends PaperCycles
    with TableInfo<$PaperCyclesTable, PaperCycle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PaperCyclesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _robotIdMeta =
      const VerificationMeta('robotId');
  @override
  late final GeneratedColumn<int> robotId = GeneratedColumn<int>(
      'robot_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES paper_robots (id)'));
  static const VerificationMeta _buyPriceMeta =
      const VerificationMeta('buyPrice');
  @override
  late final GeneratedColumn<double> buyPrice = GeneratedColumn<double>(
      'buy_price', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _sellPriceMeta =
      const VerificationMeta('sellPrice');
  @override
  late final GeneratedColumn<double> sellPrice = GeneratedColumn<double>(
      'sell_price', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _profitMeta = const VerificationMeta('profit');
  @override
  late final GeneratedColumn<double> profit = GeneratedColumn<double>(
      'profit', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<double> qty = GeneratedColumn<double>(
      'qty', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _closedAtMeta =
      const VerificationMeta('closedAt');
  @override
  late final GeneratedColumn<DateTime> closedAt = GeneratedColumn<DateTime>(
      'closed_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, robotId, buyPrice, sellPrice, profit, qty, closedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'paper_cycles';
  @override
  VerificationContext validateIntegrity(Insertable<PaperCycle> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('robot_id')) {
      context.handle(_robotIdMeta,
          robotId.isAcceptableOrUnknown(data['robot_id']!, _robotIdMeta));
    } else if (isInserting) {
      context.missing(_robotIdMeta);
    }
    if (data.containsKey('buy_price')) {
      context.handle(_buyPriceMeta,
          buyPrice.isAcceptableOrUnknown(data['buy_price']!, _buyPriceMeta));
    } else if (isInserting) {
      context.missing(_buyPriceMeta);
    }
    if (data.containsKey('sell_price')) {
      context.handle(_sellPriceMeta,
          sellPrice.isAcceptableOrUnknown(data['sell_price']!, _sellPriceMeta));
    } else if (isInserting) {
      context.missing(_sellPriceMeta);
    }
    if (data.containsKey('profit')) {
      context.handle(_profitMeta,
          profit.isAcceptableOrUnknown(data['profit']!, _profitMeta));
    } else if (isInserting) {
      context.missing(_profitMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
          _qtyMeta, qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta));
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    if (data.containsKey('closed_at')) {
      context.handle(_closedAtMeta,
          closedAt.isAcceptableOrUnknown(data['closed_at']!, _closedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PaperCycle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PaperCycle(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      robotId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}robot_id'])!,
      buyPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}buy_price'])!,
      sellPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}sell_price'])!,
      profit: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}profit'])!,
      qty: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}qty'])!,
      closedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}closed_at'])!,
    );
  }

  @override
  $PaperCyclesTable createAlias(String alias) {
    return $PaperCyclesTable(attachedDatabase, alias);
  }
}

class PaperCycle extends DataClass implements Insertable<PaperCycle> {
  final int id;
  final int robotId;
  final double buyPrice;
  final double sellPrice;
  final double profit;
  final double qty;
  final DateTime closedAt;
  const PaperCycle(
      {required this.id,
      required this.robotId,
      required this.buyPrice,
      required this.sellPrice,
      required this.profit,
      required this.qty,
      required this.closedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['robot_id'] = Variable<int>(robotId);
    map['buy_price'] = Variable<double>(buyPrice);
    map['sell_price'] = Variable<double>(sellPrice);
    map['profit'] = Variable<double>(profit);
    map['qty'] = Variable<double>(qty);
    map['closed_at'] = Variable<DateTime>(closedAt);
    return map;
  }

  PaperCyclesCompanion toCompanion(bool nullToAbsent) {
    return PaperCyclesCompanion(
      id: Value(id),
      robotId: Value(robotId),
      buyPrice: Value(buyPrice),
      sellPrice: Value(sellPrice),
      profit: Value(profit),
      qty: Value(qty),
      closedAt: Value(closedAt),
    );
  }

  factory PaperCycle.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PaperCycle(
      id: serializer.fromJson<int>(json['id']),
      robotId: serializer.fromJson<int>(json['robotId']),
      buyPrice: serializer.fromJson<double>(json['buyPrice']),
      sellPrice: serializer.fromJson<double>(json['sellPrice']),
      profit: serializer.fromJson<double>(json['profit']),
      qty: serializer.fromJson<double>(json['qty']),
      closedAt: serializer.fromJson<DateTime>(json['closedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'robotId': serializer.toJson<int>(robotId),
      'buyPrice': serializer.toJson<double>(buyPrice),
      'sellPrice': serializer.toJson<double>(sellPrice),
      'profit': serializer.toJson<double>(profit),
      'qty': serializer.toJson<double>(qty),
      'closedAt': serializer.toJson<DateTime>(closedAt),
    };
  }

  PaperCycle copyWith(
          {int? id,
          int? robotId,
          double? buyPrice,
          double? sellPrice,
          double? profit,
          double? qty,
          DateTime? closedAt}) =>
      PaperCycle(
        id: id ?? this.id,
        robotId: robotId ?? this.robotId,
        buyPrice: buyPrice ?? this.buyPrice,
        sellPrice: sellPrice ?? this.sellPrice,
        profit: profit ?? this.profit,
        qty: qty ?? this.qty,
        closedAt: closedAt ?? this.closedAt,
      );
  PaperCycle copyWithCompanion(PaperCyclesCompanion data) {
    return PaperCycle(
      id: data.id.present ? data.id.value : this.id,
      robotId: data.robotId.present ? data.robotId.value : this.robotId,
      buyPrice: data.buyPrice.present ? data.buyPrice.value : this.buyPrice,
      sellPrice: data.sellPrice.present ? data.sellPrice.value : this.sellPrice,
      profit: data.profit.present ? data.profit.value : this.profit,
      qty: data.qty.present ? data.qty.value : this.qty,
      closedAt: data.closedAt.present ? data.closedAt.value : this.closedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PaperCycle(')
          ..write('id: $id, ')
          ..write('robotId: $robotId, ')
          ..write('buyPrice: $buyPrice, ')
          ..write('sellPrice: $sellPrice, ')
          ..write('profit: $profit, ')
          ..write('qty: $qty, ')
          ..write('closedAt: $closedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, robotId, buyPrice, sellPrice, profit, qty, closedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PaperCycle &&
          other.id == this.id &&
          other.robotId == this.robotId &&
          other.buyPrice == this.buyPrice &&
          other.sellPrice == this.sellPrice &&
          other.profit == this.profit &&
          other.qty == this.qty &&
          other.closedAt == this.closedAt);
}

class PaperCyclesCompanion extends UpdateCompanion<PaperCycle> {
  final Value<int> id;
  final Value<int> robotId;
  final Value<double> buyPrice;
  final Value<double> sellPrice;
  final Value<double> profit;
  final Value<double> qty;
  final Value<DateTime> closedAt;
  const PaperCyclesCompanion({
    this.id = const Value.absent(),
    this.robotId = const Value.absent(),
    this.buyPrice = const Value.absent(),
    this.sellPrice = const Value.absent(),
    this.profit = const Value.absent(),
    this.qty = const Value.absent(),
    this.closedAt = const Value.absent(),
  });
  PaperCyclesCompanion.insert({
    this.id = const Value.absent(),
    required int robotId,
    required double buyPrice,
    required double sellPrice,
    required double profit,
    required double qty,
    this.closedAt = const Value.absent(),
  })  : robotId = Value(robotId),
        buyPrice = Value(buyPrice),
        sellPrice = Value(sellPrice),
        profit = Value(profit),
        qty = Value(qty);
  static Insertable<PaperCycle> custom({
    Expression<int>? id,
    Expression<int>? robotId,
    Expression<double>? buyPrice,
    Expression<double>? sellPrice,
    Expression<double>? profit,
    Expression<double>? qty,
    Expression<DateTime>? closedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (robotId != null) 'robot_id': robotId,
      if (buyPrice != null) 'buy_price': buyPrice,
      if (sellPrice != null) 'sell_price': sellPrice,
      if (profit != null) 'profit': profit,
      if (qty != null) 'qty': qty,
      if (closedAt != null) 'closed_at': closedAt,
    });
  }

  PaperCyclesCompanion copyWith(
      {Value<int>? id,
      Value<int>? robotId,
      Value<double>? buyPrice,
      Value<double>? sellPrice,
      Value<double>? profit,
      Value<double>? qty,
      Value<DateTime>? closedAt}) {
    return PaperCyclesCompanion(
      id: id ?? this.id,
      robotId: robotId ?? this.robotId,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      profit: profit ?? this.profit,
      qty: qty ?? this.qty,
      closedAt: closedAt ?? this.closedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (robotId.present) {
      map['robot_id'] = Variable<int>(robotId.value);
    }
    if (buyPrice.present) {
      map['buy_price'] = Variable<double>(buyPrice.value);
    }
    if (sellPrice.present) {
      map['sell_price'] = Variable<double>(sellPrice.value);
    }
    if (profit.present) {
      map['profit'] = Variable<double>(profit.value);
    }
    if (qty.present) {
      map['qty'] = Variable<double>(qty.value);
    }
    if (closedAt.present) {
      map['closed_at'] = Variable<DateTime>(closedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaperCyclesCompanion(')
          ..write('id: $id, ')
          ..write('robotId: $robotId, ')
          ..write('buyPrice: $buyPrice, ')
          ..write('sellPrice: $sellPrice, ')
          ..write('profit: $profit, ')
          ..write('qty: $qty, ')
          ..write('closedAt: $closedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$PaperTradingDatabase extends GeneratedDatabase {
  _$PaperTradingDatabase(QueryExecutor e) : super(e);
  $PaperTradingDatabaseManager get managers =>
      $PaperTradingDatabaseManager(this);
  late final $PaperRobotsTable paperRobots = $PaperRobotsTable(this);
  late final $PaperCyclesTable paperCycles = $PaperCyclesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [paperRobots, paperCycles];
}

typedef $$PaperRobotsTableCreateCompanionBuilder = PaperRobotsCompanion
    Function({
  Value<int> id,
  required String symbol,
  required String exchange,
  required double upperBound,
  required double lowerBound,
  required int numGrids,
  required double capital,
  Value<String> status,
  Value<DateTime> createdAt,
});
typedef $$PaperRobotsTableUpdateCompanionBuilder = PaperRobotsCompanion
    Function({
  Value<int> id,
  Value<String> symbol,
  Value<String> exchange,
  Value<double> upperBound,
  Value<double> lowerBound,
  Value<int> numGrids,
  Value<double> capital,
  Value<String> status,
  Value<DateTime> createdAt,
});

final class $$PaperRobotsTableReferences extends BaseReferences<
    _$PaperTradingDatabase, $PaperRobotsTable, PaperRobot> {
  $$PaperRobotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PaperCyclesTable, List<PaperCycle>>
      _paperCyclesRefsTable(_$PaperTradingDatabase db) =>
          MultiTypedResultKey.fromTable(db.paperCycles,
              aliasName: $_aliasNameGenerator(
                  db.paperRobots.id, db.paperCycles.robotId));

  $$PaperCyclesTableProcessedTableManager get paperCyclesRefs {
    final manager = $$PaperCyclesTableTableManager($_db, $_db.paperCycles)
        .filter((f) => f.robotId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_paperCyclesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$PaperRobotsTableFilterComposer
    extends Composer<_$PaperTradingDatabase, $PaperRobotsTable> {
  $$PaperRobotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get symbol => $composableBuilder(
      column: $table.symbol, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get exchange => $composableBuilder(
      column: $table.exchange, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get upperBound => $composableBuilder(
      column: $table.upperBound, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lowerBound => $composableBuilder(
      column: $table.lowerBound, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get numGrids => $composableBuilder(
      column: $table.numGrids, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get capital => $composableBuilder(
      column: $table.capital, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> paperCyclesRefs(
      Expression<bool> Function($$PaperCyclesTableFilterComposer f) f) {
    final $$PaperCyclesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.paperCycles,
        getReferencedColumn: (t) => t.robotId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PaperCyclesTableFilterComposer(
              $db: $db,
              $table: $db.paperCycles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PaperRobotsTableOrderingComposer
    extends Composer<_$PaperTradingDatabase, $PaperRobotsTable> {
  $$PaperRobotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get symbol => $composableBuilder(
      column: $table.symbol, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get exchange => $composableBuilder(
      column: $table.exchange, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get upperBound => $composableBuilder(
      column: $table.upperBound, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lowerBound => $composableBuilder(
      column: $table.lowerBound, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get numGrids => $composableBuilder(
      column: $table.numGrids, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get capital => $composableBuilder(
      column: $table.capital, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$PaperRobotsTableAnnotationComposer
    extends Composer<_$PaperTradingDatabase, $PaperRobotsTable> {
  $$PaperRobotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<String> get exchange =>
      $composableBuilder(column: $table.exchange, builder: (column) => column);

  GeneratedColumn<double> get upperBound => $composableBuilder(
      column: $table.upperBound, builder: (column) => column);

  GeneratedColumn<double> get lowerBound => $composableBuilder(
      column: $table.lowerBound, builder: (column) => column);

  GeneratedColumn<int> get numGrids =>
      $composableBuilder(column: $table.numGrids, builder: (column) => column);

  GeneratedColumn<double> get capital =>
      $composableBuilder(column: $table.capital, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> paperCyclesRefs<T extends Object>(
      Expression<T> Function($$PaperCyclesTableAnnotationComposer a) f) {
    final $$PaperCyclesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.paperCycles,
        getReferencedColumn: (t) => t.robotId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PaperCyclesTableAnnotationComposer(
              $db: $db,
              $table: $db.paperCycles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PaperRobotsTableTableManager extends RootTableManager<
    _$PaperTradingDatabase,
    $PaperRobotsTable,
    PaperRobot,
    $$PaperRobotsTableFilterComposer,
    $$PaperRobotsTableOrderingComposer,
    $$PaperRobotsTableAnnotationComposer,
    $$PaperRobotsTableCreateCompanionBuilder,
    $$PaperRobotsTableUpdateCompanionBuilder,
    (PaperRobot, $$PaperRobotsTableReferences),
    PaperRobot,
    PrefetchHooks Function({bool paperCyclesRefs})> {
  $$PaperRobotsTableTableManager(
      _$PaperTradingDatabase db, $PaperRobotsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PaperRobotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PaperRobotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PaperRobotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> symbol = const Value.absent(),
            Value<String> exchange = const Value.absent(),
            Value<double> upperBound = const Value.absent(),
            Value<double> lowerBound = const Value.absent(),
            Value<int> numGrids = const Value.absent(),
            Value<double> capital = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              PaperRobotsCompanion(
            id: id,
            symbol: symbol,
            exchange: exchange,
            upperBound: upperBound,
            lowerBound: lowerBound,
            numGrids: numGrids,
            capital: capital,
            status: status,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String symbol,
            required String exchange,
            required double upperBound,
            required double lowerBound,
            required int numGrids,
            required double capital,
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              PaperRobotsCompanion.insert(
            id: id,
            symbol: symbol,
            exchange: exchange,
            upperBound: upperBound,
            lowerBound: lowerBound,
            numGrids: numGrids,
            capital: capital,
            status: status,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PaperRobotsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({paperCyclesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (paperCyclesRefs) db.paperCycles],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (paperCyclesRefs)
                    await $_getPrefetchedData<PaperRobot, $PaperRobotsTable,
                            PaperCycle>(
                        currentTable: table,
                        referencedTable: $$PaperRobotsTableReferences
                            ._paperCyclesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PaperRobotsTableReferences(db, table, p0)
                                .paperCyclesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.robotId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$PaperRobotsTableProcessedTableManager = ProcessedTableManager<
    _$PaperTradingDatabase,
    $PaperRobotsTable,
    PaperRobot,
    $$PaperRobotsTableFilterComposer,
    $$PaperRobotsTableOrderingComposer,
    $$PaperRobotsTableAnnotationComposer,
    $$PaperRobotsTableCreateCompanionBuilder,
    $$PaperRobotsTableUpdateCompanionBuilder,
    (PaperRobot, $$PaperRobotsTableReferences),
    PaperRobot,
    PrefetchHooks Function({bool paperCyclesRefs})>;
typedef $$PaperCyclesTableCreateCompanionBuilder = PaperCyclesCompanion
    Function({
  Value<int> id,
  required int robotId,
  required double buyPrice,
  required double sellPrice,
  required double profit,
  required double qty,
  Value<DateTime> closedAt,
});
typedef $$PaperCyclesTableUpdateCompanionBuilder = PaperCyclesCompanion
    Function({
  Value<int> id,
  Value<int> robotId,
  Value<double> buyPrice,
  Value<double> sellPrice,
  Value<double> profit,
  Value<double> qty,
  Value<DateTime> closedAt,
});

final class $$PaperCyclesTableReferences extends BaseReferences<
    _$PaperTradingDatabase, $PaperCyclesTable, PaperCycle> {
  $$PaperCyclesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PaperRobotsTable _robotIdTable(_$PaperTradingDatabase db) =>
      db.paperRobots.createAlias(
          $_aliasNameGenerator(db.paperCycles.robotId, db.paperRobots.id));

  $$PaperRobotsTableProcessedTableManager get robotId {
    final $_column = $_itemColumn<int>('robot_id')!;

    final manager = $$PaperRobotsTableTableManager($_db, $_db.paperRobots)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_robotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PaperCyclesTableFilterComposer
    extends Composer<_$PaperTradingDatabase, $PaperCyclesTable> {
  $$PaperCyclesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get buyPrice => $composableBuilder(
      column: $table.buyPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get sellPrice => $composableBuilder(
      column: $table.sellPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get profit => $composableBuilder(
      column: $table.profit, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get qty => $composableBuilder(
      column: $table.qty, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get closedAt => $composableBuilder(
      column: $table.closedAt, builder: (column) => ColumnFilters(column));

  $$PaperRobotsTableFilterComposer get robotId {
    final $$PaperRobotsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.robotId,
        referencedTable: $db.paperRobots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PaperRobotsTableFilterComposer(
              $db: $db,
              $table: $db.paperRobots,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PaperCyclesTableOrderingComposer
    extends Composer<_$PaperTradingDatabase, $PaperCyclesTable> {
  $$PaperCyclesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get buyPrice => $composableBuilder(
      column: $table.buyPrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get sellPrice => $composableBuilder(
      column: $table.sellPrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get profit => $composableBuilder(
      column: $table.profit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get qty => $composableBuilder(
      column: $table.qty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get closedAt => $composableBuilder(
      column: $table.closedAt, builder: (column) => ColumnOrderings(column));

  $$PaperRobotsTableOrderingComposer get robotId {
    final $$PaperRobotsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.robotId,
        referencedTable: $db.paperRobots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PaperRobotsTableOrderingComposer(
              $db: $db,
              $table: $db.paperRobots,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PaperCyclesTableAnnotationComposer
    extends Composer<_$PaperTradingDatabase, $PaperCyclesTable> {
  $$PaperCyclesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get buyPrice =>
      $composableBuilder(column: $table.buyPrice, builder: (column) => column);

  GeneratedColumn<double> get sellPrice =>
      $composableBuilder(column: $table.sellPrice, builder: (column) => column);

  GeneratedColumn<double> get profit =>
      $composableBuilder(column: $table.profit, builder: (column) => column);

  GeneratedColumn<double> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<DateTime> get closedAt =>
      $composableBuilder(column: $table.closedAt, builder: (column) => column);

  $$PaperRobotsTableAnnotationComposer get robotId {
    final $$PaperRobotsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.robotId,
        referencedTable: $db.paperRobots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PaperRobotsTableAnnotationComposer(
              $db: $db,
              $table: $db.paperRobots,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PaperCyclesTableTableManager extends RootTableManager<
    _$PaperTradingDatabase,
    $PaperCyclesTable,
    PaperCycle,
    $$PaperCyclesTableFilterComposer,
    $$PaperCyclesTableOrderingComposer,
    $$PaperCyclesTableAnnotationComposer,
    $$PaperCyclesTableCreateCompanionBuilder,
    $$PaperCyclesTableUpdateCompanionBuilder,
    (PaperCycle, $$PaperCyclesTableReferences),
    PaperCycle,
    PrefetchHooks Function({bool robotId})> {
  $$PaperCyclesTableTableManager(
      _$PaperTradingDatabase db, $PaperCyclesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PaperCyclesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PaperCyclesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PaperCyclesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> robotId = const Value.absent(),
            Value<double> buyPrice = const Value.absent(),
            Value<double> sellPrice = const Value.absent(),
            Value<double> profit = const Value.absent(),
            Value<double> qty = const Value.absent(),
            Value<DateTime> closedAt = const Value.absent(),
          }) =>
              PaperCyclesCompanion(
            id: id,
            robotId: robotId,
            buyPrice: buyPrice,
            sellPrice: sellPrice,
            profit: profit,
            qty: qty,
            closedAt: closedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int robotId,
            required double buyPrice,
            required double sellPrice,
            required double profit,
            required double qty,
            Value<DateTime> closedAt = const Value.absent(),
          }) =>
              PaperCyclesCompanion.insert(
            id: id,
            robotId: robotId,
            buyPrice: buyPrice,
            sellPrice: sellPrice,
            profit: profit,
            qty: qty,
            closedAt: closedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PaperCyclesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({robotId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (robotId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.robotId,
                    referencedTable:
                        $$PaperCyclesTableReferences._robotIdTable(db),
                    referencedColumn:
                        $$PaperCyclesTableReferences._robotIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$PaperCyclesTableProcessedTableManager = ProcessedTableManager<
    _$PaperTradingDatabase,
    $PaperCyclesTable,
    PaperCycle,
    $$PaperCyclesTableFilterComposer,
    $$PaperCyclesTableOrderingComposer,
    $$PaperCyclesTableAnnotationComposer,
    $$PaperCyclesTableCreateCompanionBuilder,
    $$PaperCyclesTableUpdateCompanionBuilder,
    (PaperCycle, $$PaperCyclesTableReferences),
    PaperCycle,
    PrefetchHooks Function({bool robotId})>;

class $PaperTradingDatabaseManager {
  final _$PaperTradingDatabase _db;
  $PaperTradingDatabaseManager(this._db);
  $$PaperRobotsTableTableManager get paperRobots =>
      $$PaperRobotsTableTableManager(_db, _db.paperRobots);
  $$PaperCyclesTableTableManager get paperCycles =>
      $$PaperCyclesTableTableManager(_db, _db.paperCycles);
}
