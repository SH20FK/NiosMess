import 'package:url_launcher/url_launcher.dart';
import 'oauth_navigation_helper.dart';

OAuthNavigationHelper createOAuthNavigationHelper() => NativeOAuthNavigationHelper();

class NativeOAuthNavigationHelper implements OAuthNavigationHelper {
  @override
  Future<void> redirectToUrl(String url) async {
    final Uri uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Future<void> openInBrowser(String url) async {
    final Uri uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void sanitizeAddressBar({String fallbackPath = '/web'}) {
    // No address bar on native platforms
  }

  @override
  Future<void> openRegistration({String? nextUrl}) async {
    final String target = nextUrl != null && nextUrl.isNotEmpty
        ? 'https://ni-os.ru/id/register?next=${Uri.encodeComponent(nextUrl)}'
        : 'https://ni-os.ru/id/register?next=/web';
    await launchUrl(Uri.parse(target), mode: LaunchMode.externalApplication);
  }
}
