class AppConstants {
  AppConstants._();

  static const double screenHorizontalPadding = 20;
  static const double cardRadius = 28;
  static const double bubbleRadius = 18;
  static const double buttonRadius = 999;

  /// Public web origin used for share links and invites.
  static const String webOrigin = 'https://ni-os.ru';

  /// Application version constants matching pubspec.yaml.
  static const String appVersion = '3.60.5';
  static const String appBuildNumber = '141';
  static const String appVersionWithPrefix = 'v3.60.5';
  static const String appFullVersion = 'v3.60.5+141';

  static String chatShareUrl(int chatId) => '$webOrigin/chat/$chatId';
}
