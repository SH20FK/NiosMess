import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/storage/local_storage_service.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

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
    await _runStorageAction(
      () => ref.read(localStorageServiceProvider).clearTemporaryFiles(),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.settingsStorageCleared)),
      );
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
          subtitle: context.l10n.settingsStorageBreakdownSubtitle,
          iconColor: Colors.green,
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
                // Сводная карточка использования хранилища (Dashboard-стиль)
                Material(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
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
                              color: Colors.green,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.green.withValues(alpha: 0.12),
                              ),
                              tooltip: 'Refresh',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Сегментированный прогресс-бар
                        _SegmentedProgressBar(
                          appDataBytes: appDataBytes,
                          cacheBytes: cacheBytes,
                          draftBytes: draftBytes,
                        ),
                        const SizedBox(height: 10),
                        // Легенда
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            _LegendItem(color: Colors.blue, label: context.l10n.settingsStorageAppData),
                            const _LegendItem(color: Colors.orange, label: 'Cache'),
                            const _LegendItem(color: Colors.purple, label: 'Drafts'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Интерактивный ряд плиток категорий
                Row(
                  children: <Widget>[
                    _StorageCategoryCard(
                      icon: Icons.folder_rounded,
                      title: 'App Data',
                      value: _format(appDataBytes),
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _StorageCategoryCard(
                      icon: Icons.cached_rounded,
                      title: 'Cache',
                      value: _format(cacheBytes),
                      color: Colors.orange,
                      onDelete: cacheBytes > 0 && !_busy ? _clearTemporaryFiles : null,
                      deleteTooltip: context.l10n.settingsStorageClearTemporary,
                    ),
                    const SizedBox(width: 8),
                    _StorageCategoryCard(
                      icon: Icons.edit_note_rounded,
                      title: 'Drafts',
                      value: _format(draftBytes),
                      color: Colors.purple,
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
    final int total = appDataBytes + cacheBytes + draftBytes;
    if (total == 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 10,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      );
    }

    final double appDataWeight = appDataBytes / total;
    final double cacheWeight = cacheBytes / total;
    final double draftWeight = draftBytes / total;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: Row(
          children: <Widget>[
            if (appDataBytes > 0)
              Expanded(
                flex: (appDataWeight * 1000).round().clamp(1, 1000),
                child: Container(color: Colors.blue),
              ),
            if (cacheBytes > 0)
              Expanded(
                flex: (cacheWeight * 1000).round().clamp(1, 1000),
                child: Container(color: Colors.orange),
              ),
            if (draftBytes > 0)
              Expanded(
                flex: (draftWeight * 1000).round().clamp(1, 1000),
                child: Container(color: Colors.purple),
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
          style: textTheme.labelSmall?.copyWith(fontSize: 10, fontWeight: FontWeight.w500),
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
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 1),
                    Text(
                      title,
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
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
                top: 4,
                right: 4,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: scheme.error.withValues(alpha: 0.7),
                      size: 15,
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
