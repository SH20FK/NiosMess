import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';

class DeepLinkService {
  static StreamSubscription<Uri>? _sub;

  static Future<void> init() async {
    if (kIsWeb) return;

    final AppLinks appLinks = AppLinks();

    // 1. Cold start deep link handling
    try {
      final Uri? initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('[DeepLink] Cold start link detected: $initialUri');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleUri(initialUri);
        });
      }
    } catch (e) {
      debugPrint('[DeepLink] Error reading initial URI: $e');
    }

    // 2. Runtime stream listening
    await _sub?.cancel();
    _sub = appLinks.uriLinkStream.listen(_handleUri);
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  static void _handleUri(Uri uri) {
    debugPrint('[DeepLink] Received runtime link: $uri');
    AppUrlLauncher.handleDeepLink(uri);
  }
}
