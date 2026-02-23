import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'core/app_router.dart';
import 'core/theme.dart';
import 'core/utils/error_handler.dart';
import 'core/theme_provider.dart';
import 'core/settings_provider.dart';
import 'core/app_lock_provider.dart';
import 'core/data_usage_provider.dart';
import 'core/send_queue_provider.dart';
import 'core/l10n/app_localizations.dart';
import 'firebase_options.dart';
import 'features/auth/pin_lock_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (Platform.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (_) {}
  }

  // Force full immersive mode - remove ugly top/bottom system bars
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));

  runApp(const ProviderScope(child: NiosMessApp()));
}

class NiosMessApp extends StatelessWidget {
  const NiosMessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final theme = ref.watch(themeProvider);
        final settings = ref.watch(settingsProvider);
        // Initialize providers without causing MaterialApp rebuilds
        ref.read(dataUsageProvider);
        ref.read(sendQueueProvider);
        final textScale = (settings['text_scale'] as num?)?.toDouble() ?? 1.0;

        return DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            return MaterialApp(
              title: 'NiosMess',

              // Локализация
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('ru', 'RU'), // По умолчанию русский

              // Темы с улучшенным дизайном
              theme: buildNiosTheme(
                theme,
                Brightness.light,
                dynamicScheme: theme.useDynamicColor ? lightDynamic : null,
              ),
              darkTheme: buildNiosTheme(
                theme,
                Brightness.dark,
                dynamicScheme: theme.useDynamicColor ? darkDynamic : null,
              ),
              themeMode: theme.mode,

              // Масштабирование текста
              builder: (context, child) {
                final media = MediaQuery.of(context);
                return MediaQuery(
                  data: media.copyWith(
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: child ?? const SizedBox.shrink(),
                );
              },

              home: const AppLockGate(child: AppRouter()),
              debugShowCheckedModeBanner: false,
            );
          },
        );
      },
    );
  }
}

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(appLockProvider.notifier);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      lock.lock();
    }
    if (state == AppLifecycleState.resumed) {
      final current = ref.read(appLockProvider);
      if (current.isEnabled &&
          current.biometricEnabled &&
          !current.isUnlocked) {
        lock.unlockWithBiometrics();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockProvider);
    if (lock.isEnabled && !lock.isUnlocked) {
      return const PinLockScreen();
    }
    return widget.child;
  }
}
