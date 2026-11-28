import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    hydrated: true,
    busy: false,
    pendingIdentifier: null,
    error: null,
    profile: null,
    session: AuthSession(
      accessToken: 'fixture',
      userId: 1,
      username: 'one',
      displayName: 'One',
    ),
  );
}

/// Keeps native renderers untouched: the gate is what is under test.
class _Manager extends CallSessionManager {
  _Manager(Ref ref)
    : super(
        ref: ref,
        chatId: 42,
        callId: 100,
        roomId: 'fixture-room',
        isVideo: false,
        direction: CallDirection.incoming,
        displayName: 'Fixture',
      );

  @override
  void dispose() {}
}

void main() {
  test('duration ticks do not rebuild callSessionProvider watchers', () {
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_Auth.new)],
    );
    addTearDown(container.dispose);
    final manager = _Manager(container.read(callRefProvider));
    container.read(callSessionProvider.notifier).setSession(manager);

    var rebuilds = 0;
    final subscription = container.listen(
      callSessionProvider,
      (_, _) => rebuilds++,
    );
    addTearDown(subscription.close);

    final base = manager.currentData;
    manager.debugNotifySessionData(base);
    final afterFirst = rebuilds;

    for (var second = 1; second <= 3; second++) {
      manager.debugNotifySessionData(base.copyWith(durationSeconds: second));
    }
    expect(rebuilds, afterFirst);

    manager.debugNotifySessionData(
      base.copyWith(durationSeconds: 4, isMuted: true),
    );
    expect(rebuilds, greaterThan(afterFirst));
  });
}
