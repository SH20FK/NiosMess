import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/core/storage/encrypted_message_cache.dart';
import 'package:pulse_flutter/core/storage/local_storage_service.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/features/settings/domain/setting_id.dart';
import 'package:pulse_flutter/features/settings/domain/settings_control.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_responsive_shell.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SettingsStorageScreen extends ConsumerStatefulWidget {
  const SettingsStorageScreen({
    this.isEmbedded = false,
    super.key,
  });

  final bool isEmbedded;

  @override
  ConsumerState<SettingsStorageScreen> createState() =>
      _SettingsStorageScreenState();
}

class _SettingsStorageScreenState extends ConsumerState<SettingsStorageScreen> {
  bool _busy = false;

  void _refresh() {
    if (_busy) return;
    ref.read(storageSnapshotProvider.notifier).refresh(forceRefresh: true);
  }

  Future<void> _clearTemporaryFiles() async {
    final bool confirmed = await _confirm(
      title: context.l10n.settingsStorageClearTemporaryConfirmTitle,
      body: context.l10n.settingsStorageClearTemporaryConfirmBody,
    );
    if (!confirmed) return;
    await _runStorageAction(() async {
      final int deleted =
          await ref.read(localStorageServiceProvider).clearTemporaryFiles();
      await ref.read(cacheServiceProvider).clearAll();
      return deleted;
    });
  }

  Future<void> _clearDrafts() async {
    final bool confirmed = await _confirm(
      title: context.l10n.settingsStorageClearDraftsConfirmTitle,
      body: context.l10n.settingsStorageClearDraftsConfirmBody,
    );
    if (!confirmed) return;
    await _runStorageAction(() async {
      return ref.read(localStorageServiceProvider).clearDrafts();
    });
  }

  Future<void> _clearCategory(StorageCategory category) async {
    final bool confirmed = await _confirm(
      title: 'Очистить ${category.labelRu.toLowerCase()}?',
      body: 'Файлы этой категории будут удалены из локального кэша.',
    );
    if (!confirmed) return;
    await _runStorageAction(() async {
      return ref.read(localStorageServiceProvider).clearCategoryFiles(category);
    });
  }

  Future<void> _clearE2eeCache() async {
    final bool confirmed = await _confirm(
      title: 'Очистить кэш секретных чатов?',
      body:
          'Все расшифрованные сообщения секретных чатов на этом устройстве будут удалены. Это действие необратимо.',
    );
    if (!confirmed) return;
    await _runStorageAction(() async {
      await EncryptedMessageCache.clearAll();
      return null;
    });
  }

  Future<void> _runStorageAction(Future<int?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final int? deleted = await action();
      if (!mounted) return;
      ref.read(storageSnapshotProvider.notifier).refresh(forceRefresh: true);
      if (deleted != null && deleted > 0) {
        AppToast.showSuccess(
          context,
          'Очищено ${FileTypeDetector.formatFileSize(deleted)}',
        );
      } else {
        AppToast.showSuccess(context, context.l10n.settingsStorageCleared);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm({required String title, required String body}) async {
    final bool? result = await showAppConfirmDialog(
      context: context,
      title: title,
      subtitle: body,
      confirmLabel: context.l10n.commonDelete,
      cancelLabel: context.l10n.commonCancel,
      destructive: true,
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AsyncValue<LocalStorageSnapshot> snapshotAsync =
        ref.watch(storageSnapshotProvider);

    return SettingsResponsiveShell(
      title: context.l10n.settingsStorageTitle,
      isEmbedded: widget.isEmbedded,
      child: snapshotAsync.when(
        data: (LocalStorageSnapshot data) =>
            _buildContent(context, scheme, textTheme, data),
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: AppLoadingIndicator()),
        ),
        error: (Object err, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              'Ошибка загрузки данных хранилища',
              style: TextStyle(color: scheme.error),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    LocalStorageSnapshot data,
  ) {
    final int appDataBytes = data.documentsBytes + data.supportBytes;
    final int cacheBytes = data.temporaryBytes;
    final int draftBytes = data.draftBytes;
    final int totalBytes = data.totalBytes;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.14),
              ),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _format(totalBytes),
                            style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.settingsStorageUsedByApp,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: _busy ? null : _refresh,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.secondaryContainer,
                        foregroundColor: scheme.onSecondaryContainer,
                      ),
                      tooltip: context.l10n.settingsStorageRefresh,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Semantics(
                  label:
                      '${context.l10n.settingsStorageAppData}: ${_format(appDataBytes)}, '
                      '${context.l10n.settingsStorageLegendCache}: ${_format(cacheBytes)}, '
                      '${context.l10n.settingsStorageLegendDrafts}: ${_format(draftBytes)}',
                  child: _SegmentedProgressBar(
                    appDataBytes: appDataBytes,
                    cacheBytes: cacheBytes,
                    draftBytes: draftBytes,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: <Widget>[
                    _LegendItem(
                      color: scheme.primary,
                      label: context.l10n.settingsStorageAppData,
                    ),
                    _LegendItem(
                      color: scheme.tertiary,
                      label: context.l10n.settingsStorageLegendCache,
                    ),
                    _LegendItem(
                      color: scheme.secondary,
                      label: context.l10n.settingsStorageLegendDrafts,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              _StorageCategoryCard(
                icon: Icons.folder_rounded,
                title: context.l10n.settingsStorageCategoryAppData,
                value: _format(appDataBytes),
                color: scheme.primary,
              ),
              const SizedBox(width: 10),
              _StorageCategoryCard(
                icon: Icons.cached_rounded,
                title: context.l10n.settingsStorageCategoryCache,
                value: _format(cacheBytes),
                color: scheme.tertiary,
                onDelete:
                    cacheBytes > 0 && !_busy ? _clearTemporaryFiles : null,
                deleteTooltip: context.l10n.settingsStorageClearTemporary,
              ),
              const SizedBox(width: 10),
              _StorageCategoryCard(
                icon: Icons.edit_note_rounded,
                title: context.l10n.settingsStorageCategoryDrafts,
                value: _format(draftBytes),
                color: scheme.secondary,
                onDelete: draftBytes > 0 && !_busy ? _clearDrafts : null,
                deleteTooltip: context.l10n.settingsStorageClearDrafts,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Категории файлов в хранилище
        SettingsSection(
          title: 'Детализация хранилища',
          subtitle: 'Объём данных по типам медиа и кэша',
          children: <Widget>[
            ...StorageCategory.values.map((StorageCategory cat) {
              final int bytes = data.bytesFor(cat);
              final IconData icon = switch (cat) {
                StorageCategory.images => Icons.image_rounded,
                StorageCategory.videos => Icons.video_library_rounded,
                StorageCategory.audio => Icons.audiotrack_rounded,
                StorageCategory.files => Icons.insert_drive_file_rounded,
                StorageCategory.stickers => Icons.emoji_emotions_rounded,
                StorageCategory.avatars => Icons.account_circle_rounded,
                StorageCategory.drafts => Icons.edit_note_rounded,
                StorageCategory.secretChatCache => Icons.lock_clock_rounded,
                StorageCategory.other => Icons.storage_rounded,
              };

              return SettingsRow(
                leading: Icon(icon, color: scheme.primary),
                title: cat.labelRu,
                control: ValueControl(_format(bytes)),
                onTap: bytes > 0 && !_busy ? () => _clearCategory(cat) : null,
              );
            }),
          ],
        ),

        // 1. Media Auto-Download
        SettingsSection(
          title: 'Автозагрузка медиа',
          subtitle: 'Управление трафиком и загрузкой файлов',
          children: <Widget>[
            SettingsRow(
              anchor: SettingId.storageAutoDownloadWifi.value,
              leading: Icon(Icons.wifi_rounded, color: scheme.primary),
              title: 'Через сеть Wi-Fi',
              subtitle:
                  'Автоматически скачивать фото, видео и голосовые сообщения',
              control: ToggleControl(
                value: ref.watch(
                  uiSettingsProvider.select((s) => s.autoDownloadWifi),
                ),
                onChanged: (bool val) {
                  ref
                      .read(uiSettingsProvider.notifier)
                      .setAutoDownloadWifi(val);
                },
              ),
            ),
            SettingsRow(
              anchor: SettingId.storageAutoDownloadMobile.value,
              leading:
                  Icon(Icons.signal_cellular_alt_rounded, color: scheme.primary),
              title: 'Через мобильную сеть',
              subtitle: 'Экономия трафика: загрузка медиафайлов',
              control: ToggleControl(
                value: ref.watch(
                  uiSettingsProvider.select((s) => s.autoDownloadCellular),
                ),
                onChanged: (bool val) {
                  ref
                      .read(uiSettingsProvider.notifier)
                      .setAutoDownloadCellular(val);
                },
              ),
            ),
            SettingsRow(
              leading:
                  Icon(Icons.airplanemode_active_rounded, color: scheme.primary),
              title: 'В роуминге',
              subtitle: 'Полное отключение автоматической загрузки медиа',
              control: ToggleControl(
                value: ref.watch(
                  uiSettingsProvider.select((s) => s.autoDownloadRoaming),
                ),
                onChanged: (bool val) {
                  ref
                      .read(uiSettingsProvider.notifier)
                      .setAutoDownloadRoaming(val);
                },
              ),
            ),
          ],
        ),

        // 2. Save to Gallery
        SettingsSection(
          title: 'Сохранять в галерею',
          subtitle:
              'Автоматическое сохранение входящих фото и видео на устройство',
          children: <Widget>[
            SettingsRow(
              leading: Icon(Icons.person_outline_rounded, color: scheme.secondary),
              title: 'Личные чаты',
              subtitle: 'Сохранять фото и видео из личных переписок',
              control: ToggleControl(
                value: ref.watch(
                  uiSettingsProvider.select((s) => s.saveToGalleryPrivate),
                ),
                onChanged: (bool val) {
                  ref
                      .read(uiSettingsProvider.notifier)
                      .setSaveToGalleryPrivate(val);
                },
              ),
            ),
            SettingsRow(
              leading: Icon(Icons.group_outlined, color: scheme.secondary),
              title: 'Группы',
              subtitle: 'Сохранять фото и видео из групповых чатов',
              control: ToggleControl(
                value: ref.watch(
                  uiSettingsProvider.select((s) => s.saveToGalleryGroups),
                ),
                onChanged: (bool val) {
                  ref
                      .read(uiSettingsProvider.notifier)
                      .setSaveToGalleryGroups(val);
                },
              ),
            ),
            SettingsRow(
              leading: Icon(Icons.campaign_outlined, color: scheme.secondary),
              title: 'Каналы',
              subtitle:
                  'Сохранять фото и видео из публичных и приватных каналов',
              control: ToggleControl(
                value: ref.watch(
                  uiSettingsProvider.select((s) => s.saveToGalleryChannels),
                ),
                onChanged: (bool val) {
                  ref
                      .read(uiSettingsProvider.notifier)
                      .setSaveToGalleryChannels(val);
                },
              ),
            ),
          ],
        ),

        // 3. Streaming
        SettingsSection(
          title: 'Потоковое воспроизведение',
          subtitle: 'Проигрывание видео и аудио без ожидания полной загрузки',
          children: <Widget>[
            SettingsRow(
              leading:
                  Icon(Icons.play_circle_outline_rounded, color: scheme.tertiary),
              title: 'Стриминг медиа',
              subtitle:
                  'Начинать воспроизведение сразу, подгружая медиафайл частями',
              control: ToggleControl(
                value: ref.watch(
                  uiSettingsProvider.select((s) => s.streamMedia),
                ),
                onChanged: (bool val) {
                  ref.read(uiSettingsProvider.notifier).setStreamMedia(val);
                },
              ),
            ),
          ],
        ),

        // 4. Secret chats and encryption (E2EE)
        SettingsSection(
          title: 'Секретные чаты и шифрование (E2EE)',
          subtitle:
              'Управление локальным хранилищем расшифрованных сообщений сквозного шифрования',
          children: <Widget>[
            SettingsRow(
              leading: Icon(Icons.lock_reset_rounded, color: scheme.error),
              title: 'Очистить кэш секретных чатов',
              subtitle:
                  'Удалить расшифрованные сообщения секретных чатов с этого устройства',
              control: const NavigationControl(),
              onTap: _clearE2eeCache,
            ),
          ],
        ),
      ],
    );
  }

  static String _format(int bytes) => FileTypeDetector.formatFileSize(bytes);
}

class _SegmentedProgressBar extends StatelessWidget {
  const _SegmentedProgressBar({
    required this.appDataBytes,
    required this.cacheBytes,
    required this.draftBytes,
  });

  final int appDataBytes;
  final int cacheBytes;
  final int draftBytes;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int total = appDataBytes + cacheBytes + draftBytes;

    if (total == 0) {
      return Container(
        height: 10,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }

    final double appDataFlex = appDataBytes / total;
    final double cacheFlex = cacheBytes / total;
    final double draftFlex = draftBytes / total;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: Row(
          children: <Widget>[
            if (appDataFlex > 0)
              Expanded(
                flex: (appDataFlex * 1000).round().clamp(1, 1000),
                child: Container(color: scheme.primary),
              ),
            if (cacheFlex > 0)
              Expanded(
                flex: (cacheFlex * 1000).round().clamp(1, 1000),
                child: Container(color: scheme.tertiary),
              ),
            if (draftFlex > 0)
              Expanded(
                flex: (draftFlex * 1000).round().clamp(1, 1000),
                child: Container(color: scheme.secondary),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StorageCategoryCard extends StatelessWidget {
  const _StorageCategoryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.onDelete,
    this.deleteTooltip,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback? onDelete;
  final String? deleteTooltip;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: scheme.error,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    onPressed: onDelete,
                    tooltip: deleteTooltip,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
