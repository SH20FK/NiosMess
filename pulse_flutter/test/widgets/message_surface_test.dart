import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:universal_io/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/message_bubble.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults().copyWith(
    soundEffects: false,
    haptics: false,
    animateEmoji: false,
  );
}

void main() {
  final output = Platform.environment['NIOS_MEDIA_CAPTURE_DIR'];
  if (output != null) {
    setUpAll(() async {
      for (final entry in {
        'Onest': 'assets/fonts/onest/Onest-Variable.ttf',
        'NotoColorEmoji': 'assets/fonts/noto_color_emoji/NotoColorEmoji.ttf',
        'GolosText': 'assets/fonts/golos_text/GolosText-Variable.ttf',
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      }.entries) {
        await (FontLoader(
          entry.key,
        )..addFont(rootBundle.load(entry.value))).load();
      }
    });
  }
  for (final brightness in Brightness.values) {
    for (final mine in [true, false]) {
      testWidgets(
        'unframed emoji/photo and joined caption $brightness mine=$mine',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final container = ProviderContainer(
            overrides: [uiSettingsProvider.overrideWith(_Settings.new)],
          );
          addTearDown(container.dispose);
          final capture = GlobalKey();
          Future<void> snapshot(String name) async {
            if (output == null) return;
            await tester.runAsync(() async {
              final images = find.byType(Image);
              for (final image in tester.widgetList<Image>(images)) {
                await precacheImage(image.image, tester.element(images.first));
              }
            });
            await tester.pumpAndSettle();
            await tester.runAsync(() async {
              final boundary =
                  capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 1.5);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory(output).create(recursive: true);
              await File(
                '$output/${name}_${brightness.name}_$mine.png',
              ).writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }

          Widget app(Widget child) => UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(
              key: capture,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.themed(
                  const UiSettingsState.defaults().visualTheme,
                  brightness,
                ),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: Center(child: child)),
              ),
            ),
          );
          await tester.pumpWidget(
            app(
              MessageBubble(
                text: '👋',
                formattedTime: '12:30',
                isMine: mine,
                chatId: 1,
              ),
            ),
          );
          await tester.pump();
          expect(
            find.byKey(const ValueKey<String>('standalone-emoji')),
            findsOneWidget,
          );
          expect(find.text('12:30'), findsOneWidget);
          await snapshot('emoji');
          final bytes = Uint8List.fromList(
            base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
            ),
          );
          const url = 'https://example.invalid/media/surface.png';
          WsMediaFetcher.putMemoryCachedBytes(
            filePath: url,
            bytes: output == null
                ? bytes
                : (await rootBundle.load(
                    'assets/developers/SH20FK.png',
                  )).buffer.asUint8List(),
          );
          await tester.pumpWidget(
            app(
              MessageBubble(
                text: '',
                formattedTime: '12:30',
                isMine: mine,
                chatId: 1,
                mediaUrl: url,
                mediaIsImage: true,
              ),
            ),
          );
          await tester.pump();
          final bare = find.byKey(
            const ValueKey<String>('attachment-without-caption'),
          );
          expect(tester.widget<Material>(bare).color, Colors.transparent);
          expect(find.text('12:30'), findsOneWidget);
          await snapshot('photo');
          await tester.pumpWidget(
            app(
              MessageBubble(
                text: 'Подпись к фотографии',
                formattedTime: '12:30',
                isMine: mine,
                chatId: 1,
                mediaUrl: url,
                mediaIsImage: true,
              ),
            ),
          );
          await tester.pump();
          final caption = find.byKey(
            const ValueKey<String>('attachment-with-caption'),
          );
          expect(
            tester.widget<Material>(caption).color,
            isNot(Colors.transparent),
          );
          final image = find.byType(Image).last;
          expect(
            tester.getBottomLeft(image).dy,
            lessThanOrEqualTo(
              tester.getTopLeft(find.text('Подпись к фотографии')).dy,
            ),
          );
          expect(find.text('12:30'), findsOneWidget);
          expect(
            tester.getSize(image).width,
            closeTo(tester.getSize(caption).width, 1),
          );
          await snapshot('caption');
          await tester.pumpWidget(
            app(
              MessageBubble(
                text: '',
                formattedTime: '12:30',
                isMine: mine,
                chatId: 1,
                mediaUrl: 'https://example.invalid/movie.mp4',
                mediaLabel: 'movie.mp4',
              ),
            ),
          );
          await tester.pump();
          final video = find.byKey(
            const ValueKey<String>('attachment-without-caption'),
          );
          expect(tester.widget<Material>(video).color, Colors.transparent);
          expect(find.text('movie.mp4'), findsOneWidget);
          expect(find.text('12:30'), findsOneWidget);
          await snapshot('video-file');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
