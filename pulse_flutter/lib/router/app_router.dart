import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/motion/circular_reveal_transition.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/screens/chat_detail_screen.dart';
import 'package:pulse_flutter/screens/chat_manage_screen.dart';
import 'package:pulse_flutter/screens/chat_members_screen.dart';
import 'package:pulse_flutter/screens/direct_chat_resolver_screen.dart';
import 'package:pulse_flutter/screens/create_chat_screen.dart';
import 'package:pulse_flutter/screens/e2ee_settings_screen.dart';
import 'package:pulse_flutter/screens/join_chat_screen.dart';
import 'package:pulse_flutter/screens/login_screen.dart';
import 'package:pulse_flutter/screens/main_shell_screen.dart';
import 'package:pulse_flutter/screens/media_viewer_screen.dart';
import 'package:pulse_flutter/screens/create_post_screen.dart';
import 'package:pulse_flutter/screens/group_profile_screen.dart';
import 'package:pulse_flutter/screens/onboarding_screen.dart';
import 'package:pulse_flutter/screens/post_comments_screen.dart';
import 'package:pulse_flutter/screens/public_profile_screen.dart';
import 'package:pulse_flutter/screens/sticker_set_screen.dart';
import 'package:pulse_flutter/screens/sessions_screen.dart';
import 'package:pulse_flutter/screens/settings_account_screen.dart';
import 'package:pulse_flutter/screens/settings_about_screen.dart';
import 'package:pulse_flutter/screens/help_faq_screen.dart';
import 'package:pulse_flutter/screens/settings_system_device_screen.dart';
import 'package:pulse_flutter/screens/legal_viewer_screen.dart';
import 'package:pulse_flutter/screens/native_file_viewer_screen.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/screens/settings_appearance_screen.dart';
import 'package:pulse_flutter/screens/settings_language_region_screen.dart';
import 'package:pulse_flutter/screens/settings_preferences_screen.dart';
import 'package:pulse_flutter/screens/settings_privacy_screen.dart';
import 'package:pulse_flutter/screens/privacy_rule_detail_screen.dart';
import 'package:pulse_flutter/screens/blocked_users_screen.dart';
import 'package:pulse_flutter/screens/settings_storage_screen.dart';
import 'package:pulse_flutter/screens/splash_screen.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/screens/settings_wallpaper_screen.dart';
import 'package:pulse_flutter/screens/settings_chats_screen.dart';
import 'package:pulse_flutter/screens/calls/active_call_screen.dart';
import 'package:pulse_flutter/screens/calls/outgoing_call_screen.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}

Page<void> _page(GoRouterState state, Widget child, {LocalKey? pageKey}) {
  return MaterialPage<void>(
    key: pageKey ?? state.pageKey,
    child: child,
  );
}

Page<void> _m3eEntryPage(GoRouterState state, Widget child, {LocalKey? pageKey}) {
  return CustomTransitionPage<void>(
    key: pageKey ?? state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: M3SpringCurves.spatial,
      );
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.7, curve: Curves.linear),
        ),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}

Page<void> _chatDetailPage(GoRouterState state, Widget child, {LocalKey? pageKey}) {
  final Object? extra = state.extra;
  final Offset? tapOffset = extra is Offset ? extra : null;

  if (tapOffset == null) {
    return _m3eEntryPage(state, child, pageKey: pageKey);
  }

  return CustomTransitionPage<void>(
    key: pageKey ?? state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return CircularRevealTransition(
        animation: animation,
        center: tapOffset,
        child: child,
      );
    },
  );
}

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final ValueNotifier<int> refreshListenable = ValueNotifier<int>(0);
  ref.onDispose(refreshListenable.dispose);

  ref.listen(authProvider, (AuthState? previous, AuthState next) {
    if (previous?.isAuthenticated != next.isAuthenticated ||
        previous?.hydrated != next.hydrated) {
      refreshListenable.value++;
    }
  });

  String? savedDeepLink;

  return GoRouter(
    navigatorKey: AppRouter.navigatorKey,
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (BuildContext context, GoRouterState state) {
      final AuthState authState = ref.read(authProvider);
      if (!authState.hydrated) return null;
      final bool isAuth = authState.isAuthenticated;
      final String path = state.uri.path;

      final bool isPublic = path == '/' ||
          path == '/web' ||
          path == '/login' ||
          path == '/onboarding' ||
          path.startsWith('/legal');

      if (!isAuth && !isPublic) {
        // Save the intended deep link so we can resume it after login (РОУТ-3)
        savedDeepLink = state.uri.toString();
        return '/login';
      }
      if (isAuth) {
        if (savedDeepLink != null && savedDeepLink!.isNotEmpty) {
          final String target = savedDeepLink!;
          savedDeepLink = null;
          return target;
        }
        if (path == '/login' || path == '/web' || path == '/onboarding') {
          return '/main/chats';
        }
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _m3eEntryPage(state, const SplashScreen()),
      ),
      GoRoute(
        path: '/web',
        pageBuilder: (context, state) => _m3eEntryPage(
          state,
          LoginScreen(
            initialCode: state.uri.queryParameters['code'],
            initialState: state.uri.queryParameters['state'],
            initialError: state.uri.queryParameters['error'],
            initialErrorDescription: state.uri.queryParameters['error_description'],
          ),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _m3eEntryPage(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _m3eEntryPage(
          state,
          LoginScreen(
            initialCode: state.uri.queryParameters['code'],
            initialState: state.uri.queryParameters['state'],
            initialError: state.uri.queryParameters['error'],
            initialErrorDescription: state.uri.queryParameters['error_description'],
          ),
        ),
      ),
      GoRoute(
        path: '/main/:tab',
        pageBuilder: (context, state) => _page(state, MainShellScreen(tab: state.pathParameters['tab'] ?? 'chats'), pageKey: const ValueKey<String>('main-shell')),
      ),
      GoRoute(
        path: '/chat/create',
        pageBuilder: (context, state) => _page(state, CreateChatScreen(initialType: state.uri.queryParameters['type'])),
      ),
      GoRoute(
        path: '/join',
        pageBuilder: (context, state) => _page(state, JoinChatScreen(initialSlug: state.uri.queryParameters['slug'])),
      ),
      GoRoute(
        path: '/join/:slug',
        redirect: (context, state) => '/join?slug=${state.pathParameters['slug']}',
      ),
      GoRoute(
        path: '/c/:slug',
        redirect: (context, state) => '/u/${state.pathParameters['slug']}',
      ),
      GoRoute(
        path: '/chat/:chatId',
        pageBuilder: (context, state) => _chatDetailPage(
          state,
          ChatDetailScreen(
            chatId: state.pathParameters['chatId']!,
            highlightMessageId: int.tryParse(state.uri.queryParameters['highlight'] ?? ''),
          ),
          pageKey: state.pageKey,
        ),
      ),
      GoRoute(
        path: '/chat/dm/:username',
        pageBuilder: (context, state) => _page(
          state,
          DirectChatResolverScreen(username: state.pathParameters['username']!),
          pageKey: state.pageKey,
        ),
      ),
      GoRoute(
        path: '/chat/support',
        redirect: (context, state) => '/chat/dm/support',
      ),
      GoRoute(
        path: '/media-viewer',
        pageBuilder: (context, state) {
          final String url = Uri.decodeComponent(state.uri.queryParameters['url'] ?? '');
          final String typeRaw = state.uri.queryParameters['type'] ?? '';
          final MediaType mediaType = typeRaw == 'image'
              ? MediaType.image
              : typeRaw == 'video'
                  ? MediaType.video
                  : MediaType.other;
          final Object? extra = state.extra;
          List<MediaViewerItem>? playlist;
          int initialIndex = 0;
          String? e2eeKey;

          if (extra is String) {
            e2eeKey = extra;
          } else if (extra is Map<String, dynamic>) {
            e2eeKey = extra['e2eeKey'] as String?;
            playlist = extra['playlist'] as List<MediaViewerItem>?;
            initialIndex = (extra['initialIndex'] as int?) ?? 0;
          }

          return CustomTransitionPage<void>(
            key: state.pageKey,
            opaque: false,
            barrierColor: Colors.transparent,
            transitionDuration: const Duration(milliseconds: 250),
            reverseTransitionDuration: const Duration(milliseconds: 200),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: MediaViewerScreen(
              url: url,
              title: Uri.decodeComponent(state.uri.queryParameters['title'] ?? 'Attachment'),
              mediaType: mediaType,
              e2eeFileKey: e2eeKey,
              playlist: playlist,
              initialIndex: initialIndex,
            ),
          );
        },
      ),
      GoRoute(
        path: '/channel/:channelId/post/:postId/comments',
        pageBuilder: (context, state) => _page(state, PostCommentsScreen(channelId: int.tryParse(state.pathParameters['channelId'] ?? '') ?? 0, postId: int.tryParse(state.pathParameters['postId'] ?? '') ?? 0)),
      ),
      GoRoute(
        path: '/chat/:chatId/members',
        pageBuilder: (context, state) => _page(state, ChatMembersScreen(chatId: int.tryParse(state.pathParameters['chatId'] ?? '') ?? 0)),
      ),
      GoRoute(
        path: '/chat/:chatId/manage',
        pageBuilder: (context, state) => _page(state, ChatManageScreen(chatId: int.tryParse(state.pathParameters['chatId'] ?? '') ?? 0)),
      ),
      GoRoute(
        path: '/chat/:chatId/profile',
        pageBuilder: (context, state) => _page(state, GroupProfileScreen(chatId: int.tryParse(state.pathParameters['chatId'] ?? '') ?? 0)),
      ),
      GoRoute(
        path: '/profile/:username',
        pageBuilder: (context, state) => _page(state, PublicProfileScreen(username: state.pathParameters['username']!)),
      ),
      GoRoute(
        path: '/g/:username',
        pageBuilder: (context, state) => _page(
          state,
          PublicProfileScreen(
            username: state.pathParameters['username']!,
          ),
        ),
      ),
      GoRoute(
        path: '/u/:slug',
        redirect: (context, state) {
          final String slug = state.pathParameters['slug'] ?? '';
          if (slug.startsWith('+')) {
            return '/join?slug=${Uri.encodeComponent(slug)}';
          }
          final String cleanSlug = slug.startsWith('@') ? slug.substring(1) : slug;
          return '/profile/$cleanSlug';
        },
      ),
      GoRoute(
        path: '/stickers/:setId',
        pageBuilder: (context, state) => _page(
          state,
          StickerSetScreen(
            setId: int.tryParse(state.pathParameters['setId'] ?? '') ?? 0,
          ),
        ),
      ),
      GoRoute(
        path: '/contact/:username',
        redirect: (context, state) =>
            '/profile/${state.pathParameters['username']}',
      ),
      GoRoute(
        path: '/settings',
        redirect: (context, state) {
          final String? section = state.uri.queryParameters['section'];
          return section != null
              ? '/main/profile?section=$section'
              : '/main/profile';
        },
      ),
      GoRoute(
        path: '/settings/appearance',
        pageBuilder: (context, state) => _page(state, const SettingsAppearanceScreen(), pageKey: state.pageKey),
      ),
      GoRoute(
        path: '/settings/chats',
        pageBuilder: (context, state) => _page(state, const SettingsChatsScreen(), pageKey: state.pageKey),
      ),
      GoRoute(
        path: '/settings/wallpaper',
        pageBuilder: (context, state) => _page(
          state,
          SettingsWallpaperScreen(
            chatId: state.uri.queryParameters['chatId'],
            chatTitle: state.uri.queryParameters['chatTitle'],
          ),
          pageKey: state.pageKey,
        ),
      ),
      GoRoute(
        path: '/settings/language-region',
        pageBuilder: (context, state) => _page(state, const SettingsLanguageRegionScreen(), pageKey: state.pageKey),
      ),
      GoRoute(
        path: '/settings/account',
        pageBuilder: (context, state) => _page(state, const SettingsAccountScreen(), pageKey: state.pageKey),
      ),
      GoRoute(
        path: '/settings/privacy',
        pageBuilder: (context, state) => _page(state, const SettingsPrivacyScreen(), pageKey: state.pageKey),
      ),
      GoRoute(
        path: '/settings/privacy/rule/:key',
        pageBuilder: (context, state) => _page(
          state,
          PrivacyRuleDetailScreen(ruleKey: state.pathParameters['key']!),
          pageKey: state.pageKey,
        ),
      ),
      GoRoute(
        path: '/settings/privacy/blocked-users',
        pageBuilder: (context, state) => _page(
          state,
          const BlockedUsersScreen(),
          pageKey: state.pageKey,
        ),
      ),
      GoRoute(
        path: '/settings/storage',
        pageBuilder: (context, state) => _page(state, const SettingsStorageScreen(), pageKey: state.pageKey),
      ),
      GoRoute(
        path: '/settings/about',
        pageBuilder: (context, state) => _page(state, const SettingsAboutScreen(), pageKey: state.pageKey),
      ),
      GoRoute(
        path: '/help/faq',
        pageBuilder: (context, state) => _page(state, const HelpFaqScreen(), pageKey: state.pageKey),
      ),
      GoRoute(
        path: '/settings/system-device',
        redirect: (BuildContext context, GoRouterState state) {
          if (kIsWeb) return '/settings/about';
          return null;
        },
        pageBuilder: (context, state) => _page(state, const SettingsSystemDeviceScreen(), pageKey: state.pageKey),
      ),
      GoRoute(
        path: '/settings/e2ee',
        pageBuilder: (context, state) => _page(state, const E2eeSettingsScreen(), pageKey: state.pageKey),
      ),
      GoRoute(
        path: '/settings/preferences',
        pageBuilder: (context, state) => _page(state, const SettingsPreferencesScreen(), pageKey: state.pageKey),
      ),
      GoRoute(
        path: '/settings/sessions',
        pageBuilder: (context, state) => _page(state, const SessionsScreen(), pageKey: state.pageKey),
      ),
      GoRoute(
        path: '/legal/privacy',
        pageBuilder: (context, state) => _page(state, const LegalViewerScreen(docType: LegalDocType.privacy), pageKey: state.pageKey),
      ),
      GoRoute(
        path: '/legal/tos',
        pageBuilder: (context, state) => _page(state, const LegalViewerScreen(docType: LegalDocType.tos), pageKey: state.pageKey),
      ),
      GoRoute(
        path: '/legal/terms',
        pageBuilder: (context, state) => _page(state, const LegalViewerScreen(docType: LegalDocType.tos), pageKey: state.pageKey),
      ),
      GoRoute(
        path: '/legal/consent',
        pageBuilder: (context, state) => _page(state, const LegalViewerScreen(docType: LegalDocType.consent), pageKey: state.pageKey),
      ),
      GoRoute(
        path: '/file-viewer',
        pageBuilder: (context, state) {
          final url = state.uri.queryParameters['url'];
          final localPath = state.uri.queryParameters['path'];
          final fileName = state.uri.queryParameters['name'] ?? '';
          final fileType = FileTypeDetector.detect(fileName: fileName);
          final Object? extra = state.extra;
          Uint8List? bytes;
          String? e2eeKey;
          if (extra is Uint8List) {
            bytes = extra;
          } else if (extra is String && extra.isNotEmpty) {
            e2eeKey = extra;
          } else if (extra is Map) {
            if (extra['bytes'] is Uint8List) {
              bytes = extra['bytes'] as Uint8List;
            }
            if (extra['e2eeFileKey'] is String) {
              e2eeKey = extra['e2eeFileKey'] as String;
            }
          }
          return _page(
            state,
            NativeFileViewerScreen(
              fileName: fileName,
              fileType: fileType,
              url: url,
              localPath: localPath,
              bytes: bytes,
              e2eeFileKey: e2eeKey,
            ),
            pageKey: state.pageKey,
          );
        },
      ),
      GoRoute(
        path: '/niosgram/create',
        pageBuilder: (context, state) {
          final bool autoPick = state.extra is bool ? state.extra as bool : false;
          return _page(state, CreatePostScreen(autoPickMedia: autoPick), pageKey: state.pageKey);
        },
      ),
      GoRoute(
        path: '/niosgram/post/:postId/comments',
        pageBuilder: (context, state) => _page(state, PostCommentsScreen(
          channelId: 0,
          postId: int.tryParse(state.pathParameters['postId'] ?? '') ?? 0,
        )),
      ),
      GoRoute(
        path: '/call/outgoing',
        pageBuilder: (context, state) {
          final Object? extra = state.extra;
          final OutgoingCallArgs args = extra is OutgoingCallArgs
              ? extra
              : OutgoingCallArgs(
                  username: state.uri.queryParameters['username'] ?? '',
                  displayName: state.uri.queryParameters['displayName'] ?? '',
                  avatarUrl: state.uri.queryParameters['avatarUrl'],
                  isVideo: state.uri.queryParameters['isVideo'] == '1',
                );
          return _page(
            state,
            OutgoingCallScreen(args: args),
            pageKey: state.pageKey,
          );
        },
      ),
      GoRoute(
        path: '/call/dm/:username',
        pageBuilder: (context, state) {
          final Object? extra = state.extra;
          final OutgoingCallArgs args = extra is OutgoingCallArgs
              ? extra
              : OutgoingCallArgs(
                  username: state.pathParameters['username']!,
                  displayName: state.uri.queryParameters['displayName'] ?? '',
                  avatarUrl: state.uri.queryParameters['avatarUrl'],
                  isVideo: state.uri.queryParameters['isVideo'] == '1',
                );
          return _page(
            state,
            OutgoingCallScreen(args: args),
            pageKey: state.pageKey,
          );
        },
      ),
      GoRoute(
        path: '/call/:callId',
        pageBuilder: (context, state) => _page(state, const ActiveCallScreen(), pageKey: state.pageKey),
      ),
      GoRoute(
        path: '/:pathMatch(.*)',
        pageBuilder: (context, state) => _page(state, Scaffold(
          body: Center(child: Text(context.l10n.routerNotFound)),
        )),
      ),
    ],
  );
});
