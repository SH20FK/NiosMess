import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/services/protocol/nios_protocol_licenses.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/diagnostics/app_logger.dart';
import 'package:pulse_flutter/core/utils/app_time.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/router/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/core/storage/hive_bootstrap.dart';
import 'package:pulse_flutter/core/storage/encrypted_message_cache.dart';
import 'package:pulse_flutter/core/storage/chat_media_cache.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/core/services/background_service.dart';
import 'package:pulse_flutter/core/services/deep_link_service.dart';
import 'package:pulse_flutter/core/services/desktop_window_service.dart';
import 'package:pulse_flutter/firebase_options.dart';
import 'package:pulse_flutter/providers/call_incoming_provider.dart';
import 'package:pulse_flutter/providers/call_push_handler.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/repositories/call_repository.dart';
import 'package:pulse_flutter/services/calls/call_starter.dart';
import 'package:pulse_flutter/widgets/calls/call_overlay.dart';
import 'package:pulse_flutter/screens/calls/incoming_call_overlay.dart';
import 'package:pulse_flutter/widgets/notifications/in_app_notification_banner.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/widgets/circular_theme_reveal.dart';
import 'package:pulse_flutter/features/security/application/app_lock_controller.dart';
import 'package:pulse_flutter/features/security/presentation/app_lock_gate.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      registerNiosProtocolLicenses();
      final AppLogger logger = AppLogger.instance;
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        logger.flutterError(details);
        debugPrint('FLUTTER_ERROR_EXCEPTION: ${details.exception}');
        debugPrint('FLUTTER_ERROR_STACK: ${details.stack}');
      };
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        logger.error(error, stack, source: 'platform');
        debugPrint('PLATFORM_ERROR: $error\n$stack');
        return true;
      };

      // Register the native background entry point before yielding bootstrap.
      // Plugin initialization and permission UX run after the first screen.
      if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
        PushNotificationService.prepareDeferredFirebase();
      }
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        PushNotificationService.registerBackgroundHandler();
      }
      late final SharedPreferences sharedPrefs;
      await Future.wait(<Future<void>>[
        (() async {
          await HiveBootstrap.ensureInitialized();
          await Future.wait(<Future<void>>[
            const CacheService().ensureInitialized(),
            EncryptedMessageCache.ensureInitialized(),
            ChatMediaCache.ensureInitialized(),
          ]);
        })(),
        SharedPreferences.getInstance().then((SharedPreferences p) {
          sharedPrefs = p;
        }),
      ]);
      UiSettingsNotifier.cachedPrefs = sharedPrefs;
      AppTimeSettings.initialize();
      if (!kIsWeb) BackgroundService.init();
      logger.info('Application started', source: 'bootstrap');
      runApp(const ProviderScope(child: PulseApp()));
    },
    (Object error, StackTrace stack) {
      AppLogger.instance.error(error, stack, source: 'zone');
    },
  );
}

class PulseApp extends ConsumerStatefulWidget {
  const PulseApp({super.key});

  @override
  ConsumerState<PulseApp> createState() => _PulseAppState();
}

class _PulseAppState extends ConsumerState<PulseApp> {
  late final AppLifecycleListener _lifecycleListener;
  String? _lastConfiguredLocale;
  AppTimeZoneMode? _lastTimeZoneMode;
  String? _lastTimeZoneId;
  bool _acceptingNotificationCall = false;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        try {
          ref.read(appLockProvider.notifier).onAppResumed();
        } catch (_) {}
        try {
          ref.read(webSocketClientProvider).reconnectNow();
        } catch (_) {}
        try {
          if (ref.read(authProvider).isAuthenticated) {
            ref.read(chatsProvider.notifier).refresh();
          }
        } catch (_) {}
        try {
          if (ref.read(authProvider).isAuthenticated) {
            ref.read(authProvider.notifier).refreshFcmTokenRegistration();
          }
        } catch (_) {}
      },
      onPause: () {
        try {
          ref.read(appLockProvider.notifier).onAppBackgrounded();
        } catch (_) {}
        ref.read(uiSettingsProvider.notifier).flushPersist();
      },
      onHide: () {
        try {
          ref.read(appLockProvider.notifier).onAppBackgrounded();
        } catch (_) {}
      },
      onInactive: () {
        try {
          ref.read(appLockProvider.notifier).onAppBackgrounded();
        } catch (_) {}
      },
      onDetach: () {
        ref.read(uiSettingsProvider.notifier).flushPersist();
      },
    );

    PushNotificationService.onCallAccepted = (Map<String, dynamic> data) async {
      if (_acceptingNotificationCall ||
          (ref.read(callSessionProvider)?.isActive ?? false)) {
        return;
      }
      final int? chatId = int.tryParse(data['chat_id']?.toString() ?? '');
      final int? callId = int.tryParse(
        data['call_id']?.toString() ?? data['message_id']?.toString() ?? '',
      );
      final String? roomId = data['room_id']?.toString();
      final bool isVideo =
          data['is_video'] == true ||
          data['is_video'] == 'true' ||
          data['is_video'] == 1 ||
          data['is_video'] == '1';
      final String? callerName = data['caller_nickname']?.toString();

      if (chatId != null && callId != null && roomId != null) {
        _acceptingNotificationCall = true;
        ref.read(incomingCallProvider.notifier).set(null);
        try {
          await startIncomingCall(
            ref: ref,
            chatId: chatId,
            callId: callId,
            roomId: roomId,
            isVideo: isVideo,
            peerName: callerName,
          );
          if (mounted && (ref.read(callSessionProvider)?.isActive ?? false)) {
            AppRouter.navigatorKey.currentContext?.push('/call/$callId');
          }
        } catch (_) {
          final context = AppRouter.navigatorKey.currentContext;
          if (mounted && context != null && context.mounted) {
            AppToast.showError(
              context,
              context.l10n.callFailureMessage('connection_failed'),
            );
          }
        } finally {
          _acceptingNotificationCall = false;
        }
      }
    };

    PushNotificationService.onCallDeclined = (Map<String, dynamic> data) {
      final int? chatId = int.tryParse(data['chat_id']?.toString() ?? '');
      final String? roomId = data['room_id']?.toString();
      final int? callId = int.tryParse(
        data['call_id']?.toString() ?? data['message_id']?.toString() ?? '',
      );
      if (chatId != null && roomId != null) {
        ref.read(incomingCallProvider.notifier).set(null);
        unawaited(
          ref
              .read(callRepositoryProvider)
              .decline(chatId: chatId, roomId: roomId, messageId: callId ?? 0),
        );
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_initializeDeferredServices());
    });
  }

  Future<void> _initializeDeferredServices() async {
    Future<void> guarded(String source, Future<void> Function() action) async {
      try {
        await action();
      } catch (error, stack) {
        AppLogger.instance.error(error, stack, source: source);
      }
    }

    await Future.wait(<Future<void>>[
      if (!kIsWeb) guarded('deep_links', DeepLinkService.init),
      if (DesktopWindowService.isDesktop)
        guarded('desktop_window', DesktopWindowService.instance.initialize),
      if (kIsWeb || Platform.isAndroid || Platform.isIOS)
        guarded('firebase', () async {
          try {
            await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform,
            );
          } finally {
            // Auth's token request and the shell's permission UX may already
            // be waiting. Release both even on failure so their normal error
            // handling can run instead of leaving startup futures pending.
            PushNotificationService.finishDeferredFirebase();
          }
          await PushNotificationService.init();
          if (!mounted) return;
          if (!ref.read(authProvider).hydrated) {
            final hydrated = Completer<void>();
            final subscription = ref.listenManual(
              authProvider.select((state) => state.hydrated),
              (_, ready) {
                if (ready && !hydrated.isCompleted) hydrated.complete();
              },
              fireImmediately: true,
            );
            await hydrated.future;
            subscription.close();
          }
          if (!mounted) return;
          // The first frame may have passed before getInitialMessage completes.
          // Consume it only now, after router/call listeners have mounted.
          ref.read(callPushHandlerProvider);
          PushNotificationService.checkAndHandlePendingNotification();
          if (ref.read(authProvider).isAuthenticated) {
            await ref.read(authProvider.notifier).refreshFcmTokenRegistration();
          }
        }),
    ]);
  }

  @override
  void dispose() {
    PushNotificationService.onCallAccepted = null;
    PushNotificationService.onCallDeclined = null;
    _lifecycleListener.dispose();
    super.dispose();
  }

  void _syncTimeSettings(
    String effectiveLocaleCode,
    AppTimeZoneMode timeZoneMode,
    String? timeZoneId,
  ) {
    if (_lastConfiguredLocale != effectiveLocaleCode ||
        _lastTimeZoneMode != timeZoneMode ||
        _lastTimeZoneId != timeZoneId) {
      _lastConfiguredLocale = effectiveLocaleCode;
      _lastTimeZoneMode = timeZoneMode;
      _lastTimeZoneId = timeZoneId;
      AppTimeSettings.configure(
        localeCode: effectiveLocaleCode,
        timeZoneMode: timeZoneMode,
        timeZoneId: timeZoneId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeMode themeMode = ref.watch(
      uiSettingsProvider.select((s) => s.themeMode),
    );
    final String? localeCode = ref.watch(
      uiSettingsProvider.select((s) => s.localeCode),
    );
    final AppTimeZoneMode timeZoneMode = ref.watch(
      uiSettingsProvider.select((s) => s.timeZoneMode),
    );
    final String? timeZoneId = ref.watch(
      uiSettingsProvider.select((s) => s.timeZoneId),
    );
    final AppFontScale fontScale = ref.watch(
      uiSettingsProvider.select((s) => s.fontScale),
    );
    final bool showPerformanceOverlay = ref.watch(
      uiSettingsProvider.select((s) => s.showPerformanceOverlay),
    );
    final VisualThemeSettings visualTheme = ref.watch(
      uiSettingsProvider.select((s) => s.visualTheme),
    );
    final GoRouter router = ref.watch(appRouterProvider);
    ref.watch(callPushHandlerProvider);
    ref.watch(secretChatCoordinatorProvider);
    final String systemLanguageCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final String normalized = (localeCode ?? '').trim().toLowerCase();
    final String effectiveLocaleCode =
        (normalized == 'ru' || normalized == 'en')
        ? normalized
        : systemLanguageCode.toLowerCase().startsWith('ru')
        ? 'ru'
        : 'en';
    final Locale? appLocale = localeCode == null
        ? null
        : Locale(effectiveLocaleCode);

    _syncTimeSettings(effectiveLocaleCode, timeZoneMode, timeZoneId);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final bool isHighContrast = WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .highContrast;
        final double contrastLevel = isHighContrast ? 1.0 : 0.0;
        return MaterialApp.router(
          title: 'NiosMess',
          themeAnimationDuration:
              WidgetsBinding
                  .instance
                  .platformDispatcher
                  .accessibilityFeatures
                  .disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 500),
          themeAnimationCurve: M3SpringCurves.expressiveStandard,
          debugShowCheckedModeBanner: false,
          showPerformanceOverlay: showPerformanceOverlay,
          scrollBehavior: const AppScrollBehavior(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: appLocale,
          theme: AppTheme.themed(
            visualTheme,
            Brightness.light,
            dynamicScheme: lightDynamic,
            contrastLevel: contrastLevel,
          ),
          darkTheme: AppTheme.themed(
            visualTheme,
            Brightness.dark,
            dynamicScheme: darkDynamic,
            contrastLevel: contrastLevel,
          ),
          themeMode: themeMode,
          routerConfig: router,
          builder: (BuildContext context, Widget? child) {
            return CircularThemeSwitcher(
              child: Builder(
                builder: (BuildContext innerContext) {
                  final mediaQuery = MediaQuery.of(
                    innerContext,
                  ).copyWith(textScaler: TextScaler.linear(fontScale.scale));
                  return MediaQuery(
                    data: mediaQuery,
                    child: AppLockGate(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          SizedBox.expand(
                            child: child ?? const SizedBox.shrink(),
                          ),
                          Consumer(
                            builder: (BuildContext context, WidgetRef ref, _) =>
                                ref.watch(incomingCallProvider) == null
                                ? const SizedBox.shrink()
                                : const IncomingCallOverlay(),
                          ),
                          const CallOverlay(),
                          const InAppNotificationBannerOverlay(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    if (kIsWeb) {
      return const ClampingScrollPhysics(
        parent: RangeMaintainingScrollPhysics(),
      );
    }
    final TargetPlatform platform = Theme.of(context).platform;
    switch (platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
    }
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (kIsWeb && details.controller != null) {
      return RawScrollbar(
        controller: details.controller,
        thumbVisibility: false,
        thickness: 5,
        radius: const Radius.circular(3),
        fadeDuration: const Duration(milliseconds: 300),
        timeToFade: const Duration(milliseconds: 900),
        child: child,
      );
    }
    return child;
  }
}
