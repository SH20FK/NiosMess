import 'package:flutter/material.dart';
import 'package:pulse_flutter/models/api/working_hours_model.dart';

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
    return showDialog<WorkingHours>(
      context: context,
      builder: (BuildContext context) => WorkingHoursPlannerDialog(
        initialWorkingHours: initialWorkingHours,
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
      DateTime.monday: List<TimeInterval>.from(initial?.mon ?? const <TimeInterval>[]),
      DateTime.tuesday: List<TimeInterval>.from(initial?.tue ?? const <TimeInterval>[]),
      DateTime.wednesday: List<TimeInterval>.from(initial?.wed ?? const <TimeInterval>[]),
      DateTime.thursday: List<TimeInterval>.from(initial?.thu ?? const <TimeInterval>[]),
      DateTime.friday: List<TimeInterval>.from(initial?.fri ?? const <TimeInterval>[]),
      DateTime.saturday: List<TimeInterval>.from(initial?.sat ?? const <TimeInterval>[]),
      DateTime.sunday: List<TimeInterval>.from(initial?.sun ?? const <TimeInterval>[]),
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
    final List<TimeInterval> current = _schedule[_selectedDay]!;
    if (current.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Максимум 4 интервала в день')),
      );
      return;
    }

    final TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Начало работы',
    );
    if (start == null || !mounted) return;

    final TimeOfDay? end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (start.hour + 8) % 24, minute: start.minute),
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
    setState(() {
      _schedule[_selectedDay]!.removeAt(index);
    });
  }

  void _copyToWeekdays() {
    final List<TimeInterval> source = List<TimeInterval>.from(_schedule[_selectedDay]!);
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
      const SnackBar(content: Text('Расписание скопировано на будние дни (Пн-Пт)')),
    );
  }

  void _clearDay() {
    setState(() {
      _schedule[_selectedDay]!.clear();
    });
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
    final List<TimeInterval> intervals = _schedule[_selectedDay]!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'График работы',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _days.map((Map<String, dynamic> d) {
                    final int dayInt = d['day'] as int;
                    final bool isSelected = _selectedDay == dayInt;
                    final bool hasHours = _schedule[dayInt]!.isNotEmpty;

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(d['name'] as String),
                        avatar: hasHours
                            ? Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? scheme.onPrimary
                                      : scheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                        onSelected: (_) => setState(() => _selectedDay = dayInt),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _days.firstWhere((Map<String, dynamic> d) => d['day'] == _selectedDay)['full']
                    as String,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: intervals.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Выходной день (нет рабочих часов)',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: intervals.length,
                        itemBuilder: (BuildContext context, int index) {
                          final TimeInterval interval = intervals[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: <Widget>[
                                Icon(Icons.access_time_rounded,
                                    size: 18, color: scheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${interval.start} — ${interval.end}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 20),
                                  onPressed: () => _removeInterval(index),
                                  tooltip: 'Удалить интервал',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Добавить интервал'),
                    onPressed: intervals.length < 4 ? _addInterval : null,
                  ),
                  const Spacer(),
                  if (intervals.isNotEmpty)
                    TextButton(
                      onPressed: _clearDay,
                      child: const Text('Сделать выходным'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Скопировать на Пн–Пт'),
                onPressed: _copyToWeekdays,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(_buildWorkingHours());
                    },
                    child: const Text('Применить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
