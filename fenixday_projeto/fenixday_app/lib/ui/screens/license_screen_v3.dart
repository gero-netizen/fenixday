/// FênixDay — Tela de Licença v3 (integrada com API real)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/fenix_theme.dart';

const _baseUrl = 'https://fenixday.info/api/v1';

// ── Enums e modelos ───────────────────────────────────────────────────────────

enum PlanTier { exempt, basic, pro, premium }

class PlanInfo {
  final PlanTier tier;
  final String name;
  final double priceMonthly;
  final double volumeMin;
  final double? volumeMax;
  final double? notifyAt;
  final Color color;
  final Color colorBg;
  final String badge;

  const PlanInfo({
    required this.tier,
    required this.name,
    required this.priceMonthly,
    required this.volumeMin,
    this.volumeMax,
    this.notifyAt,
    required this.color,
    required this.colorBg,
    required this.badge,
  });
}

const _plans = {
  PlanTier.exempt: PlanInfo(
    tier: PlanTier.exempt,
    name: 'Isento',
    priceMonthly: 0,
    volumeMin: 0,
    volumeMax: 499.99,
    notifyAt: 300,
    color: FenixColors.green,
    colorBg: FenixColors.greenBg,
    badge: 'ISENTO',
  ),
  PlanTier.basic: PlanInfo(
    tier: PlanTier.basic,
    name: 'Basic',
    priceMonthly: 10.00,
    volumeMin: 500,
    volumeMax: 4999.99,
    notifyAt: 4800,
    color: FenixColors.blue,
    colorBg: FenixColors.blueBg,
    badge: 'BASIC',
  ),
  PlanTier.pro: PlanInfo(
    tier: PlanTier.pro,
    name: 'Pro',
    priceMonthly: 14.99,
    volumeMin: 5000,
    volumeMax: 34999.99,
    notifyAt: 33000,
    color: FenixColors.purple,
    colorBg: FenixColors.purpleBg,
    badge: 'PRO',
  ),
  PlanTier.premium: PlanInfo(
    tier: PlanTier.premium,
    name: 'Premium',
    priceMonthly: 29.90,
    volumeMin: 35000,
    volumeMax: null,
    notifyAt: null,
    color: FenixColors.yellow,
    colorBg: FenixColors.yellowBg,
    badge: 'PREMIUM',
  ),
};

PlanTier _tierFromString(String s) {
  return switch (s) {
    'basic'   => PlanTier.basic,
    'pro'     => PlanTier.pro,
    'premium' => PlanTier.premium,
    _         => PlanTier.exempt,
  };
}

class _SubState {
  final PlanTier currentTier;
  final PlanTier? pendingTier;
  final double tradedVolume;
  final bool isActive;
  final int? daysRemaining;
  final DateTime? expiresAt;
  final bool realModeAllowed;
  final bool isLoading;
  final String? error;

  const _SubState({
    this.currentTier = PlanTier.exempt,
    this.pendingTier,
    this.tradedVolume = 0,
    this.isActive = false,
    this.daysRemaining,
    this.expiresAt,
    this.realModeAllowed = false,
    this.isLoading = true,
    this.error,
  });

  PlanInfo get currentPlan => _plans[currentTier]!;
  PlanInfo? get pendingPlan =>
      pendingTier != null ? _plans[pendingTier!] : null;

  bool get hasPendingUpgrade =>
      pendingTier != null && pendingTier != currentTier;

  double get volumeProgress {
    final plan = currentPlan;
    if (plan.volumeMax == null) return 1.0;
    final next = _nextPlan;
    if (next == null) return 1.0;
    final range = next.volumeMin - plan.volumeMin;
    return ((tradedVolume - plan.volumeMin) / range).clamp(0.0, 1.0);
  }

  PlanInfo? get _nextPlan {
    final order = [PlanTier.exempt, PlanTier.basic, PlanTier.pro, PlanTier.premium];
    final idx = order.indexOf(currentTier);
    if (idx < order.length - 1) return _plans[order[idx + 1]];
    return null;
  }

  double? get volumeFaltante {
    final next = _nextPlan;
    if (next == null) return null;
    return (next.volumeMin - tradedVolume).clamp(0, double.infinity);
  }

  bool get shouldWarnUpgrade {
    final plan = currentPlan;
    if (plan.notifyAt == null) return false;
    return tradedVolume >= plan.notifyAt!;
  }

  _SubState copyWith({
    PlanTier? currentTier,
    PlanTier? pendingTier,
    double? tradedVolume,
    bool? isActive,
    int? daysRemaining,
    DateTime? expiresAt,
    bool? realModeAllowed,
    bool? isLoading,
    String? error,
  }) => _SubState(
    currentTier: currentTier ?? this.currentTier,
    pendingTier: pendingTier ?? this.pendingTier,
    tradedVolume: tradedVolume ?? this.tradedVolume,
    isActive: isActive ?? this.isActive,
    daysRemaining: daysRemaining ?? this.daysRemaining,
    expiresAt: expiresAt ?? this.expiresAt,
    realModeAllowed: realModeAllowed ?? this.realModeAllowed,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}

// ── Provider com API real ─────────────────────────────────────────────────────

class _SubNotifier extends StateNotifier<_SubState> {
  _SubNotifier() : super(const _SubState()) {
    loadStatus();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> loadStatus() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = await _getToken();
      if (token == null) {
        state = state.copyWith(isLoading: false, error: 'Não autenticado');
        return;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/subscriptions/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tier = _tierFromString(data['current_tier'] ?? 'exempt');
        final daysRemaining = data['days_remaining'] as int?;
        final expiresAtStr = data['expires_at'] as String?;

        state = state.copyWith(
          currentTier: tier,
          tradedVolume: (data['traded_volume'] as num?)?.toDouble() ?? 0,
          isActive: data['real_mode_allowed'] == true,
          daysRemaining: daysRemaining,
          expiresAt: expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null,
          realModeAllowed: data['real_mode_allowed'] == true,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Erro ao carregar status',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erro de conexão',
      );
    }
  }
}

final _subProvider = StateNotifierProvider<_SubNotifier, _SubState>(
  (ref) => _SubNotifier(),
);

// ── Tela ──────────────────────────────────────────────────────────────────────

class LicenseScreenV3 extends ConsumerStatefulWidget {
  const LicenseScreenV3({super.key});

  @override
  ConsumerState<LicenseScreenV3> createState() => _LicenseScreenV3State();
}

class _LicenseScreenV3State extends ConsumerState<LicenseScreenV3> {
  String _currency = 'USDT';

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(_subProvider);

    if (sub.isLoading) {
      return const Scaffold(
        backgroundColor: FenixColors.bg,
        body: Center(child: CircularProgressIndicator(color: FenixColors.yellow)),
      );
    }

    if (sub.error != null) {
      return Scaffold(
        backgroundColor: FenixColors.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(sub.error!, style: const TextStyle(color: FenixColors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(_subProvider.notifier).loadStatus(),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: FenixColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(_subProvider.notifier).loadStatus(),
          color: FenixColors.yellow,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Licença & Plano',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500,
                        color: FenixColors.textPrimary)),
                const SizedBox(height: 16),
                _CurrentPlanCard(sub: sub),
                const SizedBox(height: 12),
                if (sub.shouldWarnUpgrade) ...[
                  _UpgradeAlert(sub: sub),
                  const SizedBox(height: 12),
                ],
                _VolumeProgressCard(sub: sub),
                const SizedBox(height: 12),
                _PlansGrid(sub: sub),
                const SizedBox(height: 12),
                if (sub.currentTier != PlanTier.exempt) ...[
                  _CheckoutCard(
                    sub: sub,
                    currency: _currency,
                    onCurrencyChange: (c) => setState(() => _currency = c),
                  ),
                  const SizedBox(height: 12),
                ],
                _RenewalHistory(sub: sub),
                const SizedBox(height: 12),
                _FeaturesCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Card plano atual ──────────────────────────────────────────────────────────

class _CurrentPlanCard extends StatelessWidget {
  final _SubState sub;
  const _CurrentPlanCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    final plan   = sub.currentPlan;
    final fmt    = NumberFormat('#,##0.00', 'pt_BR');
    final urgent = (sub.daysRemaining ?? 99) <= 5;
    final color  = urgent ? FenixColors.red : plan.color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: plan.colorBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: plan.color.withOpacity(.3), width: .5),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: plan.color.withOpacity(.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_planIcon(plan.tier), color: plan.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Plano ${plan.name}',
                    style: const TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: FenixColors.textPrimary)),
                const SizedBox(width: 8),
                _PlanBadge(plan: plan),
              ]),
              const SizedBox(height: 2),
              Text(
                plan.priceMonthly == 0
                    ? 'Gratuito — volume abaixo de \$500'
                    : '\$${fmt.format(plan.priceMonthly)}/mês',
                style: TextStyle(fontSize: 11, color: plan.color),
              ),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: sub.isActive ? FenixColors.green : FenixColors.red,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              sub.isActive ? 'ATIVO' : 'GRATUITO',
              style: const TextStyle(fontFamily: 'RobotoMono',
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: Color(0xFF0A1F15)),
            ),
          ),
        ]),
        if (sub.daysRemaining != null && sub.currentTier != PlanTier.exempt) ...[
          const SizedBox(height: 12),
          _DaysBar(days: sub.daysRemaining!, color: color),
          if (urgent)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: FenixColors.redBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_outlined,
                      size: 14, color: FenixColors.red),
                  const SizedBox(width: 7),
                  Text(
                    'Plano vence em ${sub.daysRemaining} dia(s). Renove agora.',
                    style: const TextStyle(fontSize: 11, color: FenixColors.red),
                  ),
                ]),
              ),
            ),
        ],
        if (sub.hasPendingUpgrade) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: sub.pendingPlan!.colorBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: sub.pendingPlan!.color.withOpacity(.3), width: .5),
            ),
            child: Row(children: [
              Icon(Icons.schedule_outlined,
                  size: 14, color: sub.pendingPlan!.color),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Na próxima renovação: Plano ${sub.pendingPlan!.name} '
                '(\$${NumberFormat('#,##0.00').format(sub.pendingPlan!.priceMonthly)}/mês)',
                style: TextStyle(fontSize: 11, color: sub.pendingPlan!.color),
              )),
            ]),
          ),
        ],
      ]),
    );
  }

  IconData _planIcon(PlanTier tier) => switch (tier) {
    PlanTier.exempt  => Icons.star_outline,
    PlanTier.basic   => Icons.rocket_launch_outlined,
    PlanTier.pro     => Icons.bolt_outlined,
    PlanTier.premium => Icons.workspace_premium_outlined,
  };
}

class _DaysBar extends StatelessWidget {
  final int days;
  final Color color;
  const _DaysBar({required this.days, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (days / 30).clamp(0.0, 1.0);
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Dias restantes: $days',
            style: const TextStyle(fontSize: 11, color: FenixColors.textMuted)),
        Text('$days / 30 dias',
            style: TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: color)),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: pct, minHeight: 5,
          backgroundColor: FenixColors.border,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ]);
  }
}

// ── Alerta de upgrade ─────────────────────────────────────────────────────────

class _UpgradeAlert extends StatelessWidget {
  final _SubState sub;
  const _UpgradeAlert({required this.sub});

  @override
  Widget build(BuildContext context) {
    final nextPlan = _plans[_nextTier(sub.currentTier)];
    if (nextPlan == null) return const SizedBox.shrink();
    final fmt = NumberFormat('#,##0.00', 'pt_BR');

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: nextPlan.colorBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: nextPlan.color.withOpacity(.3), width: .5),
      ),
      child: Row(children: [
        Icon(Icons.trending_up, size: 18, color: nextPlan.color),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mudança de plano se aproximando!',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                    color: nextPlan.color)),
            const SizedBox(height: 3),
            Text(
              'Faltam apenas \$${fmt.format(sub.volumeFaltante ?? 0)} em volume '
              'para o Plano ${nextPlan.name}. '
              'O novo valor será de \$${fmt.format(nextPlan.priceMonthly)}/mês '
              'na próxima renovação.',
              style: const TextStyle(
                  fontSize: 10, color: FenixColors.textMuted, height: 1.4),
            ),
          ],
        )),
      ]),
    );
  }

  PlanTier? _nextTier(PlanTier t) {
    final order = [PlanTier.exempt, PlanTier.basic, PlanTier.pro, PlanTier.premium];
    final idx = order.indexOf(t);
    if (idx < order.length - 1) return order[idx + 1];
    return null;
  }
}

// ── Progresso de volume ───────────────────────────────────────────────────────

class _VolumeProgressCard extends StatelessWidget {
  final _SubState sub;
  const _VolumeProgressCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    final fmt  = NumberFormat('#,##0.00', 'pt_BR');
    final plan = sub.currentPlan;
    final nextPlan = _plans[_nextTier(sub.currentTier)];

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
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Volume negociado acumulado',
                style: TextStyle(fontSize: 12, color: FenixColors.textSecondary)),
            Text('\$${fmt.format(sub.tradedVolume)}',
                style: TextStyle(fontFamily: 'RobotoMono',
                    fontSize: 13, fontWeight: FontWeight.w500,
                    color: plan.color)),
          ]),
          const SizedBox(height: 10),
          _SegmentedVolumeBar(tradedVolume: sub.tradedVolume),
          const SizedBox(height: 8),
          if (nextPlan != null)
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Plano atual: ${plan.name}',
                  style: const TextStyle(fontSize: 10, color: FenixColors.textMuted)),
              Text(
                'Faltam \$${fmt.format(sub.volumeFaltante ?? 0)} para ${nextPlan.name}',
                style: TextStyle(fontSize: 10, color: nextPlan.color),
              ),
            ])
          else
            const Text('Plano Premium atingido — volume máximo',
                style: TextStyle(fontSize: 10, color: FenixColors.yellow)),
        ],
      ),
    );
  }

  PlanTier? _nextTier(PlanTier t) {
    final order = [PlanTier.exempt, PlanTier.basic, PlanTier.pro, PlanTier.premium];
    final idx = order.indexOf(t);
    if (idx < order.length - 1) return order[idx + 1];
    return null;
  }
}

class _SegmentedVolumeBar extends StatelessWidget {
  final double tradedVolume;
  const _SegmentedVolumeBar({required this.tradedVolume});

  static const _thresholds = [0.0, 500.0, 5000.0, 35000.0];
  static const _colors = [
    FenixColors.green, FenixColors.blue, FenixColors.purple, FenixColors.yellow,
  ];
  static const _labels = ['\$0', '\$500', '\$5k', '\$35k'];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        for (int i = 0; i < 4; i++)
          Expanded(
            flex: i == 0 ? 1 : i == 1 ? 2 : i == 2 ? 3 : 4,
            child: Container(
              height: 8,
              margin: EdgeInsets.only(right: i < 3 ? 2 : 0),
              decoration: BoxDecoration(
                color: tradedVolume >= _thresholds[i]
                    ? _colors[i]
                    : _colors[i].withOpacity(.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 4),
      Row(children: [
        for (int i = 0; i < 4; i++)
          Expanded(
            flex: i == 0 ? 1 : i == 1 ? 2 : i == 2 ? 3 : 4,
            child: Text(_labels[i],
                style: TextStyle(fontFamily: 'RobotoMono', fontSize: 8,
                    color: tradedVolume >= _thresholds[i]
                        ? _colors[i]
                        : FenixColors.textMuted)),
          ),
      ]),
    ]);
  }
}

// ── Grid de planos ────────────────────────────────────────────────────────────

class _PlansGrid extends StatelessWidget {
  final _SubState sub;
  const _PlansGrid({required this.sub});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'pt_BR');
    final plans = [
      _plans[PlanTier.exempt]!,
      _plans[PlanTier.basic]!,
      _plans[PlanTier.pro]!,
      _plans[PlanTier.premium]!,
    ];

    return Column(children: [
      for (final plan in plans) ...[
        _PlanCard(
          plan: plan,
          isCurrent: plan.tier == sub.currentTier,
          isPending: plan.tier == sub.pendingTier,
          isReached: sub.tradedVolume >= plan.volumeMin,
          fmt: fmt,
        ),
        const SizedBox(height: 8),
      ],
    ]);
  }
}

class _PlanCard extends StatelessWidget {
  final PlanInfo plan;
  final bool isCurrent, isPending, isReached;
  final NumberFormat fmt;

  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.isPending,
    required this.isReached,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isCurrent
        ? plan.color
        : isPending
            ? plan.color.withOpacity(.5)
            : FenixColors.border;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isCurrent ? plan.colorBg : FenixColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: isCurrent ? 1.5 : 0.5),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: plan.color.withOpacity(.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(_icon(plan.tier), color: plan.color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Plano ${plan.name}',
                  style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: FenixColors.textPrimary)),
              const SizedBox(width: 7),
              if (isCurrent) _PlanBadge(plan: plan, label: 'ATUAL'),
              if (isPending && !isCurrent) _PlanBadge(plan: plan, label: 'PRÓXIMO'),
            ]),
            const SizedBox(height: 2),
            Text(
              plan.priceMonthly == 0 ? 'Gratuito' : '\$${fmt.format(plan.priceMonthly)}/mês',
              style: TextStyle(fontFamily: 'RobotoMono',
                  fontSize: 13, fontWeight: FontWeight.w500, color: plan.color),
            ),
            Text(
              plan.volumeMax == null
                  ? 'Volume ≥ \$${_fmtV(plan.volumeMin)}'
                  : 'Volume \$${_fmtV(plan.volumeMin)} – \$${_fmtV(plan.volumeMax!)}',
              style: const TextStyle(fontSize: 10, color: FenixColors.textMuted),
            ),
          ],
        )),
        Icon(
          isReached ? Icons.check_circle_outline : Icons.lock_outline,
          size: 18,
          color: isReached ? plan.color : FenixColors.textMuted,
        ),
      ]),
    );
  }

  String _fmtV(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
    return v.toStringAsFixed(0);
  }

  IconData _icon(PlanTier t) => switch (t) {
    PlanTier.exempt  => Icons.star_outline,
    PlanTier.basic   => Icons.rocket_launch_outlined,
    PlanTier.pro     => Icons.bolt_outlined,
    PlanTier.premium => Icons.workspace_premium_outlined,
  };
}

// ── Checkout ──────────────────────────────────────────────────────────────────

class _CheckoutCard extends StatefulWidget {
  final _SubState sub;
  final String currency;
  final Function(String) onCurrencyChange;
  const _CheckoutCard({
    required this.sub,
    required this.currency,
    required this.onCurrencyChange,
  });

  @override
  State<_CheckoutCard> createState() => _CheckoutCardState();
}

class _CheckoutCardState extends State<_CheckoutCard> {
  int _secs = 1800;

  @override
  void initState() {
    super.initState();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _secs = (_secs - 1).clamp(0, 1800));
      return _secs > 0;
    });
  }

  String get _countdown {
    final m = _secs ~/ 60;
    final s = _secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.sub.pendingPlan ?? widget.sub.currentPlan;
    final fmt  = NumberFormat('#,##0.00', 'pt_BR');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FenixColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FenixColors.border, width: .5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Renovar plano ${plan.name}',
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: FenixColors.textPrimary)),
            const Spacer(),
            Text('\$${fmt.format(plan.priceMonthly)}/mês',
                style: TextStyle(fontFamily: 'RobotoMono',
                    fontSize: 15, fontWeight: FontWeight.w500,
                    color: plan.color)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _CurrBtn(label: 'USDT',
                selected: widget.currency == 'USDT',
                onTap: () => widget.onCurrencyChange('USDT')),
            const SizedBox(width: 7),
            _CurrBtn(label: 'BTC',
                selected: widget.currency == 'BTC',
                onTap: () => widget.onCurrencyChange('BTC')),
            const Spacer(),
            Row(children: [
              const Icon(Icons.timer_outlined, size: 12, color: FenixColors.textMuted),
              const SizedBox(width: 4),
              const Text('Expira em ',
                  style: TextStyle(fontSize: 11, color: FenixColors.textMuted)),
              Text(_countdown,
                  style: TextStyle(fontFamily: 'RobotoMono',
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: _secs < 300 ? FenixColors.red : FenixColors.orange)),
            ]),
          ]),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: QrImageView(
                data: 'https://fenixday.info/btcpay',
                version: QrVersions.auto,
                size: 90,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FenixColors.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: FenixColors.border, width: .5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.currency == 'USDT'
                            ? 'Endereço USDT (TRC-20)'
                            : 'Endereço BTC',
                        style: const TextStyle(
                            fontSize: 10, color: FenixColors.textMuted),
                      ),
                      const SizedBox(height: 3),
                      const Text('Acesse fenixday.info/btcpay',
                          style: TextStyle(fontFamily: 'RobotoMono',
                              fontSize: 11, color: FenixColors.purple)),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Pagamento único mensal · renovação manual · '
                  'mudança de faixa na próxima renovação',
                  style: TextStyle(
                      fontSize: 10, color: FenixColors.textMuted, height: 1.4),
                ),
              ],
            )),
          ]),
        ],
      ),
    );
  }
}

class _CurrBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CurrBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? FenixColors.yellowBg : FenixColors.bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: selected ? FenixColors.yellow.withOpacity(.4) : FenixColors.border,
          width: .5,
        ),
      ),
      child: Text(label,
          style: TextStyle(fontFamily: 'RobotoMono', fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? FenixColors.yellow : FenixColors.textMuted)),
    ),
  );
}

// ── Histórico ─────────────────────────────────────────────────────────────────

class _RenewalHistory extends StatelessWidget {
  final _SubState sub;
  const _RenewalHistory({required this.sub});

  @override
  Widget build(BuildContext context) {
    // Histórico mock - futuramente integrar com /subscriptions/history
    final history = [
      ('—', 0.0, '—', FenixColors.textMuted),
    ];
    final fmt = NumberFormat('#,##0.00', 'pt_BR');

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
          const Text('Histórico de renovações',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                  color: FenixColors.textMuted, letterSpacing: .4)),
          const SizedBox(height: 10),
          if (sub.currentTier == PlanTier.exempt)
            const Text('Plano isento — sem histórico de pagamentos',
                style: TextStyle(fontSize: 11, color: FenixColors.textMuted))
          else
            const Text('Histórico disponível em breve',
                style: TextStyle(fontSize: 11, color: FenixColors.textMuted)),
        ],
      ),
    );
  }
}

// ── Funcionalidades ───────────────────────────────────────────────────────────

class _FeaturesCard extends StatelessWidget {
  static const _features = [
    'Grids ilimitados com juros compostos',
    'Scanner de IA Top 20 em tempo real',
    'Integração Binance, Bybit e OKX',
    'Notificações Telegram por ciclo fechado',
    'Operação 24/7 com reconexão automática',
    'Paper Trading e Modo Demo',
    'Relatório diário de P&L',
    'Grids de Maior Lucro para copiar',
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: FenixColors.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: FenixColors.border, width: .5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Incluso em todos os planos',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                color: FenixColors.textMuted, letterSpacing: .4)),
        const SizedBox(height: 10),
        ..._features.map((f) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            const Icon(Icons.check_circle_outline, size: 13, color: FenixColors.green),
            const SizedBox(width: 10),
            Text(f, style: const TextStyle(
                fontSize: 12, color: FenixColors.textSecondary)),
          ]),
        )),
      ],
    ),
  );
}

// ── Badge de plano ────────────────────────────────────────────────────────────

class _PlanBadge extends StatelessWidget {
  final PlanInfo plan;
  final String? label;
  const _PlanBadge({required this.plan, this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: plan.color,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label ?? plan.badge,
      style: TextStyle(
          fontFamily: 'RobotoMono', fontSize: 8,
          fontWeight: FontWeight.w700,
          color: plan.tier == PlanTier.premium
              ? const Color(0xFF1A0A00)
              : Colors.white),
    ),
  );
}
