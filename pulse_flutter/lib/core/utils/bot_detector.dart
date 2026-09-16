/// Unified bot detection logic across NiosMess (ЧАТ-35, ЗВН-7).
bool isBotAccount({String? username, bool isBotChat = false}) {
  if (isBotChat) return true;
  if (username == null) return false;
  final String clean = username.trim().toLowerCase();
  if (clean.isEmpty) return false;
  return clean == 'bot' || clean.endsWith('_bot') || clean.endsWith('bot');
}

abstract final class BotDetector {
  static bool isBot(String? username, {bool isBotChat = false}) =>
      isBotAccount(username: username, isBotChat: isBotChat);

  static bool isSupport(String? username, {int? userId}) {
    if (username == null) return false;
    final String clean = username.trim().toLowerCase();
    return clean == 'support';
  }
}
