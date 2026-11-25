import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/storage/local_storage_service.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/features/settings/domain/settings_control.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/models/settings/auto_download.dart';
import 'package:pulse_flutter/providers/notification_preferences_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/settings/settings_async_switcher.dart';
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

  Future<void> _refresh() async {
    if (!mounted || _busy) return;
    await ref
        .read(storageSnapshotProvider.notifier)
        .refresh(forceRefresh: true);
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

  Future<void> _resetPreferences() async {
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: context.l10n.settingsV2ResetConfirm,
      subtitle: context.l10n.settingsV2ResetBody,
      confirmLabel: context.l10n.settingsV2Reset,
      cancelLabel: context.l10n.commonCancel,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(uiSettingsProvider.notifier).resetAll();
      // Notification categories live under their own per-account key.
      await ref.read(notificationPreferencesProvider.notifier).reset();
      if (mounted) {
        AppToast.showSuccess(context, context.l10n.settingsV2ResetDone);
      }
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, context.l10n.settingsV2ResetFailed);
      }
    }
  }

  Future<void> _runStorageAction(Future<int?> Function() action) async {
    if (!mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      await ref
          .read(storageSnapshotProvider.notifier)
          .refresh(forceRefresh: true);
      if (!mounted) return;
      AppToast.showSuccess(context, context.l10n.settingsStorageCleared);
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, context.l10n.settingsV2StorageError);
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
      // Temporary files and drafts are cleared, not deleted like a chat.
      confirmLabel: context.l10n.settingsStorageClearAction,
      cancelLabel: context.l10n.commonCancel,
      destructive: true,
    );
    return mounted && result == true;
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
                padding: const EdgeInsets.all(AppSpacing.lg),
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
          // A browser still separates photos from videos: one switch for both
          // would leave the type it does not touch unreachable.
          SettingsSection(
            title: context.l10n.autoDownloadPhotos,
            children: <Widget>[
              _autoDownloadRow(
                anchor: 'auto_download_wifi',
                type: AutoDownloadMediaType.photo,
                network: AutoDownloadNetwork.wifi,
                icon: Icons.image_rounded,
                web: true,
              ),
            ],
          ),
          SettingsSection(
            title: context.l10n.autoDownloadVideos,
            children: <Widget>[
              _autoDownloadRow(
                anchor: 'auto_download_video_wifi',
                type: AutoDownloadMediaType.video,
                network: AutoDownloadNetwork.wifi,
                icon: Icons.video_library_rounded,
                web: true,
              ),
            ],
          ),
          _performanceSection(context),
          _resetSection(context),
        ],
      );
    }

    return SettingsShell(
      title: context.l10n.settingsV2Storage,
      isEmbedded: widget.isEmbedded,
      onRefresh: _refresh,
      children: [
        SettingsAsyncSwitcher(
          value: snapshotAsync,
          data: (data) => _buildContent(context, scheme, textTheme, data),
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: AppLoadingIndicator(
                semanticsLabel: context.l10n.commonLoading,
              ),
            ),
          ),
          error: (_, _) => SettingsSection(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.l10n.settingsV2StorageError,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(context.l10n.commonRetry),
                    ),
                  ],
                ),
              ),
            ],
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
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(
                SettingsSection.outerRadius(context),
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
                          const SizedBox(height: AppSpacing.xs),
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
                const SizedBox(height: AppSpacing.md),
                Text(
                  context.l10n.settingsStorageEstimate,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
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
                const SizedBox(height: AppSpacing.md),
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
        SettingsSection(
          subtitle: context.l10n.settingsStorageSafeCleanup,
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
              disabledReason: cacheBytes > 0
                  ? null
                  : context.l10n.settingsStorageNothingToClear,
              onTap: _clearTemporaryFiles,
            ),
            SettingsRow(
              leading: const Icon(Icons.edit_note_rounded),
              title: context.l10n.settingsStorageClearDrafts,
              subtitle: _format(draftBytes),
              control: const ActionControl(destructive: true),
              enabled: draftBytes > 0 && !_busy,
              disabledReason: draftBytes > 0
                  ? null
                  : context.l10n.settingsStorageNothingToClear,
              onTap: _clearDrafts,
            ),
          ],
        ),

        // Categories are a breakdown, not permission to delete documents.
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
              );
            }),
          ],
        ),

        // 1. Media Auto-Download: photos and videos keep their own rules.
        SettingsSection(
          title: context.l10n.autoDownloadPhotos,
          children: <Widget>[
            _autoDownloadRow(
              anchor: 'auto_download_wifi',
              type: AutoDownloadMediaType.photo,
              network: AutoDownloadNetwork.wifi,
              icon: Icons.wifi_rounded,
            ),
            if (!kIsWeb)
              _autoDownloadRow(
                anchor: 'auto_download_cellular',
                type: AutoDownloadMediaType.photo,
                network: AutoDownloadNetwork.cellular,
                icon: Icons.signal_cellular_alt_rounded,
              ),
          ],
        ),
        if (!kIsWeb)
          SettingsSection(
            title: context.l10n.autoDownloadVideos,
            children: <Widget>[
              _autoDownloadRow(
                anchor: 'auto_download_video_wifi',
                type: AutoDownloadMediaType.video,
                network: AutoDownloadNetwork.wifi,
                icon: Icons.wifi_rounded,
              ),
              _autoDownloadRow(
                anchor: 'auto_download_video_cellular',
                type: AutoDownloadMediaType.video,
                network: AutoDownloadNetwork.cellular,
                icon: Icons.signal_cellular_alt_rounded,
              ),
            ],
          ),
        _performanceSection(context),
        _resetSection(context),
      ],
    );
  }

  Widget _resetSection(BuildContext context) => SettingsSection(
    children: [
      SettingsAnchor(
        id: 'storage.reset',
        child: SettingsListItem.danger(
          key: const ValueKey('settings-reset-preferences'),
          icon: Icons.restart_alt_rounded,
          title: context.l10n.settingsV2Reset,
          subtitle: context.l10n.settingsV2ResetHint,
          onTap: _resetPreferences,
        ),
      ),
    ],
  );

  Widget _performanceSection(BuildContext context) => SettingsSection(
    title: context.l10n.settingsV2Graphics,
    children: [
      SettingsAnchor(
        id: 'motion.optimization',
        child: SettingsListItem.toggle(
          icon: Icons.speed_rounded,
          title: context.l10n.appearanceOptimizeWeakDevices,
          subtitle: context.l10n.settingsV2OptimizeHint,
          value: ref.watch(
            uiSettingsProvider.select((s) => s.optimizeForWeakDevices),
          ),
          onChanged: ref
              .read(uiSettingsProvider.notifier)
              .setOptimizeForWeakDevices,
        ),
      ),
    ],
  );

  /// One network switch of a per-type auto-download group.
  Widget _autoDownloadRow({
    required String anchor,
    required AutoDownloadMediaType type,
    required AutoDownloadNetwork network,
    required IconData icon,
    bool web = false,
  }) => SettingsRow(
    anchor: anchor,
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: web
        ? context.l10n.autoDownloadAutomatic
        : network == AutoDownloadNetwork.wifi
        ? context.l10n.settingsV2Wifi
        : context.l10n.settingsV2MobileData,
    // Mobile traffic is the one choice people regret, so it says so.
    subtitle: !web && network == AutoDownloadNetwork.cellular
        ? context.l10n.settingsV2MobileDataHint
        : null,
    control: ToggleControl(
      value: ref.watch(
        uiSettingsProvider.select((s) => s.autoDownloadFor(type, network)),
      ),
      onChanged: (bool value) => ref
          .read(uiSettingsProvider.notifier)
          .setAutoDownload(type, network, value),
    ),
  );

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
