class AppConstants {
  AppConstants._();

  static const double screenHorizontalPadding = 20;
  static const double cardRadius = 28;
  static const double bubbleRadius = 18;
  static const double buttonRadius = 999;

  /// Public web origin used for share links and invites.
  static const String webOrigin = 'https://niosmess.com';

  static String chatShareUrl(int chatId) => '$webOrigin/chat/$chatId';
}
