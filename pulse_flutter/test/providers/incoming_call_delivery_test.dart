import 'package:pulse_flutter/providers/chat_muted_provider.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/providers/notification_preferences_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

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
import 'package:pulse_flutter/screens/calls/incoming_call_overlay.dart';

Completer<NotificationPreferences>? _optionsGate;
Completer<bool>? _mutedGate;

class _Auth extends AuthNotifier {
  void replaceSession({int? userId = 1, String token = 'fixture'}) {
    state = state.copyWith(
      clearSession: userId == null,
      session: userId == null
          ? null
          : AuthSession(
              accessToken: token,
              userId: userId,
              username: 'fixture',
              displayName: 'Fixture',
            ),
    );
  }

  @override
  AuthState build() => const AuthState(
    hydrated: true,
    busy: false,
    pendingIdentifier: null,
    error: null,
    profile: null,
    session: AuthSession(
      accessToken: 'fixture',
      userId: 1,
      username: 'one',
      displayName: 'One',
    ),
  );
}

class _Options extends NotificationPreferencesNotifier {
  @override
  Future<NotificationPreferences> build() async =>
      _optionsGate?.future ??
      Future.value(const NotificationPreferences(sound: true));
}

class _Muted extends ChatMutedNotifier {
  _Muted() : super(42);
  @override
  Future<bool> build() async => _mutedGate?.future ?? Future.value(false);
}

class _TrackedManager extends CallSessionManager {
  _TrackedManager(Ref ref, {this.disposeGate})
    : super(
        ref: ref,
        chatId: 42,
        callId: 100,
        roomId: 'fixture-room',
        isVideo: false,
        direction: CallDirection.incoming,
        displayName: 'Fixture',
      );
  final Completer<void>? disposeGate;
  int disposals = 0;
  @override
  void dispose() {
    disposals++;
  }

  @override
  Future<void> disposeAsync() async {
    dispose();
    await disposeGate?.future;
  }
}

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() =>
      const UiSettingsState.defaults().copyWith(haptics: false);
}

class _Socket extends WebSocketClient {
  _Socket()
    : super(baseUrl: 'https://fixture.invalid', readToken: () => 'fixture');
  final pushes = StreamController<Map<String, dynamic>>.broadcast();
  final actions = <String>[];
  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    actions.add(action);
    if (action == 'join_call') throw StateError('fixture join rejected');
    return <String, dynamic>{};
  }

  @override
  Stream<Map<String, dynamic>> get pushStream => pushes.stream;
  @override
  void close() {
    unawaited(pushes.close());
    super.close();
  }
}

class _Sound extends Fake implements SoundService {
  @override
  Future<void> suspendForCall() async {}
  @override
  void resumeAfterCall() {}
  int starts = 0;
  int stops = 0;
  @override
  Future<void> startLoop(dynamic soundOrEvent, {double? volume}) async {
    starts++;
  }

  @override
  Future<void> startNotificationLoop(SoundEvent event) async {
    starts++;
  }

  @override
  Future<void> stopLoop() async {
    stops++;
  }
}

Future<void> _flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Socket socket;
  late ProviderContainer container;
  var containerDisposed = false;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _optionsGate = null;
    _mutedGate = null;
    containerDisposed = false;
    socket = _Socket();
    container = ProviderContainer(
      overrides: [
        webSocketClientProvider.overrideWithValue(socket),
        authProvider.overrideWith(_Auth.new),
        uiSettingsProvider.overrideWith(_Settings.new),
        notificationPreferencesProvider.overrideWith(_Options.new),
        chatMutedProvider(42).overrideWith(_Muted.new),
        chatByIdProvider(42).overrideWithValue(null),
        appSoundProvider.overrideWithValue(_Sound()),
      ],
    );
    container.read(callPushHandlerProvider);
    await container.read(notificationPreferencesProvider.future);
    await PushNotificationService.configureAccount(1);
  });
  tearDown(() async {
    await PushNotificationService.configureAccount(null);
    if (!containerDisposed) container.dispose();
    socket.close();
  });

  Map<String, dynamic> payload({int caller = 2, bool video = false}) => {
    'account_id': '1',
    'chat_id': '42',
    'message_id': '100',
    'room_id': 'fixture-room',
    'caller_id': '$caller',
    'caller_nickname': 'Two',
    'is_video': '$video',
  };

  for (final video in [false, true]) {
    test(
      '${video ? 'video' : 'audio'} notification opens incoming flow and deduplicates WS',
      () async {
        PushNotificationService.handleNotificationData({
          'type': 'incoming_call',
          ...payload(video: video),
        });
        await _flush();
        final incoming = container.read(incomingCallProvider);
        expect(incoming?.callId, 100);
        expect(incoming?.chatId, 42);
        expect(incoming?.initiatorName, 'Two');
        expect(incoming?.isVideo, video);
        socket.pushes.add({
          'action': 'new_call',
          'payload': payload(video: video),
        });
        await _flush();
        expect(
          identical(container.read(incomingCallProvider), incoming),
          isTrue,
        );
      },
    );
  }

  test(
    'wrong-account push is rejected and a cold click waits for its account',
    () async {
      PushNotificationService.handleNotificationData({
        'type': 'incoming_call',
        ...payload(),
        'account_id': '2',
      });
      await _flush();
      expect(container.read(incomingCallProvider), isNull);
      await PushNotificationService.configureAccount(null);
      PushNotificationService.handleNotificationData({
        'type': 'incoming_call',
        ...payload(),
      });
      await _flush();
      expect(container.read(incomingCallProvider), isNull);
      await PushNotificationService.configureAccount(1);
      await _flush();
      expect(container.read(incomingCallProvider)?.callId, 100);
    },
  );

  test(
    'self call and unrelated end events cannot replace incoming call',
    () async {
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
    },
  );

  test(
    'unidentified cancellation cannot hide a different incoming call',
    () async {
      socket.pushes.add({'action': 'new_call', 'payload': payload()});
      await _flush();
      socket.pushes.add({
        'action': 'end_call',
        'payload': {'message_id': 99},
      });
      await _flush();
      expect(container.read(incomingCallProvider)?.roomId, 'fixture-room');
    },
  );

  test(
    'old pending push cannot ring after same-account token replacement',
    () async {
      _mutedGate = Completer<bool>();
      socket.pushes.add({'action': 'new_call', 'payload': payload()});
      await _flush();
      (container.read(authProvider.notifier) as _Auth).replaceSession(
        token: 'replacement',
      );
      container.read(callPushHandlerProvider);
      _mutedGate!.complete(false);
      await _flush();
      expect(container.read(incomingCallProvider), isNull);
    },
  );

  test(
    'a disposed handler rejects late preference completion without reading Ref',
    () async {
      _optionsGate = Completer<NotificationPreferences>();
      container.invalidate(notificationPreferencesProvider);
      socket.pushes.add({'action': 'new_call', 'payload': payload()});
      await _flush();
      container.dispose();
      containerDisposed = true;
      _optionsGate!.complete(const NotificationPreferences());
      await _flush();
    },
  );

  for (final replacement in [null, 2, 1]) {
    testWidgets(
      'pending permission cannot start incoming call after session replacement $replacement',
      (tester) async {
        const channel = MethodChannel(
          'flutter.baseflow.com/permissions/methods',
        );
        final permission = Completer<Map<int, int>>();
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (_) => permission.future);
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        Object? failure;
        Future<void>? accepted;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Consumer(
                builder: (_, ref, _) => TextButton(
                  onPressed: () {
                    accepted =
                        startIncomingCall(
                          ref: ref,
                          chatId: 42,
                          callId: 100,
                          roomId: 'fixture-room',
                          isVideo: false,
                        ).catchError((Object error) {
                          failure = error;
                        });
                  },
                  child: const Text('Accept'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Accept'));
        (container.read(authProvider.notifier) as _Auth).replaceSession(
          userId: replacement,
          token: 'replacement',
        );
        permission.complete({7: 0});
        await tester.runAsync(() async {
          await accepted;
        });
        expect(
          failure,
          isA<CallStartException>().having(
            (e) => e.failure,
            'failure',
            CallStartFailure.cancelled,
          ),
        );
        expect(socket.actions, isNot(contains('join_call')));
        expect(container.read(callSessionProvider), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  test(
    'active call is disposed on token replacement and container disposal',
    () {
      final first = _TrackedManager(container.read(callRefProvider));
      container.read(callSessionProvider.notifier).setSession(first);
      (container.read(authProvider.notifier) as _Auth).replaceSession(
        token: 'replacement',
      );
      expect(container.read(callSessionProvider), isNull);
      expect(first.disposals, 1);
      final next = _TrackedManager(container.read(callRefProvider));
      container.read(callSessionProvider.notifier).setSession(next);
      container.dispose();
      containerDisposed = true;
      expect(next.disposals, 1);
    },
  );

  test(
    'account exit waits for local media disposal without server requests',
    () async {
      final gate = Completer<void>();
      final manager = _TrackedManager(
        container.read(callRefProvider),
        disposeGate: gate,
      );
      container.read(callSessionProvider.notifier).setSession(manager);
      var completed = false;
      final exiting = container
          .read(callSessionProvider.notifier)
          .shutdownForAccountExit()
          .then((_) => completed = true);
      await _flush();
      expect(container.read(callSessionProvider), isNull);
      expect(completed, false);
      expect(manager.disposals, 1);
      expect(socket.actions, isEmpty);
      gate.complete();
      await exiting;
      expect(completed, true);
    },
  );

  test(
    'partial renderer initialization disposes its successful native texture',
    () async {
      const channel = MethodChannel('FlutterWebRTC.Method');
      const texture = MethodChannel('FlutterWebRTC/Texture71');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var creates = 0;
      final disposed = <int>[];
      messenger.setMockMethodCallHandler(texture, (_) async => null);
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'initialize') return null;
        if (call.method == 'createVideoRenderer') {
          creates++;
          if (creates == 2) {
            throw PlatformException(code: 'renderer_unavailable');
          }
          return {'textureId': 71};
        }
        if (call.method == 'videoRendererDispose') {
          disposed.add((call.arguments as Map)['textureId'] as int);
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        messenger.setMockMethodCallHandler(texture, null);
      });
      final manager = CallSessionManager(
        ref: container.read(callRefProvider),
        chatId: 42,
        callId: 100,
        roomId: 'fixture-room',
        isVideo: true,
        direction: CallDirection.incoming,
        displayName: 'Fixture',
      );
      await expectLater(
        manager.initRenderers(),
        throwsA(isA<PlatformException>()),
      );
      await manager.disposeAsync();
      expect(disposed, [71]);
      await manager.initRenderers();
      expect(
        creates,
        2,
        reason: 'A late screen callback cannot allocate after disposal',
      );
    },
  );

  testWidgets('accept survives overlay disposal during permission request', (
    tester,
  ) async {
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
    final permission = Completer<Map<int, int>>();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) => permission.future);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    Object? failure;
    Future<void>? accepted;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () {
                accepted =
                    startIncomingCall(
                      ref: ref,
                      chatId: 42,
                      callId: 100,
                      roomId: 'fixture-room',
                      isVideo: false,
                    ).catchError((Object error) {
                      failure = error;
                    });
              },
              child: const Text('Accept'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Accept'));
    await tester.pumpWidget(const SizedBox.shrink());
    permission.complete({7: 0});
    await tester.runAsync(() async {
      await accepted;
    });
    container.dispose();
    containerDisposed = true;
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(socket.actions, contains('join_call'));
    expect(failure.toString(), contains('fixture join rejected'));
    expect(failure.toString(), isNot(contains('disposed')));
  });

  testWidgets('incoming overlay stops ringing safely when removed', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    container
        .read(incomingCallProvider.notifier)
        .set(
          const IncomingCallData(
            callId: 100,
            roomId: 'fixture-room',
            chatId: 42,
            isVideo: false,
            initiatorId: 2,
            initiatorName: 'Two',
          ),
        );
    final sound = container.read(appSoundProvider) as _Sound;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: IncomingCallOverlay())),
      ),
    );
    await tester.runAsync(_flush);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Two'), findsOneWidget);
    expect(sound.starts, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(sound.stops, 1);
    expect(tester.takeException(), isNull);
    container.dispose();
    containerDisposed = true;
    await tester.pumpAndSettle();
  });
}
