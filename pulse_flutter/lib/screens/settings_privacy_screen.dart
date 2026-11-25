import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/settings/account_security_section.dart';
import 'package:pulse_flutter/widgets/settings/privacy_rule_row.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/features/settings/domain/setting_id.dart';
import 'package:pulse_flutter/features/settings/domain/settings_control.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/motion/m3_reveal.dart';

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
    final available = !privacy.isLoading && privacy.rules.isNotEmpty;
    final pending =
        privacy.pendingRules.isNotEmpty || privacy.pendingUsers.isNotEmpty;

    return SettingsShell(
      title: context.l10n.settingsV2Privacy,
      isEmbedded: isEmbedded,
      onRefresh: () => ref.read(privacyProvider.notifier).refresh(),
      children: <Widget>[
        // Folds away when the rules arrive, so the list below slides up
        // instead of jumping.
        M3Reveal(
          revealed: privacy.isLoading && privacy.rules.isEmpty,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: AppLoadingIndicator(
                size: 28,
                semanticsLabel: context.l10n.commonLoading,
              ),
            ),
          ),
        ),
        if (privacy.error != null)
          SettingsSection(
            children: [
              SettingsListItem(
                icon: Icons.cloud_off_rounded,
                title: context.l10n.settingsPrivacyLoadFailed,
                value: context.l10n.commonRetry,
                type: SettingsListItemType.action,
                onTap: () => ref.read(privacyProvider.notifier).refresh(),
              ),
            ],
          ),
        // 1. Связь & Сообщения
        SettingsSection(
          title: context.l10n.privacyCategoryCommunication,
          children: <Widget>[
            PrivacyRuleRow(
              ruleKey: 'calls',
              enabled: available && !pending,
              anchor: SettingId.privacyCalls.value,
              icon: Icons.call_rounded,
              title: context.l10n.privacyRuleCalls,
            ),
            PrivacyRuleRow(
              ruleKey: 'messages',
              enabled: available && !pending,
              anchor: SettingId.privacyMessages.value,
              icon: Icons.chat_bubble_outline_rounded,
              title: context.l10n.privacyRuleDirectMessages,
            ),
            PrivacyRuleRow(
              ruleKey: 'voice_messages',
              enabled: available && !pending,
              anchor: SettingId.privacyVoiceMessages.value,
              icon: Icons.mic_none_rounded,
              title: context.l10n.privacyRuleVoiceMessages,
            ),
            SettingsRow(
              enabled: available && !pending,
              anchor: SettingId.privacyReadReceipts.value,
              leading: Icon(Icons.done_all_rounded, color: scheme.primary),
              title: context.l10n.settingsV2ReadReceipts,
              subtitle: context.l10n.settingsV2ReadReceiptsHint,
              control: ToggleControl(
                value: privacy.readReceiptsEnabled,
                pending: privacy.pendingRules.contains('read_receipts'),
                onChanged: (bool value) async {
                  try {
                    await ref
                        .read(privacyProvider.notifier)
                        .setReadReceipts(value);
                  } catch (e) {
                    if (context.mounted) {
                      AppToast.showError(
                        context,
                        context.l10n.settingsV2ReadSaveFailed,
                      );
                    }
                  }
                },
              ),
            ),
            SettingsRow(
              enabled: available && !pending,
              anchor: SettingId.privacyTypingIndicators.value,
              leading: Icon(Icons.keyboard_outlined, color: scheme.primary),
              title: context.l10n.settingsV2Typing,
              subtitle: context.l10n.settingsV2TypingHint,
              control: ToggleControl(
                value: privacy.typingIndicatorsEnabled,
                pending: privacy.pendingRules.contains('typing_indicators'),
                onChanged: (bool value) async {
                  try {
                    await ref
                        .read(privacyProvider.notifier)
                        .setTypingIndicators(value);
                  } catch (e) {
                    if (context.mounted) {
                      AppToast.showError(
                        context,
                        context.l10n.settingsV2TypingSaveFailed,
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),

        // 2. Личные данные
        SettingsSection(
          title: context.l10n.privacyCategoryPersonalData,
          children: <Widget>[
            PrivacyRuleRow(
              ruleKey: 'phone',
              enabled: available && !pending,
              anchor: SettingId.privacyPhone.value,
              icon: Icons.phone_rounded,
              title: context.l10n.privacyRulePhone,
            ),
            PrivacyRuleRow(
              ruleKey: 'birthday',
              enabled: available && !pending,
              anchor: SettingId.privacyBirthday.value,
              icon: Icons.cake_rounded,
              title: context.l10n.privacyRuleBirthDate,
            ),
            PrivacyRuleRow(
              ruleKey: 'profile_photos',
              enabled: available && !pending,
              anchor: SettingId.privacyAvatar.value,
              icon: Icons.account_circle_outlined,
              title: context.l10n.privacyRuleAvatar,
            ),
            PrivacyRuleRow(
              ruleKey: 'bio',
              enabled: available && !pending,
              anchor: SettingId.privacyBio.value,
              icon: Icons.notes_rounded,
              title: context.l10n.privacyRuleBio,
            ),
            PrivacyRuleRow(
              ruleKey: 'gifts',
              enabled: available && !pending,
              anchor: SettingId.privacyGifts.value,
              icon: Icons.card_giftcard_rounded,
              title: context.l10n.privacyRuleGifts,
            ),
            PrivacyRuleRow(
              ruleKey: 'saved_music',
              enabled: available && !pending,
              anchor: SettingId.privacyMusic.value,
              icon: Icons.music_note_rounded,
              title: context.l10n.privacyRuleMusic,
            ),
          ],
        ),

        // 3. Активность
        SettingsSection(
          title: context.l10n.privacyCategoryActivity,
          children: <Widget>[
            PrivacyRuleRow(
              ruleKey: 'last_seen',
              enabled: available && !pending,
              anchor: SettingId.privacyLastSeen.value,
              icon: Icons.access_time_rounded,
              title: context.l10n.privacyRuleLastSeen,
            ),
            PrivacyRuleRow(
              ruleKey: 'forwards',
              enabled: available && !pending,
              anchor: SettingId.privacyForwards.value,
              icon: Icons.forward_rounded,
              title: context.l10n.privacyRuleForwards,
            ),
            PrivacyRuleRow(
              ruleKey: 'invites',
              enabled: available && !pending,
              anchor: SettingId.privacyInvites.value,
              icon: Icons.group_add_rounded,
              title: context.l10n.privacyRuleInvites,
            ),
          ],
        ),

        AccountSecuritySection(isEmbedded: isEmbedded),

        // 4. Безопасность и блокировки
        SettingsSection(
          title: context.l10n.privacyCategorySecurity,
          children: <Widget>[
            SettingsRow(
              enabled: available && !pending,
              anchor: SettingId.privacyBlockedUsers.value,
              leading: Icon(Icons.block_rounded, color: scheme.error),
              title: context.l10n.privacyBlacklist,
              subtitle: privacy.blockedUsers.isEmpty
                  ? context.l10n.privacyNoBlocked
                  : context.l10n.privacyBlockedCount(
                      privacy.blockedUsers.length,
                    ),
              control: const NavigationControl(),
              onTap: () => _openBlockedUsers(context),
            ),
            SettingsRow(
              leading: Icon(
                Icons.enhanced_encryption_rounded,
                color: scheme.primary,
              ),
              title: context.l10n.settingsSecretChatsTitle,
              subtitle: context.l10n.settingsSecretChatsSubtitle,
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
            title: context.l10n.settingsSpamBlockTitle,
            subtitle: context.l10n.settingsSpamBlockSubtitle,
            children: <Widget>[
              SettingsRow(
                leading: Icon(Icons.block_rounded, color: scheme.error),
                title: context.l10n.settingsServerLimitsTitle,
                subtitle: context.l10n.settingsSpamBlockServerHint,
                control: const ValueControl(''),
              ),
            ],
          ),
      ],
    );
  }
}
