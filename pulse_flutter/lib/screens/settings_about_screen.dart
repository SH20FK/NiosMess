import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/constants/build_info.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/providers/ota_update_provider.dart';
import 'package:pulse_flutter/repositories/support_repository.dart';
import 'package:pulse_flutter/services/update/app_update_service.dart';
import 'package:pulse_flutter/widgets/alpha_test_dialog.dart';
import 'package:pulse_flutter/widgets/chat/md3_squiggle_progress.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/update/app_update_dialog.dart';

/// Screen "About Application" in Material 3 Expressive style.
///
/// Features:
/// - Single source of truth for versioning ([BuildInfo] & [PackageInfo]).
/// - Real parsed changelog from bundled `assets/CHANGELOG.md` with zero fake entries.
/// - Isolated OTA update card with 7 reactive states and squiggle progress bar.
/// - Interactive shape-morphing logo Easter Egg.
/// - 3 structured tabs (What's New, Legal, Team) with [AnimatedSize] height adaptivity.
/// - 100% localization coverage and complete Semantics accessibility.
class SettingsAboutScreen extends ConsumerStatefulWidget {
  const SettingsAboutScreen({
    this.isEmbedded = false,
    super.key,
  });

  final bool isEmbedded;

  @override
  ConsumerState<SettingsAboutScreen> createState() => _SettingsAboutScreenState();
}

class _SettingsAboutScreenState extends ConsumerState<SettingsAboutScreen> {
  late final Future<PackageInfo> _packageInfo;
  int _selectedTabIndex = 0;
  List<ChangelogRelease>? _cachedReleases;
  bool _isLoadingChangelog = false;

  @override
  void initState() {
    super.initState();
    _packageInfo = PackageInfo.fromPlatform();
    _loadChangelog();
  }

  Future<void> _loadChangelog() async {
    if (_cachedReleases != null || _isLoadingChangelog) return;
    setState(() => _isLoadingChangelog = true);

    try {
      final String rawChangelog =
          await rootBundle.loadString('assets/CHANGELOG.md');
      final List<ChangelogRelease> releases =
          AppUpdateService.parseAllReleases(rawChangelog);
      if (mounted) {
        setState(() {
          _cachedReleases = releases;
          _isLoadingChangelog = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingChangelog = false);
      }
    }
  }

  Future<void> _openUrl(String url) async {
    await AppUrlLauncher.openUrl(context, url);
  }

  void _copyVersion(String version) {
    Clipboard.setData(ClipboardData(text: version));
    HapticService.tap();
    AppToast.showSuccess(context, context.l10n.aboutVersionCopied(version));
  }

  void _shareApp() {
    HapticService.tap();
    SharePlus.instance.share(
      ShareParams(
        text: '${context.l10n.appName} — ${context.l10n.aboutTagline}\n${AppConstants.webOrigin}',
        subject: context.l10n.appName,
      ),
    );
  }

  void _showBugReportDialog(BuildContext context) {
    HapticService.tap();
    final TextEditingController subjectController = TextEditingController();
    final TextEditingController bodyController = TextEditingController();
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final ColorScheme scheme = Theme.of(context).colorScheme;
            final TextTheme textTheme = Theme.of(context).textTheme;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              icon: Icon(
                Icons.bug_report_rounded,
                size: 32,
                color: scheme.primary,
              ),
              title: Text(
                context.l10n.aboutReportBugAction,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: subjectController,
                      decoration: InputDecoration(
                        labelText: context.l10n.aboutReportSubject,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bodyController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: context.l10n.aboutReportDescription,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: <Widget>[
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text(context.l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final String subj = subjectController.text.trim();
                          final String desc = bodyController.text.trim();
                          if (subj.isEmpty || desc.isEmpty) return;

                          setDialogState(() => isSubmitting = true);
                          try {
                            await ref.read(supportRepositoryProvider).createTicket(
                                  ticketType: 'bug',
                                  subject: subj,
                                  body: desc,
                                );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                              AppToast.showSuccess(
                                context,
                                context.l10n.aboutReportSuccess,
                              );
                            }
                          } catch (_) {
                            if (dialogContext.mounted) {
                              setDialogState(() => isSubmitting = false);
                              AppToast.showError(
                                context,
                                context.l10n.aboutReportError,
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? AppLoadingIndicator(size: 16, color: scheme.onPrimary)
                      : Text(context.l10n.commonSave),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SettingsShell(
      title: context.l10n.settingsAboutTitle,
      isEmbedded: widget.isEmbedded,
      children: <Widget>[
        // 1. Material 3 Expressive Hero Card with Morphing Logo
        _buildHeroCard(context, scheme, textTheme),
        const SizedBox(height: 14),

        // 2. Completely Isolated OTA Update Card (zero rebuild leakage)
        const _OtaUpdateCardWidget(),
        const SizedBox(height: 16),

        // 3. Native 3-Segment Tab Selector
        _buildSegmentedTabSelector(context, scheme, textTheme),
        const SizedBox(height: 16),

        // 4. Tab Content with AnimatedSize and M3 Spring transitions
        _buildCurrentTabContent(context, scheme, textTheme),
        const SizedBox(height: 14),

        // 5. Authentic M3 Minimalist Footer
        _buildFooter(context, scheme, textTheme),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Material 3 Expressive Hero Card
  // ---------------------------------------------------------------------------
  Widget _buildHeroCard(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        child: Column(
          children: <Widget>[
            // Interactive shape-morphing hero logo
            _InteractiveHeroLogo(scheme: scheme),
            const SizedBox(height: 14),

            // App Name
            Text(
              context.l10n.appName,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                fontSize: 22,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),

            // Tagline
            Text(
              context.l10n.aboutTagline,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),

            // Copyable Version Badge
            FutureBuilder<PackageInfo>(
              future: _packageInfo,
              builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
                final String ver = snapshot.data != null
                    ? 'v${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                    : BuildInfo.fullVersion;
                return Semantics(
                  button: true,
                  label: context.l10n.aboutVersionCopied(ver),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _copyVersion(ver),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              ver,
                              style: textTheme.labelMedium?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.copy_rounded,
                              size: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Quick Action M3 Tonal Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: <Widget>[
                _M3ActionChip(
                  icon: Icons.bug_report_rounded,
                  label: context.l10n.aboutReportBugAction,
                  onTap: () => _showBugReportDialog(context),
                ),
                _M3ActionChip(
                  icon: Icons.help_outline_rounded,
                  label: context.l10n.aboutFaqAction,
                  onTap: () => context.push('/help/faq'),
                ),
                _M3ActionChip(
                  icon: Icons.share_rounded,
                  label: context.l10n.aboutShareAction,
                  onTap: _shareApp,
                ),
                _M3ActionChip(
                  icon: Icons.science_rounded,
                  label: context.l10n.aboutAlphaTestAction,
                  onTap: () => AlphaTestDialog.show(context),
                ),
                if (!kIsWeb)
                  _M3ActionChip(
                    icon: Icons.smartphone_rounded,
                    label: context.l10n.aboutDeviceAction,
                    onTap: () => context.push('/settings/system-device'),
                  ),
                _M3ActionChip(
                  svgAsset: 'assets/svg/telegram_logo.svg',
                  label: 'Telegram',
                  onTap: () => _openUrl('https://t.me/niosmess'),
                ),
                _M3ActionChip(
                  svgAsset: 'assets/svg/globe.svg',
                  label: 'ni-os.ru',
                  onTap: () => _openUrl('https://ni-os.ru'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Material 3 SegmentedButton Tab Selector
  // ---------------------------------------------------------------------------
  Widget _buildSegmentedTabSelector(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<int>(
        segments: <ButtonSegment<int>>[
          ButtonSegment<int>(
            value: 0,
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(
              context.l10n.aboutTabWhatsNew,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          ButtonSegment<int>(
            value: 1,
            icon: const Icon(Icons.gavel_rounded, size: 18),
            label: Text(
              context.l10n.aboutTabLegal,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          ButtonSegment<int>(
            value: 2,
            icon: const Icon(Icons.people_alt_rounded, size: 18),
            label: Text(
              context.l10n.aboutTabTeam,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
        selected: <int>{_selectedTabIndex},
        onSelectionChanged: (Set<int> newSelection) {
          HapticService.selection();
          setState(() {
            _selectedTabIndex = newSelection.first;
          });
        },
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          backgroundColor: scheme.surfaceContainerLow,
          selectedBackgroundColor: scheme.secondaryContainer,
          selectedForegroundColor: scheme.onSecondaryContainer,
          foregroundColor: scheme.onSurfaceVariant,
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Current Tab Content with AnimatedSize and M3 Transitions
  // ---------------------------------------------------------------------------
  Widget _buildCurrentTabContent(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: M3SpringCurves.spatial,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: M3SpringCurves.spatial,
        switchOutCurve: M3SpringCurves.snappy,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.015, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: M3SpringCurves.spatial,
              )),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_selectedTabIndex),
          child: _tabWidgetForIndex(_selectedTabIndex, context, scheme, textTheme),
        ),
      ),
    );
  }

  Widget _tabWidgetForIndex(
    int index,
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    switch (index) {
      case 0:
        return _buildChangelogTab(context, scheme, textTheme);
      case 1:
        return _buildLegalTab(context, scheme, textTheme);
      case 2:
      default:
        return _buildDevelopersTab(context, scheme, textTheme);
    }
  }

  // ---------------------------------------------------------------------------
  // Tab 0: Real Changelog (What's New)
  // ---------------------------------------------------------------------------
  Widget _buildChangelogTab(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final List<ChangelogRelease> releases = _cachedReleases ?? const <ChangelogRelease>[];

    if (_isLoadingChangelog && releases.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: AppLoadingIndicator(size: 28, color: scheme.primary),
      );
    }

    final ChangelogRelease? currentRelease = releases.isNotEmpty ? releases.first : null;
    final List<ChangelogRelease> pastReleases = releases.length > 1
        ? releases.sublist(1)
        : const <ChangelogRelease>[];

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Current Release Highlight
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
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
                          currentRelease != null
                              ? 'v${currentRelease.version}'
                              : BuildInfo.versionWithPrefix,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            context.l10n.aboutCurrentVersionBadge,
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (currentRelease?.date != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        currentRelease!.date!,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (currentRelease != null)
            ...currentRelease.changes.map(
              (String change) => _buildChangeItem(scheme, textTheme, change),
            )
          else
            _buildChangeItem(
              scheme,
              textTheme,
              context.l10n.aboutUpToDate,
            ),

          if (pastReleases.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.15)),
            const SizedBox(height: 10),
            ...pastReleases.map(
              (ChangelogRelease rel) => _ParsedReleaseTile(release: rel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChangeItem(
    ColorScheme scheme,
    TextTheme textTheme,
    String text,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
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
              text,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Legal Documents
  // ---------------------------------------------------------------------------
  Widget _buildLegalTab(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: <Widget>[
          _ActionRow(
            icon: Icons.shield_outlined,
            title: context.l10n.legalPrivacyTitle,
            subtitle: context.l10n.legalPrivacySubtitle,
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () => context.push('/legal/privacy'),
          ),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.15)),
          _ActionRow(
            icon: Icons.gavel_rounded,
            title: context.l10n.legalToSTitle,
            subtitle: context.l10n.legalToSSubtitle,
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () => context.push('/legal/terms'),
          ),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.15)),
          _ActionRow(
            icon: Icons.assignment_turned_in_outlined,
            title: context.l10n.legalConsentTitle,
            subtitle: context.l10n.legalConsentSubtitle,
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () => context.push('/legal/consent'),
          ),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.15)),
          _ActionRow(
            icon: Icons.receipt_long_rounded,
            title: context.l10n.aboutThirdPartyLicensesTitle,
            subtitle: context.l10n.aboutThirdPartyLicensesSubtitle,
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: context.l10n.appName,
                applicationVersion: BuildInfo.fullVersion,
                applicationIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: SvgPicture.asset('assets/svg/niosmess_logo_tintable.svg'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Team (Responsive at 760 breakpoint)
  // ---------------------------------------------------------------------------
  Widget _buildDevelopersTab(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final Widget sanlsanTile = _GoogleContactsDeveloperTile(
      name: 'sanlsan',
      role: context.l10n.aboutFounderRole,
      telegramHandle: 'hello_sanlsan',
      assetPath: 'assets/developers/Sanlsan_clean.png',
      fallbackIcon: Icons.dns_rounded,
      onOpenTelegram: () => _openUrl('https://t.me/hello_sanlsan'),
    );

    final Widget sh20fkTile = _GoogleContactsDeveloperTile(
      name: 'SH20FK',
      role: context.l10n.aboutLeadDevRole,
      telegramHandle: 'Door0S',
      assetPath: 'assets/developers/SH20FK_clean.png',
      fallbackIcon: Icons.phone_iphone_rounded,
      onOpenTelegram: () => _openUrl('https://t.me/Door0S'),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth >= 760) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: sanlsanTile),
              const SizedBox(width: 12),
              Expanded(child: sh20fkTile),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            sanlsanTile,
            const SizedBox(height: 12),
            sh20fkTile,
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Minimalist M3 Footer
  // ---------------------------------------------------------------------------
  Widget _buildFooter(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final int year = DateTime.now().year;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.shield_rounded,
                  size: 13,
                  color: scheme.primary.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    context.l10n.aboutSecurityFooter,
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${context.l10n.aboutCopyrightFooter(year)} • ${BuildInfo.versionWithPrefix} (${BuildInfo.buildChannel})',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Isolated OTA Update Card Widget (Zero Rebuild Leakage)
// =============================================================================

class _OtaUpdateCardWidget extends ConsumerWidget {
  const _OtaUpdateCardWidget();

  Future<void> _handleOtaAction(BuildContext context, WidgetRef ref) async {
    HapticService.tap();
    final OtaUpdateState otaState = ref.read(otaUpdateProvider);
    final OtaUpdateNotifier notifier = ref.read(otaUpdateProvider.notifier);

    if (otaState.status == OtaStatus.readyToInstall) {
      notifier.installApk(context: context);
      return;
    }

    if (otaState.status == OtaStatus.downloading) {
      if (otaState.updateInfo != null) {
        AppUpdateDialog.show(context, otaState.updateInfo!);
      }
      return;
    }

    if (otaState.status == OtaStatus.available && otaState.updateInfo != null) {
      AppUpdateDialog.show(context, otaState.updateInfo!);
      return;
    }

    // Check connectivity before initiating request
    final bool isOnline = ref.read(connectivityProvider).value ?? true;
    if (!isOnline) {
      AppToast.showError(context, context.l10n.aboutOfflineError);
      return;
    }

    await notifier.checkForUpdate();
    if (!context.mounted) return;

    final OtaUpdateState updated = ref.read(otaUpdateProvider);
    if (updated.status == OtaStatus.idle) {
      AppToast.showSuccess(context, context.l10n.aboutUpToDate);
    } else if (updated.status == OtaStatus.available && updated.updateInfo != null) {
      AppUpdateDialog.show(context, updated.updateInfo!);
    } else if (updated.status == OtaStatus.error && updated.errorMessage != null) {
      AppToast.showError(context, updated.errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Listen only to OtaUpdateState inside this isolated subtree
    final OtaUpdateState otaState = ref.watch(otaUpdateProvider);
    final OtaStatus status = otaState.status;

    final bool isChecking = status == OtaStatus.checking;
    final bool isDownloading = status == OtaStatus.downloading;
    final bool isReady = status == OtaStatus.readyToInstall;
    final bool isAvailable = status == OtaStatus.available;
    final bool isInstalling = status == OtaStatus.installing;
    final bool isError = status == OtaStatus.error;

    // Header title and subtitle resolution
    final String titleText = context.l10n.aboutSystemUpdateTitle;
    String subtitleText = context.l10n.aboutOtaSubtitle;

    if (isReady) {
      final String ver = otaState.updateInfo?.latestVersion ?? BuildInfo.version;
      subtitleText = context.l10n.aboutReadyToInstall(ver);
    } else if (isDownloading) {
      final int pct = (otaState.progress * 100).toInt().clamp(0, 100);
      subtitleText = context.l10n.aboutDownloadingProgress(pct);
    } else if (isAvailable && otaState.updateInfo != null) {
      subtitleText = context.l10n.aboutUpdateAvailable(otaState.updateInfo!.latestVersion);
    } else if (isChecking) {
      subtitleText = context.l10n.aboutCheckingStatus;
    } else if (isInstalling) {
      subtitleText = context.l10n.commonContinue;
    } else if (isError && otaState.errorMessage != null) {
      subtitleText = otaState.errorMessage!;
    }

    // Leading icon resolution
    IconData leadingIcon = Icons.system_update_rounded;
    Color leadingColor = scheme.primary;
    Color containerBg = scheme.primaryContainer.withValues(alpha: 0.5);

    if (isReady) {
      leadingIcon = Icons.check_circle_rounded;
      leadingColor = scheme.primary;
      containerBg = scheme.primaryContainer;
    } else if (isDownloading) {
      leadingIcon = Icons.cloud_download_rounded;
      leadingColor = scheme.secondary;
      containerBg = scheme.secondaryContainer.withValues(alpha: 0.6);
    } else if (isAvailable) {
      leadingIcon = Icons.new_releases_rounded;
      leadingColor = scheme.tertiary;
      containerBg = scheme.tertiaryContainer.withValues(alpha: 0.6);
    } else if (isError) {
      leadingIcon = Icons.error_outline_rounded;
      leadingColor = scheme.error;
      containerBg = scheme.errorContainer.withValues(alpha: 0.5);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: containerBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  leadingIcon,
                  size: 22,
                  color: leadingColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      titleText,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleText,
                      style: textTheme.bodySmall?.copyWith(
                        color: isReady
                            ? scheme.primary
                            : (isError ? scheme.error : scheme.onSurfaceVariant),
                        fontWeight: isReady ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Action button
              if (isDownloading) ...<Widget>[
                IconButton.filledTonal(
                  onPressed: () {
                    HapticService.tap();
                    ref.read(otaUpdateProvider.notifier).cancelDownload();
                  },
                  tooltip: context.l10n.aboutCancelAction,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ] else
                FilledButton.tonal(
                  onPressed: (isChecking || isInstalling)
                      ? null
                      : () => _handleOtaAction(context, ref),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: const Size(0, 38),
                  ),
                  child: (isChecking || isInstalling)
                      ? AppLoadingIndicator(size: 16, color: scheme.primary)
                      : Text(
                          isReady
                              ? context.l10n.aboutInstallAction
                              : (isAvailable
                                  ? context.l10n.aboutDownloadAction
                                  : (isError
                                      ? context.l10n.commonRetry
                                      : context.l10n.aboutCheckAction)),
                          style: textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
            ],
          ),

          // Deterministic M3 Squiggle Progress Bar during download
          if (isDownloading) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              height: 10,
              width: double.infinity,
              child: Md3SquiggleProgress(
                progress: otaState.progress,
                color: scheme.primary,
                strokeWidth: 3.0,
              ),
            ),
            if (otaState.totalBytes > 0) ...<Widget>[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    '${(otaState.receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${(otaState.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '${(otaState.progress * 100).toInt()}%',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Helper Widgets & Parsed Data Structures
// =============================================================================

class _InteractiveHeroLogo extends StatefulWidget {
  const _InteractiveHeroLogo({
    required this.scheme,
  });

  final ColorScheme scheme;

  @override
  State<_InteractiveHeroLogo> createState() => _InteractiveHeroLogoState();
}

class _InteractiveHeroLogoState extends State<_InteractiveHeroLogo> {
  static const List<Shapes> _shapesPool = <Shapes>[
    Shapes.c9_sided_cookie,
    Shapes.gem,
    Shapes.flower,
    Shapes.sunny,
    Shapes.burst,
  ];

  int _shapeIndex = 0;
  int _consecutiveTaps = 0;
  Timer? _tapResetTimer;

  void _onLogoTap() {
    HapticService.selection();
    setState(() {
      _shapeIndex = (_shapeIndex + 1) % _shapesPool.length;
    });

    _consecutiveTaps++;
    _tapResetTimer?.cancel();
    _tapResetTimer = Timer(const Duration(milliseconds: 1500), () {
      _consecutiveTaps = 0;
    });

    if (_consecutiveTaps >= 5) {
      _consecutiveTaps = 0;
      HapticService.confirm();
      AppToast.showSuccess(
        context,
        '🎉 ${context.l10n.aboutEasterEggTitle} ${context.l10n.aboutEasterEggMessage}',
      );
    }
  }

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Shapes currentShape = _shapesPool[_shapeIndex];

    return Semantics(
      button: true,
      label: context.l10n.appName,
      child: GestureDetector(
        onTap: _onLogoTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: M3SpringCurves.spatial,
          switchOutCurve: M3SpringCurves.snappy,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(
              scale: animation,
              child: child,
            );
          },
          child: M3Container(
            currentShape,
            key: ValueKey<int>(_shapeIndex),
            width: 78,
            height: 78,
            color: widget.scheme.primary,
            child: Center(
              child: SvgPicture.asset(
                'assets/svg/niosmess_logo_tintable.svg',
                width: 44,
                height: 44,
                colorFilter: ColorFilter.mode(
                  widget.scheme.onPrimary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _M3ActionChip extends StatelessWidget {
  const _M3ActionChip({
    required this.label,
    required this.onTap,
    this.icon,
    this.svgAsset,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final String? svgAsset;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: label,
      child: ActionChip(
        avatar: svgAsset != null
            ? SvgPicture.asset(
                svgAsset!,
                width: 15,
                height: 15,
                colorFilter: ColorFilter.mode(scheme.primary, BlendMode.srcIn),
              )
            : (icon != null ? Icon(icon, size: 15, color: scheme.primary) : null),
        label: Text(
          label,
          style: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
            fontSize: 12,
          ),
        ),
        onPressed: () {
          HapticService.tap();
          onTap();
        },
        backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () {
        HapticService.tap();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconTheme(
              data: IconThemeData(color: scheme.onSurfaceVariant, size: 20),
              child: trailing,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleContactsDeveloperTile extends StatelessWidget {
  const _GoogleContactsDeveloperTile({
    required this.name,
    required this.role,
    required this.telegramHandle,
    required this.assetPath,
    required this.fallbackIcon,
    required this.onOpenTelegram,
  });

  final String name;
  final String role;
  final String telegramHandle;
  final String assetPath;
  final IconData fallbackIcon;
  final VoidCallback onOpenTelegram;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Widget avatar = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(6),
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Center(
          child: Icon(fallbackIcon, size: 26, color: scheme.primary),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          avatar,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  name,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.2,
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '@$telegramHandle',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    role,
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: context.l10n.aboutContactDevTooltip(telegramHandle),
            child: IconButton.filledTonal(
              onPressed: () {
                HapticService.tap();
                onOpenTelegram();
              },
              icon: SvgPicture.asset(
                'assets/svg/telegram_logo.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  scheme.onSecondaryContainer,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParsedReleaseTile extends StatefulWidget {
  const _ParsedReleaseTile({
    required this.release,
  });

  final ChangelogRelease release;

  @override
  State<_ParsedReleaseTile> createState() => _ParsedReleaseTileState();
}

class _ParsedReleaseTileState extends State<_ParsedReleaseTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      children: <Widget>[
        InkWell(
          onTap: () {
            HapticService.selection();
            setState(() {
              _expanded = !_expanded;
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'v${widget.release.version}',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                if (widget.release.date != null) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(
                    widget.release.date!,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
                const Spacer(),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: M3SpringCurves.spatial,
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.only(left: 22, top: 4, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.release.changes.map((String change) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('• ', style: TextStyle(color: scheme.outlineVariant)),
                      Expanded(
                        child: Text(
                          change,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          firstCurve: M3SpringCurves.spatial,
          secondCurve: M3SpringCurves.spatial,
        ),
      ],
    );
  }
}
