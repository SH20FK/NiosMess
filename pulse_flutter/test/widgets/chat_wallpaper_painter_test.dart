import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';
import 'package:pulse_flutter/widgets/wallpaper/chat_wallpaper_painter.dart';

void main() {
  group('ChatWallpaperPainter Layout Modes', () {
    const scheme = ColorScheme.light();

    for (final mode in WallpaperLayoutMode.values) {
      testWidgets('Renders layout mode: \${mode.name} without crashing', (tester) async {
        final config = ChatWallpaperConfig(layoutMode: mode, density: 0.8);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CustomPaint(
                size: const Size(400, 600),
                painter: ChatWallpaperPainter(
                  config: config,
                  scheme: scheme,
                ),
              ),
            ),
          ),
        );

        expect(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is ChatWallpaperPainter,
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('Renders M3 shapes and palette color mode cleanly', (tester) async {
      const config = ChatWallpaperConfig(
        iconSource: IconSource.niosMess,
        m3ShapeName: 'gem',
        colorMode: WallpaperColorMode.palette,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(360, 640),
              painter: ChatWallpaperPainter(
                config: config,
                scheme: scheme,
              ),
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is ChatWallpaperPainter,
        ),
        findsOneWidget,
      );
    });
  });
}
