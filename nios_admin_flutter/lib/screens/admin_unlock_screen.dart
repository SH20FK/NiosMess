import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nios_admin_flutter/core/localization/l10n.dart';
import 'package:nios_admin_flutter/widgets/admin_panel.dart';
import 'package:nios_admin_flutter/widgets/admin_scaffold_body.dart';
import 'package:nios_admin_flutter/providers/admin_session_provider.dart';

class AdminUnlockScreen extends ConsumerStatefulWidget {
  const AdminUnlockScreen({super.key});

  @override
  ConsumerState<AdminUnlockScreen> createState() => _AdminUnlockScreenState();
}

class _AdminUnlockScreenState extends ConsumerState<AdminUnlockScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    await ref
        .read(adminSessionProvider.notifier)
        .unlock(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(adminSessionProvider);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: AdminScaffoldBody(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AdminPanel(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.84),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.admin_panel_settings_rounded,
                        color: scheme.onPrimaryContainer,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.l10n.unlockTitle,
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.unlockSubtitle,
                      style: textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: context.l10n.unlockPassword,
                        prefixIcon: const Icon(Icons.lock_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                        ),
                      ),
                      validator: (String? value) {
                        if ((value ?? '').trim().isEmpty) {
                          return context.l10n.unlockPassword;
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if ((session.error ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer.withValues(alpha: 0.48),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: scheme.error.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              session.error!,
                              style: textTheme.bodyMedium?.copyWith(
                                color: scheme.onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (session.error!.toLowerCase().contains(
                              'dns error',
                            ))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Try switching DNS to 8.8.8.8 / 1.1.1.1 or enable VPN on the device.',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onErrorContainer.withValues(
                                      alpha: 0.82,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: session.busy ? null : _submit,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                          session.busy
                              ? context.l10n.unlockChecking
                              : context.l10n.unlockAction,
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
