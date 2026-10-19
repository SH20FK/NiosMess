import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/core/media/animated_media_controller_pool.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/chat/bubble/bubble_sticker_player.dart';

class _Saver extends AdaptivePerformanceNotifier {
  @override
  AdaptivePerformanceState build() => const AdaptivePerformanceState(
    mode: PerformanceMode.powerSaver, targetFps: 60, targetFrameBudgetMs: 16.67,
    recentJankRatio: 0, isDegraded: false,
  );
}

void main() {
  final pool = AnimatedMediaControllerPool.instance;
  setUp(pool.reset);
  tearDown(pool.reset);
  for (final brightness in Brightness.values) {
    testWidgets('video avatar keeps themed fallback without decoding in power saver $brightness', (tester) async {
      final preview = Platform.environment['NIOS_MEDIA_PREVIEW'] == '1';
      if (preview) {
        for (final font in {
          'GolosText': 'golos_text/GolosText-Variable.ttf',
          'Onest': 'onest/Onest-Variable.ttf',
        }.entries) {
          await (FontLoader(font.key)..addFont(rootBundle.load('assets/fonts/${font.value}'))).load();
        }
      }
      tester.view.physicalSize = const Size(320, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(ProviderScope(
        overrides: [adaptivePerformanceProvider.overrideWith(_Saver.new)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          theme: AppTheme.themed(const VisualThemeSettings(
            seedColor: Color(0xFFEAB0FF), themeMode: ThemeMode.dark,
            useSystemDynamic: false, predictiveBackEnabled: false,
          ), brightness),
          home: Builder(builder: (context) => Scaffold(body: RepaintBoundary(
            key: boundary,
            child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor,
              child: const Padding(padding: EdgeInsets.all(20), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20),
                  PulseAvatar(name: 'Елена', avatarUrl: 'https://fixture.invalid/avatar.mp4?test=1', radius: 42),
                  SizedBox(height: 20),
                  Text('Елена'),
                  SizedBox(height: 12),
                  PulseAvatar(name: 'Иван Петров', radius: 24),
                ],
              )),
            ),
          ))),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(StickerVideoPlayer), findsOneWidget);
      expect(find.text('Е'), findsOneWidget);
      expect(find.text('ИП'), findsOneWidget);
      expect(pool.initializedCount, 0);
      expect(tester.takeException(), isNull);
      if (preview) {
        await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('E:/NiosIDAndNiosmess/release/media-feed/avatars-${brightness.name}.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
