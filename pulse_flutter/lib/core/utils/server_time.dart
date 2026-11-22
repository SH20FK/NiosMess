/// The server keeps UTC but may print it without an offset, and Dart reads
/// such a string as local time.
DateTime? parseServerUtc(Object? raw) {
  final DateTime? parsed = raw == null
      ? null
      : DateTime.tryParse(raw.toString());
  if (parsed == null || parsed.isUtc) return parsed;
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
