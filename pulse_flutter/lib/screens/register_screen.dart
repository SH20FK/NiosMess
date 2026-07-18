import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/animated_mesh_background.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _nameController.dispose();
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
        .register(
          email: _emailController.text.trim(),
          username: _usernameController.text.trim(),
          displayName: _nameController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) {
      return;
    }

    if (result.success) {
      context.go(
        '/verify-email?email=${Uri.encodeComponent(_emailController.text.trim())}',
      );
      return;
    }

    AppToast.showError(context, result.message ?? context.l10n.registerFailed);
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: AnimatedMeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(context.l10n.registerTitle),
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
                            Icons.person_add_rounded,
                            color: scheme.onPrimaryContainer,
                            size: 38,
                          ),
                        ).animate(onPlay: (c) => c.repeat(reverse: true))
                          .shimmer(duration: 2000.ms, color: scheme.primaryContainer)
                          .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 2000.ms, curve: Curves.easeInOut),
                        const SizedBox(height: 24),
                        Text(
                          context.l10n.registerTitle,
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.registerSubtitle,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: context.l10n.profileDisplayName,
                            prefixIcon: const Icon(Icons.person_rounded),
                          ),
                          validator: (String? value) {
                            if ((value ?? '').trim().isEmpty) {
                              return context.l10n.profileDisplayName;
                            }
                            return null;
                          },
                        ).animate().fade(duration: 400.ms),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: context.l10n.profileUsername,
                            prefixIcon: const Icon(Icons.alternate_email_rounded),
                          ),
                          validator: (String? value) {
                            if ((value ?? '').trim().length < 3) {
                              return context.l10n.profileUsername;
                            }
                            return null;
                          },
                        ).animate().fade(duration: 400.ms, delay: 100.ms),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: context.l10n.loginIdentifierLabel,
                            prefixIcon: const Icon(Icons.email_rounded),
                          ),
                          validator: (String? value) {
                            final String val = (value ?? '').trim();
                            if (val.isEmpty || !val.contains('@')) {
                              return context.l10n.loginIdentifierError;
                            }
                            return null;
                          },
                        ).animate().fade(duration: 400.ms, delay: 150.ms),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _hidePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!auth.busy) _submit();
                          },
                          decoration: InputDecoration(
                            labelText: context.l10n.registerPasswordLabel,
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
                              return context.l10n.registerPasswordError;
                            }
                            return null;
                          },
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
                                      const Icon(Icons.app_registration_rounded),
                                      const SizedBox(width: 10),
                                      Text(
                                        context.l10n.registerSubmit,
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
      ),
      ),
    );
  }
}
