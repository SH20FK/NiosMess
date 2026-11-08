import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/bluetooth_mesh_service.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/mesh_preferences.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_codec.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class OrdinaryE2eeSettings extends ConsumerStatefulWidget {
  const OrdinaryE2eeSettings({super.key});
  @override
  ConsumerState<OrdinaryE2eeSettings> createState() =>
      _OrdinaryE2eeSettingsState();
}

class _OrdinaryE2eeSettingsState extends ConsumerState<OrdinaryE2eeSettings> {
  final _restore = TextEditingController();
  final _pair = TextEditingController();
  OrdinaryE2eeService? _service;
  ProviderSubscription<OrdinaryE2eeService?>? _subscription;
  Timer? _poll;
  int _generation = 0;
  bool _busy = false;
  bool _polling = false;
  String? _shownEpoch;
  String? _error;
  String? _recovery;
  String? _pairCode;
  String? _fingerprint;
  String? _contactFingerprint;
  E2eJson? _contact;
  int? _contactId;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual(ordinaryE2eeProvider, (_, next) {
      _bindService(next);
    }, fireImmediately: true);
  }

  void _bindService(OrdinaryE2eeService? service) {
    if (identical(_service, service)) return;
    _service?.removeListener(_identityChanged);
    _poll?.cancel();
    _generation++;
    _service = service;
    _shownEpoch = service?.identityEpoch;
    _busy = false;
    _polling = false;
    _clearDisplayedSecrets();
    _restore.clear();
    _pair.clear();
    service?.addListener(_identityChanged);
    if (service != null) {
      unawaited(
        Future<void>.microtask(() async {
          if (!mounted || !identical(ref.read(ordinaryE2eeProvider), service)) {
            return;
          }
          await _run((service) => service.open());
        }),
      );
    }
  }

  void _clearDisplayedSecrets() {
    _error = null;
    _recovery = null;
    _pairCode = null;
    _fingerprint = null;
    _contactFingerprint = null;
    _contact = null;
    _contactId = null;
  }

  void _identityChanged() {
    if (!mounted) return;
    final epoch = _service?.identityEpoch;
    setState(() {
      if (_shownEpoch != epoch) {
        _shownEpoch = epoch;
        _clearDisplayedSecrets();
        _poll?.cancel();
      }
    });
  }

  bool _current(OrdinaryE2eeService service, int generation) =>
      mounted &&
      generation == _generation &&
      identical(_service, service) &&
      identical(ref.read(ordinaryE2eeProvider), service);

  Future<void> _run<T>(
    Future<T> Function(OrdinaryE2eeService service) action, {
    void Function(OrdinaryE2eeService service, T result)? onSuccess,
    bool allowIdentityChange = false,
  }) async {
    final service = _service;
    if (!mounted || _busy || service == null) return;
    final generation = _generation;
    final beforeEpoch = service.identityEpoch;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await action(service);
      if (!_current(service, generation)) return;
      if (beforeEpoch != service.identityEpoch) {
        ref.invalidate(chatMessagesProvider);
        if (!allowIdentityChange) return;
      }
      setState(() => onSuccess?.call(service, result));
    } catch (_) {
      if (_current(service, generation)) {
        setState(() => _error = context.l10n.settingsE2eeActionFailed);
      }
    } finally {
      if (_current(service, generation)) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final service = _service;
    final generation = _generation;
    if (_busy || service == null) return;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: context.l10n.settingsE2eeResetTitle,
      subtitle: context.l10n.settingsE2eeResetDescription,
      confirmLabel: context.l10n.settingsE2eeResetAction,
      cancelLabel: context.l10n.commonCancel,
      icon: Icons.key_off_rounded,
      destructive: true,
    );
    if (confirmed != true || !_current(service, generation)) return;
    await _run(
      (service) async {
        await service.resetAfterLoss();
        return service.recoveryCode();
      },
      onSuccess: (_, code) => _recovery = code,
      allowIdentityChange: true,
    );
  }

  Future<void> _createPairCode() => _run(
    (service) => service.beginPairing(),
    onSuccess: (service, code) {
      _pairCode = code;
      _poll?.cancel();
      final generation = _generation;
      _poll = Timer.periodic(const Duration(seconds: 3), (_) {
        unawaited(_checkPairing(service, generation));
      });
    },
  );

  Future<void> _checkPairing(
    OrdinaryE2eeService service,
    int generation,
  ) async {
    if (!_current(service, generation) || _busy || _polling) return;
    _polling = true;
    try {
      final complete = await service.completePairing();
      if (!_current(service, generation)) return;
      if (complete) {
        _poll?.cancel();
        setState(() => _pairCode = null);
        ref.invalidate(chatMessagesProvider);
      }
    } catch (_) {
      if (!_current(service, generation)) return;
      _poll?.cancel();
      setState(() {
        _pairCode = null;
        _error = context.l10n.settingsE2eePairExpired;
      });
    } finally {
      if (_current(service, generation)) _polling = false;
    }
  }

  Future<void> _copy(String value) async {
    final service = _service;
    final generation = _generation;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    if (service != null && _current(service, generation)) {
      AppToast.showSuccess(context, context.l10n.settingsE2eeCopyToast);
    }
  }

  @override
  void dispose() {
    _generation++;
    _subscription?.close();
    _service?.removeListener(_identityChanged);
    _poll?.cancel();
    _restore.dispose();
    _pair.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(ordinaryE2eeProvider);
    if (service == null || !identical(service, _service)) {
      return const SizedBox.shrink();
    }
    final meshEnabled = ref.watch(meshPreferenceProvider);
    final mesh = meshPlatformSupported
        ? ref.watch(bluetoothMeshProvider)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          title: context.l10n.settingsE2eeOrdinaryTitle,
          children: [
            SettingsListItem.toggle(
              icon: Icons.enhanced_encryption_outlined,
              title: context.l10n.settingsE2eeEncrypt,
              subtitle: meshPlatformSupported && meshEnabled
                  ? context.l10n.settingsE2eeBluetoothRequired
                  : context.l10n.settingsE2eeModeDescription,
              value: service.enabled,
              onChanged:
                  _busy ||
                      !service.initialised ||
                      (meshPlatformSupported && meshEnabled)
                  ? null
                  : (value) => _run((s) => s.setEnabled(value)),
            ),
            if (service.locked)
              _description(context.l10n.settingsE2eeLockedDescription),
            _explanation(context.l10n.settingsE2eeDeviceDescription),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: AppLoadingIndicator(size: 24)),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: _busy ? null : () => _run((s) => s.open()),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(context.l10n.settingsE2eeReconnect),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (meshPlatformSupported)
          SettingsSection(
            title: context.l10n.settingsE2eeOfflineTitle,
            children: [
              SettingsListItem.toggle(
                icon: Icons.bluetooth_rounded,
                title: context.l10n.settingsE2eeMeshTitle,
                subtitle: context.l10n.settingsE2eeMeshDescription,
                value: meshEnabled,
                onChanged: _busy
                    ? null
                    : (value) => _run((s) async {
                        if (value) await s.setEnabled(true);
                        if (!mounted ||
                            !identical(ref.read(ordinaryE2eeProvider), s)) {
                          return;
                        }
                        await ref
                            .read(meshPreferenceProvider.notifier)
                            .setEnabled(value);
                        if (!mounted ||
                            !identical(ref.read(ordinaryE2eeProvider), s)) {
                          return;
                        }
                        if (value) await mesh?.start(requestPermission: true);
                      }),
              ),
              if (meshEnabled && mesh != null)
                ListenableBuilder(
                  listenable: mesh,
                  builder: (context, _) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _meshStatus(context, mesh),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (mesh.state == 'permission_required' ||
                            mesh.state == 'unavailable')
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(
                                      (_) =>
                                          mesh.start(requestPermission: true),
                                    ),
                              child: Text(
                                context.l10n.settingsE2eeBluetoothPermission,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        if (service.initialised && !service.locked) _recoverySection(service),
        if (service.locked) _restoreSection(),
        if (service.initialised) _pairingSection(service),
        if (service.initialised && !service.locked) _contactSection(),
      ],
    );
  }

  Widget _recoverySection(OrdinaryE2eeService service) => SettingsSection(
    title: context.l10n.settingsE2eeRecoveryTitle,
    children: [
      _description(context.l10n.settingsE2eeRecoveryDescription),
      SettingsListItem(
        icon: _recovery == null
            ? Icons.key_rounded
            : Icons.visibility_off_outlined,
        title: _recovery == null
            ? context.l10n.settingsE2eeShowRecovery
            : context.l10n.settingsE2eeHideRecovery,
        type: SettingsListItemType.action,
        enabled: !_busy,
        onTap: () {
          if (_recovery != null) {
            setState(() => _recovery = null);
          } else {
            _run(
              (s) => s.recoveryCode(),
              onSuccess: (_, code) => _recovery = code,
            );
          }
        },
      ),
      _reveal(
        'recovery',
        _recovery == null
            ? null
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SelectableText(_recovery!),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => _copy(_recovery!),
                          icon: const Icon(Icons.copy_rounded),
                          label: Text(
                            MaterialLocalizations.of(context).copyButtonLabel,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _busy || service.backupAcknowledged
                              ? null
                              : () => _run((s) => s.acknowledgeBackup()),
                          icon: Icon(
                            service.backupAcknowledged
                                ? Icons.check_circle_rounded
                                : Icons.check_rounded,
                          ),
                          label: Text(context.l10n.settingsE2eeBackupSaved),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
      SettingsListItem(
        icon: Icons.fingerprint_rounded,
        title: context.l10n.settingsE2eeOwnFingerprint,
        type: SettingsListItemType.action,
        enabled: !_busy,
        onTap: () => _run(
          (s) => s.ownFingerprint(),
          onSuccess: (_, fp) => _fingerprint = fp,
        ),
      ),
      _reveal(
        'fingerprint',
        _fingerprint == null ? null : _selectable(_fingerprint!),
      ),
    ],
  );

  Widget _restoreSection() => SettingsSection(
    title: context.l10n.settingsE2eeRestoreTitle,
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _restore,
              obscureText: true,
              enabled: !_busy,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: context.l10n.settingsE2eeRecoveryTitle,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () {
                      final code = _restore.text;
                      _run(
                        (s) => s.restore(code),
                        onSuccess: (_, _) => _restore.clear(),
                        allowIdentityChange: true,
                      );
                    },
              child: Text(
                context.l10n.settingsE2eeRestoreAction,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
      SettingsListItem.danger(
        icon: Icons.key_off_rounded,
        title: context.l10n.settingsE2eeLostKeys,
        onTap: _reset,
      ),
    ],
  );

  Widget _pairingSection(OrdinaryE2eeService service) => SettingsSection(
    title: context.l10n.settingsE2eeLinkTitle,
    children: [
      _description(
        service.locked
            ? context.l10n.settingsE2eePairNewDescription
            : context.l10n.settingsE2eePairApproveDescription,
      ),
      if (service.locked) ...[
        SettingsListItem(
          icon: Icons.qr_code_rounded,
          title: context.l10n.settingsE2eePairCodeCreate,
          type: SettingsListItemType.action,
          enabled: !_busy,
          onTap: _createPairCode,
        ),
        _reveal(
          'pair-code',
          _pairCode == null
              ? null
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final scheme = Theme.of(context).colorScheme;
                          return Semantics(
                            label: context.l10n.settingsE2eePairCodeLabel,
                            image: true,
                            child: QrImageView(
                              data: _pairCode!,
                              size: constraints.maxWidth.clamp(0, 210),
                              backgroundColor: scheme.surface,
                              eyeStyle: QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: scheme.onSurface,
                              ),
                              dataModuleStyle: QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: scheme.onSurface,
                              ),
                            ),
                          );
                        },
                      ),
                      TextButton.icon(
                        onPressed: () => _copy(_pairCode!),
                        icon: const Icon(Icons.copy_rounded),
                        label: Text(context.l10n.settingsE2eePairCodeCopy),
                      ),
                    ],
                  ),
                ),
        ),
      ] else
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _pair,
                enabled: !_busy,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: context.l10n.settingsE2eePairCodeLabel,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () {
                        final code = _pair.text;
                        _run(
                          (s) => s.approvePairing(code),
                          onSuccess: (_, _) => _pair.clear(),
                        );
                      },
                child: Text(
                  context.l10n.settingsE2eePairApproveAction,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _contactSection() {
    final chats = ref.watch(chatsProvider).value ?? const [];
    final candidates = chats
        .where((c) => c.chatType == 'direct' && !c.isSecret && !c.isBotChat)
        .toList();
    return SettingsSection(
      title: context.l10n.settingsE2eeContactTitle,
      children: [
        _description(context.l10n.settingsE2eeContactDescription),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<int>(
                key: ValueKey(('contact', _contactId)),
                isExpanded: true,
                initialValue: candidates.any((c) => c.id == _contactId)
                    ? _contactId
                    : null,
                decoration: InputDecoration(
                  labelText: context.l10n.settingsE2eeDirectChat,
                ),
                items: [
                  for (final chat in candidates)
                    DropdownMenuItem(
                      value: chat.id,
                      child: Text(
                        chat.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (id) {
                        if (id == null) return;
                        setState(() {
                          _contactId = id;
                          _contact = null;
                          _contactFingerprint = null;
                        });
                        _run(
                          (s) async {
                            final identity = await s.contactIdentity(id);
                            final fp = await s.fingerprint(identity);
                            return (identity, fp);
                          },
                          onSuccess: (_, result) {
                            _contact = result.$1;
                            _contactFingerprint = result.$2;
                          },
                        );
                      },
              ),
              _reveal(
                'contact-fingerprint',
                _contactFingerprint == null
                    ? null
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          SelectableText(_contactFingerprint!),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: _busy || _contact == null
                                ? null
                                : () {
                                    final contact = _contact!;
                                    _run(
                                      (s) => s.acceptContact(contact),
                                      onSuccess: (_, _) {
                                        ref.invalidate(chatMessagesProvider);
                                      },
                                    );
                                  },
                            child: Text(
                              context.l10n.settingsE2eeAcceptFingerprint,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _description(String text) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _selectable(String text) =>
      Padding(padding: const EdgeInsets.all(16), child: SelectableText(text));

  Widget _explanation(String text) => ExpansionTile(
    title: Text(context.l10n.e2eeHowItWorks),
    leading: const Icon(Icons.info_outline_rounded),
    shape: const Border(),
    collapsedShape: const Border(),
    expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: M3Durations.medium2,
            curve: M3SpringCurves.expressiveStandard,
          ),
    children: [_description(text)],
  );

  Widget _reveal(String key, Widget? child) => AnimatedSize(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : M3Durations.medium2,
    curve: M3SpringCurves.expressiveStandard,
    alignment: Alignment.topCenter,
    child: child == null
        ? const SizedBox.shrink()
        : KeyedSubtree(key: ValueKey(key), child: child),
  );

  String _meshStatus(BuildContext context, BluetoothMeshService mesh) =>
      switch (mesh.state) {
        'active' =>
          mesh.peerCount == 0
              ? context.l10n.settingsE2eeMeshSearching
              : '${context.l10n.settingsE2eeMeshDevices}: ${mesh.peerCount}',
        'permission_required' => context.l10n.settingsE2eeMeshPermission,
        'bluetooth_off' => context.l10n.settingsE2eeMeshOff,
        'unsupported' => context.l10n.settingsE2eeMeshUnsupported,
        'unsupported_peripheral' => context.l10n.settingsE2eeMeshScanOnly,
        'starting' => context.l10n.settingsE2eeMeshStarting,
        'stopped' => context.l10n.settingsE2eeMeshStopped,
        _ => context.l10n.settingsE2eeMeshUnavailable,
      };
}
