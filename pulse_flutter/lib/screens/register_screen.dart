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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _hidePassword = true;
  bool _consentPrivacy = false;
  bool _consentToS = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    if (!_consentPrivacy || !_consentToS) {
      HapticService.destructive();
      AppToast.showError(context, context.l10n.registerConsentRequired);
      return;
    }

    HapticFeedback.lightImpact();
    final AuthActionResult result = await ref
        .read(authProvider.notifier)
        .register(
          displayName: _nameController.text.trim(),
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) {
      return;
    }

    if (result.success) {
      HapticService.confirm();
      context.go(
        '/verify-email?email=${Uri.encodeComponent(_emailController.text.trim())}',
      );
      return;
    }

    HapticService.destructive();
    AppToast.showError(context, result.message ?? context.l10n.registerFailed);
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
                    const SizedBox(height: 16),

                    // ── Stylized Title: "Создать" with M3 Cookie Glyphs ─
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'С',
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
                                Icons.person_add_rounded,
                                size: 16,
                                color: scheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          'здать',
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ).animate().fade(duration: 350.ms).slideY(begin: -0.1, end: 0),
                    const SizedBox(height: 8),

                    Text(
                      context.l10n.registerSubtitle,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ).animate().fade(delay: 100.ms, duration: 350.ms),
                    const SizedBox(height: 32),

                    // ── Display Name ─────────────────────────────────────
                    M3AuthTextField(
                      controller: _nameController,
                      label: context.l10n.registerDisplayNameLabel,
                      prefixIcon: Icons.badge_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (String? value) {
                        if ((value ?? '').trim().isEmpty) {
                          return context.l10n.registerNameRequired;
                        }
                        if (value!.trim().length < 2) {
                          return context.l10n.registerDisplayNameError;
                        }
                        return null;
                      },
                    ).animate().fade(delay: 140.ms, duration: 350.ms),
                    const SizedBox(height: 12),

                    // ── Username ─────────────────────────────────────────
                    M3AuthTextField(
                      controller: _usernameController,
                      label: context.l10n.registerUsernameLabel,
                      prefixIcon: Icons.alternate_email_rounded,
                      textInputAction: TextInputAction.next,
                      validator: (String? value) {
                        if ((value ?? '').trim().isEmpty) {
                          return context.l10n.registerUsernameError;
                        }
                        if (value!.trim().length < 3) {
                          return context.l10n.registerUsernameTooShort;
                        }
                        return null;
                      },
                    ).animate().fade(delay: 180.ms, duration: 350.ms),
                    const SizedBox(height: 12),

                    // ── Email ────────────────────────────────────────────
                    M3AuthTextField(
                      controller: _emailController,
                      label: context.l10n.registerEmailLabel,
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (String? value) {
                        if ((value ?? '').trim().isEmpty || !value!.contains('@')) {
                          return context.l10n.registerEmailError;
                        }
                        return null;
                      },
                    ).animate().fade(delay: 220.ms, duration: 350.ms),
                    const SizedBox(height: 12),

                    // ── Password ─────────────────────────────────────────
                    M3AuthTextField(
                      controller: _passwordController,
                      label: context.l10n.registerPasswordLabel,
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
                        if ((value ?? '').length < 8) {
                          return context.l10n.registerPasswordError;
                        }
                        return null;
                      },
                    ).animate().fade(delay: 260.ms, duration: 350.ms),
                    const SizedBox(height: 20),

                    // ── Consent Checkboxes ───────────────────────────────
                    _ConsentRow(
                      value: _consentToS,
                      onChanged: (val) => setState(() => _consentToS = val ?? false),
                      text: context.l10n.registerConsentToS,
                      linkText: context.l10n.registerConsentReadMore,
                      onLinkTap: () => context.push('/legal/terms'),
                    ),
                    const SizedBox(height: 6),
                    _ConsentRow(
                      value: _consentPrivacy,
                      onChanged: (val) => setState(() => _consentPrivacy = val ?? false),
                      text: context.l10n.registerConsentPrivacy,
                      linkText: context.l10n.registerConsentReadMore,
                      onLinkTap: () => context.push('/legal/privacy'),
                    ),
                    const SizedBox(height: 28),

                    // ── Submit Pill Button: "→ Далее" ────────────────────
                    _M3AuthSubmitButton(
                      label: context.l10n.registerSubmit,
                      isLoading: auth.busy,
                      onTap: _submit,
                    ).animate().fade(delay: 300.ms, duration: 350.ms),
                    const SizedBox(height: 20),

                    // ── Secondary Link ───────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Уже есть аккаунт?',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push('/login');
                          },
                          child: Text(
                            context.l10n.loginTitle,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.value,
    required this.onChanged,
    required this.text,
    required this.linkText,
    required this.onLinkTap,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final String text;
  final String linkText;
  final VoidCallback onLinkTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '$text ',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onLinkTap();
                },
                child: Text(
                  linkText,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
