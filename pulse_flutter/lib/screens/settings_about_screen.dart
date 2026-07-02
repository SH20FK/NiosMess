import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsAboutScreen extends StatefulWidget {
  const SettingsAboutScreen({super.key});

  @override
  State<SettingsAboutScreen> createState() => _SettingsAboutScreenState();
}

class _SettingsAboutScreenState extends State<SettingsAboutScreen> {
  late final Future<PackageInfo> _packageInfo;

  @override
  void initState() {
    super.initState();
    _packageInfo = PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SettingsScaffold(
      title: context.l10n.settingsAboutTitle,
      children: <Widget>[
        SettingsNavBanner(
          icon: Icons.info_outline_rounded,
          title: context.l10n.settingsAboutTitle,
          subtitle: context.l10n.settingsAboutBannerSubtitle,
          iconColor: scheme.primary,
        ),
        SettingsSection(
          title: context.l10n.settingsHelpSupportTitle,
          subtitle: context.l10n.settingsAboutHelpDesc,
          children: <Widget>[
            ExpansionTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.quiz_rounded,
                  color: scheme.onTertiaryContainer,
                  size: 20,
                ),
              ),
              title: Text(
                context.l10n.settingsFaq,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              shape: const Border(),
              collapsedShape: const Border(),
              children: <Widget>[
                _faqItem(
                  context,
                  question: context.l10n.settingsFaqResetQ,
                  answer: context.l10n.settingsFaqResetA,
                ),
                _faqItem(
                  context,
                  question: context.l10n.settingsFaq2faQ,
                  answer: context.l10n.settingsFaq2faA,
                ),
                _faqItem(
                  context,
                  question: context.l10n.settingsFaqJoinQ,
                  answer: context.l10n.settingsFaqJoinA,
                ),
                _faqItem(
                  context,
                  question: context.l10n.settingsFaqSpamQ,
                  answer: context.l10n.settingsFaqSpamA,
                ),
              ],
            ),
            SettingsTile(
              icon: Icons.support_agent_rounded,
              title: context.l10n.settingsContactSupport,
              subtitle: context.l10n.settingsSupportEmail,
              iconColor: scheme.primary,
              onTap: () => _composeSupportEmail(
                context,
                subject: context.l10n.settingsSupportRequestSubject,
                body: context.l10n.settingsSupportRequestBody,
              ),
            ),
            SettingsTile(
              icon: Icons.bug_report_rounded,
              title: context.l10n.settingsReportIssue,
              subtitle: context.l10n.settingsReportIssueSubtitle,
              iconColor: scheme.error,
              onTap: () => _showReportDialog(context),
            ),
          ],
        ),
        FutureBuilder<PackageInfo>(
          future: _packageInfo,
          builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
            final PackageInfo? info = snapshot.data;
            final String version = info == null
                ? context.l10n.commonLoading
                : '${info.version} (${info.buildNumber})';

            return SettingsSection(
              title: context.l10n.settingsAboutVersionTitle,
              subtitle: context.l10n.settingsAboutVersionDesc,
              children: <Widget>[
                SettingsInfoTile(
                  icon: Icons.sell_rounded,
                  title: context.l10n.settingsVersion,
                  subtitle: version,
                  iconColor: scheme.secondary,
                  onLongPress: () => _showHiddenMenu(context),
                ),
                SettingsTile(
                  icon: Icons.auto_awesome_rounded,
                  title: context.l10n.settingsDevelopers,
                  subtitle: context.l10n.settingsDevelopersSubtitle,
                  iconColor: scheme.tertiary,
                  onTap: () => context.push('/settings/developers'),
                ),
              ],
            );
          },
        ),
        SettingsSection(
          title: context.l10n.settingsLegalTitle,
          subtitle: context.l10n.settingsAboutLegalDesc,
          children: <Widget>[
            SettingsTile(
              icon: Icons.policy_rounded,
              title: context.l10n.settingsPrivacyPolicy,
              subtitle: context.l10n.settingsPrivacyPolicyUrl,
              iconColor: scheme.primary,
              onTap: () => _openUrl(context, 'https://ni-os.ru/privacy'),
            ),
            SettingsTile(
              icon: Icons.gavel_rounded,
              title: context.l10n.settingsTermsOfService,
              subtitle: context.l10n.settingsTermsOfServiceUrl,
              iconColor: scheme.secondary,
              onTap: () => _openUrl(context, 'https://ni-os.ru/terms'),
            ),
            SettingsTile(
              icon: Icons.public_rounded,
              title: context.l10n.settingsOpenWebsite,
              subtitle: context.l10n.settingsWebsiteUrl,
              iconColor: scheme.tertiary,
              onTap: () => _openUrl(context, 'https://ni-os.ru'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showHiddenMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.settingsHiddenMenuTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.settingsHiddenMenuSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.code_rounded),
                title: Text(context.l10n.settingsLicenses),
                subtitle: Text(context.l10n.settingsLicensesSubtitle),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showLicensePage(
                    context: context,
                    applicationName: context.l10n.settingsAboutNiosMess,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: Text(context.l10n.settingsCopyApiUrl),
                subtitle: const Text(ApiConstants.baseUrl),
                onTap: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: ApiConstants.baseUrl),
                  );
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.settingsApiUrlCopied)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return;
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.settingsCouldNotOpenLink)),
      );
    }
  }

  Future<void> _showReportDialog(BuildContext context) async {
    final TextEditingController descController = TextEditingController();
    await showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppDialog(
          title: context.l10n.settingsReportIssue,
          icon: Icons.bug_report_rounded,
          actions: <AppDialogAction>[
            AppDialogAction(
              label: context.l10n.commonCancel,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            AppDialogAction(
              label: context.l10n.settingsSubmit,
              isPrimary: true,
              onPressed: () async {
                final String description = descController.text.trim();
                Navigator.of(dialogContext).pop();
                await _composeSupportEmail(
                  context,
                  subject: context.l10n.settingsBugReportSubject,
                  body: description.isEmpty
                      ? context.l10n.settingsBugReportEmpty
                      : description,
                );
              },
            ),
          ],
          child: AppTextFieldDialogContent(
            controller: descController,
            hint: context.l10n.settingsReportIssueHint,
            maxLines: 5,
          ),
        );
      },
    );
    descController.dispose();
  }

  Future<void> _composeSupportEmail(
    BuildContext context, {
    required String subject,
    required String body,
  }) async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: 'support@ni-os.ru',
      queryParameters: <String, String>{'subject': subject, 'body': body},
    );
    final bool launched = await launchUrl(uri);
    if (!launched) {
      await Clipboard.setData(
        ClipboardData(text: 'support@ni-os.ru\n\n$subject\n\n$body'),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.settingsSupportCopied)),
      );
    }
  }

  Widget _faqItem(
    BuildContext context, {
    required String question,
    required String answer,
  }) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            question,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text(
            answer,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
