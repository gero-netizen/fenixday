// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grid_db.dart';

// ignore_for_file: type=lint
class $GridsTable extends Grids with TableInfo<$GridsTable, Grid> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GridsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
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
  static const VerificationMeta _capitalUsdtMeta =
      const VerificationMeta('capitalUsdt');
  @override
  late final GeneratedColumn<double> capitalUsdt = GeneratedColumn<double>(
      'capital_usdt', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _niveisMeta = const VerificationMeta('niveis');
  @override
  late final GeneratedColumn<int> niveis = GeneratedColumn<int>(
      'niveis', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _limiteSuperiorMeta =
      const VerificationMeta('limiteSuperior');
  @override
  late final GeneratedColumn<double> limiteSuperior = GeneratedColumn<double>(
      'limite_superior', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _limiteInferiorMeta =
      const VerificationMeta('limiteInferior');
  @override
  late final GeneratedColumn<double> limiteInferior = GeneratedColumn<double>(
      'limite_inferior', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _espacamentoPctMeta =
      const VerificationMeta('espacamentoPct');
  @override
  late final GeneratedColumn<double> espacamentoPct = GeneratedColumn<double>(
      'espacamento_pct', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _margemLiquidaPctMeta =
      const VerificationMeta('margemLiquidaPct');
  @override
  late final GeneratedColumn<double> margemLiquidaPct = GeneratedColumn<double>(
      'margem_liquida_pct', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _adxEntradaMeta =
      const VerificationMeta('adxEntrada');
  @override
  late final GeneratedColumn<double> adxEntrada = GeneratedColumn<double>(
      'adx_entrada', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _atrPctEntradaMeta =
      const VerificationMeta('atrPctEntrada');
  @override
  late final GeneratedColumn<double> atrPctEntrada = GeneratedColumn<double>(
      'atr_pct_entrada', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _gradeEntradaMeta =
      const VerificationMeta('gradeEntrada');
  @override
  late final GeneratedColumn<String> gradeEntrada = GeneratedColumn<String>(
      'grade_entrada', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lucroRealizadoMeta =
      const VerificationMeta('lucroRealizado');
  @override
  late final GeneratedColumn<double> lucroRealizado = GeneratedColumn<double>(
      'lucro_realizado', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _ciclosFechadosMeta =
      const VerificationMeta('ciclosFechados');
  @override
  late final GeneratedColumn<int> ciclosFechados = GeneratedColumn<int>(
      'ciclos_fechados', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _volumeNegociadoMeta =
      const VerificationMeta('volumeNegociado');
  @override
  late final GeneratedColumn<double> volumeNegociado = GeneratedColumn<double>(
      'volume_negociado', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('active'));
  static const VerificationMeta _modoRealMeta =
      const VerificationMeta('modoReal');
  @override
  late final GeneratedColumn<bool> modoReal = GeneratedColumn<bool>(
      'modo_real', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("modo_real" IN (0, 1))'),
      defaultValue: const Constant(false));
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
        capitalUsdt,
        niveis,
        limiteSuperior,
        limiteInferior,
        espacamentoPct,
        margemLiquidaPct,
        adxEntrada,
        atrPctEntrada,
        gradeEntrada,
        lucroRealizado,
        ciclosFechados,
        volumeNegociado,
        status,
        modoReal,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'grids';
  @override
  VerificationContext validateIntegrity(Insertable<Grid> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
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
    if (data.containsKey('capital_usdt')) {
      context.handle(
          _capitalUsdtMeta,
          capitalUsdt.isAcceptableOrUnknown(
              data['capital_usdt']!, _capitalUsdtMeta));
    } else if (isInserting) {
      context.missing(_capitalUsdtMeta);
    }
    if (data.containsKey('niveis')) {
      context.handle(_niveisMeta,
          niveis.isAcceptableOrUnknown(data['niveis']!, _niveisMeta));
    } else if (isInserting) {
      context.missing(_niveisMeta);
    }
    if (data.containsKey('limite_superior')) {
      context.handle(
          _limiteSuperiorMeta,
          limiteSuperior.isAcceptableOrUnknown(
              data['limite_superior']!, _limiteSuperiorMeta));
    } else if (isInserting) {
      context.missing(_limiteSuperiorMeta);
    }
    if (data.containsKey('limite_inferior')) {
      context.handle(
          _limiteInferiorMeta,
          limiteInferior.isAcceptableOrUnknown(
              data['limite_inferior']!, _limiteInferiorMeta));
    } else if (isInserting) {
      context.missing(_limiteInferiorMeta);
    }
    if (data.containsKey('espacamento_pct')) {
      context.handle(
          _espacamentoPctMeta,
          espacamentoPct.isAcceptableOrUnknown(
              data['espacamento_pct']!, _espacamentoPctMeta));
    } else if (isInserting) {
      context.missing(_espacamentoPctMeta);
    }
    if (data.containsKey('margem_liquida_pct')) {
      context.handle(
          _margemLiquidaPctMeta,
          margemLiquidaPct.isAcceptableOrUnknown(
              data['margem_liquida_pct']!, _margemLiquidaPctMeta));
    } else if (isInserting) {
      context.missing(_margemLiquidaPctMeta);
    }
    if (data.containsKey('adx_entrada')) {
      context.handle(
          _adxEntradaMeta,
          adxEntrada.isAcceptableOrUnknown(
              data['adx_entrada']!, _adxEntradaMeta));
    }
    if (data.containsKey('atr_pct_entrada')) {
      context.handle(
          _atrPctEntradaMeta,
          atrPctEntrada.isAcceptableOrUnknown(
              data['atr_pct_entrada']!, _atrPctEntradaMeta));
    }
    if (data.containsKey('grade_entrada')) {
      context.handle(
          _gradeEntradaMeta,
          gradeEntrada.isAcceptableOrUnknown(
              data['grade_entrada']!, _gradeEntradaMeta));
    }
    if (data.containsKey('lucro_realizado')) {
      context.handle(
          _lucroRealizadoMeta,
          lucroRealizado.isAcceptableOrUnknown(
              data['lucro_realizado']!, _lucroRealizadoMeta));
    }
    if (data.containsKey('ciclos_fechados')) {
      context.handle(
          _ciclosFechadosMeta,
          ciclosFechados.isAcceptableOrUnknown(
              data['ciclos_fechados']!, _ciclosFechadosMeta));
    }
    if (data.containsKey('volume_negociado')) {
      context.handle(
          _volumeNegociadoMeta,
          volumeNegociado.isAcceptableOrUnknown(
              data['volume_negociado']!, _volumeNegociadoMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('modo_real')) {
      context.handle(_modoRealMeta,
          modoReal.isAcceptableOrUnknown(data['modo_real']!, _modoRealMeta));
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
  Grid map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Grid(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      symbol: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}symbol'])!,
      exchange: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}exchange'])!,
      capitalUsdt: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}capital_usdt'])!,
      niveis: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}niveis'])!,
      limiteSuperior: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}limite_superior'])!,
      limiteInferior: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}limite_inferior'])!,
      espacamentoPct: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}espacamento_pct'])!,
      margemLiquidaPct: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}margem_liquida_pct'])!,
      adxEntrada: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}adx_entrada']),
      atrPctEntrada: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}atr_pct_entrada']),
      gradeEntrada: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}grade_entrada']),
      lucroRealizado: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}lucro_realizado'])!,
      ciclosFechados: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ciclos_fechados'])!,
      volumeNegociado: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}volume_negociado'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      modoReal: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}modo_real'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $GridsTable createAlias(String alias) {
    return $GridsTable(attachedDatabase, alias);
  }
}

class Grid extends DataClass implements Insertable<Grid> {
  final String id;
  final String symbol;
  final String exchange;
  final double capitalUsdt;
  final int niveis;
  final double limiteSuperior;
  final double limiteInferior;
  final double espacamentoPct;
  final double margemLiquidaPct;
  final double? adxEntrada;
  final double? atrPctEntrada;
  final String? gradeEntrada;
  final double lucroRealizado;
  final int ciclosFechados;
  final double volumeNegociado;
  final String status;
  final bool modoReal;
  final DateTime createdAt;
  const Grid(
      {required this.id,
      required this.symbol,
      required this.exchange,
      required this.capitalUsdt,
      required this.niveis,
      required this.limiteSuperior,
      required this.limiteInferior,
      required this.espacamentoPct,
      required this.margemLiquidaPct,
      this.adxEntrada,
      this.atrPctEntrada,
      this.gradeEntrada,
      required this.lucroRealizado,
      required this.ciclosFechados,
      required this.volumeNegociado,
      required this.status,
      required this.modoReal,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['symbol'] = Variable<String>(symbol);
    map['exchange'] = Variable<String>(exchange);
    map['capital_usdt'] = Variable<double>(capitalUsdt);
    map['niveis'] = Variable<int>(niveis);
    map['limite_superior'] = Variable<double>(limiteSuperior);
    map['limite_inferior'] = Variable<double>(limiteInferior);
    map['espacamento_pct'] = Variable<double>(espacamentoPct);
    map['margem_liquida_pct'] = Variable<double>(margemLiquidaPct);
    if (!nullToAbsent || adxEntrada != null) {
      map['adx_entrada'] = Variable<double>(adxEntrada);
    }
    if (!nullToAbsent || atrPctEntrada != null) {
      map['atr_pct_entrada'] = Variable<double>(atrPctEntrada);
    }
    if (!nullToAbsent || gradeEntrada != null) {
      map['grade_entrada'] = Variable<String>(gradeEntrada);
    }
    map['lucro_realizado'] = Variable<double>(lucroRealizado);
    map['ciclos_fechados'] = Variable<int>(ciclosFechados);
    map['volume_negociado'] = Variable<double>(volumeNegociado);
    map['status'] = Variable<String>(status);
    map['modo_real'] = Variable<bool>(modoReal);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  GridsCompanion toCompanion(bool nullToAbsent) {
    return GridsCompanion(
      id: Value(id),
      symbol: Value(symbol),
      exchange: Value(exchange),
      capitalUsdt: Value(capitalUsdt),
      niveis: Value(niveis),
      limiteSuperior: Value(limiteSuperior),
      limiteInferior: Value(limiteInferior),
      espacamentoPct: Value(espacamentoPct),
      margemLiquidaPct: Value(margemLiquidaPct),
      adxEntrada: adxEntrada == null && nullToAbsent
          ? const Value.absent()
          : Value(adxEntrada),
      atrPctEntrada: atrPctEntrada == null && nullToAbsent
          ? const Value.absent()
          : Value(atrPctEntrada),
      gradeEntrada: gradeEntrada == null && nullToAbsent
          ? const Value.absent()
          : Value(gradeEntrada),
      lucroRealizado: Value(lucroRealizado),
      ciclosFechados: Value(ciclosFechados),
      volumeNegociado: Value(volumeNegociado),
      status: Value(status),
      modoReal: Value(modoReal),
      createdAt: Value(createdAt),
    );
  }

  factory Grid.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Grid(
      id: serializer.fromJson<String>(json['id']),
      symbol: serializer.fromJson<String>(json['symbol']),
      exchange: serializer.fromJson<String>(json['exchange']),
      capitalUsdt: serializer.fromJson<double>(json['capitalUsdt']),
      niveis: serializer.fromJson<int>(json['niveis']),
      limiteSuperior: serializer.fromJson<double>(json['limiteSuperior']),
      limiteInferior: serializer.fromJson<double>(json['limiteInferior']),
      espacamentoPct: serializer.fromJson<double>(json['espacamentoPct']),
      margemLiquidaPct: serializer.fromJson<double>(json['margemLiquidaPct']),
      adxEntrada: serializer.fromJson<double?>(json['adxEntrada']),
      atrPctEntrada: serializer.fromJson<double?>(json['atrPctEntrada']),
      gradeEntrada: serializer.fromJson<String?>(json['gradeEntrada']),
      lucroRealizado: serializer.fromJson<double>(json['lucroRealizado']),
      ciclosFechados: serializer.fromJson<int>(json['ciclosFechados']),
      volumeNegociado: serializer.fromJson<double>(json['volumeNegociado']),
      status: serializer.fromJson<String>(json['status']),
      modoReal: serializer.fromJson<bool>(json['modoReal']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'symbol': serializer.toJson<String>(symbol),
      'exchange': serializer.toJson<String>(exchange),
      'capitalUsdt': serializer.toJson<double>(capitalUsdt),
      'niveis': serializer.toJson<int>(niveis),
      'limiteSuperior': serializer.toJson<double>(limiteSuperior),
      'limiteInferior': serializer.toJson<double>(limiteInferior),
      'espacamentoPct': serializer.toJson<double>(espacamentoPct),
      'margemLiquidaPct': serializer.toJson<double>(margemLiquidaPct),
      'adxEntrada': serializer.toJson<double?>(adxEntrada),
      'atrPctEntrada': serializer.toJson<double?>(atrPctEntrada),
      'gradeEntrada': serializer.toJson<String?>(gradeEntrada),
      'lucroRealizado': serializer.toJson<double>(lucroRealizado),
      'ciclosFechados': serializer.toJson<int>(ciclosFechados),
      'volumeNegociado': serializer.toJson<double>(volumeNegociado),
      'status': serializer.toJson<String>(status),
      'modoReal': serializer.toJson<bool>(modoReal),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Grid copyWith(
          {String? id,
          String? symbol,
          String? exchange,
          double? capitalUsdt,
          int? niveis,
          double? limiteSuperior,
          double? limiteInferior,
          double? espacamentoPct,
          double? margemLiquidaPct,
          Value<double?> adxEntrada = const Value.absent(),
          Value<double?> atrPctEntrada = const Value.absent(),
          Value<String?> gradeEntrada = const Value.absent(),
          double? lucroRealizado,
          int? ciclosFechados,
          double? volumeNegociado,
          String? status,
          bool? modoReal,
          DateTime? createdAt}) =>
      Grid(
        id: id ?? this.id,
        symbol: symbol ?? this.symbol,
        exchange: exchange ?? this.exchange,
        capitalUsdt: capitalUsdt ?? this.capitalUsdt,
        niveis: niveis ?? this.niveis,
        limiteSuperior: limiteSuperior ?? this.limiteSuperior,
        limiteInferior: limiteInferior ?? this.limiteInferior,
        espacamentoPct: espacamentoPct ?? this.espacamentoPct,
        margemLiquidaPct: margemLiquidaPct ?? this.margemLiquidaPct,
        adxEntrada: adxEntrada.present ? adxEntrada.value : this.adxEntrada,
        atrPctEntrada:
            atrPctEntrada.present ? atrPctEntrada.value : this.atrPctEntrada,
        gradeEntrada:
            gradeEntrada.present ? gradeEntrada.value : this.gradeEntrada,
        lucroRealizado: lucroRealizado ?? this.lucroRealizado,
        ciclosFechados: ciclosFechados ?? this.ciclosFechados,
        volumeNegociado: volumeNegociado ?? this.volumeNegociado,
        status: status ?? this.status,
        modoReal: modoReal ?? this.modoReal,
        createdAt: createdAt ?? this.createdAt,
      );
  Grid copyWithCompanion(GridsCompanion data) {
    return Grid(
      id: data.id.present ? data.id.value : this.id,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      exchange: data.exchange.present ? data.exchange.value : this.exchange,
      capitalUsdt:
          data.capitalUsdt.present ? data.capitalUsdt.value : this.capitalUsdt,
      niveis: data.niveis.present ? data.niveis.value : this.niveis,
      limiteSuperior: data.limiteSuperior.present
          ? data.limiteSuperior.value
          : this.limiteSuperior,
      limiteInferior: data.limiteInferior.present
          ? data.limiteInferior.value
          : this.limiteInferior,
      espacamentoPct: data.espacamentoPct.present
          ? data.espacamentoPct.value
          : this.espacamentoPct,
      margemLiquidaPct: data.margemLiquidaPct.present
          ? data.margemLiquidaPct.value
          : this.margemLiquidaPct,
      adxEntrada:
          data.adxEntrada.present ? data.adxEntrada.value : this.adxEntrada,
      atrPctEntrada: data.atrPctEntrada.present
          ? data.atrPctEntrada.value
          : this.atrPctEntrada,
      gradeEntrada: data.gradeEntrada.present
          ? data.gradeEntrada.value
          : this.gradeEntrada,
      lucroRealizado: data.lucroRealizado.present
          ? data.lucroRealizado.value
          : this.lucroRealizado,
      ciclosFechados: data.ciclosFechados.present
          ? data.ciclosFechados.value
          : this.ciclosFechados,
      volumeNegociado: data.volumeNegociado.present
          ? data.volumeNegociado.value
          : this.volumeNegociado,
      status: data.status.present ? data.status.value : this.status,
      modoReal: data.modoReal.present ? data.modoReal.value : this.modoReal,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Grid(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('exchange: $exchange, ')
          ..write('capitalUsdt: $capitalUsdt, ')
          ..write('niveis: $niveis, ')
          ..write('limiteSuperior: $limiteSuperior, ')
          ..write('limiteInferior: $limiteInferior, ')
          ..write('espacamentoPct: $espacamentoPct, ')
          ..write('margemLiquidaPct: $margemLiquidaPct, ')
          ..write('adxEntrada: $adxEntrada, ')
          ..write('atrPctEntrada: $atrPctEntrada, ')
          ..write('gradeEntrada: $gradeEntrada, ')
          ..write('lucroRealizado: $lucroRealizado, ')
          ..write('ciclosFechados: $ciclosFechados, ')
          ..write('volumeNegociado: $volumeNegociado, ')
          ..write('status: $status, ')
          ..write('modoReal: $modoReal, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      symbol,
      exchange,
      capitalUsdt,
      niveis,
      limiteSuperior,
      limiteInferior,
      espacamentoPct,
      margemLiquidaPct,
      adxEntrada,
      atrPctEntrada,
      gradeEntrada,
      lucroRealizado,
      ciclosFechados,
      volumeNegociado,
      status,
      modoReal,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Grid &&
          other.id == this.id &&
          other.symbol == this.symbol &&
          other.exchange == this.exchange &&
          other.capitalUsdt == this.capitalUsdt &&
          other.niveis == this.niveis &&
          other.limiteSuperior == this.limiteSuperior &&
          other.limiteInferior == this.limiteInferior &&
          other.espacamentoPct == this.espacamentoPct &&
          other.margemLiquidaPct == this.margemLiquidaPct &&
          other.adxEntrada == this.adxEntrada &&
          other.atrPctEntrada == this.atrPctEntrada &&
          other.gradeEntrada == this.gradeEntrada &&
          other.lucroRealizado == this.lucroRealizado &&
          other.ciclosFechados == this.ciclosFechados &&
          other.volumeNegociado == this.volumeNegociado &&
          other.status == this.status &&
          other.modoReal == this.modoReal &&
          other.createdAt == this.createdAt);
}

class GridsCompanion extends UpdateCompanion<Grid> {
  final Value<String> id;
  final Value<String> symbol;
  final Value<String> exchange;
  final Value<double> capitalUsdt;
  final Value<int> niveis;
  final Value<double> limiteSuperior;
  final Value<double> limiteInferior;
  final Value<double> espacamentoPct;
  final Value<double> margemLiquidaPct;
  final Value<double?> adxEntrada;
  final Value<double?> atrPctEntrada;
  final Value<String?> gradeEntrada;
  final Value<double> lucroRealizado;
  final Value<int> ciclosFechados;
  final Value<double> volumeNegociado;
  final Value<String> status;
  final Value<bool> modoReal;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const GridsCompanion({
    this.id = const Value.absent(),
    this.symbol = const Value.absent(),
    this.exchange = const Value.absent(),
    this.capitalUsdt = const Value.absent(),
    this.niveis = const Value.absent(),
    this.limiteSuperior = const Value.absent(),
    this.limiteInferior = const Value.absent(),
    this.espacamentoPct = const Value.absent(),
    this.margemLiquidaPct = const Value.absent(),
    this.adxEntrada = const Value.absent(),
    this.atrPctEntrada = const Value.absent(),
    this.gradeEntrada = const Value.absent(),
    this.lucroRealizado = const Value.absent(),
    this.ciclosFechados = const Value.absent(),
    this.volumeNegociado = const Value.absent(),
    this.status = const Value.absent(),
    this.modoReal = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GridsCompanion.insert({
    required String id,
    required String symbol,
    required String exchange,
    required double capitalUsdt,
    required int niveis,
    required double limiteSuperior,
    required double limiteInferior,
    required double espacamentoPct,
    required double margemLiquidaPct,
    this.adxEntrada = const Value.absent(),
    this.atrPctEntrada = const Value.absent(),
    this.gradeEntrada = const Value.absent(),
    this.lucroRealizado = const Value.absent(),
    this.ciclosFechados = const Value.absent(),
    this.volumeNegociado = const Value.absent(),
    this.status = const Value.absent(),
    this.modoReal = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        symbol = Value(symbol),
        exchange = Value(exchange),
        capitalUsdt = Value(capitalUsdt),
        niveis = Value(niveis),
        limiteSuperior = Value(limiteSuperior),
        limiteInferior = Value(limiteInferior),
        espacamentoPct = Value(espacamentoPct),
        margemLiquidaPct = Value(margemLiquidaPct);
  static Insertable<Grid> custom({
    Expression<String>? id,
    Expression<String>? symbol,
    Expression<String>? exchange,
    Expression<double>? capitalUsdt,
    Expression<int>? niveis,
    Expression<double>? limiteSuperior,
    Expression<double>? limiteInferior,
    Expression<double>? espacamentoPct,
    Expression<double>? margemLiquidaPct,
    Expression<double>? adxEntrada,
    Expression<double>? atrPctEntrada,
    Expression<String>? gradeEntrada,
    Expression<double>? lucroRealizado,
    Expression<int>? ciclosFechados,
    Expression<double>? volumeNegociado,
    Expression<String>? status,
    Expression<bool>? modoReal,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (symbol != null) 'symbol': symbol,
      if (exchange != null) 'exchange': exchange,
      if (capitalUsdt != null) 'capital_usdt': capitalUsdt,
      if (niveis != null) 'niveis': niveis,
      if (limiteSuperior != null) 'limite_superior': limiteSuperior,
      if (limiteInferior != null) 'limite_inferior': limiteInferior,
      if (espacamentoPct != null) 'espacamento_pct': espacamentoPct,
      if (margemLiquidaPct != null) 'margem_liquida_pct': margemLiquidaPct,
      if (adxEntrada != null) 'adx_entrada': adxEntrada,
      if (atrPctEntrada != null) 'atr_pct_entrada': atrPctEntrada,
      if (gradeEntrada != null) 'grade_entrada': gradeEntrada,
      if (lucroRealizado != null) 'lucro_realizado': lucroRealizado,
      if (ciclosFechados != null) 'ciclos_fechados': ciclosFechados,
      if (volumeNegociado != null) 'volume_negociado': volumeNegociado,
      if (status != null) 'status': status,
      if (modoReal != null) 'modo_real': modoReal,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GridsCompanion copyWith(
      {Value<String>? id,
      Value<String>? symbol,
      Value<String>? exchange,
      Value<double>? capitalUsdt,
      Value<int>? niveis,
      Value<double>? limiteSuperior,
      Value<double>? limiteInferior,
      Value<double>? espacamentoPct,
      Value<double>? margemLiquidaPct,
      Value<double?>? adxEntrada,
      Value<double?>? atrPctEntrada,
      Value<String?>? gradeEntrada,
      Value<double>? lucroRealizado,
      Value<int>? ciclosFechados,
      Value<double>? volumeNegociado,
      Value<String>? status,
      Value<bool>? modoReal,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return GridsCompanion(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      exchange: exchange ?? this.exchange,
      capitalUsdt: capitalUsdt ?? this.capitalUsdt,
      niveis: niveis ?? this.niveis,
      limiteSuperior: limiteSuperior ?? this.limiteSuperior,
      limiteInferior: limiteInferior ?? this.limiteInferior,
      espacamentoPct: espacamentoPct ?? this.espacamentoPct,
      margemLiquidaPct: margemLiquidaPct ?? this.margemLiquidaPct,
      adxEntrada: adxEntrada ?? this.adxEntrada,
      atrPctEntrada: atrPctEntrada ?? this.atrPctEntrada,
      gradeEntrada: gradeEntrada ?? this.gradeEntrada,
      lucroRealizado: lucroRealizado ?? this.lucroRealizado,
      ciclosFechados: ciclosFechados ?? this.ciclosFechados,
      volumeNegociado: volumeNegociado ?? this.volumeNegociado,
      status: status ?? this.status,
      modoReal: modoReal ?? this.modoReal,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (exchange.present) {
      map['exchange'] = Variable<String>(exchange.value);
    }
    if (capitalUsdt.present) {
      map['capital_usdt'] = Variable<double>(capitalUsdt.value);
    }
    if (niveis.present) {
      map['niveis'] = Variable<int>(niveis.value);
    }
    if (limiteSuperior.present) {
      map['limite_superior'] = Variable<double>(limiteSuperior.value);
    }
    if (limiteInferior.present) {
      map['limite_inferior'] = Variable<double>(limiteInferior.value);
    }
    if (espacamentoPct.present) {
      map['espacamento_pct'] = Variable<double>(espacamentoPct.value);
    }
    if (margemLiquidaPct.present) {
      map['margem_liquida_pct'] = Variable<double>(margemLiquidaPct.value);
    }
    if (adxEntrada.present) {
      map['adx_entrada'] = Variable<double>(adxEntrada.value);
    }
    if (atrPctEntrada.present) {
      map['atr_pct_entrada'] = Variable<double>(atrPctEntrada.value);
    }
    if (gradeEntrada.present) {
      map['grade_entrada'] = Variable<String>(gradeEntrada.value);
    }
    if (lucroRealizado.present) {
      map['lucro_realizado'] = Variable<double>(lucroRealizado.value);
    }
    if (ciclosFechados.present) {
      map['ciclos_fechados'] = Variable<int>(ciclosFechados.value);
    }
    if (volumeNegociado.present) {
      map['volume_negociado'] = Variable<double>(volumeNegociado.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (modoReal.present) {
      map['modo_real'] = Variable<bool>(modoReal.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GridsCompanion(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('exchange: $exchange, ')
          ..write('capitalUsdt: $capitalUsdt, ')
          ..write('niveis: $niveis, ')
          ..write('limiteSuperior: $limiteSuperior, ')
          ..write('limiteInferior: $limiteInferior, ')
          ..write('espacamentoPct: $espacamentoPct, ')
          ..write('margemLiquidaPct: $margemLiquidaPct, ')
          ..write('adxEntrada: $adxEntrada, ')
          ..write('atrPctEntrada: $atrPctEntrada, ')
          ..write('gradeEntrada: $gradeEntrada, ')
          ..write('lucroRealizado: $lucroRealizado, ')
          ..write('ciclosFechados: $ciclosFechados, ')
          ..write('volumeNegociado: $volumeNegociado, ')
          ..write('status: $status, ')
          ..write('modoReal: $modoReal, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GridOrdersTable extends GridOrders
    with TableInfo<$GridOrdersTable, GridOrder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GridOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _gridIdMeta = const VerificationMeta('gridId');
  @override
  late final GeneratedColumn<String> gridId = GeneratedColumn<String>(
      'grid_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES grids (id)'));
  static const VerificationMeta _exchangeOrderIdMeta =
      const VerificationMeta('exchangeOrderId');
  @override
  late final GeneratedColumn<String> exchangeOrderId = GeneratedColumn<String>(
      'exchange_order_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nivelMeta = const VerificationMeta('nivel');
  @override
  late final GeneratedColumn<int> nivel = GeneratedColumn<int>(
      'nivel', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _ladoMeta = const VerificationMeta('lado');
  @override
  late final GeneratedColumn<String> lado = GeneratedColumn<String>(
      'lado', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _precoMeta = const VerificationMeta('preco');
  @override
  late final GeneratedColumn<double> preco = GeneratedColumn<double>(
      'preco', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _quantidadeMeta =
      const VerificationMeta('quantidade');
  @override
  late final GeneratedColumn<double> quantidade = GeneratedColumn<double>(
      'quantidade', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('open'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _filledAtMeta =
      const VerificationMeta('filledAt');
  @override
  late final GeneratedColumn<DateTime> filledAt = GeneratedColumn<DateTime>(
      'filled_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        gridId,
        exchangeOrderId,
        nivel,
        lado,
        preco,
        quantidade,
        status,
        createdAt,
        filledAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'grid_orders';
  @override
  VerificationContext validateIntegrity(Insertable<GridOrder> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('grid_id')) {
      context.handle(_gridIdMeta,
          gridId.isAcceptableOrUnknown(data['grid_id']!, _gridIdMeta));
    } else if (isInserting) {
      context.missing(_gridIdMeta);
    }
    if (data.containsKey('exchange_order_id')) {
      context.handle(
          _exchangeOrderIdMeta,
          exchangeOrderId.isAcceptableOrUnknown(
              data['exchange_order_id']!, _exchangeOrderIdMeta));
    }
    if (data.containsKey('nivel')) {
      context.handle(
          _nivelMeta, nivel.isAcceptableOrUnknown(data['nivel']!, _nivelMeta));
    } else if (isInserting) {
      context.missing(_nivelMeta);
    }
    if (data.containsKey('lado')) {
      context.handle(
          _ladoMeta, lado.isAcceptableOrUnknown(data['lado']!, _ladoMeta));
    } else if (isInserting) {
      context.missing(_ladoMeta);
    }
    if (data.containsKey('preco')) {
      context.handle(
          _precoMeta, preco.isAcceptableOrUnknown(data['preco']!, _precoMeta));
    } else if (isInserting) {
      context.missing(_precoMeta);
    }
    if (data.containsKey('quantidade')) {
      context.handle(
          _quantidadeMeta,
          quantidade.isAcceptableOrUnknown(
              data['quantidade']!, _quantidadeMeta));
    } else if (isInserting) {
      context.missing(_quantidadeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('filled_at')) {
      context.handle(_filledAtMeta,
          filledAt.isAcceptableOrUnknown(data['filled_at']!, _filledAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GridOrder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GridOrder(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      gridId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}grid_id'])!,
      exchangeOrderId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}exchange_order_id']),
      nivel: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}nivel'])!,
      lado: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lado'])!,
      preco: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}preco'])!,
      quantidade: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}quantidade'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      filledAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}filled_at']),
    );
  }

  @override
  $GridOrdersTable createAlias(String alias) {
    return $GridOrdersTable(attachedDatabase, alias);
  }
}

class GridOrder extends DataClass implements Insertable<GridOrder> {
  final int id;
  final String gridId;
  final String? exchangeOrderId;
  final int nivel;
  final String lado;
  final double preco;
  final double quantidade;
  final String status;
  final DateTime createdAt;
  final DateTime? filledAt;
  const GridOrder(
      {required this.id,
      required this.gridId,
      this.exchangeOrderId,
      required this.nivel,
      required this.lado,
      required this.preco,
      required this.quantidade,
      required this.status,
      required this.createdAt,
      this.filledAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['grid_id'] = Variable<String>(gridId);
    if (!nullToAbsent || exchangeOrderId != null) {
      map['exchange_order_id'] = Variable<String>(exchangeOrderId);
    }
    map['nivel'] = Variable<int>(nivel);
    map['lado'] = Variable<String>(lado);
    map['preco'] = Variable<double>(preco);
    map['quantidade'] = Variable<double>(quantidade);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || filledAt != null) {
      map['filled_at'] = Variable<DateTime>(filledAt);
    }
    return map;
  }

  GridOrdersCompanion toCompanion(bool nullToAbsent) {
    return GridOrdersCompanion(
      id: Value(id),
      gridId: Value(gridId),
      exchangeOrderId: exchangeOrderId == null && nullToAbsent
          ? const Value.absent()
          : Value(exchangeOrderId),
      nivel: Value(nivel),
      lado: Value(lado),
      preco: Value(preco),
      quantidade: Value(quantidade),
      status: Value(status),
      createdAt: Value(createdAt),
      filledAt: filledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(filledAt),
    );
  }

  factory GridOrder.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GridOrder(
      id: serializer.fromJson<int>(json['id']),
      gridId: serializer.fromJson<String>(json['gridId']),
      exchangeOrderId: serializer.fromJson<String?>(json['exchangeOrderId']),
      nivel: serializer.fromJson<int>(json['nivel']),
      lado: serializer.fromJson<String>(json['lado']),
      preco: serializer.fromJson<double>(json['preco']),
      quantidade: serializer.fromJson<double>(json['quantidade']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      filledAt: serializer.fromJson<DateTime?>(json['filledAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'gridId': serializer.toJson<String>(gridId),
      'exchangeOrderId': serializer.toJson<String?>(exchangeOrderId),
      'nivel': serializer.toJson<int>(nivel),
      'lado': serializer.toJson<String>(lado),
      'preco': serializer.toJson<double>(preco),
      'quantidade': serializer.toJson<double>(quantidade),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'filledAt': serializer.toJson<DateTime?>(filledAt),
    };
  }

  GridOrder copyWith(
          {int? id,
          String? gridId,
          Value<String?> exchangeOrderId = const Value.absent(),
          int? nivel,
          String? lado,
          double? preco,
          double? quantidade,
          String? status,
          DateTime? createdAt,
          Value<DateTime?> filledAt = const Value.absent()}) =>
      GridOrder(
        id: id ?? this.id,
        gridId: gridId ?? this.gridId,
        exchangeOrderId: exchangeOrderId.present
            ? exchangeOrderId.value
            : this.exchangeOrderId,
        nivel: nivel ?? this.nivel,
        lado: lado ?? this.lado,
        preco: preco ?? this.preco,
        quantidade: quantidade ?? this.quantidade,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        filledAt: filledAt.present ? filledAt.value : this.filledAt,
      );
  GridOrder copyWithCompanion(GridOrdersCompanion data) {
    return GridOrder(
      id: data.id.present ? data.id.value : this.id,
      gridId: data.gridId.present ? data.gridId.value : this.gridId,
      exchangeOrderId: data.exchangeOrderId.present
          ? data.exchangeOrderId.value
          : this.exchangeOrderId,
      nivel: data.nivel.present ? data.nivel.value : this.nivel,
      lado: data.lado.present ? data.lado.value : this.lado,
      preco: data.preco.present ? data.preco.value : this.preco,
      quantidade:
          data.quantidade.present ? data.quantidade.value : this.quantidade,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      filledAt: data.filledAt.present ? data.filledAt.value : this.filledAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GridOrder(')
          ..write('id: $id, ')
          ..write('gridId: $gridId, ')
          ..write('exchangeOrderId: $exchangeOrderId, ')
          ..write('nivel: $nivel, ')
          ..write('lado: $lado, ')
          ..write('preco: $preco, ')
          ..write('quantidade: $quantidade, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('filledAt: $filledAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, gridId, exchangeOrderId, nivel, lado,
      preco, quantidade, status, createdAt, filledAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GridOrder &&
          other.id == this.id &&
          other.gridId == this.gridId &&
          other.exchangeOrderId == this.exchangeOrderId &&
          other.nivel == this.nivel &&
          other.lado == this.lado &&
          other.preco == this.preco &&
          other.quantidade == this.quantidade &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.filledAt == this.filledAt);
}

class GridOrdersCompanion extends UpdateCompanion<GridOrder> {
  final Value<int> id;
  final Value<String> gridId;
  final Value<String?> exchangeOrderId;
  final Value<int> nivel;
  final Value<String> lado;
  final Value<double> preco;
  final Value<double> quantidade;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime?> filledAt;
  const GridOrdersCompanion({
    this.id = const Value.absent(),
    this.gridId = const Value.absent(),
    this.exchangeOrderId = const Value.absent(),
    this.nivel = const Value.absent(),
    this.lado = const Value.absent(),
    this.preco = const Value.absent(),
    this.quantidade = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.filledAt = const Value.absent(),
  });
  GridOrdersCompanion.insert({
    this.id = const Value.absent(),
    required String gridId,
    this.exchangeOrderId = const Value.absent(),
    required int nivel,
    required String lado,
    required double preco,
    required double quantidade,
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.filledAt = const Value.absent(),
  })  : gridId = Value(gridId),
        nivel = Value(nivel),
        lado = Value(lado),
        preco = Value(preco),
        quantidade = Value(quantidade);
  static Insertable<GridOrder> custom({
    Expression<int>? id,
    Expression<String>? gridId,
    Expression<String>? exchangeOrderId,
    Expression<int>? nivel,
    Expression<String>? lado,
    Expression<double>? preco,
    Expression<double>? quantidade,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? filledAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (gridId != null) 'grid_id': gridId,
      if (exchangeOrderId != null) 'exchange_order_id': exchangeOrderId,
      if (nivel != null) 'nivel': nivel,
      if (lado != null) 'lado': lado,
      if (preco != null) 'preco': preco,
      if (quantidade != null) 'quantidade': quantidade,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (filledAt != null) 'filled_at': filledAt,
    });
  }

  GridOrdersCompanion copyWith(
      {Value<int>? id,
      Value<String>? gridId,
      Value<String?>? exchangeOrderId,
      Value<int>? nivel,
      Value<String>? lado,
      Value<double>? preco,
      Value<double>? quantidade,
      Value<String>? status,
      Value<DateTime>? createdAt,
      Value<DateTime?>? filledAt}) {
    return GridOrdersCompanion(
      id: id ?? this.id,
      gridId: gridId ?? this.gridId,
      exchangeOrderId: exchangeOrderId ?? this.exchangeOrderId,
      nivel: nivel ?? this.nivel,
      lado: lado ?? this.lado,
      preco: preco ?? this.preco,
      quantidade: quantidade ?? this.quantidade,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      filledAt: filledAt ?? this.filledAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (gridId.present) {
      map['grid_id'] = Variable<String>(gridId.value);
    }
    if (exchangeOrderId.present) {
      map['exchange_order_id'] = Variable<String>(exchangeOrderId.value);
    }
    if (nivel.present) {
      map['nivel'] = Variable<int>(nivel.value);
    }
    if (lado.present) {
      map['lado'] = Variable<String>(lado.value);
    }
    if (preco.present) {
      map['preco'] = Variable<double>(preco.value);
    }
    if (quantidade.present) {
      map['quantidade'] = Variable<double>(quantidade.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (filledAt.present) {
      map['filled_at'] = Variable<DateTime>(filledAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GridOrdersCompanion(')
          ..write('id: $id, ')
          ..write('gridId: $gridId, ')
          ..write('exchangeOrderId: $exchangeOrderId, ')
          ..write('nivel: $nivel, ')
          ..write('lado: $lado, ')
          ..write('preco: $preco, ')
          ..write('quantidade: $quantidade, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('filledAt: $filledAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$GridDatabase extends GeneratedDatabase {
  _$GridDatabase(QueryExecutor e) : super(e);
  $GridDatabaseManager get managers => $GridDatabaseManager(this);
  late final $GridsTable grids = $GridsTable(this);
  late final $GridOrdersTable gridOrders = $GridOrdersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [grids, gridOrders];
}

typedef $$GridsTableCreateCompanionBuilder = GridsCompanion Function({
  required String id,
  required String symbol,
  required String exchange,
  required double capitalUsdt,
  required int niveis,
  required double limiteSuperior,
  required double limiteInferior,
  required double espacamentoPct,
  required double margemLiquidaPct,
  Value<double?> adxEntrada,
  Value<double?> atrPctEntrada,
  Value<String?> gradeEntrada,
  Value<double> lucroRealizado,
  Value<int> ciclosFechados,
  Value<double> volumeNegociado,
  Value<String> status,
  Value<bool> modoReal,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$GridsTableUpdateCompanionBuilder = GridsCompanion Function({
  Value<String> id,
  Value<String> symbol,
  Value<String> exchange,
  Value<double> capitalUsdt,
  Value<int> niveis,
  Value<double> limiteSuperior,
  Value<double> limiteInferior,
  Value<double> espacamentoPct,
  Value<double> margemLiquidaPct,
  Value<double?> adxEntrada,
  Value<double?> atrPctEntrada,
  Value<String?> gradeEntrada,
  Value<double> lucroRealizado,
  Value<int> ciclosFechados,
  Value<double> volumeNegociado,
  Value<String> status,
  Value<bool> modoReal,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$GridsTableReferences
    extends BaseReferences<_$GridDatabase, $GridsTable, Grid> {
  $$GridsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$GridOrdersTable, List<GridOrder>>
      _gridOrdersRefsTable(_$GridDatabase db) => MultiTypedResultKey.fromTable(
          db.gridOrders,
          aliasName: $_aliasNameGenerator(db.grids.id, db.gridOrders.gridId));

  $$GridOrdersTableProcessedTableManager get gridOrdersRefs {
    final manager = $$GridOrdersTableTableManager($_db, $_db.gridOrders)
        .filter((f) => f.gridId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_gridOrdersRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$GridsTableFilterComposer extends Composer<_$GridDatabase, $GridsTable> {
  $$GridsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get symbol => $composableBuilder(
      column: $table.symbol, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get exchange => $composableBuilder(
      column: $table.exchange, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get capitalUsdt => $composableBuilder(
      column: $table.capitalUsdt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get niveis => $composableBuilder(
      column: $table.niveis, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get limiteSuperior => $composableBuilder(
      column: $table.limiteSuperior,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get limiteInferior => $composableBuilder(
      column: $table.limiteInferior,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get espacamentoPct => $composableBuilder(
      column: $table.espacamentoPct,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get margemLiquidaPct => $composableBuilder(
      column: $table.margemLiquidaPct,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get adxEntrada => $composableBuilder(
      column: $table.adxEntrada, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get atrPctEntrada => $composableBuilder(
      column: $table.atrPctEntrada, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gradeEntrada => $composableBuilder(
      column: $table.gradeEntrada, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lucroRealizado => $composableBuilder(
      column: $table.lucroRealizado,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ciclosFechados => $composableBuilder(
      column: $table.ciclosFechados,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get volumeNegociado => $composableBuilder(
      column: $table.volumeNegociado,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get modoReal => $composableBuilder(
      column: $table.modoReal, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> gridOrdersRefs(
      Expression<bool> Function($$GridOrdersTableFilterComposer f) f) {
    final $$GridOrdersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.gridOrders,
        getReferencedColumn: (t) => t.gridId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$GridOrdersTableFilterComposer(
              $db: $db,
              $table: $db.gridOrders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$GridsTableOrderingComposer
    extends Composer<_$GridDatabase, $GridsTable> {
  $$GridsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get symbol => $composableBuilder(
      column: $table.symbol, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get exchange => $composableBuilder(
      column: $table.exchange, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get capitalUsdt => $composableBuilder(
      column: $table.capitalUsdt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get niveis => $composableBuilder(
      column: $table.niveis, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get limiteSuperior => $composableBuilder(
      column: $table.limiteSuperior,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get limiteInferior => $composableBuilder(
      column: $table.limiteInferior,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get espacamentoPct => $composableBuilder(
      column: $table.espacamentoPct,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get margemLiquidaPct => $composableBuilder(
      column: $table.margemLiquidaPct,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get adxEntrada => $composableBuilder(
      column: $table.adxEntrada, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get atrPctEntrada => $composableBuilder(
      column: $table.atrPctEntrada,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gradeEntrada => $composableBuilder(
      column: $table.gradeEntrada,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lucroRealizado => $composableBuilder(
      column: $table.lucroRealizado,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ciclosFechados => $composableBuilder(
      column: $table.ciclosFechados,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get volumeNegociado => $composableBuilder(
      column: $table.volumeNegociado,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get modoReal => $composableBuilder(
      column: $table.modoReal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$GridsTableAnnotationComposer
    extends Composer<_$GridDatabase, $GridsTable> {
  $$GridsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<String> get exchange =>
      $composableBuilder(column: $table.exchange, builder: (column) => column);

  GeneratedColumn<double> get capitalUsdt => $composableBuilder(
      column: $table.capitalUsdt, builder: (column) => column);

  GeneratedColumn<int> get niveis =>
      $composableBuilder(column: $table.niveis, builder: (column) => column);

  GeneratedColumn<double> get limiteSuperior => $composableBuilder(
      column: $table.limiteSuperior, builder: (column) => column);

  GeneratedColumn<double> get limiteInferior => $composableBuilder(
      column: $table.limiteInferior, builder: (column) => column);

  GeneratedColumn<double> get espacamentoPct => $composableBuilder(
      column: $table.espacamentoPct, builder: (column) => column);

  GeneratedColumn<double> get margemLiquidaPct => $composableBuilder(
      column: $table.margemLiquidaPct, builder: (column) => column);

  GeneratedColumn<double> get adxEntrada => $composableBuilder(
      column: $table.adxEntrada, builder: (column) => column);

  GeneratedColumn<double> get atrPctEntrada => $composableBuilder(
      column: $table.atrPctEntrada, builder: (column) => column);

  GeneratedColumn<String> get gradeEntrada => $composableBuilder(
      column: $table.gradeEntrada, builder: (column) => column);

  GeneratedColumn<double> get lucroRealizado => $composableBuilder(
      column: $table.lucroRealizado, builder: (column) => column);

  GeneratedColumn<int> get ciclosFechados => $composableBuilder(
      column: $table.ciclosFechados, builder: (column) => column);

  GeneratedColumn<double> get volumeNegociado => $composableBuilder(
      column: $table.volumeNegociado, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get modoReal =>
      $composableBuilder(column: $table.modoReal, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> gridOrdersRefs<T extends Object>(
      Expression<T> Function($$GridOrdersTableAnnotationComposer a) f) {
    final $$GridOrdersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.gridOrders,
        getReferencedColumn: (t) => t.gridId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$GridOrdersTableAnnotationComposer(
              $db: $db,
              $table: $db.gridOrders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$GridsTableTableManager extends RootTableManager<
    _$GridDatabase,
    $GridsTable,
    Grid,
    $$GridsTableFilterComposer,
    $$GridsTableOrderingComposer,
    $$GridsTableAnnotationComposer,
    $$GridsTableCreateCompanionBuilder,
    $$GridsTableUpdateCompanionBuilder,
    (Grid, $$GridsTableReferences),
    Grid,
    PrefetchHooks Function({bool gridOrdersRefs})> {
  $$GridsTableTableManager(_$GridDatabase db, $GridsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GridsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GridsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GridsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> symbol = const Value.absent(),
            Value<String> exchange = const Value.absent(),
            Value<double> capitalUsdt = const Value.absent(),
            Value<int> niveis = const Value.absent(),
            Value<double> limiteSuperior = const Value.absent(),
            Value<double> limiteInferior = const Value.absent(),
            Value<double> espacamentoPct = const Value.absent(),
            Value<double> margemLiquidaPct = const Value.absent(),
            Value<double?> adxEntrada = const Value.absent(),
            Value<double?> atrPctEntrada = const Value.absent(),
            Value<String?> gradeEntrada = const Value.absent(),
            Value<double> lucroRealizado = const Value.absent(),
            Value<int> ciclosFechados = const Value.absent(),
            Value<double> volumeNegociado = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<bool> modoReal = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GridsCompanion(
            id: id,
            symbol: symbol,
            exchange: exchange,
            capitalUsdt: capitalUsdt,
            niveis: niveis,
            limiteSuperior: limiteSuperior,
            limiteInferior: limiteInferior,
            espacamentoPct: espacamentoPct,
            margemLiquidaPct: margemLiquidaPct,
            adxEntrada: adxEntrada,
            atrPctEntrada: atrPctEntrada,
            gradeEntrada: gradeEntrada,
            lucroRealizado: lucroRealizado,
            ciclosFechados: ciclosFechados,
            volumeNegociado: volumeNegociado,
            status: status,
            modoReal: modoReal,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String symbol,
            required String exchange,
            required double capitalUsdt,
            required int niveis,
            required double limiteSuperior,
            required double limiteInferior,
            required double espacamentoPct,
            required double margemLiquidaPct,
            Value<double?> adxEntrada = const Value.absent(),
            Value<double?> atrPctEntrada = const Value.absent(),
            Value<String?> gradeEntrada = const Value.absent(),
            Value<double> lucroRealizado = const Value.absent(),
            Value<int> ciclosFechados = const Value.absent(),
            Value<double> volumeNegociado = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<bool> modoReal = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GridsCompanion.insert(
            id: id,
            symbol: symbol,
            exchange: exchange,
            capitalUsdt: capitalUsdt,
            niveis: niveis,
            limiteSuperior: limiteSuperior,
            limiteInferior: limiteInferior,
            espacamentoPct: espacamentoPct,
            margemLiquidaPct: margemLiquidaPct,
            adxEntrada: adxEntrada,
            atrPctEntrada: atrPctEntrada,
            gradeEntrada: gradeEntrada,
            lucroRealizado: lucroRealizado,
            ciclosFechados: ciclosFechados,
            volumeNegociado: volumeNegociado,
            status: status,
            modoReal: modoReal,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$GridsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({gridOrdersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (gridOrdersRefs) db.gridOrders],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (gridOrdersRefs)
                    await $_getPrefetchedData<Grid, $GridsTable, GridOrder>(
                        currentTable: table,
                        referencedTable:
                            $$GridsTableReferences._gridOrdersRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$GridsTableReferences(db, table, p0)
                                .gridOrdersRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.gridId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$GridsTableProcessedTableManager = ProcessedTableManager<
    _$GridDatabase,
    $GridsTable,
    Grid,
    $$GridsTableFilterComposer,
    $$GridsTableOrderingComposer,
    $$GridsTableAnnotationComposer,
    $$GridsTableCreateCompanionBuilder,
    $$GridsTableUpdateCompanionBuilder,
    (Grid, $$GridsTableReferences),
    Grid,
    PrefetchHooks Function({bool gridOrdersRefs})>;
typedef $$GridOrdersTableCreateCompanionBuilder = GridOrdersCompanion Function({
  Value<int> id,
  required String gridId,
  Value<String?> exchangeOrderId,
  required int nivel,
  required String lado,
  required double preco,
  required double quantidade,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<DateTime?> filledAt,
});
typedef $$GridOrdersTableUpdateCompanionBuilder = GridOrdersCompanion Function({
  Value<int> id,
  Value<String> gridId,
  Value<String?> exchangeOrderId,
  Value<int> nivel,
  Value<String> lado,
  Value<double> preco,
  Value<double> quantidade,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<DateTime?> filledAt,
});

final class $$GridOrdersTableReferences
    extends BaseReferences<_$GridDatabase, $GridOrdersTable, GridOrder> {
  $$GridOrdersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GridsTable _gridIdTable(_$GridDatabase db) => db.grids
      .createAlias($_aliasNameGenerator(db.gridOrders.gridId, db.grids.id));

  $$GridsTableProcessedTableManager get gridId {
    final $_column = $_itemColumn<String>('grid_id')!;

    final manager = $$GridsTableTableManager($_db, $_db.grids)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_gridIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$GridOrdersTableFilterComposer
    extends Composer<_$GridDatabase, $GridOrdersTable> {
  $$GridOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get exchangeOrderId => $composableBuilder(
      column: $table.exchangeOrderId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get nivel => $composableBuilder(
      column: $table.nivel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lado => $composableBuilder(
      column: $table.lado, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get preco => $composableBuilder(
      column: $table.preco, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get quantidade => $composableBuilder(
      column: $table.quantidade, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get filledAt => $composableBuilder(
      column: $table.filledAt, builder: (column) => ColumnFilters(column));

  $$GridsTableFilterComposer get gridId {
    final $$GridsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.gridId,
        referencedTable: $db.grids,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$GridsTableFilterComposer(
              $db: $db,
              $table: $db.grids,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$GridOrdersTableOrderingComposer
    extends Composer<_$GridDatabase, $GridOrdersTable> {
  $$GridOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get exchangeOrderId => $composableBuilder(
      column: $table.exchangeOrderId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get nivel => $composableBuilder(
      column: $table.nivel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lado => $composableBuilder(
      column: $table.lado, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get preco => $composableBuilder(
      column: $table.preco, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get quantidade => $composableBuilder(
      column: $table.quantidade, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get filledAt => $composableBuilder(
      column: $table.filledAt, builder: (column) => ColumnOrderings(column));

  $$GridsTableOrderingComposer get gridId {
    final $$GridsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.gridId,
        referencedTable: $db.grids,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$GridsTableOrderingComposer(
              $db: $db,
              $table: $db.grids,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$GridOrdersTableAnnotationComposer
    extends Composer<_$GridDatabase, $GridOrdersTable> {
  $$GridOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get exchangeOrderId => $composableBuilder(
      column: $table.exchangeOrderId, builder: (column) => column);

  GeneratedColumn<int> get nivel =>
      $composableBuilder(column: $table.nivel, builder: (column) => column);

  GeneratedColumn<String> get lado =>
      $composableBuilder(column: $table.lado, builder: (column) => column);

  GeneratedColumn<double> get preco =>
      $composableBuilder(column: $table.preco, builder: (column) => column);

  GeneratedColumn<double> get quantidade => $composableBuilder(
      column: $table.quantidade, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get filledAt =>
      $composableBuilder(column: $table.filledAt, builder: (column) => column);

  $$GridsTableAnnotationComposer get gridId {
    final $$GridsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.gridId,
        referencedTable: $db.grids,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$GridsTableAnnotationComposer(
              $db: $db,
              $table: $db.grids,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$GridOrdersTableTableManager extends RootTableManager<
    _$GridDatabase,
    $GridOrdersTable,
    GridOrder,
    $$GridOrdersTableFilterComposer,
    $$GridOrdersTableOrderingComposer,
    $$GridOrdersTableAnnotationComposer,
    $$GridOrdersTableCreateCompanionBuilder,
    $$GridOrdersTableUpdateCompanionBuilder,
    (GridOrder, $$GridOrdersTableReferences),
    GridOrder,
    PrefetchHooks Function({bool gridId})> {
  $$GridOrdersTableTableManager(_$GridDatabase db, $GridOrdersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GridOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GridOrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GridOrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> gridId = const Value.absent(),
            Value<String?> exchangeOrderId = const Value.absent(),
            Value<int> nivel = const Value.absent(),
            Value<String> lado = const Value.absent(),
            Value<double> preco = const Value.absent(),
            Value<double> quantidade = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> filledAt = const Value.absent(),
          }) =>
              GridOrdersCompanion(
            id: id,
            gridId: gridId,
            exchangeOrderId: exchangeOrderId,
            nivel: nivel,
            lado: lado,
            preco: preco,
            quantidade: quantidade,
            status: status,
            createdAt: createdAt,
            filledAt: filledAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String gridId,
            Value<String?> exchangeOrderId = const Value.absent(),
            required int nivel,
            required String lado,
            required double preco,
            required double quantidade,
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> filledAt = const Value.absent(),
          }) =>
              GridOrdersCompanion.insert(
            id: id,
            gridId: gridId,
            exchangeOrderId: exchangeOrderId,
            nivel: nivel,
            lado: lado,
            preco: preco,
            quantidade: quantidade,
            status: status,
            createdAt: createdAt,
            filledAt: filledAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$GridOrdersTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({gridId = false}) {
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
                if (gridId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.gridId,
                    referencedTable:
                        $$GridOrdersTableReferences._gridIdTable(db),
                    referencedColumn:
                        $$GridOrdersTableReferences._gridIdTable(db).id,
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

typedef $$GridOrdersTableProcessedTableManager = ProcessedTableManager<
    _$GridDatabase,
    $GridOrdersTable,
    GridOrder,
    $$GridOrdersTableFilterComposer,
    $$GridOrdersTableOrderingComposer,
    $$GridOrdersTableAnnotationComposer,
    $$GridOrdersTableCreateCompanionBuilder,
    $$GridOrdersTableUpdateCompanionBuilder,
    (GridOrder, $$GridOrdersTableReferences),
    GridOrder,
    PrefetchHooks Function({bool gridId})>;

class $GridDatabaseManager {
  final _$GridDatabase _db;
  $GridDatabaseManager(this._db);
  $$GridsTableTableManager get grids =>
      $$GridsTableTableManager(_db, _db.grids);
  $$GridOrdersTableTableManager get gridOrders =>
      $$GridOrdersTableTableManager(_db, _db.gridOrders);
}
