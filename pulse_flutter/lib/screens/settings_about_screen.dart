import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/constants/build_info.dart';
import 'package:pulse_flutter/core/constants/team.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/services/update/app_update_service.dart';
import 'package:pulse_flutter/widgets/about/morphing_brand_mark.dart';
import 'package:pulse_flutter/widgets/alpha_test_dialog.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/settings/about_bug_report_dialog.dart';
import 'package:pulse_flutter/widgets/settings/about_changelog_expander.dart';
import 'package:pulse_flutter/widgets/settings/about_identity_widgets.dart';
import 'package:pulse_flutter/widgets/settings/about_memorial_sheet.dart';
import 'package:pulse_flutter/widgets/settings/about_update_tile.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

/// Product information first; help, documents and maintenance use shared rows.
class SettingsAboutScreen extends ConsumerStatefulWidget {
  const SettingsAboutScreen({this.isEmbedded = false, super.key});
  final bool isEmbedded;
  @override
  ConsumerState<SettingsAboutScreen> createState() =>
      _SettingsAboutScreenState();
}

class _SettingsAboutScreenState extends ConsumerState<SettingsAboutScreen> {
  late final Future<PackageInfo> _packageInfo;
  List<ChangelogRelease>? _releases;
  bool _loadingChangelog = true;

  /// A read error is its own state. It must not masquerade as "no releases",
  /// which the tab used to render as the "you are up to date" message.
  bool _changelogFailed = false;
  int _tab = 0;

  /// The tab the user came from. The tab transition reads the pair to know
  /// which way the content travels.
  int _previousTab = 0;
  int _footerTapCount = 0;
  DateTime? _lastFooterTapAt;

  void _onFooterTap() {
    final DateTime now = DateTime.now();
    if (_lastFooterTapAt != null &&
        now.difference(_lastFooterTapAt!) > const Duration(seconds: 3)) {
      _footerTapCount = 0;
    }
    _lastFooterTapAt = now;
    _footerTapCount += 1;
    if (_footerTapCount >= 6) {
      _footerTapCount = 0;
      HapticService.mediumImpact();
      AboutMemorialSheet.show(context);
    }
  }

  @override
  void initState() {
    super.initState();
    _packageInfo = PackageInfo.fromPlatform();
    _loadChangelog();
  }

  Future<void> _loadChangelog() async {
    try {
      final raw = await rootBundle.loadString('assets/CHANGELOG.md');
      final releases = AppUpdateService.parseAllReleases(raw);
      if (mounted) {
        setState(() {
          _releases = releases;
          _loadingChangelog = false;
          _changelogFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingChangelog = false;
          _changelogFailed = true;
        });
      }
    }
  }

  Future<void> _retryChangelog() async {
    setState(() {
      _loadingChangelog = true;
      _changelogFailed = false;
    });
    await _loadChangelog();
  }

  Future<void> _openUrl(String url) => AppUrlLauncher.openUrl(context, url);

  void _copyVersion(String version) {
    Clipboard.setData(ClipboardData(text: version));
    HapticService.tap();
    AppToast.showSuccess(context, context.l10n.aboutVersionCopied(version));
  }

  void _shareApp() {
    SharePlus.instance.share(
      ShareParams(
        text:
            '${context.l10n.appName} — ${context.l10n.aboutTagline}\n${AppConstants.webOrigin}',
        subject: context.l10n.appName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reduced = context.reduceMotion;
    return SettingsShell(
      title: l.settingsV2About,
      isEmbedded: widget.isEmbedded,
      hero: SettingsHeroCard(
        // The hero card has no accentLabel of its own, so the build-channel
        // badge is composed into the trailing slot the same way the
        // appearance hero composes its mode pill.
        trailing: DecoratedBox(
          decoration: ShapeDecoration(
            color: scheme.secondaryContainer,
            shape: RoundedSuperellipseBorder(
              borderRadius: AppRadii.of(context).fullRadius,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 2,
              vertical: 3,
            ),
            child: Text(
              BuildInfo.buildChannel,
              style: text.labelSmall?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            MorphingBrandMark(
              size: 72,
              onEasterEgg: () => AppToast.showSuccess(
                context,
                '${l.aboutEasterEggTitle} ${l.aboutEasterEggMessage}',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l.appName,
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.aboutTagline,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            AboutVersionChip(
              packageInfoFuture: _packageInfo,
              onCopy: _copyVersion,
            ),
          ],
        ),
      ),
      children: [
        if (!kIsWeb)
          const SettingsSection(
            children: [
              SettingsAnchor(id: 'about.update', child: AboutUpdateTile()),
            ],
          ),
        SettingsSection(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SettingsChoiceButtons<int>(
                segments: [
                  ButtonSegment(value: 0, label: Text(l.aboutTabWhatsNew)),
                  ButtonSegment(value: 1, label: Text(l.aboutTabLegal)),
                  ButtonSegment(value: 2, label: Text(l.aboutTabTeam)),
                ],
                selected: {_tab},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  final int next = selection.first;
                  if (next == _tab) return;
                  setState(() {
                    _previousTab = _tab;
                    _tab = next;
                  });
                },
              ),
            ),
          ],
        ),
        if (reduced)
          _tabContent(context)
        else
          // Only the current child is laid out. The default AnimatedSwitcher
          // stack sizes to its tallest child, and wrapping that in AnimatedSize
          // made the whole tab block collapse to a clipped zero-height box on
          // some devices (content present, nothing painted). The fade+lift on
          // the switch is enough motion; the height follows the content.
          AnimatedSwitcher(
            duration: M3Durations.medium2,
            switchInCurve: M3SpringCurves.expressiveDecel,
            switchOutCurve: M3SpringCurves.expressiveAccel,
            transitionBuilder: _tabTransition,
            layoutBuilder: (Widget? currentChild, List<Widget> previous) =>
                currentChild ?? const SizedBox.shrink(),
            child: KeyedSubtree(
              key: ValueKey(_tab),
              child: _tabContent(context),
            ),
          ),
        SettingsSection(
          title: l.settingsAboutSupport,
          accentIcon: Icons.volunteer_activism_rounded,
          children: [
            SettingsListItem.nav(
              icon: Icons.support_agent_rounded,
              title: l.aboutContactSupportAction,
              onTap: () => context.push('/support'),
            ),
            SettingsListItem.nav(
              icon: Icons.help_outline_rounded,
              title: l.aboutFaqAction,
              onTap: () => context.push('/help/faq'),
            ),
            SettingsListItem.nav(
              icon: Icons.bug_report_outlined,
              title: l.aboutReportBugAction,
              onTap: () => showAppDialog<void>(
                context: context,
                builder: (_) => const AboutBugReportDialog(),
              ),
            ),
            SettingsListItem.nav(
              icon: Icons.share_outlined,
              title: l.aboutShareAction,
              onTap: _shareApp,
            ),
            SettingsListItem.nav(
              icon: Icons.science_outlined,
              title: l.aboutAlphaTestAction,
              onTap: () => AlphaTestDialog.show(context),
            ),
          ],
        ),
        SettingsSection(
          title: l.settingsAboutLinks,
          accentIcon: Icons.link_rounded,
          children: [
            SettingsListItem.nav(
              icon: Icons.send_outlined,
              title: 'Telegram',
              value: '@niosmess',
              onTap: () => _openUrl('https://t.me/niosmess'),
            ),
            SettingsListItem.nav(
              icon: Icons.language_rounded,
              title: 'ni-os.ru',
              onTap: () => _openUrl('https://ni-os.ru'),
            ),
          ],
        ),
        // The advanced group is gone with it: diagnostics was its only row,
        // and the device page stays reachable from search and web links.
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onFooterTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(
                '${l.aboutCopyrightFooter(2026)} · ${BuildInfo.buildChannel}',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Which way the tab content travels: a tab further right lifts the new
  /// content in from below and lets the old one out upwards; going back left
  /// mirrors it.
  double get _tabDirection => _tab >= _previousTab ? 1.0 : -1.0;

  /// Fade plus a 10 dp vertical lift, direction-aware. The switcher keeps an
  /// outgoing child's transition as first built, so enter and exit are picked
  /// from the animation status and the direction is read late — inside the
  /// builders, where the state is already the new one.
  Widget _tabTransition(Widget child, Animation<double> animation) {
    return DualTransitionBuilder(
      animation: animation,
      forwardBuilder: (context, animation, child) => _TabTravelTransition(
        animation: animation,
        travel: 10.0 * _tabDirection,
        child: child!,
      ),
      reverseBuilder: (context, animation, child) => _TabTravelTransition(
        animation: animation,
        travel: -10.0 * _tabDirection,
        child: child!,
      ),
      child: child,
    );
  }

  Widget _tabContent(BuildContext context) => switch (_tab) {
    1 => _legal(context),
    2 => SettingsSection(
      children: [
        for (final member in kTeamMembers)
          AboutTeamMemberTile(
            member: member,
            onOpen: () => _openUrl('https://t.me/${member.handle}'),
          ),
      ],
    ),
    _ => _changelog(context),
  };

  Widget _changelog(BuildContext context) {
    final l = context.l10n;
    if (_loadingChangelog) {
      // Blocks land where the release card lands, so the tab does not jump
      // when the file finishes reading.
      return const SettingsSkeleton(rows: 3);
    }
    if (_changelogFailed) {
      return SettingsErrorSection(
        title: l.aboutChangelogErrorTitle,
        message: l.aboutChangelogErrorMessage,
        onRetry: _retryChangelog,
      );
    }
    final release = _releases?.isNotEmpty == true ? _releases!.first : null;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SettingsSection(
      // The installed release rides the heading as a pill: the group carries
      // no title of its own, so the version mark floats at its trailing edge.
      accentLabel:
          release == null ? BuildInfo.versionWithPrefix : 'v${release.version}',
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.aboutCurrentVersionBadge,
                style: text.labelMedium?.copyWith(color: scheme.primary),
              ),
              if (release?.date != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    release!.date!,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              if (release == null)
                Text(l.aboutUpToDate)
              else
                AboutChangelogExpander(changes: release.changes),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legal(BuildContext context) {
    final l = context.l10n;
    return SettingsSection(
      children: [
        SettingsListItem.nav(
          icon: Icons.shield_outlined,
          title: l.legalPrivacyTitle,
          subtitle: l.legalPrivacySubtitle,
          onTap: () => context.push('/legal/privacy'),
        ),
        SettingsListItem.nav(
          icon: Icons.gavel_rounded,
          title: l.legalToSTitle,
          subtitle: l.legalToSSubtitle,
          onTap: () => context.push('/legal/terms'),
        ),
        SettingsListItem.nav(
          icon: Icons.assignment_turned_in_outlined,
          title: l.legalConsentTitle,
          subtitle: l.legalConsentSubtitle,
          onTap: () => context.push('/legal/consent'),
        ),
        SettingsListItem.nav(
          icon: Icons.receipt_long_outlined,
          title: l.aboutThirdPartyLicensesTitle,
          subtitle: l.aboutThirdPartyLicensesSubtitle,
          onTap: () => showLicensePage(
            context: context,
            applicationName: l.appName,
            applicationVersion: BuildInfo.fullVersion,
            applicationIcon: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SvgPicture.asset(
                'assets/svg/niosmess_logo_tintable.svg',
                width: 52,
                height: 52,
              ),
            ),
          ),
        ),
        // Ideas, and later files, come from exteraGram; the notice names exactly
        // that. We are not a fork of it, so this page must not claim more.
        SettingsListItem.nav(
          icon: Icons.code_rounded,
          title: l.aboutPortedTitle,
          subtitle: l.aboutPortedSubtitle,
          onTap: () => _openUrl('https://github.com/exteraSquad/exteraGram'),
        ),
      ],
    );
  }
}

/// One half of the tab swap: the child fades and covers [travel] dp
/// vertically as [animation] heads to 1. Enter runs 0→1 (rises or sinks into
/// place), exit runs 1→0 (leaves the opposite way), so the same shape serves
/// both — the sign of [travel] carries the direction.
class _TabTravelTransition extends StatelessWidget {
  const _TabTravelTransition({
    required this.animation,
    required this.travel,
    required this.child,
  });

  final Animation<double> animation;

  /// Where the child sits while [animation] is at 0, in dp.
  final double travel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, travel * (1.0 - animation.value)),
          child: child,
        ),
        child: child,
      ),
    );
  }
}
