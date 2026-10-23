import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/platform/client_capabilities.dart';
import 'package:pulse_flutter/core/storage/local_storage_service.dart';
import 'package:pulse_flutter/core/clipboard/pasted_image.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/features/settings/application/settings_health_controller.dart';
import 'package:pulse_flutter/screens/profile_screen.dart';
import 'package:pulse_flutter/screens/settings_appearance_screen.dart';
import 'package:pulse_flutter/screens/settings_chats_screen.dart';
import 'package:pulse_flutter/widgets/chat/pasted_images_dialog.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial();
  @override
  Future<void> refreshProfile() async {}
}

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults().copyWith(
    soundEffects: false,
    haptics: false,
  );
}

class _Storage extends StorageSnapshotNotifier {
  @override
  Future<LocalStorageSnapshot> build() async =>
      const LocalStorageSnapshot.empty();
}

Widget localized(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);
PastedImage fixture(String name) => PastedImage(
  name: name,
  mimeType: 'image/png',
  bytes: base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNw27HwPwAFhgKfaRamBAAAAABJRU5ErkJggg==',
  ),
);

void main() {
  testWidgets(
    'settings keep the section when resizing, with one detail heading on compact web',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/main/settings?section=appearance',
        routes: [
          GoRoute(
            path: '/main/settings',
            builder: (_, state) => LayoutBuilder(
              builder: (_, size) => Row(
                children: [
                  if (size.maxWidth >= 840) const SizedBox(width: 89),
                  Expanded(
                    child: ProfileScreen(
                      initialSection:
                          state.uri.queryParameters['section'] == null
                          ? null
                          : SettingsSectionId.fromString(
                              state.uri.queryParameters['section'],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clientCapabilitiesProvider.overrideWithValue(
              const ClientCapabilities(
                isWeb: true,
                platform: TargetPlatform.windows,
              ),
            ),
            authProvider.overrideWith(_Auth.new),
            uiSettingsProvider.overrideWith(_Settings.new),
            storageSnapshotProvider.overrideWith(_Storage.new),
            settingsHealthProvider.overrideWithValue([]),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final firstError = tester.takeException();
      expect(firstError, isNull, reason: 'initial desktop layout');
      expect(
        find.byKey(const ValueKey('settings-master-pane')),
        findsOneWidget,
      );
      expect(find.byType(SettingsAppearanceScreen), findsOneWidget);
      tester.view.physicalSize = const Size(900, 700);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('settings-master-pane')),
        findsOneWidget,
      );
      final resizedError = tester.takeException();
      expect(resizedError, isNull, reason: 'resized settings layout');
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      expect(find.byKey(const ValueKey('settings-master-pane')), findsNothing);
      expect(find.byType(SettingsAppearanceScreen), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/main/settings',
      );
      expect(find.byType(SettingsAppearanceScreen), findsNothing);
      router.go('/main/settings?section=chats');
      await tester.pump();
      expect(find.byType(SettingsChatsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );
  testWidgets(
    'pasted image remains after a save failure and already queued images are not sent twice',
    (tester) async {
      final accepted = <String>[];
      var failSecond = true;
      await tester.pumpWidget(
        localized(
          PastedImagesDialog(
            images: [fixture('first.png'), fixture('second.png')],
            initialCaption: 'keep this caption',
            onSend: (image, caption) async {
              if (image.name == 'second.png' && failSecond) {
                throw StateError('save failed');
              }
              accepted.add('${image.name}:$caption');
            },
          ),
        ),
      );
      expect(accepted, isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Send'));
      await tester.pump();
      expect(accepted, ['first.png:keep this caption']);
      expect(find.byType(Image), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      failSecond = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Send'));
      await tester.pump();
      expect(accepted, ['first.png:keep this caption', 'second.png:']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    },
  );
}
