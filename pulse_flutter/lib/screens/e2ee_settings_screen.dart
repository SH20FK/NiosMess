import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';
import 'package:pulse_flutter/widgets/settings/ordinary_e2ee_settings.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
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
  bool _loading = true;
  int _generation = 0;
  ProviderSubscription<(int?, String?)>? _accountSubscription;
  bool _hasKey = false;
  String? _fingerprint;
  String? _error;

  @override
  void initState() {
    super.initState();
    _accountSubscription = ref.listenManual(
      authProvider.select((a) => (a.session?.userId, a.session?.accessToken)),
      (_, _) {
        _generation++;
        if (mounted) {
          setState(() {
            _loading = true;
            _hasKey = false;
            _fingerprint = null;
            _error = null;
          });
        }
        _checkKey();
      },
    );
    _checkKey();
  }

  bool _current(int generation) => mounted && generation == _generation;

  @override
  void dispose() {
    _generation++;
    _accountSubscription?.close();
    super.dispose();
  }

  Future<void> _checkKey() async {
    final generation = _generation;
    try {
      final secret = await ref.read(secretChatCoordinatorProvider.future);
      final hasKey = secret != null;
      final fp = secret == null
          ? null
          : base64Decode(secret.engine.edPublicKey)
                .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
                .join();
      if (!_current(generation)) return;
      setState(() {
        _hasKey = hasKey;
        _fingerprint = fp;
        _loading = false;
      });
    } catch (_) {
      if (_current(generation)) {
        setState(() {
          _loading = false;
          _error = context.l10n.secretCreateFailed;
        });
      }
    }
  }

  Future<void> _generateKey() async {
    if (_loading) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!mounted) return;

    try {
      final secret = await ref.read(secretChatCoordinatorProvider.future);
      if (!_current(generation)) return;
      if (secret == null) throw StateError('Secret account unavailable');
      await secret.register();
      if (!_current(generation)) return;
      await _checkKey();
      if (!_current(generation)) return;
      setState(() {
        _hasKey = true;
        _loading = false;
      });
      if (!mounted) return;
      AppToast.showSuccess(context, context.l10n.e2eeKeyGenerated);
    } catch (_) {
      if (!_current(generation)) return;
      setState(() {
        _loading = false;
        _error = context.l10n.secretCreateFailed;
      });
    }
  }

  Future<void> _eraseSecretChats() async {
    if (_loading) return;
    final generation = _generation;
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: context.l10n.e2eeEraseConfirmTitle,
      subtitle: context.l10n.e2eeEraseConfirmBody,
      confirmLabel: context.l10n.e2eeEraseConfirm,
      cancelLabel: context.l10n.commonCancel,
      icon: Icons.delete_sweep_rounded,
      destructive: true,
    );
    if (confirmed != true || !_current(generation)) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    if (!mounted) return;

    try {
      final secret = await ref.read(secretChatCoordinatorProvider.future);
      if (!_current(generation)) return;
      if (secret == null) throw StateError('Secret account unavailable');
      final result = await ref
          .read(authRepositoryProvider)
          .eraseSecret(secret.engine.publicKey);
      if (!_current(generation)) return;
      await SecretChatCoordinator.eraseAccount(secret.userId);
      if (!_current(generation)) return;
      final cache = ref.read(cacheServiceProvider);
      await cache.saveChats(
        cache.getCachedChats().where((chat) => !chat.isSecret).toList(),
      );
      if (!_current(generation)) return;
      ref.invalidate(secretChatCoordinatorProvider);
      ref.invalidate(chatsProvider);
      setState(() {
        _hasKey = false;
        _fingerprint = null;
        _loading = false;
      });
      if (!mounted) return;
      AppToast.showSuccess(
        context,
        context.l10n.e2eeEraseDone(
          result.deletedChatsCount,
          result.deletedFilesCount,
        ),
      );
    } catch (_) {
      if (!_current(generation)) return;
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
        OrdinaryE2eeSettings(key: ObjectKey(ref.watch(ordinaryE2eeProvider))),
        SettingsSection(
          title: context.l10n.e2eeDeviceKey,
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: AppLoadingIndicator(size: 28)),
              )
            else if (!_hasKey)
              SettingsTile(
                icon: Icons.vpn_key_outlined,
                title: context.l10n.e2eeNoKeyPair,
                subtitle: context.l10n.e2eeGenerateKeyPair,
                iconColor: scheme.onSurfaceVariant,
                enabled: !_loading,
                onTap: _generateKey,
              )
            else ...[
              SettingsListItem.value(
                icon: Icons.verified_user_outlined,
                title: context.l10n.e2eeKeyPairReady,
              ),
              if (_fingerprint != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: SelectableText(_fingerprint!),
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
