import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/router/app_router.dart';

class DeepLinkService {
  static StreamSubscription<Uri>? _sub;

  static Future<void> init() async {
    if (kIsWeb) return;

    final AppLinks appLinks = AppLinks();

    await _sub?.cancel();
    _sub = appLinks.uriLinkStream.listen(_handleUri);
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  static void _handleUri(Uri uri) {
    debugPrint('[DeepLink] Received: $uri');

    String path = uri.path;
    if (path.isEmpty || path == '/') return;

    // Rewrite server URL patterns to app routes
    // /join/{slug} → /join?slug={slug}
    if (path.startsWith('/join/')) {
      final String slug = path.substring(6);
      if (slug.isNotEmpty) {
        path = '/join?slug=$slug';
      }
    }

    final BuildContext? ctx = AppRouter.navigatorKey.currentContext;
    if (ctx == null) return;

    ctx.go(path + (uri.query.isNotEmpty ? '?${uri.query}' : ''));
  }
}
