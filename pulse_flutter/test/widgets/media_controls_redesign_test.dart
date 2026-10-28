import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/widgets/chat/voice_recording_panel.dart';
import 'package:pulse_flutter/widgets/message_bubble.dart';
import 'package:pulse_flutter/widgets/voice_message_player.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final locale in [const Locale('en'), const Locale('ru')]) {
      for (final locked in [false, true]) {
        testWidgets(
          'recording fits 320 dp at 200%: $brightness $locale locked=$locked',
          (tester) async {
            tester.view.physicalSize = const Size(320, 640);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            var sent = 0, cancelled = 0;
            await tester.pumpWidget(
              MaterialApp(
                locale: locale,
                theme: ThemeData(useMaterial3: true, brightness: brightness),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(320, 640),
                    textScaler: TextScaler.linear(2),
                    disableAnimations: true,
                  ),
                  child: Scaffold(
                    body: VoiceRecordingPanel(
                      elapsed: const Duration(seconds: 62),
                      dragOffset: Offset.zero,
                      isLocked: locked,
                      amplitudeHistory: const [.2, .5, .8],
                      onSend: () => sent++,
                      onCancel: () => cancelled++,
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            expect(tester.takeException(), isNull);
            await tester.tap(find.byIcon(Icons.send_rounded));
            await tester.tap(find.byIcon(Icons.delete_outline_rounded));
            expect((sent, cancelled), (1, 1));
            final context = tester.element(find.byType(VoiceRecordingPanel));
            expect(
              tester
                  .getSize(find.byTooltip(context.l10n.mediaSendRecording))
                  .width,
              greaterThanOrEqualTo(48),
            );
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }

    for (final mine in [false, true]) {
      testWidgets(
        'voice message has no bubble and stays bounded: $brightness mine=$mine',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          Widget app(String url, int duration) => ProviderScope(
            child: MaterialApp(
              locale: const Locale('en'),
              theme: ThemeData(useMaterial3: true, brightness: brightness),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 640),
                  textScaler: TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: Scaffold(
                  body: MessageBubble(
                    text: '',
                    formattedTime: '12:30',
                    isMine: mine,
                    chatId: 1,
                    isVoice: true,
                    mediaUrl: url,
                    mediaDuration: duration,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpWidget(app('nios-stream://fixture', 8));
          await tester.pump();
          expect(tester.takeException(), isNull);
          final frame = tester.widget<Container>(
            find.byKey(const ValueKey('voice-message-unframed')),
          );
          expect((frame.decoration! as BoxDecoration).color, isNull);
          expect(
            tester.getSize(find.byType(VoiceMessagePlayer)).width,
            lessThanOrEqualTo(250),
          );
          final waveform = tester.getRect(
            find.byKey(const ValueKey('voice-message-waveform')),
          );
          final player = tester.getRect(find.byType(VoiceMessagePlayer));
          expect(waveform.left, greaterThanOrEqualTo(player.left));
          expect(waveform.right, lessThanOrEqualTo(player.right));
          expect(find.text('12:30'), findsOneWidget);
          expect(find.text('0:08'), findsOneWidget);
          await tester.pumpWidget(app('nios-stream://other', 21));
          await tester.pump();
          expect(find.text('0:21'), findsOneWidget);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
