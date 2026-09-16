import 'package:flutter_test/flutter_test.dart';
import 'package:universal_io/io.dart';

void main() {
  group('AppRouter Route Declaration Order & Matching (РОУТ-1, ТЕСТ-2)', () {
    test('Static source verification: /call/outgoing and /call/dm are strictly before /call/:callId', () {
      final file = File('lib/router/app_router.dart');
      final text = file.readAsStringSync();

      final outgoingIndex = text.indexOf("path: '/call/outgoing'");
      final dmIndex = text.indexOf("path: '/call/dm/:username'");
      final callIdIndex = text.indexOf("path: '/call/:callId'");

      expect(outgoingIndex, isNonNegative, reason: '/call/outgoing must be declared');
      expect(dmIndex, isNonNegative, reason: '/call/dm/:username must be declared');
      expect(callIdIndex, isNonNegative, reason: '/call/:callId must be declared');

      expect(outgoingIndex, lessThan(callIdIndex),
          reason: '/call/outgoing must appear BEFORE /call/:callId to prevent shadowing');
      expect(dmIndex, lessThan(callIdIndex),
          reason: '/call/dm/:username must appear BEFORE /call/:callId to prevent shadowing');
    });

    test('All critical routes exist in GoRoute definitions', () {
      final file = File('lib/router/app_router.dart');
      final text = file.readAsStringSync();

      final requiredRoutes = <String>[
        "'/login'",
        "'/onboarding'",
        "'/main/:tab'",
        "'/chat/create'",
        "'/call/outgoing'",
        "'/call/dm/:username'",
        "'/call/:callId'",
        "'/settings'",
        "'/profile/:username'",
      ];

      for (final route in requiredRoutes) {
        expect(text.contains("path: $route"), isTrue,
            reason: 'Missing route definition for $route');
      }
    });
  });
}
