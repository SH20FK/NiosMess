import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/core/storage/encrypted_message_cache.dart';
import 'package:pulse_flutter/core/storage/local_storage_service.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/features/settings/domain/settings_control.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_responsive_shell.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SettingsStorageScreen extends ConsumerStatefulWidget {
  const SettingsStorageScreen({this.isEmbedded = false, super.key});

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
      final int deleted = await ref
          .read(localStorageServiceProvider)
          .clearTemporaryFiles();
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
      title: context.l10n.settingsV2ClearCategory,
      body: context.l10n.settingsV2ClearCategoryHint,
    );
    if (!confirmed) return;
    await _runStorageAction(() async {
      return ref.read(localStorageServiceProvider).clearCategoryFiles(category);
    });
  }

  Future<void> _clearE2eeCache() async {
    final bool confirmed = await _confirm(
      title: context.l10n.settingsV2ClearSecretCache,
      body: context.l10n.settingsV2SecretCacheConfirm,
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
        AppToast.showSuccess(context, context.l10n.settingsStorageCleared);
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
    final AsyncValue<LocalStorageSnapshot> snapshotAsync = ref.watch(
      storageSnapshotProvider,
    );

    if (kIsWeb) {
      return SettingsShell(
        title: context.l10n.settingsV2Storage,
        isEmbedded: widget.isEmbedded,
        children: [
          SettingsSection(
            title: context.l10n.webStorageTitle,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.l10n.webStorageDescription),
              ),
              SettingsRow(
                title: context.l10n.webStorageDrafts,
                control: ValueControl(
                  '${snapshotAsync.value?.draftCount ?? 0}',
                ),
                subtitle: context.l10n.webStorageDraftsDescription,
              ),
            ],
          ),
          SettingsSection(
            title: context.l10n.webAutoDownload,
            children: [
              SettingsRow(
                anchor: 'auto_download_wifi',
                title: context.l10n.webAutoDownload,
                control: ToggleControl(
                  value: ref.watch(
                    uiSettingsProvider.select((s) => s.autoDownloadWifi),
                  ),
                  onChanged: (value) => ref
                      .read(uiSettingsProvider.notifier)
                      .setAutoDownloadWifi(value),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return SettingsResponsiveShell(
      title: context.l10n.settingsV2Storage,
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
              context.l10n.settingsV2StorageError,
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
        SettingsSection(
          children: [
            SettingsRow(
              leading: const Icon(Icons.folder_rounded),
              title: context.l10n.settingsStorageCategoryAppData,
              control: ValueControl(_format(appDataBytes)),
            ),
            SettingsRow(
              anchor: 'cache_cleaning',
              leading: const Icon(Icons.cached_rounded),
              title: context.l10n.settingsStorageClearTemporary,
              subtitle: _format(cacheBytes),
              control: const ActionControl(destructive: true),
              enabled: cacheBytes > 0 && !_busy,
              onTap: _clearTemporaryFiles,
            ),
            SettingsRow(
              leading: const Icon(Icons.edit_note_rounded),
              title: context.l10n.settingsStorageClearDrafts,
              subtitle: _format(draftBytes),
              control: const ActionControl(destructive: true),
              enabled: draftBytes > 0 && !_busy,
              onTap: _clearDrafts,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Категории файлов в хранилище
        SettingsSection(
          title: context.l10n.settingsV2StorageDetails,
          subtitle: context.l10n.settingsV2StorageDetailsHint,
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
                title: _categoryLabel(context, cat),
                control: ValueControl(_format(bytes)),
                onTap: bytes > 0 && !_busy ? () => _clearCategory(cat) : null,
              );
            }),
          ],
        ),

        // 1. Media Auto-Download
        SettingsSection(
          title: context.l10n.settingsV2AutoDownload,
          subtitle: context.l10n.settingsV2AutoDownloadHint,
          children: <Widget>[
            SettingsRow(
              anchor: 'auto_download_wifi',
              leading: Icon(Icons.wifi_rounded, color: scheme.primary),
              title: kIsWeb
                  ? context.l10n.webAutoDownload
                  : context.l10n.settingsV2Wifi,
              subtitle: context.l10n.settingsChatsAutoDownloadWifiDesc,
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
            if (!kIsWeb)
              SettingsRow(
                anchor: 'auto_download_cellular',
                leading: Icon(
                  Icons.signal_cellular_alt_rounded,
                  color: scheme.primary,
                ),
                title: context.l10n.settingsV2MobileData,
                subtitle: context.l10n.settingsV2MobileDataHint,
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
          ],
        ),

        // 4. Secret chats and encryption (E2EE)
        SettingsSection(
          title: context.l10n.settingsV2SecretCache,
          subtitle: context.l10n.settingsV2SecretCacheHint,
          children: <Widget>[
            SettingsRow(
              leading: Icon(Icons.lock_reset_rounded, color: scheme.error),
              title: context.l10n.settingsV2ClearSecretCache,
              subtitle: context.l10n.settingsV2SecretCacheHint,
              control: const ActionControl(destructive: true),
              enabled: !_busy,
              onTap: _clearE2eeCache,
            ),
          ],
        ),
      ],
    );
  }

  String _categoryLabel(BuildContext context, StorageCategory category) =>
      switch (category) {
        StorageCategory.images => context.l10n.settingsV2StorageImages,
        StorageCategory.videos => context.l10n.settingsV2StorageVideos,
        StorageCategory.audio => context.l10n.settingsV2StorageAudio,
        StorageCategory.files => context.l10n.settingsV2StorageFiles,
        StorageCategory.stickers => context.l10n.settingsV2StorageStickers,
        StorageCategory.avatars => context.l10n.settingsV2StorageAvatars,
        StorageCategory.drafts => context.l10n.settingsV2StorageDrafts,
        StorageCategory.secretChatCache => context.l10n.settingsV2SecretCache,
        StorageCategory.other => context.l10n.settingsV2StorageOther,
      };

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
  const _LegendItem({required this.color, required this.label});

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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
