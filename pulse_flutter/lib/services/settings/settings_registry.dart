import 'package:pulse_flutter/core/localization/secret_chat_l10n.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/settings/settings_node.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/services/settings/notification_preference_action.dart';

/// Search match result with full breadcrumb path and navigation target.
class SettingsSearchResult {
  const SettingsSearchResult({
    required this.node,
    required this.title,
    this.subtitle,
    required this.breadcrumb,
    required this.targetRoute,
    this.targetSectionId,
    this.anchor,
    required this.score,
  });

  final SettingsNode node;
  final String title;
  final String? subtitle;
  final String breadcrumb;
  final String targetRoute;
  final SettingsSectionId? targetSectionId;
  final String? anchor;
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
      title: (AppLocalizations l) => l.settingsV2Appearance,
      subtitle: (AppLocalizations l) => l.settingsV2AppearanceHint,
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
      ],
    ),

    // 3. Chats & Media
    SettingsNavNode(
      id: 'chats',
      title: (AppLocalizations l) => l.settingsV2Chats,
      subtitle: (AppLocalizations l) => l.settingsV2ChatsHint,
      icon: Icons.chat_bubble_outline_rounded,
      group: SettingsGroup.chats,
      route: '/settings/chats',
      sectionId: SettingsSectionId.chats,
      keywords: const <String>[
        'чаты',
        'медиа',
        'автозагрузка',
        'вайфай',
        'камера',
        'enter',
        'chats',
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
      title: (AppLocalizations l) => l.settingsV2Notifications,
      subtitle: (AppLocalizations l) => l.settingsV2NotificationsHint,
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
      title: (AppLocalizations l) => l.settingsV2Privacy,
      subtitle: (AppLocalizations l) => l.settingsV2PrivacyHint,
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
      title: (AppLocalizations l) => l.settingsV2Storage,
      subtitle: (AppLocalizations l) => l.settingsV2StorageHint,
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
      title: (AppLocalizations l) => l.settingsV2Language,
      subtitle: (AppLocalizations l) => l.settingsV2LanguageHint,
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

    // 9. Energy Saving
    SettingsNavNode(
      id: 'energy_saving',
      title: (AppLocalizations l) =>
          kIsWeb ? l.webMotionTitle : l.settingsV2Motion,
      subtitle: (AppLocalizations l) => l.settingsV2MotionHint,
      icon: Icons.battery_saver_rounded,
      group: SettingsGroup.motion,
      route: '/settings/energy-saving',
      sectionId: SettingsSectionId.energySaving,
      keywords: const <String>[
        'энергосбережение',
        'батарея',
        'аккумулятор',
        'анимации',
        'стикеры',
        'эмодзи',
        'battery',
        'energy',
        'power',
        'save',
        'animation',
      ],
    ),

    // 10. Nios Plus & AI
    SettingsNavNode(
      id: 'plus',
      title: (AppLocalizations l) => 'Nios Plus & AI',
      subtitle: (AppLocalizations l) =>
          'Подписка, расширенные лимиты ИИ и файлы до 100 МБ',
      icon: Icons.stars_rounded,
      group: SettingsGroup.plus,
      route: '/settings/plus',
      sectionId: SettingsSectionId.plus,
      keywords: const <String>[
        'plus',
        'nios plus',
        'премиум',
        'подписка',
        'ии',
        'ai',
        'триал',
        'trial',
        'premium',
        'лимиты',
      ],
    ),

    // 11. About App
    SettingsNavNode(
      id: 'about',
      title: (AppLocalizations l) => l.settingsV2About,
      subtitle: (AppLocalizations l) => l.settingsV2AboutHint,
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
    SettingsChoiceNode<AppFontScale>(
      id: 'font_scale',
      parentNavId: 'appearance',
      title: (AppLocalizations l) => l.appearanceFontSize,
      subtitle: (AppLocalizations l) => l.appearanceFontSizeSubtitle,
      icon: Icons.format_size_rounded,
      group: SettingsGroup.appearance,
      options: AppFontScale.values,
      optionLabel: (AppFontScale scale, AppLocalizations l) =>
          '${(scale.scale * 100).toInt()}%',
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
      id: 'system_dynamic_colors',
      availability: () => !kIsWeb,
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

    // Chats items
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
      parentNavId: 'storage',
      title: (AppLocalizations l) =>
          kIsWeb ? l.webAutoDownload : l.settingsChatsAutoDownloadWifi,
      subtitle: (AppLocalizations l) => l.settingsChatsAutoDownloadWifiDesc,
      icon: Icons.wifi_rounded,
      group: SettingsGroup.storage,
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
      availability: () => !kIsWeb,
      parentNavId: 'storage',
      title: (AppLocalizations l) => l.settingsChatsAutoDownloadCellular,
      subtitle: (AppLocalizations l) => l.settingsChatsAutoDownloadCellularDesc,
      icon: Icons.signal_cellular_alt_rounded,
      group: SettingsGroup.storage,
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
      title: (AppLocalizations l) => l.settingsPushNotifications,
      subtitle: (AppLocalizations l) => l.settingsPushNotificationsSubtitle,
      icon: Icons.notifications_active_rounded,
      group: SettingsGroup.notifications,
      valueSelector: (UiSettingsState s) => s.notifications,
      onChanged: (WidgetRef ref, bool v) async {
        await updateNotificationPreference(ref, v);
      },
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
      title: (AppLocalizations l) => l.settingsVolume,
      subtitle: (AppLocalizations l) => l.noticeUiSoundsHint,
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
    SettingsNavNode(
      id: 'privacy.lastSeen',
      parentNavId: 'privacy',
      title: (l) => l.privacyRuleLastSeen,
      icon: Icons.visibility_outlined,
      group: SettingsGroup.privacy,
      route: '/settings/privacy',
      sectionId: SettingsSectionId.privacy,
      keywords: [
        'онлайн',
        'скрывать онлайн',
        'online',
        'last seen',
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
      subtitle: (AppLocalizations l) =>
          'Устройства и браузеры с доступом к аккаунту',
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
      subtitle: (AppLocalizations l) =>
          'Очистка загруженных фото, аудио и превью',
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
    SettingsNavNode(
      id: 'chats.callDevices',
      parentNavId: 'chats',
      title: (l) => l.callDevicesTitle,
      icon: Icons.headset_mic_rounded,
      group: SettingsGroup.chats,
      route: '/settings/chats',
      sectionId: SettingsSectionId.chats,
      keywords: [
        "микрофон",
        "камера",
        "наушники",
        "microphone",
        "camera",
        "headphones",
        "speaker",
      ],
    ),
    SettingsNavNode(
      id: 'appearance.compact',
      parentNavId: 'appearance',
      title: (l) => l.appearanceCompactMode,
      icon: Icons.density_small_rounded,
      group: SettingsGroup.appearance,
      route: '/settings/appearance',
      sectionId: SettingsSectionId.appearance,
      keywords: ["плотность", "компактность", "compact", "density"],
    ),
    SettingsNavNode(
      id: 'motion.optimization',
      parentNavId: 'energy_saving',
      title: (l) => l.appearanceOptimizeWeakDevices,
      icon: Icons.speed_rounded,
      group: SettingsGroup.motion,
      route: '/settings/energy-saving',
      sectionId: SettingsSectionId.energySaving,
      keywords: ["оптимизация", "fps", "слабые", "performance", "optimize"],
    ),
    SettingsNavNode(
      id: 'notifications.preview',
      parentNavId: 'notifications',
      title: (l) => l.settingsV2Preview,
      icon: Icons.visibility_outlined,
      group: SettingsGroup.notifications,
      route: '/settings/preferences',
      sectionId: SettingsSectionId.preferences,
      keywords: ["превью", "текст уведомления", "preview"],
    ),
    SettingsNavNode(
      id: 'security.twoFactor',
      parentNavId: 'privacy',
      title: (l) => l.settingsTwoFactor,
      icon: Icons.key_outlined,
      group: SettingsGroup.privacy,
      route: '/settings/privacy',
      sectionId: SettingsSectionId.privacy,
      keywords: ['2fa', 'двухэтапная', 'пароль', 'two factor', 'password'],
    ),
    SettingsNavNode(
      id: 'motion.stickers',
      parentNavId: 'energy_saving',
      title: (l) => l.settingsV2Stickers,
      icon: Icons.sticky_note_2_outlined,
      group: SettingsGroup.motion,
      route: '/settings/energy-saving',
      sectionId: SettingsSectionId.energySaving,
      keywords: [
        'стикеры',
        'анимация стикеров',
        'stickers',
        'animated stickers',
      ],
    ),
    SettingsNavNode(
      id: 'motion.emoji',
      parentNavId: 'energy_saving',
      title: (l) => l.settingsV2Emoji,
      icon: Icons.emoji_emotions_outlined,
      group: SettingsGroup.motion,
      route: '/settings/energy-saving',
      sectionId: SettingsSectionId.energySaving,
      keywords: ['эмодзи', 'анимация эмодзи', 'emoji', 'animated emoji'],
    ),
    SettingsNavNode(
      id: 'security.appLock.enabled',
      availability: () => !kIsWeb,
      parentNavId: 'privacy',
      title: (l) => l.biometricTitle,
      icon: Icons.fingerprint_rounded,
      group: SettingsGroup.privacy,
      route: '/settings/privacy',
      sectionId: SettingsSectionId.privacy,
      keywords: ["блокировка", "биометрия", "lock", "fingerprint"],
    ),
    SettingsNavNode(
      id: 'privacy.messaging.readReceipts',
      parentNavId: 'privacy',
      title: (l) => l.settingsV2ReadReceipts,
      icon: Icons.done_all_rounded,
      group: SettingsGroup.privacy,
      route: '/settings/privacy',
      sectionId: SettingsSectionId.privacy,
      keywords: ["прочтение", "прочитано", "read receipts"],
    ),
    SettingsNavNode(
      id: 'privacy.messaging.typingIndicators',
      parentNavId: 'privacy',
      title: (l) => l.settingsV2Typing,
      icon: Icons.keyboard_outlined,
      group: SettingsGroup.privacy,
      route: '/settings/privacy',
      sectionId: SettingsSectionId.privacy,
      keywords: ["набор", "печатает", "typing"],
    ),
  ];

  /// Returns all top-level sections that are available in current runtime environment.
  static List<SettingsNavNode> getTopLevelSections() {
    return _topLevelSections
        .where(
          (SettingsNavNode node) =>
              node.isAvailable() &&
              node.id != 'account' &&
              node.id != 'system_device',
        )
        .toList();
  }

  /// Returns all registered nodes (sections and child items).
  static List<SettingsNode> getAllNodes() {
    return <SettingsNode>[..._topLevelSections, ..._searchableChildren];
  }

  /// Resolves the parent top-level section for any node id.
  static SettingsNavNode? getParentSection(String parentNavId) {
    for (final SettingsNavNode s in _topLevelSections) {
      if (s.id == parentNavId) return s;
    }
    return null;
  }

  /// Performs fast, localized, tokenized search across all sections and child items.
  static List<SettingsSearchResult> search(
    String query,
    AppLocalizations l10n,
  ) {
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
        final String route =
            (childNode is SettingsNavNode && childNode.route.isNotEmpty)
            ? childNode.route
            : (parent?.route ?? '/settings');
        final SettingsSectionId? sectionId =
            (childNode is SettingsNavNode && childNode.sectionId != null)
            ? childNode.sectionId
            : parent?.sectionId;
        final String parentTitle = parent != null
            ? parent.title(l10n)
            : childNode.group.localizedTitle(l10n);

        results.add(
          SettingsSearchResult(
            node: childNode,
            title: title,
            subtitle: subtitle,
            breadcrumb: '$parentTitle › $title',
            targetRoute: route,
            targetSectionId: sectionId,
            anchor: switch (childNode.id) {
              'send_on_enter' => 'chats.sendOnEnter',
              'font_scale' => 'appearance.font.scale',
              'system_dynamic_colors' => 'appearance.color.source',
              'blocked_users' => 'privacy.blockedUsers',
              'sessions_management' => 'security.sessions.active',
              _ => childNode.id,
            },
            score: score,
          ),
        );
      }
    }

    results.sort(
      (SettingsSearchResult a, SettingsSearchResult b) =>
          b.score.compareTo(a.score),
    );
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
