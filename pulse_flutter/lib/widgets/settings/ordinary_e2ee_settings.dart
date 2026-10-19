import 'package:pulse_flutter/services/bluetooth_mesh/bluetooth_mesh_service.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/mesh_preferences.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_codec.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';

class OrdinaryE2eeSettings extends ConsumerStatefulWidget {
  const OrdinaryE2eeSettings({super.key});
  @override
  ConsumerState<OrdinaryE2eeSettings> createState() =>
      _OrdinaryE2eeSettingsState();
}

class _OrdinaryE2eeSettingsState extends ConsumerState<OrdinaryE2eeSettings> {
  String? _shownEpoch;
  bool _busy = false;
  String? _error, _recovery, _pairCode, _fingerprint, _contactFingerprint;
  final _restore = TextEditingController(), _pair = TextEditingController();
  Timer? _poll;
  E2eJson? _contact;
  int? _contactId;
  @override
  void initState() {
    super.initState();
    unawaited(
      _run(() async {
        await ref.read(ordinaryE2eeProvider)?.open();
      }),
    );
  }

  @override
  void dispose() {
    _restore.dispose();
    _pair.dispose();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final beforeEpoch = ref.read(ordinaryE2eeProvider)?.identityEpoch;
    try {
      await action();
      if (mounted &&
          beforeEpoch != ref.read(ordinaryE2eeProvider)?.identityEpoch) {
        ref.invalidate(chatMessagesProvider);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Не удалось выполнить действие. Проверьте подключение, аккаунт и введённый код. Для сброса нужен новый вход в NiosID не старше 15 минут.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset(OrdinaryE2eeService service) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Начать с новыми ключами?',
      subtitle:
          'Старая зашифрованная история не восстановится без прежних ключей. Другие устройства будут отключены от аккаунта. Собеседникам понадобится проверить новый отпечаток.',
      confirmLabel: 'Создать новые ключи',
      cancelLabel: 'Отмена',
      destructive: true,
    );
    if (confirmed == true) {
      await _run(() async {
        await service.resetAfterLoss();
        _recovery = await service.recoveryCode();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(ordinaryE2eeProvider);
    if (service == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final meshEnabled = ref.watch(meshPreferenceProvider);
    final mesh = meshPlatformSupported
        ? ref.watch(bluetoothMeshProvider)
        : null;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (_shownEpoch != service.identityEpoch) {
          _shownEpoch = service.identityEpoch;
          _recovery = null;
          _fingerprint = null;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsSection(
              title: 'Личные чаты · тестирование E2E',
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Шифровать'),

                  subtitle: meshPlatformSupported && meshEnabled
                      ? const Text('Для передачи по Bluetooth нужно E2E')
                      : null,
                  value: service.enabled,
                  onChanged:
                      _busy ||
                          !service.initialised ||
                          (meshPlatformSupported && meshEnabled)
                      ? null
                      : (value) => _run(() => service.setEnabled(value)),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'Новые сообщения и файлы шифруются до отправки. Открытый режим возможен, только если оба собеседника отключили E2E.',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    service.locked
                        ? 'Это устройство ещё не подключено. Восстановите ключи или передайте их с другого устройства.'
                        : 'Подключённые устройства получают историю независимо друг от друга. Старые сообщения, группы и боты сохраняют прежний режим. При явном вызове @ai текст запроса передаётся NiosAI; история и ключи файлов не передаются. При утечке постоянного ключа может стать доступна старая зашифрованная история.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (_error != null)
                  TextButton(
                    onPressed: _busy ? null : () => _run(service.open),
                    child: const Text('Повторить подключение'),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
            if (meshPlatformSupported)
              SettingsSection(
                title: 'Без интернета',
                children: [
                  _MeshSwitch(
                    value: meshEnabled,
                    onChanged: _busy
                        ? null
                        : (value) => _run(() async {
                            if (value) await service.setEnabled(true);
                            await ref
                                .read(meshPreferenceProvider.notifier)
                                .setEnabled(value);
                            if (value) {
                              await mesh?.start(requestPermission: true);
                            }
                          }),
                  ),
                  if (meshEnabled && mesh != null)
                    ListenableBuilder(
                      listenable: mesh,
                      builder: (context, _) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mesh.stateText,
                              style: theme.textTheme.bodySmall,
                            ),
                            if (mesh.state == 'permission_required' ||
                                mesh.state == 'unavailable')
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run(
                                        () =>
                                            mesh.start(requestPermission: true),
                                      ),
                                child: const Text('Разрешить Bluetooth'),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            if (service.initialised && !service.locked)
              SettingsSection(
                title: 'Ключ восстановления',
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'Сохраните ключ в менеджере паролей. Он восстановит историю после потери всех устройств. Мы не сможем восстановить его за вас.',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                  _recovery = await service.recoveryCode();
                                }),
                          child: const Text('Показать ключ'),
                        ),
                        if (_recovery != null)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _run(service.acknowledgeBackup),
                            child: const Text('Я сохранил ключ'),
                          ),
                        if (_recovery != null)
                          TextButton(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: _recovery!),
                              );
                            },
                            child: const Text('Копировать'),
                          ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                  _fingerprint = await service.ownFingerprint();
                                }),
                          child: const Text('Мой отпечаток'),
                        ),
                      ],
                    ),
                  ),
                  if (_recovery != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SelectableText(_recovery!),
                    ),
                  if (_fingerprint != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SelectableText(_fingerprint!),
                    ),
                ],
              ),
            if (service.locked)
              SettingsSection(
                title: 'Восстановить на этом устройстве',
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _restore,
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Ключ восстановления',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                    await service.restore(_restore.text);
                                    _restore.clear();
                                  }),
                            child: const Text('Восстановить историю'),
                          ),
                        ),
                        TextButton(
                          onPressed: _busy ? null : () => _reset(service),
                          child: const Text(
                            'Все ключи потеряны — начать заново',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            SettingsSection(
              title: 'Подключить другое устройство',
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (service.locked) ...[
                        const Text(
                          'Создайте код здесь, затем передайте его в этот же раздел на уже подключённом устройстве. Код действует 10 минут; передавайте его только между своими устройствами.',
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                  _pairCode = await service.beginPairing();
                                  _poll?.cancel();
                                  _poll = Timer.periodic(
                                    const Duration(seconds: 3),
                                    (_) async {
                                      if (_busy) return;
                                      try {
                                        if (await service.completePairing()) {
                                          _poll?.cancel();
                                          if (mounted) {
                                            setState(() => _pairCode = null);
                                            ref.invalidate(
                                              chatMessagesProvider,
                                            );
                                          }
                                        }
                                      } catch (_) {
                                        _poll?.cancel();
                                        if (mounted) {
                                          setState(
                                            () => _error =
                                                'Код подключения истёк. Создайте новый.',
                                          );
                                        }
                                      }
                                    },
                                  );
                                }),
                          child: const Text('Создать код подключения'),
                        ),
                        if (_pairCode != null) ...[
                          Center(
                            child: QrImageView(
                              data: _pairCode!,
                              size: 210,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: _pairCode!),
                              );
                            },
                            child: const Text('Копировать код подключения'),
                          ),
                        ],
                      ] else ...[
                        const Text(
                          'Вставьте код с нового устройства. Это передаст ему ключи вашей переписки.',
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _pair,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Код подключения',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                    await service.approvePairing(_pair.text);
                                    _pair.clear();
                                  }),
                            child: const Text('Передать ключи'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (!service.locked)
              SettingsSection(
                title: 'Проверить собеседника',
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'При первом контакте ключ запоминается. Для защиты от подмены при первом знакомстве сравните отпечаток с собеседником по другому доверенному каналу.',
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: _contactId,
                          decoration: const InputDecoration(
                            labelText: 'Личный чат',
                          ),
                          items: [
                            for (final chat
                                in ref.watch(chatsProvider).value ?? const [])
                              if (chat.chatType == 'direct' &&
                                  !chat.isSecret &&
                                  !chat.isBotChat)
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
                                  if (id != null) {
                                    _run(() async {
                                      _contactId = id;
                                      _contact = await service.contactIdentity(
                                        id,
                                      );
                                      _contactFingerprint = await service
                                          .fingerprint(_contact!);
                                    });
                                  }
                                },
                        ),
                        if (_contactFingerprint != null) ...[
                          const SizedBox(height: 12),
                          SelectableText(_contactFingerprint!),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                    await service.acceptContact(_contact!);
                                    ref.invalidate(chatMessagesProvider);
                                  }),
                            child: const Text(
                              'Отпечаток совпадает — доверять ключу',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _MeshSwitch extends StatelessWidget {
  const _MeshSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;
  static const label = 'Если нет интернета использовать блютуз';
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth < 500 &&
              MediaQuery.textScalerOf(context).scale(16) > 20) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodyLarge),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Switch.adaptive(
                        value: value,
                        onChanged: onChanged,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return SwitchListTile.adaptive(
            title: const Text(label),
            value: value,
            onChanged: onChanged,
          );
        },
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(
          'Передаёт зашифрованный текст через устройства NiosMess рядом. Нужны разрешение Bluetooth и работающие приложения.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
}
