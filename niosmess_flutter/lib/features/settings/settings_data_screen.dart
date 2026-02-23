import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/settings_provider.dart';
import '../../core/storage/offline_cache.dart';
import '../../core/data_usage_provider.dart';
import '../../core/downloads_provider.dart';

class SettingsDataScreen extends ConsumerStatefulWidget {
  const SettingsDataScreen({
    super.key,
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  ConsumerState<SettingsDataScreen> createState() => _SettingsDataScreenState();
}

class _SettingsDataScreenState extends ConsumerState<SettingsDataScreen> {
  String _cacheSize = '—';
  bool _loadingSize = true;

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dataUsageProvider.notifier).refreshServer();
      ref.read(downloadsProvider.notifier).refreshRemote();
    });
  }

  Future<void> _calculateCacheSize() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('cache_'));
    int bytes = 0;
    for (final key in keys) {
      final value = prefs.get(key);
      if (value is String) {
        bytes += utf8.encode(value).length;
      } else if (value is List<String>) {
        bytes += utf8.encode(value.join()).length;
      }
    }
    if (!mounted) return;
    setState(() {
      _cacheSize = _formatBytes(bytes);
      _loadingSize = false;
    });
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 KB';
    const kb = 1024;
    const mb = 1024 * kb;
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    }
    return '${(bytes / kb).toStringAsFixed(1)} KB';
  }

  Future<void> _clearCache() async {
    await OfflineCache.clearAll();
    await _calculateCacheSize();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Кэш очищен')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final autoMedia = settings['auto_download_media'] ?? true;
    final autoDocs = settings['auto_download_docs'] ?? false;
    final wifiOnly = settings['wifi_only_downloads'] ?? false;
    final dataSaver = settings['data_saver'] ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Данные и память'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('Хранилище', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Использовано', style: Theme.of(context).textTheme.bodyMedium),
                      Text(
                        _loadingSize ? '...' : _cacheSize,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _clearCache,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Очистить кэш'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Автозагрузка', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Медиафайлы'),
                  subtitle: const Text('Автоматически загружать фото и видео'),
                  value: autoMedia,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('auto_download_media', v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Документы'),
                  subtitle: const Text('Автоматически загружать файлы'),
                  value: autoDocs,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('auto_download_docs', v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Только Wi‑Fi'),
                  subtitle: const Text('Загружать файлы только по Wi‑Fi'),
                  value: wifiOnly,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('wifi_only_downloads', v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Экономия трафика'),
                  subtitle: const Text('Снижать качество медиа при скачивании'),
                  value: dataSaver,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('data_saver', v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Сеть', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.wifi_outlined),
                  title: const Text('Использование данных'),
                  subtitle: const Text('Статистика сети'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const _DataUsageDetailsScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: const Text('Управление загрузками'),
                  subtitle: const Text('Список файлов'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const _DownloadsManagerScreen(),
                    ),
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

class _DataUsageDetailsScreen extends ConsumerWidget {
  const _DataUsageDetailsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dataUsageProvider);
    final local = state.local;
    final server = state.server;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Использование данных'),
        actions: [
          IconButton(
            onPressed: () => ref.read(dataUsageProvider.notifier).refreshServer(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('Локально', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _UsageRow(title: 'Сегодня', bucket: local.day),
                const Divider(height: 1),
                _UsageRow(title: 'Неделя', bucket: local.week),
                const Divider(height: 1),
                _UsageRow(title: 'Месяц', bucket: local.month),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (server != null) ...[
            Text('На сервере', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _UsageRow(title: 'Сегодня', bucket: server.day),
                  const Divider(height: 1),
                  _UsageRow(title: 'Неделя', bucket: server.week),
                  const Divider(height: 1),
                  _UsageRow(title: 'Месяц', bucket: server.month),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              await ref.read(dataUsageProvider.notifier).syncToServer();
              await ref.read(dataUsageProvider.notifier).refreshServer();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Синхронизация завершена')),
                );
              }
            },
            icon: const Icon(Icons.sync),
            label: const Text('Синхронизировать'),
          ),
          if (state.lastSync != null) ...[
            const SizedBox(height: 8),
            Text(
              'Последняя синхронизация: ${state.lastSync}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.title, required this.bucket});

  final String title;
  final UsageBucket bucket;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        'Загрузка: ${_formatBytesShort(bucket.upload)} · Скачивание: ${_formatBytesShort(bucket.download)}',
      ),
    );
  }
}

class _DownloadsManagerScreen extends ConsumerWidget {
  const _DownloadsManagerScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(downloadsProvider);
    final notifier = ref.read(downloadsProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Загрузки'),
        actions: [
          IconButton(
            onPressed: () => notifier.refreshRemote(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('На устройстве', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          if (state.local.isEmpty)
            const Text('Пока нет загрузок')
          else
            Card(
              child: Column(
                children: state.local.map((item) {
                  return Column(
                    children: [
                      ListTile(
                        title: Text(item.filename),
                        subtitle: Text(_formatBytesShort(item.size)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.open_in_new),
                              onPressed: item.path == null
                                  ? null
                                  : () async {
                                      final result = await OpenFilex.open(item.path!);
                                      if (result.type != ResultType.done && context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Не удалось открыть файл')),
                                        );
                                      }
                                    },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => notifier.removeLocalDownload(item.id, deleteFile: true),
                            ),
                          ],
                        ),
                      ),
                      if (item != state.local.last) const Divider(height: 1),
                    ],
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 16),
          Text('На сервере', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          if (state.remote.isEmpty)
            const Text('Нет данных с сервера')
          else
            Card(
              child: Column(
                children: state.remote.map((item) {
                  return Column(
                    children: [
                      ListTile(
                        title: Text(item.filename),
                        subtitle: Text(_formatBytesShort(item.size)),
                      ),
                      if (item != state.remote.last) const Divider(height: 1),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

String _formatBytesShort(int bytes) {
  if (bytes <= 0) return '0 KB';
  const kb = 1024;
  const mb = 1024 * kb;
  const gb = 1024 * mb;
  if (bytes >= gb) {
    return '${(bytes / gb).toStringAsFixed(1)} GB';
  }
  if (bytes >= mb) {
    return '${(bytes / mb).toStringAsFixed(1)} MB';
  }
  return '${(bytes / kb).toStringAsFixed(1)} KB';
}
