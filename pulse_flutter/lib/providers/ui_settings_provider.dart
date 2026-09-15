
import 'dart:async';
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

enum PaletteStyle {
  expressive(DynamicSchemeVariant.expressive),
  vibrant(DynamicSchemeVariant.vibrant),
  content(DynamicSchemeVariant.content),
  calm(DynamicSchemeVariant.fidelity),
  mono(DynamicSchemeVariant.monochrome);

  const PaletteStyle(this.variant);
  final DynamicSchemeVariant variant;
}

class VisualThemeSettings {
  const VisualThemeSettings({
    required this.seedColor,
    required this.themeMode,
    required this.useSystemDynamic,
    required this.predictiveBackEnabled,
    this.predictiveBackStrength = 1.0,
    this.pureBlackOled = false,
    this.uiCornerRadius = 20.0,
    this.paletteStyle = PaletteStyle.expressive,
  });

  final Color seedColor;
  final ThemeMode themeMode;
  final bool useSystemDynamic;
  final bool predictiveBackEnabled;
  final double predictiveBackStrength;
  final bool pureBlackOled;
  final double uiCornerRadius;
  final PaletteStyle paletteStyle;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisualThemeSettings &&
          runtimeType == other.runtimeType &&
          seedColor == other.seedColor &&
          themeMode == other.themeMode &&
          useSystemDynamic == other.useSystemDynamic &&
          predictiveBackEnabled == other.predictiveBackEnabled &&
          predictiveBackStrength == other.predictiveBackStrength &&
          pureBlackOled == other.pureBlackOled &&
          uiCornerRadius == other.uiCornerRadius &&
          paletteStyle == other.paletteStyle;

  @override
  int get hashCode =>
      seedColor.hashCode ^
      themeMode.hashCode ^
      useSystemDynamic.hashCode ^
      predictiveBackEnabled.hashCode ^
      predictiveBackStrength.hashCode ^
      pureBlackOled.hashCode ^
      uiCornerRadius.hashCode ^
      paletteStyle.hashCode;
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
    this.predictiveBackStrength = 1.0,
    required this.backgroundMode,
    required this.useSystemDynamic,
    required this.fontScale,
    required this.navBarFloating,
    this.pureBlackOled = false,
    this.sendOnEnter = true,
    this.doubleTapReactionEmoji = '❤️',
    this.autoDownloadWifi = true,
    this.autoDownloadCellular = false,
    this.messageBubbleRadius = 16.0,
    this.uiCornerRadius = 20.0,
    this.camera2Api = true,
    this.showPerformanceOverlay = false,
    this.debugRepaintRainbow = false,
    this.paletteStyle = PaletteStyle.expressive,
  });

  VisualThemeSettings get visualTheme => VisualThemeSettings(
        seedColor: seedColor,
        themeMode: themeMode,
        useSystemDynamic: useSystemDynamic,
        predictiveBackEnabled: predictiveBackEnabled,
        predictiveBackStrength: predictiveBackStrength,
        pureBlackOled: pureBlackOled,
        uiCornerRadius: uiCornerRadius,
        paletteStyle: paletteStyle,
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
      predictiveBackStrength = 1.0,
      backgroundMode = BackgroundMode.reliable,
      useSystemDynamic = false,
      fontScale = AppFontScale.normal,
      navBarFloating = false,
      pureBlackOled = false,
      sendOnEnter = true,
      doubleTapReactionEmoji = '❤️',
      autoDownloadWifi = true,
      autoDownloadCellular = false,
      messageBubbleRadius = 16.0,
      uiCornerRadius = 20.0,
      camera2Api = true,
      showPerformanceOverlay = false,
      debugRepaintRainbow = false,
      paletteStyle = PaletteStyle.expressive;

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
  final double predictiveBackStrength;
  final BackgroundMode backgroundMode;
  final bool useSystemDynamic;
  final AppFontScale fontScale;
  final bool navBarFloating;
  final bool pureBlackOled;
  final bool sendOnEnter;
  final String doubleTapReactionEmoji;
  final bool autoDownloadWifi;
  final bool autoDownloadCellular;
  final double messageBubbleRadius;
  final double uiCornerRadius;
  final bool camera2Api;
  final bool showPerformanceOverlay;
  final bool debugRepaintRainbow;
  final PaletteStyle paletteStyle;

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
    double? predictiveBackStrength,
    BackgroundMode? backgroundMode,
    bool? useSystemDynamic,
    AppFontScale? fontScale,
    bool? navBarFloating,
    bool? pureBlackOled,
    bool? sendOnEnter,
    String? doubleTapReactionEmoji,
    bool? autoDownloadWifi,
    bool? autoDownloadCellular,
    double? messageBubbleRadius,
    double? uiCornerRadius,
    bool? camera2Api,
    bool? showPerformanceOverlay,
    bool? debugRepaintRainbow,
    PaletteStyle? paletteStyle,
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
      predictiveBackStrength:
          predictiveBackStrength ?? this.predictiveBackStrength,
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
      messageBubbleRadius: messageBubbleRadius ?? this.messageBubbleRadius,
      uiCornerRadius: uiCornerRadius ?? this.uiCornerRadius,
      camera2Api: camera2Api ?? this.camera2Api,
      showPerformanceOverlay:
          showPerformanceOverlay ?? this.showPerformanceOverlay,
      debugRepaintRainbow:
          debugRepaintRainbow ?? this.debugRepaintRainbow,
      paletteStyle: paletteStyle ?? this.paletteStyle,
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
  static const String _paletteStyleKey = 'ui.paletteStyle';
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
  static const String _predictiveBackStrengthKey = 'ui.predictiveBackStrength';
  static const String _backgroundModeKey = 'ui.backgroundMode';
  static const String _useSystemDynamicKey = 'ui.useSystemDynamic';
  static const String _fontScaleKey = 'ui.fontScale';
  static const String _navBarFloatingKey = 'ui.navBarFloating';
  static const String _pureBlackOledKey = 'ui.pureBlackOled';
  static const String _sendOnEnterKey = 'ui.sendOnEnter';
  static const String _doubleTapReactionEmojiKey = 'ui.doubleTapReactionEmoji';
  static const String _autoDownloadWifiKey = 'ui.autoDownloadWifi';
  static const String _autoDownloadCellularKey = 'ui.autoDownloadCellular';
  static const String _messageBubbleRadiusKey = 'ui.messageBubbleRadius';
  static const String _uiCornerRadiusKey = 'ui.cornerRadius';
  static const String _camera2ApiKey = 'ui.camera2Api';

  static SharedPreferences? cachedPrefs;
  bool _loaded = false;
  Timer? _debounceTimer;
  final Map<String, Object?> _pendingKeyWrites = <String, Object?>{};

  static UiSettingsState readFromPrefs(SharedPreferences prefs) {
    final String? modeRaw = prefs.getString(_themeModeKey);
    final int? seedRaw = prefs.getInt(_seedColorKey);
    final String? paletteStyleRaw = prefs.getString(_paletteStyleKey);
    final String? localeCodeRaw = prefs.getString(_localeCodeKey);
    final String? timeZoneModeRaw = prefs.getString(_timeZoneModeKey);
    final String? timeZoneIdRaw = prefs.getString(_timeZoneIdKey);
    const UiSettingsState defaults = UiSettingsState.defaults();

    return defaults.copyWith(
      themeMode: ThemeMode.values.firstWhere(
        (ThemeMode mode) => mode.name == modeRaw,
        orElse: () => ThemeMode.system,
      ),
      seedColor: seedRaw == null ? defaults.seedColor : Color(seedRaw),
      paletteStyle: PaletteStyle.values.firstWhere(
        (PaletteStyle ps) => ps.name == paletteStyleRaw,
        orElse: () => PaletteStyle.expressive,
      ),
      notifications: prefs.getBool(_notificationsKey) ?? defaults.notifications,
      compactMode: prefs.getBool(_compactKey) ?? defaults.compactMode,
      haptics: prefs.getBool(_hapticsKey) ?? defaults.haptics,
      hideOnline: prefs.getBool(_hideOnlineKey) ?? defaults.hideOnline,
      soundEffects: prefs.getBool(_soundEffectsKey) ?? defaults.soundEffects,
      soundVolume: (prefs.getDouble(_soundVolumeKey) ?? defaults.soundVolume)
          .clamp(0.0, 1.0),
      localeCode: (localeCodeRaw ?? '').trim().isEmpty ? null : localeCodeRaw,
      timeZoneMode: AppTimeZoneMode.values.firstWhere(
        (AppTimeZoneMode mode) => mode.name == timeZoneModeRaw,
        orElse: () => AppTimeZoneMode.auto,
      ),
      timeZoneId: (timeZoneIdRaw ?? '').trim().isEmpty ? null : timeZoneIdRaw,
      optimizeForWeakDevices:
          prefs.getBool(_optimizeWeakKey) ?? defaults.optimizeForWeakDevices,
      predictiveBackEnabled:
          prefs.getBool(_predictiveBackKey) ?? defaults.predictiveBackEnabled,
      predictiveBackStrength: (prefs.getDouble(_predictiveBackStrengthKey) ??
              defaults.predictiveBackStrength)
          .clamp(0.5, 1.5),
      backgroundMode: BackgroundMode.values.firstWhere(
        (BackgroundMode mode) =>
            mode.name == prefs.getString(_backgroundModeKey),
        orElse: () => BackgroundMode.reliable,
      ),
      useSystemDynamic:
          prefs.getBool(_useSystemDynamicKey) ?? defaults.useSystemDynamic,
      fontScale: AppFontScale.values.firstWhere(
        (AppFontScale fs) => fs.name == prefs.getString(_fontScaleKey),
        orElse: () => AppFontScale.normal,
      ),
      navBarFloating: prefs.getBool(_navBarFloatingKey) ?? defaults.navBarFloating,
      pureBlackOled: prefs.getBool(_pureBlackOledKey) ?? defaults.pureBlackOled,
      sendOnEnter: prefs.getBool(_sendOnEnterKey) ?? defaults.sendOnEnter,
      doubleTapReactionEmoji:
          prefs.getString(_doubleTapReactionEmojiKey) ?? defaults.doubleTapReactionEmoji,
      autoDownloadWifi:
          prefs.getBool(_autoDownloadWifiKey) ?? defaults.autoDownloadWifi,
      autoDownloadCellular:
          prefs.getBool(_autoDownloadCellularKey) ?? defaults.autoDownloadCellular,
      messageBubbleRadius:
          prefs.getDouble(_messageBubbleRadiusKey) ?? defaults.messageBubbleRadius,
      uiCornerRadius:
          prefs.getDouble(_uiCornerRadiusKey) ?? defaults.uiCornerRadius,
      camera2Api: prefs.getBool(_camera2ApiKey) ?? defaults.camera2Api,
    );
  }

  @override
  UiSettingsState build() {
    if (cachedPrefs != null) {
      _loaded = true;
      return readFromPrefs(cachedPrefs!);
    }
    _load();
    return const UiSettingsState.defaults();
  }

  Future<void> _load() async {
    if (_loaded) return;
    try {
      final SharedPreferences prefs = cachedPrefs ?? await SharedPreferences.getInstance();
      cachedPrefs = prefs;
      if (_loaded) return;
      _loaded = true;
      state = readFromPrefs(prefs);
    } catch (e) {
      debugPrint('[UiSettingsNotifier] Failed to load settings: $e');
    }
  }

  Future<SharedPreferences> _getPrefs() async {
    return cachedPrefs ??= await SharedPreferences.getInstance();
  }

  Future<void> _persistKey(String key, Object? value) async {
    try {
      final SharedPreferences prefs = await _getPrefs();
      if (value == null) {
        await prefs.remove(key);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    } catch (e) {
      debugPrint('[UiSettingsNotifier] Failed to persist key $key: $e');
    }
  }

  void _persistKeyDebounced(
    String key,
    Object? value, {
    Duration duration = const Duration(milliseconds: 250),
  }) {
    _pendingKeyWrites[key] = value;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration, () {
      _flushPendingWrites();
    });
  }

  Future<void> _flushPendingWrites() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (_pendingKeyWrites.isEmpty) return;
    final Map<String, Object?> toWrite = Map<String, Object?>.from(_pendingKeyWrites);
    _pendingKeyWrites.clear();
    for (final MapEntry<String, Object?> entry in toWrite.entries) {
      await _persistKey(entry.key, entry.value);
    }
  }

  Future<void> flushPersist() => _flushPendingWrites();

  void setMessageBubbleRadius(double value) {
    state = state.copyWith(messageBubbleRadius: value);
    _persistKeyDebounced(_messageBubbleRadiusKey, value);
  }

  void setUiCornerRadius(double value) {
    state = state.copyWith(uiCornerRadius: value);
    _persistKeyDebounced(_uiCornerRadiusKey, value);
  }

  void setThemeMode(ThemeMode value) {
    debugPrint('[UiSettingsNotifier] setThemeMode -> $value');
    state = state.copyWith(themeMode: value);
    _persistKey(_themeModeKey, value.name);
  }

  void setSeedColor(Color value) {
    state = state.copyWith(seedColor: value);
    _persistKey(_seedColorKey, value.toARGB32());
  }

  void setNotifications(bool value) {
    state = state.copyWith(notifications: value);
    _persistKey(_notificationsKey, value);
  }

  void setCompactMode(bool value) {
    state = state.copyWith(compactMode: value);
    _persistKey(_compactKey, value);
  }

  void setHaptics(bool value) {
    state = state.copyWith(haptics: value);
    _persistKey(_hapticsKey, value);
  }

  void setHideOnline(bool value) {
    state = state.copyWith(hideOnline: value);
    _persistKey(_hideOnlineKey, value);
  }

  void setSoundEffects(bool value) {
    state = state.copyWith(soundEffects: value);
    _persistKey(_soundEffectsKey, value);
  }

  void setSoundVolume(double value) {
    final double clamped = value.clamp(0.0, 1.0);
    state = state.copyWith(soundVolume: clamped);
    _persistKeyDebounced(_soundVolumeKey, clamped);
  }

  void setLocaleCode(String? value) {
    final String? normalized =
        (value ?? '').trim().isEmpty ? null : value!.trim().toLowerCase();
    state = normalized == null
        ? state.copyWith(clearLocaleCode: true)
        : state.copyWith(localeCode: normalized);
    _persistKey(_localeCodeKey, normalized);
  }

  void setTimeZoneMode(AppTimeZoneMode value) {
    state = state.copyWith(timeZoneMode: value);
    _persistKey(_timeZoneModeKey, value.name);
  }

  void setTimeZoneId(String? value) {
    final String? normalized =
        (value ?? '').trim().isEmpty ? null : value!.trim();
    state = normalized == null
        ? state.copyWith(clearTimeZoneId: true)
        : state.copyWith(timeZoneId: normalized);
    _persistKey(_timeZoneIdKey, normalized);
  }

  void useAutomaticTimeZone() {
    state = state.copyWith(timeZoneMode: AppTimeZoneMode.auto);
    _persistKey(_timeZoneModeKey, AppTimeZoneMode.auto.name);
  }

  void useManualTimeZone(String timeZoneId) {
    final String trimmed = timeZoneId.trim();
    state = state.copyWith(
      timeZoneMode: AppTimeZoneMode.manual,
      timeZoneId: trimmed,
    );
    _persistKey(_timeZoneModeKey, AppTimeZoneMode.manual.name);
    _persistKey(_timeZoneIdKey, trimmed);
  }

  void setOptimizeForWeakDevices(bool value) {
    state = state.copyWith(optimizeForWeakDevices: value);
    _persistKey(_optimizeWeakKey, value);
  }

  void setPredictiveBackEnabled(bool value) {
    debugPrint('[UiSettingsNotifier] setPredictiveBackEnabled -> $value');
    state = state.copyWith(predictiveBackEnabled: value);
    _persistKey(_predictiveBackKey, value);
  }

  void setPredictiveBackStrength(double value) {
    debugPrint('[UiSettingsNotifier] setPredictiveBackStrength -> $value');
    final double clamped = value.clamp(0.5, 1.5);
    state = state.copyWith(predictiveBackStrength: clamped);
    _persistKeyDebounced(_predictiveBackStrengthKey, clamped);
  }

  void setBackgroundMode(BackgroundMode value) {
    state = state.copyWith(backgroundMode: value);
    _persistKey(_backgroundModeKey, value.name);
    if (value == BackgroundMode.reliable) {
      BackgroundService.startReliable();
    } else {
      BackgroundService.stop();
    }
  }

  void setUseSystemDynamic(bool value) {
    state = state.copyWith(useSystemDynamic: value);
    _persistKey(_useSystemDynamicKey, value);
  }

  void setFontScale(AppFontScale value) {
    state = state.copyWith(fontScale: value);
    _persistKey(_fontScaleKey, value.name);
  }

  void setNavBarFloating(bool value) {
    state = state.copyWith(navBarFloating: value);
    _persistKey(_navBarFloatingKey, value);
  }

  void setPureBlackOled(bool value) {
    state = state.copyWith(pureBlackOled: value);
    _persistKey(_pureBlackOledKey, value);
  }

  void setSendOnEnter(bool value) {
    state = state.copyWith(sendOnEnter: value);
    _persistKey(_sendOnEnterKey, value);
  }

  void setDoubleTapReactionEmoji(String value) {
    state = state.copyWith(doubleTapReactionEmoji: value);
    _persistKey(_doubleTapReactionEmojiKey, value);
  }

  void setAutoDownloadWifi(bool value) {
    state = state.copyWith(autoDownloadWifi: value);
    _persistKey(_autoDownloadWifiKey, value);
  }

  void setAutoDownloadCellular(bool value) {
    state = state.copyWith(autoDownloadCellular: value);
    _persistKey(_autoDownloadCellularKey, value);
  }

  void setCamera2Api(bool value) {
    state = state.copyWith(camera2Api: value);
    _persistKey(_camera2ApiKey, value);
  }

  void setPaletteStyle(PaletteStyle value) {
    state = state.copyWith(paletteStyle: value);
    _persistKey(_paletteStyleKey, value.name);
  }

  void setShowPerformanceOverlay(bool value) {
    state = state.copyWith(showPerformanceOverlay: value);
  }

  void setDebugRepaintRainbow(bool value) {
    state = state.copyWith(debugRepaintRainbow: value);
  }

  /// Resets all settings fields safely to [UiSettingsState.defaults()],
  /// keeping background message delivery in [BackgroundMode.reliable]
  /// and cleaning up persisted SharedPreferences keys in a single atomic batch.
  Future<void> resetAll() async {
    _debounceTimer?.cancel();
    _pendingKeyWrites.clear();
    const UiSettingsState defaultState = UiSettingsState.defaults();
    state = defaultState;
    final SharedPreferences prefs = await _getPrefs();
    await Future.wait(<Future<bool>>[
      prefs.remove(_themeModeKey),
      prefs.remove(_seedColorKey),
      prefs.remove(_paletteStyleKey),
      prefs.remove(_notificationsKey),
      prefs.remove(_compactKey),
      prefs.remove(_hapticsKey),
      prefs.remove(_hideOnlineKey),
      prefs.remove(_soundEffectsKey),
      prefs.remove(_soundVolumeKey),
      prefs.remove(_localeCodeKey),
      prefs.remove(_timeZoneModeKey),
      prefs.remove(_timeZoneIdKey),
      prefs.remove(_optimizeWeakKey),
      prefs.remove(_predictiveBackKey),
      prefs.remove(_predictiveBackStrengthKey),
      prefs.remove(_backgroundModeKey),
      prefs.remove(_useSystemDynamicKey),
      prefs.remove(_fontScaleKey),
      prefs.remove(_navBarFloatingKey),
      prefs.remove(_pureBlackOledKey),
      prefs.remove(_sendOnEnterKey),
      prefs.remove(_doubleTapReactionEmojiKey),
      prefs.remove(_autoDownloadWifiKey),
      prefs.remove(_autoDownloadCellularKey),
      prefs.remove(_messageBubbleRadiusKey),
      prefs.remove(_uiCornerRadiusKey),
      prefs.remove(_camera2ApiKey),
    ]);
  }
}

final NotifierProvider<UiSettingsNotifier, UiSettingsState> uiSettingsProvider =
    NotifierProvider<UiSettingsNotifier, UiSettingsState>(
      UiSettingsNotifier.new,
    );
