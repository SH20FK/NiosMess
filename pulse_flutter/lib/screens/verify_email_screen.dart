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

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({this.initialEmail, super.key});

  final String? initialEmail;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final TextEditingController _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    HapticFeedback.lightImpact();
    final AuthActionResult result = await ref
        .read(authProvider.notifier)
        .verifyEmail(
          email: _emailController.text.trim(),
          code: _normalizedCode,
        );

    if (!mounted) return;

    if (result.success) {
      HapticService.confirm();
      AppToast.showSuccess(context, result.message ?? context.l10n.verifyEmailDone);
      if (ref.read(authProvider).isAuthenticated) {
        context.go('/setup');
      } else {
        context.go('/login');
      }
    } else {
      HapticService.destructive();
      AppToast.showError(context, result.message ?? context.l10n.verifyEmailDone);
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
                          Icons.mark_email_read_rounded,
                          color: scheme.onPrimaryContainer,
                          size: 32,
                        ),
                      ),
                    ).animate().scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), curve: Curves.easeOutBack, duration: 400.ms),
                    const SizedBox(height: 20),

                    Text(
                      context.l10n.verifyEmailTitle,
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      context.l10n.verifyEmailCodeLabel,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Read-only email container
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
                    const SizedBox(height: 24),

                    // Code preview & hidden text input
                    Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        CodePreview(code: code),
                        TextFormField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textInputAction: TextInputAction.done,
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
                          onFieldSubmitted: (_) {
                            if (!auth.busy) _submit();
                          },
                          validator: (String? value) {
                            if ((value ?? '').replaceAll(RegExp(r'\D'), '').length != 6) {
                              return '';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

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
                                  children: <Widget>[
                                    Icon(Icons.check_circle_outline_rounded, color: scheme.onPrimary, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      context.l10n.verifyEmailSubmit,
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
