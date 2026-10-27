import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:pulse_flutter/models/live_location.dart';

typedef LocationPoint = ({double latitude, double longitude, double accuracy});

class _Sharing {
  _Sharing(this.chatId, this.messageId, this.location);
  final int chatId, messageId;
  LiveLocation location;
  Timer? expiry;
  Future<void> tail = Future<void>.value();
  DateTime? lastAttempt;
}

/// Collects coordinates only during an explicitly started, bounded session.
/// The callbacks use the ordinary E2E message path; no location API gets text.
class LiveLocationService {
  LiveLocationService({
    required this.firstPosition,
    required this.positions,
    required this.send,
    required this.edit,
    this.accountId,
    DateTime Function()? now,
    Timer Function(Duration, void Function())? createTimer,
  }) : now = now ?? DateTime.now,
       _createTimer =
           createTimer ?? ((duration, action) => Timer(duration, action)) {
    if (accountId != null) {
      _accounts.putIfAbsent(accountId!, () => {}).add(this);
    }
  }
  static final _accounts = <int, Set<LiveLocationService>>{};
  static Future<void> shutdownAccount(int id) => Future.wait(
    (_accounts[id]?.toList() ?? <LiveLocationService>[]).map(
      (service) => service.close(),
    ),
  );
  final int? accountId;
  final Future<LocationPoint> Function() firstPosition;
  final Stream<LocationPoint> Function() positions;
  final Future<int> Function(int chatId, String content) send;
  final Future<void> Function(int chatId, int messageId, String content) edit;
  final DateTime Function() now;
  final Timer Function(Duration, void Function()) _createTimer;
  final _sessions = <int, _Sharing>{};
  final _starting = <int>{};
  final stopped = <String>{};
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  StreamSubscription<LocationPoint>? _subscription;
  bool _closed = false;
  Future<void>? _closing;

  bool isSharing(int chatId, String id) => _sessions[chatId]?.location.id == id;

  Future<void> start(int chatId, Duration duration) async {
    if (_closed ||
        duration < const Duration(minutes: 1) ||
        duration > const Duration(hours: 24)) {
      throw StateError('Недопустимый срок передачи геопозиции');
    }
    if (_starting.contains(chatId) || _sessions.containsKey(chatId)) {
      throw StateError('Вы уже передаёте геопозицию в этом чате');
    }
    if (_sessions.length + _starting.length >= 3) {
      throw StateError('Одновременно доступны три передачи геопозиции');
    }
    _starting.add(chatId);
    try {
      final p = await firstPosition();
      if (_closed) throw StateError('Сеанс закрыт');
      final time = now().toUtc();
      final location = LiveLocation(
        id: const Uuid().v4(),
        latitude: p.latitude,
        longitude: p.longitude,
        accuracy: p.accuracy,
        createdAt: time,
        updatedAt: time,
        expiresAt: time.add(duration),
        active: true,
      );
      if (LiveLocation.parse(location.encode()) == null) {
        throw StateError('Не удалось определить координаты');
      }
      final messageId = await send(chatId, location.encode());
      if (_closed) {
        await edit(chatId, messageId, location.stop().encode());
        throw StateError('Сеанс закрыт');
      }
      final session = _Sharing(chatId, messageId, location);
      session.lastAttempt = time;
      _sessions[chatId] = session;
      final remaining = location.expiresAt.difference(now().toUtc());
      session.expiry = _createTimer(
        remaining.isNegative ? Duration.zero : remaining,
        () => unawaited(stop(chatId).catchError((Object _) {})),
      );
      try {
        _subscription ??= positions().listen(
          _onPosition,
          onError: (Object _) {
            unawaited(stopAll().catchError((Object _) {}));
          },
          onDone: () {
            _subscription = null;
            unawaited(stopAll().catchError((Object _) {}));
          },
        );
      } catch (_) {
        await stop(chatId);
        rethrow;
      }
      _changes.add(null);
    } finally {
      _starting.remove(chatId);
    }
  }

  void _onPosition(LocationPoint point) {
    final time = now().toUtc();
    if (_closed ||
        !point.latitude.isFinite ||
        !point.longitude.isFinite ||
        !point.accuracy.isFinite ||
        point.latitude.abs() > 90 ||
        point.longitude.abs() > 180 ||
        point.accuracy < 0 ||
        point.accuracy > 100000) {
      return;
    }
    for (final session in _sessions.values.toList()) {
      if (!session.location.activeAt(time)) {
        unawaited(stop(session.chatId).catchError((Object _) {}));
        continue;
      }
      if (session.lastAttempt != null &&
          time.difference(session.lastAttempt!) < const Duration(seconds: 15)) {
        continue;
      }
      session.lastAttempt = time;
      session.tail = session.tail
          .catchError((Object _) {})
          .then((_) async {
            if (_closed ||
                _sessions[session.chatId] != session ||
                !session.location.activeAt(now().toUtc())) {
              return;
            }
            final next = session.location.update(
              point.latitude,
              point.longitude,
              point.accuracy,
              now().toUtc(),
            );
            await edit(session.chatId, session.messageId, next.encode());
            session.location = next;
          })
          .catchError((Object _) {});
    }
  }

  Future<void> stop(int chatId) async {
    final session = _sessions.remove(chatId);
    if (session == null) return;
    stopped.add(session.location.id);
    session.expiry?.cancel();
    if (_sessions.isEmpty) {
      final subscription = _subscription;
      _subscription = null;
      await subscription?.cancel();
    }
    if (!_changes.isClosed) _changes.add(null);
    // Serialize the terminal update after any already in-flight position.
    await session.tail;
    await edit(chatId, session.messageId, session.location.stop().encode());
  }

  Future<void> stopAll() async {
    await Future.wait(_sessions.keys.toList().map(stop));
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    try {
      await stopAll();
    } finally {
      await _subscription?.cancel();
      _subscription = null;
      if (accountId != null) _accounts[accountId]?.remove(this);
      await _changes.close();
    }
  }
}
