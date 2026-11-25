import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/services/background_service.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/system_utils.dart';
import 'package:pulse_flutter/features/settings/domain/setting_id.dart';
import 'package:pulse_flutter/features/settings/domain/settings_control.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/motion/m3_reveal.dart';
import 'package:pulse_flutter/widgets/motion/m3_spring_switcher.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

/// How messages keep arriving while the app is closed. Android lets the user
/// choose a mode; on other native platforms the system decides, and the
/// section says so. Not shown in a browser.
class BackgroundDeliverySection extends ConsumerWidget {
  const BackgroundDeliverySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SettingsSection(
      title: context.l10n.settingsBackgroundTitle,
      subtitle: context.l10n.settingsBackgroundSubtitle,
      children: <Widget>[
        if (!kIsWeb && Platform.isAndroid)
          const _BackgroundModePicker()
        else
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
    );
  }
}

class _BackgroundModePicker extends ConsumerWidget {
  const _BackgroundModePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final BackgroundMode mode = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.backgroundMode),
    );
    final bool reliable = mode == BackgroundMode.reliable;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SettingsChoiceButtons<BackgroundMode>(
            showSelectedIcon: false,
            segments: <ButtonSegment<BackgroundMode>>[
              ButtonSegment<BackgroundMode>(
                value: BackgroundMode.off,
                label: Text(context.l10n.settingsV2Off),
                icon: const Icon(Icons.power_settings_new_rounded, size: 18),
              ),
              ButtonSegment<BackgroundMode>(
                value: BackgroundMode.economy,
                label: Text(context.l10n.settingsV2Economy),
                icon: const Icon(Icons.battery_saver_rounded, size: 18),
              ),
              ButtonSegment<BackgroundMode>(
                value: BackgroundMode.reliable,
                label: Text(context.l10n.settingsV2Reliable),
                icon: const Icon(Icons.shield_rounded, size: 18),
              ),
            ],
            selected: <BackgroundMode>{mode},
            onSelectionChanged: (Set<BackgroundMode> selected) async {
              final BackgroundMode next = selected.first;
              ref.read(uiSettingsProvider.notifier).setBackgroundMode(next);
              if (next == BackgroundMode.reliable) {
                await BackgroundService.requestDisableBatteryOptimization();
              } else if (next == BackgroundMode.economy) {
                await SystemUtils.requestIgnoreBatteryOptimizations();
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          M3SpringSwitcher(
            type: M3SwitcherType.fade,
            duration: M3Durations.short4,
            child: Text(
              key: ValueKey<BackgroundMode>(mode),
              switch (mode) {
                BackgroundMode.off => context.l10n.settingsV2BackgroundOff,
                BackgroundMode.economy =>
                  context.l10n.settingsBackgroundEconomyDesc,
                BackgroundMode.reliable =>
                  context.l10n.settingsBackgroundReliableDesc,
              },
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
          // Only the reliable mode needs the battery exemption, so the
          // button unfolds with it instead of jumping in.
          M3Reveal(
            revealed: reliable,
            child: IgnorePointer(
              ignoring: !reliable,
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
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
                    label: Text(context.l10n.privacyBatteryOptimization),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
