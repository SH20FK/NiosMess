import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionState {
  const SessionState({
    required this.hydrated,
    required this.onboardingCompleted,
  });

  const SessionState.initial() : hydrated = false, onboardingCompleted = false;

  final bool hydrated;
  final bool onboardingCompleted;

  SessionState copyWith({bool? hydrated, bool? onboardingCompleted}) {
    return SessionState(
      hydrated: hydrated ?? this.hydrated,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }
}

class SessionNotifier extends Notifier<SessionState> {
  static const String _onboardingKey = 'session.onboardingCompleted';

  Future<void>? _loadFuture;

  @override
  SessionState build() {
    _loadFuture = _load();
    return const SessionState.initial();
  }

  Future<void> ensureLoaded() async {
    await (_loadFuture ?? Future<void>.value());
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      hydrated: true,
      onboardingCompleted: prefs.getBool(_onboardingKey) ?? false,
    );
  }

  Future<void> completeOnboarding() async {
    final SessionState next = state.copyWith(onboardingCompleted: true);
    state = next;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }
}

final NotifierProvider<SessionNotifier, SessionState> sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
