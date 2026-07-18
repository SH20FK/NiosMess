import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_time.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';

class SettingsLanguageRegionScreen extends ConsumerWidget {
  const SettingsLanguageRegionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String manualZone = settings.timeZoneId ?? 'Europe/Moscow';
    final String currentZoneLabel =
        settings.timeZoneMode == AppTimeZoneMode.auto
        ? '${DateTime.now().timeZoneName} (${_offsetLabel(DateTime.now().timeZoneOffset)})'
        : _manualZoneLabel(manualZone);
    final String? selectedLocale = settings.localeCode;

    return SettingsScaffold(
      title: context.l10n.languageRegionTitle,
      children: <Widget>[
        SettingsNavBanner(
          icon: Icons.language_rounded,
          title: context.l10n.languageRegionTitle,
          subtitle: context.l10n.languageRegionSubtitle,
          iconColor: scheme.primary,
        ),
        SettingsSection(
          title: context.l10n.languageRegionAppLanguage,
          subtitle: context.l10n.settingsLanguageBannerDesc,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: SegmentedButton<String?>(
                showSelectedIcon: false,
                segments: <ButtonSegment<String?>>[
                  ButtonSegment<String?>(
                    value: null,
                    label: Text(context.l10n.commonAutomatic),
                    icon: const Icon(Icons.auto_awesome_rounded),
                  ),
                  ButtonSegment<String?>(
                    value: 'ru',
                    label: Text(context.l10n.languageRussian),
                  ),
                  ButtonSegment<String?>(
                    value: 'en',
                    label: Text(context.l10n.languageEnglish),
                  ),
                ],
                selected: <String?>{selectedLocale},
                onSelectionChanged: (Set<String?> s) =>
                    ref.read(uiSettingsProvider.notifier).setLocaleCode(s.first),
              ),
            ),
            SettingsInfoTile(
              icon: Icons.translate_rounded,
              title: context.l10n.settingsLanguageCurrentLang,
              subtitle: selectedLocale == null
                  ? context.l10n.commonAutomatic
                  : (selectedLocale == 'ru'
                        ? context.l10n.languageRussian
                        : context.l10n.languageEnglish),
              value: selectedLocale == null ? context.l10n.settingsLanguageAuto : selectedLocale.toUpperCase(),
              iconColor: scheme.primary,
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.languageRegionTimeZone,
          subtitle: context.l10n.settingsLanguageTzDesc,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: SegmentedButton<AppTimeZoneMode>(
                showSelectedIcon: false,
                segments: <ButtonSegment<AppTimeZoneMode>>[
                  ButtonSegment<AppTimeZoneMode>(
                    value: AppTimeZoneMode.auto,
                    label: Text(context.l10n.commonAutomatic),
                    icon: const Icon(Icons.gps_fixed_rounded),
                  ),
                  ButtonSegment<AppTimeZoneMode>(
                    value: AppTimeZoneMode.manual,
                    label: Text(context.l10n.commonManual),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
                selected: <AppTimeZoneMode>{settings.timeZoneMode},
                onSelectionChanged: (Set<AppTimeZoneMode> s) {
                  final AppTimeZoneMode mode = s.first;
                  ref.read(uiSettingsProvider.notifier).setTimeZoneMode(mode);
                  if (mode == AppTimeZoneMode.manual) {
                    _showTimeZonePicker(context, ref, manualZone);
                  }
                },
              ),
            ),
            SettingsTile(
              icon: Icons.schedule_rounded,
              title: currentZoneLabel,
              subtitle: settings.timeZoneMode == AppTimeZoneMode.auto
                  ? context.l10n.commonAutomatic
                  : context.l10n.commonManual,
              iconColor: scheme.tertiary,
              trailing: settings.timeZoneMode == AppTimeZoneMode.manual
                  ? Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                      size: 20,
                    )
                  : Text(
                      context.l10n.commonAutomatic,
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
              onTap: settings.timeZoneMode == AppTimeZoneMode.manual
                  ? () => _showTimeZonePicker(context, ref, manualZone)
                  : () {},
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.languageRegionCurrentTime,
          subtitle: context.l10n.settingsLanguageTimePreview,
          children: <Widget>[
            SettingsInfoTile(
              icon: Icons.access_time_rounded,
              title: context.l10n.settingsLanguageLocalTime,
              subtitle: formatFullDateTime(AppTimeSettings.now()),
              iconColor: scheme.secondary,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showTimeZonePicker(
    BuildContext context,
    WidgetRef ref,
    String selectedId,
  ) async {
    final TextEditingController controller = TextEditingController();
    String query = '';

    await AppBottomSheets.show<void>(
      context: context,
      isScrollControlled: true,
      
      builder: (BuildContext context) {
        final ColorScheme scheme = Theme.of(context).colorScheme;
        final TextTheme textTheme = Theme.of(context).textTheme;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final List<AppTimeZoneOption> items = appTimeZoneOptions
                .where((AppTimeZoneOption option) {
                  final String hay = '${option.label} ${option.id}'.toLowerCase();
                  return hay.contains(query.toLowerCase());
                })
                .toList(growable: false);

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: context.l10n.languageRegionSearchTimeZones,
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                    onChanged: (String value) {
                      setModalState(() => query = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        final AppTimeZoneOption option = items[index];
                        final bool selected = option.id == selectedId;
                        return ListTile(
                          title: Text(
                            option.label,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                          subtitle: Text(
                            '${option.id} · ${option.currentOffsetLabel()}',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: selected
                              ? Icon(Icons.check_rounded, color: scheme.primary)
                              : null,
                          selected: selected,
                          selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          onTap: () {
                            ref.read(uiSettingsProvider.notifier).useManualTimeZone(option.id);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    controller.dispose();
  }

  String _manualZoneLabel(String zoneId) {
    for (final AppTimeZoneOption option in appTimeZoneOptions) {
      if (option.id == zoneId) {
        return '${option.label} (${option.currentOffsetLabel()})';
      }
    }
    return zoneId;
  }

  String _offsetLabel(Duration offset) {
    final String sign = offset.isNegative ? '-' : '+';
    final int hours = offset.inHours.abs();
    final int minutes = offset.inMinutes.abs() % 60;
    return 'UTC$sign${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }
}
