import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/providers/notifications_provider.dart';
import 'package:pulse_flutter/screens/create_post_screen.dart';
import 'package:pulse_flutter/screens/niosgram_screen.dart';

class _MockAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(
      hydrated: true,
      busy: false,
      pendingIdentifier: null,
      error: null,
      session: AuthSession(
        accessToken: 'token',
        userId: 1,
        username: 'alice',
        displayName: 'Alice Cooper',
      ),
      profile: ApiProfile(
        id: 1,
        username: 'alice',
        displayName: 'Alice Cooper',
        bio: 'Hello world',
      ),
    );
  }

  @override
  Future<void> refreshProfile() async {}
}

class _MockNotificationsNotifier extends NotificationsNotifier {
  @override
  NotificationsState build() => const NotificationsState(unreadCount: 0);
}

class _MockNiosgramNotifier extends NiosgramNotifier {
  @override
  Future<NiosgramState> build() async {
    return const NiosgramState(posts: []);
  }
}

void main() {
  group('CreatePostScreen Responsive Layout', () {
    testWidgets('renders on compact mobile (320x640) with zero overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier()),
            notificationsProvider.overrideWith(() => _MockNotificationsNotifier()),
            niosgramProvider.overrideWith(() => _MockNiosgramNotifier()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CreatePostScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CreatePostScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('inline composer expands and renders compact icon button without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier()),
            notificationsProvider.overrideWith(() => _MockNotificationsNotifier()),
            niosgramProvider.overrideWith(() => _MockNiosgramNotifier()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NiosgramScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final quickBarFinder = find.text('Что у вас нового?');
      expect(quickBarFinder, findsOneWidget);
      await tester.tap(quickBarFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Новая публикация'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
