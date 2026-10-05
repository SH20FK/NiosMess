import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/features/settings/domain/setting_id.dart';
import 'package:pulse_flutter/features/settings/domain/settings_destination.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';

void validateSettingsRegistry(Iterable<SettingsDestination> destinations) {
  final Set<String> ids = <String>{};
  final Map<String, Set<String>> anchorsByRoute = <String, Set<String>>{};

  for (final SettingsDestination item in destinations) {
    if (!ids.add(item.id.value)) {
      throw StateError('Duplicate setting id: ${item.id.value}');
    }

    final Set<String> anchors = anchorsByRoute.putIfAbsent(item.route, () => <String>{});
    if (!anchors.add(item.anchor)) {
      throw StateError('Duplicate anchor ${item.anchor} on ${item.route}');
    }
  }
}

class SettingsRegistry {
  const SettingsRegistry._();

  static final List<SettingsDestination> all = <SettingsDestination>[
    // 1. Account
    SettingsDestination(
      id: SettingId.securityTwoFactor,
      sectionId: 'account',
      route: '/settings/account',
      anchor: 'account-2fa',
      title: (AppLocalizations l) => 'Двухэтапная аутентификация',
      keywords: (AppLocalizations l) => <String>['2fa', 'пароль', 'облачный', 'защита', 'вход', 'безопасность'],
    ),
    SettingsDestination(
      id: SettingId.securitySessionsActive,
      sectionId: 'account',
      route: '/settings/sessions',
      anchor: 'sessions-list',
      title: (AppLocalizations l) => 'Активные сессии и устройства',
      keywords: (AppLocalizations l) => <String>['сессии', 'устройства', 'телефон', 'пк', 'компьютер', 'выйти'],
    ),

    // 2. Appearance
    SettingsDestination(
      id: SettingId.appearanceThemeMode,
      sectionId: 'appearance',
      route: '/settings/appearance',
      anchor: 'appearance-theme-mode',
      title: (AppLocalizations l) => 'Тема оформления',
      keywords: (AppLocalizations l) => <String>['тема', 'темная', 'светлая', 'системная', 'oled', 'черная'],
    ),
    SettingsDestination(
      id: SettingId.appearanceColorSource,
      sectionId: 'appearance',
      route: '/settings/appearance',
      anchor: 'appearance-color-seed',
      title: (AppLocalizations l) => 'Цветовая палитра NiosColorField',
      keywords: (AppLocalizations l) => <String>['цвет', 'палитра', 'акцент', 'material you', 'seed', 'стиль'],
    ),
    SettingsDestination(
      id: SettingId.appearanceDynamicColor,
      sectionId: 'appearance',
      route: '/settings/appearance',
      anchor: 'appearance-dynamic-color',
      title: (AppLocalizations l) => 'Динамические цвета системы',
      keywords: (AppLocalizations l) => <String>['динамические', 'material you', 'обои', 'оттенки', 'android'],
    ),

    // 3. Privacy & Messaging
    SettingsDestination(
      id: SettingId.privacyReadReceipts,
      sectionId: 'privacy',
      route: '/settings/privacy',
      anchor: 'privacy-read-receipts',
      title: (AppLocalizations l) => 'Отчёты о прочтении',
      keywords: (AppLocalizations l) => <String>['прочтение', 'галочки', 'статус', 'прочитано', 'сообщения'],
    ),
    SettingsDestination(
      id: SettingId.privacyTypingIndicators,
      sectionId: 'privacy',
      route: '/settings/privacy',
      anchor: 'privacy-typing',
      title: (AppLocalizations l) => 'Индикатор набора текста',
      keywords: (AppLocalizations l) => <String>['печатает', 'набор', 'статус', 'индикатор'],
    ),
    SettingsDestination(
      id: SettingId.privacyDefaultExpiry,
      sectionId: 'privacy',
      route: '/settings/privacy',
      anchor: 'privacy-default-expiry',
      title: (AppLocalizations l) => 'Автоудаление сообщений по умолчанию',
      keywords: (AppLocalizations l) => <String>['самоуничтожение', 'таймер', 'удаление', 'секретный', 'исчезающие'],
    ),
    SettingsDestination(
      id: SettingId.privacyHideOnline,
      sectionId: 'privacy',
      route: '/settings/privacy',
      anchor: 'privacy-hide-online',
      title: (AppLocalizations l) => 'Скрывать статус «В сети»',
      keywords: (AppLocalizations l) => <String>['онлайн', 'в сети', 'статус', 'невидимка', 'скрыть'],
    ),
    SettingsDestination(
      id: SettingId.privacyBlockedUsers,
      sectionId: 'privacy',
      route: '/settings/privacy',
      anchor: 'privacy-black-list',
      title: (AppLocalizations l) => 'Чёрный список',
      keywords: (AppLocalizations l) => <String>['заблокированные', 'бан', 'чс', 'черный список', 'спам'],
    ),

    // 4. Security & App Lock
    SettingsDestination(
      id: SettingId.securityAppLock,
      sectionId: 'security',
      route: '/settings/account',
      anchor: 'security-app-lock',
      title: (AppLocalizations l) => 'Блокировка приложения биометрией',
      keywords: (AppLocalizations l) => <String>['блокировка', 'пин', 'биометрия', 'отпечаток', 'face id', 'пароль'],
    ),
    SettingsDestination(
      id: SettingId.securityAppLockTimeout,
      sectionId: 'security',
      route: '/settings/account',
      anchor: 'security-app-lock-timeout',
      title: (AppLocalizations l) => 'Таймер автоблокировки',
      keywords: (AppLocalizations l) => <String>['таймер', 'время', 'автоблокировка', 'секунды', 'минуты'],
    ),

    // 5. Storage
    SettingsDestination(
      id: SettingId.storageClearCache,
      sectionId: 'storage',
      route: '/settings/storage',
      anchor: 'storage-cache-clear',
      title: (AppLocalizations l) => 'Очистка кэша и временных файлов',
      keywords: (AppLocalizations l) => <String>['кэш', 'память', 'очистить', 'диск', 'хранилище', 'место'],
    ),
    SettingsDestination(
      id: SettingId.storageAutoDownloadWifi,
      sectionId: 'storage',
      route: '/settings/storage',
      anchor: 'storage-auto-download',
      title: (AppLocalizations l) => 'Автозагрузка медиа по Wi-Fi',
      keywords: (AppLocalizations l) => <String>['автозагрузка', 'wifi', 'медиа', 'фото', 'видео', 'файлы'],
    ),

    // 6. Notifications
    SettingsDestination(
      id: SettingId.notificationsEnabled,
      sectionId: 'notifications',
      route: '/settings/notifications',
      anchor: 'notifications-permission',
      title: (AppLocalizations l) => 'Входящие уведомления',
      keywords: (AppLocalizations l) => <String>['уведомления', 'пуши', 'звук', 'вибрация', 'колокольчик'],
    ),
  ];
}

class SearchMatch {
  const SearchMatch({
    required this.destination,
    required this.title,
    required this.score,
  });

  final SettingsDestination destination;
  final String title;
  final double score;
}

class SettingsSearchController extends Notifier<List<SearchMatch>> {
  @override
  List<SearchMatch> build() => const <SearchMatch>[];

  void search(String query, AppLocalizations l10n) {
    final String clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      state = const <SearchMatch>[];
      return;
    }

    final List<SearchMatch> matches = <SearchMatch>[];

    for (final SettingsDestination dest in SettingsRegistry.all) {
      final String title = dest.title(l10n);
      final String lowerTitle = title.toLowerCase();
      final List<String> keywords = dest.keywords(l10n).map((k) => k.toLowerCase()).toList();

      double score = 0.0;
      if (lowerTitle == clean) {
        score = 100.0;
      } else if (lowerTitle.startsWith(clean)) {
        score = 80.0;
      } else if (lowerTitle.contains(clean)) {
        score = 60.0;
      } else {
        for (final String kw in keywords) {
          if (kw == clean) {
            score = 70.0;
            break;
          } else if (kw.contains(clean)) {
            score = 40.0;
            break;
          }
        }
      }

      if (score > 0) {
        matches.add(SearchMatch(destination: dest, title: title, score: score));
      }
    }

    matches.sort((a, b) => b.score.compareTo(a.score));
    state = matches;
  }

  void clear() {
    state = const <SearchMatch>[];
  }
}

final NotifierProvider<SettingsSearchController, List<SearchMatch>>
    settingsSearchControllerProvider =
        NotifierProvider<SettingsSearchController, List<SearchMatch>>(
  SettingsSearchController.new,
);
