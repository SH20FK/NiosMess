import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/clipboard/pasted_image.dart';
import 'package:pulse_flutter/core/media/media_album.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/recent_stickers_provider.dart';
import 'package:pulse_flutter/providers/sticker_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/services/calls/call_devices.dart';
import 'package:pulse_flutter/widgets/calls/call_devices_dialog.dart';
import 'package:pulse_flutter/widgets/chat/pasted_images_dialog.dart';
import 'package:pulse_flutter/widgets/chat/sticker_picker_view.dart';
import 'package:pulse_flutter/widgets/chat/bubble/media_album_bubble.dart';

class _AlbumTransport extends WebSocketClient {
  _AlbumTransport()
    : super(baseUrl: 'wss://example.invalid', readToken: () => '');
  int requests = 0;
  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    requests++;
    throw StateError('No automatic download permitted');
  }
}

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial();
}

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults().copyWith(
    soundEffects: false,
    haptics: false,
  );
}

class _Stickers extends StickerSetsNotifier {
  @override
  Future<List<ApiStickerSet>> build() async => const [
    ApiStickerSet(
      id: 1,
      name: 'cats',
      title: 'Cats',
      stickers: [
        ApiSticker(id: 1, url: 'https://example.invalid/cat.webp', emoji: '🐱'),
      ],
    ),
    ApiStickerSet(
      id: 2,
      name: 'hearts',
      title: 'Hearts',
      stickers: [
        ApiSticker(
          id: 2,
          url: 'https://example.invalid/heart.webp',
          emoji: '❤️',
        ),
      ],
    ),
  ];
}

class _Recents extends RecentStickersNotifier {
  @override
  Future<List<int>> build() async => [2];
  @override
  Future<void> record(int id) async {}
}

Widget app(Widget child) => ProviderScope(
  overrides: [
    authProvider.overrideWith(_Auth.new),
    uiSettingsProvider.overrideWith(_Settings.new),
    stickerSetsProvider.overrideWith(_Stickers.new),
    recentStickersProvider.overrideWith(_Recents.new),
  ],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native microphone uses sourceId so desktop WebRTC cannot mistake it for an output device',
    () {
      final constraints = const CallDevices(
        microphone: 'usb',
        camera: 'front',
      ).constraints(video: true);
      expect((constraints['audio'] as Map).containsKey('deviceId'), false);
      expect(
        (constraints['audio'] as Map)['optional'],
        contains(containsPair('sourceId', 'usb')),
      );
      expect(
        (constraints['video'] as Map)['optional'],
        contains(containsPair('sourceId', 'front')),
      );
    },
  );
  testWidgets(
    'local album tiles decode privately without entering the shared image cache',
    (tester) async {
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNw27HwPwAFhgKfaRamBAAAAABJRU5ErkJggg==',
      );
      final album = MediaAlbum.encode([
        AlbumImage('a.png', bytes),
        AlbumImage('b.png', bytes),
      ]);
      final transport = _AlbumTransport();
      final before = PaintingBinding.instance.imageCache.currentSize;
      await tester.pumpWidget(
        app(
          MediaAlbumBubble(
            url: 'local://album',
            wsClient: transport,
            localBytes: album,
          ),
        ),
      );
      await tester.pump();
      for (
        var i = 0;
        i < 20 && find.byType(RawImage).evaluate().length < 2;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(find.byType(RawImage), findsNWidgets(2));
      expect(PaintingBinding.instance.imageCache.currentSize, before);
      expect(transport.requests, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
      transport.close();
    },
  );
  testWidgets(
    'incoming albums respect disabled automatic downloads until explicitly opened',
    (tester) async {
      final transport = _AlbumTransport();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [autoDownloadAllowedProvider.overrideWithValue(false)],
          child: app(
            MediaAlbumBubble(
              url: '/uploads/offline.niosalbum.zip',
              wsClient: transport,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open album'), findsOneWidget);
      expect(transport.requests, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      transport.close();
    },
  );
  testWidgets(
    'device settings fit a narrow screen at double text size without capture',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('FlutterWebRTC.Method'),
            (call) async =>
                call.method == 'getSources' ? {'sources': []} : null,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('FlutterWebRTC.Method'),
              null,
            ),
      );
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: const CallDevicesDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'devices dialog enumerates without opening capture and saves a selected microphone',
    (tester) async {
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('FlutterWebRTC.Method'),
            (call) async {
              methods.add(call.method);
              if (call.method == 'getSources') {
                return {
                  'sources': [
                    {
                      'deviceId': 'usb-mic',
                      'kind': 'audioinput',
                      'label': 'USB microphone',
                    },
                    {
                      'deviceId': 'headphones',
                      'kind': 'audiooutput',
                      'label': 'Headphones',
                    },
                  ],
                };
              }
              return null;
            },
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('FlutterWebRTC.Method'),
              null,
            ),
      );
      CallDevices? selected;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showCallDevicesDialog(
                context,
                video: false,
                onApply: (devices) async {
                  selected = devices;
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(methods.where((m) => m != 'initialize'), [
        'getSources',
      ]); // No permission prompt, capture, renderer or mic activation.
      await tester.tap(find.byType(DropdownMenu<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('USB microphone').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(selected?.microphone, 'usb-mic');
      expect(methods.where((m) => m != 'initialize'), ['getSources']);
    },
  );
  testWidgets(
    'album confirmation sends one group, preserves caption and offers separate sending',
    (tester) async {
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNw27HwPwAFhgKfaRamBAAAAABJRU5ErkJggg==',
      );
      var groups = 0, singles = 0;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showPastedImagesDialog(
                context,
                images: [
                  PastedImage(
                    bytes: bytes,
                    name: 'a.png',
                    mimeType: 'image/png',
                  ),
                  PastedImage(
                    bytes: bytes,
                    name: 'b.png',
                    mimeType: 'image/png',
                  ),
                ],
                caption: 'important caption',
                onSend: (_, _) async {
                  singles++;
                },
                onSendAlbum: (items, caption) async {
                  groups++;
                  expect(items.length, 2);
                  expect(caption, 'important caption');
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Group photos into an album'), findsOneWidget);
      expect(groups, 0);
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(groups, 1);
      expect(singles, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'sticker hub starts with recent, searches packs and uses tap rather than long-press release to send',
    (tester) async {
      ApiSticker? sent;
      await tester.pumpWidget(
        app(
          SizedBox(
            width: 390,
            height: 360,
            child: StickerPickerView(onStickerSelected: (s) => sent = s),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recent'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'cats');
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('🐱'), findsOneWidget);
      expect(find.bySemanticsLabel('❤️'), findsNothing);
      await tester.tap(find.bySemanticsLabel('🐱'));
      await tester.pump();
      expect(sent?.id, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
