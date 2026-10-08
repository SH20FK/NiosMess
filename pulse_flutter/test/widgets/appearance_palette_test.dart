import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/screens/settings_appearance_screen.dart';
import 'package:pulse_flutter/widgets/settings/palette_mesh_preview.dart';
import 'package:universal_io/io.dart';

Future<void> _waitForMeshShader(WidgetTester tester) async {
  final paint = find.descendant(
    of: find.byType(PaletteMeshPreview),
    matching: find.byType(CustomPaint),
  );
  for (int attempt = 0; attempt < 100 && paint.evaluate().isEmpty; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(
    paint,
    findsOneWidget,
    reason: 'The actual mesh_gradient shader must load',
  );
}

void main() {
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
      Color? selected;
      bool dynamic = true;
      int customOpened = 0;
      double fontScale = 1.8;
      final capture = GlobalKey();
      Widget app() => MaterialApp(
        theme: AppTheme.themed(
          VisualThemeSettings(
            seedColor: selected ?? const Color(0xFF6750A4),
            themeMode: ThemeMode.system,
            useSystemDynamic: dynamic,
            predictiveBackEnabled: true,
          ),
          brightness,
        ),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(fontScale)),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: RepaintBoundary(
                    key: capture,
                    child: NiosColorField(
                      scheme: Theme.of(context).colorScheme,
                      seedColor: selected ?? const Color(0xFF6750A4),
                      useSystemDynamic: dynamic,
                      paletteStyle: PaletteStyle.expressive,
                      onColorSelected: (color) => selected = color,
                      onToggleDynamic: (value) => dynamic = value,
                      onCustomColorTap: () => customOpened++,
                      onSelectPaletteStyle: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await _waitForMeshShader(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(PaletteMeshPreview), findsOneWidget);
      expect(find.byType(RawImage), findsNothing);
      await tester.tap(find.text('Лагуна'));
      expect(dynamic, isFalse);
      expect(selected, const Color(0xFF006C5B));
      await tester.ensureVisible(find.byTooltip('Пользовательский цвет'));
      await tester.tap(find.byTooltip('Пользовательский цвет'));
      await tester.pumpAndSettle();
      expect(customOpened, 1);
      expect(tester.takeException(), isNull);
      final directory = Platform.environment['NIOS_PALETTE_CAPTURE_DIR'];
      if (directory != null) {
        fontScale = 1.0;
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        final strip = find.byKey(const ValueKey('appearance-palette-strip'));
        tester
            .state<ScrollableState>(
              find.descendant(of: strip, matching: find.byType(Scrollable)),
            )
            .position
            .jumpTo(0);
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

  testWidgets('mesh palette transitions finish and respect reduced motion', (
    tester,
  ) async {
    Widget card(Color seed, bool disableMotion) => MaterialApp(
      themeAnimationDuration: Duration.zero,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seed)),
      home: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableMotion),
            child: SingleChildScrollView(
              child: NiosColorField(
                scheme: scheme,
                seedColor: scheme.primary,
                useSystemDynamic: false,
                paletteStyle: PaletteStyle.expressive,
                onColorSelected: (_) {},
                onCustomColorTap: () {},
                onToggleDynamic: (_) {},
                onSelectPaletteStyle: (_) {},
              ),
            ),
          );
        },
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
    await tester.pumpWidget(card(const Color(0xFF6750A4), false));
    await tester.pumpAndSettle();
    await _waitForMeshShader(tester);
    await tester.pumpWidget(card(const Color(0xFF006C5B), false));
    expect(find.byType(PaletteMeshPreview), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(PaletteMeshPreview), findsOneWidget);
    await tester.pumpWidget(card(const Color(0xFF984061), true));
    await tester.pump();
    expect(find.byType(PaletteMeshPreview), findsOneWidget);
    expect(find.byType(AnimatedSwitcher), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mesh motion pauses offscreen, in background and in power saving',
    (tester) async {
      const colors = [
        Color(0xFF7CE0CE),
        Color(0xFFD9BAFF),
        Color(0xFFB4DEFF),
        Color(0xFFFCD5AA),
      ];
      Widget card({
        bool visible = true,
        bool animate = true,
        bool reduced = false,
      }) => MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: TickerMode(
              enabled: visible,
              child: SizedBox(
                width: 320,
                height: 160,
                child: PaletteMeshPreview(colors: colors, animate: animate),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(card());
      await _waitForMeshShader(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(card(visible: false));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(card());
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(card(animate: false));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(card(reduced: true));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
