import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    'ui.autoDownloadWifi',
    false,
    (n) => n.setAutoDownloadWifi(false),
    (s) => s.autoDownloadWifi,
    false,
  ),
  _Case(
    'ui.autoDownloadCellular',
    true,
    (n) => n.setAutoDownloadCellular(true),
    (s) => s.autoDownloadCellular,
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
  });
}
