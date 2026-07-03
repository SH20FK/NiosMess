import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Md3Variant {
  tonalSpot,
  vibrant,
  expressive,
  neutral,
  monochrome,
  fidelity,
}

enum AppTimeZoneMode { auto, manual }

class UiSettingsState {
  const UiSettingsState({
    required this.themeMode,
    required this.variant,
    required this.seedColor,
    required this.notifications,
    required this.darkCallBackdrop,
    required this.compactMode,
    required this.haptics,
    required this.hideOnline,
    required this.soundEffects,
    required this.soundVolume,
    required this.localeCode,
    required this.timeZoneMode,
    required this.timeZoneId,
    required this.optimizeForWeakDevices,
  });

  const UiSettingsState.defaults()
    : themeMode = ThemeMode.system,
      variant = Md3Variant.tonalSpot,
      seedColor = const Color(0xFF6750A4),
      notifications = true,
      darkCallBackdrop = false,
      compactMode = false,
      haptics = true,
      hideOnline = false,
      soundEffects = true,
      soundVolume = 0.85,
      localeCode = null,
      timeZoneMode = AppTimeZoneMode.auto,
      timeZoneId = null,
      optimizeForWeakDevices = false;

  final ThemeMode themeMode;
  final Md3Variant variant;
  final Color seedColor;
  final bool notifications;
  final bool darkCallBackdrop;
  final bool compactMode;
  final bool haptics;
  final bool hideOnline;
  final bool soundEffects;
  final double soundVolume;
  final String? localeCode;
  final AppTimeZoneMode timeZoneMode;
  final String? timeZoneId;
  final bool optimizeForWeakDevices;

  UiSettingsState copyWith({
    ThemeMode? themeMode,
    Md3Variant? variant,
    Color? seedColor,
    bool? notifications,
    bool? darkCallBackdrop,
    bool? compactMode,
    bool? haptics,
    bool? hideOnline,
    bool? soundEffects,
    double? soundVolume,
    String? localeCode,
    bool clearLocaleCode = false,
    AppTimeZoneMode? timeZoneMode,
    String? timeZoneId,
    bool clearTimeZoneId = false,
    bool? optimizeForWeakDevices,
  }) {
    return UiSettingsState(
      themeMode: themeMode ?? this.themeMode,
      variant: variant ?? this.variant,
      seedColor: seedColor ?? this.seedColor,
      notifications: notifications ?? this.notifications,
      darkCallBackdrop: darkCallBackdrop ?? this.darkCallBackdrop,
      compactMode: compactMode ?? this.compactMode,
      haptics: haptics ?? this.haptics,
      hideOnline: hideOnline ?? this.hideOnline,
      soundEffects: soundEffects ?? this.soundEffects,
      soundVolume: soundVolume ?? this.soundVolume,
      localeCode: clearLocaleCode ? null : (localeCode ?? this.localeCode),
      timeZoneMode: timeZoneMode ?? this.timeZoneMode,
      timeZoneId: clearTimeZoneId ? null : (timeZoneId ?? this.timeZoneId),
      optimizeForWeakDevices:
          optimizeForWeakDevices ?? this.optimizeForWeakDevices,
    );
  }

  String effectiveLocaleCode(String systemLanguageCode) {
    final String normalized = (localeCode ?? '').trim().toLowerCase();
    if (normalized == 'ru' || normalized == 'en') return normalized;
    return systemLanguageCode.toLowerCase().startsWith('ru') ? 'ru' : 'en';
  }
}

class UiSettingsNotifier extends Notifier<UiSettingsState> {
  static const String _themeModeKey = 'ui.themeMode';
  static const String _variantKey = 'ui.variant';
  static const String _seedColorKey = 'ui.seedColor';
  static const String _notificationsKey = 'ui.notifications';
  static const String _darkBackdropKey = 'ui.darkBackdrop';
  static const String _compactKey = 'ui.compact';
  static const String _hapticsKey = 'ui.haptics';
  static const String _hideOnlineKey = 'ui.hideOnline';
  static const String _soundEffectsKey = 'ui.soundEffects';
  static const String _soundVolumeKey = 'ui.soundVolume';
  static const String _localeCodeKey = 'ui.localeCode';
  static const String _timeZoneModeKey = 'ui.timeZoneMode';
  static const String _timeZoneIdKey = 'ui.timeZoneId';
  static const String _optimizeWeakKey = 'ui.optimizeWeak';

  bool _loaded = false;

  @override
  UiSettingsState build() {
    _load();
    return const UiSettingsState.defaults();
  }

  Future<void> _load() async {
    try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_loaded) return;
    _loaded = true;
    final String? modeRaw = prefs.getString(_themeModeKey);
    final String? variantRaw = prefs.getString(_variantKey);
    final int? seedRaw = prefs.getInt(_seedColorKey);
    final String? localeCodeRaw = prefs.getString(_localeCodeKey);
    final String? timeZoneModeRaw = prefs.getString(_timeZoneModeKey);
    final String? timeZoneIdRaw = prefs.getString(_timeZoneIdKey);

    state = state.copyWith(
      themeMode: ThemeMode.values.firstWhere(
        (ThemeMode mode) => mode.name == modeRaw,
        orElse: () => ThemeMode.system,
      ),
      variant: Md3Variant.values.firstWhere(
        (Md3Variant variant) => variant.name == variantRaw,
        orElse: () => Md3Variant.tonalSpot,
      ),
      seedColor: seedRaw == null ? state.seedColor : Color(seedRaw),
      notifications: prefs.getBool(_notificationsKey) ?? state.notifications,
      darkCallBackdrop:
          prefs.getBool(_darkBackdropKey) ?? state.darkCallBackdrop,
      compactMode: prefs.getBool(_compactKey) ?? state.compactMode,
      haptics: prefs.getBool(_hapticsKey) ?? state.haptics,
      hideOnline: prefs.getBool(_hideOnlineKey) ?? state.hideOnline,
      soundEffects: prefs.getBool(_soundEffectsKey) ?? state.soundEffects,
      soundVolume: (prefs.getDouble(_soundVolumeKey) ?? state.soundVolume)
          .clamp(0.0, 1.0),
      localeCode: (localeCodeRaw ?? '').trim().isEmpty ? null : localeCodeRaw,
      timeZoneMode: AppTimeZoneMode.values.firstWhere(
        (AppTimeZoneMode mode) => mode.name == timeZoneModeRaw,
        orElse: () => AppTimeZoneMode.auto,
      ),
      timeZoneId: (timeZoneIdRaw ?? '').trim().isEmpty ? null : timeZoneIdRaw,
      optimizeForWeakDevices:
          prefs.getBool(_optimizeWeakKey) ?? state.optimizeForWeakDevices,
    );
    } catch (e) {
      debugPrint('[UiSettingsNotifier] Failed to load settings: $e');
    }
  }

  Future<void> _persist(UiSettingsState nextState) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await Future.wait(<Future<bool>>[
      prefs.setString(_themeModeKey, nextState.themeMode.name),
      prefs.setString(_variantKey, nextState.variant.name),
      prefs.setInt(_seedColorKey, nextState.seedColor.toARGB32()),
      prefs.setBool(_notificationsKey, nextState.notifications),
      prefs.setBool(_darkBackdropKey, nextState.darkCallBackdrop),
      prefs.setBool(_compactKey, nextState.compactMode),
      prefs.setBool(_hapticsKey, nextState.haptics),
      prefs.setBool(_hideOnlineKey, nextState.hideOnline),
      prefs.setBool(_soundEffectsKey, nextState.soundEffects),
      prefs.setDouble(_soundVolumeKey, nextState.soundVolume),
      if ((nextState.localeCode ?? '').trim().isEmpty)
        prefs.remove(_localeCodeKey)
      else
        prefs.setString(_localeCodeKey, nextState.localeCode!),
      prefs.setString(_timeZoneModeKey, nextState.timeZoneMode.name),
      if ((nextState.timeZoneId ?? '').trim().isEmpty)
        prefs.remove(_timeZoneIdKey)
      else
        prefs.setString(_timeZoneIdKey, nextState.timeZoneId!),
      prefs.setBool(_optimizeWeakKey, nextState.optimizeForWeakDevices),
    ]);
  }

  void _set(UiSettingsState nextState) {
    state = nextState;
    _persist(nextState);
  }

  void setThemeMode(ThemeMode value) => _set(state.copyWith(themeMode: value));

  void setVariant(Md3Variant value) => _set(state.copyWith(variant: value));

  void setSeedColor(Color value) => _set(state.copyWith(seedColor: value));

  void setNotifications(bool value) =>
      _set(state.copyWith(notifications: value));

  void setDarkCallBackdrop(bool value) =>
      _set(state.copyWith(darkCallBackdrop: value));

  void setCompactMode(bool value) => _set(state.copyWith(compactMode: value));

  void setHaptics(bool value) => _set(state.copyWith(haptics: value));

  void setHideOnline(bool value) => _set(state.copyWith(hideOnline: value));

  void setSoundEffects(bool value) => _set(state.copyWith(soundEffects: value));

  void setSoundVolume(double value) =>
      _set(state.copyWith(soundVolume: value.clamp(0.0, 1.0)));

  void setLocaleCode(String? value) => _set(
    value == null || value.trim().isEmpty
        ? state.copyWith(clearLocaleCode: true)
        : state.copyWith(localeCode: value.trim().toLowerCase()),
  );

  void setTimeZoneMode(AppTimeZoneMode value) =>
      _set(state.copyWith(timeZoneMode: value));

  void setTimeZoneId(String? value) => _set(
    value == null || value.trim().isEmpty
        ? state.copyWith(clearTimeZoneId: true)
        : state.copyWith(timeZoneId: value.trim()),
  );

  void useAutomaticTimeZone() =>
      _set(state.copyWith(timeZoneMode: AppTimeZoneMode.auto));

  void useManualTimeZone(String timeZoneId) => _set(
    state.copyWith(
      timeZoneMode: AppTimeZoneMode.manual,
      timeZoneId: timeZoneId,
    ),
  );

  void setOptimizeForWeakDevices(bool value) =>
      _set(state.copyWith(optimizeForWeakDevices: value));
}

final NotifierProvider<UiSettingsNotifier, UiSettingsState> uiSettingsProvider =
    NotifierProvider<UiSettingsNotifier, UiSettingsState>(
      UiSettingsNotifier.new,
    );
