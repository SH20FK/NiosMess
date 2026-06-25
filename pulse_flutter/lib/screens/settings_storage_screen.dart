import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/storage/encrypted_message_cache.dart';
import 'package:pulse_flutter/core/storage/local_storage_service.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SettingsStorageScreen extends ConsumerStatefulWidget {
  const SettingsStorageScreen({super.key});

  @override
  ConsumerState<SettingsStorageScreen> createState() =>
      _SettingsStorageScreenState();
}

class _SettingsStorageScreenState extends ConsumerState<SettingsStorageScreen> {
  late Future<LocalStorageSnapshot> _snapshotFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshot();
  }

  Future<LocalStorageSnapshot> _loadSnapshot() {
    return ref.read(localStorageServiceProvider).snapshot();
  }

  void _refresh() {
    if (_busy) return;
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
  }

  Future<void> _clearTemporaryFiles() async {
    final bool confirmed = await _confirm(
      title: context.l10n.settingsStorageClearTemporaryConfirmTitle,
      body: context.l10n.settingsStorageClearTemporaryConfirmBody,
    );
    if (!confirmed) return;
    await _runStorageAction(() async {
      await ref.read(localStorageServiceProvider).clearTemporaryFiles();
      await EncryptedMessageCache.clearAll();
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

  Future<void> _runStorageAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.settingsStorageCleared)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm({required String title, required String body}) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => SettingsConfirmDialog(
        title: title,
        body: body,
        confirmLabel: context.l10n.commonDelete,
        cancelLabel: context.l10n.commonCancel,
        destructive: true,
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SettingsScaffold(
      title: context.l10n.settingsStorageTitle,
      children: <Widget>[
        SettingsNavBanner(
          icon: Icons.storage_rounded,
          title: context.l10n.settingsStorageTitle,
          subtitle: 'Использование памяти, кеша и черновиков приложения.',
          iconColor: scheme.primary,
        ),
        FutureBuilder<LocalStorageSnapshot>(
          future: _snapshotFuture,
          builder: (
            BuildContext context,
            AsyncSnapshot<LocalStorageSnapshot> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: PulseLoadingIndicator()),
              );
            }

            final LocalStorageSnapshot data =
                snapshot.data ?? const LocalStorageSnapshot.empty();

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
                    borderRadius: BorderRadius.circular(28),
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
                            tooltip: 'Refresh',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SegmentedProgressBar(
                        appDataBytes: appDataBytes,
                        cacheBytes: cacheBytes,
                        draftBytes: draftBytes,
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
                          _LegendItem(color: scheme.tertiary, label: 'Cache'),
                          _LegendItem(color: scheme.secondary, label: 'Drafts'),
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
                      title: 'App Data',
                      value: _format(appDataBytes),
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 10),
                    _StorageCategoryCard(
                      icon: Icons.cached_rounded,
                      title: 'Cache',
                      value: _format(cacheBytes),
                      color: scheme.tertiary,
                      onDelete: cacheBytes > 0 && !_busy ? _clearTemporaryFiles : null,
                      deleteTooltip: context.l10n.settingsStorageClearTemporary,
                    ),
                    const SizedBox(width: 10),
                    _StorageCategoryCard(
                      icon: Icons.edit_note_rounded,
                      title: 'Drafts',
                      value: _format(draftBytes),
                      color: scheme.secondary,
                      onDelete: draftBytes > 0 && !_busy ? _clearDrafts : null,
                      deleteTooltip: context.l10n.settingsStorageClearDrafts,
                    ),
                  ],
                ),
              ],
            );
          },
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
        borderRadius: BorderRadius.circular(22),
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
                        borderRadius: BorderRadius.circular(16),
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
                top: 6,
                right: 6,
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: scheme.error.withValues(alpha: 0.84),
                      size: 16,
                    ),
                    onPressed: onDelete,
                    tooltip: deleteTooltip,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
