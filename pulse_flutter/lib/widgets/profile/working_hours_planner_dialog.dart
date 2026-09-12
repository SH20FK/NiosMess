import 'package:flutter/material.dart';
import 'package:pulse_flutter/models/api/working_hours_model.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';

class WorkingHoursPlannerDialog extends StatefulWidget {
  const WorkingHoursPlannerDialog({
    this.initialWorkingHours,
    this.isDialog = false,
    super.key,
  });

  final WorkingHours? initialWorkingHours;
  final bool isDialog;

  static Future<WorkingHours?> show(
    BuildContext context, {
    WorkingHours? initialWorkingHours,
  }) {
    final bool isWide = MediaQuery.sizeOf(context).width >= 600;
    if (isWide) {
      return showDialog<WorkingHours>(
        context: context,
        builder: (BuildContext context) => WorkingHoursPlannerDialog(
          initialWorkingHours: initialWorkingHours,
          isDialog: true,
        ),
      );
    }
    return showModalBottomSheet<WorkingHours>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => WorkingHoursPlannerDialog(
        initialWorkingHours: initialWorkingHours,
        isDialog: false,
      ),
    );
  }

  @override
  State<WorkingHoursPlannerDialog> createState() =>
      _WorkingHoursPlannerDialogState();
}

class _WorkingHoursPlannerDialogState extends State<WorkingHoursPlannerDialog> {
  int _selectedDay = DateTime.monday;
  late Map<int, List<TimeInterval>> _schedule;
  late String _timezone;

  @override
  void initState() {
    super.initState();
    final WorkingHours? initial = widget.initialWorkingHours;
    _timezone = initial?.timezone ?? 'Europe/Moscow';
    _schedule = <int, List<TimeInterval>>{
      DateTime.monday:
          List<TimeInterval>.from(initial?.mon ?? const <TimeInterval>[]),
      DateTime.tuesday:
          List<TimeInterval>.from(initial?.tue ?? const <TimeInterval>[]),
      DateTime.wednesday:
          List<TimeInterval>.from(initial?.wed ?? const <TimeInterval>[]),
      DateTime.thursday:
          List<TimeInterval>.from(initial?.thu ?? const <TimeInterval>[]),
      DateTime.friday:
          List<TimeInterval>.from(initial?.fri ?? const <TimeInterval>[]),
      DateTime.saturday:
          List<TimeInterval>.from(initial?.sat ?? const <TimeInterval>[]),
      DateTime.sunday:
          List<TimeInterval>.from(initial?.sun ?? const <TimeInterval>[]),
    };
  }

  static const List<Map<String, dynamic>> _days = <Map<String, dynamic>>[
    <String, dynamic>{'day': DateTime.monday, 'name': 'Пн', 'full': 'Понедельник'},
    <String, dynamic>{'day': DateTime.tuesday, 'name': 'Вт', 'full': 'Вторник'},
    <String, dynamic>{'day': DateTime.wednesday, 'name': 'Ср', 'full': 'Среда'},
    <String, dynamic>{'day': DateTime.thursday, 'name': 'Чт', 'full': 'Четверг'},
    <String, dynamic>{'day': DateTime.friday, 'name': 'Пт', 'full': 'Пятница'},
    <String, dynamic>{'day': DateTime.saturday, 'name': 'Сб', 'full': 'Суббота'},
    <String, dynamic>{'day': DateTime.sunday, 'name': 'Вс', 'full': 'Воскресенье'},
  ];

  Future<void> _addInterval() async {
    HapticService.tap();
    final List<TimeInterval> current = _schedule[_selectedDay]!;
    if (current.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Максимум 4 интервала в день')),
      );
      return;
    }

    // Default start time: after last interval end or 09:00
    TimeOfDay defaultStart = const TimeOfDay(hour: 9, minute: 0);
    if (current.isNotEmpty) {
      final TimeInterval last = current.last;
      final int? lastEnd = last.endMinutes;
      if (lastEnd != null && lastEnd + 60 <= 23 * 60 + 59) {
        final int nextHour = (lastEnd ~/ 60);
        final int nextMin = lastEnd % 60;
        defaultStart = TimeOfDay(hour: nextHour, minute: nextMin);
      }
    }

    final TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: defaultStart,
      helpText: 'Начало работы',
    );
    if (start == null || !mounted) return;

    final TimeOfDay? end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (start.hour + 8) % 24,
        minute: start.minute,
      ),
      helpText: 'Конец работы',
    );
    if (end == null || !mounted) return;

    final int startMinutes = start.hour * 60 + start.minute;
    final int endMinutes = end.hour * 60 + end.minute;
    if (endMinutes <= startMinutes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Конец интервала должен быть позже начала')),
      );
      return;
    }

    for (final TimeInterval existing in current) {
      final int? exStart = existing.startMinutes;
      final int? exEnd = existing.endMinutes;
      if (exStart != null && exEnd != null) {
        if (startMinutes < exEnd && endMinutes > exStart) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Интервалы не должны пересекаться')),
          );
          return;
        }
      }
    }

    final String startStr =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final String endStr =
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';

    setState(() {
      _schedule[_selectedDay]!.add(TimeInterval(start: startStr, end: endStr));
      _schedule[_selectedDay]!.sort((TimeInterval a, TimeInterval b) {
        final int aM = a.startMinutes ?? 0;
        final int bM = b.startMinutes ?? 0;
        return aM.compareTo(bM);
      });
    });
  }

  void _removeInterval(int index) {
    HapticService.tap();
    setState(() {
      _schedule[_selectedDay]!.removeAt(index);
    });
  }

  void _copyToWeekdays() {
    HapticService.confirm();
    final List<TimeInterval> source =
        List<TimeInterval>.from(_schedule[_selectedDay]!);
    setState(() {
      for (final int day in <int>[
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
      ]) {
        _schedule[day] = List<TimeInterval>.from(source);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Расписание скопировано на будни (Пн–Пт)')),
    );
  }

  void _clearDay() {
    HapticService.tap();
    setState(() {
      _schedule[_selectedDay]!.clear();
    });
  }

  String _formatDuration(TimeInterval interval) {
    final int? s = interval.startMinutes;
    final int? e = interval.endMinutes;
    if (s == null || e == null || e <= s) return '';
    final int diff = e - s;
    final int hours = diff ~/ 60;
    final int mins = diff % 60;
    if (mins == 0) return '$hours ч';
    if (hours == 0) return '$mins мин';
    return '$hours ч $mins мин';
  }

  WorkingHours _buildWorkingHours() {
    return WorkingHours(
      timezone: _timezone,
      mon: _schedule[DateTime.monday]!,
      tue: _schedule[DateTime.tuesday]!,
      wed: _schedule[DateTime.wednesday]!,
      thu: _schedule[DateTime.thursday]!,
      fri: _schedule[DateTime.friday]!,
      sat: _schedule[DateTime.saturday]!,
      sun: _schedule[DateTime.sunday]!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final Widget bodyContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Mobile Drag Handle
        if (!widget.isDialog) ...<Widget>[
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],

        // Header Top Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text(
                  'Отмена',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.schedule_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'График работы',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(60, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () {
                  HapticService.confirm();
                  Navigator.of(context).pop(_buildWorkingHours());
                },
                child: const Text(
                  'Применить',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: scheme.outlineVariant.withValues(alpha: 0.15),
        ),

        // Content
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 20 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // 1. 7-Day Pill Selector (Equal width, fits mobile perfectly)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? scheme.surfaceContainerHighest.withValues(alpha: 0.3)
                        : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: _days.map((Map<String, dynamic> d) {
                      final int dayInt = d['day'] as int;
                      final bool isSelected = _selectedDay == dayInt;
                      final bool hasHours = _schedule[dayInt]!.isNotEmpty;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: InkWell(
                            onTap: () {
                              HapticService.tap();
                              setState(() => _selectedDay = dayInt);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? scheme.primary
                                    : (hasHours
                                        ? scheme.primaryContainer
                                            .withValues(alpha: 0.3)
                                        : Colors.transparent),
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: scheme.outlineVariant
                                            .withValues(alpha: 0.1),
                                        width: 1,
                                      ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Text(
                                    d['name'] as String,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      fontSize: 13,
                                      color: isSelected
                                          ? scheme.onPrimary
                                          : (hasHours
                                              ? scheme.primary
                                              : scheme.onSurfaceVariant),
                                    ),
                                  ),
                                  if (hasHours && !isSelected) ...<Widget>[
                                    const SizedBox(height: 2),
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: scheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Active Day Card
                _buildActiveDayCard(scheme, textTheme, isDark),
                const SizedBox(height: 14),

                // 3. Quick Actions
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text(
                          'Будни (Пн–Пт)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: _copyToWeekdays,
                      ),
                    ),
                    if (_schedule[_selectedDay]!.isNotEmpty) ...<Widget>[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.error,
                            minimumSize: const Size.fromHeight(40),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: scheme.error.withValues(alpha: 0.3),
                            ),
                          ),
                          icon: const Icon(Icons.event_busy_rounded, size: 16),
                          label: const Text(
                            'Выходной',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: _clearDay,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // 4. Timezone Footer Note
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.public_rounded,
                        size: 14,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Часовой пояс: $_timezone',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.isDialog) {
      return Dialog(
        backgroundColor: isDark ? scheme.surfaceContainerLow : scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 660),
          child: bodyContent,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerLow : scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: bodyContent,
      ),
    );
  }

  Widget _buildActiveDayCard(
    ColorScheme scheme,
    TextTheme textTheme,
    bool isDark,
  ) {
    final List<TimeInterval> intervals = _schedule[_selectedDay]!;
    final String dayFull = _days.firstWhere(
      (Map<String, dynamic> d) => d['day'] == _selectedDay,
    )['full'] as String;
    final bool hasHours = intervals.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.12 : 0.18),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header of Active Day
          Row(
            children: <Widget>[
              Text(
                dayFull,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasHours
                      ? scheme.primary.withValues(alpha: 0.12)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: hasHours
                            ? scheme.primary
                            : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasHours ? 'Рабочий день' : 'Выходной',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: hasHours
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Body: Intervals or Empty
          if (intervals.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.bedtime_outlined,
                    size: 36,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Выходной день',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Рабочие часы в этот день отключены',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _addInterval,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'Добавить интервал',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...<Widget>[
            ...intervals.asMap().entries.map((MapEntry<int, TimeInterval> entry) {
              final int index = entry.key;
              final TimeInterval interval = entry.value;
              final String durationStr = _formatDuration(interval);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? scheme.surfaceContainerLow
                      : scheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: scheme.outlineVariant
                        .withValues(alpha: isDark ? 0.1 : 0.15),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${interval.start} — ${interval.end}',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (durationStr.isNotEmpty) ...<Widget>[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          durationStr,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      onPressed: () => _removeInterval(index),
                      tooltip: 'Удалить интервал',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              );
            }),
            if (intervals.length < 4) ...<Widget>[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addInterval,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Добавить еще интервал',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
