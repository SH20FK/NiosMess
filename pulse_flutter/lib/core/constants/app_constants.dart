import 'package:pulse_flutter/core/constants/build_info.dart';

class AppConstants {
  AppConstants._();

  static const double screenHorizontalPadding = 20;
  static const double cardRadius = 28;
  static const double bubbleRadius = 18;
  static const double buttonRadius = 999;

  /// Public web origin used for share links and invites.
  static const String webOrigin = 'https://ni-os.ru';

  /// Application version constants proxied from BuildInfo (matching pubspec.yaml).
  static const String appVersion = BuildInfo.version;
  static const String appBuildNumber = BuildInfo.buildNumber;
  static const String appVersionWithPrefix = BuildInfo.versionWithPrefix;
  static const String appFullVersion = BuildInfo.fullVersion;

  static String chatShareUrl(int chatId) => '$webOrigin/chat/$chatId';
}
