import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/features/settings/domain/setting_id.dart';
import 'package:pulse_flutter/features/settings/domain/settings_control.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/widgets/settings/account_security_section.dart';
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
    final bool pending =
        privacy.pendingRules.isNotEmpty || privacy.pendingUsers.isNotEmpty;
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
            enabled: available && !pending,
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
      hero: _PrivacyHero(state: privacy),
      children: <Widget>[
        // The rules are the page. Until they arrive the skeleton holds their
        // place, so nothing slides under the finger when the answer lands.
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
                enabled: available && !pending,
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
                enabled: available && !pending,
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
        AccountSecuritySection(isEmbedded: isEmbedded),
        // 4. Безопасность и блокировки
        SettingsSection(
          title: l.privacyCategorySecurity,
          accentIcon: Icons.shield_rounded,
          children: <Widget>[
            SettingsRow(
              enabled: available && !pending,
              disabledReason: privacy.error == null
                  ? null
                  : l.settingsPrivacyLoadFailed,
              anchor: SettingId.privacyBlockedUsers.value,
              leading: Icon(Icons.block_rounded, color: scheme.error),
              title: l.privacyBlacklist,
              subtitle: privacy.blockedUsers.isEmpty
                  ? l.privacyNoBlocked
                  : l.privacyBlockedCount(privacy.blockedUsers.length),
              control: const NavigationControl(),
              onTap: () => _openBlockedUsers(context),
            ),
            SettingsRow(
              leading: Icon(
                Icons.enhanced_encryption_rounded,
                color: scheme.primary,
              ),
              title: l.settingsSecretChatsTitle,
              subtitle: l.settingsSecretChatsSubtitle,
              control: const NavigationControl(),
              onTap: () {
                if (kIsWeb) {
                  context.go('/main/settings?section=e2ee');
                } else if (isEmbedded) {
                  ref
                      .read(desktopSelectedSettingsSectionProvider.notifier)
                      .setSelectedSection(SettingsSectionId.e2ee);
                } else {
                  context.push('/settings/e2ee');
                }
              },
            ),
          ],
        ),
        // 7. Спамблок
        if (spamBlock)
          SettingsSection(
            title: l.settingsSpamBlockTitle,
            subtitle: l.settingsSpamBlockSubtitle,
            accentIcon: Icons.speed_rounded,
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

/// The first look at the page answers the question the rules below ask one by
/// one: who sees the profile, the phone number and the last seen time. The
/// answers come from the same provider as the rows, so the card cannot drift
/// from them; while they load it says so instead of guessing.
class _PrivacyHero extends StatelessWidget {
  const _PrivacyHero({required this.state});

  final PrivacyState state;

  static final List<_PrivacyRuleSpec> _summary = <_PrivacyRuleSpec>[
    _PrivacyRuleSpec(
      key: 'profile_photos',
      icon: Icons.account_circle_rounded,
      title: (AppLocalizations l) => l.privacyRuleAvatar,
      settingId: SettingId.privacyAvatar,
    ),
    _PrivacyRuleSpec(
      key: 'phone',
      icon: Icons.phone_rounded,
      title: (AppLocalizations l) => l.privacyRulePhone,
      settingId: SettingId.privacyPhone,
    ),
    _PrivacyRuleSpec(
      key: 'last_seen',
      icon: Icons.access_time_rounded,
      title: (AppLocalizations l) => l.privacyRuleLastSeen,
      settingId: SettingId.privacyLastSeen,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final bool ready = state.rules.isNotEmpty;
    final int blocked = state.blockedUsers.length;

    Widget pill(String label) => DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerHigh,
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
          label,
          style: text.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    Widget summaryRow(_PrivacyRuleSpec rule) => Row(
      children: <Widget>[
        Icon(rule.icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            rule.title(l),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium?.copyWith(color: scheme.onSurface),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        pill(state.policyFor(rule.key).localized(l)),
      ],
    );

    return SettingsHeroCard(
      label: l.settingsPrivacyVisibilityTitle,
      leadingIcon: Icons.visibility_rounded,
      trailing: blocked == 0
          ? null
          : Semantics(
              label: l.privacyBlockedCount(blocked),
              child: ExcludeSemantics(
                child: DecoratedBox(
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.block_rounded,
                          size: 14,
                          color: scheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '$blocked',
                          style: text.labelSmall?.copyWith(
                            color: scheme.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      child: ready
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final (int index, _PrivacyRuleSpec rule)
                    in _summary.indexed) ...<Widget>[
                  if (index != 0) const SizedBox(height: AppSpacing.sm),
                  summaryRow(rule),
                ],
              ],
            )
          : Text(
              state.isLoading
                  ? l.commonLoading
                  : l.settingsPrivacyLoadFailed,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
    );
  }
}
