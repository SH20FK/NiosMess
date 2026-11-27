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

  /// The one reset the app already offers, reached from the page that shows
  /// what it changes: confirm, write, report. The same global reset is also
  /// reachable from the other settings screen; both are honest about a
  /// partial result.
  ///
  /// [UiSettingsNotifier.resetAll] answers how many keys the disk refused to
  /// drop, so a reset that only half landed is reported as partial instead of
  /// claiming success over preferences that will come back on the next launch.
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
      final int leftover = await ref
          .read(uiSettingsProvider.notifier)
          .resetAll();
      // Notification categories live under their own per-account key.
      await ref.read(notificationPreferencesProvider.notifier).reset();
      if (!mounted) return;
      if (leftover > 0) {
        AppToast.showInfo(context, context.l10n.settingsStorageResetPartial);
      } else {
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
    if (kIsWeb) return _buildWeb(context);

    final AsyncValue<LocalStorageSnapshot> snapshotAsync = ref.watch(
      storageSnapshotProvider,
    );

    return SettingsShell(
      title: context.l10n.settingsV2Storage,
      isEmbedded: widget.isEmbedded,
      onRefresh: _refresh,
      children: <Widget>[
        SettingsAsyncSwitcher(
          value: snapshotAsync,
          data: (LocalStorageSnapshot data) => _buildSnapshot(context, data),
          // Placeholder rows, not a spinner: the page keeps its shape while the
          // scan runs and no value is invented before it is measured.
          loading: () => const SettingsSection(
            children: <Widget>[SettingsSkeleton(rows: 3)],
          ),
          error: (_, _) => SettingsErrorSection(
            title: context.l10n.settingsV2Storage,
            message: context.l10n.settingsV2StorageError,
            onRetry: _refresh,
          ),
        ),
      ],
    );
  }

  /// A browser owns the storage: there is no disk total to put in a hero, so
  /// the page leads with what it can measure — the drafts kept in this browser.
  Widget _buildWeb(BuildContext context) {
    final AsyncValue<LocalStorageSnapshot> snapshotAsync = ref.watch(
      storageSnapshotProvider,
    );

    return SettingsShell(
      title: context.l10n.settingsV2Storage,
      isEmbedded: widget.isEmbedded,
      // The page has no refresh control of its own: pulling the list is the
      // one way to re-read the numbers, on the browser as on the phone.
      onRefresh: _refresh,
      children: <Widget>[
        _webStorageSection(context, snapshotAsync),
        ..._autoDownloadSections(context, web: true),
        _performanceSection(context),
        _resetSection(context),
      ],
    );
  }

  Widget _webStorageSection(
    BuildContext context,
    AsyncValue<LocalStorageSnapshot> snapshotAsync,
  ) {
    final l10n = context.l10n;
    final Widget draftRow = snapshotAsync.when(
      data: (LocalStorageSnapshot data) => SettingsRow(
        title: l10n.webStorageDrafts,
        control: ValueControl('${data.draftCount}'),
        subtitle: l10n.webStorageDraftsDescription,
      ),
      error: (_, _) => SettingsRow(
        title: l10n.webStorageDrafts,
        control: ValueControl(l10n.settingsDeviceUnknown),
        subtitle: l10n.webStorageDraftsDescription,
      ),
      // The count is unknown until it is read: a skeleton says so, an invented
      // zero would not.
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: SettingsSkeleton(rows: 1, showLeading: false),
      ),
    );

    return SettingsSection(
      title: l10n.webStorageTitle,
      subtitle: l10n.webStorageDescription,
      accentIcon: Icons.public_rounded,
      children: <Widget>[draftRow],
    );
  }

  Widget _buildSnapshot(BuildContext context, LocalStorageSnapshot data) {
    final int appDataBytes = data.documentsBytes + data.supportBytes;
    final int cacheBytes = data.temporaryBytes;
    final int draftBytes = data.draftBytes;
    // A category holding nothing says nothing: the hero already totals the
    // empty part, so the breakdown lists only what actually occupies space.
    final List<StorageCategory> categories = StorageCategory.values
        .where((StorageCategory cat) => data.bytesFor(cat) > 0)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StorageHero(
          totalBytes: data.totalBytes,
          appDataBytes: appDataBytes,
          cacheBytes: cacheBytes,
          draftBytes: draftBytes,
        ),
        SettingsSection(
          title: context.l10n.settingsStorageActions,
          subtitle: context.l10n.settingsStorageSafeCleanup,
          accentIcon: Icons.cleaning_services_rounded,
          children: <Widget>[
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
        if (categories.isNotEmpty)
          SettingsSection(
            title: context.l10n.settingsV2StorageDetails,
            subtitle: context.l10n.settingsV2StorageDetailsHint,
            accentIcon: Icons.pie_chart_outline_rounded,
            children: <Widget>[
              for (final StorageCategory cat in categories)
                SettingsRow(
                  leading: Icon(_categoryIcon(cat)),
                  title: _categoryLabel(context, cat),
                  control: ValueControl(_format(data.bytesFor(cat))),
                ),
            ],
          ),

        ..._autoDownloadSections(context, web: false),
        _performanceSection(context),
        _resetSection(context),
      ],
    );
  }

  /// Media auto-download as one 2×2 matrix: each media type gets its Wi-Fi
  /// and its cellular switch in the same group, instead of two groups of the
  /// same shape. The browser has no cellular rule, so it keeps one automatic
  /// switch per type.
  List<Widget> _autoDownloadSections(
    BuildContext context, {
    required bool web,
  }) => <Widget>[
    SettingsSection(
      title: context.l10n.settingsStorageAutoDownloadMedia,
      // The cellular switches are the only ones that can cost money, so the
      // group says it once instead of repeating it in every row.
      subtitle: web ? null : context.l10n.settingsV2MobileDataHint,
      accentIcon: Icons.download_rounded,
      children: <Widget>[
        _autoDownloadRow(
          anchor: 'auto_download_wifi',
          type: AutoDownloadMediaType.photo,
          network: AutoDownloadNetwork.wifi,
          icon: Icons.image_rounded,
          web: web,
        ),
        if (!web)
          _autoDownloadRow(
            anchor: 'auto_download_cellular',
            type: AutoDownloadMediaType.photo,
            network: AutoDownloadNetwork.cellular,
            icon: Icons.image_rounded,
          ),
        _autoDownloadRow(
          anchor: 'auto_download_video_wifi',
          type: AutoDownloadMediaType.video,
          network: AutoDownloadNetwork.wifi,
          icon: Icons.video_library_rounded,
          web: web,
        ),
        if (!web)
          _autoDownloadRow(
            anchor: 'auto_download_video_cellular',
            type: AutoDownloadMediaType.video,
            network: AutoDownloadNetwork.cellular,
            icon: Icons.video_library_rounded,
          ),
      ],
    ),
  ];

  Widget _resetSection(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SettingsSection(
      title: context.l10n.settingsV2ResetSection,
      accentIcon: Icons.restart_alt_rounded,
      accentColor: scheme.errorContainer,
      accentForeground: scheme.onErrorContainer,
      children: <Widget>[
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
  }

  Widget _performanceSection(BuildContext context) => SettingsSection(
    title: context.l10n.settingsV2Graphics,
    accentIcon: Icons.speed_rounded,
    children: <Widget>[
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

  /// One switch of the 2×2 auto-download matrix: a media type on one network.
  Widget _autoDownloadRow({
    required String anchor,
    required AutoDownloadMediaType type,
    required AutoDownloadNetwork network,
    required IconData icon,
    bool web = false,
  }) => SettingsRow(
    anchor: anchor,
    leading: Icon(icon),
    title: type == AutoDownloadMediaType.photo
        ? context.l10n.settingsV2StorageImages
        : context.l10n.settingsV2StorageVideos,
    subtitle: web
        ? context.l10n.autoDownloadAutomatic
        : network == AutoDownloadNetwork.wifi
        ? context.l10n.settingsV2Wifi
        : context.l10n.settingsV2MobileData,
    control: ToggleControl(
      value: ref.watch(
        uiSettingsProvider.select((s) => s.autoDownloadFor(type, network)),
      ),
      onChanged: (bool value) => ref
          .read(uiSettingsProvider.notifier)
          .setAutoDownload(type, network, value),
    ),
  );

  static IconData _categoryIcon(StorageCategory cat) => switch (cat) {
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

/// The opening panel: what the app occupies, split into the three parts the
/// cleanup actions can touch. The figure is the point of the page, so it is
/// the one place with display type. The panel carries no controls: the page
/// is re-read by pulling it, so it never offers two ways to refresh.
class _StorageHero extends StatelessWidget {
  const _StorageHero({
    required this.totalBytes,
    required this.appDataBytes,
    required this.cacheBytes,
    required this.draftBytes,
  });

  final int totalBytes;
  final int appDataBytes;
  final int cacheBytes;
  final int draftBytes;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: SettingsHeroCard(
        label: context.l10n.settingsStorageTitle,
        leadingIcon: Icons.storage_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Scale the figure down instead of clipping it when a large text
            // size meets a narrow pane.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  FileTypeDetector.formatFileSize(totalBytes),
                  maxLines: 1,
                  style: text.displaySmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.settingsStorageUsedByApp,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              label:
                  '${context.l10n.settingsStorageAppData}: '
                  '${FileTypeDetector.formatFileSize(appDataBytes)}, '
                  '${context.l10n.settingsStorageLegendCache}: '
                  '${FileTypeDetector.formatFileSize(cacheBytes)}, '
                  '${context.l10n.settingsStorageLegendDrafts}: '
                  '${FileTypeDetector.formatFileSize(draftBytes)}',
              child: _SegmentedProgressBar(
                appDataBytes: appDataBytes,
                cacheBytes: cacheBytes,
                draftBytes: draftBytes,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
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
            const SizedBox(height: AppSpacing.md),
            Text(
              context.l10n.settingsStorageEstimate,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
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
    // One clip for the whole bar: the segments have to lose their corners
    // against the track, and there is only ever one of these per page.
    final BorderRadius radius = BorderRadius.circular(
      AppRadii.of(context).xs.clamp(4.0, 8.0),
    );

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: 12,
        child: ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: total == 0
              ? const SizedBox.expand()
              : Row(
                  children: <Widget>[
                    if (appDataBytes > 0)
                      Expanded(
                        flex: (appDataBytes / total * 1000).round().clamp(
                          1,
                          1000,
                        ),
                        child: ColoredBox(
                          color: scheme.primary,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    if (cacheBytes > 0)
                      Expanded(
                        flex: (cacheBytes / total * 1000).round().clamp(
                          1,
                          1000,
                        ),
                        child: ColoredBox(
                          color: scheme.tertiary,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    if (draftBytes > 0)
                      Expanded(
                        flex: (draftBytes / total * 1000).round().clamp(
                          1,
                          1000,
                        ),
                        child: ColoredBox(
                          color: scheme.secondary,
                          child: const SizedBox.expand(),
                        ),
                      ),
                  ],
                ),
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
        DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox.square(dimension: 8),
        ),
        const SizedBox(width: 6),
        // Flexible: at 180 % text a legend entry is wider than the wrap line
        // it sits on, so it wraps instead of overflowing the card.
        Flexible(
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
