import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/pulse_button.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/animated_mesh_background.dart';

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

    final String identifier = _identifierController.text.trim();
    final String password = _passwordController.text;

    final AuthActionResult result = await ref
        .read(authProvider.notifier)
        .login(identifier: identifier, password: password);

    if (!mounted) {
      return;
    }

    if (result.success) {
      context.go('/main/chats');
      return;
    }

    if (result.requiresTwoFa) {
      context.go('/2fa?identifier=${Uri.encodeComponent(identifier)}');
      return;
    }

    AppToast.showError(context, result.message ?? context.l10n.loginFailed);
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return AnimatedMeshBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenHorizontalPadding,
              vertical: 16,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.18),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      // Branding
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_open_rounded,
                          color: scheme.onPrimaryContainer,
                          size: 36,
                        ),
                      ).animate().fade(duration: 400.ms).scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1, 1),
                        duration: 400.ms,
                        curve: Curves.easeOutBack,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        context.l10n.loginTitle,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ).animate().fade(duration: 400.ms, delay: 100.ms),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.loginSubtitle,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ).animate().fade(duration: 400.ms, delay: 150.ms),
                      const SizedBox(height: 28),

                      // Email/username field
                      TextFormField(
                        controller: _identifierController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: context.l10n.loginIdentifierLabel,
                          prefixIcon: const Icon(Icons.alternate_email_rounded),
                        ),
                        validator: (String? value) {
                          if ((value ?? '').trim().isEmpty) {
                            return context.l10n.loginIdentifierError;
                          }
                          return null;
                        },
                      ).animate().fade(duration: 400.ms, delay: 200.ms),

                      const SizedBox(height: 16),

                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!auth.busy) _submit();
                        },
                        decoration: InputDecoration(
                          labelText: context.l10n.loginPasswordLabel,
                          prefixIcon: const Icon(Icons.lock_rounded),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _hidePassword = !_hidePassword);
                            },
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                        validator: (String? value) {
                          if ((value ?? '').length < 6) {
                            return context.l10n.loginPasswordError;
                          }
                          return null;
                        },
                      ).animate().fade(duration: 400.ms, delay: 250.ms),

                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/reset-password/request'),
                          child: Text(context.l10n.loginForgotPassword),
                        ),
                      ).animate().fade(duration: 400.ms, delay: 300.ms),

                      const SizedBox(height: 8),
                      SizedBox(
                        height: 56,
                        child: FilledButton(
                          onPressed: auth.busy ? null : _submit,
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: auth.busy
                              ? AppLoadingIndicator(size: 22, color: scheme.onPrimary)
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    const Icon(Icons.login_rounded),
                                    const SizedBox(width: 10),
                                    Text(
                                      context.l10n.loginSubmit,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                        ),
                      ).animate().fade(duration: 400.ms, delay: 350.ms).slideY(
                        begin: 0.1,
                        end: 0,
                        duration: 400.ms,
                        delay: 350.ms,
                        curve: Curves.easeOutCubic,
                      ),

                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () => context.push('/register'),
                          child: Text(context.l10n.loginCreateAccount),
                        ),
                      ).animate().fade(duration: 400.ms, delay: 400.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
