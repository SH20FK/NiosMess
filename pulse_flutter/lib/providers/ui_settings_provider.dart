
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    this.uiCornerRadius = 20.0,
    this.paletteStyle = PaletteStyle.expressive,
  });

  final Color seedColor;
  final ThemeMode themeMode;
  final bool useSystemDynamic;
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
          uiCornerRadius == other.uiCornerRadius &&
          paletteStyle == other.paletteStyle;

  @override
  int get hashCode =>
      seedColor.hashCode ^
      themeMode.hashCode ^
      useSystemDynamic.hashCode ^
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
    required this.backgroundMode,
    required this.useSystemDynamic,
    required this.fontScale,
    this.sendOnEnter = true,
    this.doubleTapReactionEmoji = '❤️',
    this.autoDownloadWifi = true,
    this.autoDownloadCellular = false,
    this.autoDownloadRoaming = false,
    this.messageBubbleRadius = 16.0,
    this.uiCornerRadius = 20.0,
    this.paletteStyle = PaletteStyle.expressive,
    this.autoPauseVideoOnBackground = true,
    this.energySavingThreshold = 20,
    this.animateStickers = true,
    this.animateEmoji = true,
    this.saveToGalleryPrivate = false,
    this.saveToGalleryGroups = false,
    this.saveToGalleryChannels = false,
    this.linkPreviewsInSecretChats = false,
    this.secureScreenshotsInSecretChats = true,
  });

  VisualThemeSettings get visualTheme => VisualThemeSettings(
        seedColor: seedColor,
        themeMode: themeMode,
        useSystemDynamic: useSystemDynamic,
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
      soundEffects = false,
      soundVolume = 0.85,
      localeCode = null,
      timeZoneMode = AppTimeZoneMode.auto,
      timeZoneId = null,
      optimizeForWeakDevices = false,
      backgroundMode = BackgroundMode.reliable,
      useSystemDynamic = false,
      fontScale = AppFontScale.normal,
      sendOnEnter = true,
      doubleTapReactionEmoji = '❤️',
      autoDownloadWifi = true,
      autoDownloadCellular = false,
      autoDownloadRoaming = false,
      messageBubbleRadius = 16.0,
      uiCornerRadius = 20.0,
      paletteStyle = PaletteStyle.expressive,
      autoPauseVideoOnBackground = true,
      energySavingThreshold = 20,
      animateStickers = true,
      animateEmoji = true,
      saveToGalleryPrivate = false,
      saveToGalleryGroups = false,
      saveToGalleryChannels = false,
      linkPreviewsInSecretChats = false,
      secureScreenshotsInSecretChats = true;

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
  final BackgroundMode backgroundMode;
  final bool useSystemDynamic;
  final AppFontScale fontScale;
  final bool sendOnEnter;
  final String doubleTapReactionEmoji;
  final bool autoDownloadWifi;
  final bool autoDownloadCellular;
  final bool autoDownloadRoaming;
  final double messageBubbleRadius;
  final double uiCornerRadius;
  final PaletteStyle paletteStyle;
  final bool autoPauseVideoOnBackground;
  final int energySavingThreshold;
  final bool animateStickers;
  final bool animateEmoji;
  final bool saveToGalleryPrivate;
  final bool saveToGalleryGroups;
  final bool saveToGalleryChannels;
  final bool linkPreviewsInSecretChats;
  final bool secureScreenshotsInSecretChats;

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
    BackgroundMode? backgroundMode,
    bool? useSystemDynamic,
    AppFontScale? fontScale,
    bool? sendOnEnter,
    String? doubleTapReactionEmoji,
    bool? autoDownloadWifi,
    bool? autoDownloadCellular,
    bool? autoDownloadRoaming,
    double? messageBubbleRadius,
    double? uiCornerRadius,
    PaletteStyle? paletteStyle,
    bool? autoPauseVideoOnBackground,
    int? energySavingThreshold,
    bool? animateStickers,
    bool? animateEmoji,
    bool? saveToGalleryPrivate,
    bool? saveToGalleryGroups,
    bool? saveToGalleryChannels,
    bool? linkPreviewsInSecretChats,
    bool? secureScreenshotsInSecretChats,
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
      backgroundMode: backgroundMode ?? this.backgroundMode,
      useSystemDynamic: useSystemDynamic ?? this.useSystemDynamic,
      fontScale: fontScale ?? this.fontScale,
      sendOnEnter: sendOnEnter ?? this.sendOnEnter,
      doubleTapReactionEmoji:
          doubleTapReactionEmoji ?? this.doubleTapReactionEmoji,
      autoDownloadWifi: autoDownloadWifi ?? this.autoDownloadWifi,
      autoDownloadCellular:
          autoDownloadCellular ?? this.autoDownloadCellular,
      autoDownloadRoaming:
          autoDownloadRoaming ?? this.autoDownloadRoaming,
      messageBubbleRadius: messageBubbleRadius ?? this.messageBubbleRadius,
      uiCornerRadius: uiCornerRadius ?? this.uiCornerRadius,
      paletteStyle: paletteStyle ?? this.paletteStyle,
      autoPauseVideoOnBackground:
          autoPauseVideoOnBackground ?? this.autoPauseVideoOnBackground,
      energySavingThreshold:
          energySavingThreshold ?? this.energySavingThreshold,
      animateStickers: animateStickers ?? this.animateStickers,
      animateEmoji: animateEmoji ?? this.animateEmoji,
      saveToGalleryPrivate: saveToGalleryPrivate ?? this.saveToGalleryPrivate,
      saveToGalleryGroups: saveToGalleryGroups ?? this.saveToGalleryGroups,
      saveToGalleryChannels:
          saveToGalleryChannels ?? this.saveToGalleryChannels,
      linkPreviewsInSecretChats:
          linkPreviewsInSecretChats ?? this.linkPreviewsInSecretChats,
      secureScreenshotsInSecretChats:
          secureScreenshotsInSecretChats ?? this.secureScreenshotsInSecretChats,
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
  static const String _backgroundModeKey = 'ui.backgroundMode';
  static const String _useSystemDynamicKey = 'ui.useSystemDynamic';
  static const String _fontScaleKey = 'ui.fontScale';
  static const String _sendOnEnterKey = 'ui.sendOnEnter';
  static const String _doubleTapReactionEmojiKey = 'ui.doubleTapReactionEmoji';
  static const String _autoDownloadWifiKey = 'ui.autoDownloadWifi';
  static const String _autoDownloadCellularKey = 'ui.autoDownloadCellular';
  static const String _autoDownloadRoamingKey = 'ui.autoDownloadRoaming';
  static const String _messageBubbleRadiusKey = 'ui.messageBubbleRadius';
  static const String _uiCornerRadiusKey = 'ui.cornerRadius';
  static const String _autoPauseVideoKey = 'ui.autoPauseVideo';
  static const String _energySavingThresholdKey = 'ui.energySavingThreshold';
  static const String _animateStickersKey = 'ui.animateStickers';
  static const String _animateEmojiKey = 'ui.animateEmoji';
  static const String _saveToGalleryPrivateKey = 'ui.saveGalleryPrivate';
  static const String _saveToGalleryGroupsKey = 'ui.saveGalleryGroups';
  static const String _saveToGalleryChannelsKey = 'ui.saveGalleryChannels';
  static const String _linkPreviewsSecretKey = 'ui.linkPreviewsSecret';
  static const String _secureScreenshotsSecretKey = 'ui.secureScreenshotsSecret';

  /// Keys of settings that no longer exist. Nothing reads them; a reset
  /// still clears what an older build may have stored.
  static const List<String> _retiredKeys = <String>[
    'ui.camera2Api',
    'ui.hideBubbleTails',
    'ui.replaceEditedWithIcon',
    'ui.videoSeekSeconds',
    'ui.chatEffects',
    'ui.streamMedia',
    'ui.accountSelfDestructMonths',
    'ui.autoTerminateSessionsDays',
  ];

  static SharedPreferences? cachedPrefs;
  bool _loaded = false;
  Timer? _debounceTimer;
  final Map<String, Future<void> Function()> _pendingWrites =
      <String, Future<void> Function()>{};

  /// Last value of each key known to be on disk, as the state holds it.
  final Map<String, Object?> _confirmed = <String, Object?>{};

  /// Bumped by [resetAll]: a write that started before it reports nothing.
  int _epoch = 0;

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
      sendOnEnter: prefs.getBool(_sendOnEnterKey) ?? defaults.sendOnEnter,
      doubleTapReactionEmoji:
          prefs.getString(_doubleTapReactionEmojiKey) ?? defaults.doubleTapReactionEmoji,
      autoDownloadWifi:
          prefs.getBool(_autoDownloadWifiKey) ?? defaults.autoDownloadWifi,
      autoDownloadCellular:
          prefs.getBool(_autoDownloadCellularKey) ?? defaults.autoDownloadCellular,
      autoDownloadRoaming:
          prefs.getBool(_autoDownloadRoamingKey) ?? defaults.autoDownloadRoaming,
      messageBubbleRadius:
          prefs.getDouble(_messageBubbleRadiusKey) ?? defaults.messageBubbleRadius,
      uiCornerRadius:
          prefs.getDouble(_uiCornerRadiusKey) ?? defaults.uiCornerRadius,
      autoPauseVideoOnBackground:
          prefs.getBool(_autoPauseVideoKey) ?? defaults.autoPauseVideoOnBackground,
      energySavingThreshold:
          prefs.getInt(_energySavingThresholdKey) ?? defaults.energySavingThreshold,
      animateStickers:
          prefs.getBool(_animateStickersKey) ?? defaults.animateStickers,
      animateEmoji:
          prefs.getBool(_animateEmojiKey) ?? defaults.animateEmoji,
      saveToGalleryPrivate:
          prefs.getBool(_saveToGalleryPrivateKey) ?? defaults.saveToGalleryPrivate,
      saveToGalleryGroups:
          prefs.getBool(_saveToGalleryGroupsKey) ?? defaults.saveToGalleryGroups,
      saveToGalleryChannels:
          prefs.getBool(_saveToGalleryChannelsKey) ?? defaults.saveToGalleryChannels,
      linkPreviewsInSecretChats:
          prefs.getBool(_linkPreviewsSecretKey) ?? defaults.linkPreviewsInSecretChats,
      secureScreenshotsInSecretChats:
          prefs.getBool(_secureScreenshotsSecretKey) ?? defaults.secureScreenshotsInSecretChats,
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

  /// Whether [value] reached the disk under [key]. The plugin reports a
  /// refused write either by throwing or by answering false.
  Future<bool> _persistKey(String key, Object? value) async {
    try {
      final SharedPreferences prefs = await _getPrefs();
      return switch (value) {
        null => await prefs.remove(key),
        final bool v => await prefs.setBool(key, v),
        final double v => await prefs.setDouble(key, v),
        final int v => await prefs.setInt(key, v),
        final String v => await prefs.setString(key, v),
        _ => false,
      };
    } catch (e) {
      debugPrint('[UiSettingsNotifier] Failed to persist key $key: $e');
      return false;
    }
  }

  static Object? _encode(Object? value) => switch (value) {
    final Enum e => e.name,
    final Color c => c.toARGB32(),
    _ => value,
  };

  /// Shows [value] at once and stores it under [key]. If the disk refuses,
  /// the field returns to the last value known to be stored and the failure
  /// is reported together with a way to ask again.
  void _set<T>(
    String key,
    T value,
    T Function(UiSettingsState s) read,
    UiSettingsState Function(UiSettingsState s, T v) copy, {
    bool debounced = false,
  }) {
    _confirmed.putIfAbsent(key, () => read(state));
    state = copy(state, value);
    _store<T>(key, value, read, copy, debounced: debounced);
  }

  /// Writes a [value] the state already shows. Apart from [_set] so that one
  /// state change can cover several keys.
  void _store<T>(
    String key,
    T value,
    T Function(UiSettingsState s) read,
    UiSettingsState Function(UiSettingsState s, T v) copy, {
    bool debounced = false,
  }) {
    final int epoch = _epoch;
    Future<void> write() async {
      final bool stored = await _persistKey(key, _encode(value));
      // A reset in between owns both the state and the disk now.
      if (epoch != _epoch || !ref.mounted) return;
      if (stored) {
        _confirmed[key] = value;
        return;
      }
      // An older failure does not undo a newer request for the same key.
      if (read(state) == value) state = copy(state, _confirmed[key] as T);
      ref
          .read(settingsSaveFailureProvider.notifier)
          .report(SettingsSaveFailure(() => _set<T>(key, value, read, copy)));
    }

    if (!debounced) {
      write();
      return;
    }
    // Sliders: the last request per key wins once the thumb rests.
    _pendingWrites[key] = write;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _flushPendingWrites();
    });
  }

  Future<void> _flushPendingWrites() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (_pendingWrites.isEmpty) return;
    final List<Future<void> Function()> writes = _pendingWrites.values.toList();
    _pendingWrites.clear();
    for (final Future<void> Function() write in writes) {
      await write();
    }
  }

  Future<void> flushPersist() => _flushPendingWrites();

  void setMessageBubbleRadius(double value) => _set<double>(
    _messageBubbleRadiusKey,
    value,
    (s) => s.messageBubbleRadius,
    (s, v) => s.copyWith(messageBubbleRadius: v),
    debounced: true,
  );

  void setUiCornerRadius(double value) => _set<double>(
    _uiCornerRadiusKey,
    value,
    (s) => s.uiCornerRadius,
    (s, v) => s.copyWith(uiCornerRadius: v),
    debounced: true,
  );

  void setThemeMode(ThemeMode value) => _set<ThemeMode>(
    _themeModeKey,
    value,
    (s) => s.themeMode,
    (s, v) => s.copyWith(themeMode: v),
  );

  void setSeedColor(Color value) {
    // One state change for both fields: the theme rebuilds once, not once
    // with the old accent and system colours off and then again.
    final bool wasDynamic = state.useSystemDynamic;
    _confirmed.putIfAbsent(_seedColorKey, () => state.seedColor);
    if (wasDynamic) _confirmed.putIfAbsent(_useSystemDynamicKey, () => true);
    state = state.copyWith(seedColor: value, useSystemDynamic: false);
    _store<Color>(
      _seedColorKey,
      value,
      (s) => s.seedColor,
      (s, v) => s.copyWith(seedColor: v),
    );
    if (wasDynamic) {
      _store<bool>(
        _useSystemDynamicKey,
        false,
        (s) => s.useSystemDynamic,
        (s, v) => s.copyWith(useSystemDynamic: v),
      );
    }
  }

  void setNotifications(bool value) => _set<bool>(
    _notificationsKey,
    value,
    (s) => s.notifications,
    (s, v) => s.copyWith(notifications: v),
  );

  void setCompactMode(bool value) => _set<bool>(
    _compactKey,
    value,
    (s) => s.compactMode,
    (s, v) => s.copyWith(compactMode: v),
  );

  void setHaptics(bool value) => _set<bool>(
    _hapticsKey,
    value,
    (s) => s.haptics,
    (s, v) => s.copyWith(haptics: v),
  );

  void setHideOnline(bool value) => _set<bool>(
    _hideOnlineKey,
    value,
    (s) => s.hideOnline,
    (s, v) => s.copyWith(hideOnline: v),
  );

  void setSoundEffects(bool value) => _set<bool>(
    _soundEffectsKey,
    value,
    (s) => s.soundEffects,
    (s, v) => s.copyWith(soundEffects: v),
  );

  void setSoundVolume(double value) => _set<double>(
    _soundVolumeKey,
    value.clamp(0.0, 1.0),
    (s) => s.soundVolume,
    (s, v) => s.copyWith(soundVolume: v),
    debounced: true,
  );

  void setLocaleCode(String? value) => _set<String?>(
    _localeCodeKey,
    (value ?? '').trim().isEmpty ? null : value!.trim().toLowerCase(),
    (s) => s.localeCode,
    (s, v) => v == null
        ? s.copyWith(clearLocaleCode: true)
        : s.copyWith(localeCode: v),
  );

  void setTimeZoneMode(AppTimeZoneMode value) => _set<AppTimeZoneMode>(
    _timeZoneModeKey,
    value,
    (s) => s.timeZoneMode,
    (s, v) => s.copyWith(timeZoneMode: v),
  );

  void _setTimeZoneId(String? value) => _set<String?>(
    _timeZoneIdKey,
    value,
    (s) => s.timeZoneId,
    (s, v) => v == null
        ? s.copyWith(clearTimeZoneId: true)
        : s.copyWith(timeZoneId: v),
  );

  void setTimeZoneId(String? value) =>
      _setTimeZoneId((value ?? '').trim().isEmpty ? null : value!.trim());

  void useAutomaticTimeZone() => setTimeZoneMode(AppTimeZoneMode.auto);

  void useManualTimeZone(String timeZoneId) {
    setTimeZoneMode(AppTimeZoneMode.manual);
    _setTimeZoneId(timeZoneId.trim());
  }

  void setOptimizeForWeakDevices(bool value) => _set<bool>(
    _optimizeWeakKey,
    value,
    (s) => s.optimizeForWeakDevices,
    (s, v) => s.copyWith(optimizeForWeakDevices: v),
  );

  // Account lifecycle owns the foreground service and socket together.
  void setBackgroundMode(BackgroundMode value) => _set<BackgroundMode>(
    _backgroundModeKey,
    value,
    (s) => s.backgroundMode,
    (s, v) => s.copyWith(backgroundMode: v),
  );

  void setUseSystemDynamic(bool value) {
    if (state.useSystemDynamic == value) return;
    _set<bool>(
      _useSystemDynamicKey,
      value,
      (s) => s.useSystemDynamic,
      (s, v) => s.copyWith(useSystemDynamic: v),
    );
  }

  void setFontScale(AppFontScale value) => _set<AppFontScale>(
    _fontScaleKey,
    value,
    (s) => s.fontScale,
    (s, v) => s.copyWith(fontScale: v),
  );

  void setSendOnEnter(bool value) => _set<bool>(
    _sendOnEnterKey,
    value,
    (s) => s.sendOnEnter,
    (s, v) => s.copyWith(sendOnEnter: v),
  );

  void setDoubleTapReactionEmoji(String value) => _set<String>(
    _doubleTapReactionEmojiKey,
    value,
    (s) => s.doubleTapReactionEmoji,
    (s, v) => s.copyWith(doubleTapReactionEmoji: v),
  );

  void setAutoDownloadWifi(bool value) => _set<bool>(
    _autoDownloadWifiKey,
    value,
    (s) => s.autoDownloadWifi,
    (s, v) => s.copyWith(autoDownloadWifi: v),
  );

  void setAutoDownloadCellular(bool value) => _set<bool>(
    _autoDownloadCellularKey,
    value,
    (s) => s.autoDownloadCellular,
    (s, v) => s.copyWith(autoDownloadCellular: v),
  );

  void setAutoDownloadRoaming(bool value) => _set<bool>(
    _autoDownloadRoamingKey,
    value,
    (s) => s.autoDownloadRoaming,
    (s, v) => s.copyWith(autoDownloadRoaming: v),
  );

  void setPaletteStyle(PaletteStyle value) => _set<PaletteStyle>(
    _paletteStyleKey,
    value,
    (s) => s.paletteStyle,
    (s, v) => s.copyWith(paletteStyle: v),
  );

  void setAutoPauseVideoOnBackground(bool value) => _set<bool>(
    _autoPauseVideoKey,
    value,
    (s) => s.autoPauseVideoOnBackground,
    (s, v) => s.copyWith(autoPauseVideoOnBackground: v),
  );

  void setEnergySavingThreshold(int value) => _set<int>(
    _energySavingThresholdKey,
    value,
    (s) => s.energySavingThreshold,
    (s, v) => s.copyWith(energySavingThreshold: v),
  );

  void setAnimateStickers(bool value) => _set<bool>(
    _animateStickersKey,
    value,
    (s) => s.animateStickers,
    (s, v) => s.copyWith(animateStickers: v),
  );

  void setAnimateEmoji(bool value) => _set<bool>(
    _animateEmojiKey,
    value,
    (s) => s.animateEmoji,
    (s, v) => s.copyWith(animateEmoji: v),
  );

  void setSaveToGalleryPrivate(bool value) => _set<bool>(
    _saveToGalleryPrivateKey,
    value,
    (s) => s.saveToGalleryPrivate,
    (s, v) => s.copyWith(saveToGalleryPrivate: v),
  );

  void setSaveToGalleryGroups(bool value) => _set<bool>(
    _saveToGalleryGroupsKey,
    value,
    (s) => s.saveToGalleryGroups,
    (s, v) => s.copyWith(saveToGalleryGroups: v),
  );

  void setSaveToGalleryChannels(bool value) => _set<bool>(
    _saveToGalleryChannelsKey,
    value,
    (s) => s.saveToGalleryChannels,
    (s, v) => s.copyWith(saveToGalleryChannels: v),
  );

  void setLinkPreviewsInSecretChats(bool value) => _set<bool>(
    _linkPreviewsSecretKey,
    value,
    (s) => s.linkPreviewsInSecretChats,
    (s, v) => s.copyWith(linkPreviewsInSecretChats: v),
  );

  void setSecureScreenshotsInSecretChats(bool value) => _set<bool>(
    _secureScreenshotsSecretKey,
    value,
    (s) => s.secureScreenshotsInSecretChats,
    (s, v) => s.copyWith(secureScreenshotsInSecretChats: v),
  );

  /// Resets all settings fields safely to [UiSettingsState.defaults()],
  /// keeping background message delivery in [BackgroundMode.reliable]
  /// and cleaning up persisted SharedPreferences keys in a single atomic batch.
  Future<void> resetAll() async {
    _debounceTimer?.cancel();
    _pendingWrites.clear();
    _confirmed.clear();
    _epoch++;
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
      prefs.remove(_backgroundModeKey),
      prefs.remove(_useSystemDynamicKey),
      prefs.remove(_fontScaleKey),
      prefs.remove(_sendOnEnterKey),
      prefs.remove(_doubleTapReactionEmojiKey),
      prefs.remove(_autoDownloadWifiKey),
      prefs.remove(_autoDownloadCellularKey),
      prefs.remove(_autoDownloadRoamingKey),
      prefs.remove(_messageBubbleRadiusKey),
      prefs.remove(_uiCornerRadiusKey),
      prefs.remove(_autoPauseVideoKey),
      prefs.remove(_energySavingThresholdKey),
      prefs.remove(_animateStickersKey),
      prefs.remove(_animateEmojiKey),
      prefs.remove(_saveToGalleryPrivateKey),
      prefs.remove(_saveToGalleryGroupsKey),
      prefs.remove(_saveToGalleryChannelsKey),
      prefs.remove(_linkPreviewsSecretKey),
      prefs.remove(_secureScreenshotsSecretKey),
      for (final String key in _retiredKeys) prefs.remove(key),
    ]);
  }
}

final NotifierProvider<UiSettingsNotifier, UiSettingsState> uiSettingsProvider =
    NotifierProvider<UiSettingsNotifier, UiSettingsState>(
      UiSettingsNotifier.new,
    );

/// A setting the disk refused to store. The state already shows the stored
/// value again; [retry] asks for the refused one once more.
class SettingsSaveFailure {
  const SettingsSaveFailure(this.retry);

  final VoidCallback retry;
}

class SettingsSaveFailureNotifier extends Notifier<SettingsSaveFailure?> {
  @override
  SettingsSaveFailure? build() => null;

  void report(SettingsSaveFailure failure) => state = failure;
}

final NotifierProvider<SettingsSaveFailureNotifier, SettingsSaveFailure?>
settingsSaveFailureProvider =
    NotifierProvider<SettingsSaveFailureNotifier, SettingsSaveFailure?>(
      SettingsSaveFailureNotifier.new,
    );
