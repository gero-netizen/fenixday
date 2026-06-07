/// FênixDay — Tela de Privacidade e LGPD
///
/// Exibida:
///   1. No primeiro cadastro (aceite obrigatório)
///   2. Em Configurações > Privacidade
///
/// Funcionalidades:
///   • Aceite de Termos de Uso e Política de Privacidade
///   • Visualização de dados coletados e suas finalidades
///   • Exportação de dados (JSON)
///   • Revogação do consentimento Telegram
///   • Exclusão completa da conta

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/fenix_theme.dart';

// ── Tela de aceite inicial (onboarding) ───────────────────────────────────────

class ConsentScreen extends ConsumerStatefulWidget {
  final VoidCallback onAccepted;
  const ConsentScreen({super.key, required this.onAccepted});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _acceptedTerms   = false;
  bool _acceptedPrivacy = false;
  bool _isLoading       = false;

  bool get _canProceed => _acceptedTerms && _acceptedPrivacy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FenixColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // Logo
              const Icon(Icons.security_outlined,
                  size: 48, color: FenixColors.yellow),
              const SizedBox(height: 16),
              const Text(
                'Antes de começar',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: FenixColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Leia e aceite nossos documentos para usar o FênixDay.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: FenixColors.textMuted),
              ),
              const SizedBox(height: 32),

              // Card de aceites
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FenixColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: FenixColors.border, width: 0.5),
                ),
                child: Column(
                  children: [
                    _ConsentItem(
                      title: 'Termos de Uso',
                      description:
                          'Condições de uso do serviço, responsabilidades e '
                          'disclaimer de risco financeiro.',
                      linkUrl: 'https://fenixday.com/termos',
                      accepted: _acceptedTerms,
                      onChanged: (v) =>
                          setState(() => _acceptedTerms = v ?? false),
                    ),
                    const Divider(
                        height: 20,
                        thickness: 0.5,
                        color: FenixColors.border),
                    _ConsentItem(
                      title: 'Política de Privacidade',
                      description:
                          'Como coletamos, usamos e protegemos seus dados '
                          'conforme a LGPD (Lei 13.709/2018).',
                      linkUrl: 'https://fenixday.com/privacidade',
                      accepted: _acceptedPrivacy,
                      onChanged: (v) =>
                          setState(() => _acceptedPrivacy = v ?? false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Disclaimer de risco
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FenixColors.orangeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: FenixColors.orange.withOpacity(0.3),
                      width: 0.5),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        size: 16, color: FenixColors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Trading de criptoativos envolve riscos. '
                        'Resultados passados não garantem resultados futuros. '
                        'Opere apenas com capital que pode perder.',
                        style: TextStyle(
                            fontSize: 10,
                            color: FenixColors.orange,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Botão continuar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canProceed
                        ? FenixColors.yellow
                        : FenixColors.border,
                    foregroundColor: _canProceed
                        ? const Color(0xFF1A0A00)
                        : FenixColors.textMuted,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: _canProceed && !_isLoading
                      ? _handleAccept
                      : null,
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Color(0xFF1A0A00)),
                        )
                      : const Text(
                          'Aceitar e continuar',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              const Text(
                'Você pode revogar seu consentimento a qualquer momento '
                'em Configurações > Privacidade.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10, color: FenixColors.textMuted),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAccept() async {
    setState(() => _isLoading = true);
    try {
      // TODO: POST /api/v1/lgpd/consent
      await Future.delayed(const Duration(milliseconds: 500));
      widget.onAccepted();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _ConsentItem extends StatelessWidget {
  final String title;
  final String description;
  final String linkUrl;
  final bool accepted;
  final Function(bool?) onChanged;

  const _ConsentItem({
    required this.title,
    required this.description,
    required this.linkUrl,
    required this.accepted,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: accepted,
          onChanged: onChanged,
          activeColor: FenixColors.yellow,
          side: const BorderSide(
              color: FenixColors.border, width: 0.5),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => launchUrl(Uri.parse(linkUrl)),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: FenixColors.yellow,
                    decoration: TextDecoration.underline,
                    decorationColor: FenixColors.yellow,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(description,
                  style: const TextStyle(
                      fontSize: 11,
                      color: FenixColors.textMuted,
                      height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Tela de configurações de privacidade ──────────────────────────────────────

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState
    extends ConsumerState<PrivacySettingsScreen> {
  bool _exportLoading  = false;
  bool _deleteLoading  = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FenixColors.bg,
      appBar: AppBar(
        title: const Text('Privacidade e Dados'),
        backgroundColor: FenixColors.surface,
        foregroundColor: FenixColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Seus direitos ─────────────────────────────────────────
            _SectionHeader(
              icon: Icons.gavel_outlined,
              title: 'Seus direitos — LGPD',
              subtitle: 'Lei Geral de Proteção de Dados (Lei 13.709/2018)',
            ),
            const SizedBox(height: 10),
            _RightsCard(),
            const SizedBox(height: 16),

            // ── Dados coletados ───────────────────────────────────────
            _SectionHeader(
              icon: Icons.dataset_outlined,
              title: 'Dados armazenados no servidor',
            ),
            const SizedBox(height: 10),
            _DataCollectedCard(),
            const SizedBox(height: 16),

            // ── Ações ─────────────────────────────────────────────────
            _SectionHeader(
              icon: Icons.manage_accounts_outlined,
              title: 'Gerenciar meus dados',
            ),
            const SizedBox(height: 10),

            // Exportar dados
            _ActionTile(
              icon: Icons.download_outlined,
              title: 'Exportar meus dados',
              subtitle: 'Baixe um JSON com todos os seus dados (Art. 18, V)',
              color: FenixColors.blue,
              isLoading: _exportLoading,
              onTap: _exportData,
            ),
            const SizedBox(height: 8),

            // Revogar Telegram
            _ActionTile(
              icon: Icons.notifications_off_outlined,
              title: 'Revogar notificações Telegram',
              subtitle: 'Remove seu Chat ID e para os alertas (Art. 18, IX)',
              color: FenixColors.orange,
              onTap: _revokeTelegram,
            ),
            const SizedBox(height: 8),

            // Links externos
            _ActionTile(
              icon: Icons.open_in_new,
              title: 'Política de Privacidade',
              subtitle: 'fenixday.com/privacidade',
              color: FenixColors.textMuted,
              onTap: () => launchUrl(
                  Uri.parse('https://fenixday.com/privacidade')),
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.open_in_new,
              title: 'Termos de Uso',
              subtitle: 'fenixday.com/termos',
              color: FenixColors.textMuted,
              onTap: () =>
                  launchUrl(Uri.parse('https://fenixday.com/termos')),
            ),

            const SizedBox(height: 20),

            // Zona de perigo
            _DangerZone(
              isLoading: _deleteLoading,
              onDelete: _deleteAccount,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData() async {
    setState(() => _exportLoading = true);
    try {
      // TODO: GET /api/v1/lgpd/export-data → salvar/compartilhar JSON
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dados exportados com sucesso!'),
            backgroundColor: FenixColors.green,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportLoading = false);
    }
  }

  Future<void> _revokeTelegram() async {
    final confirm = await _showConfirmDialog(
      title: 'Revogar notificações Telegram?',
      message: 'Você deixará de receber alertas de ciclos fechados '
          'e relatórios diários no Telegram.',
      confirmLabel: 'Revogar',
      confirmColor: FenixColors.orange,
    );
    if (confirm != true) return;
    // TODO: PUT /api/v1/lgpd/revoke-telegram
  }

  Future<void> _deleteAccount() async {
    final confirm = await _showConfirmDialog(
      title: 'Excluir conta permanentemente?',
      message: 'Esta ação é irreversível. Todos os seus dados no servidor '
          'serão removidos permanentemente.',
      confirmLabel: 'Excluir conta',
      confirmColor: FenixColors.red,
    );
    if (confirm != true) return;

    setState(() => _deleteLoading = true);
    try {
      // TODO: POST /api/v1/lgpd/delete-account
      await Future.delayed(const Duration(seconds: 1));
      // Navegar para login após exclusão
    } finally {
      if (mounted) setState(() => _deleteLoading = false);
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: FenixColors.card,
        title: Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: FenixColors.textPrimary)),
        content: Text(message,
            style: const TextStyle(
                fontSize: 12, color: FenixColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: FenixColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel,
                style: TextStyle(
                    color: confirmColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _SectionHeader(
      {required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: FenixColors.textMuted),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: FenixColors.textMuted,
                    letterSpacing: .4)),
            if (subtitle != null)
              Text(subtitle!,
                  style: const TextStyle(
                      fontSize: 9, color: FenixColors.textMuted)),
          ],
        ),
      ],
    );
  }
}

class _RightsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rights = [
      'Acesso aos seus dados pessoais',
      'Correção de dados incompletos ou incorretos',
      'Eliminação dos dados tratados com consentimento',
      'Portabilidade dos dados (exportação)',
      'Revogação do consentimento a qualquer momento',
      'Informação sobre compartilhamento com terceiros',
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FenixColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FenixColors.border, width: 0.5),
      ),
      child: Column(
        children: rights
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 12, color: FenixColors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(r,
                            style: const TextStyle(
                                fontSize: 11,
                                color: FenixColors.textSecondary)),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _DataCollectedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final data = [
      ('E-mail', 'Autenticação', 'Contrato'),
      ('Telegram Chat ID', 'Notificações', 'Consentimento'),
      ('Pagamentos', 'Assinatura', 'Obrigação legal'),
      ('Volume negociado', 'Isenção', 'Contrato'),
      ('Logs de acesso (IP)', 'Segurança', 'Legítimo interesse'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: FenixColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FenixColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: FenixColors.border, width: 0.5)),
            ),
            child: const Row(
              children: [
                Expanded(
                    flex: 2,
                    child: Text('Dado',
                        style: TextStyle(
                            fontSize: 10,
                            color: FenixColors.textMuted,
                            fontWeight: FontWeight.w500))),
                Expanded(
                    child: Text('Finalidade',
                        style: TextStyle(
                            fontSize: 10,
                            color: FenixColors.textMuted,
                            fontWeight: FontWeight.w500))),
                Expanded(
                    child: Text('Base legal',
                        style: TextStyle(
                            fontSize: 10,
                            color: FenixColors.textMuted,
                            fontWeight: FontWeight.w500))),
              ],
            ),
          ),
          ...data.map((d) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: FenixColors.border, width: 0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                        flex: 2,
                        child: Text(d.$1,
                            style: const TextStyle(
                                fontSize: 11,
                                color: FenixColors.textPrimary))),
                    Expanded(
                        child: Text(d.$2,
                            style: const TextStyle(
                                fontSize: 10,
                                color: FenixColors.textMuted))),
                    Expanded(
                        child: Text(d.$3,
                            style: const TextStyle(
                                fontSize: 10,
                                color: FenixColors.textMuted))),
                  ],
                ),
              )),
          // Nota sobre trades
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: const Row(
              children: [
                Icon(Icons.lock_outline,
                    size: 12, color: FenixColors.green),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Histórico de trades: armazenado APENAS no seu dispositivo. Nunca enviado ao servidor.',
                    style: TextStyle(
                        fontSize: 10,
                        color: FenixColors.green,
                        height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isLoading;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: FenixColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FenixColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: FenixColors.textPrimary)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 10,
                          color: FenixColors.textMuted)),
                ],
              ),
            ),
            isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: FenixColors.textMuted))
                : const Icon(Icons.chevron_right,
                    size: 16, color: FenixColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _DangerZone extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onDelete;
  const _DangerZone({required this.isLoading, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FenixColors.redBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: FenixColors.red.withOpacity(0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_outlined,
                  size: 14, color: FenixColors.red),
              SizedBox(width: 6),
              Text('Zona de perigo',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: FenixColors.red)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'A exclusão da conta é permanente e irreversível. '
            'Todos os dados do servidor serão removidos imediatamente.',
            style: TextStyle(
                fontSize: 11,
                color: FenixColors.textMuted,
                height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: FenixColors.red,
                side: BorderSide(
                    color: FenixColors.red.withOpacity(0.4),
                    width: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.delete_forever_outlined, size: 14),
              label: const Text('Excluir minha conta',
                  style: TextStyle(fontSize: 12)),
              onPressed: isLoading ? null : onDelete,
            ),
          ),
        ],
      ),
    );
  }
}
