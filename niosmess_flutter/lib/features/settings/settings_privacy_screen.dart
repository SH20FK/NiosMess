import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/settings_provider.dart';
import '../../core/ghost_mode_provider.dart';
import '../../core/app_lock_provider.dart';

class SettingsPrivacyScreen extends ConsumerWidget {
  const SettingsPrivacyScreen({
    super.key,
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final ghostMode = ref.watch(ghostModeProvider);
    final lockState = ref.watch(appLockProvider);
    final whoCanWrite = (settings['who_can_write'] as String?) ?? 'all';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Конфиденциальность'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('Видимость', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _OptionTile(
                  title: 'Последнее посещение',
                  value: (settings['last_seen_visibility'] as String?) ?? 'Все',
                  onTap: () => _selectOption(
                    context,
                    ref,
                    key: 'last_seen_visibility',
                    title: 'Последнее посещение',
                    options: const ['Все', 'Контакты', 'Никто'],
                  ),
                ),
                const Divider(height: 1),
                _OptionTile(
                  title: 'Фото профиля',
                  value: (settings['photo_visibility'] as String?) ?? 'Все',
                  onTap: () => _selectOption(
                    context,
                    ref,
                    key: 'photo_visibility',
                    title: 'Фото профиля',
                    options: const ['Все', 'Контакты', 'Никто'],
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Индикатор набора'),
                  subtitle: const Text('Показывать, когда вы печатаете'),
                  value: settings['show_typing'] ?? true,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('show_typing', v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Отчёты о прочтении'),
                  subtitle: const Text('Показывать отметки «прочитано»'),
                  value: settings['read_receipts'] ?? true,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('read_receipts', v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Контакты', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _OptionTile(
                  title: 'Кто может писать мне',
                  value: _formatWhoCanWrite(whoCanWrite),
                  onTap: () => _selectOption(
                    context,
                    ref,
                    key: 'who_can_write',
                    title: 'Кто может писать мне',
                    options: const ['all', 'contacts', 'nobody'],
                  ),
                ),
                const Divider(height: 1),
                _OptionTile(
                  title: 'Кто может писать мне',
                  value: (settings['message_privacy'] as String?) ?? 'Все',
                  onTap: () => _selectOption(
                    context,
                    ref,
                    key: 'message_privacy',
                    title: 'Кто может писать мне',
                    options: const ['Все', 'Контакты', 'Никто'],
                  ),
                ),
                const Divider(height: 1),
                _OptionTile(
                  title: 'Кто может звонить мне',
                  value: (settings['call_privacy'] as String?) ?? 'Все',
                  onTap: () => _selectOption(
                    context,
                    ref,
                    key: 'call_privacy',
                    title: 'Кто может звонить мне',
                    options: const ['Все', 'Контакты', 'Никто'],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Безопасность', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Скрытый режим'),
                  subtitle: const Text('Чтение без отметки «прочитано»'),
                  value: ghostMode.isActive,
                  onChanged: (v) {
                    if (v) {
                      ref.read(ghostModeProvider.notifier).activate();
                    } else {
                      ref.read(ghostModeProvider.notifier).deactivate();
                    }
                    ref.read(settingsProvider.notifier).setSetting('ghost_mode', v);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Блокировка паролем'),
                  subtitle: const Text('Запрашивать PIN при входе'),
                  value: lockState.isEnabled,
                  onChanged: (value) async {
                    if (value) {
                      final pin = await _promptNewPin(context);
                      if (pin == null) return;
                      await ref.read(appLockProvider.notifier).enable(pin);
                      ref.read(settingsProvider.notifier).setSetting('passcode_lock', true);
                    } else {
                      final ok = await _promptPinVerify(context, ref);
                      if (!ok) return;
                      await ref.read(appLockProvider.notifier).disable();
                      ref.read(settingsProvider.notifier).setSetting('passcode_lock', false);
                    }
                  },
                ),
                if (lockState.isEnabled) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Вход по биометрии'),
                    subtitle: Text(
                      lockState.biometricAvailable ? 'Face ID / Touch ID' : 'Биометрия недоступна',
                    ),
                    value: lockState.biometricEnabled,
                    onChanged: lockState.biometricAvailable
                        ? (v) => ref.read(appLockProvider.notifier).setBiometricEnabled(v)
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatWhoCanWrite(String value) {
    switch (value) {
      case 'contacts':
        return 'Контакты';
      case 'nobody':
        return 'Никто';
      case 'all':
      default:
        return 'Все';
    }
  }

  Future<void> _selectOption(
    BuildContext context,
    WidgetRef ref, {
    required String key,
    required String title,
    required List<String> options,
  }) async {
    final current = ref.read(settingsProvider)[key] as String?;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            ...options.map((opt) => RadioListTile<String>(
                  value: opt,
                  groupValue: current ?? options.first,
                  onChanged: (value) => Navigator.pop(context, value),
                  title: Text(key == 'who_can_write' ? _formatWhoCanWrite(opt) : opt),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) {
      ref.read(settingsProvider.notifier).setSetting(key, selected);
    }
  }

  Future<String?> _promptNewPin(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (_) => const _PinSetupDialog(),
    );
  }

  Future<bool> _promptPinVerify(BuildContext context, WidgetRef ref) async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _PinVerifyDialog(),
    );
    if (pin == null || pin.isEmpty) return false;
    final ok = await ref.read(appLockProvider.notifier).verifyPin(pin);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Неверный PIN')),
      );
    }
    return ok;
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(value),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog();

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Создайте PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _first,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            decoration: const InputDecoration(labelText: 'PIN', counterText: ''),
          ),
          TextField(
            controller: _second,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            decoration: const InputDecoration(labelText: 'Повторите PIN', counterText: ''),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final p1 = _first.text.trim();
            final p2 = _second.text.trim();
            if (p1.length < 4 || p2.length < 4) {
              setState(() => _error = 'Введите 4 цифры');
              return;
            }
            if (p1 != p2) {
              setState(() => _error = 'PIN не совпадает');
              return;
            }
            Navigator.pop(context, p1);
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _PinVerifyDialog extends StatefulWidget {
  const _PinVerifyDialog();

  @override
  State<_PinVerifyDialog> createState() => _PinVerifyDialogState();
}

class _PinVerifyDialogState extends State<_PinVerifyDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Введите PIN'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 4,
        decoration: const InputDecoration(counterText: ''),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Продолжить'),
        ),
      ],
    );
  }
}
