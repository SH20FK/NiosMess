import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/utils/app_time.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/features/settings/domain/settings_control.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SettingsLanguageRegionScreen extends ConsumerWidget {
  const SettingsLanguageRegionScreen({this.isEmbedded = false, super.key});
  final bool isEmbedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(uiSettingsProvider);
    final manualZone = settings.timeZoneId ?? 'Europe/Moscow';
    final currentZoneLabel = settings.timeZoneMode == AppTimeZoneMode.auto
        ? _offsetLabel(DateTime.now().timeZoneOffset)
        : _manualZoneLabel(manualZone);
    return SettingsShell(
      title: context.l10n.settingsV2Language,
      isEmbedded: isEmbedded,
      children: [
        SettingsSection(
          title: context.l10n.languageRegionAppLanguage,
          subtitle: context.l10n.settingsLanguageBannerDesc,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SettingsChoiceButtons<String?>(
                segments: [
                  ButtonSegment<String?>(
                    value: null,
                    label: Text(context.l10n.commonAutomatic),
                    icon: const Icon(Icons.language_rounded),
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
                selected: {settings.localeCode},
                onSelectionChanged: (selected) => ref
                    .read(uiSettingsProvider.notifier)
                    .setLocaleCode(selected.first),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.languageRegionTimeZone,
          subtitle: context.l10n.settingsLanguageTzDesc,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SettingsChoiceButtons<AppTimeZoneMode>(
                segments: [
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
                selected: {settings.timeZoneMode},
                onSelectionChanged: (selected) {
                  if (selected.first == AppTimeZoneMode.manual) {
                    _showTimeZonePicker(context, ref, manualZone);
                  } else {
                    ref
                        .read(uiSettingsProvider.notifier)
                        .setTimeZoneMode(AppTimeZoneMode.auto);
                  }
                },
              ),
            ),
            SettingsRow(
              leading: const Icon(Icons.schedule_rounded),
              title: currentZoneLabel,
              subtitle: settings.timeZoneMode == AppTimeZoneMode.auto
                  ? context.l10n.commonAutomatic
                  : context.l10n.commonManual,
              control: settings.timeZoneMode == AppTimeZoneMode.manual
                  ? const NavigationControl()
                  : const ValueControl(''),
              onTap: settings.timeZoneMode == AppTimeZoneMode.manual
                  ? () => _showTimeZonePicker(context, ref, manualZone)
                  : null,
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.languageRegionCurrentTime,
          subtitle: context.l10n.settingsLanguageTimePreview,
          children: [
            _LocalTimePreview(
              key: ValueKey('${settings.timeZoneMode}-${settings.timeZoneId}'),
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
    final selected = await AppModal.showSheet<String>(
      context: context,
      builder: (_) => _TimeZonePicker(selectedId: selectedId),
    );
    if (selected == null || !context.mounted) return;
    ref.read(uiSettingsProvider.notifier).useManualTimeZone(selected);
  }

  String _manualZoneLabel(String zoneId) {
    for (final option in appTimeZoneOptions) {
      if (option.id == zoneId) {
        return '${option.label} (${option.currentOffsetLabel()})';
      }
    }
    return zoneId;
  }

  String _offsetLabel(Duration offset) {
    final sign = offset.isNegative ? '-' : '+';
    return 'UTC$sign${offset.inHours.abs().toString().padLeft(2, '0')}:'
        '${(offset.inMinutes.abs() % 60).toString().padLeft(2, '0')}';
  }
}

class _LocalTimePreview extends StatefulWidget {
  const _LocalTimePreview({super.key});
  @override
  State<_LocalTimePreview> createState() => _LocalTimePreviewState();
}

class _LocalTimePreviewState extends State<_LocalTimePreview> {
  Timer? _timer;

  void _scheduleMinute() {
    _timer?.cancel();
    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _timer = Timer(nextMinute.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleMinute();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TickerMode.valuesOf(context).enabled) {
      _scheduleMinute();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsInfoTile(
    icon: Icons.access_time_rounded,
    title: context.l10n.settingsLanguageLocalTime,
    subtitle: formatFullDateTime(AppTimeSettings.now()),
  );
}

class _TimeZonePicker extends StatefulWidget {
  const _TimeZonePicker({required this.selectedId});
  final String selectedId;
  @override
  State<_TimeZonePicker> createState() => _TimeZonePickerState();
}

class _TimeZonePickerState extends State<_TimeZonePicker> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = appTimeZoneOptions
        .where(
          (option) =>
              '${option.label} ${option.id}'.toLowerCase().contains(_query),
        )
        .toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: math.min(600, constraints.maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.languageRegionTimeZone,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('settings-time-zone-search'),
                controller: _search,
                decoration: InputDecoration(
                  hintText: context.l10n.languageRegionSearchTimeZones,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).deleteButtonTooltip,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
                onChanged: (query) =>
                    setState(() => _query = query.trim().toLowerCase()),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: items.isEmpty
                    ? Center(child: Text(context.l10n.settingsV2SearchNone))
                    : ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final option = items[index];
                          return SettingsListItem(
                            icon: Icons.public_rounded,
                            title: option.label,
                            subtitle:
                                '${option.id} · ${option.currentOffsetLabel()}',
                            isSelected: option.id == widget.selectedId,
                            trailing: option.id == widget.selectedId
                                ? const Icon(Icons.check_rounded)
                                : null,
                            onTap: () => Navigator.of(context).pop(option.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
