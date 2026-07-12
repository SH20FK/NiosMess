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
import 'package:pulse_flutter/widgets/animated_mesh_background.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class TwoFaScreen extends ConsumerStatefulWidget {
  const TwoFaScreen({this.initialIdentifier, super.key});

  final String? initialIdentifier;

  @override
  ConsumerState<TwoFaScreen> createState() => _TwoFaScreenState();
}

class _TwoFaScreenState extends ConsumerState<TwoFaScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final String? identifier = widget.initialIdentifier;
    if (identifier != null && identifier.isNotEmpty) {
      ref.read(authProvider.notifier).setPendingIdentifier(identifier);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final AuthActionResult result = await ref
        .read(authProvider.notifier)
        .verifyTwoFa(code: _normalizedCode);

    if (!mounted) {
      return;
    }

    if (result.success) {
      context.go('/main/chats');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(result.message ?? context.l10n.twoFaFailed),
      ),
    );
  }

  String get _normalizedCode =>
      _codeController.text.replaceAll(RegExp(r'\D'), '');

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String code = _normalizedCode;

    return AnimatedMeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(context.l10n.twoFaTitle),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(26),
                              ),
                              child: Icon(
                                Icons.enhanced_encryption_rounded,
                                color: scheme.primary,
                                size: 38,
                              ),
                            ).animate(onPlay: (c) => c.repeat(reverse: true))
                              .shimmer(duration: 2000.ms, color: scheme.primaryContainer)
                              .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 2000.ms, curve: Curves.easeInOut),
                            const SizedBox(height: 24),
                            Text(
                              context.l10n.twoFaHeroTitle,
                              textAlign: TextAlign.center,
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              context.l10n.twoFaHeroSubtitle,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.info_outline_rounded,
                              color: scheme.primary.withValues(alpha: 0.8),
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                context.l10n.twoFaHint,
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fade(duration: 400.ms, delay: 200.ms),
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
                                    const Icon(Icons.lock_open_rounded),
                                    const SizedBox(width: 10),
                                    Text(
                                      context.l10n.twoFaVerify,
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
