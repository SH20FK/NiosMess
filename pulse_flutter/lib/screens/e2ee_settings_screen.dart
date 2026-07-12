import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class E2eeSettingsScreen extends ConsumerStatefulWidget {
  const E2eeSettingsScreen({super.key});

  @override
  ConsumerState<E2eeSettingsScreen> createState() => _E2eeSettingsScreenState();
}

class _E2eeSettingsScreenState extends ConsumerState<E2eeSettingsScreen> {
  bool _loading = false;
  bool _hasKey = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkKey();
  }

  Future<void> _checkKey() async {
    final e2ee = ref.read(e2eeServiceProvider);
    final hasKey = await e2ee.hasKeyPair();
    if (!mounted) return;
    setState(() => _hasKey = hasKey);
  }

  Future<void> _generateKey() async {
    setState(() { _loading = true; _error = null; });
    if (!mounted) return;

    try {
      final e2ee = ref.read(e2eeServiceProvider);
      final publicKeyB64 = await e2ee.getPublicKeyBase64();
      await ref.read(authRepositoryProvider).setPublicKey(publicKeyB64);
      if (!mounted) return;
      setState(() { _hasKey = true; _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.e2eeKeyGenerated)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  Future<void> _rotateKey() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(context.l10n.e2eeRotateConfirmTitle),
        content: Text(context.l10n.e2eeRotateConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.e2eeRotateConfirm,
                style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() { _loading = true; _error = null; });
    if (!mounted) return;

    try {
      final e2ee = ref.read(e2eeServiceProvider);
      await e2ee.deleteKeyPair();
      final publicKeyB64 = await e2ee.getPublicKeyBase64();
      await ref.read(authRepositoryProvider).setPublicKey(publicKeyB64);
      if (!mounted) return;
      setState(() { _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.e2eeKeyRotated)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  Future<void> _eraseSecretChats() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(context.l10n.e2eeEraseConfirmTitle),
        content: Text(context.l10n.e2eeEraseConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.e2eeEraseConfirm,
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() { _loading = true; _error = null; });
    if (!mounted) return;

    try {
      final e2ee = ref.read(e2eeServiceProvider);
      final publicKeyB64 = await e2ee.getPublicKeyBase64();
      final result = await ref.read(authRepositoryProvider).eraseSecret(publicKeyB64);
      await e2ee.deleteKeyPair();
      if (!mounted) return;
      setState(() { _hasKey = false; _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.e2eeEraseDone(result.deletedChatsCount, result.deletedFilesCount),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SettingsScaffold(
      title: context.l10n.e2eeScreenTitle,
      children: [
        SettingsNavBanner(
          icon: Icons.lock_rounded,
          title: context.l10n.e2eeBannerTitle,
          subtitle: context.l10n.e2eeBannerSubtitle,
          iconColor: Colors.green,
        ),
        SettingsSection(
          title: context.l10n.e2eeDeviceKey,
          children: [
            SettingsTile(
              icon: _hasKey ? Icons.vpn_key_rounded : Icons.vpn_key_outlined,
              title: _hasKey ? context.l10n.e2eeKeyPairReady : context.l10n.e2eeNoKeyPair,
              subtitle: _hasKey ? context.l10n.e2eeTapToRegenerate : context.l10n.e2eeGenerateKeyPair,
              iconColor: _hasKey ? Colors.green : scheme.onSurfaceVariant,
              onTap: _loading || _hasKey ? () {} : () { _generateKey(); },
            ),
            if (_hasKey)
              SettingsTile(
                icon: Icons.refresh_rounded,
                title: context.l10n.e2eeRotateKey,
                subtitle: context.l10n.e2eeRotateKeySubtitle,
                iconColor: Colors.orange,
                onTap: _loading ? () {} : () { _rotateKey(); },
              ),
            if (_hasKey)
              SettingsTile(
                icon: Icons.delete_sweep_rounded,
                title: context.l10n.e2eeEraseTitle,
                subtitle: context.l10n.e2eeEraseSubtitle,
                iconColor: Colors.red,
                onTap: _loading ? () {} : () { _eraseSecretChats(); },
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
              ),
          ],
        ),
        SettingsSection(
          title: context.l10n.e2eeHowItWorks,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text(
                context.l10n.e2eeHowItWorksDesc,
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
