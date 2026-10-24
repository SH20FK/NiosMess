import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/services/background_service.dart';
import 'package:pulse_flutter/core/utils/system_utils.dart';
import 'package:pulse_flutter/features/settings/domain/setting_id.dart';
import 'package:pulse_flutter/features/settings/domain/settings_control.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SettingsEnergySavingScreen extends ConsumerWidget {
  const SettingsEnergySavingScreen({this.isEmbedded = false, super.key});
  final bool isEmbedded;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(uiSettingsProvider);
    final scheme = Theme.of(context).colorScheme;
    final isAndroid = !kIsWeb && Platform.isAndroid;
    return SettingsShell(
      title: kIsWeb
          ? context.l10n.webMotionTitle
          : context.l10n.settingsV2Motion,
      isEmbedded: isEmbedded,
      children: [
        SettingsSection(
          title: context.l10n.settingsV2ChatAnimations,
          subtitle: context.l10n.settingsV2ChatAnimationsHint,
          children: [
            SettingsAnchor(
              id: 'motion.stickers',
              child: SettingsSwitchTile(
                icon: Icons.auto_awesome_motion_rounded,
                title: context.l10n.settingsV2Stickers,
                subtitle: context.l10n.settingsV2StickersHint,
                value: settings.animateStickers,
                onChanged: (v) =>
                    ref.read(uiSettingsProvider.notifier).setAnimateStickers(v),
              ),
            ),
            SettingsAnchor(
              id: 'motion.emoji',
              child: SettingsSwitchTile(
                icon: Icons.mood_rounded,
                title: context.l10n.settingsV2Emoji,
                subtitle: context.l10n.settingsV2EmojiHint,
                value: settings.animateEmoji,
                onChanged: (v) =>
                    ref.read(uiSettingsProvider.notifier).setAnimateEmoji(v),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.settingsV2Graphics,
          children: [
            SettingsAnchor(
              id: 'motion.optimization',
              child: SettingsSwitchTile(
                icon: Icons.speed_rounded,
                title: context.l10n.appearanceOptimizeWeakDevices,
                subtitle: context.l10n.settingsV2OptimizeHint,
                value: settings.optimizeForWeakDevices,
                onChanged: (v) => ref
                    .read(uiSettingsProvider.notifier)
                    .setOptimizeForWeakDevices(v),
              ),
            ),
          ],
        ),
        // 6. Фоновая работа
        if (!kIsWeb)
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
                      SettingsChoiceButtons<BackgroundMode>(
                        showSelectedIcon: false,
                        segments: <ButtonSegment<BackgroundMode>>[
                          ButtonSegment<BackgroundMode>(
                            value: BackgroundMode.off,
                            label: Text(context.l10n.settingsV2Off),
                            icon: Icon(
                              Icons.power_settings_new_rounded,
                              size: 18,
                            ),
                          ),
                          ButtonSegment<BackgroundMode>(
                            value: BackgroundMode.economy,
                            label: Text(context.l10n.settingsV2Economy),
                            icon: Icon(Icons.battery_saver_rounded, size: 18),
                          ),
                          ButtonSegment<BackgroundMode>(
                            value: BackgroundMode.reliable,
                            label: Text(context.l10n.settingsV2Reliable),
                            icon: Icon(Icons.shield_rounded, size: 18),
                          ),
                        ],
                        selected: <BackgroundMode>{settings.backgroundMode},
                        onSelectionChanged: (Set<BackgroundMode> selected) async {
                          final BackgroundMode newMode = selected.first;
                          ref
                              .read(uiSettingsProvider.notifier)
                              .setBackgroundMode(newMode);
                          if (newMode == BackgroundMode.reliable) {
                            await BackgroundService.requestDisableBatteryOptimization();
                          } else if (newMode == BackgroundMode.economy) {
                            await SystemUtils.requestIgnoreBatteryOptimizations();
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        switch (settings.backgroundMode) {
                          BackgroundMode.off =>
                            context.l10n.settingsV2BackgroundOff,
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
                      if (settings.backgroundMode ==
                          BackgroundMode.reliable) ...<Widget>[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              minimumSize: const Size(48, 48),
                              tapTargetSize: MaterialTapTargetSize.padded,
                            ),
                            onPressed: () async {
                              await BackgroundService.requestDisableBatteryOptimization();
                            },
                            icon: const Icon(
                              Icons.battery_charging_full_rounded,
                              size: 16,
                            ),
                            label: Text(
                              context.l10n.privacyBatteryOptimization,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ] else
                SettingsRow(
                  anchor: SettingId.privacyBackgroundMode.value,
                  leading: Icon(
                    Icons.info_outline_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                  title: context.l10n.settingsBackgroundNotAvailable,
                  subtitle: context.l10n.settingsBackgroundNotAvailableDesc,
                  control: const ValueControl(''),
                ),
            ],
          ),
      ],
    );
  }
}
