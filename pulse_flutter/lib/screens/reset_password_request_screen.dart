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
import 'package:pulse_flutter/widgets/m3_organic_background.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class ResetPasswordRequestScreen extends ConsumerStatefulWidget {
  const ResetPasswordRequestScreen({super.key});

  @override
  ConsumerState<ResetPasswordRequestScreen> createState() =>
      _ResetPasswordRequestScreenState();
}

class _ResetPasswordRequestScreenState
    extends ConsumerState<ResetPasswordRequestScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    HapticFeedback.lightImpact();
    final String email = _emailController.text.trim();
    final AuthActionResult result = await ref
        .read(authProvider.notifier)
        .requestPasswordReset(email: email);

    if (!mounted) {
      return;
    }

    if (result.success) {
      HapticService.confirm();
      AppToast.showSuccess(context, result.message ?? context.l10n.resetPasswordRequestSent);
      context.go('/reset-password/confirm?email=${Uri.encodeComponent(email)}');
    } else {
      HapticService.destructive();
      AppToast.showError(context, result.message ?? context.l10n.resetPasswordRequestSent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

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
                          Icons.lock_reset_rounded,
                          color: scheme.onPrimaryContainer,
                          size: 32,
                        ),
                      ),
                    ).animate().scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), curve: Curves.easeOutBack, duration: 400.ms),
                    const SizedBox(height: 20),

                    Text(
                      context.l10n.resetPasswordRequestTitle,
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      context.l10n.resetPasswordRequestHeroSubtitle,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Email input container
                    Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.25),
                        ),
                      ),
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: context.l10n.resetPasswordRequestEmailLabel,
                          prefixIcon: Icon(Icons.email_outlined, size: 20, color: scheme.primary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        validator: (String? value) {
                          if (!((value ?? '').contains('@'))) {
                            return context.l10n.registerEmailError;
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
                                    Icon(Icons.send_rounded, size: 20, color: scheme.onPrimary),
                                    const SizedBox(width: 8),
                                    Text(
                                      context.l10n.resetPasswordRequestSubmit,
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
