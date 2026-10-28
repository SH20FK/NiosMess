import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/providers/notifications_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/screens/niosgram_screen.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'fixture',
      userId: 1,
      username: 'one',
      displayName: 'One',
    ),
  );
}

class _Feed extends NiosgramNotifier {
  @override
  Future<NiosgramState> build() async => NiosgramState(
    posts: [
      NgPost(
        id: 1,
        content: 'A sample post with some text and a link.',
        author: const ApiProfile(
          id: 2,
          username: 'long_username_for_test',
          displayName: 'A very long author display name',
          bio: '',
        ),
        createdAt: DateTime.utc(2026),
        likesCount: 1234567,
        dislikesCount: 4567,
        commentsCount: 9999,
      ),
    ],
    hasMore: false,
  );
}

class _Notifications extends NotificationsNotifier {
  @override
  NotificationsState build() => const NotificationsState(unreadCount: 0);
}

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults().copyWith(
    haptics: false,
    soundEffects: false,
  );
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('feed remains usable at 320 dp and 200% text: $brightness', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final theme = AppTheme.themed(
        const VisualThemeSettings(
          seedColor: Color(0xFF6750A4),
          themeMode: ThemeMode.system,
          useSystemDynamic: false,
          predictiveBackEnabled: false,
        ),
        brightness,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            niosgramProvider.overrideWith(_Feed.new),
            notificationsProvider.overrideWith(_Notifications.new),
            uiSettingsProvider.overrideWith(_Settings.new),
          ],
          child: MaterialApp(
            theme: theme,
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const NiosgramScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NiosgramScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
