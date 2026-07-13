import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    final ThemeMode themeMode =
        ref.watch(uiSettingsProvider.select((s) => s.themeMode));
    final Color seedColor =
        ref.watch(uiSettingsProvider.select((s) => s.seedColor));
    final String? localeCode =
        ref.watch(uiSettingsProvider.select((s) => s.localeCode));
    final AppTimeZoneMode timeZoneMode =
        ref.watch(uiSettingsProvider.select((s) => s.timeZoneMode));
    final String? timeZoneId =
        ref.watch(uiSettingsProvider.select((s) => s.timeZoneId));
    final bool useSystemDynamic =
        ref.watch(uiSettingsProvider.select((s) => s.useSystemDynamic));
    final AppFontScale fontScale =
        ref.watch(uiSettingsProvider.select((s) => s.fontScale));
    final AsyncValue<Color?> systemAccent =
        ref.watch(systemAccentColorProvider);
    final Color effectiveSeed = (useSystemDynamic &&
            systemAccent.hasValue &&
            systemAccent.value != null)
        ? systemAccent.value!
        : seedColor;
    final UiSettingsState themeSettings = effectiveSeed == seedColor
        ? ref.read(uiSettingsProvider)
        : ref.read(uiSettingsProvider).copyWith(seedColor: effectiveSeed);
    final GoRouter router = ref.watch(appRouterProvider);
    final String systemLanguageCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final String normalized = (localeCode ?? '').trim().toLowerCase();
    final String effectiveLocaleCode =
        (normalized == 'ru' || normalized == 'en')
            ? normalized
            : systemLanguageCode.toLowerCase().startsWith('ru')
                ? 'ru'
                : 'en';
    final Locale? appLocale =
        localeCode == null ? null : Locale(effectiveLocaleCode);

    AppTimeSettings.configure(
      localeCode: effectiveLocaleCode,
      timeZoneMode: timeZoneMode,
      timeZoneId: timeZoneId,
    );

    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) => context.l10n.appName,
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: false,
      locale: appLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.themed(themeSettings, Brightness.light),
      darkTheme: AppTheme.themed(themeSettings, Brightness.dark),
      themeMode: themeMode,
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        final mediaQuery = MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(fontScale.scale),
        );
        return MediaQuery(data: mediaQuery, child: child ?? const SizedBox.shrink());
      },
    );
  }
}
