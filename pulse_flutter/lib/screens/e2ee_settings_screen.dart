import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class E2eeSettingsScreen extends ConsumerStatefulWidget {
  const E2eeSettingsScreen({
    this.isEmbedded = false,
    super.key,
  });

  final bool isEmbedded;

  @override
  ConsumerState<E2eeSettingsScreen> createState() => _E2eeSettingsScreenState();
}

class _E2eeSettingsScreenState extends ConsumerState<E2eeSettingsScreen> {
  bool _loading = false;
  bool _hasKey = false;
  String? _fingerprint;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkKey();
  }

  Future<void> _checkKey() async {
    final e2ee = ref.read(e2eeServiceProvider);
    final hasKey = await e2ee.hasKeyPair();
    String? fp;
    if (hasKey) {
      try {
        fp = await e2ee.getDeviceFingerprint();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _hasKey = hasKey;
      _fingerprint = fp;
    });
  }

  Future<void> _generateKey() async {
    setState(() { _loading = true; _error = null; });
    if (!mounted) return;

    try {
      final e2ee = ref.read(e2eeServiceProvider);
      final publicKeyB64 = await e2ee.getPublicKeyBase64();
      await ref.read(authRepositoryProvider).setPublicKey(publicKeyB64);
      final fp = await e2ee.getDeviceFingerprint();
      if (!mounted) return;
      setState(() {
        _hasKey = true;
        _fingerprint = fp;
        _loading = false;
      });
      AppToast.showSuccess(context, context.l10n.e2eeKeyGenerated);
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  Future<void> _rotateKey() async {
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: context.l10n.e2eeRotateConfirmTitle,
      subtitle: context.l10n.e2eeRotateConfirmBody,
      confirmLabel: context.l10n.e2eeRotateConfirm,
      cancelLabel: context.l10n.commonCancel,
      icon: Icons.refresh_rounded,
    );
    if (confirmed != true) return;

    setState(() { _loading = true; _error = null; });
    if (!mounted) return;

    try {
      final e2ee = ref.read(e2eeServiceProvider);
      await e2ee.deleteKeyPair();
      final publicKeyB64 = await e2ee.getPublicKeyBase64();
      await ref.read(authRepositoryProvider).setPublicKey(publicKeyB64);
      final fp = await e2ee.getDeviceFingerprint();
      if (!mounted) return;
      setState(() {
        _fingerprint = fp;
        _loading = false;
      });
      AppToast.showSuccess(context, context.l10n.e2eeKeyRotated);
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  Future<void> _eraseSecretChats() async {
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: context.l10n.e2eeEraseConfirmTitle,
      subtitle: context.l10n.e2eeEraseConfirmBody,
      confirmLabel: context.l10n.e2eeEraseConfirm,
      cancelLabel: context.l10n.commonCancel,
      icon: Icons.delete_sweep_rounded,
      destructive: true,
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
      setState(() { _hasKey = false; _fingerprint = null; _loading = false; });
      AppToast.showSuccess(context, context.l10n.e2eeEraseDone(result.deletedChatsCount, result.deletedFilesCount));
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SettingsShell(
      title: context.l10n.e2eeScreenTitle,
      isEmbedded: widget.isEmbedded,
      children: [
        SettingsNavBanner(
          illustrationCategory: SettingsIllustrationCategory.e2ee,
          subtitle: context.l10n.e2eeBannerSubtitle,
          iconColor: scheme.tertiary,
        ),
        SettingsSection(
          title: context.l10n.e2eeDeviceKey,
          children: [
            if (!_hasKey)
              SettingsTile(
                icon: Icons.vpn_key_outlined,
                title: context.l10n.e2eeNoKeyPair,
                subtitle: context.l10n.e2eeGenerateKeyPair,
                iconColor: scheme.onSurfaceVariant,
                enabled: !_loading,
                onTap: _generateKey,
              )
            else ...[
              SettingsTile(
                icon: Icons.vpn_key_rounded,
                title: context.l10n.e2eeKeyPairReady,
                subtitle: _fingerprint != null
                    ? _fingerprint!
                    : context.l10n.e2eeKeyPairReady,
                iconColor: scheme.tertiary,
                enabled: false,
                onTap: () {},
              ),
              SettingsTile(
                icon: Icons.refresh_rounded,
                title: context.l10n.e2eeRotateKey,
                subtitle: context.l10n.e2eeRotateKeySubtitle,
                iconColor: scheme.secondary,
                enabled: !_loading,
                onTap: _rotateKey,
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
              ),
          ],
        ),
        if (_hasKey)
          SettingsSection(
            title: context.l10n.profileDangerZone,
            children: [
              SettingsTile(
                icon: Icons.delete_sweep_rounded,
                title: context.l10n.e2eeEraseTitle,
                subtitle: context.l10n.e2eeEraseSubtitle,
                iconColor: scheme.error,
                enabled: !_loading,
                onTap: _eraseSecretChats,
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
