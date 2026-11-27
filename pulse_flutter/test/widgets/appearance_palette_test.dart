import 'dart:ui' as ui;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/screens/settings_appearance_accent_screen.dart';
import 'package:pulse_flutter/screens/settings_appearance_screen.dart';
import 'package:pulse_flutter/widgets/circular_theme_reveal.dart';
import 'package:pulse_flutter/widgets/settings/custom_color_picker_sheet.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:universal_io/io.dart';

void main() {
  testWidgets(
    'appearance uses intermediate theme colors and one atomic accent update',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'ui.optimizeWeak': true,
        'ui.useSystemDynamic': true,
      });
      final previousPrefs = UiSettingsNotifier.cachedPrefs;
      UiSettingsNotifier.cachedPrefs = await SharedPreferences.getInstance();
      addTearDown(() => UiSettingsNotifier.cachedPrefs = previousPrefs);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsAppearanceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(SettingsAppearanceScreen)),
      );
      // The system-colours toggle moved to the accent sub-screen, which only
      // offers it where the platform really has a palette; what the quick
      // page always shows is the grid itself.
      expect(
        find.byKey(const ValueKey('appearance-palette-strip')),
        findsOneWidget,
      );
      final updates = <UiSettingsState>[];
      final subscription = scope.listen(
        uiSettingsProvider,
        (_, state) => updates.add(state),
      );
      addTearDown(subscription.close);
      // The old field carried the ambient theme in its constructor; the grid
      // under the AnimatedTheme reads it the same way through the tree.
      Color accentPrimary() => Theme.of(
        tester.element(find.byKey(const ValueKey('appearance-palette-strip'))),
      ).colorScheme.primary;
      final before = accentPrimary();
      scope
          .read(uiSettingsProvider.notifier)
          .setSeedColor(const Color(0xff006c5b));
      expect(updates.length, 1);
      expect(updates.single.useSystemDynamic, isFalse);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final middle = accentPrimary();
      await tester.pumpAndSettle();
      final after = accentPrimary();
      expect(middle, isNot(before));
      expect(middle, isNot(after));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a new accent opens in a reveal together with its mark', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'ui.useSystemDynamic': true});
    final previousPrefs = UiSettingsNotifier.cachedPrefs;
    UiSettingsNotifier.cachedPrefs = await SharedPreferences.getInstance();
    addTearDown(() => UiSettingsNotifier.cachedPrefs = previousPrefs);
    addTearDown(() => CircularThemeSwitcher.revealing.value = false);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CircularThemeSwitcher(child: SettingsAppearanceScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scope = ProviderScope.containerOf(
      tester.element(find.byType(SettingsAppearanceScreen)),
    );
    final lagoon = find.byTooltip('Lagoon');
    await tester.ensureVisible(lagoon);
    await tester.pumpAndSettle();
    expect(CircularThemeSwitcher.revealing.value, isFalse);

    await tester.tap(lagoon);
    await tester.pump();
    // The setting and the reveal start in the same frame: the mark on the
    // swatch does not run ahead of the colours.
    expect(scope.read(uiSettingsProvider).seedColor, const Color(0xff006c5b));
    expect(scope.read(uiSettingsProvider).useSystemDynamic, isFalse);
    expect(CircularThemeSwitcher.revealing.value, isTrue);

    await tester.pumpAndSettle();
    expect(CircularThemeSwitcher.revealing.value, isFalse);

    // The accent already in use has nothing to reveal.
    await tester.tap(lagoon);
    await tester.pump();
    expect(CircularThemeSwitcher.revealing.value, isFalse);
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'custom color draft validates HEX and applies once $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Color? applied;
        double fontScale = 1.8;
        final capture = GlobalKey();
        Widget app() => MaterialApp(
          theme: AppTheme.themed(
            const VisualThemeSettings(
              seedColor: Color(0xff6750a4),
              themeMode: ThemeMode.system,
              useSystemDynamic: false,
            ),
            brightness,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(fontScale)),
            child: child!,
          ),
          home: Scaffold(
            body: RepaintBoundary(
              key: capture,
              child: CustomColorPickerSheet(
                initialColor: const Color(0xff6750a4),
                onApplyColor: (color) => applied = color,
              ),
            ),
          ),
        );
        await tester.pumpWidget(ProviderScope(child: app()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final plane = find.byKey(const ValueKey('custom-color-plane'));
        await tester.ensureVisible(plane);
        await tester.drag(plane, const Offset(25, 15));
        await tester.pumpAndSettle();
        expect(applied, isNull);
        final input = find.byKey(const ValueKey('custom-color-hex'));
        final apply = find.byKey(const ValueKey('custom-color-apply'));
        await tester.ensureVisible(input);
        await tester.enterText(input, '12');
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(apply).onPressed, isNull);
        expect(applied, isNull);
        await tester.enterText(input, '#006C5B');
        await tester.pumpAndSettle();
        expect(applied, isNull);
        expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);
        final output = Platform.environment['NIOS_PALETTE_CAPTURE_DIR'];
        if (output != null) {
          fontScale = 1;
          await tester.pumpWidget(ProviderScope(child: app()));
          await tester.pumpAndSettle();
          tester
              .state<ScrollableState>(
                find
                    .descendant(
                      of: find.byType(CustomColorPickerSheet),
                      matching: find.byType(Scrollable),
                    )
                    .first,
              )
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1.5);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(output).create(recursive: true);
            await File(
              '$output/custom_${brightness.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.ensureVisible(apply);
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(applied, const Color(0xff006c5b));
        expect(tester.takeException(), isNull);
      },
    );
  }

  if (Platform.environment['NIOS_PALETTE_CAPTURE_DIR'] != null) {
    setUpAll(() async {
      for (final entry in {
        'Onest': 'assets/fonts/onest/Onest-Variable.ttf',
        'GolosText': 'assets/fonts/golos_text/GolosText-Variable.ttf',
        'BricolageGrotesque':
            'assets/fonts/bricolage_grotesque/BricolageGrotesque-Variable.ttf',
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      }.entries) {
        final loader = FontLoader(entry.key)
          ..addFont(rootBundle.load(entry.value));
        await loader.load();
      }
    });
  }
  for (final brightness in Brightness.values) {
    testWidgets('palette controls work with large text in $brightness', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({'ui.useSystemDynamic': true});
      final previousPrefs = UiSettingsNotifier.cachedPrefs;
      UiSettingsNotifier.cachedPrefs = await SharedPreferences.getInstance();
      addTearDown(() => UiSettingsNotifier.cachedPrefs = previousPrefs);
      double fontScale = 1.8;
      final capture = GlobalKey();
      // The palette field became the accent screen's own section, so the
      // screen stands in for the widget this test used to build by hand.
      Widget app() => MaterialApp(
        theme: AppTheme.themed(
          const VisualThemeSettings(
            seedColor: Color(0xFF6750A4),
            themeMode: ThemeMode.system,
            useSystemDynamic: true,
          ),
          brightness,
        ),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(fontScale)),
          child: child!,
        ),
        home: Scaffold(
          body: RepaintBoundary(
            key: capture,
            child: const SettingsAppearanceAccentScreen(isEmbedded: true),
          ),
        ),
      );
      await tester.pumpWidget(ProviderScope(child: app()));
      await tester.pumpAndSettle();
      expect(find.byType(RawImage), findsNothing);
      expect(tester.takeException(), isNull);
      expect(find.byType(RawImage), findsNothing);
      // The grid shows the whole palette at once: the pager that hid two
      // thirds of it behind a swipe is gone, and every swatch, custom tile
      // included, sits inside the section.
      final grid = find.byKey(const ValueKey('appearance-palette-strip'));
      final gridBounds = tester.getRect(grid);
      for (final label in <String>[
        'Аметист',
        'Лагуна',
        'Луг',
        'Янтарь',
        'Орхидея',
        'Сланец',
        'Небо',
        'Роза',
        'Пользовательский цвет',
      ]) {
        final bounds = tester.getRect(find.byTooltip(label));
        expect(bounds.left, greaterThanOrEqualTo(gridBounds.left));
        expect(bounds.right, lessThanOrEqualTo(gridBounds.right));
        expect(bounds.top, greaterThanOrEqualTo(gridBounds.top));
        expect(bounds.bottom, lessThanOrEqualTo(gridBounds.bottom));
      }
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(SettingsAppearanceAccentScreen)),
      );
      await tester.tap(find.byTooltip('Лагуна'));
      await tester.pump();
      expect(scope.read(uiSettingsProvider).useSystemDynamic, isFalse);
      expect(
        scope.read(uiSettingsProvider).seedColor,
        const Color(0xFF006C5B),
      );
      await tester.ensureVisible(find.byTooltip('Пользовательский цвет'));
      await tester.tap(find.byTooltip('Пользовательский цвет'));
      await tester.pumpAndSettle();
      // The custom tile opens the same sheet the HEX row opens; the counter
      // the old widget took only proved the callback fired.
      expect(find.byType(CustomColorPickerSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      final directory = Platform.environment['NIOS_PALETTE_CAPTURE_DIR'];
      if (directory != null) {
        fontScale = 1.0;
        await tester.pumpWidget(ProviderScope(child: app()));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1.5);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(directory).create(recursive: true);
          await File(
            '$directory/palette_${brightness.name}.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }

  testWidgets(
    'palette changes preserve controls without restoring decorative backgrounds',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final previousPrefs = UiSettingsNotifier.cachedPrefs;
      UiSettingsNotifier.cachedPrefs = await SharedPreferences.getInstance();
      addTearDown(() => UiSettingsNotifier.cachedPrefs = previousPrefs);
      // The accent screen owns the palette controls now, and its theme rides
      // the provider: driving the seed through the notifier runs the same
      // rebuild path the old widget saw when its theme was swapped by hand.
      Widget app({bool disableMotion = false}) => ProviderScope(
        child: MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6750A4),
            ),
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableMotion),
            child: child!,
          ),
          home: const SettingsAppearanceAccentScreen(isEmbedded: true),
        ),
      );
      // The palette rows are settings rows: they reach for sound and haptics.
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(RawImage), findsNothing);
      final UiSettingsNotifier notifier = ProviderScope.containerOf(
        tester.element(find.byType(SettingsAppearanceAccentScreen)),
      ).read(uiSettingsProvider.notifier);
      notifier.setSeedColor(const Color(0xFF006C5B));
      await tester.pump();
      expect(find.byType(RawImage), findsNothing);
      // Rapid accent changes must not recreate the disabled wallpaper renderer.
      await tester.pump(const Duration(milliseconds: 90));
      notifier.setSeedColor(const Color(0xFF475569));
      await tester.pump(const Duration(milliseconds: 60));
      notifier.setSeedColor(const Color(0xFF6750A4));
      await tester.pumpAndSettle();
      expect(find.byType(RawImage), findsNothing);
      await tester.pumpWidget(app(disableMotion: true));
      await tester.pump();
      expect(find.byType(RawImage), findsNothing);
      // The style selector is still made of real controls, not a picture of
      // them standing in for the rows.
      expect(find.byType(SettingsChoiceButtons<PaletteStyle>), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
