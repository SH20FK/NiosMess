import 'package:flutter/foundation.dart';

@immutable
class TimeInterval {
  const TimeInterval({
    required this.start,
    required this.end,
  });

  final String start;
  final String end;

  factory TimeInterval.fromJson(dynamic json) {
    if (json is List && json.length >= 2) {
      return TimeInterval(
        start: json[0]?.toString() ?? '09:00',
        end: json[1]?.toString() ?? '18:00',
      );
    }
    return const TimeInterval(start: '09:00', end: '18:00');
  }

  List<String> toJson() => <String>[start, end];

  int? get startMinutes => WorkingHours.parseMinutes(start);
  int? get endMinutes => WorkingHours.parseMinutes(end);
  bool get isValid =>
      startMinutes != null && endMinutes != null && startMinutes! < endMinutes!;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeInterval &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '$start - $end';
}


@immutable
class WorkingHours {
  const WorkingHours({
    required this.timezone,
    this.mon = const <TimeInterval>[],
    this.tue = const <TimeInterval>[],
    this.wed = const <TimeInterval>[],
    this.thu = const <TimeInterval>[],
    this.fri = const <TimeInterval>[],
    this.sat = const <TimeInterval>[],
    this.sun = const <TimeInterval>[],
  });

  final String timezone;
  final List<TimeInterval> mon;
  final List<TimeInterval> tue;
  final List<TimeInterval> wed;
  final List<TimeInterval> thu;
  final List<TimeInterval> fri;
  final List<TimeInterval> sat;
  final List<TimeInterval> sun;

  static List<TimeInterval> _parseIntervals(dynamic raw) {
    if (raw is! List) return const <TimeInterval>[];
    return raw
        .whereType<List>()
        .take(4)
        .map((List item) => TimeInterval.fromJson(item))
        .toList(growable: false);
  }


  factory WorkingHours.fromJson(Map<String, dynamic> json) {
    return WorkingHours(
      timezone: json['timezone'] as String? ?? 'UTC',
      mon: _parseIntervals(json['mon']),
      tue: _parseIntervals(json['tue']),
      wed: _parseIntervals(json['wed']),
      thu: _parseIntervals(json['thu']),
      fri: _parseIntervals(json['fri']),
      sat: _parseIntervals(json['sat']),
      sun: _parseIntervals(json['sun']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'timezone': timezone,
      'mon': mon.map((TimeInterval i) => i.toJson()).toList(),
      'tue': tue.map((TimeInterval i) => i.toJson()).toList(),
      'wed': wed.map((TimeInterval i) => i.toJson()).toList(),
      'thu': thu.map((TimeInterval i) => i.toJson()).toList(),
      'fri': fri.map((TimeInterval i) => i.toJson()).toList(),
      'sat': sat.map((TimeInterval i) => i.toJson()).toList(),
      'sun': sun.map((TimeInterval i) => i.toJson()).toList(),
    };
  }

  List<TimeInterval> intervalsForDay(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return mon;
      case DateTime.tuesday:
        return tue;
      case DateTime.wednesday:
        return wed;
      case DateTime.thursday:
        return thu;
      case DateTime.friday:
        return fri;
      case DateTime.saturday:
        return sat;
      case DateTime.sunday:
        return sun;
      default:
        return const <TimeInterval>[];
    }
  }

  bool get isEmpty =>
      mon.isEmpty &&
      tue.isEmpty &&
      wed.isEmpty &&
      thu.isEmpty &&
      fri.isEmpty &&
      sat.isEmpty &&
      sun.isEmpty;

  bool isOpenNow([DateTime? dateTime]) {
    final DateTime now = dateTime ?? DateTime.now();
    final List<TimeInterval> todayIntervals = intervalsForDay(now.weekday);
    if (todayIntervals.isEmpty) return false;

    final int nowMinutes = now.hour * 60 + now.minute;
    for (final TimeInterval interval in todayIntervals) {
      final int? startMinutes = _parseMinutes(interval.start);
      final int? endMinutes = _parseMinutes(interval.end);
      if (startMinutes != null && endMinutes != null) {
        if (nowMinutes >= startMinutes && nowMinutes < endMinutes) {
          return true;
        }
      }
    }
    return false;
  }

  String getStatusText([DateTime? dateTime]) {
    final DateTime now = dateTime ?? DateTime.now();
    final List<TimeInterval> todayIntervals = intervalsForDay(now.weekday);
    final int nowMinutes = now.hour * 60 + now.minute;

    for (final TimeInterval interval in todayIntervals) {
      final int? startMinutes = _parseMinutes(interval.start);
      final int? endMinutes = _parseMinutes(interval.end);
      if (startMinutes != null && endMinutes != null) {
        if (nowMinutes >= startMinutes && nowMinutes < endMinutes) {
          return 'Открыто до ${interval.end}';
        }
      }
    }

    for (final TimeInterval interval in todayIntervals) {
      final int? startMinutes = _parseMinutes(interval.start);
      if (startMinutes != null && nowMinutes < startMinutes) {
        return 'Откроется сегодня в ${interval.start}';
      }
    }

    for (int offset = 1; offset <= 7; offset++) {
      final int nextDay = ((now.weekday - 1 + offset) % 7) + 1;
      final List<TimeInterval> nextIntervals = intervalsForDay(nextDay);
      if (nextIntervals.isNotEmpty) {
        final String dayName = _dayNameShort(nextDay);
        return 'Откроется в $dayName в ${nextIntervals.first.start}';
      }
    }

    return 'Закрыто';
  }

  static int? parseMinutes(String time) {
    final List<String> parts = time.split(':');
    if (parts.length != 2) return null;
    final int? h = int.tryParse(parts[0]);
    final int? m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  static int? _parseMinutes(String time) => parseMinutes(time);


  static String _dayNameShort(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'пн';
      case DateTime.tuesday:
        return 'вт';
      case DateTime.wednesday:
        return 'ср';
      case DateTime.thursday:
        return 'чт';
      case DateTime.friday:
        return 'пт';
      case DateTime.saturday:
        return 'сб';
      case DateTime.sunday:
        return 'вс';
      default:
        return '';
    }
  }

  WorkingHours copyWith({
    String? timezone,
    List<TimeInterval>? mon,
    List<TimeInterval>? tue,
    List<TimeInterval>? wed,
    List<TimeInterval>? thu,
    List<TimeInterval>? fri,
    List<TimeInterval>? sat,
    List<TimeInterval>? sun,
  }) {
    return WorkingHours(
      timezone: timezone ?? this.timezone,
      mon: mon ?? this.mon,
      tue: tue ?? this.tue,
      wed: wed ?? this.wed,
      thu: thu ?? this.thu,
      fri: fri ?? this.fri,
      sat: sat ?? this.sat,
      sun: sun ?? this.sun,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkingHours &&
          runtimeType == other.runtimeType &&
          timezone == other.timezone &&
          listEquals(mon, other.mon) &&
          listEquals(tue, other.tue) &&
          listEquals(wed, other.wed) &&
          listEquals(thu, other.thu) &&
          listEquals(fri, other.fri) &&
          listEquals(sat, other.sat) &&
          listEquals(sun, other.sun);

  @override
  int get hashCode => Object.hash(
        timezone,
        Object.hashAll(mon),
        Object.hashAll(tue),
        Object.hashAll(wed),
        Object.hashAll(thu),
        Object.hashAll(fri),
        Object.hashAll(sat),
        Object.hashAll(sun),
      );
}
