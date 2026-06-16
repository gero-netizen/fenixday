/// FênixDay — Painel do Cliente
/// Alterar senha, configurar Telegram, excluir conta
/// NÃO aparece para superuser

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import '../theme/fenix_theme.dart';

const _baseUrl = 'https://fenixday.info/api/v1';

Future<Map<String, String>> _authHeader() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('access_token') ?? '';
  return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
}

// ── Provider de perfil ────────────────────────────────────────────────────────

class _ProfileData {
  final String email, plan, licenseStatus;
  final String? telegramChatId;
  final bool isGoogle;
  const _ProfileData({
    required this.email, required this.plan,
    required this.licenseStatus, this.telegramChatId,
    required this.isGoogle,
  });
}

final _profileProvider = FutureProvider<_ProfileData>((ref) async {
  final headers = await _authHeader();
  final r = await http.get(Uri.parse('$_baseUrl/auth/profile'), headers: headers);
  if (r.statusCode != 200) throw Exception('Erro ao carregar perfil');
  final d = jsonDecode(r.body);
  return _ProfileData(
    email:          d['email'] ?? '',
    plan:           d['plan']  ?? 'exempt',
    licenseStatus:  d['license_status']?.toString() ?? 'pending',
    telegramChatId: d['telegram_chat_id'],
    isGoogle:       d['google_id'] != null,
  );
});

// ── Tela principal ────────────────────────────────────────────────────────────

class ClientProfileScreen extends ConsumerWidget {
  const ClientProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(_profileProvider);

    return Scaffold(
      backgroundColor: FenixColors.bg,
      appBar: AppBar(
        title: const Text('Minha Conta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: FenixColors.textMuted),
          onPressed: () => context.pop(),
        ),
      ),
      body: asyncProfile.when(
        loading: () => const Center(child: CircularProgressIndicator(color: FenixColors.yellow)),
        error:   (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: FenixColors.red))),
        data:    (profile) => _buildContent(context, ref, profile),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, _ProfileData profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Avatar + email
        Center(child: Column(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: FenixColors.yellowBg,
              shape: BoxShape.circle,
              border: Border.all(color: FenixColors.yellow.withOpacity(.3)),
            ),
            child: Center(child: Text(
              profile.email[0].toUpperCase(),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600,
                  color: FenixColors.yellow, fontFamily: 'RobotoMono'),
            )),
          ),
          const SizedBox(height: 10),
          Text(profile.email, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: FenixColors.textPrimary)),
          const SizedBox(height: 4),
          _PlanBadge(plan: profile.plan, status: profile.licenseStatus),
        ])),

        const SizedBox(height: 24),

        // Seção Telegram
        _SectionTitle('Notificações Telegram'),
        const SizedBox(height: 8),
        _TelegramSection(current: profile.telegramChatId, onSaved: () => ref.refresh(_profileProvider)),

        const SizedBox(height: 20),

        // Seção Senha
        if (!profile.isGoogle) ...[
          _SectionTitle('Segurança'),
          const SizedBox(height: 8),
          _ChangePasswordSection(),
          const SizedBox(height: 20),
        ],

        // Seção Excluir conta
        _SectionTitle('Zona de perigo'),
        const SizedBox(height: 8),
        _DeleteAccountSection(email: profile.email),
      ]),
    );
  }
}

// ── Badge de plano ────────────────────────────────────────────────────────────

class _PlanBadge extends StatelessWidget {
  final String plan, status;
  const _PlanBadge({required this.plan, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (plan) {
      'premium' => (FenixColors.yellow,  'Premium'),
      'pro'     => (FenixColors.purple,  'Pro'),
      'basic'   => (FenixColors.blue,    'Basic'),
      _         => (FenixColors.green,   'Isento'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Telegram ──────────────────────────────────────────────────────────────────

class _TelegramSection extends StatefulWidget {
  final String? current;
  final VoidCallback onSaved;
  const _TelegramSection({this.current, required this.onSaved});

  @override
  State<_TelegramSection> createState() => _TelegramSectionState();
}

class _TelegramSectionState extends State<_TelegramSection> {
  late final TextEditingController _ctrl;
  bool _loading = false;
  String? _msg;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.current ?? '');
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() { _loading = true; _msg = null; });
    final headers = await _authHeader();
    final r = await http.patch(
      Uri.parse('$_baseUrl/auth/profile'),
      headers: headers,
      body: jsonEncode({'telegram_chat_id': _ctrl.text.trim().isEmpty ? null : _ctrl.text.trim()}),
    );
    setState(() {
      _loading = false;
      _success = r.statusCode == 200;
      _msg = _success ? 'Telegram salvo!' : 'Erro ao salvar.';
    });
    if (_success) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: _cardDeco(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Chat ID do Telegram',
          style: TextStyle(fontSize: 11, color: FenixColors.textMuted)),
      const SizedBox(height: 4),
      TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 13, color: FenixColors.textPrimary),
        decoration: const InputDecoration(
          hintText: 'Ex: 123456789',
          hintStyle: TextStyle(color: FenixColors.textMuted),
          prefixIcon: Icon(Icons.telegram, size: 18, color: Color(0xFF0088CC)),
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Para obter seu Chat ID, envie /start para @FenixDayBot no Telegram.',
        style: TextStyle(fontSize: 10, color: FenixColors.textMuted),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0088CC),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          icon: _loading
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
              : const Icon(Icons.save_outlined, size: 16),
          label: Text(_loading ? 'Salvando...' : 'Salvar Telegram'),
          onPressed: _loading ? null : _save,
        ),
      ),
      if (_msg != null) ...[
        const SizedBox(height: 8),
        _FeedbackBanner(msg: _msg!, success: _success),
      ],
    ]),
  );
}

// ── Alterar senha ─────────────────────────────────────────────────────────────

class _ChangePasswordSection extends StatefulWidget {
  @override
  State<_ChangePasswordSection> createState() => _ChangePasswordSectionState();
}

class _ChangePasswordSectionState extends State<_ChangePasswordSection> {
  final _currentCtrl = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false, _showCurrent = false, _showNew = false;
  String? _msg;
  bool _success = false;

  @override
  void dispose() {
    _currentCtrl.dispose(); _newCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() { _msg = 'As senhas não coincidem.'; _success = false; });
      return;
    }
    if (_newCtrl.text.length < 6) {
      setState(() { _msg = 'Senha deve ter ao menos 6 caracteres.'; _success = false; });
      return;
    }
    setState(() { _loading = true; _msg = null; });
    final headers = await _authHeader();
    final r = await http.post(
      Uri.parse('$_baseUrl/auth/change-password2'),
      headers: headers,
      body: jsonEncode({
        'current_password': _currentCtrl.text,
        'new_password':     _newCtrl.text,
      }),
    );
    setState(() {
      _loading = false;
      _success = r.statusCode == 204;
      _msg = _success
          ? 'Senha alterada com sucesso!'
          : jsonDecode(r.body)['detail'] ?? 'Erro ao alterar senha.';
      if (_success) { _currentCtrl.clear(); _newCtrl.clear(); _confirmCtrl.clear(); }
    });
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: _cardDeco(),
    child: Column(children: [
      _PassField('Senha atual',  _currentCtrl, _showCurrent,
          () => setState(() => _showCurrent = !_showCurrent)),
      const SizedBox(height: 10),
      _PassField('Nova senha',   _newCtrl, _showNew,
          () => setState(() => _showNew = !_showNew)),
      const SizedBox(height: 10),
      _PassField('Confirmar nova senha', _confirmCtrl, false, null),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: FenixColors.yellow,
            foregroundColor: const Color(0xFF1A0A00),
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          icon: _loading
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5))
              : const Icon(Icons.lock_reset, size: 16),
          label: Text(_loading ? 'Alterando...' : 'Alterar senha'),
          onPressed: _loading ? null : _change,
        ),
      ),
      if (_msg != null) ...[
        const SizedBox(height: 8),
        _FeedbackBanner(msg: _msg!, success: _success),
      ],
    ]),
  );
}

Widget _PassField(String label, TextEditingController ctrl, bool show, VoidCallback? toggle) =>
    TextField(
      controller: ctrl,
      obscureText: !show,
      style: const TextStyle(fontSize: 13, color: FenixColors.textPrimary),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: const TextStyle(color: FenixColors.textMuted),
        prefixIcon: const Icon(Icons.lock_outline, size: 16, color: FenixColors.textMuted),
        suffixIcon: toggle != null ? GestureDetector(
          onTap: toggle,
          child: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 16, color: FenixColors.textMuted),
        ) : null,
      ),
    );

// ── Excluir conta ─────────────────────────────────────────────────────────────

class _DeleteAccountSection extends StatefulWidget {
  final String email;
  const _DeleteAccountSection({required this.email});

  @override
  State<_DeleteAccountSection> createState() => _DeleteAccountSectionState();
}

class _DeleteAccountSectionState extends State<_DeleteAccountSection> {
  bool _loading = false;

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: FenixColors.card,
        title: const Text('Excluir conta',
            style: TextStyle(color: FenixColors.red, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'Esta ação é irreversível. Todos os seus dados serão removidos permanentemente.',
            style: TextStyle(color: FenixColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Text('Conta: ${widget.email}',
              style: const TextStyle(color: FenixColors.textMuted, fontSize: 11)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: FenixColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: FenixColors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;
    setState(() => _loading = true);

    final headers = await _authHeader();
    final r = await http.post(
      Uri.parse('$_baseUrl/lgpd/delete-account'),
      headers: headers,
      body: jsonEncode({'confirmation': 'CONFIRMO EXCLUSÃO', 'reason': 'Solicitação do usuário'}),
    );

    if (!context.mounted) return;
    if (r.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      context.go('/login');
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(jsonDecode(r.body)['detail'] ?? 'Erro ao excluir conta.'),
        backgroundColor: FenixColors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: FenixColors.card,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: FenixColors.red.withOpacity(.3)),
    ),
    child: Row(children: [
      const Icon(Icons.warning_amber_outlined, color: FenixColors.red, size: 20),
      const SizedBox(width: 12),
      const Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Excluir minha conta',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                  color: FenixColors.red)),
          Text('Remove todos os dados permanentemente (LGPD)',
              style: TextStyle(fontSize: 10, color: FenixColors.textMuted)),
        ],
      )),
      _loading
          ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: FenixColors.red))
          : TextButton(
              onPressed: () => _delete(context),
              child: const Text('Excluir',
                  style: TextStyle(color: FenixColors.red, fontSize: 12)),
            ),
    ]),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

BoxDecoration _cardDeco() => BoxDecoration(
  color: FenixColors.card,
  borderRadius: BorderRadius.circular(8),
  border: Border.all(color: FenixColors.border, width: .5),
);

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
          color: FenixColors.textMuted, letterSpacing: .3));
}

class _FeedbackBanner extends StatelessWidget {
  final String msg;
  final bool success;
  const _FeedbackBanner({required this.msg, required this.success});
  @override
  Widget build(BuildContext context) {
    final color = success ? FenixColors.green : FenixColors.red;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(.3)),
      ),
      child: Row(children: [
        Icon(success ? Icons.check_circle_outline : Icons.error_outline,
            size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: TextStyle(fontSize: 11, color: color))),
      ]),
    );
  }
}
