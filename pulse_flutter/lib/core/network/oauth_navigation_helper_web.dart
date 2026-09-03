// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'oauth_navigation_helper.dart';

OAuthNavigationHelper createOAuthNavigationHelper() => WebOAuthNavigationHelper();

class WebOAuthNavigationHelper implements OAuthNavigationHelper {
  @override
  Future<void> redirectToUrl(String url) async {
    html.window.location.assign(url);
  }

  @override
  Future<void> openInBrowser(String url) async {
    html.window.open(url, '_blank');
  }

  @override
  void sanitizeAddressBar({String fallbackPath = '/web'}) {
    try {
      final String path = html.window.location.pathname ?? fallbackPath;
      html.window.history.replaceState(null, html.document.title, path);
    } catch (_) {}
  }

  @override
  Future<void> openRegistration({String? nextUrl}) async {
    final String fallbackNext = '${html.window.location.origin}/web';
    final String targetNext = nextUrl ?? fallbackNext;
    final String target =
        'https://ni-os.ru/id/register?next=${Uri.encodeComponent(targetNext)}';
    html.window.location.assign(target);
  }
}
