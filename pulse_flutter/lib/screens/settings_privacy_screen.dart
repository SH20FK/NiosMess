import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/services/background_service.dart';
import 'package:pulse_flutter/core/utils/system_utils.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';


import 'package:pulse_flutter/models/api/privacy_model.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/screens/blocked_users_screen.dart';
import 'package:pulse_flutter/screens/privacy_rule_detail_screen.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:universal_io/io.dart';

class SettingsPrivacyScreen extends ConsumerWidget {
  const SettingsPrivacyScreen({
    this.isEmbedded = false,
    super.key,
  });

  final bool isEmbedded;

  void _openRule(BuildContext context, String key) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            PrivacyRuleDetailScreen(ruleKey: key),
      ),
    );
  }

  void _openBlockedUsers(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const BlockedUsersScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final PrivacyState privacy = ref.watch(privacyProvider);
    final AuthState auth = ref.watch(authProvider);
    final bool spamBlock = auth.profile?.spamBlock ?? false;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isAndroid = !kIsWeb && Platform.isAndroid;

    return SettingsScaffold(
      title: context.l10n.settingsPrivacyTitle,
      isEmbedded: isEmbedded,
      children: <Widget>[
        SettingsNavBanner(
          illustrationCategory: SettingsIllustrationCategory.privacy,
          title: context.l10n.settingsPrivacyTitle,
          subtitle: context.l10n.settingsPrivacyBannerSubtitle,
          iconColor: scheme.primary,
        ),

        // 1. Связь
        SettingsSection(
          title: context.l10n.privacyCategoryCommunication,
          subtitle: context.l10n.privacyCategoryCommunicationDesc,
          children: <Widget>[
            SettingsTile(
              icon: Icons.call_rounded,
              title: context.l10n.privacyRuleCalls,
              subtitle: privacy.policyFor('calls').localized(context.l10n),
              iconColor: scheme.primary,
              onTap: () => _openRule(context, 'calls'),
            ),
            SettingsTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: context.l10n.privacyRuleDirectMessages,
              subtitle: privacy.policyFor('messages').localized(context.l10n),
              iconColor: scheme.primary,
              onTap: () => _openRule(context, 'messages'),
            ),
            SettingsTile(
              icon: Icons.mic_none_rounded,
              title: context.l10n.privacyRuleVoiceMessages,
              subtitle: privacy.policyFor('voice_messages').localized(context.l10n),
              iconColor: scheme.primary,
              onTap: () => _openRule(context, 'voice_messages'),
            ),
          ],
        ),

        // 2. Личные данные
        SettingsSection(
          title: context.l10n.privacyCategoryPersonalData,
          subtitle: context.l10n.privacyCategoryPersonalDataDesc,
          children: <Widget>[
            SettingsTile(
              icon: Icons.phone_rounded,
              title: context.l10n.privacyRulePhone,
              subtitle: privacy.policyFor('phone').localized(context.l10n),
              iconColor: scheme.secondary,
              onTap: () => _openRule(context, 'phone'),
            ),
            SettingsTile(
              icon: Icons.cake_rounded,
              title: context.l10n.privacyRuleBirthDate,
              subtitle: privacy.policyFor('birthday').localized(context.l10n),
              iconColor: scheme.secondary,
              onTap: () => _openRule(context, 'birthday'),
            ),
            SettingsTile(
              icon: Icons.account_circle_outlined,
              title: context.l10n.privacyRuleAvatar,
              subtitle: privacy.policyFor('profile_photos').localized(context.l10n),
              iconColor: scheme.secondary,
              onTap: () => _openRule(context, 'profile_photos'),
            ),
            SettingsTile(
              icon: Icons.notes_rounded,
              title: context.l10n.privacyRuleBio,
              subtitle: privacy.policyFor('bio').localized(context.l10n),
              iconColor: scheme.secondary,
              onTap: () => _openRule(context, 'bio'),
            ),
            SettingsTile(
              icon: Icons.card_giftcard_rounded,
              title: context.l10n.privacyRuleGifts,
              subtitle: privacy.policyFor('gifts').localized(context.l10n),
              iconColor: scheme.secondary,
              onTap: () => _openRule(context, 'gifts'),
            ),
            SettingsTile(
              icon: Icons.music_note_rounded,
              title: context.l10n.privacyRuleMusic,
              subtitle: privacy.policyFor('saved_music').localized(context.l10n),
              iconColor: scheme.secondary,
              onTap: () => _openRule(context, 'saved_music'),
            ),
          ],
        ),

        // 3. Активность
        SettingsSection(
          title: context.l10n.privacyCategoryActivity,
          subtitle: context.l10n.privacyCategoryActivityDesc,
          children: <Widget>[
            SettingsTile(
              icon: Icons.access_time_rounded,
              title: context.l10n.privacyRuleLastSeen,
              subtitle: privacy.policyFor('last_seen').localized(context.l10n),
              iconColor: scheme.tertiary,
              onTap: () => _openRule(context, 'last_seen'),
            ),
            SettingsTile(
              icon: Icons.forward_rounded,
              title: context.l10n.privacyRuleForwards,
              subtitle: privacy.policyFor('forwards').localized(context.l10n),
              iconColor: scheme.tertiary,
              onTap: () => _openRule(context, 'forwards'),
            ),
            SettingsTile(
              icon: Icons.group_add_rounded,
              title: context.l10n.privacyRuleInvites,
              subtitle: privacy.policyFor('invites').localized(context.l10n),
              iconColor: scheme.tertiary,
              onTap: () => _openRule(context, 'invites'),
            ),
            SettingsSwitchTile(
              icon: Icons.visibility_off_rounded,
              title: context.l10n.settingsPrivacyHideOnline,
              subtitle: context.l10n.settingsPrivacyHideOnlineDesc,
              iconColor: scheme.tertiary,
              value: privacy.policyFor('last_seen') == PrivacyPolicy.nobody || settings.hideOnline,
              onChanged: (bool value) async {
                ref.read(uiSettingsProvider.notifier).setHideOnline(value);
                await ref.read(privacyProvider.notifier).updateRule(
                  key: 'last_seen',
                  policy: value ? PrivacyPolicy.nobody : PrivacyPolicy.everyone,
                );
              },
            ),
          ],
        ),

        // 4. Безопасность и блокировки
        SettingsSection(
          title: context.l10n.privacyCategorySecurity,
          children: <Widget>[
            SettingsTile(
              icon: Icons.block_rounded,
              title: context.l10n.privacyBlacklist,
              subtitle: privacy.blockedUsers.isEmpty
                  ? context.l10n.privacyNoBlocked
                  : context.l10n.privacyBlockedCount(privacy.blockedUsers.length),
              iconColor: scheme.error,
              onTap: () => _openBlockedUsers(context),
            ),
            SettingsTile(
              icon: Icons.enhanced_encryption_rounded,
              title: context.l10n.settingsSecretChatsTitle,
              subtitle: context.l10n.settingsSecretChatsSubtitle,
              iconColor: scheme.primary,
              onTap: () {
                if (isEmbedded) {
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

        // 5. Фоновая работа
        SettingsSection(
          title: context.l10n.settingsBackgroundTitle,
          subtitle: context.l10n.settingsBackgroundSubtitle,
          children: <Widget>[
            if (isAndroid)
              SettingsSwitchTile(
                icon: Icons.battery_saver_rounded,
                title: context.l10n.settingsBackgroundEconomy,
                subtitle: context.l10n.settingsBackgroundEconomyDesc,
                iconColor: scheme.tertiary,
                value: settings.backgroundMode == BackgroundMode.economy,
                onChanged: (bool value) async {
                  final BackgroundMode newMode = value
                      ? BackgroundMode.economy
                      : BackgroundMode.off;
                  ref.read(uiSettingsProvider.notifier).setBackgroundMode(newMode);
                  if (value) {
                    await SystemUtils.requestIgnoreBatteryOptimizations();
                  }
                },
              ),
            if (isAndroid)
              SettingsSwitchTile(
                icon: Icons.shield_rounded,
                title: context.l10n.settingsBackgroundReliable,
                subtitle: context.l10n.settingsBackgroundReliableDesc,
                iconColor: scheme.primary,
                value: settings.backgroundMode == BackgroundMode.reliable,
                onChanged: (bool value) async {
                  final BackgroundMode newMode = value
                      ? BackgroundMode.reliable
                      : BackgroundMode.off;
                  ref.read(uiSettingsProvider.notifier).setBackgroundMode(newMode);
                  if (value) {
                    await BackgroundService.startReliable();
                    await BackgroundService.requestDisableBatteryOptimization();
                  } else {
                    await BackgroundService.stop();
                  }
                },
              ),
            if (isAndroid)
              SettingsTile(
                icon: Icons.battery_charging_full_rounded,
                title: context.l10n.privacyBatteryOptimization,
                subtitle: context.l10n.privacyBatteryOptimizationDesc,
                iconColor: scheme.secondary,
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () async {
                  await BackgroundService.requestDisableBatteryOptimization();
                },
              ),
            if (!isAndroid)
              SettingsInfoTile(
                icon: Icons.info_outline_rounded,
                title: context.l10n.settingsBackgroundNotAvailable,
                subtitle: context.l10n.settingsBackgroundNotAvailableDesc,
                iconColor: scheme.onSurfaceVariant,
              ),
          ],
        ),

        // 6. Спамблок
        if (spamBlock)
          SettingsSection(
            title: context.l10n.settingsSpamBlockTitle,
            subtitle: context.l10n.settingsSpamBlockSubtitle,
            children: <Widget>[
              SettingsInfoTile(
                icon: Icons.block_rounded,
                title: context.l10n.settingsServerLimitsTitle,
                subtitle: context.l10n.settingsServerLimitsSubtitle,
                value: context.l10n.settingsProduction,
                iconColor: scheme.error,
              ),
            ],
          ),
      ],
    );
  }
}
