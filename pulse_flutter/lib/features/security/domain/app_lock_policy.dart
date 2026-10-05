import 'package:flutter/foundation.dart';

enum AppLockTimeout {
  immediately,
  after30Seconds,
  after1Minute,
  after5Minutes,
  after30Minutes;

  Duration get duration {
    switch (this) {
      case AppLockTimeout.immediately:
        return Duration.zero;
      case AppLockTimeout.after30Seconds:
        return const Duration(seconds: 30);
      case AppLockTimeout.after1Minute:
        return const Duration(minutes: 1);
      case AppLockTimeout.after5Minutes:
        return const Duration(minutes: 5);
      case AppLockTimeout.after30Minutes:
        return const Duration(minutes: 30);
    }
  }

  String get labelRu {
    switch (this) {
      case AppLockTimeout.immediately:
        return 'Сразу';
      case AppLockTimeout.after30Seconds:
        return 'Через 30 секунд';
      case AppLockTimeout.after1Minute:
        return 'Через 1 минуту';
      case AppLockTimeout.after5Minutes:
        return 'Через 5 минут';
      case AppLockTimeout.after30Minutes:
        return 'Через 30 минут';
    }
  }

  String get labelEn {
    switch (this) {
      case AppLockTimeout.immediately:
        return 'Immediately';
      case AppLockTimeout.after30Seconds:
        return 'After 30 seconds';
      case AppLockTimeout.after1Minute:
        return 'After 1 minute';
      case AppLockTimeout.after5Minutes:
        return 'After 5 minutes';
      case AppLockTimeout.after30Minutes:
        return 'After 30 minutes';
    }
  }

  static AppLockTimeout fromString(String? raw) {
    if (raw == null) return AppLockTimeout.immediately;
    for (final AppLockTimeout v in AppLockTimeout.values) {
      if (v.name == raw) return v;
    }
    return AppLockTimeout.immediately;
  }
}

@immutable
class AppLockState {
  final bool isEnabled;
  final AppLockTimeout timeout;
  final bool isSupported;
  final bool isLocked;
  final DateTime? lastBackgroundedAt;
  final bool isAuthenticating;

  const AppLockState({
    this.isEnabled = false,
    this.timeout = AppLockTimeout.immediately,
    this.isSupported = true,
    this.isLocked = false,
    this.lastBackgroundedAt,
    this.isAuthenticating = false,
  });

  AppLockState copyWith({
    bool? isEnabled,
    AppLockTimeout? timeout,
    bool? isSupported,
    bool? isLocked,
    DateTime? lastBackgroundedAt,
    bool clearLastBackgroundedAt = false,
    bool? isAuthenticating,
  }) {
    return AppLockState(
      isEnabled: isEnabled ?? this.isEnabled,
      timeout: timeout ?? this.timeout,
      isSupported: isSupported ?? this.isSupported,
      isLocked: isLocked ?? this.isLocked,
      lastBackgroundedAt: clearLastBackgroundedAt
          ? null
          : (lastBackgroundedAt ?? this.lastBackgroundedAt),
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppLockState &&
          runtimeType == other.runtimeType &&
          isEnabled == other.isEnabled &&
          timeout == other.timeout &&
          isSupported == other.isSupported &&
          isLocked == other.isLocked &&
          lastBackgroundedAt == other.lastBackgroundedAt &&
          isAuthenticating == other.isAuthenticating;

  @override
  int get hashCode => Object.hash(
        isEnabled,
        timeout,
        isSupported,
        isLocked,
        lastBackgroundedAt,
        isAuthenticating,
      );
}
