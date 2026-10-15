import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pulse_flutter/core/utils/system_utils.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/core/services/account_background_policy.dart';

class BackgroundService {
  BackgroundService._();
  static final Set<Object> _work = {};
  static final ValueNotifier<int> _workCount = ValueNotifier(0);
  static ValueListenable<int> get workCount => _workCount;
  static Future<void>? _policyChain;
  static bool _authenticated = false;
  static bool get accountAuthenticated => _authenticated;
  static bool _wantService = false;
  static bool _wantWakeLock = false;

  /// Holds CPU only for an actual transfer; release is safe to call twice.
  static VoidCallback retainWork() {
    final token = Object();
    _work.add(token);
    _workCount.value = _work.length;
    return () {
      if (_work.remove(token)) _workCount.value = _work.length;
    };
  }

  /// Only an auth transition may enable service requests. A stale widget or
  /// transfer callback cannot revive a logged-out account through applyPolicy.
  static Future<void> setAuthenticated(bool authenticated) {
    final wasAuthenticated = _authenticated;
    _authenticated = authenticated;
    if (authenticated) {
      // Authorization alone requests no native work; the account policy will
      // decide whether an actual service is needed.
      return Future<void>.value();
    }
    final hadServiceRequest = _wantService || _policyChain != null;
    if (!authenticated) {
      _wantService = false;
      _wantWakeLock = false;
    }
    if (!wasAuthenticated && !hadServiceRequest) {
      return Future<void>.value();
    }
    return _enqueuePolicy();
  }

  static Future<void> applyPolicy(AccountBackgroundPolicy policy) {
    _wantService = _authenticated && policy.keepService;
    _wantWakeLock = _authenticated && policy.keepCpuAwake;
    return _enqueuePolicy();
  }

  static Future<void> _enqueuePolicy() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return Future<void>.value();
    }
    final previous = _policyChain;
    final job = previous == null
        ? _applyNativePolicy()
        : previous.catchError((Object _) {}).then((_) => _applyNativePolicy());
    late final Future<void> tail;
    tail = job.whenComplete(() {
      if (identical(_policyChain, tail)) {
        _policyChain = null;
      }
    });
    _policyChain = tail;
    return tail;
  }

  static Future<void> _applyNativePolicy() async {
    try {
      final running = await FlutterForegroundTask.isRunningService;
      if (!_authenticated || !_wantService) {
        if (running) {
          await FlutterForegroundTask.stopService();
        }
        return;
      }
      final options = ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: _wantWakeLock,
      );
      if (running) {
        await FlutterForegroundTask.updateService(
          foregroundTaskOptions: options,
        );
      } else {
        init(allowWakeLock: _wantWakeLock);
        await _startReliable();
      }
      // Logout may have happened while the native start/update was pending.
      // Stop in this same serialized operation before any caller can finish.
      if (!_authenticated || !_wantService) {
        if (await FlutterForegroundTask.isRunningService) {
          await FlutterForegroundTask.stopService();
        }
      }
    } catch (_) {
      debugPrint('[BackgroundService] Policy update unavailable');
    }
  }

  static final List<String> _titles = <String>[
    'NiosMess рядом с вами ✨',
    'Мяу~ Жду твоих сообщений 🐱',
    'Соединение активно 💕',
    'Твои чаты под защитой 🌸',
    'Пуши летают быстро~ 🕊️',
  ];

  static final List<String> _texts = <String>[
    'Все сообщения доставляются в реальном времени',
    'Секретные чаты защищены end-to-end 🔒',
    'Пуши работают исправно~',
    'Никто не пропадёт из виду 💌',
  ];

  static String _randomTitle() => _titles[Random().nextInt(_titles.length)];
  static String _randomText() => _texts[Random().nextInt(_texts.length)];

  static void init({bool allowWakeLock = false}) {
    if (kIsWeb) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'niosmess_background',
        channelName: 'NiosMess Background',
        channelDescription: 'Keeps NiosMess alive in background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        showBadge: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: allowWakeLock,
      ),
    );
  }

  static Future<void> _startReliable() async {
    if (kIsWeb) return;
    try {
      final String title = _randomTitle();
      final String text = _randomText();
      await FlutterForegroundTask.startService(
        notificationTitle: title,
        notificationText: text,
        notificationButtons: <NotificationButton>[
          const NotificationButton(id: 'stop', text: '💤 Спать'),
        ],
      );
    } catch (e) {
      debugPrint('[BackgroundService] startReliable error: $e');
    }
  }

  /// A hard shutdown revokes authorization synchronously and shares the same
  /// chain as starts/updates. Re-enabling requires a later auth transition.
  static Future<void> stop() {
    _authenticated = false;
    _wantService = false;
    _wantWakeLock = false;
    return _enqueuePolicy();
  }

  /// Prompts the user to exclude NiosMess from Android battery optimization / Doze mode
  /// to ensure timely push notifications and uninterrupted WebSocket delivery.
  static Future<void> requestDisableBatteryOptimization() async {
    if (kIsWeb) return;
    try {
      await SystemUtils.requestIgnoreBatteryOptimizations();
    } catch (e) {
      debugPrint(
        '[BackgroundService] requestDisableBatteryOptimization error: $e',
      );
    }
  }

  static void handleBackgroundServiceAction(
    String action,
    BackgroundMode currentMode,
    void Function(BackgroundMode) onSwitchToEconomy,
  ) {
    if (action == 'stop') {
      onSwitchToEconomy(BackgroundMode.economy);
    }
  }
}
