import 'package:flutter/material.dart';
import 'package:pulse_flutter/models/api/working_hours_model.dart';

class WorkingHoursWidget extends StatefulWidget {
  const WorkingHoursWidget({
    required this.workingHours,
    this.isEditable = false,
    this.onEdit,
    this.now,
    super.key,
  });

  final WorkingHours? workingHours;
  final bool isEditable;
  final VoidCallback? onEdit;
  final DateTime? now;

  @override
  State<WorkingHoursWidget> createState() => _WorkingHoursWidgetState();
}

class _WorkingHoursWidgetState extends State<WorkingHoursWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final WorkingHours? hours = widget.workingHours;
    if (hours == null || hours.isEmpty) {
      if (!widget.isEditable) return const SizedBox.shrink();
      return _buildEmptyState(context);
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime current = widget.now ?? DateTime.now();
    final bool isOpen = hours.isOpenNow(current);
    final String status = hours.getStatusText(current);


    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isOpen
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.schedule_rounded,
                      size: 20,
                      color: isOpen
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'График работы',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: <Widget>[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isOpen ? Colors.green : scheme.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                status,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: isOpen
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.isEditable)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: widget.onEdit,
                      tooltip: 'Редактировать график',
                    ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...<Widget>[
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                children: <Widget>[
                  _buildDayRow(context, 'Понедельник', hours.mon, DateTime.monday),
                  _buildDayRow(context, 'Вторник', hours.tue, DateTime.tuesday),
                  _buildDayRow(context, 'Среда', hours.wed, DateTime.wednesday),
                  _buildDayRow(context, 'Четверг', hours.thu, DateTime.thursday),
                  _buildDayRow(context, 'Пятница', hours.fri, DateTime.friday),
                  _buildDayRow(context, 'Суббота', hours.sat, DateTime.saturday),
                  _buildDayRow(context, 'Воскресенье', hours.sun, DateTime.sunday),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        leading: Icon(Icons.schedule_rounded, color: scheme.primary),
        title: const Text('График работы не настроен'),
        subtitle: const Text('Нажмите, чтобы добавить расписание'),
        trailing: const Icon(Icons.add_rounded),
        onTap: widget.onEdit,
      ),
    );
  }

  Widget _buildDayRow(
    BuildContext context,
    String dayName,
    List<TimeInterval> intervals,
    int weekday,
  ) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime current = widget.now ?? DateTime.now();
    final bool isToday = current.weekday == weekday;

    final String text = intervals.isEmpty
        ? 'Выходной'
        : intervals.map((TimeInterval i) => '${i.start} – ${i.end}').join(', ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            dayName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  color: isToday ? scheme.primary : scheme.onSurface,
                ),
          ),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                  color: intervals.isEmpty
                      ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
                      : (isToday ? scheme.primary : scheme.onSurfaceVariant),
                ),
          ),
        ],
      ),
    );
  }
}
