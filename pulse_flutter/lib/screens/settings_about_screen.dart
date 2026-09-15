import 'dart:async';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/constants/build_info.dart';
import 'package:pulse_flutter/core/constants/team.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/providers/ota_update_provider.dart';
import 'package:pulse_flutter/repositories/support_repository.dart';
import 'package:pulse_flutter/services/update/app_update_service.dart';
import 'package:pulse_flutter/widgets/about/morphing_brand_mark.dart';
import 'package:pulse_flutter/widgets/alpha_test_dialog.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/update/app_update_dialog.dart';

/// Screen "About Application" redesigned in full Material 3 Expressive style.
///
/// Highlights:
/// - True radial morphing brand mark via [MorphingBrandMark] (zero saveLayer).
/// - 3-tier action hierarchy: primary tonal button, connected group, and brand links.
/// - Focused single-release view in "What's New" tab with lazy history in dedicated screen.
/// - Responsive team members grid with brand shape avatars and clean typography.
/// - Pure M3 motion: horizontal [SharedAxisTransition] + one-shot entrance stagger.
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
  static const int _copyrightYear = 2026;

  late final Future<PackageInfo> _packageInfo;
  int _selectedTabIndex = 0;
  List<ChangelogRelease>? _cachedReleases;
  bool _isLoadingChangelog = false;
  double _tabScale = 1.0;

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

  void _showEasterEgg() {
    HapticService.confirm();
    AppToast.showSuccess(
      context,
      '🎉 ${context.l10n.aboutEasterEggTitle} ${context.l10n.aboutEasterEggMessage}',
    );
  }

  void _showBugReportDialog(BuildContext context) {
    HapticService.tap();
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => const _BugReportDialog(),
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
        // Block 0: Hero Card with Morphing Logo
        _buildHeroCard(context, scheme, textTheme)
            .animate()
            .fadeIn(
              duration: M3Durations.medium2,
              curve: M3SpringCurves.expressiveDecel,
            )
            .slideY(
              begin: 0.04,
              end: 0.0,
              duration: M3Durations.medium2,
              curve: M3SpringCurves.expressiveDecel,
            ),
        const SizedBox(height: 14),

        // Block 1: Isolated OTA Update Card
        const _OtaUpdateCardWidget()
            .animate(delay: const Duration(milliseconds: 50))
            .fadeIn(
              duration: M3Durations.medium2,
              curve: M3SpringCurves.expressiveDecel,
            )
            .slideY(
              begin: 0.04,
              end: 0.0,
              duration: M3Durations.medium2,
              curve: M3SpringCurves.expressiveDecel,
            ),
        const SizedBox(height: 16),

        // Block 2: Segmented Tabs, Content, and Footer
        Column(
          children: <Widget>[
            _buildSegmentedTabSelector(context, scheme, textTheme),
            const SizedBox(height: 16),
            _buildCurrentTabContent(context, scheme, textTheme),
            const SizedBox(height: 14),
            _buildFooter(context, scheme, textTheme),
          ],
        )
            .animate(delay: const Duration(milliseconds: 100))
            .fadeIn(
              duration: M3Durations.medium2,
              curve: M3SpringCurves.expressiveDecel,
            )
            .slideY(
              begin: 0.04,
              end: 0.0,
              duration: M3Durations.medium2,
              curve: M3SpringCurves.expressiveDecel,
            ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Material 3 Expressive Hero Card (Tiered Hierarchy)
  // ---------------------------------------------------------------------------
  Widget _buildHeroCard(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.of(context).lgRadius,
      ),
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          children: <Widget>[
            // Interactive shape-morphing brand mark
            MorphingBrandMark(
              size: 84,
              onEasterEgg: _showEasterEgg,
            ),
            const SizedBox(height: 16),

            // App Name
            Text(
              context.l10n.appName,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
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
              ),
            ),
            const SizedBox(height: 16),

            // Copyable Version Chip
            _VersionChip(
              packageInfoFuture: _packageInfo,
              onCopy: _copyVersion,
            ),
            const SizedBox(height: 20),

            // Tier 1: Primary Action (Bug Report)
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _showBugReportDialog(context),
                icon: const Icon(Icons.bug_report_rounded, size: 20),
                label: Text(context.l10n.aboutReportBugAction),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadii.of(context).mdRadius,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Tier 2: Connected Button Group
            _ConnectedGroup(
              items: <_GroupItem>[
                _GroupItem(
                  Icons.help_outline_rounded,
                  context.l10n.aboutFaqAction,
                  () => context.push('/help/faq'),
                ),
                _GroupItem(
                  Icons.share_rounded,
                  context.l10n.aboutShareAction,
                  _shareApp,
                ),
                _GroupItem(
                  Icons.science_rounded,
                  context.l10n.aboutAlphaTestAction,
                  () => AlphaTestDialog.show(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tier 3: Brand Links Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _BrandLink(
                  svgAsset: 'assets/svg/telegram_logo.svg',
                  tooltip: 'Telegram',
                  onTap: () => _openUrl('https://t.me/niosmess'),
                ),
                const SizedBox(width: 8),
                _BrandLink(
                  svgAsset: 'assets/svg/globe.svg',
                  tooltip: 'ni-os.ru',
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
  // 2. Material 3 SegmentedButton Tab Selector
  // ---------------------------------------------------------------------------
  Widget _buildSegmentedTabSelector(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return AnimatedScale(
      scale: _tabScale,
      duration: M3Durations.short3,
      curve: M3SpringCurves.spatial,
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          segments: <ButtonSegment<int>>[
            ButtonSegment<int>(
              value: 0,
              label: Text(
                context.l10n.aboutTabWhatsNew,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ButtonSegment<int>(
              value: 1,
              label: Text(
                context.l10n.aboutTabLegal,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ButtonSegment<int>(
              value: 2,
              label: Text(
                context.l10n.aboutTabTeam,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          selected: <int>{_selectedTabIndex},
          onSelectionChanged: (Set<int> newSelection) {
            HapticService.selection();
            setState(() {
              _tabScale = 0.97;
              _selectedTabIndex = newSelection.first;
            });
            Future<void>.delayed(M3Durations.short3, () {
              if (mounted) {
                setState(() => _tabScale = 1.0);
              }
            });
          },
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            backgroundColor: scheme.surfaceContainerLow,
            selectedBackgroundColor: scheme.secondaryContainer,
            selectedForegroundColor: scheme.onSecondaryContainer,
            foregroundColor: scheme.onSurfaceVariant,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadii.of(context).mdRadius,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            textStyle: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Tab Content Switcher with SharedAxisTransition & AnimatedSize
  // ---------------------------------------------------------------------------
  Widget _buildCurrentTabContent(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return AnimatedSize(
      duration: M3Durations.medium2,
      curve: M3SpringCurves.expressiveDecel,
      alignment: Alignment.topCenter,
      child: PageTransitionSwitcher(
        duration: M3Durations.medium2,
        transitionBuilder: (
          Widget child,
          Animation<double> primaryAnimation,
          Animation<double> secondaryAnimation,
        ) {
          return SharedAxisTransition(
            animation: primaryAnimation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.horizontal,
            child: child,
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
  // Tab 0: What's New (Single Current Release Focus)
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

    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.of(context).mdRadius,
      ),
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Current Release Header
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: AppRadii.of(context).smRadius,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: scheme.primary,
                    size: 20,
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
                      if (currentRelease?.date != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          currentRelease!.date!,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Changes List for Current Release
            if (currentRelease != null && currentRelease.changes.isNotEmpty)
              ...currentRelease.changes.map(
                (String change) => _buildChangeItem(scheme, textTheme, change),
              )
            else
              _buildChangeItem(
                scheme,
                textTheme,
                context.l10n.aboutUpToDate,
              ),

            const SizedBox(height: 16),

            // Action to view complete version history
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => context.push('/settings/about/changelog'),
                icon: const Icon(Icons.history_rounded, size: 20),
                label: Text(context.l10n.aboutTabWhatsNew),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadii.of(context).mdRadius,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangeItem(
    ColorScheme scheme,
    TextTheme textTheme,
    String text,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Container(
              width: 6,
              height: 6,
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
                height: 1.4,
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
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.of(context).mdRadius,
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
          Divider(
            height: 1,
            indent: 58,
            color: scheme.outlineVariant.withValues(alpha: 0.3),
          ),
          _ActionRow(
            icon: Icons.gavel_rounded,
            title: context.l10n.legalToSTitle,
            subtitle: context.l10n.legalToSSubtitle,
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () => context.push('/legal/terms'),
          ),
          Divider(
            height: 1,
            indent: 58,
            color: scheme.outlineVariant.withValues(alpha: 0.3),
          ),
          _ActionRow(
            icon: Icons.assignment_turned_in_outlined,
            title: context.l10n.legalConsentTitle,
            subtitle: context.l10n.legalConsentSubtitle,
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () => context.push('/legal/consent'),
          ),
          Divider(
            height: 1,
            indent: 58,
            color: scheme.outlineVariant.withValues(alpha: 0.3),
          ),
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
                  child: SizedBox.square(
                    dimension: 52,
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
  // Tab 2: Team (Responsive Grid at 840 Breakpoint)
  // ---------------------------------------------------------------------------
  Widget _buildDevelopersTab(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isExpanded = constraints.maxWidth >= Breakpoints.expanded;

        if (isExpanded) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: kTeamMembers.map((TeamMember member) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _TeamMemberTile(
                    member: member,
                    onOpenTelegram: () => _openUrl('https://t.me/${member.handle}'),
                  ),
                ),
              );
            }).toList(),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: kTeamMembers.map((TeamMember member) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TeamMemberTile(
                member: member,
                onOpenTelegram: () => _openUrl('https://t.me/${member.handle}'),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Minimalist M3 Footer
  // ---------------------------------------------------------------------------
  Widget _buildFooter(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
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
                  size: 14,
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
              '${context.l10n.aboutCopyrightFooter(_copyrightYear)} • ${BuildInfo.versionWithPrefix} (${BuildInfo.buildChannel})',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Isolated OTA Update Card Widget (Zero Rebuild Leakage + RepaintBoundary)
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

    return RepaintBoundary(
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.of(context).mdRadius,
        ),
        clipBehavior: Clip.hardEdge,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                      borderRadius: AppRadii.of(context).smRadius,
                    ),
                    child: Icon(
                      leadingIcon,
                      size: 20,
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
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Action button (touch target >= 48)
                  if (isDownloading) ...<Widget>[
                    IconButton.filledTonal(
                      onPressed: () {
                        HapticService.tap();
                        ref.read(otaUpdateProvider.notifier).cancelDownload();
                      },
                      tooltip: context.l10n.aboutCancelAction,
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ] else
                    FilledButton.tonal(
                      onPressed: (isChecking || isInstalling)
                          ? null
                          : () => _handleOtaAction(context, ref),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadii.of(context).mdRadius,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: const Size(48, 48),
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

              // Progress bar during download
              if (isDownloading) ...<Widget>[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: AppRadii.of(context).smRadius,
                  child: LinearProgressIndicator(
                    value: otaState.progress > 0 ? otaState.progress : null,
                    color: scheme.primary,
                    backgroundColor: scheme.surfaceContainerHighest,
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
                        ),
                      ),
                      Text(
                        '${(otaState.progress * 100).toInt()}%',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Helper Widgets
// =============================================================================

class _VersionChip extends StatelessWidget {
  const _VersionChip({
    required this.packageInfoFuture,
    required this.onCopy,
  });

  final Future<PackageInfo> packageInfoFuture;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return FutureBuilder<PackageInfo>(
      future: packageInfoFuture,
      builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
        final String ver = snapshot.data != null
            ? 'v${snapshot.data!.version}+${snapshot.data!.buildNumber}'
            : BuildInfo.fullVersion;

        return Semantics(
          button: true,
          label: '${context.l10n.aboutCurrentVersionBadge}: $ver',
          child: SizedBox(
            height: 48,
            child: Center(
              child: Material(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadii.of(context).fullRadius,
                ),
                clipBehavior: Clip.hardEdge,
                child: InkWell(
                  onTap: () => onCopy(ver),
                  borderRadius: AppRadii.of(context).fullRadius,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          ver,
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GroupItem {
  const _GroupItem(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _ConnectedGroup extends StatelessWidget {
  const _ConnectedGroup({required this.items});
  final List<_GroupItem> items;

  BorderRadius _groupRadius(int i, int len, Radius full, Radius tight) {
    final bool first = i == 0;
    final bool last = i == len - 1;
    return BorderRadius.horizontal(
      left: first ? full : tight,
      right: last ? full : tight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Radius full = Radius.circular(AppRadii.full);
    const Radius tight = Radius.circular(8);

    return Row(
      children: List<Widget>.generate(items.length, (int index) {
        final _GroupItem item = items[index];
        final BorderRadius radius = _groupRadius(index, items.length, full, tight);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 2,
              right: index == items.length - 1 ? 0 : 2,
            ),
            child: Material(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(borderRadius: radius),
              clipBehavior: Clip.hardEdge,
              child: InkWell(
                onTap: () {
                  HapticService.tap();
                  item.onTap();
                },
                borderRadius: radius,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(item.icon, size: 18, color: scheme.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          item.label,
                          style: textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _BrandLink extends StatelessWidget {
  const _BrandLink({
    required this.svgAsset,
    required this.tooltip,
    required this.onTap,
  });

  final String svgAsset;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 48,
        child: Material(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: const CircleBorder(),
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            onTap: () {
              HapticService.tap();
              onTap();
            },
            customBorder: const CircleBorder(),
            child: Center(
              child: SvgPicture.asset(
                svgAsset,
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  scheme.primary,
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: AppRadii.of(context).smRadius,
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
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
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

class _TeamMemberTile extends StatelessWidget {
  const _TeamMemberTile({
    required this.member,
    required this.onOpenTelegram,
  });

  final TeamMember member;
  final VoidCallback onOpenTelegram;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.of(context).mdRadius,
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () {
          HapticService.tap();
          onOpenTelegram();
        },
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: '@${member.handle}'));
          HapticService.confirm();
          AppToast.showSuccess(context, '@${member.handle}');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: <Widget>[
              // Avatar placed in BrandShape with high contrast
              StaticBrandShapeContainer(
                shape: kBrandShapes[member.shapeIndex % kBrandShapes.length],
                color: scheme.primary,
                size: 52,
                child: SizedBox.square(
                  dimension: 34,
                  child: Image.asset(
                    member.assetPath,
                    fit: BoxFit.contain,
                    color: scheme.onPrimary,
                    colorBlendMode: BlendMode.srcIn,
                    errorBuilder: (_, _, _) => Center(
                      child: Icon(
                        member.fallbackIcon,
                        size: 24,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      member.name,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${member.handle}',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      member.roleResolver(context),
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: context.l10n.aboutContactDevTooltip(member.handle),
                child: SizedBox.square(
                  dimension: 48,
                  child: Center(
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Bug Report Dialog (Dedicated StatefulWidget with Disposed Controllers)
// =============================================================================

class _BugReportDialog extends ConsumerStatefulWidget {
  const _BugReportDialog();

  @override
  ConsumerState<_BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends ConsumerState<_BugReportDialog> {
  late final TextEditingController _subjectController;
  late final TextEditingController _bodyController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController();
    _bodyController = TextEditingController();
    _subjectController.addListener(_onTextChanged);
    _bodyController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _subjectController.removeListener(_onTextChanged);
    _bodyController.removeListener(_onTextChanged);
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _subjectController.text.trim().isNotEmpty &&
      _bodyController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.of(context).lgRadius,
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
              controller: _subjectController,
              decoration: InputDecoration(
                labelText: context.l10n.aboutReportSubject,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: AppRadii.of(context).smRadius,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: context.l10n.aboutReportDescription,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: AppRadii.of(context).smRadius,
                ),
              ),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: <Widget>[
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: (_isSubmitting || !_canSubmit)
              ? null
              : () async {
                  final String subj = _subjectController.text.trim();
                  final String desc = _bodyController.text.trim();

                  setState(() => _isSubmitting = true);
                  try {
                    await ref.read(supportRepositoryProvider).createTicket(
                          ticketType: 'bug',
                          subject: subj,
                          body: desc,
                        );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      AppToast.showSuccess(
                        context,
                        context.l10n.aboutReportSuccess,
                      );
                    }
                  } catch (_) {
                    if (context.mounted) {
                      setState(() => _isSubmitting = false);
                      AppToast.showError(
                        context,
                        context.l10n.aboutReportError,
                      );
                    }
                  }
                },
          child: _isSubmitting
              ? AppLoadingIndicator(size: 16, color: scheme.onPrimary)
              : Text(context.l10n.settingsSubmit),
        ),
      ],
    );
  }
}
