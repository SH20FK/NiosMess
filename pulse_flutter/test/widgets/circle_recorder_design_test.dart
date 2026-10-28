import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/screens/circle_video_recorder_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final locale in [const Locale('en'), const Locale('ru')]) {
      testWidgets('circle recorder fits narrow screen: $brightness $locale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        const camera = MethodChannel('plugins.flutter.io/camera');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(camera, (
          call,
        ) async {
          switch (call.method) {
            case 'availableCameras':
              return [
                {
                  'name': 'fixture',
                  'lensFacing': 'front',
                  'sensorOrientation': 90,
                },
              ];
            case 'create':
              return {'cameraId': 1};
            case 'initialize':
              scheduleMicrotask(() {
                tester.binding.defaultBinaryMessenger.handlePlatformMessage(
                  'flutter.io/cameraPlugin/camera1',
                  const StandardMethodCodec().encodeMethodCall(
                    const MethodCall('initialized', {
                      'previewWidth': 640.0,
                      'previewHeight': 480.0,
                      'exposureMode': 'auto',
                      'exposurePointSupported': false,
                      'focusMode': 'auto',
                      'focusPointSupported': false,
                    }),
                  ),
                  (_) {},
                );
              });
              return <String, Object?>{};
            default:
              return null;
          }
        });
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            camera,
            null,
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              locale: locale,
              theme: ThemeData(useMaterial3: true, brightness: brightness),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 640),
                  textScaler: TextScaler.linear(2),
                ),
                child: const CircleVideoRecorderScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final context = tester.element(find.byType(CircleVideoRecorderScreen));
        expect(find.text(context.l10n.mediaFrontCamera), findsOneWidget);
        expect(find.byTooltip(context.l10n.mediaRecordStart), findsOneWidget);
        expect(
          find.byTooltip(context.l10n.mediaViewerFlipCamera),
          findsOneWidget,
        );
        expect(
          find.byTooltip(MaterialLocalizations.of(context).closeButtonTooltip),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip(context.l10n.mediaRecordStart));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byTooltip(context.l10n.mediaRecordStop), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }
}
