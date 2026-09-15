import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/services/update/app_update_service.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// Screen displaying the complete changelog history using lazy [ListView.builder].
class AboutChangelogScreen extends StatefulWidget {
  const AboutChangelogScreen({super.key});

  @override
  State<AboutChangelogScreen> createState() => _AboutChangelogScreenState();
}

class _AboutChangelogScreenState extends State<AboutChangelogScreen> {
  List<ChangelogRelease>? _releases;
  bool _isLoading = true;
  final Set<int> _expandedIndices = <int>{0};

  @override
  void initState() {
    super.initState();
    _loadChangelog();
  }

  Future<void> _loadChangelog() async {
    try {
      final String raw = await rootBundle.loadString('assets/CHANGELOG.md');
      final List<ChangelogRelease> parsed = AppUpdateService.parseAllReleases(raw);
      if (mounted) {
        setState(() {
          _releases = parsed;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          context.l10n.aboutTabWhatsNew,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: AppLoadingIndicator(
                size: 28,
                color: scheme.primary,
              ),
            )
          : (_releases == null || _releases!.isEmpty)
              ? Center(
                  child: Text(
                    context.l10n.aboutUpToDate,
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _releases!.length,
                  itemBuilder: (BuildContext context, int index) {
                    final ChangelogRelease release = _releases![index];
                    final bool isLatest = index == 0;
                    final bool isExpanded = _expandedIndices.contains(index);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: scheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadii.of(context).mdRadius,
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: InkWell(
                          onTap: () {
                            HapticService.selection();
                            setState(() {
                              if (isExpanded) {
                                _expandedIndices.remove(index);
                              } else {
                                _expandedIndices.add(index);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isLatest
                                            ? scheme.primaryContainer
                                            : scheme.surfaceContainerHighest,
                                        borderRadius: AppRadii.of(context).smRadius,
                                      ),
                                      child: Icon(
                                        isLatest
                                            ? Icons.auto_awesome_rounded
                                            : Icons.history_rounded,
                                        color: isLatest
                                            ? scheme.primary
                                            : scheme.onSurfaceVariant,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Wrap(
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: <Widget>[
                                              Text(
                                                'v${release.version}',
                                                style: textTheme.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  color: scheme.onSurface,
                                                ),
                                              ),
                                              if (isLatest)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: scheme.primary.withValues(alpha: 0.15),
                                                    borderRadius: AppRadii.of(context).fullRadius,
                                                  ),
                                                  child: Text(
                                                    context.l10n.aboutCurrentVersionBadge,
                                                    style: textTheme.labelSmall?.copyWith(
                                                      color: scheme.primary,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          if (release.date != null) ...<Widget>[
                                            const SizedBox(height: 2),
                                            Text(
                                              release.date!,
                                              style: textTheme.bodySmall?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isExpanded
                                          ? Icons.expand_less_rounded
                                          : Icons.expand_more_rounded,
                                      color: scheme.onSurfaceVariant,
                                      size: 20,
                                    ),
                                  ],
                                ),
                                if (isExpanded) ...<Widget>[
                                  const SizedBox(height: 12),
                                  ...release.changes.map((String change) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6, right: 8),
                                            child: Container(
                                              width: 5,
                                              height: 5,
                                              decoration: BoxDecoration(
                                                color: scheme.primary,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              change,
                                              style: textTheme.bodySmall?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
