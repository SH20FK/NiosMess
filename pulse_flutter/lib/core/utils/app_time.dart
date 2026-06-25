import 'package:intl/intl.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class AppTimeSettings {
  AppTimeSettings._();

  static bool _initialized = false;
  static String _localeCode = 'en';
  static AppTimeZoneMode _timeZoneMode = AppTimeZoneMode.auto;
  static String? _timeZoneId;

  static void initialize() {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    _initialized = true;
  }

  static void configure({
    required String localeCode,
    required AppTimeZoneMode timeZoneMode,
    required String? timeZoneId,
  }) {
    initialize();
    _localeCode = localeCode;
    _timeZoneMode = timeZoneMode;
    _timeZoneId = timeZoneId;
    Intl.defaultLocale = localeCode;
  }

  static String get localeCode => _localeCode;

  static DateTime now() {
    initialize();
    if (_timeZoneMode == AppTimeZoneMode.manual &&
        (_timeZoneId ?? '').trim().isNotEmpty) {
      try {
        return tz.TZDateTime.now(tz.getLocation(_timeZoneId!.trim()));
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  static DateTime resolve(DateTime dateTime) {
    initialize();
    final DateTime base = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    if (_timeZoneMode == AppTimeZoneMode.manual &&
        (_timeZoneId ?? '').trim().isNotEmpty) {
      try {
        return tz.TZDateTime.from(
          base.toUtc(),
          tz.getLocation(_timeZoneId!.trim()),
        );
      } catch (_) {
        return base;
      }
    }
    return base;
  }
}

class AppTimeZoneOption {
  const AppTimeZoneOption({required this.id, required this.label});

  final String id;
  final String label;

  String currentOffsetLabel() {
    try {
      final tz.Location location = tz.getLocation(id);
      final tz.TZDateTime now = tz.TZDateTime.now(location);
      final Duration offset = now.timeZoneOffset;
      final String sign = offset.isNegative ? '-' : '+';
      final int hours = offset.inHours.abs();
      final int minutes = offset.inMinutes.abs() % 60;
      return 'UTC$sign${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'UTC';
    }
  }
}

const List<AppTimeZoneOption> appTimeZoneOptions = <AppTimeZoneOption>[
  AppTimeZoneOption(id: 'UTC', label: 'UTC'),
  AppTimeZoneOption(id: 'Europe/London', label: 'London'),
  AppTimeZoneOption(id: 'Europe/Berlin', label: 'Berlin'),
  AppTimeZoneOption(id: 'Europe/Paris', label: 'Paris'),
  AppTimeZoneOption(id: 'Europe/Madrid', label: 'Madrid'),
  AppTimeZoneOption(id: 'Europe/Rome', label: 'Rome'),
  AppTimeZoneOption(id: 'Europe/Moscow', label: 'Moscow'),
  AppTimeZoneOption(id: 'Europe/Kaliningrad', label: 'Kaliningrad'),
  AppTimeZoneOption(id: 'Europe/Samara', label: 'Samara'),
  AppTimeZoneOption(id: 'Asia/Yekaterinburg', label: 'Yekaterinburg'),
  AppTimeZoneOption(id: 'Asia/Omsk', label: 'Omsk'),
  AppTimeZoneOption(id: 'Asia/Krasnoyarsk', label: 'Krasnoyarsk'),
  AppTimeZoneOption(id: 'Asia/Irkutsk', label: 'Irkutsk'),
  AppTimeZoneOption(id: 'Asia/Yakutsk', label: 'Yakutsk'),
  AppTimeZoneOption(id: 'Asia/Vladivostok', label: 'Vladivostok'),
  AppTimeZoneOption(id: 'Asia/Magadan', label: 'Magadan'),
  AppTimeZoneOption(id: 'Asia/Kamchatka', label: 'Kamchatka'),
  AppTimeZoneOption(id: 'Asia/Tbilisi', label: 'Tbilisi'),
  AppTimeZoneOption(id: 'Asia/Baku', label: 'Baku'),
  AppTimeZoneOption(id: 'Asia/Dubai', label: 'Dubai'),
  AppTimeZoneOption(id: 'Asia/Yerevan', label: 'Yerevan'),
  AppTimeZoneOption(id: 'Asia/Almaty', label: 'Almaty'),
  AppTimeZoneOption(id: 'Asia/Tashkent', label: 'Tashkent'),
  AppTimeZoneOption(id: 'Asia/Bishkek', label: 'Bishkek'),
  AppTimeZoneOption(id: 'Asia/Novosibirsk', label: 'Novosibirsk'),
  AppTimeZoneOption(id: 'Asia/Shanghai', label: 'Shanghai'),
  AppTimeZoneOption(id: 'Asia/Hong_Kong', label: 'Hong Kong'),
  AppTimeZoneOption(id: 'Asia/Seoul', label: 'Seoul'),
  AppTimeZoneOption(id: 'Asia/Tokyo', label: 'Tokyo'),
  AppTimeZoneOption(id: 'Asia/Bangkok', label: 'Bangkok'),
  AppTimeZoneOption(id: 'Asia/Singapore', label: 'Singapore'),
  AppTimeZoneOption(id: 'Asia/Jakarta', label: 'Jakarta'),
  AppTimeZoneOption(id: 'Australia/Perth', label: 'Perth'),
  AppTimeZoneOption(id: 'Australia/Sydney', label: 'Sydney'),
  AppTimeZoneOption(id: 'Pacific/Auckland', label: 'Auckland'),
  AppTimeZoneOption(id: 'America/New_York', label: 'New York'),
  AppTimeZoneOption(id: 'America/Chicago', label: 'Chicago'),
  AppTimeZoneOption(id: 'America/Denver', label: 'Denver'),
  AppTimeZoneOption(id: 'America/Los_Angeles', label: 'Los Angeles'),
  AppTimeZoneOption(id: 'America/Toronto', label: 'Toronto'),
  AppTimeZoneOption(id: 'America/Sao_Paulo', label: 'Sao Paulo'),
];
