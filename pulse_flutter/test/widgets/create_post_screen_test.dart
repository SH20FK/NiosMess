import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
      expect(tester.getTopLeft(find.text('Alice Cooper')).dy, lessThan(200));
      expect(tester.getSize(find.byType(TextField)).height, greaterThan(80));
      expect(tester.takeException(), isNull);
    });

    for (final brightness in Brightness.values) {
      for (final locale in [const Locale('en'), const Locale('ru')]) {
        testWidgets('editor fits 320 dp with 200% text: $brightness $locale', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authProvider.overrideWith(_MockAuthNotifier.new),
                niosgramDraftStoreProvider.overrideWith((_) => _DraftFixture()),
                niosgramProvider.overrideWith(_MockNiosgramNotifier.new),
              ],
              child: MaterialApp(
                locale: locale,
                theme: ThemeData(useMaterial3: true, brightness: brightness),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: const CreatePostScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final title = locale.languageCode == 'ru' ? 'Новый пост' : 'New post';
          final publish = locale.languageCode == 'ru'
              ? 'Опубликовать'
              : 'Publish';
          final render = tester.renderObject<RenderParagraph>(find.text(title));
          expect(render.didExceedMaxLines, isFalse);
          expect(find.text(publish).hitTestable(), findsOneWidget);
          expect(
            find.byIcon(Icons.add_photo_alternate_outlined).hitTestable(),
            findsOneWidget,
          );
          await tester.showKeyboard(find.byType(TextField));
          tester.view.viewInsets = const FakeViewPadding(bottom: 250);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text(publish).hitTestable(), findsOneWidget);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }

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
