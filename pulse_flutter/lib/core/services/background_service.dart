import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

class BackgroundService {
  BackgroundService._();

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

  static void init() {
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
        allowWakeLock: true,
      ),
    );
  }

  static Future<void> startReliable() async {
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

  static Future<void> stop() async {
    if (kIsWeb) return;
    try {
      await FlutterForegroundTask.stopService();
    } catch (e) {
      debugPrint('[BackgroundService] stop error: $e');
    }
  }

  static void handleBackgroundServiceAction(
    String action,
    BackgroundMode currentMode,
    void Function(BackgroundMode) onSwitchToEconomy,
  ) {
    if (action == 'stop') {
      stop();
      onSwitchToEconomy(BackgroundMode.economy);
    }
  }
}
