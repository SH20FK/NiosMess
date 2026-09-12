class AppConstants {
  AppConstants._();

  static const double screenHorizontalPadding = 20;
  static const double cardRadius = 28;
  static const double bubbleRadius = 18;
  static const double buttonRadius = 999;

  /// Public web origin used for share links and invites.
  static const String webOrigin = 'https://niosmess.com';

  /// Application version constants matching pubspec.yaml.
  static const String appVersion = '3.33.4';
  static const String appBuildNumber = '69';
  static const String appVersionWithPrefix = 'v3.33.4';
  static const String appFullVersion = 'v3.33.4+69';

  static String chatShareUrl(int chatId) => '$webOrigin/chat/$chatId';
}
