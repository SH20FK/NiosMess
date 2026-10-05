import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/features/sessions/domain/session_model.dart';

class SessionsRepository {
  const SessionsRepository(this._ref);
  final Ref _ref;

  Future<({int? currentSessionId, List<AccountSession> sessions})> getSessions() async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('list_sessions', payload: <String, dynamic>{});

    if (response is Map) {
      final int? currentId = response['current_session_id'] as int?;
      final List rawSessions = response['sessions'] as List? ?? <dynamic>[];
      final List<AccountSession> list = rawSessions
          .whereType<Map>()
          .map((Map item) => AccountSession.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
                currentSessionId: currentId,
              ))
          .toList();
      return (currentSessionId: currentId, sessions: list);
    } else if (response is List) {
      final List<AccountSession> list = response
          .whereType<Map>()
          .map((Map item) => AccountSession.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ))
          .toList();
      return (currentSessionId: null, sessions: list);
    }

    return (currentSessionId: null, sessions: const <AccountSession>[]);
  }

  Future<void> revokeSession(int sessionId) async {
    await _ref.read(webSocketClientProvider).request(
      'kick_session',
      payload: <String, dynamic>{'session_id': sessionId},
    );
  }

  Future<void> revokeOtherSessions() async {
    await _ref.read(webSocketClientProvider).request(
      'revoke_other_sessions',
      payload: <String, dynamic>{},
    );
  }
}

final Provider<SessionsRepository> sessionsRepositoryProvider =
    Provider<SessionsRepository>((Ref ref) => SessionsRepository(ref));
