import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/widgets/chat/voice_recording_panel.dart';

void main() {
  testWidgets(
    'recording pulse stops for reduced motion and resumes afterwards',
    (tester) async {
      Widget app(bool disabled) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disabled),
          child: Scaffold(
            body: VoiceRecordingPanel(
              elapsed: Duration.zero,
              dragOffset: Offset.zero,
              isLocked: false,
              amplitudeHistory: const [],
              onSend: () {},
              onCancel: () {},
            ),
          ),
        ),
      );
      double scale() => tester
          .widget<Transform>(
            find.byKey(const ValueKey('voice-recording-pulse')),
          )
          .transform
          .getMaxScaleOnAxis();

      await tester.pumpWidget(app(false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(scale(), greaterThan(1));
      await tester.pumpWidget(app(true));
      expect(scale(), 1);
      await tester.pump(const Duration(milliseconds: 400));
      expect(scale(), 1);
      await tester.pumpWidget(app(false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(scale(), greaterThan(1));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}
