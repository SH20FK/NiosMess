import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage/session_store.dart';
import '../core/notification_service.dart';

class SessionState {
  SessionState({this.token, this.username, this.name});
  final String? token;
  final String? username;
  final String? name;

  bool get isAuthed => token != null && username != null;

  Map<String, dynamic> toJson() => {
        'token': token,
        'username': username,
        'name': name,
      };

  factory SessionState.fromJson(Map<String, dynamic> json) => SessionState(
        token: json['token'] as String?,
        username: json['username'] as String?,
        name: json['name'] as String?,
      );
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(SessionState()) {
    _load();
  }

  Future<void> _load() async {
    final data = await SessionStore.load();
    if (data != null) {
      state = SessionState.fromJson(data);
      if (state.isAuthed) {
        await NotificationService.instance.setSession(state.username!, state.token!);
      }
    }
  }

  Future<void> setSession(SessionState next) async {
    state = next;
    await SessionStore.save(next.toJson());
    if (next.isAuthed) {
      await NotificationService.instance.setSession(next.username!, next.token!);
    }
  }

  Future<void> clear() async {
    state = SessionState();
    await SessionStore.clear();
    await NotificationService.instance.clearSession();
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) => SessionNotifier());
