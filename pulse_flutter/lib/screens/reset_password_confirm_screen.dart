import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_curves.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/code_preview.dart';

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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? context.l10n.resetPasswordConfirmDone)),
    );

    if (result.success) {
      context.go('/login');
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

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.resetPasswordConfirmTitle),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.screenHorizontalPadding,
                vertical: 24,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.18),
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.password_rounded,
                              color: scheme.onPrimaryContainer,
                              size: 38,
                            ),
                          ).animate(onPlay: (c) => c.repeat(reverse: true))
                            .shimmer(duration: 2000.ms, color: scheme.primaryContainer)
                            .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 2000.ms, curve: Curves.easeInOut),
                          const SizedBox(height: 24),
                          Text(
                            context.l10n.resetPasswordConfirmHeroTitle,
                            textAlign: TextAlign.center,
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            context.l10n.resetPasswordConfirmHeroSubtitle,
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fade(duration: 400.ms).slideY(begin: 0.05, end: 0, curve: AppCurves.easeOutSmooth),
                    const SizedBox(height: 36),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: context.l10n.resetPasswordConfirmEmailLabel,
                        prefixIcon: const Icon(Icons.email_rounded),
                      ),
                      validator: (String? value) {
                        if (!((value ?? '').contains('@'))) {
                          return context.l10n.resetPasswordConfirmEmailError;
                        }
                        return null;
                      },
                    ).animate().fade(duration: 400.ms, delay: 50.ms),
                    const SizedBox(height: 24),
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
                    ).animate().fade(duration: 400.ms, delay: 100.ms).scale(begin: const Offset(0.98, 0.98), end: const Offset(1, 1), delay: 100.ms),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        labelText: context.l10n.resetPasswordConfirmPasswordLabel,
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
                        if ((value ?? '').length < 8) {
                          return context.l10n.resetPasswordConfirmPasswordError;
                        }
                        return null;
                      },
                    ).animate().fade(duration: 400.ms, delay: 150.ms),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 58,
                      child: FilledButton(
                        onPressed: auth.busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: auth.busy
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(year2023: false, strokeWidth: 3, color: Colors.white),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  const Icon(Icons.password_rounded),
                                  const SizedBox(width: 10),
                                  Text(
                                    context.l10n.resetPasswordConfirmSubmit,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                      ),
                    ).animate().fade(duration: 400.ms, delay: 200.ms).slideY(begin: 0.1, end: 0, delay: 200.ms),
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
