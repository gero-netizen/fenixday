/// FênixDay — Simulador de Ganhos do Grid Bot
///
/// Calcula quanto o capital rende com reinvestimento automático
/// (juros compostos) baseado em:
///   • Capital inicial (USDT)
///   • Margem por ciclo (%)  — faixa real: 0,25%–0,38% após taxas Binance
///   • Ciclos fechados por dia
///   • Período (7d / 30d / 90d / 180d / 1a / 2a / 3a)
///
/// Exibe:
///   • Cards de lucro diário / semanal / mensal / no período
///   • Quando o capital dobra
///   • Gráfico de evolução: com reinvest vs sem reinvest
///   • Tabela de marcos de rentabilidade
///   • Comparativo reinvestir tudo vs retirar mensalmente

import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/fenix_theme.dart';

// ── Modelo auxiliar de snapshot diário ───────────────────────────────────────

class _DayResult {
  final int    dia;
  final double capitalOp, caixaRetido, patrimonio;
  final double lucroDia, lucroAcum;
  final bool   reinvestiu;
  const _DayResult({
    required this.dia,
    required this.capitalOp,
    required this.caixaRetido,
    required this.patrimonio,
    required this.lucroDia,
    required this.lucroAcum,
    required this.reinvestiu,
  });
}



class _SimParams {
  final double capital;
  final double margemPct;
  final int    ciclosDia;
  final int    periodosDias;

  const _SimParams({
    this.capital      = 300,
    this.margemPct    = 0.25,
    this.ciclosDia    = 6,
    this.periodosDias = 30,
  });

  // ── Parâmetros de grade ────────────────────────────────────────────────
  int    get numGrids       => 25;                // nº de ordens simultâneas
  double get minNotional    => 10.0;              // mínimo Binance por ordem (USDT)
  double get gatilhoReinvest => 0.01;             // caixa >= 1% capital → reinveste
  double get valorPorOrdem  => capital / numGrids; // USDT por ordem
  double get lucroPorCicloPorOrdem => (margemPct / 100) * valorPorOrdem;
  double get lucroDiaBase   => lucroPorCicloPorOrdem * ciclosDia;

  // ── Simulação realista por degraus ────────────────────────────────────
  // Lucro sobre valor_por_ordem, NÃO sobre capital total.
  // Reinvestimento só quando caixa >= 1% do capital operando.
  List<_DayResult> simulacaoDias(int dias) {
    final results = <_DayResult>[];
    double capitalOp   = capital;
    double caixaRetido = 0.0;
    double lucroAcum   = 0.0;
    double valorOrdem  = capitalOp / numGrids;

    for (int d = 1; d <= dias; d++) {
      final lucroDia = (margemPct / 100) * valorOrdem * ciclosDia;
      caixaRetido += lucroDia;
      lucroAcum   += lucroDia;

      bool reinvestiu = false;
      final gatilhoVal    = gatilhoReinvest * capitalOp;
      final novoCapital   = capitalOp + caixaRetido;
      final novoValorOrdem = novoCapital / numGrids;

      if (caixaRetido >= gatilhoVal && novoValorOrdem >= minNotional) {
        capitalOp    = novoCapital;
        caixaRetido  = 0.0;
        valorOrdem   = capitalOp / numGrids;
        reinvestiu   = true;
      }

      results.add(_DayResult(
        dia:             d,
        capitalOp:       capitalOp,
        caixaRetido:     caixaRetido,
        patrimonio:      capitalOp + caixaRetido,
        lucroDia:        lucroDia,
        lucroAcum:       lucroAcum,
        reinvestiu:      reinvestiu,
      ));
    }
    return results;
  }

  // Patrimônio ao dia D (com simulação real)
  double capitalAoDia(int d) {
    if (d <= 0) return capital;
    final snap = simulacaoDias(d);
    return snap.last.patrimonio;
  }

  double lucroAoDia(int d)  => capitalAoDia(d) - capital;
  double rentabAoDia(int d) => (lucroAoDia(d) / capital) * 100;
  int    ciclosTotais(int d) => ciclosDia * d;

  // Sem reinvestimento (linear sobre valor_por_ordem)
  double capitalSemReinvest(int d) => capital + lucroDiaBase * d;

  // Dias para dobrar (estimativa linear)
  int get diasParaDobrar {
    if (lucroDiaBase <= 0) return 9999;
    return (capital / lucroDiaBase).ceil();
  }

  String get dobrarLabel {
    final d = diasParaDobrar;
    if (d <= 30)   return 'Dobra em $d dias';
    if (d <= 365)  return 'Dobra em ${(d / 30).round()} meses';
    return 'Dobra em ${(d / 365 * 10).round() / 10} anos';
  }

  _SimParams copyWith({
    double? capital, double? margemPct,
    int? ciclosDia, int? periodosDias,
  }) => _SimParams(
        capital:      capital      ?? this.capital,
        margemPct:    margemPct    ?? this.margemPct,
        ciclosDia:    ciclosDia    ?? this.ciclosDia,
        periodosDias: periodosDias ?? this.periodosDias,
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _simProvider =
    StateNotifierProvider<_SimNotifier, _SimParams>(
  (ref) => _SimNotifier(),
);

class _SimNotifier extends StateNotifier<_SimParams> {
  _SimNotifier() : super(const _SimParams());
  void setCapital(double v)   => state = state.copyWith(capital: v.clamp(10, 1e7));
  void setMargem(double v)    => state = state.copyWith(margemPct: v.clamp(0.01, 5));
  void setCiclos(int v)       => state = state.copyWith(ciclosDia: v.clamp(1, 50));
  void setPeriodo(int v)      => state = state.copyWith(periodosDias: v);
}

// ── Tela ──────────────────────────────────────────────────────────────────────

class SimulatorScreen extends ConsumerWidget {
  const SimulatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: FenixColors.bg,
      appBar: AppBar(
        backgroundColor: FenixColors.surface,
        elevation: 0,
        title: const Text('Simulador de Ganhos',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: FenixColors.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              size: 18, color: FenixColors.textMuted),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: FenixColors.greenBg,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                  color: FenixColors.green.withOpacity(.3), width: .5),
            ),
            child: const Text('REINVEST ON',
                style: TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: FenixColors.green)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _InputsCard(),
            const SizedBox(height: 12),
            _PeriodoSelector(),
            const SizedBox(height: 12),
            _ResultCards(),
            const SizedBox(height: 8),
            _DobrarBadge(),
            const SizedBox(height: 12),
            _ChartCard(),
            const SizedBox(height: 12),
            _MarcosTable(),
            const SizedBox(height: 12),
            _ComparativoCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Inputs ────────────────────────────────────────────────────────────────────

class _InputsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(_simProvider);
    final n = ref.read(_simProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FenixColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FenixColors.border, width: .5),
      ),
      child: Column(
        children: [
          // Capital
          _SliderInput(
            label:     'Capital inicial',
            icon:      Icons.account_balance_wallet_outlined,
            iconColor: FenixColors.yellow,
            value:     p.capital,
            unit:      'USDT',
            min:       100,
            max:       10000,
            step:      100,
            fmt:       (v) => NumberFormat('#,##0.00', 'pt_BR').format(v),
            hint:      'Sugerido: \$300 – \$10.000',
            onChanged: n.setCapital,
          ),
          const SizedBox(height: 12),

          // Margem
          _SliderInput(
            label:     'Margem por ciclo',
            icon:      Icons.percent_outlined,
            iconColor: FenixColors.green,
            value:     p.margemPct,
            unit:      '% / ciclo',
            min:       0.10,
            max:       1.00,
            step:      0.01,
            fmt:       (v) => v.toStringAsFixed(2),
            hint:      'Faixa real FênixDay: 0,25% – 0,38% após taxas Binance',
            onChanged: n.setMargem,
            valueColor: FenixColors.green,
          ),
          const SizedBox(height: 12),

          // Ciclos por dia
          _SliderInput(
            label:     'Ciclos fechados por dia',
            icon:      Icons.loop_outlined,
            iconColor: FenixColors.purple,
            value:     p.ciclosDia.toDouble(),
            unit:      'ciclos/dia',
            min:       1,
            max:       20,
            step:      1,
            isInt:     true,
            fmt:       (v) => v.toInt().toString(),
            hint:      'Depende do par e da volatilidade do mercado',
            onChanged: (v) => n.setCiclos(v.toInt()),
            valueColor: FenixColors.purple,
          ),
        ],
      ),
    );
  }
}

class _SliderInput extends StatelessWidget {
  final String label, unit, hint;
  final IconData icon;
  final Color iconColor;
  final double value, min, max, step;
  final bool isInt;
  final String Function(double) fmt;
  final Function(double) onChanged;
  final Color valueColor;

  const _SliderInput({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.step,
    required this.fmt,
    required this.hint,
    required this.onChanged,
    this.isInt = false,
    this.valueColor = FenixColors.yellow,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: FenixColors.textSecondary)),
        const Spacer(),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: FenixColors.card,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: iconColor.withOpacity(.3), width: .5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(fmt(value),
                style: TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: valueColor)),
            const SizedBox(width: 4),
            Text(unit,
                style: const TextStyle(
                    fontSize: 10, color: FenixColors.textMuted)),
          ]),
        ),
      ]),
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor:   iconColor,
          inactiveTrackColor: FenixColors.border,
          thumbColor:         iconColor,
          trackHeight:        3,
          thumbShape:
              const RoundSliderThumbShape(enabledThumbRadius: 7),
          overlayShape:
              const RoundSliderOverlayShape(overlayRadius: 12),
        ),
        child: Slider(
          value:    value.clamp(min, max),
          min:      min,
          max:      max,
          divisions: ((max - min) / step).round(),
          onChanged: onChanged,
        ),
      ),
      Text(hint,
          style: const TextStyle(
              fontSize: 9, color: FenixColors.textMuted)),
    ]);
  }
}

// ── Seletor de período ────────────────────────────────────────────────────────

class _PeriodoSelector extends ConsumerWidget {
  static const _opts = [
    (7, '7d'), (30, '1m'), (90, '3m'),
    (180, '6m'), (365, '1a'), (730, '2a'), (1095, '3a'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(_simProvider).periodosDias;
    final n       = ref.read(_simProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FenixColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FenixColors.border, width: .5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.calendar_today_outlined,
              size: 13, color: FenixColors.blue),
          SizedBox(width: 5),
          Text('Período de simulação',
              style: TextStyle(
                  fontSize: 11, color: FenixColors.textSecondary)),
        ]),
        const SizedBox(height: 10),
        Row(children: _opts.map((o) => Expanded(
          child: GestureDetector(
            onTap: () => n.setPeriodo(o.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: current == o.$1
                    ? FenixColors.yellowBg
                    : FenixColors.card2,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: current == o.$1
                      ? FenixColors.yellow.withOpacity(.4)
                      : FenixColors.border,
                  width: .5,
                ),
              ),
              child: Text(o.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: current == o.$1
                          ? FenixColors.yellow
                          : FenixColors.textMuted)),
            ),
          ),
        )).toList()),
      ]),
    );
  }
}

// ── Cards de resultado ────────────────────────────────────────────────────────

class _ResultCards extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p   = ref.watch(_simProvider);
    final fmt = NumberFormat('#,##0.00', 'pt_BR');

    final cards = [
      _CardData('Diário',    1,   FenixColors.blue),
      _CardData('Semanal',   7,   FenixColors.purple),
      _CardData('Mensal',    30,  FenixColors.green),
      _CardData('No período', p.periodosDias, FenixColors.yellow),
    ];

    return Row(children: cards.map((c) {
      final lucro  = p.lucroAoDia(c.dias);
      final rentab = p.rentabAoDia(c.dias);
      final ciclos = p.ciclosTotais(c.dias);

      return Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: FenixColors.card,
            borderRadius: BorderRadius.circular(0),
            border: Border(
              top: BorderSide(color: c.color, width: 2),
              left: BorderSide(color: FenixColors.border, width: .5),
              right: BorderSide(color: FenixColors.border, width: .5),
              bottom: BorderSide(color: FenixColors.border, width: .5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.label,
                  style: const TextStyle(
                      fontSize: 9, color: FenixColors.textMuted)),
              const SizedBox(height: 4),
              Text(
                lucro < 1
                    ? '\$${lucro.toStringAsFixed(4)}'
                    : '\$${fmt.format(lucro)}',
                style: TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c.color),
              ),
              Text('+${rentab.toStringAsFixed(2)}%',
                  style: TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 9,
                      color: c.color)),
              const SizedBox(height: 3),
              Text('$ciclos ciclos',
                  style: const TextStyle(
                      fontSize: 9, color: FenixColors.textMuted)),
            ],
          ),
        ),
      );
    }).toList());
  }
}

class _CardData {
  final String label;
  final int dias;
  final Color color;
  const _CardData(this.label, this.dias, this.color);
}

// ── Badge de dobrar ───────────────────────────────────────────────────────────

class _DobrarBadge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(_simProvider);
    return Center(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: FenixColors.purpleBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: FenixColors.purple.withOpacity(.3), width: .5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.schedule_outlined,
              size: 14, color: FenixColors.purple),
          const SizedBox(width: 6),
          Text(p.dobrarLabel,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: FenixColors.purple)),
        ]),
      ),
    );
  }
}

// ── Gráfico ───────────────────────────────────────────────────────────────────

class _ChartCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p   = ref.watch(_simProvider);
    final fmt = NumberFormat('#,##0.00', 'pt_BR');
    final dias = p.periodosDias;

    // Gerar pontos do gráfico
    final step = max(1, (dias / 50).ceil());
    final compSpots   = <FlSpot>[];
    final linearSpots = <FlSpot>[];

    for (int i = 0; i <= dias; i += step) {
      compSpots.add(FlSpot(i.toDouble(), p.capitalAoDia(i)));
      linearSpots.add(FlSpot(i.toDouble(), p.capitalSemReinvest(i)));
    }
    if (compSpots.last.x < dias) {
      compSpots.add(FlSpot(dias.toDouble(), p.capitalAoDia(dias)));
      linearSpots.add(FlSpot(dias.toDouble(), p.capitalSemReinvest(dias)));
    }

    final minY = p.capital * 0.998;
    final maxY = p.capitalAoDia(dias) * 1.002;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FenixColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FenixColors.border, width: .5),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Evolução do patrimônio',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: FenixColors.textPrimary)),
                Text('Com reinvestimento automático (juros compostos)',
                    style: TextStyle(
                        fontSize: 9, color: FenixColors.textMuted)),
              ],
            ),
            Text(
              '\$${fmt.format(p.capitalAoDia(dias))}',
              style: const TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: FenixColors.green),
            ),
          ],
        ),
        const SizedBox(height: 16),

        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: minY, maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY - minY) / 4,
                getDrawingHorizontalLine: (_) => FlLine(
                    color: FenixColors.border.withOpacity(.5),
                    strokeWidth: .5),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    getTitlesWidget: (v, _) => Text(
                      v >= 1000
                          ? '\$${(v / 1000).toStringAsFixed(1)}k'
                          : '\$${v.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontFamily: 'RobotoMono',
                          fontSize: 9,
                          color: FenixColors.textMuted),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: max(1, dias / 5).toDouble(),
                    getTitlesWidget: (v, _) {
                      final d = v.toInt();
                      final lbl = d < 365
                          ? 'D$d'
                          : '${(d / 30).round()}m';
                      return Text(lbl,
                          style: const TextStyle(
                              fontFamily: 'RobotoMono',
                              fontSize: 9,
                              color: FenixColors.textMuted));
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                // Curva com reinvestimento
                LineChartBarData(
                  spots: compSpots,
                  isCurved: true,
                  curveSmoothness: .4,
                  color: FenixColors.green,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                      show: true, color: FenixColors.greenBg),
                ),
                // Curva sem reinvestimento (linear)
                LineChartBarData(
                  spots: linearSpots,
                  isCurved: false,
                  color: FenixColors.textMuted.withOpacity(.5),
                  barWidth: 1,
                  dotData: const FlDotData(show: false),
                  dashArray: [4, 4],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Legenda
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _LegItem(FenixColors.green,   'Com reinvestimento'),
          const SizedBox(width: 16),
          _LegItem(FenixColors.textMuted, 'Sem reinvestimento', dashed: true),
        ]),
      ]),
    );
  }
}

class _LegItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  const _LegItem(this.color, this.label, {this.dashed = false});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14, height: 3,
        decoration: BoxDecoration(
          color: dashed ? Colors.transparent : color,
          border: dashed ? Border.all(color: color, width: 1) : null,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 5),
      Text(label,
          style: const TextStyle(
              fontSize: 10, color: FenixColors.textMuted)),
    ],
  );
}

// ── Tabela de marcos ──────────────────────────────────────────────────────────

class _MarcosTable extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p   = ref.watch(_simProvider);
    final fmt = NumberFormat('#,##0.00', 'pt_BR');

    final marcos = <(String, int, bool)>[
      if (p.periodosDias >= 7)    ('7 dias',   7,   false),
      if (p.periodosDias >= 30)   ('1 mês',    30,  false),
      if (p.periodosDias >= 90)   ('3 meses',  90,  false),
      if (p.periodosDias >= 180)  ('6 meses',  180, false),
      if (p.periodosDias >= 365)  ('1 ano',    365, false),
      if (p.periodosDias >= 730)  ('2 anos',   730, false),
      if (p.periodosDias >= 1095) ('3 anos',   1095,false),
      (_periodoLabel(p.periodosDias), p.periodosDias, true),
    ];

    return Container(
      decoration: BoxDecoration(
        color: FenixColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FenixColors.border, width: .5),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: FenixColors.border, width: .5)),
          ),
          child: const Row(children: [
            Expanded(flex:2, child: Text('Período',
                style: TextStyle(fontSize: 9, color: FenixColors.textMuted))),
            Expanded(child: Text('Capital',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 9, color: FenixColors.textMuted))),
            Expanded(child: Text('Lucro',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 9, color: FenixColors.textMuted))),
            Expanded(child: Text('Rentab.',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 9, color: FenixColors.textMuted))),
            Expanded(child: Text('Ciclos',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 9, color: FenixColors.textMuted))),
          ]),
        ),

        // Linhas
        ...marcos.map((m) {
          final cap    = p.capitalAoDia(m.$2);
          final lucro  = p.lucroAoDia(m.$2);
          final rentab = p.rentabAoDia(m.$2);
          final ciclos = p.ciclosTotais(m.$2);
          final hl     = m.$3;

          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: hl ? FenixColors.yellowBg : Colors.transparent,
              border: const Border(
                  bottom: BorderSide(
                      color: FenixColors.border, width: .5)),
            ),
            child: Row(children: [
              Expanded(flex:2, child: Text(m.$1,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: hl ? FontWeight.w500 : FontWeight.normal,
                      color: hl
                          ? FenixColors.yellow
                          : FenixColors.textMuted))),
              Expanded(child: Text('\$${fmt.format(cap)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 11,
                      fontWeight: hl ? FontWeight.w500 : FontWeight.normal,
                      color: hl
                          ? FenixColors.yellow
                          : FenixColors.green))),
              Expanded(child: Text('\$${fmt.format(lucro)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 11,
                      color: FenixColors.green))),
              Expanded(child: Text('+${rentab.toStringAsFixed(2)}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 11,
                      color: FenixColors.green))),
              Expanded(child: Text(
                  NumberFormat('#,##0').format(ciclos),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 11,
                      color: FenixColors.textMuted))),
            ]),
          );
        }),
      ]),
    );
  }

  String _periodoLabel(int d) {
    const map = {
      7: '7 dias', 30: '1 mês', 90: '3 meses', 180: '6 meses',
      365: '1 ano', 730: '2 anos', 1095: '3 anos',
    };
    return map[d] ?? '$d dias';
  }
}

// ── Comparativo reinvest vs retirada ─────────────────────────────────────────

class _ComparativoCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p    = ref.watch(_simProvider);
    final fmt  = NumberFormat('#,##0.00', 'pt_BR');
    final dias = p.periodosDias;

    final capComReinvest  = p.capitalAoDia(dias);
    final lucroLinearDia  = p.lucroDiaBase;
    final meses           = (dias / 30).floor();
    final lucroMensalFixo = lucroLinearDia * 30;
    final totalRetirado   = lucroMensalFixo * meses;
    final diferenca = (capComReinvest - p.capital) - totalRetirado;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FenixColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FenixColors.border, width: .5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reinvestir vs Retirar mensalmente',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: FenixColors.textPrimary)),
          const SizedBox(height: 3),
          const Text(
            'O que acontece se você retirar o lucro todo mês vs reinvestir tudo',
            style: TextStyle(fontSize: 10, color: FenixColors.textMuted),
          ),
          const SizedBox(height: 12),

          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Reinvestir
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FenixColors.greenBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: FenixColors.green.withOpacity(.3), width: .5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('♻ Reinvestir tudo',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: FenixColors.green)),
                    const SizedBox(height: 8),
                    Text('\$${fmt.format(capComReinvest)}',
                        style: const TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: FenixColors.green)),
                    const SizedBox(height: 3),
                    const Text('Capital ao final do período',
                        style: TextStyle(
                            fontSize: 9, color: FenixColors.textMuted)),
                    const SizedBox(height: 5),
                    Text(
                      '+${((capComReinvest - p.capital) / p.capital * 100).toStringAsFixed(2)}% sobre o capital',
                      style: const TextStyle(
                          fontSize: 10, color: FenixColors.green),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Retirar mensalmente
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FenixColors.card2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: FenixColors.border, width: .5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💸 Retirar mensalmente',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: FenixColors.textSecondary)),
                    const SizedBox(height: 8),
                    Text('\$${fmt.format(totalRetirado)}',
                        style: const TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: FenixColors.yellow)),
                    const SizedBox(height: 3),
                    Text('Total retirado em $meses mês(es)',
                        style: const TextStyle(
                            fontSize: 9, color: FenixColors.textMuted)),
                    const SizedBox(height: 5),
                    Text(
                      'Capital mantido: \$${fmt.format(p.capital)}',
                      style: const TextStyle(
                          fontSize: 9, color: FenixColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ]),

          const SizedBox(height: 10),

          // Diferença
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FenixColors.purpleBg,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                  color: FenixColors.purple.withOpacity(.3), width: .5),
            ),
            child: Row(children: [
              const Icon(Icons.trending_up_outlined,
                  size: 14, color: FenixColors.purple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'O reinvestimento gera \$${fmt.format(diferenca.abs())} '
                  '${diferenca >= 0 ? 'a mais' : 'a menos'} '
                  'do que a retirada mensal no período.',
                  style: const TextStyle(
                      fontSize: 11, color: FenixColors.purple),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
