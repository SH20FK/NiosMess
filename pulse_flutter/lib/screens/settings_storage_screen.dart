import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/core/storage/encrypted_message_cache.dart';
import 'package:pulse_flutter/core/storage/local_storage_service.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

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
      await ref.read(localStorageServiceProvider).clearTemporaryFiles();
      await ref.read(cacheServiceProvider).clearAll();
    });
  }

  Future<void> _clearDrafts() async {
    final bool confirmed = await _confirm(
      title: context.l10n.settingsStorageClearDraftsConfirmTitle,
      body: context.l10n.settingsStorageClearDraftsConfirmBody,
    );
    if (!confirmed) return;
    await _runStorageAction(() async {
      await ref.read(localStorageServiceProvider).clearDrafts();
    });
  }

  Future<void> _clearE2eeCache() async {
    final bool confirmed = await _confirm(
      title: 'Очистить кэш секретных чатов?',
      body: 'Все расшифрованные сообщения секретных чатов на этом устройстве будут удалены. Это действие необратимо.',
    );
    if (!confirmed) return;
    await _runStorageAction(() async {
      await EncryptedMessageCache.clearAll();
    });
  }

  Future<void> _runStorageAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ref.read(storageSnapshotProvider.notifier).refresh(forceRefresh: true);
      AppToast.showSuccess(context, context.l10n.settingsStorageCleared);
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

    return SettingsShell(
      title: context.l10n.settingsStorageTitle,
      isEmbedded: widget.isEmbedded,
      onRefresh: () async => _refresh(),
      children: <Widget>[
        SettingsNavBanner(
          illustrationCategory: SettingsIllustrationCategory.storage,
          subtitle: context.l10n.settingsStorageBannerSubtitle,
          iconColor: scheme.primary,
        ),
        snapshotAsync.when(
          data: (LocalStorageSnapshot data) =>
              _buildContent(context, scheme, textTheme, data),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
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
      ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
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
                label: '${context.l10n.settingsStorageAppData}: ${_format(appDataBytes)}, '
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
                  _LegendItem(color: scheme.tertiary, label: context.l10n.settingsStorageLegendCache),
                  _LegendItem(color: scheme.secondary, label: context.l10n.settingsStorageLegendDrafts),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
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
              onDelete: cacheBytes > 0 && !_busy ? _clearTemporaryFiles : null,
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
        const SizedBox(height: 24),

        // 1. Media Auto-Download
        SettingsSection(
          title: 'Автозагрузка медиа',
          subtitle: 'Управление трафиком и загрузкой файлов',
          children: <Widget>[
            SettingsSwitchTile(
              icon: Icons.wifi_rounded,
              title: 'Через сеть Wi-Fi',
              subtitle: 'Автоматически скачивать фото, видео и голосовые сообщения',
              iconColor: scheme.primary,
              value: ref.watch(uiSettingsProvider.select((s) => s.autoDownloadWifi)),
              onChanged: (bool val) {
                ref.read(uiSettingsProvider.notifier).setAutoDownloadWifi(val);
              },
            ),
            SettingsSwitchTile(
              icon: Icons.signal_cellular_alt_rounded,
              title: 'Через мобильную сеть',
              subtitle: 'Экономия трафика: загрузка медиафайлов',
              iconColor: scheme.primary,
              value: ref.watch(uiSettingsProvider.select((s) => s.autoDownloadCellular)),
              onChanged: (bool val) {
                ref.read(uiSettingsProvider.notifier).setAutoDownloadCellular(val);
              },
            ),
            SettingsSwitchTile(
              icon: Icons.airplanemode_active_rounded,
              title: 'В роуминге',
              subtitle: 'Полное отключение автоматической загрузки медиа',
              iconColor: scheme.primary,
              value: ref.watch(uiSettingsProvider.select((s) => s.autoDownloadRoaming)),
              onChanged: (bool val) {
                ref.read(uiSettingsProvider.notifier).setAutoDownloadRoaming(val);
              },
            ),
          ],
        ),

        // 2. Save to Gallery
        SettingsSection(
          title: 'Сохранять в галерею',
          subtitle: 'Автоматическое сохранение входящих фото и видео на устройство',
          children: <Widget>[
            SettingsSwitchTile(
              icon: Icons.person_outline_rounded,
              title: 'Личные чаты',
              subtitle: 'Сохранять фото и видео из личных переписок',
              iconColor: scheme.secondary,
              value: ref.watch(uiSettingsProvider.select((s) => s.saveToGalleryPrivate)),
              onChanged: (bool val) {
                ref.read(uiSettingsProvider.notifier).setSaveToGalleryPrivate(val);
              },
            ),
            SettingsSwitchTile(
              icon: Icons.group_outlined,
              title: 'Группы',
              subtitle: 'Сохранять фото и видео из групповых чатов',
              iconColor: scheme.secondary,
              value: ref.watch(uiSettingsProvider.select((s) => s.saveToGalleryGroups)),
              onChanged: (bool val) {
                ref.read(uiSettingsProvider.notifier).setSaveToGalleryGroups(val);
              },
            ),
            SettingsSwitchTile(
              icon: Icons.campaign_outlined,
              title: 'Каналы',
              subtitle: 'Сохранять фото и видео из публичных и приватных каналов',
              iconColor: scheme.secondary,
              value: ref.watch(uiSettingsProvider.select((s) => s.saveToGalleryChannels)),
              onChanged: (bool val) {
                ref.read(uiSettingsProvider.notifier).setSaveToGalleryChannels(val);
              },
            ),
          ],
        ),

        // 3. Streaming
        SettingsSection(
          title: 'Потоковое воспроизведение',
          subtitle: 'Проигрывание видео и аудио без ожидания полной загрузки',
          children: <Widget>[
            SettingsSwitchTile(
              icon: Icons.play_circle_outline_rounded,
              title: 'Стриминг медиа',
              subtitle: 'Начинать воспроизведение сразу, подгружая медиафайл частями',
              iconColor: scheme.tertiary,
              value: ref.watch(uiSettingsProvider.select((s) => s.streamMedia)),
              onChanged: (bool val) {
                ref.read(uiSettingsProvider.notifier).setStreamMedia(val);
              },
            ),
          ],
        ),

        // 4. Secret chats and encryption (E2EE)
        SettingsSection(
          title: 'Секретные чаты и шифрование (E2EE)',
          subtitle: 'Управление локальным хранилищем расшифрованных сообщений сквозного шифрования',
          children: <Widget>[
            SettingsTile(
              icon: Icons.lock_reset_rounded,
              title: 'Очистить кэш секретных чатов',
              subtitle: 'Удалит локальные копии расшифрованных сообщений секретных чатов',
              iconColor: scheme.error,
              onTap: () {
                if (!_busy) _clearE2eeCache();
              },
            ),
          ],
        ),
      ],
    );
  }

  String _format(int bytes) => FileTypeDetector.formatFileSize(bytes);
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 12,
          color: scheme.surfaceContainerHighest,
        ),
      );
    }

    final double appDataWeight = appDataBytes / total;
    final double cacheWeight = cacheBytes / total;
    final double draftWeight = draftBytes / total;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 12,
        child: Row(
          children: <Widget>[
            if (appDataBytes > 0)
              Expanded(
                flex: (appDataWeight * 1000).round().clamp(1, 1000),
                child: Container(color: scheme.primary),
              ),
            if (cacheBytes > 0)
              Expanded(
                flex: (cacheWeight * 1000).round().clamp(1, 1000),
                child: Container(color: scheme.tertiary),
              ),
            if (draftBytes > 0)
              Expanded(
                flex: (draftWeight * 1000).round().clamp(1, 1000),
                child: Container(color: scheme.secondary),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
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
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      value,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            if (onDelete != null)
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.all(8),
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: scheme.error.withValues(alpha: 0.84),
                    size: 18,
                  ),
                  onPressed: onDelete,
                  tooltip: deleteTooltip,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
