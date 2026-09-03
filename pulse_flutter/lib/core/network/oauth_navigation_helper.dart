import 'oauth_navigation_helper_stub.dart'
    if (dart.library.html) 'oauth_navigation_helper_web.dart';

abstract class OAuthNavigationHelper {
  factory OAuthNavigationHelper() => createOAuthNavigationHelper();

  Future<void> redirectToUrl(String url);
  Future<void> openInBrowser(String url);
  void sanitizeAddressBar({String fallbackPath = '/web'});
  Future<void> openRegistration({String? nextUrl});
}
