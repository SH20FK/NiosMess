import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/call_incoming_provider.dart';
import 'package:pulse_flutter/providers/call_push_handler.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/services/calls/call_starter.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    hydrated: true, busy: false, pendingIdentifier: null, error: null, profile: null,
    session: AuthSession(accessToken: 'fixture', userId: 1, username: 'one', displayName: 'One'),
  );
}

class _Socket extends WebSocketClient {
  _Socket() : super(baseUrl: 'https://fixture.invalid', readToken: () => 'fixture');
  final pushes = StreamController<Map<String, dynamic>>.broadcast();
  final actions = <String>[];
  @override
  Future<dynamic> request(String action, {
    Map<String, dynamic>? payload, Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    actions.add(action);
    if (action == 'join_call') throw StateError('fixture join rejected');
    return <String, dynamic>{};
  }
  @override
  Stream<Map<String, dynamic>> get pushStream => pushes.stream;
  @override
  void close() { unawaited(pushes.close()); super.close(); }
}

class _Sound extends Fake implements SoundService {
  @override
  Future<void> stopLoop() async {}
}

Future<void> _flush() async {
  for (var i = 0; i < 5; i++) { await Future<void>.delayed(Duration.zero); }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Socket socket;
  late ProviderContainer container;
  var containerDisposed = false;
  setUp(() {
    containerDisposed = false;
    socket = _Socket();
    container = ProviderContainer(overrides: [
      webSocketClientProvider.overrideWithValue(socket),
      authProvider.overrideWith(_Auth.new),
      chatByIdProvider(42).overrideWithValue(null),
      appSoundProvider.overrideWithValue(_Sound()),
    ]);
    container.read(callPushHandlerProvider);
  });
  tearDown(() {
    if (!containerDisposed) container.dispose();
    socket.close();
  });

  Map<String, dynamic> payload({int caller = 2, bool video = false}) => {
    'chat_id': '42', 'message_id': '100', 'room_id': 'fixture-room',
    'caller_id': '$caller', 'caller_nickname': 'Two', 'is_video': '$video',
  };

  for (final video in [false, true]) {
    test('${video ? 'video' : 'audio'} notification opens incoming flow and deduplicates WS', () async {
      PushNotificationService.handleNotificationData({
        'type': 'incoming_call', ...payload(video: video),
      });
      await _flush();
      final incoming = container.read(incomingCallProvider);
      expect(incoming?.callId, 100);
      expect(incoming?.chatId, 42);
      expect(incoming?.initiatorName, 'Two');
      expect(incoming?.isVideo, video);
      socket.pushes.add({'action': 'new_call', 'payload': payload(video: video)});
      await _flush();
      expect(identical(container.read(incomingCallProvider), incoming), isTrue);
    });
  }

  test('self call and unrelated end events cannot replace incoming call', () async {
    socket.pushes.add({'action': 'new_call', 'payload': payload(caller: 1)});
    await _flush();
    expect(container.read(incomingCallProvider), isNull);
    socket.pushes.add({'action': 'new_call', 'payload': payload()});
    await _flush();
    socket.pushes.add({'action': 'end_call', 'room_id': 'other-room'});
    await _flush();
    expect(container.read(incomingCallProvider)?.roomId, 'fixture-room');
    socket.pushes.add({'action': 'end_call', 'room_id': 'fixture-room'});
    await _flush();
    expect(container.read(incomingCallProvider), isNull);
  });

  testWidgets('accept survives overlay disposal during permission request', (tester) async {
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
    final permission = Completer<Map<int, int>>();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) => permission.future);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    Object? failure;
    Future<void>? accepted;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Consumer(builder: (context, ref, _) =>
        TextButton(onPressed: () {
          accepted = startIncomingCall(
            ref: ref, chatId: 42, callId: 100, roomId: 'fixture-room', isVideo: false,
          ).catchError((Object error) { failure = error; });
        }, child: const Text('Accept')),
      )),
    ));
    await tester.tap(find.text('Accept'));
    await tester.pumpWidget(const SizedBox.shrink());
    permission.complete({7: 0});
    await tester.runAsync(() async { await accepted; });
    container.dispose();
    containerDisposed = true;
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(socket.actions, contains('join_call'));
    expect(failure.toString(), contains('fixture join rejected'));
    expect(failure.toString(), isNot(contains('disposed')));
  });
}
