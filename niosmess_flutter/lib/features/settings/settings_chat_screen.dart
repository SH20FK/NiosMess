import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/settings_provider.dart';

class SettingsChatScreen extends ConsumerWidget {
  const SettingsChatScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Чаты'),
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
                  title: const Text('Отправка по Enter'),
                  subtitle: const Text('Нажимайте Enter, чтобы отправить сообщение'),
                  value: settings['enter_to_send'] ?? false,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('enter_to_send', v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Сохранять черновики'),
                  subtitle: const Text('Возвращайтесь к незавершённым сообщениям'),
                  value: settings['autosave_drafts'] ?? true,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('autosave_drafts', v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Обрезать лишние пробелы'),
                  subtitle: const Text('Автоматически убирать двойные пробелы'),
                  value: settings['trim_spaces'] ?? false,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('trim_spaces', v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Отображение', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Компактные сообщения'),
                  subtitle: const Text('Меньше отступов в списках и чатах'),
                  value: settings['compact_messages'] ?? false,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('compact_messages', v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Превью ссылок'),
                  subtitle: const Text('Показывать карточки для ссылок'),
                  value: settings['link_preview'] ?? true,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('link_preview', v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
