import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';

import 'core/app_router.dart';
import 'core/theme.dart';
import 'core/theme_provider.dart';
import 'core/settings_provider.dart';
import 'core/app_lock_provider.dart';
import 'core/data_usage_provider.dart';
import 'core/send_queue_provider.dart';
import 'core/window_state_persistence.dart';
import 'firebase_options.dart';
import 'features/auth/pin_lock_screen.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details);
      if (details.stack != null) {
        print('[FlutterError] ${details.exception}\n${details.stack}');
      }
    };
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      print('[Uncaught] $error\n$stack');
      return true;
    };

    final isolateErrors = ReceivePort();
    Isolate.current.addErrorListener(isolateErrors.sendPort);
    isolateErrors.listen((dynamic message) {
      try {
        if (message is List && message.length >= 2) {
          print('[IsolateError] ${message[0]}');
          print(message[1]);
        } else {
          print('[IsolateError] $message');
        }
      } catch (_) {}
    });

    await _repairSharedPrefsIfCorrupted();

  // Инициализация Firebase в фоне без блокировки запуска
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    // Игнорируем ошибки Firebase при старте - приложение продолжит работу
    debugPrint('Firebase initialization error: $error');
  }

  if (Platform.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (_) {}
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    const WindowOptions windowOptions = WindowOptions(
      size: Size(1280, 800),
      center: true,
      // Solid dark background — transparent causes a black hole on Windows when maximized
      backgroundColor: Color(0xFF17212B),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'NiosMess',
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setMinimumSize(const Size(900, 600));
      await windowManager.show();
      await windowManager.focus();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WindowStatePersistence.restore();
    });
  }

    runApp(const ProviderScope(child: NiosMessApp()));
  }, (error, stack) {
    final stackStr = stack.toString();
    if (stackStr.trim().isEmpty) {
      print('[ZoneError] $error\n${StackTrace.current}');
    } else {
      print('[ZoneError] $error\n$stack');
    }
  });
}

Future<void> _repairSharedPrefsIfCorrupted() async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'shared_preferences.json'));
    if (!await file.exists()) return;
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return;
    try {
      json.decode(raw);
    } catch (_) {
      final backup = File('${file.path}.bad_${DateTime.now().millisecondsSinceEpoch}');
      await file.copy(backup.path);
      await file.writeAsString('{}');
      print('[PrefsRepair] Corrupted prefs fixed. Backup: ${backup.path}');
    }
  } catch (e, st) {
    print('[PrefsRepair] Failed to repair prefs: $e\n$st');
  }
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
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('ru', 'RU')],
              locale: const Locale('ru', 'RU'),

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
