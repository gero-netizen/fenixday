/// FênixDay — Tela de Configuração do Grid Bot v2
///
/// Reprodução fiel da referência visual:
///   • Toolbar horizontal estilo TradingView (timeframes + indicadores + botões)
///   • Toolbar vertical esquerda com todas as ferramentas de desenho
///   • Gráfico candlestick com overlay das linhas do grid
///   • Layout responsivo: desktop/tablet = lado a lado | mobile = coluna única
///   • Em mobile: sem toolbars laterais

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../theme/fenix_theme.dart';
import '../widgets/chart/candlestick_chart.dart';

// ── Breakpoints ──────────────────────────────────────────────────────────────
const double _kTablet  = 768.0;
const double _kDesktop = 1100.0;

// ── Providers ────────────────────────────────────────────────────────────────
final _tfProvider    = StateProvider<String>((ref) => '1h');
final _toolProvider  = StateProvider<String>((ref) => 'crosshair');
final _paramsProvider = StateNotifierProvider<_GridParamsNotifier, _GridParams>(
  (ref) => _GridParamsNotifier(),
);

// ── Tela ─────────────────────────────────────────────────────────────────────
class GridConfigScreenV2 extends ConsumerWidget {
  const GridConfigScreenV2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w         = MediaQuery.of(context).size.width;
    final isTablet  = w >= _kTablet;
    final isDesktop = w >= _kDesktop;

    return Scaffold(
      backgroundColor: FenixColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _PairHeader(),
            _HorizontalToolbar(),
            Expanded(
              child: isTablet
                  ? Row(children: [
                      _VerticalToolbar(),
                      Expanded(child: _ChartArea()),
                      Container(width: .5, color: FenixColors.border),
                      SizedBox(width: isDesktop ? 300 : 240, child: _ParamsPanel()),
                    ])
                  : Column(children: [
                      Expanded(child: _ChartArea(showVerticalToolbar: false)),
                      _ParamsPanel(mobile: true),
                    ]),
            ),
            _SummaryBar(),
          ],
        ),
      ),
    );
  }
}

// ── Cabeçalho do par ─────────────────────────────────────────────────────────
class _PairHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat('#,##0.00', 'pt_BR');
    return Container(
      color: FenixColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          // Ícone BTC
          Container(
            width: 26, height: 26,
            decoration: const BoxDecoration(
              color: FenixColors.yellow, shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('₿', style: TextStyle(fontSize: 13, color: Color(0xFF1A0A00))),
            ),
          ),
          const SizedBox(width: 7),
          // Par + dropdown
          Row(
            children: [
              const Text('BTC/USDT',
                  style: TextStyle(
                      fontFamily: 'RobotoMono', fontSize: 13,
                      fontWeight: FontWeight.w500, color: FenixColors.textPrimary)),
              const Icon(Icons.arrow_drop_down, size: 16, color: FenixColors.textMuted),
            ],
          ),
          const SizedBox(width: 12),
          // Preço + variação
          const Text('66.842,19',
              style: TextStyle(
                  fontFamily: 'RobotoMono', fontSize: 17,
                  fontWeight: FontWeight.w500, color: FenixColors.green)),
          const SizedBox(width: 6),
          const Text('+1,25%',
              style: TextStyle(
                  fontFamily: 'RobotoMono', fontSize: 11, color: FenixColors.green)),
          const Spacer(),
          // Estatísticas 24h
          Wrap(spacing: 16, children: [
            _StatMini('24h Máxima', '67.189,00'),
            _StatMini('24h Mínima', '65.812,10'),
            _StatMini('Volume 24h (BTC)', '18.573,25'),
            _StatMini('Volume 24h (USDT)', '1,23B'),
          ]),
        ],
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String label, value;
  const _StatMini(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 9, color: FenixColors.textMuted)),
      Text(value,
          style: const TextStyle(
              fontFamily: 'RobotoMono', fontSize: 11,
              fontWeight: FontWeight.w500, color: FenixColors.textPrimary)),
    ],
  );
}

// ── Toolbar horizontal ────────────────────────────────────────────────────────
class _HorizontalToolbar extends ConsumerWidget {
  static const _tfs = ['15m', '1h', '4h', '1D'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_tfProvider);
    return Container(
      color: FenixColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        children: [
          // Timeframes
          ..._tfs.map((tf) => _TfBtn(
                label: tf,
                active: tf == selected,
                onTap: () => ref.read(_tfProvider.notifier).state = tf,
              )),

          // Divisor
          _vDivider(),

          // Comparar
          _IconBtn(icon: Icons.compare_arrows, tooltip: 'Comparar'),
          // Tipo de gráfico
          _IconBtn(icon: Icons.candlestick_chart_outlined, tooltip: 'Tipo de gráfico'),

          // Divisor
          _vDivider(),

          // Indicadores
          _TextBtn(
            icon: Icons.functions,
            label: 'Indicadores',
            onTap: () {},
          ),

          const Spacer(),

          // Trading View
          _OutlineBtn(label: 'Trading View', onTap: () {}),
          const SizedBox(width: 5),
          // Profundidade
          _OutlineBtn(label: 'Profundidade', onTap: () {}),
          const SizedBox(width: 8),
          // Tela cheia
          _IconBtn(icon: Icons.fullscreen, tooltip: 'Tela cheia'),
          // Configurações
          _IconBtn(icon: Icons.settings_outlined, tooltip: 'Configurações'),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
      width: .5, height: 18, color: FenixColors.border,
      margin: const EdgeInsets.symmetric(horizontal: 6));
}

class _TfBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TfBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? FenixColors.yellowBg : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: active
            ? Border.all(color: FenixColors.yellow.withOpacity(.3), width: .5)
            : null,
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w500,
              color: active ? FenixColors.yellow : FenixColors.textMuted)),
    ),
  );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _IconBtn({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(icon, size: 15, color: FenixColors.textMuted),
      ),
    ),
  );
}

class _TextBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _TextBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(children: [
        Icon(icon, size: 13, color: FenixColors.textMuted),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: FenixColors.textMuted)),
      ]),
    ),
  );
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: FenixColors.border, width: .5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 11, color: FenixColors.textSecondary)),
    ),
  );
}

// ── Toolbar vertical esquerda (desktop/tablet) ────────────────────────────────
class _VerticalToolbar extends ConsumerWidget {
  // Ferramentas agrupadas exatamente como na imagem de referência
  static final _groups = [
    // Grupo 1: cursor
    [_VTool('crosshair', Icons.add, 'Cursor / Crosshair')],
    // Grupo 2: linhas
    [
      _VTool('line',      Icons.show_chart,            'Linha de tendência'),
      _VTool('hline',     Icons.horizontal_rule,        'Linha horizontal'),
      _VTool('hlines',    Icons.format_line_spacing,    'Linhas paralelas'),
      _VTool('arrow',     Icons.arrow_right_alt,        'Seta'),
    ],
    // Grupo 3: texto
    [_VTool('text', Icons.text_fields, 'Texto')],
    // Grupo 4: padrões
    [
      _VTool('elliott',   Icons.timeline,               'Ondas de Elliott'),
      _VTool('fib',       Icons.compress,               'Fibonacci Retracement'),
      _VTool('ruler',     Icons.straighten,             'Régua / Medidor'),
    ],
    // Grupo 5: formas
    [
      _VTool('brush',     Icons.brush_outlined,         'Pincel livre'),
      _VTool('zoom',      Icons.zoom_in,                'Zoom'),
    ],
    // Grupo 6: extras
    [
      _VTool('magnet',    Icons.magnet,                 'Imã'),
      _VTool('layers',    Icons.layers_outlined,        'Camadas / Visibilidade'),
      _VTool('lock',      Icons.lock_outline,           'Bloquear objetos'),
      _VTool('eye_cfg',   Icons.visibility_outlined,    'Configurar visibilidade'),
    ],
    // Grupo 7: lixeira
    [_VTool('delete', Icons.delete_outline, 'Excluir objetos')],
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_toolProvider);
    return Container(
      width: 42,
      color: FenixColors.surface,
      child: Column(
        children: [
          const SizedBox(height: 6),
          ..._groups.expand((group) => [
            ...group.map((t) => _VToolBtn(
                  tool: t,
                  selected: selected == t.id,
                  onTap: () => ref.read(_toolProvider.notifier).state = t.id,
                )),
            // Separador entre grupos
            if (group != _groups.last)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Divider(height: 1, thickness: .5, color: FenixColors.border),
              ),
          ]),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _VTool {
  final String id, tooltip;
  final IconData icon;
  const _VTool(this.id, this.icon, this.tooltip);
}

class _VToolBtn extends StatelessWidget {
  final _VTool tool;
  final bool selected;
  final VoidCallback onTap;
  const _VToolBtn({required this.tool, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tool.tooltip,
    preferBelow: false,
    child: InkWell(
      onTap: onTap,
      child: Container(
        width: 42, height: 34,
        decoration: selected
            ? BoxDecoration(
                color: FenixColors.yellowBg,
                border: Border(
                  left: BorderSide(color: FenixColors.yellow, width: 2),
                ),
              )
            : null,
        child: Icon(
          tool.icon,
          size: 16,
          color: selected ? FenixColors.yellow : FenixColors.textMuted,
        ),
      ),
    ),
  );
}

// ── Área do gráfico ───────────────────────────────────────────────────────────
class _ChartArea extends ConsumerWidget {
  final bool showVerticalToolbar;
  const _ChartArea({this.showVerticalToolbar = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(_paramsProvider);
    final candles = _generateMockCandles();

    return Container(
      color: FenixColors.bg,
      child: Column(
        children: [
          // Info OHLC no topo do gráfico (estilo TradingView)
          Container(
            color: FenixColors.bg,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(children: [
              const Text('BTC/USDT · 1h · BINANCE',
                  style: TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 10, color: FenixColors.textMuted)),
              const SizedBox(width: 10),
              _ohlc('Abr', '67.021,10'),
              _ohlc('Máx', '67.089,20', color: FenixColors.green),
              _ohlc('Mín', '66.742,10', color: FenixColors.red),
              _ohlc('Fch', '66.842,19'),
              const Text(' −178,91 (−0,27%)',
                  style: TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 10, color: FenixColors.red)),
            ]),
          ),

          // Gráfico
          Expanded(
            child: CandlestickChart(
              candles: candles,
              upperBound:   params.upperPrice,
              lowerBound:   params.lowerPrice,
              currentPrice: 66842.19,
              gridLevels:   params.computedLevels,
              visibleCandles: 60,
            ),
          ),

          // Barra de períodos e info rodapé
          _PeriodBar(),
        ],
      ),
    );
  }

  Widget _ohlc(String label, String value, {Color color = FenixColors.textSecondary}) =>
      Padding(
        padding: const EdgeInsets.only(right: 10),
        child: RichText(
          text: TextSpan(children: [
            TextSpan(
                text: '$label ',
                style: const TextStyle(
                    fontFamily: 'RobotoMono', fontSize: 10,
                    color: FenixColors.textMuted)),
            TextSpan(
                text: value,
                style: TextStyle(
                    fontFamily: 'RobotoMono', fontSize: 10, color: color)),
          ]),
        ),
      );
}

// ── Barra de períodos (rodapé do gráfico) ────────────────────────────────────
class _PeriodBar extends StatelessWidget {
  static const _periods = ['1D', '5D', '1M', '3M', '6M', 'YTD', '1A', '5A', 'Todos'];

  @override
  Widget build(BuildContext context) => Container(
    color: FenixColors.surface,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(children: [
      ..._periods.map((p) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(p,
                style: const TextStyle(fontSize: 10, color: FenixColors.textMuted)),
          )),
      const SizedBox(width: 4),
      const Icon(Icons.compare_arrows, size: 12, color: FenixColors.textMuted),
      const Spacer(),
      Text(
        DateFormat('HH:mm:ss').format(DateTime.now()) + ' (UTC-3)',
        style: const TextStyle(
            fontFamily: 'RobotoMono', fontSize: 10, color: FenixColors.textMuted),
      ),
      const SizedBox(width: 10),
      const Text('%', style: TextStyle(fontSize: 10, color: FenixColors.textMuted)),
      const SizedBox(width: 8),
      const Text('log', style: TextStyle(fontSize: 10, color: FenixColors.textMuted)),
      const SizedBox(width: 8),
      const Text('auto',
          style: TextStyle(
              fontSize: 10, color: FenixColors.yellow,
              fontWeight: FontWeight.w500)),
    ]),
  );
}

// ── Painel de parâmetros ──────────────────────────────────────────────────────
class _ParamsPanel extends ConsumerStatefulWidget {
  final bool mobile;
  const _ParamsPanel({this.mobile = false});

  @override
  ConsumerState<_ParamsPanel> createState() => _ParamsPanelState();
}

class _ParamsPanelState extends ConsumerState<_ParamsPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  bool _showAdvanced = false;

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final params  = ref.watch(_paramsProvider);
    final notifier = ref.read(_paramsProvider.notifier);

    Widget content = Column(
      children: [
        // Abas
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: FenixColors.border, width: .5)),
          ),
          child: TabBar(
            controller: _tab,
            labelColor: FenixColors.yellow,
            unselectedLabelColor: FenixColors.textMuted,
            indicatorColor: FenixColors.yellow,
            indicatorWeight: 2,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            tabs: const [Tab(text: 'Parâmetros do Grid'), Tab(text: 'Sobre o Bot')],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              // ── Aba parâmetros ──────────────────────────────────────────
              SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Toggle Estratégias / Manual
                    Container(
                      decoration: BoxDecoration(
                        color: FenixColors.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: FenixColors.border, width: .5),
                      ),
                      child: Row(children: [
                        _ToggleTab(label: 'Estratégias inteligentes', active: false,
                            onTap: () {}),
                        _ToggleTab(label: 'Manual', active: true, onTap: () {}),
                      ]),
                    ),
                    const SizedBox(height: 12),

                    // Intervalo de preço
                    _FieldLabel('Intervalo de preço (USDT)',
                        trailing: TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero),
                          child: const Text('🗑 Limpar tudo',
                              style: TextStyle(fontSize: 10,
                                  color: FenixColors.textMuted)),
                        )),
                    Row(children: [
                      Expanded(
                        child: _PriceField(
                          value: params.lowerPrice,
                          onMinus: () => notifier.adjustLower(-100),
                          onPlus:  () => notifier.adjustLower(100),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('–', style: TextStyle(color: FenixColors.textMuted)),
                      ),
                      Expanded(
                        child: _PriceField(
                          value: params.upperPrice,
                          onMinus: () => notifier.adjustUpper(-100),
                          onPlus:  () => notifier.adjustUpper(100),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      'Margem de lucro por grid ${params.marginMin.toStringAsFixed(2)}% – ${params.marginMax.toStringAsFixed(2)}% (–)',
                      style: const TextStyle(fontSize: 10, color: FenixColors.textMuted),
                    ),
                    const SizedBox(height: 12),

                    // Quantidade de grids
                    _FieldLabel('Quantidade de grids (2 a 230)'),
                    _PriceField(
                      value: params.numGrids.toDouble(),
                      isInt: true,
                      onMinus: () => notifier.adjustGrids(-1),
                      onPlus:  () => notifier.adjustGrids(1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Margem de lucro por grade ${params.currentMargin.toStringAsFixed(2)}% – ${params.marginMax.toStringAsFixed(2)}% (–)',
                      style: const TextStyle(fontSize: 10, color: FenixColors.textMuted),
                    ),
                    const SizedBox(height: 12),

                    // Valor do investimento
                    _FieldLabel('Valor do investimento'),
                    Container(
                      decoration: BoxDecoration(
                        color: FenixColors.card,
                        border: Border.all(color: FenixColors.border, width: .5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            '≥ ${NumberFormat('#,##0.00', 'pt_BR').format(params.allocatedUsdt)}',
                            style: const TextStyle(
                                fontFamily: 'RobotoMono',
                                fontSize: 13, color: FenixColors.textPrimary),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            border: Border.all(color: FenixColors.border, width: .5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(children: [
                            Text('USDT',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: FenixColors.textSecondary)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down,
                                size: 14, color: FenixColors.textMuted),
                          ]),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    SliderTheme(
                      data: _sliderTheme,
                      child: Slider(
                        value: params.allocationPct,
                        onChanged: notifier.setAllocationPct,
                        divisions: 4,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: ['0', '', '', '', '100%'].map((s) =>
                          Text(s, style: const TextStyle(
                              fontSize: 9, color: FenixColors.textMuted))).toList(),
                    ),
                    const SizedBox(height: 4),
                    const Text('Disponível 0,00 USDT',
                        style: TextStyle(
                            fontSize: 10, color: FenixColors.textMuted)),
                    const SizedBox(height: 12),

                    // Reinvestir lucros
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Reinvestir lucros',
                            style: TextStyle(
                                fontSize: 13, color: FenixColors.textSecondary)),
                        Switch(
                          value: params.reinvest,
                          onChanged: notifier.setReinvest,
                          activeColor: FenixColors.green,
                          inactiveThumbColor: FenixColors.textMuted,
                          inactiveTrackColor: FenixColors.border,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Configurações avançadas
                    InkWell(
                      onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          const Text('Configurações avançadas',
                              style: TextStyle(
                                  fontSize: 13, color: FenixColors.textSecondary)),
                          const Spacer(),
                          Icon(
                            _showAdvanced
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 18, color: FenixColors.textMuted,
                          ),
                        ]),
                      ),
                    ),

                    if (_showAdvanced) ...[
                      const Divider(height: 1, thickness: .5, color: FenixColors.border),
                      const SizedBox(height: 10),
                      // Trailing
                      const Text('Configurações de trailing',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500,
                              color: FenixColors.textPrimary)),
                      const SizedBox(height: 8),
                      _CheckRow(
                        label: 'Trailing up',
                        value: params.trailingUp,
                        onChanged: notifier.setTrailingUp,
                      ),
                      _CheckRow(
                        label: 'Trailing down',
                        value: params.trailingDown,
                        onChanged: notifier.setTrailingDown,
                      ),
                      const SizedBox(height: 10),

                      // Condição de início
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Condição de início',
                              style: TextStyle(
                                  fontSize: 12, color: FenixColors.textSecondary)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: FenixColors.border, width: .5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(children: [
                              Text('Instantâneo',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: FenixColors.textSecondary)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down,
                                  size: 14, color: FenixColors.textMuted),
                            ]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // TP/SL
                      _CheckRow(
                        label: 'TP/SL',
                        value: params.tpsl,
                        onChanged: notifier.setTpSl,
                      ),

                      if (params.tpsl) ...[
                        const SizedBox(height: 8),
                        // Take profit
                        const Text('Take profit',
                            style: TextStyle(
                                fontSize: 11, color: FenixColors.textMuted)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 9),
                              decoration: BoxDecoration(
                                color: FenixColors.card,
                                border: Border.all(
                                    color: FenixColors.border, width: .5),
                                borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(5)),
                              ),
                              child: const Text('Preço TP',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: FenixColors.textMuted)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 9),
                            decoration: BoxDecoration(
                              color: FenixColors.card2,
                              border: Border.all(
                                  color: FenixColors.border, width: .5),
                              borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(5)),
                            ),
                            child: const Row(children: [
                              Text('USDT',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: FenixColors.textSecondary)),
                              SizedBox(width: 3),
                              Icon(Icons.arrow_drop_down,
                                  size: 13, color: FenixColors.textMuted),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        // Stop loss
                        const Text('Stop loss',
                            style: TextStyle(
                                fontSize: 11, color: FenixColors.textMuted)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 9),
                              decoration: BoxDecoration(
                                color: FenixColors.card,
                                border: Border.all(
                                    color: FenixColors.border, width: .5),
                                borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(5)),
                              ),
                              child: const Text('Preço SL',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: FenixColors.textMuted)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 9),
                            decoration: BoxDecoration(
                              color: FenixColors.card2,
                              border: Border.all(
                                  color: FenixColors.border, width: .5),
                              borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(5)),
                            ),
                            child: const Row(children: [
                              Text('USDT',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: FenixColors.textSecondary)),
                              SizedBox(width: 3),
                              Icon(Icons.arrow_drop_down,
                                  size: 13, color: FenixColors.textMuted),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        // Início tardio
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                            color: FenixColors.card,
                            border: Border.all(
                                color: FenixColors.border, width: .5),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Row(children: [
                            Expanded(
                              child: Text('Início tardio',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: FenixColors.textMuted)),
                            ),
                            Text('5 – 30 S',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: FenixColors.textSecondary)),
                          ]),
                        ),
                        const SizedBox(height: 6),
                        // Cripto devolvida
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                            color: FenixColors.card,
                            border: Border.all(
                                color: FenixColors.border, width: .5),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Row(children: [
                            Expanded(
                              child: Text('Cripto devolvida',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: FenixColors.textSecondary)),
                            ),
                            Text('USDT',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: FenixColors.textSecondary)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down,
                                size: 13, color: FenixColors.textMuted),
                          ]),
                        ),
                      ],

                      const SizedBox(height: 10),
                      // Modo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Modo',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: FenixColors.textSecondary)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: FenixColors.border, width: .5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(children: [
                              Text('Geométrico',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: FenixColors.textSecondary)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down,
                                  size: 14, color: FenixColors.textMuted),
                            ]),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Botão Criar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FenixColors.textPrimary,
                          foregroundColor: FenixColors.bg,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          elevation: 0,
                        ),
                        onPressed: () {},
                        child: const Text('Criar',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Aba sobre o bot ────────────────────────────────────────────
              const Center(
                child: Text('Informações sobre o bot',
                    style: TextStyle(color: FenixColors.textMuted)),
              ),
            ],
          ),
        ),
      ],
    );

    return widget.mobile
        ? SizedBox(height: 400, child: content)
        : content;
  }
}

// ── SliderTheme compartilhado ─────────────────────────────────────────────────
final _sliderTheme = SliderThemeData(
  activeTrackColor: FenixColors.yellow,
  inactiveTrackColor: FenixColors.border,
  thumbColor: FenixColors.yellow,
  trackHeight: 3,
  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
);

// ── Barra de resumo inferior ──────────────────────────────────────────────────
class _SummaryBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(_paramsProvider);
    final fmt    = NumberFormat('#,##0.00', 'pt_BR');
    const rate   = 5.49;

    return Container(
      decoration: const BoxDecoration(
        color: FenixColors.surface,
        border: Border(top: BorderSide(color: FenixColors.border, width: .5)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _SumCard('Preço Atual',
              '${fmt.format(66842.19)} USDT',
              '≈ R\$ ${fmt.format(66842.19 * rate)}',
              FenixColors.green),
          _divider(),
          _SumCard('Investimento Total',
              '${fmt.format(params.allocatedUsdt)} USDT',
              '${(params.allocationPct * 100).toStringAsFixed(0)}% do saldo',
              FenixColors.textPrimary),
          _divider(),
          _SumCard('Lucro Estimado (7d)',
              '${fmt.format(params.allocatedUsdt * .0124)} ~ ${fmt.format(params.allocatedUsdt * .0187)} USDT',
              '1,24% ~ 1,87%',
              FenixColors.green),
          _divider(),
          _SumCard('Nº de Ordens',
              '${params.totalOrders} ordens',
              '${params.numGrids} compras + ${params.numGrids} vendas',
              FenixColors.textPrimary),
          _divider(),
          _SumCard('Margem por Grade',
              '${params.currentMargin.toStringAsFixed(2)}%',
              'Entre 0,35% e 0,48%',
              FenixColors.green),
        ]),
      ),
    );
  }

  Widget _divider() =>
      Container(width: .5, height: 50, color: FenixColors.border);
}

class _SumCard extends StatelessWidget {
  final String label, value, sub;
  final Color valueColor;
  const _SumCard(this.label, this.value, this.sub, this.valueColor);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: FenixColors.textMuted)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontFamily: 'RobotoMono', fontSize: 12,
                fontWeight: FontWeight.w500, color: valueColor)),
        Text(sub, style: const TextStyle(fontSize: 10, color: FenixColors.textMuted)),
      ],
    ),
  );
}

// ── Widgets de formulário ─────────────────────────────────────────────────────
class _ToggleTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? FenixColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: active
              ? Border.all(color: FenixColors.border, width: .5)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w500,
                color: active
                    ? FenixColors.textPrimary
                    : FenixColors.textMuted)),
      ),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final Widget? trailing;
  const _FieldLabel(this.label, {this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12, color: FenixColors.textSecondary)),
      const Spacer(),
      if (trailing != null) trailing!,
    ]),
  );
}

class _PriceField extends StatelessWidget {
  final double value;
  final bool isInt;
  final VoidCallback onMinus, onPlus;
  const _PriceField({
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.isInt = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = isInt
        ? value.toInt().toString()
        : NumberFormat('#,##0.00', 'pt_BR').format(value);

    return Container(
      decoration: BoxDecoration(
        color: FenixColors.card,
        border: Border.all(color: FenixColors.border, width: .5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Text(text,
                style: const TextStyle(
                    fontFamily: 'RobotoMono', fontSize: 13,
                    color: FenixColors.textPrimary)),
          ),
        ),
        InkWell(
          onTap: onMinus,
          child: Container(
            width: 36, height: 40,
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: FenixColors.border, width: .5)),
            ),
            child: const Icon(Icons.remove, size: 14, color: FenixColors.textMuted),
          ),
        ),
        InkWell(
          onTap: onPlus,
          child: Container(
            width: 36, height: 40,
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: FenixColors.border, width: .5)),
            ),
            child: const Icon(Icons.add, size: 14, color: FenixColors.yellow),
          ),
        ),
      ]),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _CheckRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(
      width: 20, height: 20,
      child: Checkbox(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        activeColor: FenixColors.yellow,
        side: const BorderSide(color: FenixColors.border, width: .5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
    ),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(fontSize: 12, color: FenixColors.textSecondary)),
  ]);
}

// ── State ─────────────────────────────────────────────────────────────────────
class _GridParams {
  final double upperPrice, lowerPrice;
  final int numGrids;
  final double marginMin, marginMax;
  final double allocatedUsdt, allocationPct;
  final bool reinvest, trailingUp, trailingDown, tpsl;

  const _GridParams({
    this.upperPrice    = 1.6,
    this.lowerPrice    = 0.99,
    this.numGrids      = 70,
    this.marginMin     = 0.35,
    this.marginMax     = 0.48,
    this.allocatedUsdt = 0.0,
    this.allocationPct = 0.0,
    this.reinvest      = true,
    this.trailingUp    = false,
    this.trailingDown  = false,
    this.tpsl          = false,
  });

  double get currentMargin  => (marginMin + marginMax) / 2;
  int    get totalOrders    => numGrids * 2;
  List<double> get computedLevels {
    if (numGrids <= 1) return [];
    final step = (upperPrice - lowerPrice) / numGrids;
    return List.generate(numGrids - 1, (i) => lowerPrice + step * (i + 1));
  }

  _GridParams copyWith({
    double? upperPrice, double? lowerPrice, int? numGrids,
    double? allocatedUsdt, double? allocationPct,
    bool? reinvest, bool? trailingUp, bool? trailingDown, bool? tpsl,
  }) => _GridParams(
    upperPrice:    upperPrice    ?? this.upperPrice,
    lowerPrice:    lowerPrice    ?? this.lowerPrice,
    numGrids:      numGrids      ?? this.numGrids,
    allocatedUsdt: allocatedUsdt ?? this.allocatedUsdt,
    allocationPct: allocationPct ?? this.allocationPct,
    reinvest:      reinvest      ?? this.reinvest,
    trailingUp:    trailingUp    ?? this.trailingUp,
    trailingDown:  trailingDown  ?? this.trailingDown,
    tpsl:          tpsl          ?? this.tpsl,
  );
}

class _GridParamsNotifier extends StateNotifier<_GridParams> {
  _GridParamsNotifier() : super(const _GridParams());
  void adjustUpper(double d) => state = state.copyWith(upperPrice: (state.upperPrice + d).clamp(0, 1e8));
  void adjustLower(double d) => state = state.copyWith(lowerPrice: (state.lowerPrice + d).clamp(0, 1e8));
  void adjustGrids(int d)    => state = state.copyWith(numGrids: (state.numGrids + d).clamp(2, 230));
  void setAllocationPct(double v) => state = state.copyWith(allocationPct: v, allocatedUsdt: 1000 * v);
  void setReinvest(bool v)   => state = state.copyWith(reinvest: v);
  void setTrailingUp(bool v) => state = state.copyWith(trailingUp: v);
  void setTrailingDown(bool v) => state = state.copyWith(trailingDown: v);
  void setTpSl(bool v)       => state = state.copyWith(tpsl: v);
}

// ── Mock de candles ───────────────────────────────────────────────────────────
List<CandleData> _generateMockCandles() {
  double price = 66800;
  return List.generate(80, (i) {
    final seed   = (DateTime.now().millisecondsSinceEpoch + i * 1234567) % 1000;
    final change = (seed / 1000 - 0.5) * 400;
    final open   = price;
    final close  = price + change;
    final high   = [open, close].reduce((a, b) => a > b ? a : b) + seed % 120;
    final low    = [open, close].reduce((a, b) => a < b ? a : b) - seed % 100;
    price = close;
    return CandleData(
      time: DateTime.now().subtract(Duration(hours: 80 - i)),
      open: open, high: high, low: low, close: close,
      volume: 500 + seed * 20.0,
    );
  });
}
