import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/features/settings/domain/setting_id.dart';
import 'package:pulse_flutter/features/settings/domain/settings_control.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/widgets/settings/privacy_rule_row.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

/// One visibility rule: the server key, its glyph, its label and the search
/// anchor. A whole category is a list of these, so a rule can be added,
/// removed or reordered without growing another near-identical widget.
class _PrivacyRuleSpec {
  const _PrivacyRuleSpec({
    required this.key,
    required this.icon,
    required this.title,
    required this.settingId,
  });

  /// Server key of the rule, such as `last_seen`.
  final String key;
  final IconData icon;
  final String Function(AppLocalizations l10n) title;
  final SettingId settingId;
}

final List<_PrivacyRuleSpec> _communicationRules = <_PrivacyRuleSpec>[
  _PrivacyRuleSpec(
    key: 'calls',
    icon: Icons.call_rounded,
    title: (AppLocalizations l) => l.privacyRuleCalls,
    settingId: SettingId.privacyCalls,
  ),
  _PrivacyRuleSpec(
    key: 'messages',
    icon: Icons.chat_bubble_outline_rounded,
    title: (AppLocalizations l) => l.privacyRuleDirectMessages,
    settingId: SettingId.privacyMessages,
  ),
  _PrivacyRuleSpec(
    key: 'voice_messages',
    icon: Icons.mic_none_rounded,
    title: (AppLocalizations l) => l.privacyRuleVoiceMessages,
    settingId: SettingId.privacyVoiceMessages,
  ),
];

final List<_PrivacyRuleSpec> _personalDataRules = <_PrivacyRuleSpec>[
  _PrivacyRuleSpec(
    key: 'phone',
    icon: Icons.phone_rounded,
    title: (AppLocalizations l) => l.privacyRulePhone,
    settingId: SettingId.privacyPhone,
  ),
  _PrivacyRuleSpec(
    key: 'birthday',
    icon: Icons.cake_rounded,
    title: (AppLocalizations l) => l.privacyRuleBirthDate,
    settingId: SettingId.privacyBirthday,
  ),
  _PrivacyRuleSpec(
    key: 'profile_photos',
    icon: Icons.account_circle_outlined,
    title: (AppLocalizations l) => l.privacyRuleAvatar,
    settingId: SettingId.privacyAvatar,
  ),
  _PrivacyRuleSpec(
    key: 'bio',
    icon: Icons.notes_rounded,
    title: (AppLocalizations l) => l.privacyRuleBio,
    settingId: SettingId.privacyBio,
  ),
  _PrivacyRuleSpec(
    key: 'gifts',
    icon: Icons.card_giftcard_rounded,
    title: (AppLocalizations l) => l.privacyRuleGifts,
    settingId: SettingId.privacyGifts,
  ),
  _PrivacyRuleSpec(
    key: 'saved_music',
    icon: Icons.music_note_rounded,
    title: (AppLocalizations l) => l.privacyRuleMusic,
    settingId: SettingId.privacyMusic,
  ),
];

final List<_PrivacyRuleSpec> _activityRules = <_PrivacyRuleSpec>[
  _PrivacyRuleSpec(
    key: 'last_seen',
    icon: Icons.access_time_rounded,
    title: (AppLocalizations l) => l.privacyRuleLastSeen,
    settingId: SettingId.privacyLastSeen,
  ),
  _PrivacyRuleSpec(
    key: 'forwards',
    icon: Icons.forward_rounded,
    title: (AppLocalizations l) => l.privacyRuleForwards,
    settingId: SettingId.privacyForwards,
  ),
  _PrivacyRuleSpec(
    key: 'invites',
    icon: Icons.group_add_rounded,
    title: (AppLocalizations l) => l.privacyRuleInvites,
    settingId: SettingId.privacyInvites,
  ),
];

class SettingsPrivacyScreen extends ConsumerWidget {
  const SettingsPrivacyScreen({this.isEmbedded = false, super.key});

  final bool isEmbedded;

  void _openBlockedUsers(BuildContext context) {
    openSettingsPage(context, '/settings/privacy/blocked-users');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PrivacyState privacy = ref.watch(privacyProvider);
    final AuthState auth = ref.watch(authProvider);
    final bool spamBlock = auth.profile?.spamBlock ?? false;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppLocalizations l = context.l10n;
    final bool hasRules = privacy.rules.isNotEmpty;
    final bool available = !privacy.isLoading && hasRules;
    final String errorMessage = privacy.error == 'privacy_save_failed'
        ? l.settingsPrivacySaveFailed
        : l.settingsPrivacyLoadFailed;

    Widget rulesSection({
      required String title,
      required IconData accentIcon,
      required List<_PrivacyRuleSpec> rules,
      List<Widget> extra = const <Widget>[],
    }) => SettingsSection(
      title: title,
      accentIcon: accentIcon,
      children: <Widget>[
        for (final _PrivacyRuleSpec rule in rules)
          PrivacyRuleRow(
            key: ValueKey<String>('privacy-rule-${rule.key}'),
            ruleKey: rule.key,
            // Only the row whose rule is being saved steps aside; the rest
            // stay usable while the write is in flight.
            enabled: available && !privacy.pendingRules.contains(rule.key),
            anchor: rule.settingId.value,
            icon: rule.icon,
            title: rule.title(l),
          ),
        ...extra,
      ],
    );

    return SettingsShell(
      title: l.settingsV2Privacy,
      isEmbedded: isEmbedded,
      onRefresh: () => ref.read(privacyProvider.notifier).refresh(),
      children: <Widget>[
        // Blocking and the secret chats answer for themselves, so they sit
        // under the header instead of after the wall of visibility rules.
        SettingsSection(
          title: l.privacyCategorySecurity,
          accentIcon: Icons.shield_rounded,
          children: <Widget>[
            SettingsRow(
              enabled: available,
              disabledReason: privacy.error == null
                  ? null
                  : l.settingsPrivacyLoadFailed,
              anchor: SettingId.privacyBlockedUsers.value,
              leading: Icon(Icons.block_rounded, color: scheme.primary),
              title: l.privacyBlacklist,
              subtitle: privacy.blockedUsers.isEmpty
                  ? l.privacyNoBlocked
                  : l.privacyBlockedCount(privacy.blockedUsers.length),
              control: const NavigationControl(),
              onTap: () => _openBlockedUsers(context),
            ),
          ],
        ),
        // The rules are the rest of the page. Until they arrive the skeleton
        // holds their place, so nothing slides under the finger when the
        // answer lands.
        if (privacy.isLoading && !hasRules)
          const SettingsSection(children: <Widget>[SettingsSkeleton(rows: 5)]),
        if (privacy.error != null)
          SettingsErrorSection(
            title: l.commonError,
            message: errorMessage,
            onRetry: () => ref.read(privacyProvider.notifier).refresh(),
          ),
        // Without rules the categories would be a wall of disabled rows with
        // no explanation; the failed card above and the retry are enough.
        if (hasRules) ...<Widget>[
          rulesSection(
            title: l.privacyCategoryCommunication,
            accentIcon: Icons.forum_rounded,
            rules: _communicationRules,
            extra: <Widget>[
              SettingsRow(
                enabled: available &&
                    !privacy.pendingRules.contains('read_receipts'),
                anchor: SettingId.privacyReadReceipts.value,
                leading: Icon(Icons.done_all_rounded, color: scheme.primary),
                title: l.settingsV2ReadReceipts,
                subtitle: l.settingsV2ReadReceiptsHint,
                control: ToggleControl(
                  value: privacy.readReceiptsEnabled,
                  pending: privacy.pendingRules.contains('read_receipts'),
                  onChanged: (bool value) async {
                    try {
                      await ref
                          .read(privacyProvider.notifier)
                          .setReadReceipts(value);
                    } catch (_) {
                      if (context.mounted) {
                        AppToast.showError(context, l.settingsV2ReadSaveFailed);
                      }
                    }
                  },
                ),
              ),
              SettingsRow(
                enabled: available &&
                    !privacy.pendingRules.contains('typing_indicators'),
                anchor: SettingId.privacyTypingIndicators.value,
                leading: Icon(Icons.keyboard_outlined, color: scheme.primary),
                title: l.settingsV2Typing,
                subtitle: l.settingsV2TypingHint,
                control: ToggleControl(
                  value: privacy.typingIndicatorsEnabled,
                  pending: privacy.pendingRules.contains('typing_indicators'),
                  onChanged: (bool value) async {
                    try {
                      await ref
                          .read(privacyProvider.notifier)
                          .setTypingIndicators(value);
                    } catch (_) {
                      if (context.mounted) {
                        AppToast.showError(context, l.settingsV2TypingSaveFailed);
                      }
                    }
                  },
                ),
              ),
            ],
          ),
          rulesSection(
            title: l.privacyCategoryPersonalData,
            accentIcon: Icons.badge_rounded,
            rules: _personalDataRules,
          ),
          rulesSection(
            title: l.privacyCategoryActivity,
            accentIcon: Icons.bolt_rounded,
            rules: _activityRules,
          ),
        ],
        if (spamBlock)
          SettingsSection(
            title: l.settingsSpamBlockTitle,
            subtitle: l.settingsSpamBlockSubtitle,
            accentIcon: Icons.gpp_bad_rounded,
            children: <Widget>[
              SettingsRow(
                leading: Icon(Icons.block_rounded, color: scheme.error),
                title: l.settingsServerLimitsTitle,
                subtitle: l.settingsSpamBlockServerHint,
                control: const ValueControl(''),
              ),
            ],
          ),
      ],
    );
  }
}
