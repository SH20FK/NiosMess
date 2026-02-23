import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/settings_provider.dart';
import '../../core/storage/offline_cache.dart';
import '../../core/data_usage_provider.dart';
import '../../core/downloads_provider.dart';
import '../../ui/widgets/animated_list_item.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: widget.onBack,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back),
          ),
        ),
        title: Text(
          'Данные и память',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: AnimatedListItem(
              index: 0,
              child: _buildStorageSection(context),
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedListItem(
              index: 1,
              child: _buildAutoDownloadSection(context, ref, autoMedia, autoDocs, wifiOnly, dataSaver),
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedListItem(
              index: 2,
              child: _buildNetworkSection(context),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  Widget _buildStorageSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 100, 16, 8),
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.storage_outlined,
                      size: 28,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Использовано',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _loadingSize ? 'Вычисление...' : _cacheSize,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _clearCache,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Очистить кэш'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoDownloadSection(
    BuildContext context,
    WidgetRef ref,
    bool autoMedia,
    bool autoDocs,
    bool wifiOnly,
    bool dataSaver,
  ) {
    final textTheme = Theme.of(context).textTheme;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12, top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.download_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Автозагрузка',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: Column(
              children: [
                _buildAnimatedSwitch(
                  context,
                  title: 'Медиафайлы',
                  subtitle: 'Автоматически загружать фото и видео',
                  icon: Icons.photo_outlined,
                  value: autoMedia,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('auto_download_media', v),
                ),
                const Divider(height: 1, indent: 56),
                _buildAnimatedSwitch(
                  context,
                  title: 'Документы',
                  subtitle: 'Автоматически загружать файлы',
                  icon: Icons.insert_drive_file_outlined,
                  value: autoDocs,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('auto_download_docs', v),
                ),
                const Divider(height: 1, indent: 56),
                _buildAnimatedSwitch(
                  context,
                  title: 'Только Wi‑Fi',
                  subtitle: 'Загружать файлы только по Wi‑Fi',
                  icon: Icons.wifi_outlined,
                  value: wifiOnly,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('wifi_only_downloads', v),
                ),
                const Divider(height: 1, indent: 56),
                _buildAnimatedSwitch(
                  context,
                  title: 'Экономия трафика',
                  subtitle: 'Снижать качество медиа при скачивании',
                  icon: Icons.data_saver_on_outlined,
                  value: dataSaver,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('data_saver', v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12, top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.network_check_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Сеть',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: Column(
              children: [
                _buildNetworkTile(
                  context,
                  icon: Icons.wifi_outlined,
                  title: 'Использование данных',
                  subtitle: 'Статистика сети',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const _DataUsageDetailsScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _buildNetworkTile(
                  context,
                  icon: Icons.folder_outlined,
                  title: 'Управление загрузками',
                  subtitle: 'Список файлов',
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

  Widget _buildAnimatedSwitch(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: value 
              ? colorScheme.primaryContainer 
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: value 
              ? colorScheme.onPrimaryContainer 
              : colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildNetworkTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
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
