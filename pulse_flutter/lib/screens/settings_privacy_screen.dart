import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/services/background_service.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/system_utils.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/models/api/privacy_model.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:universal_io/io.dart';

class SettingsPrivacyScreen extends ConsumerWidget {
  const SettingsPrivacyScreen({
    this.isEmbedded = false,
    super.key,
  });

  final bool isEmbedded;

  static String _formatSelfDestructPeriod(int months) {
    switch (months) {
      case 1:
        return '1 месяц';
      case 3:
        return '3 месяца';
      case 6:
        return '6 месяцев';
      case 12:
        return '1 год';
      case 24:
        return '2 года';
      default:
        return '$months мес.';
    }
  }

  Future<void> _showSelfDestructPicker(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    HapticService.tap();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    await AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext ctx) {
        const List<int> options = <int>[1, 3, 6, 12, 24];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Самоликвидация аккаунта',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Если вы ни разу не войдёте в NiosMess в течение этого срока, ваш аккаунт и все данные будут безвозвратно удалены.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ...options.map((int months) {
                  final bool isSelected = months == current;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _formatSelfDestructPeriod(months),
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                        color: isSelected ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                        : null,
                    onTap: () {
                      HapticService.confirm();
                      ref
                          .read(uiSettingsProvider.notifier)
                          .setAccountSelfDestructMonths(months);
                      Navigator.of(ctx).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openRule(BuildContext context, String key) {
    context.push('/settings/privacy/rule/$key');
  }

  void _openBlockedUsers(BuildContext context) {
    context.push('/settings/privacy/blocked-users');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final PrivacyState privacy = ref.watch(privacyProvider);
    final AuthState auth = ref.watch(authProvider);
    final bool spamBlock = auth.profile?.spamBlock ?? false;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isAndroid = !kIsWeb && Platform.isAndroid;

    return SettingsShell(
      title: context.l10n.settingsPrivacyTitle,
      isEmbedded: isEmbedded,
      children: <Widget>[
        SettingsNavBanner(
          illustrationCategory: SettingsIllustrationCategory.privacy,
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
            SettingsSwitchTile(
              icon: Icons.link_rounded,
              title: 'Предпросмотр ссылок в секретных чатах',
              subtitle: 'Генерировать предпросмотр для отправляемых веб-ссылок',
              iconColor: scheme.primary,
              value: settings.linkPreviewsInSecretChats,
              onChanged: (bool value) {
                ref
                    .read(uiSettingsProvider.notifier)
                    .setLinkPreviewsInSecretChats(value);
              },
            ),
            SettingsSwitchTile(
              icon: Icons.screenshot_rounded,
              title: 'Защита от снимков экрана',
              subtitle: 'Блокировать скриншоты и запись экрана в секретных чатах',
              iconColor: scheme.primary,
              value: settings.secureScreenshotsInSecretChats,
              onChanged: (bool value) {
                ref
                    .read(uiSettingsProvider.notifier)
                    .setSecureScreenshotsInSecretChats(value);
              },
            ),
          ],
        ),

        // 5. Удалить мой аккаунт
        SettingsSection(
          title: 'Удалить мой аккаунт',
          subtitle: 'Автоматическое удаление аккаунта при длительном отсутствии',
          children: <Widget>[
            SettingsTile(
              icon: Icons.delete_forever_rounded,
              title: 'Если я не захожу',
              subtitle: 'Срок отсутствия до полной очистки данных',
              value: _formatSelfDestructPeriod(settings.accountSelfDestructMonths),
              iconColor: scheme.error,
              onTap: () => _showSelfDestructPicker(
                context,
                ref,
                settings.accountSelfDestructMonths,
              ),
            ),
          ],
        ),

        // 6. Фоновая работа
        SettingsSection(
          title: context.l10n.settingsBackgroundTitle,
          subtitle: context.l10n.settingsBackgroundSubtitle,
          children: <Widget>[
            if (isAndroid) ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SegmentedButton<BackgroundMode>(
                      showSelectedIcon: false,
                      segments: const <ButtonSegment<BackgroundMode>>[
                        ButtonSegment<BackgroundMode>(
                          value: BackgroundMode.off,
                          label: Text('Отключен'),
                          icon: Icon(Icons.power_settings_new_rounded, size: 18),
                        ),
                        ButtonSegment<BackgroundMode>(
                          value: BackgroundMode.economy,
                          label: Text('Экономный'),
                          icon: Icon(Icons.battery_saver_rounded, size: 18),
                        ),
                        ButtonSegment<BackgroundMode>(
                          value: BackgroundMode.reliable,
                          label: Text('Надежный'),
                          icon: Icon(Icons.shield_rounded, size: 18),
                        ),
                      ],
                      selected: <BackgroundMode>{settings.backgroundMode},
                      onSelectionChanged: (Set<BackgroundMode> selected) async {
                        final BackgroundMode newMode = selected.first;
                        ref.read(uiSettingsProvider.notifier).setBackgroundMode(newMode);
                        if (newMode == BackgroundMode.reliable) {
                          await BackgroundService.startReliable();
                          await BackgroundService.requestDisableBatteryOptimization();
                        } else if (newMode == BackgroundMode.economy) {
                          await BackgroundService.stop();
                          await SystemUtils.requestIgnoreBatteryOptimizations();
                        } else {
                          await BackgroundService.stop();
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      switch (settings.backgroundMode) {
                        BackgroundMode.off =>
                          'Фоновое соединение отключено. Уведомления поступают через Google Play / FCM.',
                        BackgroundMode.economy =>
                          context.l10n.settingsBackgroundEconomyDesc,
                        BackgroundMode.reliable =>
                          context.l10n.settingsBackgroundReliableDesc,
                      },
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                    ),
                    if (settings.backgroundMode == BackgroundMode.reliable) ...<Widget>[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () async {
                            await BackgroundService.requestDisableBatteryOptimization();
                          },
                          icon: const Icon(Icons.battery_charging_full_rounded, size: 16),
                          label: Text(
                            context.l10n.privacyBatteryOptimization,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else
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
