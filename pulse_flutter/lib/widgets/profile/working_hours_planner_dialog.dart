import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/modal/app_time_picker.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/models/api/working_hours_model.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/profile/profile_sheet_layout.dart';

class WorkingHoursPlannerDialog extends StatefulWidget {
  const WorkingHoursPlannerDialog({
    this.initialWorkingHours,
    super.key,
  });
  final WorkingHours? initialWorkingHours;

  static Future<WorkingHours?> show(
    BuildContext context, {
    WorkingHours? initialWorkingHours,
  }) {
    return ProfileSheetLayout.show<WorkingHours>(
      context,
      builder: (_) =>
          WorkingHoursPlannerDialog(initialWorkingHours: initialWorkingHours),
    );
  }

  @override
  State<WorkingHoursPlannerDialog> createState() =>
      _WorkingHoursPlannerDialogState();
}

class _WorkingHoursPlannerDialogState extends State<WorkingHoursPlannerDialog> {
  int _day = DateTime.monday;
  late final Map<int, List<TimeInterval>> _schedule;
  late final String _timezone;
  bool _picking = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _timezone = widget.initialWorkingHours?.timezone ?? 'Europe/Moscow';
    _schedule = {
      for (var day = 1; day <= 7; day++)
        day: List.of(
          widget.initialWorkingHours?.intervalsForDay(day) ??
              const <TimeInterval>[],
        ),
    };
  }

  bool get _dirty => List.generate(7, (index) => index + 1).any(
    (day) => !listEquals(
      _schedule[day],
      widget.initialWorkingHours?.intervalsForDay(day) ??
          const <TimeInterval>[],
    ),
  );

  Future<void> _cancel() async {
    if (_picking) return;
    if (_dirty) {
      final discard = await showAppConfirmDialog(
        context: context,
        title: context.l10n.commonDiscardChanges,
        subtitle: context.l10n.commonDiscardChangesDesc,
        confirmLabel: context.l10n.commonDiscardChangesConfirm,
        cancelLabel: context.l10n.commonCancel,
        destructive: true,
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  String _dayName(int day, {bool full = false}) {
    final value = DateFormat(
      full ? 'EEEE' : 'E',
      context.l10n.localeName,
    ).format(DateTime(2024, 1, day));
    return value[0].toUpperCase() + value.substring(1);
  }

  bool _overlaps(
    List<TimeInterval> intervals,
    int start,
    int end,
    int? ignore,
  ) {
    for (var i = 0; i < intervals.length; i++) {
      if (i == ignore) continue;
      final oldStart = intervals[i].startMinutes;
      final oldEnd = intervals[i].endMinutes;
      if (oldStart != null &&
          oldEnd != null &&
          start < oldEnd &&
          end > oldStart) {
        return true;
      }
    }
    return false;
  }

  Future<void> _pickInterval({int? index}) async {
    if (_picking) return;
    final day = _day;
    final intervals = _schedule[day]!;
    if (index == null && intervals.length >= 4) {
      AppToast.showError(context, context.l10n.settingsHoursLimit);
      return;
    }
    final target = index == null ? null : intervals[index];
    final defaultStart =
        target?.startMinutes ??
        (intervals.isEmpty ? 9 * 60 : intervals.last.endMinutes ?? 9 * 60);
    setState(() => _picking = true);
    try {
      final start = await AppTimePicker.show(
        context: context,
        initialTime: TimeOfDay(
          hour: defaultStart ~/ 60,
          minute: defaultStart % 60,
        ),
        helpText: context.l10n.settingsHoursStart,
      );
      if (start == null || !mounted) return;
      final startMinute = start.hour * 60 + start.minute;
      final endMinute =
          target?.endMinutes ?? (startMinute + 9 * 60).clamp(0, 23 * 60 + 59);
      final end = await AppTimePicker.show(
        context: context,
        initialTime: TimeOfDay(hour: endMinute ~/ 60, minute: endMinute % 60),
        helpText: context.l10n.settingsHoursEnd,
      );
      if (end == null || !mounted) return;
      final endMinutes = end.hour * 60 + end.minute;
      if (endMinutes <= startMinute) {
        AppToast.showError(context, context.l10n.settingsHoursEndAfterStart);
        return;
      }
      if (_overlaps(intervals, startMinute, endMinutes, index)) {
        AppToast.showError(context, context.l10n.settingsHoursOverlap);
        return;
      }
      String format(TimeOfDay value) =>
          '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
      final interval = TimeInterval(start: format(start), end: format(end));
      setState(() {
        if (index == null) {
          intervals.add(interval);
        } else {
          intervals[index] = interval;
        }
        intervals.sort(
          (a, b) => (a.startMinutes ?? 0).compareTo(b.startMinutes ?? 0),
        );
      });
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _preset(TimeInterval interval) =>
      setState(() => _schedule[_day] = [interval]);
  void _copy({required bool weekdays}) {
    final original = List<TimeInterval>.of(_schedule[_day]!);
    setState(() {
      for (var day = 1; day <= (weekdays ? 5 : 7); day++) {
        _schedule[day] = List.of(original);
      }
    });
    AppToast.showSuccess(context, context.l10n.settingsHoursCopied);
  }

  void _save() {
    if (_picking) return;
    for (final intervals in _schedule.values) {
      for (var i = 0; i < intervals.length; i++) {
        final interval = intervals[i];
        if (!interval.isValid ||
            _overlaps(
              intervals,
              interval.startMinutes ?? 0,
              interval.endMinutes ?? 0,
              i,
            )) {
          AppToast.showError(context, context.l10n.settingsHoursOverlap);
          return;
        }
      }
    }
    setState(() => _allowPop = true);
    Navigator.of(context).pop(
      WorkingHours(
        timezone: _timezone,
        mon: List.unmodifiable(_schedule[1]!),
        tue: List.unmodifiable(_schedule[2]!),
        wed: List.unmodifiable(_schedule[3]!),
        thu: List.unmodifiable(_schedule[4]!),
        fri: List.unmodifiable(_schedule[5]!),
        sat: List.unmodifiable(_schedule[6]!),
        sun: List.unmodifiable(_schedule[7]!),
      ),
    );
  }

  Widget _daySection(BuildContext context, List<TimeInterval> intervals) {
    final l = context.l10n;
    return SettingsSection(
      title: _dayName(_day, full: true),
      children: [
        if (intervals.isEmpty)
          SettingsListItem.value(
            icon: Icons.bedtime_outlined,
            title: l.settingsHoursDayOff,
            subtitle: l.settingsHoursDayOffHint,
          ),
        for (var index = 0; index < intervals.length; index++)
          SettingsListItem(
            icon: Icons.schedule_outlined,
            title: '${intervals[index].start} — ${intervals[index].end}',
            enabled: !_picking,
            onTap: () => _pickInterval(index: index),
            trailing: IconButton(
              tooltip: l.settingsHoursDeleteInterval,
              onPressed: _picking
                  ? null
                  : () => setState(() => _schedule[_day]!.removeAt(index)),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        if (intervals.length < 4)
          SettingsListItem.nav(
            icon: Icons.add_rounded,
            title: l.settingsHoursAddInterval,
            enabled: !_picking,
            onTap: _pickInterval,
          ),
      ],
    );
  }

  Widget _weekdays(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final style = Theme.of(context).textTheme.labelLarge;
      var width = 48.0;
      for (var day = 1; day <= 7; day++) {
        final text = TextPainter(
          text: TextSpan(text: _dayName(day), style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        width = math.max(width, text.width + 24);
        text.dispose();
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(bounds.maxWidth, width * 7),
          child: Row(
            children: [
              for (var day = 1; day <= 7; day++)
                Expanded(
                  child: Center(
                    child: ChoiceChip(
                      label: Text(_dayName(day)),
                      tooltip: _dayName(day, full: true),
                      selected: _day == day,
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onSelected: _picking
                          ? null
                          : (_) => setState(() => _day = day),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final intervals = _schedule[_day]!;
    const presets = [
      TimeInterval(start: '09:00', end: '18:00'),
      TimeInterval(start: '10:00', end: '19:00'),
      TimeInterval(start: '08:00', end: '17:00'),
      TimeInterval(start: '10:00', end: '22:00'),
      TimeInterval(start: '00:00', end: '23:59'),
    ];
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _cancel();
      },
      child: ProfileSheetLayout(
        title: l.settingsProfileWorkingHours,
        onClose: _picking ? null : _cancel,
        actionLabel: l.appearanceApply,
        onSubmit: _picking ? null : _save,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _weekdays(context),
            const SizedBox(height: 16),
            if (reduced)
              _daySection(context, intervals)
            else
              AnimatedSize(
                duration: M3Durations.medium2,
                curve: M3SpringCurves.expressiveDecel,
                alignment: Alignment.topCenter,
                child: _daySection(context, intervals),
              ),
            ProfileDetailsGroup(
              title: l.settingsHoursPresets,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final interval in presets)
                        ChoiceChip(
                          showCheckmark: false,
                          label: Text('${interval.start}–${interval.end}'),
                          selected:
                              intervals.length == 1 &&
                              intervals.first == interval,
                          onSelected: _picking
                              ? null
                              : (_) => _preset(interval),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ProfileDetailsGroup(
              title: l.settingsHoursRepeat,
              children: [
                SettingsListItem.nav(
                  icon: Icons.content_copy_rounded,
                  title: l.settingsHoursCopyWeekdays,
                  enabled: !_picking,
                  onTap: () => _copy(weekdays: true),
                ),
                SettingsListItem.nav(
                  icon: Icons.date_range_rounded,
                  title: l.settingsHoursCopyAll,
                  enabled: !_picking,
                  onTap: () => _copy(weekdays: false),
                ),
                if (intervals.isNotEmpty)
                  SettingsListItem(
                    icon: Icons.event_busy_outlined,
                    title: l.settingsHoursDayOff,
                    enabled: !_picking,
                    onTap: () => setState(() => _schedule[_day]!.clear()),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                '${l.settingsHoursTimezone}: $_timezone',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
