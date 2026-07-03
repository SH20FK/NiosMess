import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pulse_flutter/core/diagnostics/app_logger.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_time.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/router/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/core/storage/encrypted_message_cache.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/core/services/background_service.dart';
import 'package:pulse_flutter/core/services/deep_link_service.dart';
import 'package:pulse_flutter/firebase_options.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await const CacheService().ensureInitialized();
      await EncryptedMessageCache.ensureInitialized();
      final AppLogger logger = AppLogger.instance;
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        logger.flutterError(details);
      };
      PlatformDispatcher.instance.onError = (
        Object error,
        StackTrace stack,
      ) {
        logger.error(error, stack, source: 'platform');
        return true;
      };

      await SharedPreferences.getInstance();
      AppTimeSettings.initialize();
      if (!kIsWeb) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        await PushNotificationService.init();
        await DeepLinkService.init();
        BackgroundService.init();
      }
      logger.info('Application started', source: 'bootstrap');
      runApp(const ProviderScope(child: PulseApp()));
    },
    (Object error, StackTrace stack) {
      AppLogger.instance.error(error, stack, source: 'zone');
    },
  );
}

class PulseApp extends ConsumerWidget {
  const PulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final GoRouter router = ref.watch(appRouterProvider);
    final String systemLanguageCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final String localeCode = settings.effectiveLocaleCode(systemLanguageCode);
    final Locale? appLocale = settings.localeCode == null
        ? null
        : Locale(localeCode);

    AppTimeSettings.configure(
      localeCode: localeCode,
      timeZoneMode: settings.timeZoneMode,
      timeZoneId: settings.timeZoneId,
    );

    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) => context.l10n.appName,
      debugShowCheckedModeBanner: false,
      locale: appLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.themed(settings, Brightness.light),
      darkTheme: AppTheme.themed(settings, Brightness.dark),
      themeMode: settings.themeMode,
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        return Shortcuts(
          shortcuts: <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (DismissIntent intent) {
                  if (router.canPop()) {
                    router.pop();
                    return true;
                  }
                  final String currentPath = router.routerDelegate.currentConfiguration.uri.path;
                  if (currentPath != '/main/chats' && currentPath != '/') {
                    router.go('/main/chats');
                    return true;
                  }
                  return false;
                },
              ),
            },
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
