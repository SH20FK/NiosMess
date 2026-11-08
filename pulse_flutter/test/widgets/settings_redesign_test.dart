import 'dart:ui' as ui;
import 'package:universal_io/io.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/storage/local_storage_service.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/features/settings/application/settings_health_controller.dart';
import 'package:pulse_flutter/features/settings/domain/settings_issue.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/screens/profile_screen.dart';
import 'package:pulse_flutter/widgets/motion/m3_reveal.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    hydrated: true,
    session: AuthSession(
      accessToken: 'isolated-test',
      userId: 81,
      username: 'alex_demo',
      displayName: 'Александр',
    ),
    profile: ApiProfile(
      id: 81,
      username: 'alex_demo',
      displayName: 'Александр',
      bio: '',
    ),
    busy: false,
    pendingIdentifier: null,
    error: null,
  );
  @override
  Future<void> refreshProfile() async {}
}

class _Storage extends StorageSnapshotNotifier {
  @override
  Future<LocalStorageSnapshot> build() async =>
      const LocalStorageSnapshot.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const captureDir = String.fromEnvironment('NIOS_SETTINGS_CAPTURE_DIR');
  const iconFontPath = String.fromEnvironment('NIOS_SETTINGS_ICON_FONT');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> showSettings(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    Brightness brightness = Brightness.dark,
    String language = 'ru',
    double scale = 1,
    bool reducedMotion = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ProfileScreen()),
        GoRoute(
          path: '/settings/account',
          builder: (_, _) => const Scaffold(body: Text('Account destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    if (captureDir.isNotEmpty) {
      for (final family in ['Onest', 'GolosText', 'BricolageGrotesque']) {
        final asset = switch (family) {
          'Onest' => 'assets/fonts/onest/Onest-Variable.ttf',
          'GolosText' => 'assets/fonts/golos_text/GolosText-Variable.ttf',
          _ =>
            'assets/fonts/bricolage_grotesque/BricolageGrotesque-Variable.ttf',
        };
        await tester.runAsync(
          () => (FontLoader(family)..addFont(rootBundle.load(asset))).load(),
        );
      }
    }
    if (captureDir.isNotEmpty && iconFontPath.isNotEmpty) {
      await tester.runAsync(() async {
        final icons = ByteData.sublistView(
          await File(iconFontPath).readAsBytes(),
        );
        await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(icons))).load();
      });
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          storageSnapshotProvider.overrideWith(_Storage.new),
          settingsHealthProvider.overrideWithValue(
            const <SettingsHealthIssue>[],
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.themed(
            VisualThemeSettings(
              seedColor: const Color(0xffa8c7fa),
              themeMode: ThemeMode.dark,
              useSystemDynamic: false,
              predictiveBackEnabled: false,
            ),
            brightness,
          ),
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reducedMotion,
            ),
            child: RepaintBoundary(
              key: const ValueKey('settings-capture'),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (captureDir.isEmpty) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('settings-capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await Directory(captureDir).create(recursive: true);
      await File(
        '$captureDir/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('settings retain identity and navigation during scrolling', (
    tester,
  ) async {
    await showSettings(tester);
    expect(find.text('Александр'), findsWidgets);
    expect(tester.widget<PulseAvatar>(find.byType(PulseAvatar)).radius, 52);
    await capture(tester, 'settings-dark-expanded');
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.widget<PulseAvatar>(find.byType(PulseAvatar)).radius, 52);
    final avatarTarget = find
        .ancestor(of: find.byType(PulseAvatar), matching: find.byType(InkWell))
        .first;
    expect(tester.getSize(avatarTarget).width, greaterThanOrEqualTo(48));
    await capture(tester, 'settings-dark-collapsed');
  });

  testWidgets('reduced motion reveal has no hidden animation ticker', (
    tester,
  ) async {
    var revealed = false;
    var reduced = true;
    late StateSetter change;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, update) {
            change = update;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: M3Reveal(
                revealed: revealed,
                child: const Text('Revealed content'),
              ),
            );
          },
        ),
      ),
    );
    change(() => revealed = true);
    await tester.pump();
    expect(find.text('Revealed content'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    change(() {
      revealed = false;
      reduced = false;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    change(() => reduced = true);
    await tester.pump();
    expect(find.text('Revealed content'), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['ru', 'en']) {
    for (final brightness in Brightness.values) {
      testWidgets('settings fit 320dp 200% $language $brightness', (
        tester,
      ) async {
        await showSettings(
          tester,
          size: const Size(320, 800),
          brightness: brightness,
          language: language,
          scale: 2,
          reducedMotion: true,
        );
        expect(tester.takeException(), isNull);
        await capture(tester, 'settings-${brightness.name}-$language-large');
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -480),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
