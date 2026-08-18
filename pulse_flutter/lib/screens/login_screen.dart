import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/m3_auth_text_field.dart';
import 'package:pulse_flutter/widgets/m3_organic_background.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _hidePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    HapticFeedback.lightImpact();
    final String identifier = _identifierController.text.trim();
    final String password = _passwordController.text;

    final AuthActionResult result = await ref
        .read(authProvider.notifier)
        .login(identifier: identifier, password: password);

    if (!mounted) {
      return;
    }

    if (result.success) {
      HapticService.confirm();
      context.go('/main/chats');
      return;
    }

    if (result.requiresTwoFa) {
      HapticService.tap();
      context.go('/2fa?identifier=${Uri.encodeComponent(identifier)}');
      return;
    }

    HapticService.destructive();
    AppToast.showError(context, result.message ?? context.l10n.loginFailed);
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return M3OrganicBackground(
      showBackButton: true,
      showThemeToggle: true,
      onBack: () {
        if (Navigator.canPop(context)) {
          context.pop();
        } else {
          context.go('/onboarding');
        }
      },
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenHorizontalPadding,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // ── Stylized Title: "Войти" with M3 Cookie Glyphs ──
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'В',
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: M3Container(
                            Shapes.c9_sided_cookie,
                            width: 26,
                            height: 26,
                            color: scheme.primary,
                            child: Center(
                              child: Icon(
                                Icons.person_rounded,
                                size: 16,
                                color: scheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          'йти',
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ).animate().fade(duration: 350.ms).slideY(begin: -0.1, end: 0),
                    const SizedBox(height: 8),

                    Text(
                      context.l10n.loginSubtitle,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ).animate().fade(delay: 100.ms, duration: 350.ms),
                    const SizedBox(height: 36),

                    // ── M3 Input: Username ──────────────────────────────
                    M3AuthTextField(
                      controller: _identifierController,
                      label: 'Имя пользователя',
                      hintText: 'Введите имя пользователя',
                      prefixIcon: Icons.alternate_email_rounded,
                      textInputAction: TextInputAction.next,
                      validator: (String? value) {
                        if ((value ?? '').trim().isEmpty) {
                          return context.l10n.loginIdentifierError;
                        }
                        return null;
                      },
                    ).animate().fade(delay: 150.ms, duration: 350.ms),
                    const SizedBox(height: 14),

                    // ── M3 Input: Password ───────────────────────────────
                    M3AuthTextField(
                      controller: _passwordController,
                      label: context.l10n.loginPasswordLabel,
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _hidePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _hidePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _hidePassword = !_hidePassword);
                        },
                      ),
                      validator: (String? value) {
                        if ((value ?? '').isEmpty) {
                          return context.l10n.loginPasswordError;
                        }
                        return null;
                      },
                    ).animate().fade(delay: 200.ms, duration: 350.ms),
                    const SizedBox(height: 28),

                    // ── Submit Pill Button: "→ Продолжить" ───────────────
                    _M3AuthSubmitButton(
                      label: context.l10n.loginSubmit,
                      isLoading: auth.busy,
                      onTap: _submit,
                    ).animate().fade(delay: 250.ms, duration: 350.ms),
                    const SizedBox(height: 20),

                    // ── Secondary Links ──────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Нет аккаунта?',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push('/register');
                          },
                          child: Text(
                            context.l10n.registerTitle,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.push('/reset-password/request');
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.onSurfaceVariant,
                      ),
                      child: Text(
                        context.l10n.loginForgotPassword,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _M3AuthSubmitButton extends StatelessWidget {
  const _M3AuthSubmitButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(28),
      elevation: 0,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: double.infinity,
          height: 54,
          alignment: Alignment.center,
          child: isLoading
              ? AppLoadingIndicator(
                  size: 24,
                  color: scheme.onPrimary,
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: scheme.onPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
