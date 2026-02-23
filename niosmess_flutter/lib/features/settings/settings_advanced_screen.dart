import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/settings_provider.dart';

class SettingsAdvancedScreen extends ConsumerWidget {
  const SettingsAdvancedScreen({
    super.key,
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final reduceMotion = settings['reduce_motion'] ?? false;
    final experimental = settings['experimental_features'] ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Дополнительно'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('Производительность', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Снизить анимации'),
                  subtitle: const Text('Подходит для слабых устройств'),
                  value: reduceMotion,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('reduce_motion', v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Экспериментальные', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Бета‑функции'),
                  subtitle: const Text('Включить нестабильные возможности'),
                  value: experimental,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('experimental_features', v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('О приложении', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Версия'),
                  subtitle: Text('NiosMess v2.0.0'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.code_outlined),
                  title: Text('Разработчик'),
                  subtitle: Text('Nios Team'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Лицензии'),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'NiosMess',
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
