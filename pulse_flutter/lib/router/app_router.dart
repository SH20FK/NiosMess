import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/screens/chat_detail_screen.dart';
import 'package:pulse_flutter/screens/chat_manage_screen.dart';
import 'package:pulse_flutter/screens/chat_members_screen.dart';
import 'package:pulse_flutter/screens/contact_detail_screen.dart';
import 'package:pulse_flutter/screens/create_chat_screen.dart';
import 'package:pulse_flutter/screens/direct_chat_resolver_screen.dart';
import 'package:pulse_flutter/screens/e2ee_settings_screen.dart';
import 'package:pulse_flutter/screens/join_chat_screen.dart';
import 'package:pulse_flutter/screens/login_screen.dart';
import 'package:pulse_flutter/screens/main_shell_screen.dart';
import 'package:pulse_flutter/screens/media_viewer_screen.dart';
import 'package:pulse_flutter/screens/create_post_screen.dart';
import 'package:pulse_flutter/screens/onboarding_screen.dart';
import 'package:pulse_flutter/screens/post_comments_screen.dart';
import 'package:pulse_flutter/screens/public_profile_screen.dart';
import 'package:pulse_flutter/screens/register_screen.dart';
import 'package:pulse_flutter/screens/setup_onboarding_screen.dart';
import 'package:pulse_flutter/screens/reset_password_confirm_screen.dart';
import 'package:pulse_flutter/screens/reset_password_request_screen.dart';
import 'package:pulse_flutter/screens/sessions_screen.dart';
import 'package:pulse_flutter/screens/settings_account_screen.dart';
import 'package:pulse_flutter/screens/settings_about_screen.dart';
import 'package:pulse_flutter/screens/settings_appearance_screen.dart';
import 'package:pulse_flutter/screens/settings_language_region_screen.dart';
import 'package:pulse_flutter/screens/settings_privacy_screen.dart';
import 'package:pulse_flutter/screens/settings_storage_screen.dart';
import 'package:pulse_flutter/screens/splash_screen.dart';
import 'package:pulse_flutter/screens/two_fa_screen.dart';
import 'package:pulse_flutter/screens/verify_email_screen.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}

CustomTransitionPage<void> _page(GoRouterState state, Widget child, {LocalKey? pageKey}) {
  return CustomTransitionPage<void>(
    key: pageKey ?? state.pageKey,
    child: child,
    transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
      final Animatable<Offset> slideIn = Tween<Offset>(
        begin: const Offset(0.08, 0.0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));

      final Animatable<double> fadeIn = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic));

      final Animatable<Offset> slideOut = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.04, 0.0),
      ).chain(CurveTween(curve: Curves.easeOutCubic));

      final Animatable<double> fadeOut = Tween<double>(
        begin: 1.0,
        end: 0.6,
      ).chain(CurveTween(curve: Curves.easeOutCubic));

      return SlideTransition(
        position: animation.drive(slideIn),
        child: FadeTransition(
          opacity: animation.drive(fadeIn),
          child: SlideTransition(
            position: secondaryAnimation.drive(slideOut),
            child: FadeTransition(
              opacity: secondaryAnimation.drive(fadeOut),
              child: child,
            ),
          ),
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
  );
}

CustomTransitionPage<void> _sharedAxisPage(Widget child, LocalKey pageKey) {
  return CustomTransitionPage<void>(
    key: pageKey,
    child: child,
    transitionsBuilder: (_, animation, __, child) {
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: __,
        transitionType: SharedAxisTransitionType.scaled,
        child: child,
      );
    },
  );
}

CustomTransitionPage<void> _fadeThroughPage(Widget child, LocalKey pageKey) {
  return CustomTransitionPage<void>(
    key: pageKey,
    child: child,
    transitionsBuilder: (_, animation, __, child) {
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: __,
        child: child,
      );
    },
  );
}

CustomTransitionPage<void> _slideUpPage(Widget child, LocalKey pageKey) {
  return CustomTransitionPage<void>(
    key: pageKey,
    child: child,
    transitionsBuilder: (_, animation, secondaryAnimation, child) {
      final Animatable<Offset> slideUp = Tween<Offset>(
        begin: const Offset(0.0, 0.3),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));

      final Animatable<double> fadeIn = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic));

      return SlideTransition(
        position: animation.drive(slideUp),
        child: FadeTransition(
          opacity: animation.drive(fadeIn),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
  );
}

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final ValueNotifier<int> refreshListenable = ValueNotifier<int>(0);
  ref.onDispose(refreshListenable.dispose);

  ref.listen(authProvider, (AuthState? previous, AuthState next) {
    if (previous?.isAuthenticated != next.isAuthenticated) {
      refreshListenable.value++;
    }
  });

  return GoRouter(
    navigatorKey: AppRouter.navigatorKey,
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (BuildContext context, GoRouterState state) {
      final AuthState authState = ref.read(authProvider);
      final bool isAuth = authState.isAuthenticated;
      final String path = state.uri.path;

      final bool isPublic = path == '/' || path == '/login' || path == '/register' || path == '/onboarding' || path.startsWith('/reset-password') || path.startsWith('/verify-email') || path.startsWith('/2fa') || path.startsWith('/setup');

      if (!isAuth && !isPublic) return '/login';
      if (isAuth && (path == '/login' || path == '/onboarding' || path == '/register' || path.startsWith('/2fa'))) return '/main/chats';
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _page(state, const SplashScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _page(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _page(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => _page(state, const RegisterScreen()),
      ),
      GoRoute(
        path: '/setup',
        pageBuilder: (context, state) => _page(state, const SetupOnboardingScreen()),
      ),
      GoRoute(
        path: '/verify-email',
        pageBuilder: (context, state) => _page(state, VerifyEmailScreen(initialEmail: state.uri.queryParameters['email'])),
      ),
      GoRoute(
        path: '/2fa',
        pageBuilder: (context, state) => _page(state, TwoFaScreen(initialIdentifier: state.uri.queryParameters['identifier'])),
      ),
      GoRoute(
        path: '/reset-password/request',
        pageBuilder: (context, state) => _page(state, const ResetPasswordRequestScreen()),
      ),
      GoRoute(
        path: '/reset-password/confirm',
        pageBuilder: (context, state) => _page(state, ResetPasswordConfirmScreen(initialEmail: state.uri.queryParameters['email'])),
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
        path: '/chat/:chatId',
        pageBuilder: (context, state) => _sharedAxisPage(ChatDetailScreen(chatId: state.pathParameters['chatId']!, highlightMessageId: int.tryParse(state.uri.queryParameters['highlight'] ?? '')), state.pageKey),
      ),
      GoRoute(
        path: '/chat/dm/:username',
        pageBuilder: (context, state) => _page(state, DirectChatResolverScreen(
          username: state.pathParameters['username']!,
          isSecret: state.uri.queryParameters['isSecret'] == '1',
        )),
      ),
      GoRoute(
        path: '/media-viewer',
        pageBuilder: (context, state) {
          final String url = Uri.decodeComponent(state.uri.queryParameters['url'] ?? '');
          return _page(state, MediaViewerScreen(url: url, title: Uri.decodeComponent(state.uri.queryParameters['title'] ?? 'Attachment'), isImage: state.uri.queryParameters['image'] == '1'));
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
        path: '/profile/:username',
        pageBuilder: (context, state) => _page(state, PublicProfileScreen(username: state.pathParameters['username']!)),
      ),
      GoRoute(
        path: '/contact/:username',
        pageBuilder: (context, state) => _page(state, ContactDetailScreen(username: state.pathParameters['username']!)),
      ),
      GoRoute(
        path: '/settings',
        redirect: (context, state) => '/main/profile',
      ),
      GoRoute(
        path: '/settings/appearance',
        pageBuilder: (context, state) => _fadeThroughPage(const SettingsAppearanceScreen(), state.pageKey),
      ),
      GoRoute(
        path: '/settings/language-region',
        pageBuilder: (context, state) => _fadeThroughPage(const SettingsLanguageRegionScreen(), state.pageKey),
      ),
      GoRoute(
        path: '/settings/account',
        pageBuilder: (context, state) => _fadeThroughPage(const SettingsAccountScreen(), state.pageKey),
      ),
      GoRoute(
        path: '/settings/privacy',
        pageBuilder: (context, state) => _fadeThroughPage(const SettingsPrivacyScreen(), state.pageKey),
      ),
      GoRoute(
        path: '/settings/storage',
        pageBuilder: (context, state) => _fadeThroughPage(const SettingsStorageScreen(), state.pageKey),
      ),
      GoRoute(
        path: '/settings/about',
        pageBuilder: (context, state) => _fadeThroughPage(const SettingsAboutScreen(), state.pageKey),
      ),
      GoRoute(
        path: '/settings/e2ee',
        pageBuilder: (context, state) => _fadeThroughPage(const E2eeSettingsScreen(), state.pageKey),
      ),
      GoRoute(
        path: '/settings/sessions',
        pageBuilder: (context, state) => _fadeThroughPage(const SessionsScreen(), state.pageKey),
      ),
      GoRoute(
        path: '/two-fa',
        pageBuilder: (context, state) => _page(state, const TwoFaScreen()),
      ),
      GoRoute(
        path: '/niosgram/create',
        pageBuilder: (context, state) => _slideUpPage(const CreatePostScreen(), state.pageKey),
      ),
      GoRoute(
        path: '/niosgram/post/:postId/comments',
        pageBuilder: (context, state) => _page(state, PostCommentsScreen(
          channelId: 0,
          postId: int.parse(state.pathParameters['postId']!),
        )),
      ),
      GoRoute(
        path: '/:pathMatch(.*)',
        pageBuilder: (context, state) => _page(state, const Scaffold(
          body: Center(child: Text('404 — Page not found')),
        )),
      ),
    ],
  );
});
