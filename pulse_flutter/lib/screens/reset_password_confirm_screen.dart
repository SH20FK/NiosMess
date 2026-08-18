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
import 'package:pulse_flutter/widgets/code_preview.dart';
import 'package:pulse_flutter/widgets/m3_organic_background.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class ResetPasswordConfirmScreen extends ConsumerStatefulWidget {
  const ResetPasswordConfirmScreen({this.initialEmail, super.key});

  final String? initialEmail;

  @override
  ConsumerState<ResetPasswordConfirmScreen> createState() =>
      _ResetPasswordConfirmScreenState();
}

class _ResetPasswordConfirmScreenState
    extends ConsumerState<ResetPasswordConfirmScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    HapticFeedback.lightImpact();
    final AuthActionResult result = await ref
        .read(authProvider.notifier)
        .confirmPasswordReset(
          email: _emailController.text.trim(),
          code: _normalizedCode,
          newPassword: _passwordController.text,
        );

    if (!mounted) {
      return;
    }

    if (result.success) {
      HapticService.confirm();
      AppToast.showInfo(context, result.message ?? context.l10n.resetPasswordConfirmDone);
      context.go('/login');
    } else {
      HapticService.destructive();
      AppToast.showError(context, result.message ?? context.l10n.resetPasswordConfirmDone);
    }
  }

  String get _normalizedCode =>
      _codeController.text.replaceAll(RegExp(r'\D'), '');

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String code = _normalizedCode;

    return M3OrganicBackground(
      showBackButton: true,
      showThemeToggle: true,
      onBack: () => context.go('/login'),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.screenHorizontalPadding,
                vertical: 24,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    M3Container(
                      Shapes.c9_sided_cookie,
                      width: 64,
                      height: 64,
                      color: scheme.primaryContainer,
                      child: Center(
                        child: Icon(
                          Icons.password_rounded,
                          color: scheme.onPrimaryContainer,
                          size: 32,
                        ),
                      ),
                    ).animate().scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), curve: Curves.easeOutBack, duration: 400.ms),
                    const SizedBox(height: 20),

                    Text(
                      context.l10n.resetPasswordConfirmTitle,
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      context.l10n.resetPasswordConfirmHeroSubtitle,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Read-only email
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.email_outlined, size: 20, color: scheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _emailController.text,
                              style: textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Code preview & hidden text input
                    Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        CodePreview(code: code),
                        TextFormField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textInputAction: TextInputAction.next,
                          autofillHints: const <String>[AutofillHints.oneTimeCode],
                          cursorColor: Colors.transparent,
                          enableInteractiveSelection: false,
                          style: const TextStyle(color: Colors.transparent, fontSize: 1),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                            fillColor: Colors.transparent,
                          ),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          onChanged: (_) => setState(() {}),
                          validator: (String? value) {
                            if ((value ?? '').replaceAll(RegExp(r'\D'), '').length != 6) {
                              return '';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // New Password input container
                    Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.25),
                        ),
                      ),
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: context.l10n.resetPasswordConfirmPasswordLabel,
                          prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: scheme.primary),
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
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        validator: (String? value) {
                          if ((value ?? '').length < 8) {
                            return context.l10n.registerPasswordError;
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Submit Pill Button
                    Material(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(28),
                      elevation: 0,
                      child: InkWell(
                        onTap: auth.busy ? null : _submit,
                        borderRadius: BorderRadius.circular(28),
                        child: Container(
                          width: double.infinity,
                          height: 54,
                          alignment: Alignment.center,
                          child: auth.busy
                              ? AppLoadingIndicator(size: 22, color: scheme.onPrimary)
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded, size: 20, color: scheme.onPrimary),
                                    const SizedBox(width: 8),
                                    Text(
                                      context.l10n.resetPasswordConfirmSubmit,
                                      style: textTheme.titleSmall?.copyWith(
                                        color: scheme.onPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
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
