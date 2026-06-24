import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppResumeState {
  const AppResumeState({required this.hydrated, required this.lastRoute});

  const AppResumeState.initial() : hydrated = false, lastRoute = null;

  final bool hydrated;
  final String? lastRoute;

  AppResumeState copyWith({
    bool? hydrated,
    String? lastRoute,
    bool clearRoute = false,
  }) {
    return AppResumeState(
      hydrated: hydrated ?? this.hydrated,
      lastRoute: clearRoute ? null : (lastRoute ?? this.lastRoute),
    );
  }
}

class AppResumeNotifier extends Notifier<AppResumeState> {
  Future<void>? _loadFuture;

  @override
  AppResumeState build() {
    _loadFuture = _load();
    return const AppResumeState.initial();
  }

  Future<void> ensureLoaded() async {
    await (_loadFuture ?? Future<void>.value());
  }

  Future<void> _load() async {
    state = state.copyWith(
      hydrated: true,
      lastRoute: null,
    );
  }

  Future<void> setLastRoute(String route) async {
    // Disabled to prevent route restoration saving
  }

  Future<void> clear() async {
    // Disabled
  }
}

final NotifierProvider<AppResumeNotifier, AppResumeState> appResumeProvider =
    NotifierProvider<AppResumeNotifier, AppResumeState>(AppResumeNotifier.new);
