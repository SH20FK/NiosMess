@TestOn('browser')
library;
import 'package:pulse_flutter/core/clipboard/pasted_image.dart';
import 'package:pulse_flutter/core/clipboard/file_drop_web.dart';
import 'package:pulse_flutter/services/calls/microphone_meter_web.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:dart_webrtc/dart_webrtc.dart' show MediaStreamWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:pulse_flutter/core/clipboard/image_paste_web.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/storage/local_storage_service.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/screens/settings_storage_screen.dart';
import 'package:pulse_flutter/widgets/chat/browser_image_paste_target.dart';
import 'package:pulse_flutter/widgets/chat/pasted_images_dialog.dart';
import 'package:pulse_flutter/services/calls/call_capture_profile.dart';
import 'package:pulse_flutter/services/calls/call_sender_quality.dart';

const pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNw27HwPwAFhgKfaRamBAAAAABJRU5ErkJggg==';
web.ClipboardEvent imageEvent() {
  final data = web.DataTransfer();
  data.items.add(
    web.File(
      [base64Decode(pixel).toJS].toJS,
      'Screenshot.png',
      web.FilePropertyBag(type: 'image/png'),
    ),
  );
  return web.ClipboardEvent(
    'paste',
    web.ClipboardEventInit(
      clipboardData: data,
      bubbles: true,
      cancelable: true,
    ),
  );
}

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults().copyWith(
    soundEffects: false,
    haptics: false,
  );
}

class _Storage extends StorageSnapshotNotifier {
  @override
  Future<LocalStorageSnapshot> build() async => const LocalStorageSnapshot(
    documentsBytes: 0,
    supportBytes: 0,
    temporaryBytes: 0,
    draftBytes: 100,
    draftCount: 3,
  );
}

Widget localized(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);
void main() {
  test('file drop reads real File bytes, leaves URLs alone and detaches cleanly', () async {
    final received = Completer<List<PastedImage>>();
    final detach = listenForFileDrop(bounds: () => const Rect.fromLTWH(0, 0, 200, 200),
      canHandle: () => true, onHover: (_) {}, onFiles: received.complete, onError: received.completeError);
    final data = web.DataTransfer();
    data.items.add(web.File([base64Decode(pixel).toJS].toJS, 'screen.png', web.FilePropertyBag(type: 'image/png')));
    final drop = web.DragEvent('drop', web.DragEventInit(dataTransfer: data, clientX: 40, clientY: 40, bubbles: true, cancelable: true));
    web.document.dispatchEvent(drop);
    expect(drop.defaultPrevented, true);
    final files = await received.future.timeout(const Duration(seconds: 3));
    expect(files.single.name, 'screen.png'); expect(files.single.bytes, base64Decode(pixel));
    final link = web.DataTransfer()..setData('text/uri-list', 'https://example.invalid/image.png');
    final urlDrop = web.DragEvent('drop', web.DragEventInit(dataTransfer: link, clientX: 40, clientY: 40, bubbles: true, cancelable: true));
    web.document.dispatchEvent(urlDrop); expect(urlDrop.defaultPrevented, false);
    detach();
    final after = web.DragEvent('drop', web.DragEventInit(dataTransfer: data, clientX: 40, clientY: 40, bubbles: true, cancelable: true));
    web.document.dispatchEvent(after); expect(after.defaultPrevented, false);
  });

  test(
    'browser paste reads image bytes only from a claimed event and leaves plain text alone',
    () async {
      var active = false;
      final received = Completer<void>();
      var calls = 0;
      final detach = listenForImagePaste(
        canHandle: () => active,
        onImages: (images) {
          calls++;
          expect(images.single.bytes, base64Decode(pixel));
          expect(images.single.name, 'Screenshot.png');
          received.complete();
        },
        onError: (error) => fail('Unexpected clipboard error: $error'),
      );
      final ignored = imageEvent();
      web.document.dispatchEvent(ignored);
      expect(ignored.defaultPrevented, false);
      active = true;
      final textData = web.DataTransfer()
        ..setData('text/plain', 'do not swallow me');
      final text = web.ClipboardEvent(
        'paste',
        web.ClipboardEventInit(clipboardData: textData, cancelable: true),
      );
      web.document.dispatchEvent(text);
      expect(text.defaultPrevented, false);
      final image = imageEvent();
      web.document.dispatchEvent(image);
      expect(image.defaultPrevented, true);
      await received.future.timeout(const Duration(seconds: 5));
      detach();
      web.document.dispatchEvent(imageEvent());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(calls, 1);
    },
  );
  testWidgets(
    'focused composer previews a pasted screenshot without sending it',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var sent = 0;
      await tester.pumpWidget(
        localized(
          Builder(
            builder: (context) => BrowserImagePasteTarget(
              focusNode: focus,
              onImages: (images) => unawaited(
                showPastedImagesDialog(
                  context,
                  images: images,
                  caption: 'draft text',
                  onSend: (_, _) async {
                    sent++;
                  },
                ),
              ),
              child: TextField(focusNode: focus),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      final event = imageEvent();
      web.document.dispatchEvent(event);
      for (
        var i = 0;
        i < 100 && find.byType(PastedImagesDialog).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(find.byType(PastedImagesDialog), findsOneWidget);
      expect(sent, 0);
      expect(find.text('draft text'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(sent, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'browser storage presents real draft counts without filesystem controls or fake disk totals',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uiSettingsProvider.overrideWith(_Settings.new),
            storageSnapshotProvider.overrideWith(_Storage.new),
          ],
          child: localized(const SettingsStorageScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('Browser data'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.textContaining('0 B'), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );
  test(
    'real Chrome media capture and two peers exchange audio and deterministic video RTP with production tuning',
    () async {
      final profile = CallCaptureProfile(480);
      MediaStream? stream;
      RTCPeerConnection? caller, receiver;
      var closing = false;
      Timer? frames;
      MicrophoneMeter? meter;
      final canvas = web.HTMLCanvasElement()
        ..width = profile.width
        ..height = profile.height;
      final remoteVideo = web.HTMLVideoElement()
        ..autoplay = true
        ..muted = true;
      web.document.body?.appendChild(remoteVideo);
      try {
        stream = await navigator.mediaDevices.getUserMedia(
          profile.constraints(isWeb: true, video: true),
        );
        expect(stream.getAudioTracks(), hasLength(1));
        meter = await openMicrophoneMeter(stream);
        final level = await meter.readLevel();
        expect(level, inInclusiveRange(0, 1));
        final video = stream.getVideoTracks().single.getSettings();
        expect(video['height'], lessThanOrEqualTo(480));
        expect(video['height'], greaterThan(240));
        expect(video['frameRate'], greaterThan(15));
        // Chrome's built-in fake camera has no frames on some Windows GPU
        // drivers. Validate its constraints above, then supply deterministic
        // canvas frames so the transport/encoder assertion is portable.
        final source = (stream as MediaStreamWeb).jsStream;
        for (final track in source.getVideoTracks().toDart) {
          source.removeTrack(track);
          track.stop();
        }
        final generated = canvas.captureStream(0);
        final generatedTrack =
            generated.getVideoTracks().toDart.single
                as web.CanvasCaptureMediaStreamTrack;
        source.addTrack(generatedTrack);
        final drawing =
            canvas.getContext('2d')! as web.CanvasRenderingContext2D;
        var frame = 0;
        frames = Timer.periodic(const Duration(milliseconds: 50), (_) {
          drawing.fillStyle = ((frame++ % 2 == 0) ? '#46b8a1' : '#8899ee').toJS;
          drawing.fillRect(0, 0, canvas.width, canvas.height);
          generatedTrack.requestFrame();
        });
        caller = await createPeerConnection({
          'iceServers': [],
          'sdpSemantics': 'unified-plan',
        });
        receiver = await createPeerConnection({
          'iceServers': [],
          'sdpSemantics': 'unified-plan',
        });
        final left = caller, right = receiver;
        right.onTrack = (event) {
          if (event.streams.isNotEmpty) {
            remoteVideo.srcObject =
                (event.streams.first as MediaStreamWeb).jsStream;
          }
        };
        var leftReady = false, rightReady = false;
        final leftIce = <RTCIceCandidate>[], rightIce = <RTCIceCandidate>[];
        left.onIceCandidate = (ice) {
          if (closing || ice.candidate == null || ice.candidate!.isEmpty) {
            return;
          }
          if (rightReady) {
            unawaited(right.addCandidate(ice));
          } else {
            rightIce.add(ice);
          }
        };
        right.onIceCandidate = (ice) {
          if (closing || ice.candidate == null || ice.candidate!.isEmpty) {
            return;
          }
          if (leftReady) {
            unawaited(left.addCandidate(ice));
          } else {
            leftIce.add(ice);
          }
        };
        for (final track in stream.getTracks()) {
          await left.addTrack(track, stream);
        }
        final offer = await left.createOffer();
        await left.setLocalDescription(offer);
        await right.setRemoteDescription(offer);
        rightReady = true;
        for (final ice in rightIce) {
          await right.addCandidate(ice);
        }
        final answer = await right.createAnswer();
        await right.setLocalDescription(answer);
        await left.setRemoteDescription(answer);
        leftReady = true;
        for (final ice in leftIce) {
          await left.addCandidate(ice);
        }
        for (final sender in await left.getSenders()) {
          expect(await configureCallSender(sender, profile), true);
          expect(sender.parameters.encodings, isNotEmpty);
        }
        var audioReceived = false, videoReceived = false;
        for (var i = 0; i < 50 && !(audioReceived && videoReceived); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          for (final report in await right.getStats()) {
            if (report.type != 'inbound-rtp') continue;
            final bytes = report.values['bytesReceived'];
            if (bytes is! num || bytes <= 0) continue;
            final kind = report.values['kind'] ?? report.values['mediaType'];
            audioReceived |= kind == 'audio';
            videoReceived |= kind == 'video';
          }
        }
        final beforeRestart = await left.getLocalDescription();
        leftReady = false; rightReady = false; leftIce.clear(); rightIce.clear();
        await left.restartIce();
        final restart = await left.createOffer({'iceRestart': true});
        expect(restart.sdp, isNot(beforeRestart?.sdp));
        await left.setLocalDescription(restart);
        await right.setRemoteDescription(restart); rightReady = true;
        for (final ice in rightIce) { await right.addCandidate(ice); }
        final restartedAnswer = await right.createAnswer();
        await right.setLocalDescription(restartedAnswer);
        await left.setRemoteDescription(restartedAnswer); leftReady = true;
        for (final ice in leftIce) { await left.addCandidate(ice); }
        int totalBytes(List<StatsReport> reports) => reports.where((r) => r.type == 'inbound-rtp')
          .fold<int>(0, (n, r) => n + ((r.values['bytesReceived'] as num?)?.toInt() ?? 0));
        final beforeBytes = totalBytes(await right.getStats());
        var recovered = false;
        for (var i = 0; i < 40 && !recovered; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          recovered = totalBytes(await right.getStats()) > beforeBytes;
        }
        expect(recovered, true, reason: 'RTP must keep arriving after a real ICE restart');
        expect(
          audioReceived,
          true,
          reason: 'Real audio RTP must arrive at the other peer',
        );
        expect(
          videoReceived,
          true,
          reason: 'Real video RTP must arrive at the other peer',
        );
      } finally {
        closing = true;
        await meter?.dispose();
        frames?.cancel();
        canvas.remove();
        remoteVideo.srcObject = null;
        remoteVideo.remove();
        if (stream != null) {
          for (final track in stream.getTracks()) {
            await track.stop();
          }
          await stream.dispose();
        }
        await caller?.close();
        await caller?.dispose();
        await receiver?.close();
        await receiver?.dispose();
      }
    },
    skip: !const bool.fromEnvironment('NIOS_CALL_SYNTHETIC_MEDIA_TEST'),
  );
}
