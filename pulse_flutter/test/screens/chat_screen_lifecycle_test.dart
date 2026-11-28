// Tests for `lib/screens/chat_detail/chat_screen_lifecycle.dart`.
//
// The lifecycle took `initState` / `dispose` / `didChangeAppLifecycleState` and
// the secret-chat screenshot guard out of `_ChatDetailScreenState`. These tests
// freeze the invariants that only a device would otherwise catch:
//   1. `setSecureFlag(true)` on entry and `false` exactly once in `dispose` —
//      strict pairing, the platform channel is mocked and inspected.
//   2. `PushNotificationService.setCurrentChat(chatId)` on entry, `null` on
//      exit, and the observer is unregistered (a later lifecycle event is not
//      delivered).
//   3. `markRead` / `markChatAsRead` only while the app is foreground.
//   4. `inlineQueryProvider.clear()` may throw once its scope is gone; dispose
//      must survive it.
//   5. The protection overlay is never built on desktop.
//   6. Screenshot notices are throttled to one per 5 s.
//   7. Sending a screenshot notice is the same message as before (text and
//      chat), and `refreshNow` never throws — it only `debugPrint`s.
//
// The platform is detected the way the app detects it
// (`DesktopWindowService.isDesktop` over `defaultTargetPlatform`), so the
// desktop case overrides `debugDefaultTargetPlatformOverride` instead of
// injecting a fake.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_screen_lifecycle.dart';

const int _chatId = 42;
const MethodChannel _securityChannel = MethodChannel(
  'com.niosmess.pulse/security',
);

ApiChatSummary _chat({bool isSecret = false}) => ApiChatSummary(
  id: _chatId,
  chatType: 'direct',
  name: 'Тестовый собеседник',
  unreadCount: 3,
  membersCount: 2,
  partnerUserId: 2,
  isSecret: isSecret,
);

/// Everything the lifecycle is allowed to reach, recorded instead of executed.
class _Recorder {
  final List<bool> secureFlags = <bool>[];
  final List<OverlayEntry> inserted = <OverlayEntry>[];
  final List<OverlayEntry> removed = <OverlayEntry>[];
  final List<String> infos = <String>[];
  final List<bool> canPersist = <bool>[];
  final List<ApiChatSummary> upserts = <ApiChatSummary>[];
  final List<Object> loadErrors = <Object>[];

  bool haptics = false;
  bool isMounted = true;
  bool? chatIsSecret;
  bool refreshFails = false;
  bool inlineQueryFails = false;
  bool loadOlderFails = false;
  bool followingLatest = false;
  int olderAdded = 0;

  int refreshCalls = 0;
  int fetchChatCalls = 0;
  int loadOlderCalls = 0;
  int markMessagesReadCalls = 0;
  int markChatAsReadCalls = 0;
  int screenshotNotices = 0;
  int inlineQueryClears = 0;
  int secretDetections = 0;
  int beforeFrameCalls = 0;
  int controllerDisposals = 0;
  int scrollJumps = 0;
}

ChatScreenLifecycle _lifecycle(
  _Recorder recorder, {
  bool isSecret = true,
  int? chatId = _chatId,
  DateTime Function()? now,
}) => ChatScreenLifecycle(
  ports: ChatLifecyclePorts(
    chatId: chatId,
    isMounted: () => recorder.isMounted,
    isSecret: () => isSecret,
    chatIsSecret: () => recorder.chatIsSecret,
    onSecretDetected: () => recorder.secretDetections++,
    setCanPersistOrdinaryDraft: recorder.canPersist.add,
    haptics: () => recorder.haptics,
    markMessagesRead: () async {
      recorder.markMessagesReadCalls++;
    },
    markChatAsRead: () => recorder.markChatAsReadCalls++,
    refreshMessages: () async {
      recorder.refreshCalls++;
      if (recorder.refreshFails) throw StateError('offline');
    },
    followingLatest: () => recorder.followingLatest,
    fetchChat: (int id) async {
      recorder.fetchChatCalls++;
      return _chat(isSecret: isSecret);
    },
    upsertChat: recorder.upserts.add,
    loadOlderPage: () async {
      recorder.loadOlderCalls++;
      if (recorder.loadOlderFails) throw StateError('offline');
      return recorder.olderAdded;
    },
    onLoadOlderError: recorder.loadErrors.add,
    clearInlineQuery: () {
      recorder.inlineQueryClears++;
      if (recorder.inlineQueryFails) throw StateError('scope destroyed');
    },
    scrimColor: () => const Color(0xFF000000),
    insertOverlay: recorder.inserted.add,
    removeOverlay: recorder.removed.add,
    onInfo: recorder.infos.add,
    sendScreenshotNotice: () => recorder.screenshotNotices++,
    onScrollToBottom: () => recorder.scrollJumps++,
    beforeSecureFlag: () => recorder.beforeFrameCalls++,
    disposeControllers: () => recorder.controllerDisposals++,
  ),
  now: now,
);

/// Lets the mocked platform channel answer `setSecureFlag`.
Future<void> _flushChannel() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

/// Delivers an app-lifecycle event the way the engine does, through
/// `SystemChannels.lifecycle`. This also updates
/// `WidgetsBinding.instance.lifecycleState`, which `isForeground` reads.
Future<void> _setLifecycle(AppLifecycleState state) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        SystemChannels.lifecycle.name,
        SystemChannels.lifecycle.codec.encodeMessage(state.toString()),
        (ByteData? _) {},
      );
}

/// Puts the binding in `resumed` before a lifecycle is attached.
///
/// Flutter synthesizes the intermediate states when the app moves *up* the
/// enum (paused -> hidden -> inactive -> resumed), and each of those reaches
/// `didChangeAppLifecycleState`. Dispatching before `attach()` keeps those
/// transitions out of the recorder.
Future<void> _ensureForeground() => _setLifecycle(AppLifecycleState.resumed);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The host may be Windows, but a test is not a desktop app: the app's own
    // detection must report "mobile" unless a test says otherwise.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_securityChannel, (MethodCall call) async {
          return null;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_securityChannel, null);
    PushNotificationService.setCurrentChat(null);
  });

  group('secure flag pairing', () {
    test('is raised on entry and lowered exactly once in dispose', () async {
      final List<bool> flags = <bool>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_securityChannel, (MethodCall call) async {
            if (call.method == 'setSecureFlag') {
              flags.add(call.arguments as bool);
            }
            return null;
          });
      final _Recorder recorder = _Recorder()..chatIsSecret = true;
      final ChatScreenLifecycle lifecycle = _lifecycle(recorder)..attach();

      lifecycle.applySecureFlag();
      await _flushChannel();
      expect(flags, <bool>[true]);
      expect(recorder.secretDetections, 1);
      expect(recorder.canPersist, <bool>[false]);

      lifecycle.dispose();
      // A second dispose must not repeat the pair.
      lifecycle.dispose();
      await _flushChannel();
      expect(flags, <bool>[true, false]);
    });

    test('an ordinary chat neither raises nor lowers the flag', () async {
      final List<bool> flags = <bool>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_securityChannel, (MethodCall call) async {
            if (call.method == 'setSecureFlag') {
              flags.add(call.arguments as bool);
            }
            return null;
          });
      final _Recorder recorder = _Recorder()..chatIsSecret = false;
      final ChatScreenLifecycle lifecycle = _lifecycle(
        recorder,
        isSecret: false,
      )..attach();

      lifecycle.applySecureFlag();
      lifecycle.dispose();
      await _flushChannel();

      expect(flags, isEmpty);
      expect(recorder.secretDetections, 0);
      expect(recorder.canPersist, <bool>[true]);
    });
  });

  group('mount and teardown', () {
    test('dispose clears the push pointer and stops observing', () async {
      await _ensureForeground();
      final _Recorder recorder = _Recorder()..chatIsSecret = true;
      final ChatScreenLifecycle lifecycle = _lifecycle(recorder)..attach();
      expect(PushNotificationService.currentChatId, _chatId);

      // Sanity: while attached, a pause is delivered and builds the overlay.
      await _setLifecycle(AppLifecycleState.paused);
      expect(recorder.inserted, hasLength(1));
      lifecycle.removeScreenshotOverlay();
      expect(recorder.removed, hasLength(1));

      lifecycle.dispose();
      await _flushChannel();
      expect(PushNotificationService.currentChatId, isNull);
      expect(recorder.controllerDisposals, 1);

      // paused -> resumed is synthesized as hidden -> inactive -> resumed, and
      // `hidden` builds the overlay. A lifecycle still registered as an
      // observer would leave two entries and two removals behind.
      await _setLifecycle(AppLifecycleState.resumed);
      expect(
        recorder.inserted,
        hasLength(1),
        reason: 'removeObserver must have unregistered the lifecycle',
      );
      expect(recorder.removed, hasLength(1));
    });

    test('dispose survives an already-destroyed inline query provider', () {
      final _Recorder recorder = _Recorder()
        ..chatIsSecret = true
        ..inlineQueryFails = true;
      final ChatScreenLifecycle lifecycle = _lifecycle(recorder)..attach();

      expect(lifecycle.dispose, returnsNormally);
      expect(recorder.inlineQueryClears, 1);
    });
  });

  group('secret-chat overlay', () {
    test('covers paused, inactive and hidden, and leaves on resumed', () async {
      await _ensureForeground();
      final _Recorder recorder = _Recorder()..chatIsSecret = true;
      final ChatScreenLifecycle lifecycle = _lifecycle(recorder)..attach();

      for (final AppLifecycleState state in <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        await _setLifecycle(state);
        expect(lifecycle.hasScreenshotOverlay, isTrue, reason: '$state');
      }
      // Never stacked: one entry for three signals.
      expect(recorder.inserted, hasLength(1));

      await _setLifecycle(AppLifecycleState.resumed);
      expect(lifecycle.hasScreenshotOverlay, isFalse);
      expect(recorder.inserted, hasLength(1));
      expect(recorder.removed, hasLength(1));

      lifecycle.dispose();
    });

    test('is never built on desktop', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await _ensureForeground();
      final _Recorder recorder = _Recorder()..chatIsSecret = true;
      final ChatScreenLifecycle lifecycle = _lifecycle(recorder)..attach();

      for (final AppLifecycleState state in <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        await _setLifecycle(state);
      }

      expect(recorder.inserted, isEmpty);
      expect(lifecycle.hasScreenshotOverlay, isFalse);
      lifecycle.dispose();
    });
  });

  group('screenshot throttle', () {
    test('two screenshots inside five seconds produce one notice', () async {
      DateTime now = DateTime.utc(2026, 11, 28, 12);
      final _Recorder recorder = _Recorder()..chatIsSecret = true;
      final ChatScreenLifecycle lifecycle = _lifecycle(recorder, now: () => now)
        ..attach();

      lifecycle.handleScreenshotAction();
      now = now.add(const Duration(seconds: 4));
      lifecycle.handleScreenshotAction();
      expect(recorder.infos, <String>[
        'В секретном чате зафиксирован снимок экрана',
      ]);
      expect(recorder.screenshotNotices, 1);

      now = now.add(const Duration(seconds: 1));
      lifecycle.handleScreenshotAction();
      expect(recorder.screenshotNotices, 2);

      lifecycle.dispose();
    });
  });

  group('read receipts', () {
    test('go out only while the app is foreground', () async {
      await _ensureForeground();
      final _Recorder recorder = _Recorder()..chatIsSecret = true;
      final ChatScreenLifecycle lifecycle = _lifecycle(recorder)..attach();

      lifecycle.scrollToBottom();
      expect(recorder.markMessagesReadCalls, 1);
      expect(recorder.markChatAsReadCalls, 1);
      expect(recorder.scrollJumps, 1);

      await _setLifecycle(AppLifecycleState.paused);
      lifecycle.scrollToBottom();
      expect(recorder.markMessagesReadCalls, 1);
      expect(recorder.markChatAsReadCalls, 1);
      expect(recorder.scrollJumps, 2);

      lifecycle.dispose();
      await _ensureForeground();
    });
  });

  group('refresh and paging', () {
    test('a failing refresh only debugPrints', () async {
      final _Recorder recorder = _Recorder()
        ..chatIsSecret = true
        ..refreshFails = true;
      final ChatScreenLifecycle lifecycle = _lifecycle(recorder)..attach();

      await expectLater(lifecycle.refreshNow(), completes);
      expect(recorder.refreshCalls, 1);
      expect(recorder.fetchChatCalls, 0);
      expect(recorder.upserts, isEmpty);

      lifecycle.dispose();
    });

    test('an ordinary chat refreshes inbox metadata', () async {
      await _ensureForeground();
      final _Recorder recorder = _Recorder()
        ..chatIsSecret = false
        ..followingLatest = true;
      final ChatScreenLifecycle lifecycle = _lifecycle(
        recorder,
        isSecret: false,
      )..attach();

      await lifecycle.refreshNow();
      expect(recorder.fetchChatCalls, 1);
      expect(recorder.upserts.single.unreadCount, 0);
      expect(recorder.markMessagesReadCalls, 1);

      lifecycle.dispose();
    });

    test(
      'older-history paging is single-flight and reports failures',
      () async {
        final _Recorder recorder = _Recorder()
          ..chatIsSecret = true
          ..olderAdded = 50;
        final ChatScreenLifecycle lifecycle = _lifecycle(recorder)..attach();

        await Future.wait(<Future<void>>[
          lifecycle.autoLoadOlderMessages(),
          lifecycle.autoLoadOlderMessages(),
        ]);
        expect(recorder.loadOlderCalls, 1);
        expect(lifecycle.loadingOlderNotifier.value, isFalse);

        recorder.loadOlderFails = true;
        expect(await lifecycle.loadOlderMessages(), isFalse);
        expect(recorder.loadErrors, hasLength(1));

        lifecycle.dispose();
      },
    );
  });
}
