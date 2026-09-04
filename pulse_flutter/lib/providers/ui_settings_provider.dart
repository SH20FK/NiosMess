
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/services/background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTimeZoneMode { auto, manual }

enum BackgroundMode { off, economy, reliable }

enum AppFontScale {
  small(0.85),
  normal(1.0),
  large(1.15),
  extraLarge(1.3);

  const AppFontScale(this.scale);
  final double scale;
}

class VisualThemeSettings {
  const VisualThemeSettings({
    required this.seedColor,
    required this.themeMode,
    required this.useSystemDynamic,
    required this.predictiveBackEnabled,
    this.pureBlackOled = false,
  });

  final Color seedColor;
  final ThemeMode themeMode;
  final bool useSystemDynamic;
  final bool predictiveBackEnabled;
  final bool pureBlackOled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisualThemeSettings &&
          runtimeType == other.runtimeType &&
          seedColor == other.seedColor &&
          themeMode == other.themeMode &&
          useSystemDynamic == other.useSystemDynamic &&
          predictiveBackEnabled == other.predictiveBackEnabled &&
          pureBlackOled == other.pureBlackOled;

  @override
  int get hashCode =>
      seedColor.hashCode ^
      themeMode.hashCode ^
      useSystemDynamic.hashCode ^
      predictiveBackEnabled.hashCode ^
      pureBlackOled.hashCode;
}

class UiSettingsState {
  const UiSettingsState({
    required this.themeMode,
    required this.seedColor,
    required this.notifications,
    required this.compactMode,
    required this.haptics,
    required this.hideOnline,
    required this.soundEffects,
    required this.soundVolume,
    required this.localeCode,
    required this.timeZoneMode,
    required this.timeZoneId,
    required this.optimizeForWeakDevices,
    required this.predictiveBackEnabled,
    required this.backgroundMode,
    required this.useSystemDynamic,
    required this.fontScale,
    required this.navBarFloating,
    this.pureBlackOled = false,
    this.sendOnEnter = true,
    this.doubleTapReactionEmoji = '❤️',
    this.autoDownloadWifi = true,
    this.autoDownloadCellular = false,
  });

  VisualThemeSettings get visualTheme => VisualThemeSettings(
        seedColor: seedColor,
        themeMode: themeMode,
        useSystemDynamic: useSystemDynamic,
        predictiveBackEnabled: predictiveBackEnabled,
        pureBlackOled: pureBlackOled,
      );

  const UiSettingsState.defaults()
    : themeMode = ThemeMode.system,
      seedColor = const Color(0xFF6750A4),
      notifications = true,
      compactMode = false,
      haptics = true,
      hideOnline = false,
      soundEffects = true,
      soundVolume = 0.85,
      localeCode = null,
      timeZoneMode = AppTimeZoneMode.auto,
      timeZoneId = null,
      optimizeForWeakDevices = false,
      predictiveBackEnabled = true,
      backgroundMode = BackgroundMode.reliable,
      useSystemDynamic = false,
      fontScale = AppFontScale.normal,
      navBarFloating = true,
      pureBlackOled = false,
      sendOnEnter = true,
      doubleTapReactionEmoji = '❤️',
      autoDownloadWifi = true,
      autoDownloadCellular = false;

  final ThemeMode themeMode;
  final Color seedColor;
  final bool notifications;
  final bool compactMode;
  final bool haptics;
  final bool hideOnline;
  final bool soundEffects;
  final double soundVolume;
  final String? localeCode;
  final AppTimeZoneMode timeZoneMode;
  final String? timeZoneId;
  final bool optimizeForWeakDevices;
  final bool predictiveBackEnabled;
  final BackgroundMode backgroundMode;
  final bool useSystemDynamic;
  final AppFontScale fontScale;
  final bool navBarFloating;
  final bool pureBlackOled;
  final bool sendOnEnter;
  final String doubleTapReactionEmoji;
  final bool autoDownloadWifi;
  final bool autoDownloadCellular;

  UiSettingsState copyWith({
    ThemeMode? themeMode,
    Color? seedColor,
    bool? notifications,
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
    bool? predictiveBackEnabled,
    BackgroundMode? backgroundMode,
    bool? useSystemDynamic,
    AppFontScale? fontScale,
    bool? navBarFloating,
    bool? pureBlackOled,
    bool? sendOnEnter,
    String? doubleTapReactionEmoji,
    bool? autoDownloadWifi,
    bool? autoDownloadCellular,
  }) {
    return UiSettingsState(
      themeMode: themeMode ?? this.themeMode,
      seedColor: seedColor ?? this.seedColor,
      notifications: notifications ?? this.notifications,
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
      predictiveBackEnabled:
          predictiveBackEnabled ?? this.predictiveBackEnabled,
      backgroundMode: backgroundMode ?? this.backgroundMode,
      useSystemDynamic: useSystemDynamic ?? this.useSystemDynamic,
      fontScale: fontScale ?? this.fontScale,
      navBarFloating: navBarFloating ?? this.navBarFloating,
      pureBlackOled: pureBlackOled ?? this.pureBlackOled,
      sendOnEnter: sendOnEnter ?? this.sendOnEnter,
      doubleTapReactionEmoji:
          doubleTapReactionEmoji ?? this.doubleTapReactionEmoji,
      autoDownloadWifi: autoDownloadWifi ?? this.autoDownloadWifi,
      autoDownloadCellular:
          autoDownloadCellular ?? this.autoDownloadCellular,
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
  static const String _seedColorKey = 'ui.seedColor';
  static const String _notificationsKey = 'ui.notifications';
  static const String _compactKey = 'ui.compact';
  static const String _hapticsKey = 'ui.haptics';
  static const String _hideOnlineKey = 'ui.hideOnline';
  static const String _soundEffectsKey = 'ui.soundEffects';
  static const String _soundVolumeKey = 'ui.soundVolume';
  static const String _localeCodeKey = 'ui.localeCode';
  static const String _timeZoneModeKey = 'ui.timeZoneMode';
  static const String _timeZoneIdKey = 'ui.timeZoneId';
  static const String _optimizeWeakKey = 'ui.optimizeWeak';
  static const String _predictiveBackKey = 'ui.predictiveBack';
  static const String _backgroundModeKey = 'ui.backgroundMode';
  static const String _useSystemDynamicKey = 'ui.useSystemDynamic';
  static const String _fontScaleKey = 'ui.fontScale';
  static const String _navBarFloatingKey = 'ui.navBarFloating';
  static const String _pureBlackOledKey = 'ui.pureBlackOled';
  static const String _sendOnEnterKey = 'ui.sendOnEnter';
  static const String _doubleTapReactionEmojiKey = 'ui.doubleTapReactionEmoji';
  static const String _autoDownloadWifiKey = 'ui.autoDownloadWifi';
  static const String _autoDownloadCellularKey = 'ui.autoDownloadCellular';

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
    final int? seedRaw = prefs.getInt(_seedColorKey);
    final String? localeCodeRaw = prefs.getString(_localeCodeKey);
    final String? timeZoneModeRaw = prefs.getString(_timeZoneModeKey);
    final String? timeZoneIdRaw = prefs.getString(_timeZoneIdKey);

    state = state.copyWith(
      themeMode: ThemeMode.values.firstWhere(
        (ThemeMode mode) => mode.name == modeRaw,
        orElse: () => ThemeMode.system,
      ),
      seedColor: seedRaw == null ? state.seedColor : Color(seedRaw),
      notifications: prefs.getBool(_notificationsKey) ?? state.notifications,
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
      predictiveBackEnabled:
          prefs.getBool(_predictiveBackKey) ?? state.predictiveBackEnabled,
      backgroundMode: BackgroundMode.values.firstWhere(
        (BackgroundMode mode) =>
            mode.name == prefs.getString(_backgroundModeKey),
        orElse: () => BackgroundMode.reliable,
      ),
      useSystemDynamic:
          prefs.getBool(_useSystemDynamicKey) ?? state.useSystemDynamic,
      fontScale: AppFontScale.values.firstWhere(
        (AppFontScale fs) => fs.name == prefs.getString(_fontScaleKey),
        orElse: () => AppFontScale.normal,
      ),
      navBarFloating: prefs.getBool(_navBarFloatingKey) ?? true,
      pureBlackOled: prefs.getBool(_pureBlackOledKey) ?? state.pureBlackOled,
      sendOnEnter: prefs.getBool(_sendOnEnterKey) ?? state.sendOnEnter,
      doubleTapReactionEmoji:
          prefs.getString(_doubleTapReactionEmojiKey) ?? state.doubleTapReactionEmoji,
      autoDownloadWifi:
          prefs.getBool(_autoDownloadWifiKey) ?? state.autoDownloadWifi,
      autoDownloadCellular:
          prefs.getBool(_autoDownloadCellularKey) ?? state.autoDownloadCellular,
    );
    } catch (e) {
      debugPrint('[UiSettingsNotifier] Failed to load settings: $e');
    }
  }

  Future<void> _persist(UiSettingsState nextState) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await Future.wait(<Future<bool>>[
      prefs.setString(_themeModeKey, nextState.themeMode.name),
      prefs.setInt(_seedColorKey, nextState.seedColor.toARGB32()),
      prefs.setBool(_notificationsKey, nextState.notifications),
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
      prefs.setBool(_predictiveBackKey, nextState.predictiveBackEnabled),
      prefs.setString(_backgroundModeKey, nextState.backgroundMode.name),
      prefs.setBool(_useSystemDynamicKey, nextState.useSystemDynamic),
      prefs.setString(_fontScaleKey, nextState.fontScale.name),
      prefs.setBool(_navBarFloatingKey, nextState.navBarFloating),
      prefs.setBool(_pureBlackOledKey, nextState.pureBlackOled),
      prefs.setBool(_sendOnEnterKey, nextState.sendOnEnter),
      prefs.setString(_doubleTapReactionEmojiKey, nextState.doubleTapReactionEmoji),
      prefs.setBool(_autoDownloadWifiKey, nextState.autoDownloadWifi),
      prefs.setBool(_autoDownloadCellularKey, nextState.autoDownloadCellular),
    ]);
  }

  void _set(UiSettingsState nextState) {
    state = nextState;
    _persist(nextState);
  }

  void setThemeMode(ThemeMode value) {
    debugPrint('[UiSettingsNotifier] setThemeMode -> $value');
    _set(state.copyWith(themeMode: value));
  }

  void setSeedColor(Color value) => _set(state.copyWith(seedColor: value));

  void setNotifications(bool value) =>
      _set(state.copyWith(notifications: value));

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

  void setPredictiveBackEnabled(bool value) {
    debugPrint('[UiSettingsNotifier] setPredictiveBackEnabled -> $value');
    _set(state.copyWith(predictiveBackEnabled: value));
  }

  void setBackgroundMode(BackgroundMode value) {
    _set(state.copyWith(backgroundMode: value));
    if (value == BackgroundMode.reliable) {
      BackgroundService.startReliable();
    } else {
      BackgroundService.stop();
    }
  }

  void setUseSystemDynamic(bool value) =>
      _set(state.copyWith(useSystemDynamic: value));

  void setFontScale(AppFontScale value) =>
      _set(state.copyWith(fontScale: value));

  void setNavBarFloating(bool value) =>
      _set(state.copyWith(navBarFloating: value));

  void setPureBlackOled(bool value) =>
      _set(state.copyWith(pureBlackOled: value));

  void setSendOnEnter(bool value) =>
      _set(state.copyWith(sendOnEnter: value));

  void setDoubleTapReactionEmoji(String value) =>
      _set(state.copyWith(doubleTapReactionEmoji: value));

  void setAutoDownloadWifi(bool value) =>
      _set(state.copyWith(autoDownloadWifi: value));

  void setAutoDownloadCellular(bool value) =>
      _set(state.copyWith(autoDownloadCellular: value));
}

final NotifierProvider<UiSettingsNotifier, UiSettingsState> uiSettingsProvider =
    NotifierProvider<UiSettingsNotifier, UiSettingsState>(
      UiSettingsNotifier.new,
    );
