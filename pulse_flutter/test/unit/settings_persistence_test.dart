import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/settings/auto_download.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Case {
  const _Case(this.key, this.stored, this.apply, this.read, this.expected);

  final String key;
  final Object stored;
  final void Function(UiSettingsNotifier) apply;
  final Object? Function(UiSettingsState) read;
  final Object expected;
}

/// Settings that have a working control today. Every value differs from the
/// default so a setter that does nothing cannot pass.
final List<_Case> _cases = <_Case>[
  _Case(
    'ui.themeMode',
    'dark',
    (n) => n.setThemeMode(ThemeMode.dark),
    (s) => s.themeMode,
    ThemeMode.dark,
  ),
  _Case(
    'ui.seedColor',
    0xFF2563EB,
    (n) => n.setSeedColor(const Color(0xFF2563EB)),
    (s) => s.seedColor,
    const Color(0xFF2563EB),
  ),
  _Case(
    'ui.paletteStyle',
    'mono',
    (n) => n.setPaletteStyle(PaletteStyle.mono),
    (s) => s.paletteStyle,
    PaletteStyle.mono,
  ),
  _Case(
    'ui.useSystemDynamic',
    true,
    (n) => n.setUseSystemDynamic(true),
    (s) => s.useSystemDynamic,
    true,
  ),
  _Case(
    'ui.fontScale',
    'extraLarge',
    (n) => n.setFontScale(AppFontScale.extraLarge),
    (s) => s.fontScale,
    AppFontScale.extraLarge,
  ),
  _Case(
    'ui.compact',
    true,
    (n) => n.setCompactMode(true),
    (s) => s.compactMode,
    true,
  ),
  _Case(
    'ui.cornerRadius',
    12.0,
    (n) => n.setUiCornerRadius(12),
    (s) => s.uiCornerRadius,
    12.0,
  ),
  _Case(
    'ui.messageBubbleRadius',
    24.0,
    (n) => n.setMessageBubbleRadius(24),
    (s) => s.messageBubbleRadius,
    24.0,
  ),
  _Case(
    'ui.notifications',
    false,
    (n) => n.setNotifications(false),
    (s) => s.notifications,
    false,
  ),
  _Case(
    'ui.haptics',
    false,
    (n) => n.setHaptics(false),
    (s) => s.haptics,
    false,
  ),
  _Case(
    'ui.soundEffects',
    true,
    (n) => n.setSoundEffects(true),
    (s) => s.soundEffects,
    true,
  ),
  _Case(
    'ui.soundVolume',
    0.4,
    (n) => n.setSoundVolume(0.4),
    (s) => s.soundVolume,
    0.4,
  ),
  _Case(
    'ui.sendOnEnter',
    false,
    (n) => n.setSendOnEnter(false),
    (s) => s.sendOnEnter,
    false,
  ),
  _Case(
    'ui.doubleTapReactionEmoji',
    '🔥',
    (n) => n.setDoubleTapReactionEmoji('🔥'),
    (s) => s.doubleTapReactionEmoji,
    '🔥',
  ),
  _Case(
    'ui.autoDownload.photo.wifi',
    false,
    (n) => n.setAutoDownload(
      AutoDownloadMediaType.photo,
      AutoDownloadNetwork.wifi,
      false,
    ),
    (s) => s.autoDownloadPhotoWifi,
    false,
  ),
  _Case(
    'ui.autoDownload.photo.cellular',
    true,
    (n) => n.setAutoDownload(
      AutoDownloadMediaType.photo,
      AutoDownloadNetwork.cellular,
      true,
    ),
    (s) => s.autoDownloadPhotoCellular,
    true,
  ),
  _Case(
    'ui.autoDownload.video.wifi',
    false,
    (n) => n.setAutoDownload(
      AutoDownloadMediaType.video,
      AutoDownloadNetwork.wifi,
      false,
    ),
    (s) => s.autoDownloadVideoWifi,
    false,
  ),
  _Case(
    'ui.autoDownload.video.cellular',
    true,
    (n) => n.setAutoDownload(
      AutoDownloadMediaType.video,
      AutoDownloadNetwork.cellular,
      true,
    ),
    (s) => s.autoDownloadVideoCellular,
    true,
  ),
  _Case(
    'ui.optimizeWeak',
    true,
    (n) => n.setOptimizeForWeakDevices(true),
    (s) => s.optimizeForWeakDevices,
    true,
  ),
  _Case(
    'ui.backgroundMode',
    'economy',
    (n) => n.setBackgroundMode(BackgroundMode.economy),
    (s) => s.backgroundMode,
    BackgroundMode.economy,
  ),
  _Case(
    'ui.animateStickers',
    false,
    (n) => n.setAnimateStickers(false),
    (s) => s.animateStickers,
    false,
  ),
  _Case(
    'ui.animateEmoji',
    false,
    (n) => n.setAnimateEmoji(false),
    (s) => s.animateEmoji,
    false,
  ),
  _Case(
    'ui.hideOnline',
    true,
    (n) => n.setHideOnline(true),
    (s) => s.hideOnline,
    true,
  ),
  _Case(
    'ui.localeCode',
    'en',
    (n) => n.setLocaleCode('en'),
    (s) => s.localeCode,
    'en',
  ),
  _Case(
    'ui.timeZoneMode',
    'manual',
    (n) => n.setTimeZoneMode(AppTimeZoneMode.manual),
    (s) => s.timeZoneMode,
    AppTimeZoneMode.manual,
  ),
  _Case(
    'ui.timeZoneId',
    'Europe/Moscow',
    (n) => n.setTimeZoneId('Europe/Moscow'),
    (s) => s.timeZoneId,
    'Europe/Moscow',
  ),
];

/// Preferences whose writes can be refused, the way a full or read-only disk
/// refuses them.
class _RefusingPrefs extends Fake implements SharedPreferences {
  _RefusingPrefs(this.accept);

  bool Function(String key, Object? value) accept;
  final Map<String, Object> stored = <String, Object>{};

  Future<bool> _write(String key, Object value) async {
    if (!accept(key, value)) return false;
    stored[key] = value;
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) => _write(key, value);
  @override
  Future<bool> setDouble(String key, double value) => _write(key, value);
  @override
  Future<bool> setInt(String key, int value) => _write(key, value);
  @override
  Future<bool> setString(String key, String value) => _write(key, value);
  @override
  Future<bool> remove(String key) async {
    if (!accept(key, null)) return false;
    stored.remove(key);
    return true;
  }

  @override
  bool? getBool(String key) => stored[key] as bool?;
  @override
  double? getDouble(String key) => stored[key] as double?;
  @override
  int? getInt(String key) => stored[key] as int?;
  @override
  String? getString(String key) => stored[key] as String?;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, SharedPreferences)> boot([
    Map<String, Object> initial = const <String, Object>{},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    UiSettingsNotifier.cachedPrefs = prefs;
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    return (container, prefs);
  }

  // Plain setters do not await their write; sliders debounce it.
  Future<void> settle(UiSettingsNotifier notifier) async {
    await notifier.flushPersist();
    await pumpEventQueue();
  }

  tearDown(() => UiSettingsNotifier.cachedPrefs = null);

  group('Settings persistence', () {
    test('every case uses a non-default value and a unique key', () {
      const UiSettingsState defaults = UiSettingsState.defaults();
      for (final _Case c in _cases) {
        expect(c.read(defaults), isNot(c.expected), reason: c.key);
      }
      expect(_cases.map((_Case c) => c.key).toSet().length, _cases.length);
    });

    for (final _Case c in _cases) {
      test('${c.key}: setter changes state and reaches prefs', () async {
        final (ProviderContainer container, SharedPreferences prefs) =
            await boot();
        final UiSettingsNotifier notifier = container.read(
          uiSettingsProvider.notifier,
        );

        c.apply(notifier);
        expect(c.read(container.read(uiSettingsProvider)), c.expected);

        await settle(notifier);
        expect(prefs.get(c.key), c.stored);
      });

      test('${c.key}: stored value is restored on start', () async {
        final (ProviderContainer container, _) = await boot(<String, Object>{
          c.key: c.stored,
        });
        expect(c.read(container.read(uiSettingsProvider)), c.expected);
      });
    }

    test('resetAll returns every setting to default and clears prefs', () async {
      final (ProviderContainer container, SharedPreferences prefs) =
          await boot();
      final UiSettingsNotifier notifier = container.read(
        uiSettingsProvider.notifier,
      );
      for (final _Case c in _cases) {
        c.apply(notifier);
      }
      await settle(notifier);
      expect(
        prefs.getKeys().where((String k) => k.startsWith('ui.')),
        isNotEmpty,
      );

      await notifier.resetAll();
      await pumpEventQueue();

      const UiSettingsState defaults = UiSettingsState.defaults();
      final UiSettingsState state = container.read(uiSettingsProvider);
      for (final _Case c in _cases) {
        expect(c.read(state), c.read(defaults), reason: c.key);
      }
      expect(
        prefs.getKeys().where((String k) => k.startsWith('ui.')),
        isEmpty,
      );
    });

    test('resetAll clears keys left by settings that no longer exist', () async {
      final (ProviderContainer container, SharedPreferences prefs) =
          await boot(<String, Object>{
            'ui.camera2Api': false,
            'ui.streamMedia': false,
            'ui.videoSeekSeconds': 30,
            'ui.autoTerminateSessionsDays': 7,
          });

      await container.read(uiSettingsProvider.notifier).resetAll();
      await pumpEventQueue();

      expect(
        prefs.getKeys().where((String k) => k.startsWith('ui.')),
        isEmpty,
      );
    });

    test('resetAll drops a slider write that is still debounced', () async {
      final (ProviderContainer container, SharedPreferences prefs) =
          await boot();
      final UiSettingsNotifier notifier = container.read(
        uiSettingsProvider.notifier,
      );

      notifier.setUiCornerRadius(12);
      await notifier.resetAll();
      await notifier.flushPersist();
      await pumpEventQueue();

      expect(prefs.containsKey('ui.cornerRadius'), isFalse);
      expect(container.read(uiSettingsProvider).uiCornerRadius, 20.0);
    });

    test('a refused write returns the stored value and offers a retry', () async {
      final _RefusingPrefs prefs = _RefusingPrefs(
        (String key, Object? value) => false,
      );
      UiSettingsNotifier.cachedPrefs = prefs;
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      final UiSettingsNotifier notifier = container.read(
        uiSettingsProvider.notifier,
      );
      final bool before = container.read(uiSettingsProvider).sendOnEnter;

      notifier.setSendOnEnter(!before);
      expect(container.read(uiSettingsProvider).sendOnEnter, !before);
      expect(container.read(settingsSaveFailureProvider), isNull);
      await settle(notifier);

      expect(container.read(uiSettingsProvider).sendOnEnter, before);
      final SettingsSaveFailure? failure = container.read(
        settingsSaveFailureProvider,
      );
      expect(failure, isNotNull);

      prefs.accept = (String key, Object? value) => true;
      failure!.retry();
      await settle(notifier);

      expect(container.read(uiSettingsProvider).sendOnEnter, !before);
      expect(prefs.stored['ui.sendOnEnter'], !before);
    });

    test('an older refused write does not undo a newer value', () async {
      final _RefusingPrefs prefs = _RefusingPrefs(
        (String key, Object? value) => value != 37,
      );
      UiSettingsNotifier.cachedPrefs = prefs;
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      final UiSettingsNotifier notifier = container.read(
        uiSettingsProvider.notifier,
      );

      // The dead energy saver took its plain int setter with it; the accent
      // seed writes the same kind of value through the same _store path.
      notifier.setSeedColor(const Color(0x00000025));
      notifier.setSeedColor(const Color(0x00000029));
      await settle(notifier);

      expect(
        container.read(uiSettingsProvider).seedColor,
        const Color(0x00000029),
      );
      expect(prefs.stored['ui.seedColor'], 41);
      expect(container.read(settingsSaveFailureProvider), isNotNull);
    });

    test('picking an accent leaves system colours in one state change', () async {
      final (ProviderContainer container, SharedPreferences prefs) =
          await boot(<String, Object>{'ui.useSystemDynamic': true});
      final UiSettingsNotifier notifier = container.read(
        uiSettingsProvider.notifier,
      );
      final List<UiSettingsState> updates = <UiSettingsState>[];
      final ProviderSubscription<UiSettingsState> subscription = container
          .listen(uiSettingsProvider, (_, UiSettingsState s) => updates.add(s));
      addTearDown(subscription.close);

      notifier.setSeedColor(const Color(0xFF006C5B));
      expect(updates, hasLength(1));
      expect(updates.single.useSystemDynamic, isFalse);

      await settle(notifier);
      expect(prefs.getInt('ui.seedColor'), 0xFF006C5B);
      expect(prefs.getBool('ui.useSystemDynamic'), isFalse);
    });

    test('a refused slider write returns the stored radius', () async {
      final _RefusingPrefs prefs = _RefusingPrefs(
        (String key, Object? value) => false,
      );
      UiSettingsNotifier.cachedPrefs = prefs;
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      final UiSettingsNotifier notifier = container.read(
        uiSettingsProvider.notifier,
      );
      final double before = container.read(uiSettingsProvider).uiCornerRadius;

      notifier.setUiCornerRadius(12);
      expect(container.read(uiSettingsProvider).uiCornerRadius, 12);
      await settle(notifier);

      expect(container.read(uiSettingsProvider).uiCornerRadius, before);
      expect(container.read(settingsSaveFailureProvider), isNotNull);
    });
  });

  group('Auto download migration', () {
    test('legacy keys seed both photos and videos', () async {
      final (ProviderContainer container, _) = await boot(<String, Object>{
        'ui.autoDownloadWifi': false,
        'ui.autoDownloadCellular': true,
      });
      final UiSettingsState state = container.read(uiSettingsProvider);

      expect(state.autoDownloadPhotoWifi, isFalse);
      expect(state.autoDownloadPhotoCellular, isTrue);
      expect(state.autoDownloadVideoWifi, isFalse);
      expect(state.autoDownloadVideoCellular, isTrue);
    });

    test('a per-type key wins over the legacy one', () async {
      final (ProviderContainer container, _) = await boot(<String, Object>{
        'ui.autoDownloadWifi': false,
        'ui.autoDownloadCellular': true,
        'ui.autoDownload.photo.wifi': true,
        'ui.autoDownload.video.cellular': false,
      });
      final UiSettingsState state = container.read(uiSettingsProvider);

      expect(state.autoDownloadPhotoWifi, isTrue);
      expect(state.autoDownloadPhotoCellular, isTrue);
      expect(state.autoDownloadVideoWifi, isFalse);
      expect(state.autoDownloadVideoCellular, isFalse);
    });

    test('resetAll clears the per-type and the legacy keys', () async {
      final (ProviderContainer container, SharedPreferences prefs) =
          await boot(<String, Object>{
            'ui.autoDownloadWifi': false,
            'ui.autoDownloadCellular': true,
          });

      await container.read(uiSettingsProvider.notifier).resetAll();
      await pumpEventQueue();

      expect(
        prefs.getKeys().where((String k) => k.startsWith('ui.autoDownload')),
        isEmpty,
      );
    });
  });

  group('Auto download by media type', () {
    Future<ProviderContainer> bootNetwork(NetworkType type) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      UiSettingsNotifier.cachedPrefs = await SharedPreferences.getInstance();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          networkTypeProvider.overrideWith(
            (ref) => Stream<NetworkType>.value(type),
          ),
        ],
      );
      addTearDown(container.dispose);
      final ProviderSubscription<UiSettingsState> keepAlive = container.listen(
        uiSettingsProvider,
        (_, _) {},
      );
      addTearDown(keepAlive.close);
      // A stream provider only subscribes while someone listens to it.
      final ProviderSubscription<AsyncValue<NetworkType>> network =
          container.listen(networkTypeProvider, (_, _) {});
      addTearDown(network.close);
      await pumpEventQueue();
      expect(container.read(networkTypeProvider).value, type);
      return container;
    }

    bool allowed(ProviderContainer c, AutoDownloadMediaType type) =>
        c.read(autoDownloadAllowedProvider(type));

    void setRule(
      ProviderContainer container,
      AutoDownloadMediaType type,
      AutoDownloadNetwork network,
      bool value,
    ) => container
        .read(uiSettingsProvider.notifier)
        .setAutoDownload(type, network, value);

    test('a wifi network follows the wifi flag of each type', () async {
      final ProviderContainer container = await bootNetwork(NetworkType.wifi);
      expect(allowed(container, AutoDownloadMediaType.photo), isTrue);
      expect(allowed(container, AutoDownloadMediaType.video), isTrue);

      setRule(
        container,
        AutoDownloadMediaType.video,
        AutoDownloadNetwork.wifi,
        false,
      );
      expect(allowed(container, AutoDownloadMediaType.photo), isTrue);
      expect(allowed(container, AutoDownloadMediaType.video), isFalse);
    });

    test('a wired or unknown network follows the wifi flag', () async {
      final ProviderContainer container = await bootNetwork(NetworkType.other);
      expect(allowed(container, AutoDownloadMediaType.photo), isTrue);
      expect(allowed(container, AutoDownloadMediaType.video), isTrue);

      setRule(
        container,
        AutoDownloadMediaType.photo,
        AutoDownloadNetwork.wifi,
        false,
      );
      setRule(
        container,
        AutoDownloadMediaType.photo,
        AutoDownloadNetwork.cellular,
        true,
      );
      // Cellular permission must not leak onto a wired or unknown network.
      expect(allowed(container, AutoDownloadMediaType.photo), isFalse);
      expect(allowed(container, AutoDownloadMediaType.video), isTrue);
    });

    test('a cellular network follows the cellular flag of each type', () async {
      final ProviderContainer container = await bootNetwork(
        NetworkType.cellular,
      );
      expect(allowed(container, AutoDownloadMediaType.photo), isFalse);
      expect(allowed(container, AutoDownloadMediaType.video), isFalse);

      setRule(
        container,
        AutoDownloadMediaType.photo,
        AutoDownloadNetwork.cellular,
        true,
      );
      expect(allowed(container, AutoDownloadMediaType.photo), isTrue);
      expect(allowed(container, AutoDownloadMediaType.video), isFalse);
    });

    test('no network allows nothing, whatever the flags say', () async {
      final ProviderContainer container = await bootNetwork(NetworkType.none);
      for (final AutoDownloadMediaType type in AutoDownloadMediaType.values) {
        for (final AutoDownloadNetwork network
            in AutoDownloadNetwork.values) {
          setRule(container, type, network, true);
        }
      }
      expect(allowed(container, AutoDownloadMediaType.photo), isFalse);
      expect(allowed(container, AutoDownloadMediaType.video), isFalse);
    });
  });
}
