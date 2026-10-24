import 'package:pulse_flutter/widgets/settings/account_security_section.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

class SettingsPrivacyScreen extends ConsumerWidget {
  const SettingsPrivacyScreen({this.isEmbedded = false, super.key});

  final bool isEmbedded;

  void _openRule(BuildContext context, String key) {
    context.push('/settings/privacy/rule/$key');
  }

  void _openBlockedUsers(BuildContext context) {
    context.push('/settings/privacy/blocked-users');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PrivacyState privacy = ref.watch(privacyProvider);
    final AuthState auth = ref.watch(authProvider);
    final bool spamBlock = auth.profile?.spamBlock ?? false;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SettingsShell(
      title: context.l10n.settingsV2Privacy,
      isEmbedded: isEmbedded,
      children: <Widget>[
        // 1. Связь & Сообщения
        SettingsSection(
          title: context.l10n.privacyCategoryCommunication,
          subtitle: context.l10n.privacyCategoryCommunicationDesc,
          children: <Widget>[
            SettingsRow(
              anchor: SettingId.privacyCalls.value,
              leading: Icon(Icons.call_rounded, color: scheme.primary),
              title: context.l10n.privacyRuleCalls,
              control: NavigationControl(
                value: privacy.policyFor('calls').localized(context.l10n),
              ),
              onTap: () => _openRule(context, 'calls'),
            ),
            SettingsRow(
              anchor: SettingId.privacyMessages.value,
              leading: Icon(
                Icons.chat_bubble_outline_rounded,
                color: scheme.primary,
              ),
              title: context.l10n.privacyRuleDirectMessages,
              control: NavigationControl(
                value: privacy.policyFor('messages').localized(context.l10n),
              ),
              onTap: () => _openRule(context, 'messages'),
            ),
            SettingsRow(
              anchor: SettingId.privacyVoiceMessages.value,
              leading: Icon(Icons.mic_none_rounded, color: scheme.primary),
              title: context.l10n.privacyRuleVoiceMessages,
              control: NavigationControl(
                value: privacy
                    .policyFor('voice_messages')
                    .localized(context.l10n),
              ),
              onTap: () => _openRule(context, 'voice_messages'),
            ),
            SettingsRow(
              anchor: SettingId.privacyReadReceipts.value,
              leading: Icon(Icons.done_all_rounded, color: scheme.primary),
              title: context.l10n.settingsV2ReadReceipts,
              subtitle: context.l10n.settingsV2ReadReceiptsHint,
              control: ToggleControl(
                value: privacy.readReceiptsEnabled,
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
              anchor: SettingId.privacyTypingIndicators.value,
              leading: Icon(Icons.keyboard_outlined, color: scheme.primary),
              title: context.l10n.settingsV2Typing,
              subtitle: context.l10n.settingsV2TypingHint,
              control: ToggleControl(
                value: privacy.typingIndicatorsEnabled,
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
          subtitle: context.l10n.privacyCategoryPersonalDataDesc,
          children: <Widget>[
            SettingsRow(
              anchor: SettingId.privacyPhone.value,
              leading: Icon(Icons.phone_rounded, color: scheme.secondary),
              title: context.l10n.privacyRulePhone,
              control: NavigationControl(
                value: privacy.policyFor('phone').localized(context.l10n),
              ),
              onTap: () => _openRule(context, 'phone'),
            ),
            SettingsRow(
              anchor: SettingId.privacyBirthday.value,
              leading: Icon(Icons.cake_rounded, color: scheme.secondary),
              title: context.l10n.privacyRuleBirthDate,
              control: NavigationControl(
                value: privacy.policyFor('birthday').localized(context.l10n),
              ),
              onTap: () => _openRule(context, 'birthday'),
            ),
            SettingsRow(
              anchor: SettingId.privacyAvatar.value,
              leading: Icon(
                Icons.account_circle_outlined,
                color: scheme.secondary,
              ),
              title: context.l10n.privacyRuleAvatar,
              control: NavigationControl(
                value: privacy
                    .policyFor('profile_photos')
                    .localized(context.l10n),
              ),
              onTap: () => _openRule(context, 'profile_photos'),
            ),
            SettingsRow(
              anchor: SettingId.privacyBio.value,
              leading: Icon(Icons.notes_rounded, color: scheme.secondary),
              title: context.l10n.privacyRuleBio,
              control: NavigationControl(
                value: privacy.policyFor('bio').localized(context.l10n),
              ),
              onTap: () => _openRule(context, 'bio'),
            ),
            SettingsRow(
              anchor: SettingId.privacyGifts.value,
              leading: Icon(
                Icons.card_giftcard_rounded,
                color: scheme.secondary,
              ),
              title: context.l10n.privacyRuleGifts,
              control: NavigationControl(
                value: privacy.policyFor('gifts').localized(context.l10n),
              ),
              onTap: () => _openRule(context, 'gifts'),
            ),
            SettingsRow(
              anchor: SettingId.privacyMusic.value,
              leading: Icon(Icons.music_note_rounded, color: scheme.secondary),
              title: context.l10n.privacyRuleMusic,
              control: NavigationControl(
                value: privacy.policyFor('saved_music').localized(context.l10n),
              ),
              onTap: () => _openRule(context, 'saved_music'),
            ),
          ],
        ),

        // 3. Активность
        SettingsSection(
          title: context.l10n.privacyCategoryActivity,
          subtitle: context.l10n.privacyCategoryActivityDesc,
          children: <Widget>[
            SettingsRow(
              anchor: SettingId.privacyLastSeen.value,
              leading: Icon(Icons.access_time_rounded, color: scheme.tertiary),
              title: context.l10n.privacyRuleLastSeen,
              control: NavigationControl(
                value: privacy.policyFor('last_seen').localized(context.l10n),
              ),
              onTap: () => _openRule(context, 'last_seen'),
            ),
            SettingsRow(
              anchor: SettingId.privacyForwards.value,
              leading: Icon(Icons.forward_rounded, color: scheme.tertiary),
              title: context.l10n.privacyRuleForwards,
              control: NavigationControl(
                value: privacy.policyFor('forwards').localized(context.l10n),
              ),
              onTap: () => _openRule(context, 'forwards'),
            ),
            SettingsRow(
              anchor: SettingId.privacyInvites.value,
              leading: Icon(Icons.group_add_rounded, color: scheme.tertiary),
              title: context.l10n.privacyRuleInvites,
              control: NavigationControl(
                value: privacy.policyFor('invites').localized(context.l10n),
              ),
              onTap: () => _openRule(context, 'invites'),
            ),
          ],
        ),

        AccountSecuritySection(isEmbedded: isEmbedded),

        // 4. Безопасность и блокировки
        SettingsSection(
          title: context.l10n.privacyCategorySecurity,
          children: <Widget>[
            SettingsRow(
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
                subtitle: context.l10n.settingsServerLimitsSubtitle,
                control: ValueControl(context.l10n.settingsProduction),
              ),
            ],
          ),
      ],
    );
  }
}
