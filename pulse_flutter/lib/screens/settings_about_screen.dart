import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/services/update/app_update_service.dart';
import 'package:pulse_flutter/widgets/about/morphing_brand_mark.dart';
import 'package:pulse_flutter/widgets/alpha_test_dialog.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/settings/about_bug_report_dialog.dart';
import 'package:pulse_flutter/widgets/settings/about_identity_widgets.dart';
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
  int _tab = 0;

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
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingChangelog = false);
    }
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

  Future<void> _resetPreferences() async {
    final confirmed = await showAppConfirmDialog(
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
      if (mounted) {
        AppToast.showSuccess(context, context.l10n.settingsV2ResetDone);
      }
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, context.l10n.settingsV2ResetFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return SettingsShell(
      title: l.settingsV2About,
      isEmbedded: widget.isEmbedded,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            children: [
              MorphingBrandMark(
                size: 72,
                onEasterEgg: () => AppToast.showSuccess(
                  context,
                  '${l.aboutEasterEggTitle} ${l.aboutEasterEggMessage}',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l.appName,
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l.aboutTagline,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              AboutVersionChip(
                packageInfoFuture: _packageInfo,
                onCopy: _copyVersion,
              ),
            ],
          ),
        ),
        if (!kIsWeb) const SettingsSection(children: [AboutUpdateTile()]),
        SettingsChoiceButtons<int>(
          segments: [
            ButtonSegment(value: 0, label: Text(l.aboutTabWhatsNew)),
            ButtonSegment(value: 1, label: Text(l.aboutTabLegal)),
            ButtonSegment(value: 2, label: Text(l.aboutTabTeam)),
          ],
          selected: {_tab},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            HapticService.selection();
            setState(() => _tab = selection.first);
          },
        ),
        const SizedBox(height: 16),
        if (reduced)
          _tabContent(context)
        else
          AnimatedSize(
            duration: M3Durations.medium2,
            curve: M3SpringCurves.expressiveDecel,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: M3Durations.medium2,
              switchInCurve: M3SpringCurves.expressiveDecel,
              switchOutCurve: M3SpringCurves.expressiveAccel,
              child: KeyedSubtree(
                key: ValueKey(_tab),
                child: _tabContent(context),
              ),
            ),
          ),
        SettingsSection(
          title: l.settingsAboutSupport,
          children: [
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
        SettingsSection(
          title: l.settingsV2Advanced,
          children: [
            if (!kIsWeb)
              SettingsListItem.nav(
                icon: Icons.monitor_heart_outlined,
                title: l.settingsV2Diagnostics,
                subtitle: l.settingsV2DiagnosticsHint,
                onTap: () {
                  if (widget.isEmbedded) {
                    ref
                        .read(desktopSelectedSettingsSectionProvider.notifier)
                        .setSelectedSection(SettingsSectionId.systemDevice);
                  } else {
                    context.push('/settings/system-device');
                  }
                },
              ),
            SettingsListItem.danger(
              icon: Icons.restart_alt_rounded,
              title: l.settingsV2Reset,
              subtitle: l.settingsV2ResetHint,
              onTap: _resetPreferences,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Text(
            '${l.aboutCopyrightFooter(2026)} · ${BuildInfo.buildChannel}',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
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
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: AppLoadingIndicator()),
      );
    }
    final release = _releases?.isNotEmpty == true ? _releases!.first : null;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SettingsSection(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    release == null
                        ? BuildInfo.versionWithPrefix
                        : 'v${release.version}',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    l.aboutCurrentVersionBadge,
                    style: text.labelMedium?.copyWith(color: scheme.primary),
                  ),
                ],
              ),
              if (release?.date != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    release!.date!,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              if (release == null)
                Text(l.aboutUpToDate)
              else
                for (final change in release.changes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      change,
                      style: text.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ),
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
              padding: const EdgeInsets.all(12),
              child: SvgPicture.asset(
                'assets/svg/niosmess_logo_tintable.svg',
                width: 52,
                height: 52,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
