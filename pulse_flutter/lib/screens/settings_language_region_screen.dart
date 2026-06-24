import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_time.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

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

    // Determine selected language key
    final String? selectedLocale = settings.localeCode;

    return SettingsScaffold(
      title: context.l10n.languageRegionTitle,
      children: <Widget>[
        SettingsNavBanner(
          icon: Icons.language_rounded,
          title: context.l10n.languageRegionTitle,
          subtitle: context.l10n.languageRegionSubtitle,
          iconColor: Colors.teal,
        ),

        // --- Язык ---
        SettingsSection(
          title: context.l10n.languageRegionAppLanguage,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SegmentedButton<String?>(
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
                onSelectionChanged: (Set<String?> s) => ref
                    .read(uiSettingsProvider.notifier)
                    .setLocaleCode(s.first),
              ),
            ),
          ],
        ),

        // --- Часовой пояс ---
        SettingsSection(
          title: context.l10n.languageRegionTimeZone,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SegmentedButton<AppTimeZoneMode>(
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
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.schedule_rounded, color: Colors.teal, size: 20),
              ),
              title: Text(
                currentZoneLabel,
                style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                settings.timeZoneMode == AppTimeZoneMode.auto
                    ? context.l10n.commonAutomatic
                    : context.l10n.commonManual,
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              trailing: settings.timeZoneMode == AppTimeZoneMode.manual
                  ? Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant, size: 20)
                  : null,
              onTap: settings.timeZoneMode == AppTimeZoneMode.manual
                  ? () => _showTimeZonePicker(context, ref, manualZone)
                  : null,
            ),
          ],
        ),

        // --- Текущее время ---
        SettingsSection(
          title: context.l10n.languageRegionCurrentTime,
          children: <Widget>[
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.access_time_rounded, color: Colors.indigo, size: 20),
              ),
              title: Text(
                formatFullDateTime(AppTimeSettings.now()),
                style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onTap: () {
                            ref
                                .read(uiSettingsProvider.notifier)
                                .useManualTimeZone(option.id);
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
