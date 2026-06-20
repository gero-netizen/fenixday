/// FênixDay — Tela de Grids Ativos
/// Integrado com API real: GET/POST/PUT/DELETE /api/v1/grids

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../theme/fenix_theme.dart';
import 'shared_providers.dart';

const _baseUrl = 'https://fenixday.info/api/v1';

// ── Modelo ────────────────────────────────────────────────────────────────────

class GridModel {
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

  const GridModel({
    required this.id,
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
    required this.createdAt,
  });

  factory GridModel.fromJson(Map<String, dynamic> j) => GridModel(
    id:               j['id'],
    symbol:           j['symbol'],
    exchange:         j['exchange'],
    capitalUsdt:      (j['capital_usdt'] as num).toDouble(),
    niveis:           j['niveis'],
    limiteSuperior:   (j['limite_superior'] as num).toDouble(),
    limiteInferior:   (j['limite_inferior'] as num).toDouble(),
    espacamentoPct:   (j['espacamento_pct'] as num).toDouble(),
    margemLiquidaPct: (j['margem_liquida_pct'] as num).toDouble(),
    adxEntrada:       j['adx_entrada'] != null ? (j['adx_entrada'] as num).toDouble() : null,
    atrPctEntrada:    j['atr_pct_entrada'] != null ? (j['atr_pct_entrada'] as num).toDouble() : null,
    gradeEntrada:     j['grade_entrada'],
    lucroRealizado:   (j['lucro_realizado'] as num).toDouble(),
    ciclosFechados:   j['ciclos_fechados'],
    volumeNegociado:  (j['volume_negociado'] as num).toDouble(),
    status:           j['status'],
    modoReal:         j['modo_real'] ?? false,
    createdAt:        DateTime.parse(j['created_at']),
  );

  bool get isActive  => status == 'active';
  bool get isPaused  => status == 'paused';
  bool get isStopped => status == 'stopped';

  double get lucroPercent =>
      capitalUsdt > 0 ? (lucroRealizado / capitalUsdt) * 100 : 0;
}

// ── Serviço API ───────────────────────────────────────────────────────────────

class _GridsApi {
  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  Future<List<GridModel>> fetchGrids() async {
    final token = await _token();
    if (token == null) throw Exception('Não autenticado');
    final r = await http.get(
      Uri.parse('$_baseUrl/grids'),
      headers: _headers(token),
    ).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw Exception('Erro ao buscar grids');
    final List data = jsonDecode(r.body);
    return data.map((j) => GridModel.fromJson(j)).toList();
  }

  Future<GridModel> createGrid(Map<String, dynamic> payload) async {
    final token = await _token();
    if (token == null) throw Exception('Não autenticado');
    final r = await http.post(
      Uri.parse('$_baseUrl/grids'),
      headers: _headers(token),
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 10));
    if (r.statusCode != 201) throw Exception(jsonDecode(r.body)['detail'] ?? 'Erro ao criar grid');
    return GridModel.fromJson(jsonDecode(r.body));
  }

  Future<GridModel> pauseGrid(String id) async {
    final token = await _token();
    if (token == null) throw Exception('Não autenticado');
    final r = await http.put(
      Uri.parse('$_baseUrl/grids/$id/pause'),
      headers: _headers(token),
    ).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw Exception('Erro ao pausar grid');
    return GridModel.fromJson(jsonDecode(r.body));
  }

  Future<GridModel> stopGrid(String id) async {
    final token = await _token();
    if (token == null) throw Exception('Não autenticado');
    final r = await http.put(
      Uri.parse('$_baseUrl/grids/$id/stop'),
      headers: _headers(token),
    ).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw Exception('Erro ao parar grid');
    return GridModel.fromJson(jsonDecode(r.body));
  }

  Future<void> deleteGrid(String id) async {
    final token = await _token();
    if (token == null) throw Exception('Não autenticado');
    await http.delete(
      Uri.parse('$_baseUrl/grids/$id'),
      headers: _headers(token),
    ).timeout(const Duration(seconds: 10));
  }
}

// ── Provider de preço ────────────────────────────────────────────────────────

final _gridPriceProvider = FutureProvider.family<double?, String>((ref, symbol) async {
  try {
    final sym = symbol.replaceAll('/', '').replaceAll('USDT', '') + 'USDT';
    final r = await http.get(Uri.parse(
        'https://api.binance.com/api/v3/ticker/price?symbol=$sym'));
    if (r.statusCode == 200) {
      return double.tryParse(jsonDecode(r.body)['price'].toString());
    }
  } catch (_) {}
  return null;
});

// ── Provider ──────────────────────────────────────────────────────────────────

class _GridsNotifier extends StateNotifier<AsyncValue<List<GridModel>>> {
  final _api = _GridsApi();
  _GridsNotifier() : super(const AsyncValue.loading()) { fetch(); }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _api.fetchGrids());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createGrid(Map<String, dynamic> payload) async {
    await _api.createGrid(payload);
    await fetch();
  }

  Future<void> pauseGrid(String id) async {
    await _api.pauseGrid(id);
    await fetch();
  }

  Future<void> stopGrid(String id) async {
    await _api.stopGrid(id);
    await fetch();
  }

  Future<void> deleteGrid(String id) async {
    await _api.deleteGrid(id);
    await fetch();
  }
}

final gridsProvider =
    StateNotifierProvider<_GridsNotifier, AsyncValue<List<GridModel>>>(
  (ref) => _GridsNotifier(),
);

// ── Tela principal ────────────────────────────────────────────────────────────

class GridsScreen extends ConsumerWidget {
  const GridsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gridsAsync = ref.watch(gridsProvider);

    return Scaffold(
      backgroundColor: FenixColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(children: [
                const Text('Grids ativos',
                    style: TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: FenixColors.textPrimary)),
                const SizedBox(width: 8),
                Consumer(builder: (context, ref, _) {
                  final modoReal = ref.watch(modoRealProvider);
                  return GestureDetector(
                    onTap: () => ref.read(modoRealProvider.notifier).toggle(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: modoReal ? FenixColors.green.withOpacity(.15) : FenixColors.orange.withOpacity(.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: modoReal ? FenixColors.green : FenixColors.orange, width: .5),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.circle, size: 7, color: modoReal ? FenixColors.green : FenixColors.orange),
                        const SizedBox(width: 4),
                        Text(modoReal ? 'REAL' : 'DEMO',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                color: modoReal ? FenixColors.green : FenixColors.orange)),
                        const SizedBox(width: 4),
                        Icon(Icons.swap_horiz, size: 12, color: modoReal ? FenixColors.green : FenixColors.orange),
                      ]),
                    ),
                  );
                }),
                const Spacer(),
                // Novo Grid
                GestureDetector(
                  onTap: () => context.push('/grids/config'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: FenixColors.yellowBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: FenixColors.yellow.withOpacity(.3), width: .5),
                    ),
                    child: const Row(children: [
                      Icon(Icons.add, size: 14, color: FenixColors.yellow),
                      SizedBox(width: 4),
                      Text('Novo Grid', style: TextStyle(
                          fontSize: 12, color: FenixColors.yellow,
                          fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                // Refresh
                gridsAsync.when(
                  loading: () => const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: FenixColors.yellow)),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (_) => IconButton(
                    icon: const Icon(Icons.refresh,
                        size: 20, color: FenixColors.textMuted),
                    onPressed: () => ref.read(gridsProvider.notifier).fetch(),
                  ),
                ),
              ]),
            ),

            // Conteúdo
            Expanded(
              child: gridsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: FenixColors.yellow),
                ),
                error: (e, _) => Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.wifi_off_outlined,
                        size: 32, color: FenixColors.textMuted),
                    const SizedBox(height: 12),
                    Text(e.toString(), textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11,
                            color: FenixColors.textMuted)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.read(gridsProvider.notifier).fetch(),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: FenixColors.yellow),
                      child: const Text('Tentar novamente',
                          style: TextStyle(color: Colors.black)),
                    ),
                  ]),
                ),
                data: (grids) {
                  final modoReal = ref.watch(modoRealProvider);
                  final filtrados = grids.where((g) => g.modoReal == modoReal).toList();
                  final ativos  = filtrados.where((g) => g.isActive).toList();
                  final pausados = filtrados.where((g) => g.isPaused).toList();
                  final parados = filtrados.where((g) => g.isStopped).toList();

                  if (filtrados.isEmpty) {
                    return Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.grid_view_outlined,
                            size: 48, color: FenixColors.textMuted),
                        const SizedBox(height: 16),
                        const Text('Nenhum grid ativo.',
                            style: TextStyle(fontSize: 14,
                                color: FenixColors.textMuted)),
                        const SizedBox(height: 6),
                        const Text('Use o Scanner de IA para encontrar\nos melhores pares.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11,
                                color: FenixColors.textMuted, height: 1.5)),
                      ]),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => ref.read(gridsProvider.notifier).fetch(),
                    color: FenixColors.yellow,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                      children: [
                        // Resumo total - só mostra se tiver grids
                        if (filtrados.isNotEmpty) _ResumoCard(grids: filtrados),
                        if (filtrados.isNotEmpty) const SizedBox(height: 14),

                        if (ativos.isNotEmpty) ...[
                          _SectionLabel('Ativos (${ativos.length})',
                              FenixColors.green),
                          const SizedBox(height: 6),
                          ...ativos.map((g) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _GridCard(grid: g),
                          )),
                        ],
                        if (pausados.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _SectionLabel('Pausados (${pausados.length})',
                              FenixColors.orange),
                          const SizedBox(height: 6),
                          ...pausados.map((g) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _GridCard(grid: g),
                          )),
                        ],
                        if (parados.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _SectionLabel('Parados (${parados.length})',
                              FenixColors.textMuted),
                          const SizedBox(height: 6),
                          ...parados.map((g) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _GridCard(grid: g),
                          )),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card resumo total ─────────────────────────────────────────────────────────

class _ResumoCard extends StatelessWidget {
  final List<GridModel> grids;
  const _ResumoCard({required this.grids});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'pt_BR');
    final totalCapital = grids.fold<double>(0.0, (s, g) => s + g.capitalUsdt);
    final totalLucro   = grids.fold<double>(0.0, (s, g) => s + g.lucroRealizado);
    final totalCiclos  = grids.fold<int>(0, (s, g) => s + g.ciclosFechados);
    final lucroPercent = totalCapital > 0 ? (totalLucro / totalCapital) * 100 : 0.0;

    // Gráfico simulado de lucro acumulado (por grid)
    final spots = grids.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), e.value.lucroRealizado)).toList();
    final hasChart = spots.length >= 2;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FenixColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FenixColors.yellow, width: 1),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(child: _ResumoItem(
            label: 'Capital total',
            value: '\$${fmt.format(totalCapital)}',
            color: FenixColors.yellow,
          )),
          Container(width: .5, height: 40, color: FenixColors.border),
          Expanded(child: _ResumoItem(
            label: 'Lucro realizado',
            value: '+\$${fmt.format(totalLucro)}',
            color: FenixColors.green,
            sub: '+${lucroPercent.toStringAsFixed(2)}%',
          )),
          Container(width: .5, height: 40, color: FenixColors.border),
          Expanded(child: _ResumoItem(
            label: 'Ciclos fechados',
            value: '$totalCiclos',
            color: FenixColors.blue,
            sub: '${grids.length} grids',
          )),
        ]),
        if (hasChart) ...[
          const SizedBox(height: 14),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Lucro por grid', style: TextStyle(
                fontSize: 10, color: FenixColors.textMuted)),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 80,
            child: BarChart(BarChartData(
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < grids.length) {
                      final sym = grids[i].symbol.replaceAll('USDT', '');
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(sym, style: const TextStyle(
                            fontSize: 8, color: FenixColors.textMuted)),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                )),
                leftTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              barGroups: grids.asMap().entries.map((e) => BarChartGroupData(
                x: e.key,
                barRods: [BarChartRodData(
                  toY: e.value.lucroRealizado,
                  color: e.value.lucroRealizado >= 0
                      ? FenixColors.green : FenixColors.red,
                  width: 14,
                  borderRadius: BorderRadius.circular(3),
                )],
              )).toList(),
            )),
          ),
        ],
      ]),
    );
  }
}

class _ResumoItem extends StatelessWidget {
  final String label, value;
  final String? sub;
  final Color color;
  const _ResumoItem({required this.label, required this.value,
      required this.color, this.sub});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 9, color: FenixColors.textMuted)),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(fontFamily: 'RobotoMono',
          fontSize: 13, fontWeight: FontWeight.w500, color: color)),
      if (sub != null)
        Text(sub!, style: TextStyle(fontSize: 9, color: color)),
    ]),
  );
}

// ── Card de grid ──────────────────────────────────────────────────────────────

class _GridCard extends ConsumerWidget {
  final GridModel grid;
  const _GridCard({required this.grid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt        = NumberFormat('#,##0.00', 'pt_BR');
    final statusColor = _statusColor(grid.status);
    final gradeColor  = _gradeColor(grid.gradeEntrada ?? 'C');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FenixColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: grid.isActive
              ? statusColor.withOpacity(.3)
              : FenixColors.border,
          width: .5,
        ),
      ),
      child: Column(children: [
        // Linha 1: symbol + status + grade + lucro
        Row(children: [
          // Exchange badge
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: FenixColors.yellowBg,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(child: Text(
              grid.exchange[0].toUpperCase(),
              style: const TextStyle(fontSize: 10,
                  fontWeight: FontWeight.w700, color: FenixColors.yellow),
            )),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(grid.symbol.replaceAll('USDT', '/USDT'),
                style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: FenixColors.textPrimary)),
          ),
          // Grade
          if (grid.gradeEntrada != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: gradeColor.withOpacity(.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(grid.gradeEntrada!,
                  style: TextStyle(fontFamily: 'RobotoMono',
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: gradeColor)),
            ),
          const SizedBox(width: 6),
          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(.15),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(_statusLabel(grid.status),
                style: TextStyle(fontFamily: 'RobotoMono',
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: statusColor)),
          ),
        ]),
        const SizedBox(height: 10),

        // Métricas
        Row(children: [
          _Metrica(label: 'Capital',
              value: '\$${fmt.format(grid.capitalUsdt)}',
              color: FenixColors.textPrimary),
          _Metrica(label: 'Lucro',
              value: '+\$${fmt.format(grid.lucroRealizado)}',
              color: FenixColors.green,
              sub: '+${grid.lucroPercent.toStringAsFixed(2)}%'),
          _Metrica(label: 'Ciclos',
              value: '${grid.ciclosFechados}',
              color: FenixColors.blue),
          _Metrica(label: 'Margem/ciclo',
              value: '+${grid.margemLiquidaPct.toStringAsFixed(2)}%',
              color: FenixColors.yellow),
        ]),
        const SizedBox(height: 10),

        // Range do grid
        Row(children: [
          Text('\$${_fmtPrice(grid.limiteInferior)}',
              style: const TextStyle(fontFamily: 'RobotoMono',
                  fontSize: 9, color: FenixColors.textMuted)),
          const Expanded(child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: LinearProgressIndicator(
              value: 0.5, minHeight: 3,
              backgroundColor: FenixColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(FenixColors.yellow),
            ),
          )),
          Text('\$${_fmtPrice(grid.limiteSuperior)}',
              style: const TextStyle(fontFamily: 'RobotoMono',
                  fontSize: 9, color: FenixColors.textMuted)),
          const SizedBox(width: 6),
          Text('${grid.niveis} níveis',
              style: const TextStyle(fontSize: 9, color: FenixColors.textMuted)),
        ]),
        const SizedBox(height: 10),

        // Botões de ação
        if (!grid.isStopped)
          Row(children: [
            // Pausar/Retomar
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: grid.isPaused
                      ? FenixColors.green
                      : FenixColors.orange,
                  side: BorderSide(
                    color: grid.isPaused
                        ? FenixColors.green.withOpacity(.3)
                        : FenixColors.orange.withOpacity(.3),
                    width: .5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                icon: Icon(
                  grid.isPaused
                      ? Icons.play_arrow_outlined
                      : Icons.pause_outlined,
                  size: 14,
                ),
                label: Text(grid.isPaused ? 'Retomar' : 'Pausar',
                    style: const TextStyle(fontSize: 11)),
                onPressed: () async {
                  try {
                    await ref.read(gridsProvider.notifier).pauseGrid(grid.id);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString()),
                            backgroundColor: FenixColors.red),
                      );
                    }
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            // Parar
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: FenixColors.red,
                  side: BorderSide(
                      color: FenixColors.red.withOpacity(.3), width: .5),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.stop_outlined, size: 14),
                label: const Text('Parar', style: TextStyle(fontSize: 11)),
                onPressed: () async {
                  try {
                    await _confirmStop(context, ref);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: FenixColors.red));
                    }
                  }
                },
              ),
            ),
          ])
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: FenixColors.textMuted,
                side: const BorderSide(color: FenixColors.border, width: .5),
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.delete_outline, size: 14),
              label: const Text('Remover', style: TextStyle(fontSize: 11)),
              onPressed: () async {
                try { await _confirmDelete(context, ref); }
                catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: FenixColors.red));
                }
              },
            ),
          ),
        if (!grid.isStopped)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: FenixColors.red,
                  side: BorderSide(color: FenixColors.red.withOpacity(.3), width: .5),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.delete_forever_outlined, size: 14),
                label: const Text('Parar e Excluir', style: TextStyle(fontSize: 11)),
                onPressed: () => _confirmStopAndDelete(context, ref),
              ),
            ),
          ),
      ]),
    );
  }

  Future<void> _confirmStop(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: FenixColors.card,
        title: Text('Parar grid ${grid.symbol}?',
            style: const TextStyle(fontSize: 14, color: FenixColors.textPrimary)),
        content: const Text('O grid será parado e todas as ordens abertas canceladas.',
            style: TextStyle(fontSize: 12, color: FenixColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancelar',
                  style: TextStyle(color: FenixColors.textMuted))),
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Parar',
                  style: TextStyle(color: FenixColors.red,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(gridsProvider.notifier).stopGrid(grid.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao parar: $e'),
            backgroundColor: FenixColors.red));
        }
      }
    }
  }

  Future<void> _confirmStopAndDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: FenixColors.card,
        title: Text('Parar e excluir ${grid.symbol}?',
            style: const TextStyle(fontSize: 14, color: FenixColors.textPrimary)),
        content: const Text('O grid sera parado e removido permanentemente.',
            style: TextStyle(fontSize: 12, color: FenixColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancelar', style: TextStyle(color: FenixColors.textMuted))),
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Parar e Excluir',
                  style: TextStyle(color: FenixColors.red, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(gridsProvider.notifier).stopGrid(grid.id);
        await ref.read(gridsProvider.notifier).deleteGrid(grid.id);
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: FenixColors.red));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: FenixColors.card,
        title: const Text('Remover grid?',
            style: TextStyle(fontSize: 14, color: FenixColors.textPrimary)),
        content: const Text('O grid será removido permanentemente.',
            style: TextStyle(fontSize: 12, color: FenixColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancelar',
                  style: TextStyle(color: FenixColors.textMuted))),
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Remover',
                  style: TextStyle(color: FenixColors.red,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(gridsProvider.notifier).deleteGrid(grid.id);
    }
  }

  Color _statusColor(String s) => switch (s) {
    'active'  => FenixColors.green,
    'paused'  => FenixColors.orange,
    'error'   => FenixColors.red,
    _         => FenixColors.textMuted,
  };

  String _statusLabel(String s) => switch (s) {
    'active'  => 'ATIVO',
    'paused'  => 'PAUSADO',
    'stopped' => 'PARADO',
    'error'   => 'ERRO',
    _         => s.toUpperCase(),
  };

  Color _gradeColor(String g) => switch (g) {
    'A+' => FenixColors.yellow,
    'A'  => FenixColors.green,
    'B'  => FenixColors.blue,
    _    => FenixColors.textMuted,
  };

  String _fmtPrice(double p) {
    if (p >= 1000) return NumberFormat('#,##0.00', 'pt_BR').format(p);
    if (p >= 1)    return p.toStringAsFixed(4);
    if (p >= 0.01) return p.toStringAsFixed(5);
    return p.toStringAsFixed(6);
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _Metrica extends StatelessWidget {
  final String label, value;
  final String? sub;
  final Color color;
  const _Metrica({required this.label, required this.value,
      required this.color, this.sub});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 9, color: FenixColors.textMuted)),
      Text(value, style: TextStyle(fontFamily: 'RobotoMono',
          fontSize: 11, fontWeight: FontWeight.w500, color: color)),
      if (sub != null)
        Text(sub!, style: TextStyle(fontSize: 8, color: color)),
    ]),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 3, height: 14,
        decoration: BoxDecoration(color: color,
            borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(text, style: TextStyle(fontSize: 11,
        fontWeight: FontWeight.w500, color: color)),
  ]);
}
