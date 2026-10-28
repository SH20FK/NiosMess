import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/providers/niosgram_draft_provider.dart';
import 'package:pulse_flutter/core/storage/niosgram_draft_store.dart';
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

class _DraftFixture extends NiosgramDraftStore {
  _DraftFixture() : super(1);
  @override
  Future<NiosgramPostDraft?> read() async => null;
  @override
  Future<void> write(NiosgramPostDraft draft) async {}
}

void main() {
  group('CreatePostScreen Responsive Layout', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));
    testWidgets('renders on compact mobile (320x640) with zero overflow', (
      WidgetTester tester,
    ) async {
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
            niosgramDraftStoreProvider.overrideWith((_) => _DraftFixture()),
            notificationsProvider.overrideWith(
              () => _MockNotificationsNotifier(),
            ),
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

    testWidgets('feed composer opens the shared editor without overflow', (
      WidgetTester tester,
    ) async {
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
            niosgramDraftStoreProvider.overrideWith((_) => _DraftFixture()),
            notificationsProvider.overrideWith(
              () => _MockNotificationsNotifier(),
            ),
            niosgramProvider.overrideWith(() => _MockNiosgramNotifier()),
          ],
          child: const MaterialApp(
            locale: Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NiosgramScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final quickBarFinder = find.byKey(
        const ValueKey<String>('collapsed_quick_bar'),
      );
      expect(quickBarFinder, findsOneWidget);
      expect(find.text('О чём думаешь?'), findsOneWidget);
      await tester.tap(quickBarFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      for (
        var i = 0;
        i < 40 &&
            find.byIcon(Icons.add_photo_alternate_outlined).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 30));
      }

      expect(find.byType(CreatePostScreen), findsOneWidget);
      expect(find.text('Новый пост'), findsOneWidget);
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
