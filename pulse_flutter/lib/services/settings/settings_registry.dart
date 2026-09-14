import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/settings/settings_node.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

/// Search match result with full breadcrumb path and navigation target.
class SettingsSearchResult {
  const SettingsSearchResult({
    required this.node,
    required this.title,
    this.subtitle,
    required this.breadcrumb,
    required this.targetRoute,
    this.targetSectionId,
    required this.score,
  });

  final SettingsNode node;
  final String title;
  final String? subtitle;
  final String breadcrumb;
  final String targetRoute;
  final SettingsSectionId? targetSectionId;
  final double score;
}

/// Centralized registry of all settings sections, items, and search indices.
/// Acts as the single source of truth for mobile, desktop, and in-settings search.
class SettingsRegistry {
  const SettingsRegistry._();

  /// Top-level sections shown in the main settings hub and desktop master sidebar.
  static final List<SettingsNavNode> _topLevelSections = <SettingsNavNode>[
    // 1. Account
    SettingsNavNode(
      id: 'account',
      title: (AppLocalizations l) => l.settingsAccountTitle,
      subtitle: (AppLocalizations l) => l.settingsAccountSubtitle,
      icon: Icons.manage_accounts_rounded,
      group: SettingsGroup.account,
      route: '/settings/account',
      sectionId: SettingsSectionId.account,
      keywords: const <String>[
        'аккаунт',
        'профиль',
        'имя',
        'юзернейм',
        'телефон',
        'account',
        'profile',
        'username',
        'phone',
        'birthday',
        'bio',
        '2fa',
        'nios id',
      ],
    ),

    // 2. Appearance
    SettingsNavNode(
      id: 'appearance',
      title: (AppLocalizations l) => l.profileAppearance,
      subtitle: (AppLocalizations l) => 'Тема, палитра, геометрия и шрифты',
      icon: Icons.palette_rounded,
      group: SettingsGroup.appearance,
      route: '/settings/appearance',
      sectionId: SettingsSectionId.appearance,
      keywords: const <String>[
        'внешний вид',
        'тема',
        'темная',
        'светлая',
        'цвета',
        'скругление',
        'радиус',
        'appearance',
        'theme',
        'palette',
        'color',
        'corner',
        'radius',
        'font',
        'contrast',
        'oled',
        'mesh',
      ],
    ),

    // 3. Chats & Media
    SettingsNavNode(
      id: 'chats',
      title: (AppLocalizations l) => l.settingsChatsTitle,
      subtitle: (AppLocalizations l) => 'Обои чатов, автозагрузка и камера',
      icon: Icons.chat_bubble_outline_rounded,
      group: SettingsGroup.chats,
      route: '/settings/chats',
      sectionId: SettingsSectionId.chats,
      keywords: const <String>[
        'чаты',
        'обои',
        'медиа',
        'автозагрузка',
        'вайфай',
        'камера',
        'enter',
        'chats',
        'wallpaper',
        'media',
        'download',
        'wifi',
        'cellular',
        'camera',
        'reaction',
      ],
    ),

    // 4. Notifications & Sounds
    SettingsNavNode(
      id: 'notifications',
      title: (AppLocalizations l) => l.settingsPreferencesTitle,
      subtitle: (AppLocalizations l) => 'Push-уведомления, звуки и вибрация',
      icon: Icons.notifications_active_rounded,
      group: SettingsGroup.notifications,
      route: '/settings/preferences',
      sectionId: SettingsSectionId.preferences,
      keywords: const <String>[
        'уведомления',
        'звуки',
        'пуши',
        'вибрация',
        'громкость',
        'notifications',
        'sounds',
        'push',
        'alerts',
        'haptics',
        'volume',
      ],
    ),

    // 5. Privacy & Security
    SettingsNavNode(
      id: 'privacy',
      title: (AppLocalizations l) => l.settingsPrivacyTitle,
      subtitle: (AppLocalizations l) => 'Секретные чаты, сессии, черный список',
      icon: Icons.security_rounded,
      group: SettingsGroup.privacy,
      route: '/settings/privacy',
      sectionId: SettingsSectionId.privacy,
      keywords: const <String>[
        'приватность',
        'безопасность',
        'онлайн',
        'последняя активность',
        'черный список',
        'сессии',
        'e2ee',
        'шифрование',
        'биометрия',
        'privacy',
        'security',
        'last seen',
        'blocklist',
        'sessions',
        'encryption',
        'biometrics',
      ],
    ),

    // 6. Storage & Data
    SettingsNavNode(
      id: 'storage',
      title: (AppLocalizations l) => l.settingsStorageTitle,
      subtitle: (AppLocalizations l) => 'Очистка кэша и управление памятью',
      icon: Icons.sd_storage_rounded,
      group: SettingsGroup.storage,
      route: '/settings/storage',
      sectionId: SettingsSectionId.storage,
      keywords: const <String>[
        'память',
        'хранилище',
        'кэш',
        'очистить кэш',
        'файлы',
        'storage',
        'data',
        'cache',
        'clean',
        'disk',
      ],
    ),

    // 7. Language & Region
    SettingsNavNode(
      id: 'language',
      title: (AppLocalizations l) => l.profileLanguage,
      subtitle: (AppLocalizations l) => 'Язык интерфейса, время и регион',
      icon: Icons.language_rounded,
      group: SettingsGroup.language,
      route: '/settings/language-region',
      sectionId: SettingsSectionId.languageRegion,
      keywords: const <String>[
        'язык',
        'регион',
        'время',
        'часовой пояс',
        'русский',
        'английский',
        'language',
        'region',
        'locale',
        'timezone',
        'time',
      ],
    ),

    // 8. System & Device (Native platforms only)
    SettingsNavNode(
      id: 'system_device',
      title: (AppLocalizations l) => 'Система и устройство',
      subtitle: (AppLocalizations l) => 'Аппаратные ресурсы, экран и датчики',
      icon: Icons.memory_rounded,
      group: SettingsGroup.about,
      route: '/settings/system-device',
      sectionId: SettingsSectionId.systemDevice,
      availability: () => !kIsWeb,
      keywords: const <String>[
        'устройство',
        'система',
        'процессор',
        'память',
        'характеристики',
        'экран',
        'device',
        'system',
        'cpu',
        'ram',
        'specs',
        'hardware',
      ],
    ),

    // 9. About App
    SettingsNavNode(
      id: 'about',
      title: (AppLocalizations l) => l.settingsSupportAboutTitle,
      subtitle: (AppLocalizations l) => 'Версия NiosMess, документы и справка',
      icon: Icons.info_outline_rounded,
      group: SettingsGroup.about,
      route: '/settings/about',
      sectionId: SettingsSectionId.about,
      keywords: const <String>[
        'о приложении',
        'версия',
        'обновления',
        'лицензия',
        'справка',
        'документы',
        'about',
        'version',
        'license',
        'privacy policy',
        'terms',
      ],
    ),
  ];

  /// Deeply searchable items mapped to their parent section and route.
  static final List<SettingsNode> _searchableChildren = <SettingsNode>[
    // Appearance items
    SettingsSliderNode(
      id: 'ui_corner_radius',
      parentNavId: 'appearance',
      title: (AppLocalizations l) => l.appearanceUiRounding,
      subtitle: (AppLocalizations l) => l.appearanceUiRoundingDesc,
      icon: Icons.rounded_corner_rounded,
      group: SettingsGroup.appearance,
      min: 8.0,
      max: 28.0,
      divisions: 20,
      unit: 'dp',
      valueSelector: (UiSettingsState s) => s.uiCornerRadius,
      onChanged: (WidgetRef ref, double v) =>
          ref.read(uiSettingsProvider.notifier).setUiCornerRadius(v),
      keywords: const <String>[
        'скругление интерфейса',
        'радиус',
        'карточки',
        'углы',
        'corner radius',
        'ui radius',
        'geometry',
      ],
    ),
    SettingsSliderNode(
      id: 'bubble_radius',
      parentNavId: 'appearance',
      title: (AppLocalizations l) => l.appearanceMessageRounding,
      subtitle: (AppLocalizations l) => l.appearanceMessageRoundingDesc,
      icon: Icons.bubble_chart_rounded,
      group: SettingsGroup.appearance,
      min: 4.0,
      max: 28.0,
      divisions: 24,
      unit: 'dp',
      valueSelector: (UiSettingsState s) => s.messageBubbleRadius,
      onChanged: (WidgetRef ref, double v) =>
          ref.read(uiSettingsProvider.notifier).setMessageBubbleRadius(v),
      keywords: const <String>[
        'пузыри',
        'сообщения',
        'баблы',
        'радиус сообщений',
        'bubble radius',
        'chat bubbles',
      ],
    ),
    SettingsChoiceNode<AppFontScale>(
      id: 'font_scale',
      parentNavId: 'appearance',
      title: (AppLocalizations l) => 'Масштаб шрифта',
      subtitle: (AppLocalizations l) => 'Размер текста во всем приложении',
      icon: Icons.format_size_rounded,
      group: SettingsGroup.appearance,
      options: AppFontScale.values,
      optionLabel: (AppFontScale scale, AppLocalizations l) => '${(scale.scale * 100).toInt()}%',
      valueSelector: (UiSettingsState s) => s.fontScale,
      onChanged: (WidgetRef ref, AppFontScale scale) =>
          ref.read(uiSettingsProvider.notifier).setFontScale(scale),
      keywords: const <String>[
        'шрифт',
        'текст',
        'размер шрифта',
        'масштаб',
        'font scale',
        'text size',
      ],
    ),
    SettingsToggleNode(
      id: 'true_black_oled',
      parentNavId: 'appearance',
      title: (AppLocalizations l) => l.appearanceDeepBlackOled,
      subtitle: (AppLocalizations l) => l.appearanceDeepBlackOledDesc,
      icon: Icons.dark_mode_rounded,
      group: SettingsGroup.appearance,
      valueSelector: (UiSettingsState s) => s.pureBlackOled,
      onChanged: (WidgetRef ref, bool v) =>
          ref.read(uiSettingsProvider.notifier).setPureBlackOled(v),
      keywords: const <String>[
        'oled',
        'черный',
        'глубокий черный',
        'true black',
        'батарея',
      ],
    ),
    SettingsToggleNode(
      id: 'system_dynamic_colors',
      parentNavId: 'appearance',
      title: (AppLocalizations l) => l.appearanceSystemColors,
      subtitle: (AppLocalizations l) => l.appearanceSystemColorsSubtitle,
      icon: Icons.auto_awesome_rounded,
      group: SettingsGroup.appearance,
      valueSelector: (UiSettingsState s) => s.useSystemDynamic,
      onChanged: (WidgetRef ref, bool v) =>
          ref.read(uiSettingsProvider.notifier).setUseSystemDynamic(v),
      keywords: const <String>[
        'динамические цвета',
        'системные цвета',
        'палитра android',
        'dynamic colors',
      ],
    ),
    SettingsToggleNode(
      id: 'navbar_floating',
      parentNavId: 'appearance',
      title: (AppLocalizations l) => l.appearanceFloatingNav,
      subtitle: (AppLocalizations l) => l.appearanceFloatingNavSubtitle,
      icon: Icons.dock_rounded,
      group: SettingsGroup.appearance,
      valueSelector: (UiSettingsState s) => s.navBarFloating,
      onChanged: (WidgetRef ref, bool v) =>
          ref.read(uiSettingsProvider.notifier).setNavBarFloating(v),
      keywords: const <String>[
        'навигация',
        'нижняя панель',
        'плавающая',
        'navbar',
        'bottom navigation',
      ],
    ),

    // Chats items
    SettingsNavNode(
      id: 'wallpaper_generator',
      parentNavId: 'chats',
      title: (AppLocalizations l) => l.settingsChatsWallpaperGenerator,
      subtitle: (AppLocalizations l) => l.settingsChatsWallpaperGeneratorDesc,
      icon: Icons.wallpaper_rounded,
      group: SettingsGroup.chats,
      route: '/settings/wallpaper',
      keywords: const <String>[
        'обои',
        'генератор обоев',
        'фон',
        'паттерн',
        'wallpaper',
        'pattern',
      ],
    ),
    SettingsToggleNode(
      id: 'send_on_enter',
      parentNavId: 'chats',
      title: (AppLocalizations l) => l.settingsChatsSendOnEnter,
      subtitle: (AppLocalizations l) => l.settingsChatsSendOnEnterDesc,
      icon: Icons.keyboard_return_rounded,
      group: SettingsGroup.chats,
      valueSelector: (UiSettingsState s) => s.sendOnEnter,
      onChanged: (WidgetRef ref, bool v) =>
          ref.read(uiSettingsProvider.notifier).setSendOnEnter(v),
      keywords: const <String>[
        'enter',
        'отправка',
        'клавиатура',
        'send on enter',
        'keyboard',
      ],
    ),
    SettingsToggleNode(
      id: 'auto_download_wifi',
      parentNavId: 'chats',
      title: (AppLocalizations l) => l.settingsChatsAutoDownloadWifi,
      subtitle: (AppLocalizations l) => l.settingsChatsAutoDownloadWifiDesc,
      icon: Icons.wifi_rounded,
      group: SettingsGroup.chats,
      valueSelector: (UiSettingsState s) => s.autoDownloadWifi,
      onChanged: (WidgetRef ref, bool v) =>
          ref.read(uiSettingsProvider.notifier).setAutoDownloadWifi(v),
      keywords: const <String>[
        'автозагрузка wifi',
        'вайфай',
        'скачивание',
        'медиа',
        'трафик',
        'wifi download',
      ],
    ),
    SettingsToggleNode(
      id: 'auto_download_cellular',
      parentNavId: 'chats',
      title: (AppLocalizations l) => l.settingsChatsAutoDownloadCellular,
      subtitle: (AppLocalizations l) => l.settingsChatsAutoDownloadCellularDesc,
      icon: Icons.signal_cellular_alt_rounded,
      group: SettingsGroup.chats,
      valueSelector: (UiSettingsState s) => s.autoDownloadCellular,
      onChanged: (WidgetRef ref, bool v) =>
          ref.read(uiSettingsProvider.notifier).setAutoDownloadCellular(v),
      keywords: const <String>[
        'мобильная сеть',
        'сотовая сеть',
        'автозагрузка сотовая',
        'трафик',
        'cellular download',
      ],
    ),

    // Notifications items
    SettingsToggleNode(
      id: 'push_notifications',
      parentNavId: 'notifications',
      title: (AppLocalizations l) => 'Push-уведомления',
      subtitle: (AppLocalizations l) => 'Всплывающие оповещения о новых сообщениях',
      icon: Icons.notifications_active_rounded,
      group: SettingsGroup.notifications,
      valueSelector: (UiSettingsState s) => s.notifications,
      onChanged: (WidgetRef ref, bool v) =>
          ref.read(uiSettingsProvider.notifier).setNotifications(v),
      keywords: const <String>[
        'уведомления',
        'пуши',
        'оповещения',
        'push',
        'notifications',
      ],
    ),
    SettingsSliderNode(
      id: 'sound_volume',
      parentNavId: 'notifications',
      title: (AppLocalizations l) => 'Громкость звуков',
      subtitle: (AppLocalizations l) => 'Уровень громкости уведомлений и эффектов',
      icon: Icons.volume_up_rounded,
      group: SettingsGroup.notifications,
      min: 0.0,
      max: 1.0,
      divisions: 10,
      unit: '%',
      valueSelector: (UiSettingsState s) => s.soundVolume,
      onChanged: (WidgetRef ref, double v) =>
          ref.read(uiSettingsProvider.notifier).setSoundVolume(v),
      keywords: const <String>[
        'громкость',
        'звук',
        'тишина',
        'volume',
        'sound',
      ],
    ),

    // Privacy & Security items
    SettingsToggleNode(
      id: 'hide_online',
      parentNavId: 'privacy',
      title: (AppLocalizations l) => 'Скрывать статус онлайн',
      subtitle: (AppLocalizations l) => 'Не показывать собеседникам ваше присутствие в сети',
      icon: Icons.visibility_off_rounded,
      group: SettingsGroup.privacy,
      valueSelector: (UiSettingsState s) => s.hideOnline,
      onChanged: (WidgetRef ref, bool v) =>
          ref.read(uiSettingsProvider.notifier).setHideOnline(v),
      keywords: const <String>[
        'онлайн',
        'скрывать онлайн',
        'активность',
        'last seen',
        'online',
        'invisible',
      ],
    ),
    SettingsNavNode(
      id: 'blocked_users',
      parentNavId: 'privacy',
      title: (AppLocalizations l) => 'Чёрный список',
      subtitle: (AppLocalizations l) => 'Заблокированные пользователи',
      icon: Icons.block_rounded,
      group: SettingsGroup.privacy,
      route: '/settings/privacy/blocked-users',
      keywords: const <String>[
        'черный список',
        'заблокированные',
        'бан',
        'blocklist',
        'blocked',
      ],
    ),
    SettingsNavNode(
      id: 'e2ee_security',
      parentNavId: 'privacy',
      title: (AppLocalizations l) => 'Сквозное шифрование E2EE',
      subtitle: (AppLocalizations l) => 'Ключи безопасности и секретные чаты',
      icon: Icons.lock_outline_rounded,
      group: SettingsGroup.privacy,
      route: '/settings/e2ee',
      sectionId: SettingsSectionId.e2ee,
      keywords: const <String>[
        'e2ee',
        'шифрование',
        'сквозное шифрование',
        'ключи',
        'секретные чаты',
        'encryption',
      ],
    ),
    SettingsNavNode(
      id: 'sessions_management',
      parentNavId: 'privacy',
      title: (AppLocalizations l) => 'Активные сессии',
      subtitle: (AppLocalizations l) => 'Устройства и браузеры с доступом к аккаунту',
      icon: Icons.devices_rounded,
      group: SettingsGroup.privacy,
      route: '/settings/sessions',
      sectionId: SettingsSectionId.sessions,
      keywords: const <String>[
        'сессии',
        'устройства',
        'компьютеры',
        'входы',
        'sessions',
        'devices',
      ],
    ),

    // Storage items
    SettingsNavNode(
      id: 'cache_cleaning',
      parentNavId: 'storage',
      title: (AppLocalizations l) => 'Очистить кэш медиа',
      subtitle: (AppLocalizations l) => 'Очистка загруженных фото, аудио и превью',
      icon: Icons.cleaning_services_rounded,
      group: SettingsGroup.storage,
      route: '/settings/storage',
      sectionId: SettingsSectionId.storage,
      keywords: const <String>[
        'кэш',
        'очистка',
        'удалить временные файлы',
        'память',
        'cache',
        'clear',
      ],
    ),
  ];

  /// Returns all top-level sections that are available in current runtime environment.
  static List<SettingsNavNode> getTopLevelSections() {
    return _topLevelSections.where((SettingsNavNode node) => node.isAvailable()).toList();
  }

  /// Resolves the parent top-level section for any node id.
  static SettingsNavNode? getParentSection(String parentNavId) {
    for (final SettingsNavNode s in _topLevelSections) {
      if (s.id == parentNavId) return s;
    }
    return null;
  }

  /// Performs fast, localized, tokenized search across all sections and child items.
  static List<SettingsSearchResult> search(String query, AppLocalizations l10n) {
    final String cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return const <SettingsSearchResult>[];

    final List<SettingsSearchResult> results = <SettingsSearchResult>[];
    final List<String> queryTokens = cleanQuery.split(RegExp(r'\s+'));

    // Check top level sections
    for (final SettingsNavNode topNode in _topLevelSections) {
      if (!topNode.isAvailable()) continue;
      final String title = topNode.title(l10n);
      final String? subtitle = topNode.subtitle?.call(l10n);
      final double score = _calculateMatchScore(
        cleanQuery,
        queryTokens,
        title,
        subtitle,
        topNode.keywords,
      );

      if (score > 0) {
        results.add(
          SettingsSearchResult(
            node: topNode,
            title: title,
            subtitle: subtitle,
            breadcrumb: topNode.group.localizedTitle(l10n),
            targetRoute: topNode.route,
            targetSectionId: topNode.sectionId,
            score: score + 10.0, // Slight boost for top-level hubs
          ),
        );
      }
    }

    // Check child items
    for (final SettingsNode childNode in _searchableChildren) {
      if (!childNode.isAvailable()) continue;
      final String title = childNode.title(l10n);
      final String? subtitle = childNode.subtitle?.call(l10n);
      final double score = _calculateMatchScore(
        cleanQuery,
        queryTokens,
        title,
        subtitle,
        childNode.keywords,
      );

      if (score > 0) {
        final SettingsNavNode? parent = childNode.parentNavId != null
            ? getParentSection(childNode.parentNavId!)
            : null;
        final String route = parent?.route ?? '/settings';
        final SettingsSectionId? sectionId = parent?.sectionId;
        final String parentTitle = parent != null ? parent.title(l10n) : childNode.group.localizedTitle(l10n);

        results.add(
          SettingsSearchResult(
            node: childNode,
            title: title,
            subtitle: subtitle,
            breadcrumb: '$parentTitle › $title',
            targetRoute: route,
            targetSectionId: sectionId,
            score: score,
          ),
        );
      }
    }

    results.sort((SettingsSearchResult a, SettingsSearchResult b) => b.score.compareTo(a.score));
    return results;
  }

  static double _calculateMatchScore(
    String fullQuery,
    List<String> tokens,
    String title,
    String? subtitle,
    List<String> keywords,
  ) {
    final String lowerTitle = title.toLowerCase();
    final String lowerSub = subtitle?.toLowerCase() ?? '';

    // Exact title match
    if (lowerTitle == fullQuery) return 100.0;

    // Title starts with query
    if (lowerTitle.startsWith(fullQuery)) return 85.0;

    // Title contains query
    if (lowerTitle.contains(fullQuery)) return 70.0;

    // Keyword match
    for (final String kw in keywords) {
      final String lowerKw = kw.toLowerCase();
      if (lowerKw == fullQuery) return 80.0;
      if (lowerKw.contains(fullQuery)) return 60.0;
    }

    // Subtitle contains query
    if (lowerSub.contains(fullQuery)) return 40.0;

    // Token matching
    int matchedTokens = 0;
    for (final String t in tokens) {
      if (lowerTitle.contains(t) ||
          lowerSub.contains(t) ||
          keywords.any((String k) => k.toLowerCase().contains(t))) {
        matchedTokens++;
      }
    }

    if (matchedTokens == tokens.length && tokens.isNotEmpty) {
      return 50.0;
    }

    return 0.0;
  }
}
