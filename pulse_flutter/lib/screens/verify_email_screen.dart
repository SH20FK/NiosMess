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

    final AuthActionResult result = await ref
        .read(authProvider.notifier)
        .verifyEmail(
          email: _emailController.text.trim(),
          code: _normalizedCode,
        );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? context.l10n.verifyEmailDone)),
    );

    if (result.success) {
      context.go('/setup');
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

    return PopScope(
      canPop: false,
      child: Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.verifyEmailTitle),
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
                              Icons.mark_email_read_rounded,
                              color: scheme.onPrimaryContainer,
                              size: 38,
                            ),
                          ).animate(onPlay: (c) => c.repeat(reverse: true))
                            .shimmer(duration: 2000.ms, color: scheme.primaryContainer)
                            .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 2000.ms, curve: Curves.easeInOut),
                          const SizedBox(height: 24),
                          Text(
                            context.l10n.verifyEmailTitle,
                            textAlign: TextAlign.center,
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            context.l10n.verifyEmailCodeLabel, // Using as subtitle
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
                        labelText: context.l10n.registerEmailLabel,
                        prefixIcon: const Icon(Icons.email_rounded),
                      ),
                      validator: (String? value) {
                        if (!((value ?? '').contains('@'))) {
                          return context.l10n.registerEmailError;
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
                    ).animate().fade(duration: 400.ms, delay: 100.ms).scale(begin: const Offset(0.98, 0.98), end: const Offset(1, 1), delay: 100.ms),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 58,
                      child: FilledButton(
                        onPressed: auth.busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: auth.busy
                            ? AppLoadingIndicator(size: 22, color: Theme.of(context).colorScheme.onPrimary)
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  const Icon(Icons.check_circle_outline_rounded),
                                  const SizedBox(width: 10),
                                  Text(
                                    context.l10n.verifyEmailSubmit,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                      ),
                    ).animate().fade(duration: 400.ms, delay: 300.ms).slideY(begin: 0.1, end: 0, delay: 300.ms),
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
