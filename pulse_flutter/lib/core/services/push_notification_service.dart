import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:pulse_flutter/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/core/notifications/notification_event.dart';
import 'package:pulse_flutter/core/notifications/notification_web_bridge.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // Data-only messages need manual local notification display
  if (message.notification != null) return;
  await PushNotificationService.showLocalNotification(message.data);
}

class PushNotificationService {
  static const String kVapidKey =
      'BKSYxeF_VSU0itkdSfWOKu6t6fn7bw4Kleb-hwnRn57lg0qj-VFAAGeLHVlO1Xg5KG0F2o43vQgBZBrHNv3Eu2w';

  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedAppSubscription;
  static final _messages = StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get messages => _messages.stream;
  static int? _accountId;
  static bool _routingReady = false;
  static final deviceRegistered = ValueNotifier<bool>(false);
  static final _handledClicks = <String>{};
  static bool get supportsPush =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  static bool get isForeground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  static Future<void> configureAccount(
    int? account, {
    bool ready = true,
  }) async {
    if (_accountId != account) deviceRegistered.value = false;
    _accountId = account;
    _routingReady = ready && account != null;
    final prefs = await SharedPreferences.getInstance();
    if (account == null) {
      await prefs.remove('notifications.active_account');
    } else {
      await prefs.setInt('notifications.active_account', account);
    }
    if (_accountId != account) return;
    if (!kIsWeb && !(prefs.getBool('ui.notifications') ?? true)) {
      try {
        await _local.cancelAll();
      } catch (_) {}
    }
    await syncNotificationWorker({
      'account_id': account,
      'enabled': account != null && (prefs.getBool('ui.notifications') ?? true),
      'preferences': {
        ...jsonDecode(
          prefs.getString('notification_preferences_$account') ?? '{}',
        ),
        'muted_chat_ids': prefs
            .getKeys()
            .where(
              (key) =>
                  key.startsWith('chat_notifications_muted_${account}_') &&
                  prefs.getBool(key) == true,
            )
            .map((key) => int.tryParse(key.split('_').last))
            .whereType<int>()
            .toList(),
      },
      'locale':
          prefs.getString('ui.localeCode') ??
          WidgetsBinding.instance.platformDispatcher.locale.languageCode,
    }).catchError((Object _) {
      debugPrint('[Push] WORKER_SETTINGS_UNAVAILABLE');
    });
    if (_routingReady) checkAndHandlePendingNotification();
  }

  static Future<void> clearAccount() async {
    _routingReady = false;
    _accountId = null;
    _currentChatId = null;
    pendingNotificationData = null;
    _pendingLocalResponse = null;
    await configureAccount(null);
    if (!kIsWeb) {
      try {
        await _local.cancelAll();
      } catch (_) {}
    }
  }

  static Future<AppLocalizations> _strings() async {
    final prefs = await SharedPreferences.getInstance();
    final language =
        prefs.getString('ui.localeCode') ??
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return lookupAppLocalizations(
      Locale(language.startsWith('ru') ? 'ru' : 'en'),
    );
  }

  static int? _currentChatId;
  static Completer<void>? _firebaseBootstrap;
  static final _incomingCalls =
      StreamController<Map<String, dynamic>>.broadcast();

  /// FCM and notification taps enter the same call flow as WebSocket pushes.
  static Stream<Map<String, dynamic>> get incomingCalls =>
      _incomingCalls.stream;

  static FlutterLocalNotificationsPlugin get localNotifications => _local;
  static int? get currentChatId => _currentChatId;

  static void setCurrentChat(int? chatId) {
    _currentChatId = chatId;
  }

  /// Called before runApp; auth and permission UX can then safely overlap the
  /// first frame with Firebase startup without touching an uninitialized app.
  static void prepareDeferredFirebase() {
    _firebaseBootstrap ??= Completer<void>();
  }

  static void finishDeferredFirebase() {
    final bootstrap = _firebaseBootstrap;
    if (bootstrap != null && !bootstrap.isCompleted) bootstrap.complete();
  }

  static Future<bool> requestPermission() async {
    try {
      await _firebaseBootstrap?.future;
      final NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('[Push] PERMISSION_UNAVAILABLE');
      return false;
    }
  }

  static Future<bool> isPermissionGranted() async {
    try {
      await _firebaseBootstrap?.future;
      final NotificationSettings settings = await _fcm
          .getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  static bool _shouldIgnorePush(
    String title,
    String body, {
    bool isCall = false,
  }) {
    final String cleanTitle = title.trim().toLowerCase();
    final String cleanBody = body.trim().toLowerCase();
    if (cleanTitle == 'new activity' || cleanBody == 'new activity') {
      return true;
    }
    // If not a call and body is empty, ignore to prevent phantom notifications
    if (!isCall && cleanBody.isEmpty) {
      return true;
    }
    return false;
  }

  static NotificationDetails _buildNotificationDetails({
    required String title,
    required String body,
    required bool isCall,
    int? chatId,
    required AppLocalizations strings,
    bool sound = true,
  }) {
    final String channelId = isCall
        ? 'niosmess_calls'
        : sound
        ? 'niosmess_messages'
        : 'niosmess_messages_silent';
    final String channelName = isCall
        ? strings.noticeCallsChannel
        : strings.noticeMessagesChannel;

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: isCall
            ? strings.noticeCallsChannel
            : strings.noticeMessagesChannel,
        importance: isCall ? Importance.max : Importance.high,
        priority: isCall ? Priority.max : Priority.high,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF6750A4),
        category: isCall
            ? AndroidNotificationCategory.call
            : AndroidNotificationCategory.message,
        styleInformation: isCall
            ? BigTextStyleInformation(body, contentTitle: title)
            : MessagingStyleInformation(
                const Person(name: 'NiosMess'),
                conversationTitle: title,
                messages: [Message(body, DateTime.now(), Person(name: title))],
              ),
        timeoutAfter: isCall ? 60000 : null,
        onlyAlertOnce: true,
        groupKey: chatId != null ? 'niosmess_chat_$chatId' : 'niosmess_general',
        subText: isCall ? strings.noticeIncomingCall : null,
        enableLights: true,
        ledColor: const Color(0xFF6750A4),
        ledOnMs: 1000,
        ledOffMs: 500,
        enableVibration: true,
        playSound: sound,
        silent: !sound,
        sound: const RawResourceAndroidNotificationSound('notification'),
        ticker: title,
        actions: isCall
            ? <AndroidNotificationAction>[
                AndroidNotificationAction(
                  'action_accept',
                  strings.noticeAccept,
                  showsUserInterface: true,
                  contextual: true,
                ),
                AndroidNotificationAction(
                  'action_decline',
                  strings.noticeDecline,
                  showsUserInterface: true,
                  cancelNotification: true,
                  contextual: true,
                ),
              ]
            : null,
        fullScreenIntent: isCall,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: sound,
        interruptionLevel: isCall
            ? InterruptionLevel.timeSensitive
            : InterruptionLevel.active,
        threadIdentifier: chatId != null ? 'chat_$chatId' : 'general',
      ),
    );
  }

  static Future<void> showLocalNotification(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final account = prefs.getInt('notifications.active_account');
    final event = NotificationEvent.fromJson(data);
    if (account == null || !event.belongsTo(account)) return;
    if (event.isCancellation) {
      final room = data['room_id']?.toString();
      if (room != null) {
        final ended = {
          ...?prefs.getStringList('notifications.ended_calls'),
          room,
        }.toList();
        await prefs.setStringList(
          'notifications.ended_calls',
          ended.skip(ended.length > 128 ? ended.length - 128 : 0).toList(),
        );
      }
      await cancelCallNotification(roomId: data['room_id']?.toString());
      return;
    }
    if (event.isCall &&
        (prefs.getStringList('notifications.ended_calls') ?? []).contains(
          data['room_id']?.toString(),
        )) {
      return;
    }
    if (event.isReadReceipt) {
      if (event.chatId != null) await cancelChatNotification(event.chatId!);
      return;
    }
    if (event.expiredAt(DateTime.now())) return;
    final options =
        jsonDecode(prefs.getString('notification_preferences_$account') ?? '{}')
            as Map<String, dynamic>;
    if (!(prefs.getBool('ui.notifications') ?? true) ||
        options[event.isCall
                ? 'calls'
                : event.chatId != null
                ? 'messages'
                : 'activity'] ==
            false ||
        (event.chatId != null &&
            (prefs.getBool(
                  'chat_notifications_muted_${account}_${event.chatId}',
                ) ??
                false))) {
      return;
    }
    final strings = await _strings();
    final title = event.title;
    final body = event.isCall
        ? strings.noticeIncomingCall
        : options['preview'] == false
        ? strings.noticeNewMessage
        : event.body;
    if (_shouldIgnorePush(title, body, isCall: event.isCall)) return;
    if (kIsWeb) return; // The FCM worker owns background web notifications.
    if (event.isCall && data['room_id'] != null) {
      await prefs.setString(
        'notifications.ringing_room',
        data['room_id'].toString(),
      );
    }
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    await _local.show(
      id: event.isCall ? kCallNotificationId : notificationSystemId(event.id),
      title: title,
      body: body,
      notificationDetails: _buildNotificationDetails(
        title: title,
        body: body,
        isCall: event.isCall,
        chatId: event.chatId,
        strings: strings,
        sound: options['sound'] != false,
      ),
      payload: jsonEncode({...data, 'account_id': account}),
    );
  }

  static void registerBackgroundHandler() {
    if (!kIsWeb) FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
  }

  static Future<void> init() async {
    registerBackgroundHandler();
    // Notification permission is requested by the authenticated shell/settings
    // UX, rather than blocking bootstrap or showing a prompt over the splash.
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );
    if (!kIsWeb) {
      await _local.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
    }

    if (!kIsWeb) {
      final NotificationAppLaunchDetails? launch = await _local
          .getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _pendingLocalResponse = launch?.notificationResponse;
      }
    }

    final strings = await _strings();
    final AndroidNotificationChannel messagesChannel =
        AndroidNotificationChannel(
          'niosmess_messages',
          strings.noticeMessagesChannel,
          description: strings.noticeMessagesChannel,
          importance: Importance.high,
          playSound: true,
        );
    final AndroidNotificationChannel callsChannel = AndroidNotificationChannel(
      'niosmess_calls',
      strings.noticeCallsChannel,
      description: strings.noticeCallsChannel,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    final AndroidNotificationChannel updatesChannel =
        AndroidNotificationChannel(
          'niosmess_updates',
          strings.noticeUpdatesChannel,
          description: strings.noticeUpdatesChannel,
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(messagesChannel);
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          'niosmess_messages_silent',
          strings.noticeSilentMessages,
          importance: Importance.high,
          playSound: false,
        ),
      );
      await androidPlugin.createNotificationChannel(callsChannel);
      await androidPlugin.createNotificationChannel(updatesChannel);
    }

    await _foregroundSubscription?.cancel();
    await _openedAppSubscription?.cancel();
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _onForegroundMessage,
    );
    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _onNotificationTap2,
    );

    installNotificationBridge(
      handleNotificationData,
      (data) => _messages.add(data),
    );
    await configureAccount(_accountId, ready: _routingReady);
    final RemoteMessage? initial = await _fcm.getInitialMessage();
    if (initial != null) {
      pendingNotificationData = initial.data;
    }
  }

  static Map<String, dynamic>? pendingNotificationData;
  static NotificationResponse? _pendingLocalResponse;

  static void checkAndHandlePendingNotification() {
    if (!_routingReady) return;
    final response = _pendingLocalResponse;
    _pendingLocalResponse = null;
    if (response != null) _onNotificationTap(response);
    if (pendingNotificationData != null) {
      final Map<String, dynamic> data = pendingNotificationData!;
      pendingNotificationData = null;
      handleNotificationData(data);
    }
  }

  static Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedAppSubscription?.cancel();
    _foregroundSubscription = null;
    _openedAppSubscription = null;
  }

  static Future<String?> getToken() async {
    try {
      await _firebaseBootstrap?.future;
      if (!await isPermissionGranted()) return null;
      if (kIsWeb) {
        return await _fcm.getToken(vapidKey: kVapidKey);
      }
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('[Push] TOKEN_UNAVAILABLE');
      return null;
    }
  }

  static Future<void> revokeToken() async {
    if (!supportsPush) return;
    try {
      await _fcm.deleteToken();
    } catch (_) {
      debugPrint('[Push] TOKEN_REVOCATION_PENDING');
    }
  }

  static Stream<String> get onTokenRefresh => _fcm.onTokenRefresh;

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    final data = <String, dynamic>{
      ...message.data,
      if (message.notification?.title != null)
        'title': message.notification!.title,
      if (message.notification?.body != null)
        'body': message.notification!.body,
    };
    final event = NotificationEvent.fromJson(data);
    if (_accountId == null ||
        (event.accountId == null && data['action'] != 'install_update') ||
        !event.belongsTo(_accountId!) ||
        event.expiredAt(DateTime.now())) {
      return;
    }
    if (event.isCall) {
      final prefs = await SharedPreferences.getInstance();
      final options =
          jsonDecode(
                prefs.getString('notification_preferences_$_accountId') ?? '{}',
              )
              as Map<String, dynamic>;
      if ((prefs.getBool('ui.notifications') ?? true) &&
          options['calls'] != false) {
        _incomingCalls.add(data);
      }
      return;
    }
    _messages.add(data);
  }

  static const int kCallNotificationId = 999999;

  /// Callback when user taps 'Принять' on a call notification
  static void Function(Map<String, dynamic> data)? onCallAccepted;

  /// Callback when user taps 'Отклонить' on a call notification
  static void Function(Map<String, dynamic> data)? onCallDeclined;

  static Future<void> showIncomingCallNotification({
    required int chatId,
    required int callId,
    required String roomId,
    required String callerName,
    required bool isVideo,
  }) async {
    final Map<String, dynamic> data = <String, dynamic>{
      'type': 'incoming_call',
      'chat_id': chatId,
      'call_id': callId,
      'message_id': callId,
      'room_id': roomId,
      'caller_nickname': callerName,
      'is_video': isVideo,
    };
    if (kIsWeb) {
      return; // Foreground call UI is already visible; worker handles hidden tabs.
    }
    final strings = await _strings();
    final body = isVideo
        ? strings.noticeIncomingVideo
        : strings.noticeIncomingCall;
    final prefs = await SharedPreferences.getInstance();
    final options =
        jsonDecode(
              prefs.getString('notification_preferences_$_accountId') ?? '{}',
            )
            as Map<String, dynamic>;
    await prefs.setString('notifications.ringing_room', roomId);
    await _local.show(
      id: kCallNotificationId,
      title: callerName,
      body: body,
      notificationDetails: _buildNotificationDetails(
        title: callerName,
        body: body,
        isCall: true,
        chatId: chatId,
        strings: strings,
        sound: options['sound'] != false,
      ),
      payload: jsonEncode({
        ...data,
        'account_id': _accountId,
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(seconds: 60))
            .toIso8601String(),
      }),
    );
  }

  static Future<void> cancelCallNotification({String? roomId}) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final current = prefs.getString('notifications.ringing_room');
      final endedRoom = roomId ?? current;
      if (endedRoom != null) {
        final ended = {
          ...?prefs.getStringList('notifications.ended_calls'),
          endedRoom,
        }.toList();
        await prefs.setStringList(
          'notifications.ended_calls',
          ended.skip(ended.length > 128 ? ended.length - 128 : 0).toList(),
        );
        await _local.cancel(id: 0, tag: 'call-$endedRoom');
      }
      // A late cancellation from an old room cannot erase a newer incoming call.
      if (roomId == null || current == roomId) {
        await _local.cancel(id: kCallNotificationId);
        await prefs.remove('notifications.ringing_room');
      }
    } catch (_) {}
  }

  static Future<void> cancelChatNotification(int chatId) async {
    if (!kIsWeb) {
      try {
        await _local.cancel(id: 0, tag: 'chat-$chatId');
      } catch (_) {}
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final Map<String, dynamic> data =
          jsonDecode(response.payload!) as Map<String, dynamic>;

      if ((response.actionId?.isNotEmpty ?? false)) {
        data['notification_action'] = response.actionId;
      }
      handleNotificationData(data);
    } catch (_) {}
  }

  static void _onNotificationTap2(RemoteMessage message) {
    handleNotificationData(message.data);
  }

  static void handleNotificationData(Map<String, dynamic> data) {
    if (!_routingReady) {
      pendingNotificationData = Map.from(data);
      return;
    }
    final event = NotificationEvent.fromJson(data);
    if (_accountId == null ||
        (event.accountId == null && data['action'] != 'install_update') ||
        !event.belongsTo(_accountId!) ||
        event.expiredAt(DateTime.now())) {
      return;
    }
    final clickId = data['_click_id']?.toString();
    if (clickId != null) {
      if (!_handledClicks.add(clickId)) return;
      if (_handledClicks.length > 128) {
        _handledClicks.remove(_handledClicks.first);
      }
    }
    if (event.isCancellation) {
      unawaited(cancelCallNotification(roomId: data['room_id']?.toString()));
      return;
    }
    if (event.isCall) {
      unawaited(cancelCallNotification());
      switch (data['notification_action']) {
        case 'action_accept':
          onCallAccepted?.call(data);
        case 'action_decline':
          onCallDeclined?.call(data);
        default:
          _incomingCalls.add(Map<String, dynamic>.from(data));
      }
      return;
    }
    final String? action = data['action']?.toString();
    if (action == 'install_update') {
      final String? apkPath = data['apk_path']?.toString();
      if (apkPath != null && apkPath.isNotEmpty) {
        OpenFile.open(apkPath, type: 'application/vnd.android.package-archive');
      }
      return;
    }

    _messages.add(data);
    final target = event.target;
    if (target != null) AppRouter.navigatorKey.currentContext?.go(target);
  }
}
