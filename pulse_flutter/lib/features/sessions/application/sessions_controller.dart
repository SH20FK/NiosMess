import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/features/sessions/data/sessions_repository.dart';
import 'package:pulse_flutter/features/sessions/domain/session_model.dart';

sealed class SessionsState {
  const SessionsState();
}

final class SessionsLoading extends SessionsState {
  const SessionsLoading();
}

final class SessionsReady extends SessionsState {
  const SessionsReady({
    required this.sessions,
    this.currentSessionId,
    this.revokingIds = const <int>{},
    this.terminatingOthers = false,
  });

  final List<AccountSession> sessions;
  final int? currentSessionId;
  final Set<int> revokingIds;
  final bool terminatingOthers;

  AccountSession? get currentSession {
    if (sessions.isEmpty) return null;
    try {
      return sessions.firstWhere((AccountSession s) => s.isCurrent);
    } catch (_) {
      return null;
    }
  }

  List<AccountSession> get otherSessions {
    return sessions.where((AccountSession s) => !s.isCurrent).toList();
  }

  SessionsReady copyWith({
    List<AccountSession>? sessions,
    int? currentSessionId,
    Set<int>? revokingIds,
    bool? terminatingOthers,
  }) {
    return SessionsReady(
      sessions: sessions ?? this.sessions,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      revokingIds: revokingIds ?? this.revokingIds,
      terminatingOthers: terminatingOthers ?? this.terminatingOthers,
    );
  }
}

final class SessionsFailure extends SessionsState {
  const SessionsFailure(this.message);
  final String message;
}

class SessionsController extends Notifier<SessionsState> {
  @override
  SessionsState build() {
    load();
    return const SessionsLoading();
  }

  Future<void> load() async {
    try {
      final res = await ref.read(sessionsRepositoryProvider).getSessions();
      state = SessionsReady(
        sessions: res.sessions,
        currentSessionId: res.currentSessionId,
      );
    } catch (e) {
      state = SessionsFailure('Не удалось загрузить список сессий: $e');
    }
  }

  Future<bool> revokeSession(int sessionId) async {
    final SessionsState cur = state;
    if (cur is! SessionsReady) return false;

    state = cur.copyWith(
      revokingIds: <int>{...cur.revokingIds, sessionId},
    );

    try {
      await ref.read(sessionsRepositoryProvider).revokeSession(sessionId);
      await load();
      return true;
    } catch (_) {
      state = cur;
      return false;
    }
  }

  Future<bool> terminateOtherSessions() async {
    final SessionsState cur = state;
    if (cur is! SessionsReady) return false;

    state = cur.copyWith(terminatingOthers: true);

    try {
      await ref.read(sessionsRepositoryProvider).revokeOtherSessions();
      await load();
      return true;
    } catch (_) {
      state = cur;
      return false;
    }
  }
}

final NotifierProvider<SessionsController, SessionsState> sessionsControllerProvider =
    NotifierProvider<SessionsController, SessionsState>(SessionsController.new);
