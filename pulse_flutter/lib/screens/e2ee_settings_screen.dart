import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class E2eeSettingsScreen extends ConsumerStatefulWidget {
  const E2eeSettingsScreen({this.isEmbedded = false, super.key});

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
    try {
      final secret = await ref.read(secretChatCoordinatorProvider.future);
      final hasKey = secret != null;
      final fp = secret == null
          ? null
          : base64Decode(secret.engine.edPublicKey)
                .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
                .join();
      if (!mounted) return;
      setState(() {
        _hasKey = hasKey;
        _fingerprint = fp;
      });
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.secretCreateFailed);
    }
  }

  Future<void> _generateKey() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!mounted) return;

    try {
      final secret = await ref.read(secretChatCoordinatorProvider.future);
      if (secret == null) throw StateError('Secret account unavailable');
      await secret.register();
      await _checkKey();
      if (!mounted) return;
      setState(() {
        _hasKey = true;
        _loading = false;
      });
      AppToast.showSuccess(context, context.l10n.e2eeKeyGenerated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.l10n.secretCreateFailed;
      });
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

    setState(() {
      _loading = true;
      _error = null;
    });
    if (!mounted) return;

    try {
      final secret = await ref.read(secretChatCoordinatorProvider.future);
      if (secret == null) throw StateError('Secret account unavailable');
      final result = await ref
          .read(authRepositoryProvider)
          .eraseSecret(secret.engine.publicKey);
      await SecretChatCoordinator.eraseAccount(secret.userId);
      final cache = ref.read(cacheServiceProvider);
      await cache.saveChats(
        cache.getCachedChats().where((chat) => !chat.isSecret).toList(),
      );
      ref.invalidate(secretChatCoordinatorProvider);
      ref.invalidate(chatsProvider);
      if (!mounted) return;
      setState(() {
        _hasKey = false;
        _fingerprint = null;
        _loading = false;
      });
      AppToast.showSuccess(
        context,
        context.l10n.e2eeEraseDone(
          result.deletedChatsCount,
          result.deletedFilesCount,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.l10n.secretCreateFailed;
      });
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
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: scheme.error, fontSize: 13),
                ),
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
                context.l10n.secretDescription,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
