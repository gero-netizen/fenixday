/// FênixDay — Tela de Login
///
/// Suporta dois métodos de autenticação:
///   1. Login com Google (OAuth2 via google_sign_in)
///   2. E-mail e senha (JWT via FastAPI)
///
/// Após login bem-sucedido, verifica license_status do JWT:
///   • PENDING/EXPIRED → Modo Demo
///   • ACTIVE/LIFETIME → Modo Real

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../theme/fenix_theme.dart';

// ── Provider de autenticação ──────────────────────────────────────────────────

final _authProvider =
    StateNotifierProvider<_AuthNotifier, _AuthState>((ref) => _AuthNotifier());

class _AuthState {
  final bool isLoading;
  final String? error;
  final bool isGoogleLoading;

  const _AuthState({
    this.isLoading = false,
    this.error,
    this.isGoogleLoading = false,
  });

  _AuthState copyWith({
    bool? isLoading, String? error, bool? isGoogleLoading,
  }) => _AuthState(
        isLoading:       isLoading       ?? this.isLoading,
        error:           error,
        isGoogleLoading: isGoogleLoading ?? this.isGoogleLoading,
      );
}

class _AuthNotifier extends StateNotifier<_AuthState> {
  _AuthNotifier() : super(const _AuthState());

  final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  Future<void> signInWithGoogle(BuildContext context) async {
    state = state.copyWith(isGoogleLoading: true);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        state = state.copyWith(isGoogleLoading: false);
        return;
      }
      final auth = await account.authentication;
      // TODO: enviar auth.idToken para POST /api/v1/auth/google
      // e receber JWT + license_status
      state = state.copyWith(isGoogleLoading: false);
    } catch (e) {
      state = state.copyWith(
        isGoogleLoading: false,
        error: 'Falha no login com Google: $e',
      );
    }
  }

  Future<void> signInWithEmail(
      BuildContext context, String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      // TODO: POST /api/v1/auth/login
      await Future.delayed(const Duration(seconds: 1));
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'E-mail ou senha incorretos.',
      );
    }
  }
}

// ── Tela de Login ─────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPassword  = false;
  bool _showEmailForm = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(_authProvider);

    return Scaffold(
      backgroundColor: FenixColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 60),

                // ── Logo ─────────────────────────────────────────────────
                _Logo(),
                const SizedBox(height: 40),

                // ── Card principal ────────────────────────────────────────
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: FenixColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: FenixColors.border, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Entrar na sua conta',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: FenixColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Bem-vindo ao FênixDay. Escolha como deseja entrar.',
                        style: TextStyle(
                          fontSize: 12,
                          color: FenixColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Botão Google ────────────────────────────────────
                      _GoogleSignInButton(
                        isLoading: auth.isGoogleLoading,
                        onTap: () => ref
                            .read(_authProvider.notifier)
                            .signInWithGoogle(context),
                      ),
                      const SizedBox(height: 16),

                      // ── Divisor ─────────────────────────────────────────
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(
                                color: FenixColors.border, thickness: 0.5),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'ou continue com e-mail',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: FenixColors.textMuted),
                            ),
                          ),
                          const Expanded(
                            child: Divider(
                                color: FenixColors.border, thickness: 0.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Formulário e-mail/senha ──────────────────────────
                      AnimatedCrossFade(
                        firstChild: _EmailToggleButton(
                          onTap: () =>
                              setState(() => _showEmailForm = true),
                        ),
                        secondChild: _EmailForm(
                          emailCtrl:    _emailCtrl,
                          passwordCtrl: _passwordCtrl,
                          showPassword: _showPassword,
                          isLoading:    auth.isLoading,
                          onTogglePassword: () =>
                              setState(() => _showPassword = !_showPassword),
                          onLogin: () => ref
                              .read(_authProvider.notifier)
                              .signInWithEmail(context,
                                  _emailCtrl.text, _passwordCtrl.text),
                        ),
                        crossFadeState: _showEmailForm
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 250),
                      ),

                      // ── Erro ─────────────────────────────────────────────
                      if (auth.error != null) ...[
                        const SizedBox(height: 12),
                        _ErrorBanner(message: auth.error!),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Link de cadastro ──────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Não tem conta? ',
                        style: TextStyle(
                            fontSize: 12, color: FenixColors.textMuted)),
                    GestureDetector(
                      onTap: () {
                        // TODO: navegar para RegisterScreen
                      },
                      child: const Text(
                        'Criar conta grátis',
                        style: TextStyle(
                          fontSize: 12,
                          color: FenixColors.yellow,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Modo Demo sem conta ───────────────────────────────────
                GestureDetector(
                  onTap: () {
                    // TODO: entrar em modo demo sem autenticar
                  },
                  child: const Text(
                    'Experimentar em Modo Demo sem conta',
                    style: TextStyle(
                      fontSize: 11,
                      color: FenixColors.textMuted,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // ── Disclaimer LGPD ───────────────────────────────────────
                const _LgpdDisclaimer(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Logo ──────────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: FenixColors.yellowBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: FenixColors.yellow.withOpacity(0.3), width: 0.5),
          ),
          child: const Center(
            child: Text('Fx',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: FenixColors.yellow,
                  fontFamily: 'RobotoMono',
                )),
          ),
        ),
        const SizedBox(height: 14),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Fênix',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: FenixColors.yellow,
                ),
              ),
              TextSpan(
                text: 'Day',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: FenixColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Grid Trading Bot com Inteligência Artificial',
          style: TextStyle(fontSize: 11, color: FenixColors.textMuted),
        ),
      ],
    );
  }
}

// ── Botão Google ──────────────────────────────────────────────────────────────

class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _GoogleSignInButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: FenixColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FenixColors.border, width: 0.5),
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: FenixColors.textMuted),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ícone Google (SVG simplificado via CustomPaint)
                  _GoogleIcon(),
                  const SizedBox(width: 10),
                  const Text(
                    'Continuar com Google',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: FenixColors.textPrimary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18, height: 18,
      child: CustomPaint(painter: _GoogleIconPainter()),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Círculo base
    canvas.drawCircle(c, r,
        Paint()..color = const Color(0xFFEEEEEE));

    // Letras G simplificadas como arco colorido
    final rect = Rect.fromCircle(center: c, radius: r * 0.75);
    canvas.drawArc(rect, -0.5, 2.1, false,
        Paint()
          ..color = const Color(0xFF4285F4)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke);
    canvas.drawArc(rect, 1.6, 1.0, false,
        Paint()
          ..color = const Color(0xFF34A853)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke);
    canvas.drawArc(rect, 2.6, 1.2, false,
        Paint()
          ..color = const Color(0xFFFBBC05)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke);
    canvas.drawArc(rect, 3.8, 1.0, false,
        Paint()
          ..color = const Color(0xFFEA4335)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Botão toggle do formulário de e-mail ──────────────────────────────────────

class _EmailToggleButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EmailToggleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FenixColors.border, width: 0.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline,
                size: 16, color: FenixColors.textMuted),
            SizedBox(width: 8),
            Text(
              'Entrar com e-mail e senha',
              style: TextStyle(
                fontSize: 13,
                color: FenixColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Formulário e-mail/senha ───────────────────────────────────────────────────

class _EmailForm extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool showPassword;
  final bool isLoading;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;

  const _EmailForm({
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.showPassword,
    required this.isLoading,
    required this.onTogglePassword,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // E-mail
        TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(
              fontSize: 13, color: FenixColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'seu@email.com',
            hintStyle: TextStyle(color: FenixColors.textMuted),
            prefixIcon: Icon(Icons.mail_outline,
                size: 16, color: FenixColors.textMuted),
          ),
        ),
        const SizedBox(height: 10),

        // Senha
        TextField(
          controller: passwordCtrl,
          obscureText: !showPassword,
          style: const TextStyle(
              fontSize: 13, color: FenixColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Senha',
            hintStyle:
                const TextStyle(color: FenixColors.textMuted),
            prefixIcon: const Icon(Icons.lock_outline,
                size: 16, color: FenixColors.textMuted),
            suffixIcon: GestureDetector(
              onTap: onTogglePassword,
              child: Icon(
                showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 16,
                color: FenixColors.textMuted,
              ),
            ),
          ),
          onSubmitted: (_) => onLogin(),
        ),
        const SizedBox(height: 6),

        // Esqueci a senha
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {
              // TODO: navegar para ForgotPasswordScreen
            },
            child: const Text(
              'Esqueci minha senha',
              style: TextStyle(
                  fontSize: 11, color: FenixColors.yellow),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Botão entrar
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FenixColors.yellow,
              foregroundColor: const Color(0xFF1A0A00),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: isLoading ? null : onLogin,
            child: isLoading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Color(0xFF1A0A00)),
                  )
                : const Text(
                    'Entrar',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Banner de erro ────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FenixColors.redBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: FenixColors.red.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              size: 14, color: FenixColors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 11, color: FenixColors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Disclaimer LGPD ───────────────────────────────────────────────────────────

class _LgpdDisclaimer extends StatelessWidget {
  const _LgpdDisclaimer();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'Ao entrar, você concorda com nossos Termos de Uso e Política de Privacidade. '
        'Seus dados são protegidos conforme a LGPD (Lei 13.709/2018).',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          color: FenixColors.textMuted,
          height: 1.5,
        ),
      ),
    );
  }
}
