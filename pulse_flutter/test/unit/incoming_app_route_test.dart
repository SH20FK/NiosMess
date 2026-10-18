import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';
import 'package:pulse_flutter/router/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'OS activation link survives absent navigator and pending auth hydration',
    () async {
      final queue = AppRouter.incomingRoute;
      queue.take(hydrated: true);
      addTearDown(() => queue.take(hydrated: true));
      expect(AppRouter.navigatorKey.currentContext, isNull);
      const code = 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG';
      expect(
        await AppUrlLauncher.handleDeepLink(
          Uri.parse('niosmess://plus/activate#$code'),
        ),
        isTrue,
      );
      expect(queue.take(hydrated: false), isNull);
      expect(queue.take(hydrated: true), '/plus/activate#$code');
      expect(queue.take(hydrated: true), isNull);
      expect(
        await AppUrlLauncher.handleDeepLink(
          Uri.parse('https://example.com/plus/activate#$code'),
        ),
        isFalse,
      );
      expect(queue.take(hydrated: true), isNull);
    },
  );
}
