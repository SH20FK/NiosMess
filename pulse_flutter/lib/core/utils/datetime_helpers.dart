import 'package:intl/intl.dart';
import 'package:pulse_flutter/core/utils/app_time.dart';

final DateFormat _timeFormat = DateFormat('HH:mm');
final DateFormat _dateFormatShort = DateFormat('dd.MM');
final DateFormat _dateFormatFull = DateFormat('dd.MM.yyyy');
final DateFormat _dateTimeFormat = DateFormat('dd.MM.yyyy HH:mm');

DateTime parseApiDateTime(String? iso) {
  if (iso == null || iso.trim().isEmpty) {
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  final String value = iso.trim();
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  if (_hasExplicitTimeZone(value)) return parsed.toUtc();
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}

DateTime? parseApiDateTimeNullable(String? iso) {
  if (iso == null || iso.trim().isEmpty) {
    return null;
  }
  final String value = iso.trim();
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return null;
  }
  if (_hasExplicitTimeZone(value)) return parsed.toUtc();
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}

String formatRelativeTime(DateTime dateTime, {String? localeCode}) {
  final locale = (localeCode ?? AppTimeSettings.localeCode)
      .split(RegExp(r"[_-]"))
      .first;
  if (dateTime.millisecondsSinceEpoch <= 0) return '--';

  final DateTime resolved = AppTimeSettings.resolve(dateTime);
  final DateTime now = AppTimeSettings.now();
  final Duration diff = now.difference(resolved);
  if (diff.isNegative) return _wordNow(locale);
  if (diff.inSeconds < 60) return _wordNow(locale);
  if (diff.inMinutes < 60) {
    return _minutesAgo(diff.inMinutes, locale);
  }

  final bool sameDay =
      resolved.year == now.year &&
      resolved.month == now.month &&
      resolved.day == now.day;
  if (sameDay) {
    return _timeFormat.format(resolved);
  }

  final DateTime yesterday = now.subtract(const Duration(days: 1));
  final bool isYesterday =
      resolved.year == yesterday.year &&
      resolved.month == yesterday.month &&
      resolved.day == yesterday.day;
  if (isYesterday) return _wordYesterday(locale);

  if (diff.inDays < 7) {
    return _daysAgo(diff.inDays, locale);
  }

  if (resolved.year == now.year) {
    return _dateFormatShort.format(resolved);
  }
  return _dateFormatFull.format(resolved);
}

String formatMessageTime(DateTime dateTime) {
  if (dateTime.millisecondsSinceEpoch <= 0) return '--:--';
  final DateTime resolved = AppTimeSettings.resolve(dateTime);
  return _timeFormat.format(resolved);
}

String formatCallDuration(Duration duration) {
  if (duration.isNegative) return '00:00';
  final int totalSeconds = duration.inSeconds;
  final int hours = totalSeconds ~/ 3600;
  final int minutes = (totalSeconds % 3600) ~/ 60;
  final int seconds = totalSeconds % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String formatFullDateTime(DateTime dateTime) {
  if (dateTime.millisecondsSinceEpoch <= 0) return '--';
  final DateTime resolved = AppTimeSettings.resolve(dateTime);
  return _dateTimeFormat.format(resolved);
}

Duration computeCallElapsed(DateTime? startedAt, int? durationSeconds) {
  if (durationSeconds != null && durationSeconds > 0) {
    return Duration(seconds: durationSeconds);
  }
  if (startedAt != null && startedAt.millisecondsSinceEpoch > 0) {
    final Duration diff = AppTimeSettings.now().difference(
      AppTimeSettings.resolve(startedAt),
    );
    return diff.isNegative ? Duration.zero : diff;
  }
  return Duration.zero;
}

/// Short unit words for relative timestamps.
///
/// This helper is imported by pure-Dart models (`message_model`, `call_models`)
/// and therefore must never import `package:flutter` — `dart test` runs those
/// models without `dart:ui`. The widget layer gets the same labels from the
/// `timeNow` / `timeYesterday` ARB keys, so keep both in sync.
class _RelativeTimeWords {
  const _RelativeTimeWords({
    required this.now,
    required this.yesterday,
    required this.minute,
    required this.day,
  });

  final String now;
  final String yesterday;
  final String minute;
  final String day;
}

/// `minute` / `day` carry their own separator: Russian needs a space before the
/// shortened unit ("7 мин"), English does not ("7m").
const Map<String, _RelativeTimeWords> _relativeTimeWords = {
  'ru': _RelativeTimeWords(
    now: 'сейчас',
    yesterday: 'вчера',
    minute: ' мин',
    day: ' д',
  ),
};

const _RelativeTimeWords _relativeTimeFallback = _RelativeTimeWords(
  now: 'now',
  yesterday: 'yesterday',
  minute: 'm',
  day: 'd',
);

_RelativeTimeWords _wordsFor(String locale) =>
    _relativeTimeWords[locale] ?? _relativeTimeFallback;

String _minutesAgo(int count, String locale) {
  final unit = _wordsFor(locale).minute;
  return Intl.plural(
    count,
    locale: locale,
    one: '$count$unit',
    few: '$count$unit',
    many: '$count$unit',
    other: '$count$unit',
  );
}

String _daysAgo(int count, String locale) {
  final unit = _wordsFor(locale).day;
  return Intl.plural(
    count,
    locale: locale,
    one: '$count$unit',
    few: '$count$unit',
    many: '$count$unit',
    other: '$count$unit',
  );
}

String _wordNow(String locale) => _wordsFor(locale).now;

String _wordYesterday(String locale) => _wordsFor(locale).yesterday;

bool _hasExplicitTimeZone(String value) {
  return RegExp(r'(?:[tT ].*)(?:[zZ]|[+-]\d\d(?::?\d\d)?)$').hasMatch(value);
}
