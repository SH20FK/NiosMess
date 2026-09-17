import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pulse_flutter/router/app_router.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';

/// Centralized URL and Deep Link router for NiosMess.
///
/// Features:
/// 1. Internal NiosMess URLs (`https://ni-os.ru/...`, `niosmess://...`, relative paths)
///    are routed directly inside the Flutter app using [GoRouter] without leaving to a browser.
/// 2. Telegram links (`https://t.me/...`, `tg://...`) are launched directly into the native
///    Telegram app via `tg://` scheme with seamless fallback to external browser.
/// 3. Other external URLs are opened in-app via [LaunchMode.inAppBrowserView].
class AppUrlLauncher {
  AppUrlLauncher._();

  /// Public web origin used for canonical share links and invites.
  static const String webOrigin = 'https://ni-os.ru';

  /// Normalizes any raw invite slug, token, or legacy URL into canonical `https://ni-os.ru/u/...` format.
  ///
  /// Examples:
  /// - `+token123` -> `https://ni-os.ru/u/+token123`
  /// - `/join/test` -> `https://ni-os.ru/u/test`
  /// - `https://ni-os.ru/join/group` -> `https://ni-os.ru/u/group`
  /// - `my_channel` -> `https://ni-os.ru/u/my_channel`
  static String formatCanonicalInviteUrl(String? raw) {
    if (raw == null) return '';
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    // If it's already a full https://ni-os.ru/u/... URL, return as is
    if (trimmed.startsWith('$webOrigin/u/')) {
      return trimmed;
    }

    String slug = trimmed;

    // Handle full URLs
    if (slug.startsWith('http://') || slug.startsWith('https://') || slug.startsWith('niosmess://')) {
      final Uri? uri = Uri.tryParse(slug);
      if (uri != null) {
        final List<String> segments = uri.pathSegments.where((String s) => s.isNotEmpty).toList();
        if (segments.isNotEmpty) {
          final int joinIdx = segments.indexOf('join');
          if (joinIdx != -1 && joinIdx + 1 < segments.length) {
            slug = segments[joinIdx + 1];
          } else {
            final int uIdx = segments.indexOf('u');
            if (uIdx != -1 && uIdx + 1 < segments.length) {
              slug = segments[uIdx + 1];
            } else {
              slug = segments.last;
            }
          }
        }
      }
    }

    // Handle relative paths like /join/slug or /u/slug
    if (slug.startsWith('/join/')) {
      slug = slug.substring(6);
    } else if (slug.startsWith('/u/')) {
      slug = slug.substring(3);
    } else if (slug.startsWith('join/')) {
      slug = slug.substring(5);
    } else if (slug.startsWith('u/')) {
      slug = slug.substring(2);
    }

    slug = slug.replaceAll(RegExp(r'^/+|/+$'), '').trim();
    if (slug.isEmpty) return '';

    return '$webOrigin/u/$slug';
  }

  /// Opens any given [rawUrl] string intelligently based on its scheme and destination.
  static Future<bool> openUrl(
    BuildContext? context,
    String rawUrl, {
    bool enableHaptics = true,
  }) async {
    final String trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return false;

    if (enableHaptics) {
      HapticService.tap();
    }

    // Handle relative in-app paths directly (e.g. '/u/username', '/settings/about')
    if (trimmed.startsWith('/')) {
      return _routeInternally(context, trimmed);
    }

    Uri? parsedUri;
    try {
      parsedUri = Uri.parse(trimmed);
    } catch (e) {
      debugPrint('[AppUrlLauncher] Malformed URL: $trimmed ($e)');
      return false;
    }

    // Auto-prepend https if user clicked e.g. "t.me/something" or "ni-os.ru/something"
    if (!parsedUri.hasScheme && (trimmed.startsWith('t.me/') || trimmed.startsWith('telegram.me/') || trimmed.startsWith('ni-os.ru/'))) {
      parsedUri = Uri.parse('https://$trimmed');
    }

    // 1. Internal NiosMess Link
    if (isInternalNiosLink(parsedUri)) {
      final String? internalRoute = resolveInternalAppRoute(parsedUri);
      if (internalRoute != null) {
        return _routeInternally(context, internalRoute);
      }
    }

    // 2. Telegram Link
    if (isTelegramLink(parsedUri)) {
      return _launchTelegram(parsedUri);
    }

    // 3. Other External Link
    return _launchExternal(parsedUri);
  }

  /// Handles an incoming deep link URI from OS (e.g. via [DeepLinkService]).
  static Future<bool> handleDeepLink(Uri uri) async {
    debugPrint('[AppUrlLauncher] Handling deep link: $uri');

    final String? internalRoute = resolveInternalAppRoute(uri);
    if (internalRoute != null) {
      final BuildContext? ctx = AppRouter.navigatorKey.currentContext;
      return _routeInternally(ctx, internalRoute);
    }

    return false;
  }

  /// Checks if a given [uri] belongs to the NiosMess ecosystem.
  static bool isInternalNiosLink(Uri uri) {
    if (uri.scheme == 'niosmess') return true;
    final String host = uri.host.toLowerCase();
    return host == 'ni-os.ru' ||
        host == 'www.ni-os.ru' ||
        host == 'c.ni-os.ru' ||
        host == 'localhost' ||
        host == '127.0.0.1';
  }

  /// Resolves an internal [uri] to a relative GoRouter path.
  static String? resolveInternalAppRoute(Uri uri) {
    String path = uri.path;

    // Support URLs with hash routing (e.g. 'https://ni-os.ru/#/u/alice' or '/web#/u/alice')
    if (uri.fragment.isNotEmpty && (path.isEmpty || path == '/' || path == '/web')) {
      path = uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}';
    }

    if (uri.scheme == 'niosmess') {
      if (uri.host.isNotEmpty && !path.startsWith('/${uri.host}')) {
        path = '/${uri.host}$path';
      }
    }

    // Strip '/web' prefix if link was copied from web client (e.g. '/web/u/alice')
    if (path.startsWith('/web/')) {
      path = path.substring(4);
    }

    // Bare landing page (https://ni-os.ru / https://ni-os.ru/) is external landing
    if (uri.scheme != 'niosmess' && (path.isEmpty || path == '/')) {
      return null;
    }

    if (path.isEmpty || path == '/') {
      return '/main/chats';
    }

    // Strip trailing slash if present (except root)
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    // 1. /join/slug or /join?slug=...
    if (path.startsWith('/join/')) {
      final String slug = path.substring(6);
      if (slug.isNotEmpty) return '/join?slug=$slug';
    } else if (path == '/join') {
      final String? slug = uri.queryParameters['slug'];
      if (slug != null && slug.isNotEmpty) return '/join?slug=$slug';
      return '/join';
    }

    // 2. /u/{slug} (username, public channel, private invite /u/+TOKEN)
    if (path.startsWith('/u/')) {
      final String slug = path.substring(3);
      if (slug.isNotEmpty) return '/u/$slug';
    }

    // /c/{slug} (alias for /u/)
    if (path.startsWith('/c/')) {
      final String slug = path.substring(3);
      if (slug.isNotEmpty) return '/u/$slug';
    }

    // 3. /g/{username} (NiosGram public profile / direct chat resolver)
    if (path.startsWith('/g/')) {
      final String username = path.substring(3);
      if (username.isNotEmpty) return '/g/$username';
    }

    // /stickers/{setId} (sticker pack view and save)
    if (path.startsWith('/stickers/')) {
      final String setId = path.substring(10);
      if (setId.isNotEmpty) return '/stickers/$setId';
    }

    // /w/{code} (Nios Weave procedural wallpaper link)
    if (path.startsWith('/w/')) {
      final String code = path.substring(3);
      if (code.isNotEmpty) return '/settings/wallpaper?code=$code';
    }
    if (path == '/wallpaper') {
      final String? code = uri.queryParameters['code'];
      if (code != null && code.isNotEmpty) return '/settings/wallpaper?code=$code';
      return '/settings/wallpaper';
    }

    // 4. /chat/{chatId} or /chat/dm/{username}
    if (path.startsWith('/chat/')) {
      return path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
    }

    // 5. /settings/...
    if (path.startsWith('/settings')) {
      return path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
    }

    // 6. /legal/...
    if (path.startsWith('/legal')) {
      return path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
    }

    // 7. /call/...
    if (path.startsWith('/call')) {
      return path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
    }

    // 8. Standard app shells
    if (path.startsWith('/main') || path == '/login' || path == '/web' || path == '/onboarding') {
      return path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
    }

    return null;
  }

  /// Checks if a [uri] points to Telegram.
  static bool isTelegramLink(Uri uri) {
    if (uri.scheme == 'tg') return true;
    final String host = uri.host.toLowerCase();
    return host == 't.me' ||
        host == 'telegram.me' ||
        host == 'telegram.dog';
  }

  /// Converts a Telegram web URL (`https://t.me/...`) into a native `tg://` URI.
  static Uri? convertTelegramToNativeScheme(Uri uri) {
    if (uri.scheme == 'tg') return uri;

    final List<String> segments = uri.pathSegments.where((String s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      return Uri.parse('tg://');
    }

    final String first = segments[0];

    // Invite link: https://t.me/+hash
    if (first.startsWith('+')) {
      final String invite = first.substring(1);
      return Uri.parse('tg://join?invite=$invite');
    }

    // Legacy invite link: https://t.me/joinchat/hash
    if (first == 'joinchat' && segments.length > 1) {
      return Uri.parse('tg://join?invite=${segments[1]}');
    }

    // Private channel post: https://t.me/c/12345/67
    if (first == 'c' && segments.length > 1) {
      final String channel = segments[1];
      final String post = segments.length > 2 ? '&post=${segments[2]}' : '';
      return Uri.parse('tg://privatepost?channel=$channel$post');
    }

    // Username or channel with optional post id: https://t.me/channel/123
    if (segments.length >= 2) {
      return Uri.parse('tg://resolve?domain=$first&post=${segments[1]}');
    }

    return Uri.parse('tg://resolve?domain=$first');
  }

  static bool _routeInternally(BuildContext? context, String route) {
    final BuildContext? targetContext = context ?? AppRouter.navigatorKey.currentContext;
    if (targetContext == null || !targetContext.mounted) {
      debugPrint('[AppUrlLauncher] Cannot route internally: no active BuildContext for $route');
      return false;
    }

    try {
      targetContext.push(route);
      return true;
    } catch (e) {
      debugPrint('[AppUrlLauncher] context.push failed for $route, trying context.go: $e');
      try {
        targetContext.go(route);
        return true;
      } catch (e2) {
        debugPrint('[AppUrlLauncher] context.go also failed for $route: $e2');
        return false;
      }
    }
  }

  static Future<bool> _launchTelegram(Uri uri) async {
    final Uri? nativeTgUri = convertTelegramToNativeScheme(uri);
    final Uri webFallbackUri = uri.scheme == 'tg'
        ? Uri.parse('https://t.me/${uri.queryParameters['domain'] ?? ''}')
        : uri;

    // On non-web (Android/iOS/Desktop), attempt native tg:// first
    if (!kIsWeb && nativeTgUri != null) {
      try {
        final bool canLaunchNative = await canLaunchUrl(nativeTgUri);
        if (canLaunchNative) {
          final bool launched = await launchUrl(
            nativeTgUri,
            mode: LaunchMode.externalNonBrowserApplication,
          );
          if (launched) return true;
        }
      } catch (e) {
        debugPrint('[AppUrlLauncher] Native tg launch error: $e');
      }
    }

    // Fallback to external browser
    return _launchExternal(webFallbackUri);
  }

  static Future<bool> _launchExternal(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      debugPrint('[AppUrlLauncher] Error launching external URL: $uri ($e)');
    }
    return false;
  }
}
