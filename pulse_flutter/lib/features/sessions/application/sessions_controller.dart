import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/features/sessions/data/sessions_repository.dart';
import 'package:pulse_flutter/features/sessions/domain/session_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';

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
  int _epoch = 0;
  (int?, String?) _account = (null, null);
  int _request = 0;

  bool _current(int epoch) =>
      ref.mounted &&
      epoch == _epoch &&
      !ref.read(authProvider.notifier).isLoggingOut &&
      _account ==
          (
            ref.read(authProvider).session?.userId,
            ref.read(authProvider).session?.accessToken,
          ) &&
      ref.read(authProvider).isAuthenticated;

  @override
  SessionsState build() {
    final account = ref.watch(
      authProvider.select(
        (auth) => (auth.session?.userId, auth.session?.accessToken),
      ),
    );
    _account = account;
    final epoch = ++_epoch;
    ref.onDispose(() {
      if (_epoch == epoch) _epoch++;
    });
    if (account.$1 == null || account.$2?.isNotEmpty != true) {
      return const SessionsReady(sessions: []);
    }
    unawaited(Future<void>.microtask(() => _load(epoch)));
    return const SessionsLoading();
  }

  Future<void> load() => _load(_epoch);

  Future<void> _load(int epoch) async {
    if (!_current(epoch)) return;
    final current = state;
    if (current is SessionsReady &&
        (current.terminatingOthers || current.revokingIds.isNotEmpty)) {
      return;
    }
    final request = ++_request;
    try {
      final res = await ref.read(sessionsRepositoryProvider).getSessions();
      if (!_current(epoch) || request != _request) return;
      state = SessionsReady(
        sessions: res.sessions,
        currentSessionId: res.currentSessionId,
      );
    } catch (_) {
      if (_current(epoch) && request == _request) {
        state = const SessionsFailure('sessions_load_failed');
      }
    }
  }

  Future<bool> revokeSession(int sessionId) async {
    final epoch = _epoch;
    final SessionsState cur = state;
    if (!_current(epoch) ||
        cur is! SessionsReady ||
        cur.terminatingOthers ||
        cur.revokingIds.isNotEmpty ||
        sessionId == cur.currentSessionId ||
        !cur.sessions.any((s) => s.id == sessionId && !s.isCurrent)) {
      return false;
    }

    // A pending refresh must not replace a mutation's disabled state.
    _request++;

    state = cur.copyWith(revokingIds: <int>{...cur.revokingIds, sessionId});

    try {
      await ref.read(sessionsRepositoryProvider).revokeSession(sessionId);
      if (!_current(epoch)) return false;
      state = cur.copyWith(
        sessions: cur.sessions.where((s) => s.id != sessionId).toList(),
        revokingIds: const {},
      );
      return true;
    } catch (_) {
      if (_current(epoch)) state = cur;
      return false;
    }
  }

  Future<bool> terminateOtherSessions() async {
    final epoch = _epoch;
    final SessionsState cur = state;
    if (!_current(epoch) ||
        cur is! SessionsReady ||
        cur.currentSessionId == null ||
        cur.terminatingOthers ||
        cur.revokingIds.isNotEmpty ||
        cur.otherSessions.isEmpty) {
      return false;
    }

    _request++;

    state = cur.copyWith(terminatingOthers: true);

    try {
      await ref.read(sessionsRepositoryProvider).revokeOtherSessions();
      if (!_current(epoch)) return false;
      state = cur.copyWith(
        sessions: cur.sessions.where((s) => s.isCurrent).toList(),
        terminatingOthers: false,
      );
      return true;
    } catch (_) {
      if (_current(epoch)) state = cur;
      return false;
    }
  }
}

final NotifierProvider<SessionsController, SessionsState>
sessionsControllerProvider =
    NotifierProvider<SessionsController, SessionsState>(SessionsController.new);
