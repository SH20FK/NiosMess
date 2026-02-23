import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/settings_provider.dart';

class SettingsNotificationsScreen extends ConsumerWidget {
  const SettingsNotificationsScreen({
    super.key,
    required this.onBack,
  });

  final VoidCallback onBack;

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref, {
    required String key,
    required String title,
  }) async {
    final currentRaw = ref.read(settingsProvider)[key] as String?;
    final now = TimeOfDay.now();
    TimeOfDay initial = now;
    if (currentRaw != null && currentRaw.contains(':')) {
      final parts = currentRaw.split(':');
      final h = int.tryParse(parts.first) ?? now.hour;
      final m = int.tryParse(parts.last) ?? now.minute;
      initial = TimeOfDay(hour: h, minute: m);
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: title,
    );
    if (picked == null) return;
    final formatted = picked.hour.toString().padLeft(2, '0') +
        ':' +
        picked.minute.toString().padLeft(2, '0');
    ref.read(settingsProvider.notifier).setSetting(key, formatted);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Уведомления'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('Сообщения', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Звуки'),
                  subtitle: const Text('Проигрывать звук при новом сообщении'),
                  value: settings['notify_sound'] ?? true,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('notify_sound', v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Вибрация'),
                  subtitle: const Text('Вибрировать при уведомлении'),
                  value: settings['notify_vibrate'] ?? true,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('notify_vibrate', v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Предпросмотр текста'),
                  subtitle: const Text('Показывать текст в уведомлениях'),
                  value: settings['notify_preview'] ?? true,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('notify_preview', v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Группы и каналы', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Уведомления из групп'),
                  subtitle: const Text('Получать уведомления из групповых чатов'),
                  value: settings['notify_group'] ?? true,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('notify_group', v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Упоминания'),
                  subtitle: const Text('Уведомлять при @упоминании'),
                  value: settings['notify_mentions'] ?? true,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('notify_mentions', v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Звонки и реакции', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Звонки'),
                  subtitle: const Text('Показывать уведомления о звонках'),
                  value: settings['notify_calls'] ?? true,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('notify_calls', v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Реакции'),
                  subtitle: const Text('Уведомлять о реакциях на сообщения'),
                  value: settings['notify_reactions'] ?? true,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('notify_reactions', v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Тихие часы', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.nightlight_outlined),
                  title: const Text('Начало'),
                  subtitle: Text(settings['quiet_hours_start']?.toString() ?? 'Не задано'),
                  onTap: () => _pickTime(
                    context,
                    ref,
                    key: 'quiet_hours_start',
                    title: 'Начало тихого периода',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: const Text('Конец'),
                  subtitle: Text(settings['quiet_hours_end']?.toString() ?? 'Не задано'),
                  onTap: () => _pickTime(
                    context,
                    ref,
                    key: 'quiet_hours_end',
                    title: 'Конец тихого периода',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
