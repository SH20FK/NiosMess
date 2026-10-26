import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/notifications/notification_event.dart';
import 'package:pulse_flutter/core/notifications/notification_history_store.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/chat_muted_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/notification_preferences_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/providers/in_app_notification_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

enum AppNotificationType { message, postLike, postComment, other }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.payload,
    this.isRead = false,
  });

  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final Map<String, dynamic>? payload;
  final bool isRead;

  NotificationEvent get event => NotificationEvent.fromJson({
    ...?payload,
    'event_id': id,
    'title': title,
    'body': body,
    'created_at': createdAt.toIso8601String(),
    'is_read': isRead,
    'type': switch (type) {
      AppNotificationType.postLike => 'post_like',
      AppNotificationType.postComment => 'post_comment',
      AppNotificationType.message => 'message',
      _ => 'other',
    },
  });

  factory AppNotification.fromEvent(NotificationEvent event) => AppNotification(
    id: event.id,
    type: switch (event.type) {
      'message' || 'new_message' => AppNotificationType.message,
      'post_like' => AppNotificationType.postLike,
      'post_comment' => AppNotificationType.postComment,
      _ => AppNotificationType.other,
    },
    title: event.title,
    body: event.body,
    createdAt: event.createdAt,
    isRead: event.isRead,
    payload: event.toJson(),
  );

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    createdAt: createdAt,
    payload: payload,
    isRead: isRead ?? this.isRead,
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final String typeStr = json['type'] as String? ?? '';
    final AppNotificationType type = switch (typeStr) {
      'message' => AppNotificationType.message,
      'post_like' => AppNotificationType.postLike,
      'post_comment' => AppNotificationType.postComment,
      _ => AppNotificationType.other,
    };
    return AppNotification(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      title: json['title'] as String? ?? 'NiosMess',
      body: json['body'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['is_read'] == true || json['read'] == true,
      payload: json['payload'] is Map
          ? asStringMap(json['payload'] as Map)
          : null,
    );
  }
}

class NotificationsState {
  const NotificationsState({
    this.notifications = const <AppNotification>[],
    this.unreadCount = 0,
  });

  final List<AppNotification> notifications;
  final int unreadCount;

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
  }) => NotificationsState(
    notifications: notifications ?? this.notifications,
    unreadCount: unreadCount ?? this.unreadCount,
  );
}

class NotificationsNotifier extends Notifier<NotificationsState> {
  NotificationHistoryStore? _store;
  int? _account;
  Future<void> _delivery = Future.value();
  Future<void> _historyReady = Future.value();
  bool _restoring = false, _readAllOnRestore = false, _clearOnRestore = false;
  final _readIdsOnRestore = <String>{};
  final _readChatsOnRestore = <int>{};

  @override
  NotificationsState build() {
    final account = ref.watch(authProvider.select((s) => s.session?.userId));
    _account = account;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.mounted && _account == account) {
        unawaited(PushNotificationService.configureAccount(account));
      }
    });
    _store = account == null
        ? null
        : NotificationHistoryStore.forAccount(account);
    final store = _store;
    _restoring = store != null;
    _readAllOnRestore = false;
    _clearOnRestore = false;
    _readIdsOnRestore.clear();
    _readChatsOnRestore.clear();
    _historyReady = store == null
        ? Future.value()
        : store
              .restore()
              .then((events) {
                if (!ref.mounted ||
                    _account != account ||
                    ref.read(authProvider.notifier).isLoggingOut) {
                  return;
                }
                var merged = _clearOnRestore ? <NotificationEvent>[] : events;
                for (final n in state.notifications) {
                  merged = mergeNotification(merged, n.event);
                }
                _setEvents(
                  merged
                      .map(
                        (event) =>
                            _readAllOnRestore ||
                                _readIdsOnRestore.contains(event.id) ||
                                _readChatsOnRestore.contains(event.chatId)
                            ? event.read()
                            : event,
                      )
                      .toList(),
                );
                _restoring = false;
                _readIdsOnRestore.clear();
                _readChatsOnRestore.clear();
              })
              .catchError((Object _) {
                if (!ref.mounted || _account != account) return;
                _restoring = false;
                debugPrint('[Notifications] HISTORY_RESTORE_UNAVAILABLE');
              });
    final ws = ref.read(webSocketClientProvider).pushStream.listen((event) {
      if (event['action'] == 'chat_read') {
        final data = event['payload'];
        if (data is Map &&
            data['user_id'] == account &&
            data['chat_id'] is int) {
          markChatRead(data['chat_id'] as int);
          unawaited(
            PushNotificationService.cancelChatNotification(
              data['chat_id'] as int,
            ),
          );
        }
        return;
      }
      if (event['action'] != 'notification') return;
      final data = event['payload'] ?? event['data'];
      if (data is Map) accept(asStringMap(data));
    });
    final push = PushNotificationService.messages.listen(accept);
    ref.onDispose(() {
      ws.cancel();
      push.cancel();
    });
    return const NotificationsState();
  }

  void _setEvents(List<NotificationEvent> events) {
    state = NotificationsState(
      notifications: events
          .map(AppNotification.fromEvent)
          .toList(growable: false),
      unreadCount: events.where((n) => !n.isRead).length,
    );
  }

  Future<void> accept(Map<String, dynamic> data, {bool present = true}) {
    final account = _account;
    final task = _delivery.catchError((Object _) {}).then((_) async {
      await _historyReady;
      if (account == null ||
          !ref.mounted ||
          _account != account ||
          ref.read(authProvider.notifier).isLoggingOut) {
        return;
      }
      var event = NotificationEvent.fromJson(data);
      if (!event.belongsTo(account) || event.expiredAt(DateTime.now())) return;
      if (event.isCancellation) {
        await PushNotificationService.cancelCallNotification(
          roomId: data['room_id']?.toString(),
        );
        return;
      }
      if (event.isReadReceipt) {
        if (event.chatId != null) {
          markChatRead(event.chatId!);
          await PushNotificationService.cancelChatNotification(event.chatId!);
        }
        return;
      }
      if (event.isCall) {
        return; // Call state machine owns ringing and deduplication.
      }
      final language = ref
          .read(uiSettingsProvider)
          .effectiveLocaleCode(PlatformDispatcher.instance.locale.languageCode);
      final strings = lookupAppLocalizations(Locale(language));
      if (event.type == 'post_like' || event.type == 'post_comment') {
        final actor = event.data['actor_name']?.toString();
        if (actor != null) {
          event = NotificationEvent.fromJson({
            ...event.toJson(),
            'body':
                '$actor · ${event.type == 'post_like' ? strings.noticePostLike : strings.noticePostComment}',
          });
        }
      }
      final prefs = await ref.read(notificationPreferencesProvider.future);
      if (!ref.mounted || _account != account) return;
      if (event.chatId != null &&
          await ref.read(chatMutedProvider(event.chatId!).future)) {
        return;
      }
      if (!ref.mounted || _account != account) return;
      if (!ref.read(uiSettingsProvider).notifications ||
          (event.chatId != null ? !prefs.messages : !prefs.activity)) {
        return;
      }
      final previous = state.notifications
          .where((n) => n.id == event.id)
          .firstOrNull;
      final duplicate = previous != null;
      if (previous != null &&
          event.avatarUrl == null &&
          previous.event.avatarUrl != null) {
        event = NotificationEvent.fromJson({
          ...event.toJson(),
          'avatar_url': previous.event.avatarUrl,
        });
      }
      if (event.type != 'reminder' &&
          PushNotificationService.currentChatId == event.chatId &&
          event.chatId != null &&
          PushNotificationService.isForeground) {
        event = event.read();
        present = false;
      }
      if (!prefs.preview) {
        event = NotificationEvent.fromJson({
          ...event.toJson(),
          'body': strings.noticeNewMessage,
        });
      }
      _setEvents(
        mergeNotification(
          state.notifications.map((n) => n.event).toList(),
          event,
        ),
      );
      final snapshot = state.notifications.map((n) => n.event).toList();
      try {
        await _store?.save(snapshot);
      } catch (_) {
        debugPrint('[Notifications] HISTORY_WRITE_UNAVAILABLE');
      }
      if (!ref.mounted ||
          _account != account ||
          !present ||
          (duplicate && ref.read(inAppNotificationProvider)?.id != event.id) ||
          !PushNotificationService.isForeground) {
        return;
      }
      if (event.body.trim().isEmpty ||
          event.body.toLowerCase() == 'new activity') {
        return;
      }
      ref
          .read(inAppNotificationProvider.notifier)
          .show(
            InAppNotificationItem(
              id: event.id,
              title: event.title,
              body: event.body,
              avatarUrl: event.avatarUrl,
              route: event.target,
              chatId: event.chatId,
              timestamp: event.createdAt,
            ),
          );
    });
    _delivery = task;
    return task;
  }

  void stopAccount() {
    _account = null;
    state = const NotificationsState();
  }

  void markRead(String id) {
    if (_restoring) _readIdsOnRestore.add(id);
    _setEvents(
      state.notifications
          .map((n) => n.id == id ? n.event.read() : n.event)
          .toList(),
    );
    _persist();
  }

  void markChatRead(int chatId) {
    if (_restoring) _readChatsOnRestore.add(chatId);
    _setEvents(
      state.notifications
          .map((n) => n.event.chatId == chatId ? n.event.read() : n.event)
          .toList(),
    );
    _persist();
  }

  void markAllRead() {
    if (_restoring) _readAllOnRestore = true;
    _setEvents(state.notifications.map((n) => n.event.read()).toList());
    _persist();
  }

  void _persist() {
    final store = _store, account = _account;
    if (store == null) return;
    unawaited(
      _historyReady
          .then((_) async {
            if (!ref.mounted ||
                _account != account ||
                !identical(_store, store)) {
              return;
            }
            await store.save(state.notifications.map((n) => n.event).toList());
          })
          .catchError((Object _) {
            debugPrint('[Notifications] HISTORY_WRITE_UNAVAILABLE');
          }),
    );
  }

  void clear() {
    if (_restoring) _clearOnRestore = true;
    state = const NotificationsState();
    _persist();
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, NotificationsState>(
      NotificationsNotifier.new,
    );
