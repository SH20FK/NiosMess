import 'package:pulse_flutter/core/localization/secret_chat_l10n.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/settings/settings_node.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';

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
        'камера',
        'enter',
        'chats',
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
      route: '/settings/notifications',
      sectionId: SettingsSectionId.notifications,
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
        'фон',
        'батарея',
        'энергосбережение',
        'background',
        'battery',
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
        'e2ee',
        'шифрование',
        'биометрия',
        'privacy',
        'security',
        'last seen',
        'blocklist',
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
      title: (AppLocalizations l) => l.settingsDeviceTitle,
      subtitle: (AppLocalizations l) => l.settingsDeviceSpecs,
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

    // Devices: the sessions signed in to this account.
    SettingsNavNode(
      id: 'devices',
      title: (AppLocalizations l) => l.settingsDevicesTitle,
      subtitle: (AppLocalizations l) => l.settingsActiveSessionsSubtitle,
      icon: Icons.devices_rounded,
      group: SettingsGroup.privacy,
      route: '/settings/sessions',
      sectionId: SettingsSectionId.sessions,
      keywords: const <String>[
        'сеансы',
        'сессии',
        'устройства',
        'компьютеры',
        'входы',
        'sessions',
        'devices',
      ],
    ),

    // 10. Nios Plus & AI
    SettingsNavNode(
      id: 'plus',
      title: (AppLocalizations l) => 'Nios+',
      subtitle: (AppLocalizations l) => l.settingsPlusSummary,
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
    // The corner radii live on the shape sub-screen: the node points at it,
    // and its anchor keeps the row id so search still highlights the slider.
    SettingsNavNode(
      id: 'ui_corner_radius',
      parentNavId: 'appearance',
      title: (AppLocalizations l) => l.appearanceUiRounding,
      subtitle: (AppLocalizations l) => l.appearanceUiRoundingDesc,
      icon: Icons.rounded_corner_rounded,
      group: SettingsGroup.appearance,
      route: '/settings/appearance/shape',
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
    SettingsItemNode(
      id: 'appearance.font.scale',
      parentNavId: 'appearance',
      title: (AppLocalizations l) => l.appearanceFontSize,
      subtitle: (AppLocalizations l) => l.appearanceFontSizeSubtitle,
      icon: Icons.format_size_rounded,
      group: SettingsGroup.appearance,
      keywords: const <String>[
        'шрифт',
        'текст',
        'размер шрифта',
        'масштаб',
        'font scale',
        'text size',
      ],
    ),

    // The system-colours toggle lives on the accent sub-screen now; the node
    // keeps the row id as its anchor and the web-unavailability it had.
    SettingsNavNode(
      id: 'appearance.color.source',
      availability: () => !kIsWeb,
      parentNavId: 'appearance',
      title: (AppLocalizations l) => l.appearanceSystemColors,
      subtitle: (AppLocalizations l) => l.appearanceSystemColorsSubtitle,
      icon: Icons.auto_awesome_rounded,
      group: SettingsGroup.appearance,
      route: '/settings/appearance/accent',
      keywords: const <String>[
        'динамические цвета',
        'системные цвета',
        'палитра android',
        'dynamic colors',
      ],
    ),

    // Chats items
    SettingsItemNode(
      id: 'chats.sendOnEnter',
      parentNavId: 'chats',
      title: (AppLocalizations l) => l.settingsChatsSendOnEnter,
      subtitle: (AppLocalizations l) => l.settingsChatsSendOnEnterDesc,
      icon: Icons.keyboard_return_rounded,
      group: SettingsGroup.chats,
      keywords: const <String>[
        'enter',
        'отправка',
        'клавиатура',
        'send on enter',
        'keyboard',
      ],
    ),
    // The 2×2 auto-download matrix of the storage screen: one row per media
    // type and network, so a search says which of the four switches it means.
    // The browser has no cellular rule, so its rows and nodes stay hidden.
    SettingsItemNode(
      id: 'auto_download_wifi',
      parentNavId: 'storage',
      title: (AppLocalizations l) => l.settingsV2StorageImages,
      subtitle: (AppLocalizations l) => l.settingsV2Wifi,
      icon: Icons.image_rounded,
      group: SettingsGroup.storage,
      keywords: const <String>[
        'автозагрузка фото',
        'фото',
        'вайфай',
        'скачивание',
        'медиа',
        'трафик',
        'photo download',
        'wifi download',
      ],
    ),
    SettingsItemNode(
      id: 'auto_download_cellular',
      availability: () => !kIsWeb,
      parentNavId: 'storage',
      title: (AppLocalizations l) => l.settingsV2StorageImages,
      subtitle: (AppLocalizations l) => l.settingsV2MobileData,
      icon: Icons.image_rounded,
      group: SettingsGroup.storage,
      keywords: const <String>[
        'автозагрузка фото',
        'фото',
        'мобильная сеть',
        'сотовая',
        'скачивание',
        'медиа',
        'трафик',
        'photo download',
        'cellular download',
      ],
    ),
    SettingsItemNode(
      id: 'auto_download_video_wifi',
      parentNavId: 'storage',
      title: (AppLocalizations l) => l.settingsV2StorageVideos,
      subtitle: (AppLocalizations l) => l.settingsV2Wifi,
      icon: Icons.video_library_rounded,
      group: SettingsGroup.storage,
      keywords: const <String>[
        'автозагрузка видео',
        'видео',
        'вайфай',
        'скачивание видео',
        'медиа',
        'трафик',
        'video download',
        'video wifi download',
      ],
    ),
    SettingsItemNode(
      id: 'auto_download_video_cellular',
      availability: () => !kIsWeb,
      parentNavId: 'storage',
      title: (AppLocalizations l) => l.settingsV2StorageVideos,
      subtitle: (AppLocalizations l) => l.settingsV2MobileData,
      icon: Icons.video_library_rounded,
      group: SettingsGroup.storage,
      keywords: const <String>[
        'автозагрузка видео',
        'видео',
        'мобильная сеть',
        'сотовая',
        'скачивание видео',
        'медиа',
        'трафик',
        'video download',
        'video cellular download',
      ],
    ),

    // Notifications items
    SettingsItemNode(
      id: 'push_notifications',
      parentNavId: 'notifications',
      title: (AppLocalizations l) => l.settingsPushNotifications,
      subtitle: (AppLocalizations l) => l.settingsPushNotificationsSubtitle,
      icon: Icons.notifications_active_rounded,
      group: SettingsGroup.notifications,
      keywords: const <String>[
        'уведомления',
        'пуши',
        'оповещения',
        'push',
        'notifications',
      ],
    ),
    SettingsItemNode(
      id: 'sound_volume',
      parentNavId: 'notifications',
      title: (AppLocalizations l) => l.settingsVolume,
      subtitle: (AppLocalizations l) => l.noticeUiSoundsHint,
      icon: Icons.volume_up_rounded,
      group: SettingsGroup.notifications,
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
    // The blocked list is a screen of its own, not a row on the Privacy page,
    // so search opens the list instead of pointing at a row that is not there.
    SettingsNavNode(
      id: 'privacy.blockedUsers',
      parentNavId: 'privacy',
      anchorless: true,
      title: (AppLocalizations l) => l.privacyBlacklist,
      subtitle: (AppLocalizations l) => l.blockedUsersTitle,
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
      title: (AppLocalizations l) => l.settingsSecretChatsTitle,
      subtitle: (AppLocalizations l) => l.settingsSecretChatsSubtitle,
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
    // Storage items
    SettingsNavNode(
      id: 'cache_cleaning',
      parentNavId: 'storage',
      title: (AppLocalizations l) => l.settingsStorageClearTemporary,
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
    // Moved to the chats screen together with their rows: the parent and the
    // group follow the move, and the old row ids stay as anchors so search
    // deep links still highlight the relocated controls.
    SettingsNavNode(
      id: 'appearance.compact',
      parentNavId: 'chats',
      title: (l) => l.appearanceCompactMode,
      icon: Icons.density_small_rounded,
      group: SettingsGroup.chats,
      route: '/settings/chats',
      keywords: ["плотность", "компактность", "compact", "density"],
    ),
    SettingsNavNode(
      id: 'appearance.wallpaper',
      parentNavId: 'chats',
      title: (l) => l.appearanceChatWallpaperTitle,
      icon: Icons.texture_rounded,
      group: SettingsGroup.chats,
      route: '/settings/chats',
      keywords: ['обои', 'фон чата', 'узор', 'wallpaper', 'background'],
    ),
    // Account items
    SettingsItemNode(
      id: 'account.password',
      parentNavId: 'account',
      title: (AppLocalizations l) => l.settingsPasswordEntry,
      subtitle: (AppLocalizations l) => l.settingsPasswordEntryHint,
      icon: Icons.password_rounded,
      group: SettingsGroup.account,
      keywords: const <String>[
        'пароль',
        'сброс пароля',
        'изменить пароль',
        'код с почты',
        'password',
      ],
    ),
    SettingsNavNode(
      id: 'account.delete',
      parentNavId: 'account',
      title: (l) => l.accountDeleteEntry,
      icon: Icons.delete_forever_outlined,
      group: SettingsGroup.account,
      route: '/settings/account',
      sectionId: SettingsSectionId.account,
      keywords: [
        'удалить аккаунт',
        'удаление аккаунта',
        'отменить удаление',
        'delete account',
        'cancel deletion',
      ],
    ),
    SettingsNavNode(
      id: 'storage.reset',
      parentNavId: 'storage',
      title: (l) => l.settingsV2Reset,
      icon: Icons.restart_alt_rounded,
      group: SettingsGroup.storage,
      route: '/settings/storage',
      sectionId: SettingsSectionId.storage,
      keywords: [
        'сброс',
        'сбросить настройки',
        'по умолчанию',
        'reset',
        'defaults',
      ],
    ),
    SettingsNavNode(
      id: 'motion.optimization',
      parentNavId: 'storage',
      title: (l) => l.appearanceOptimizeWeakDevices,
      icon: Icons.speed_rounded,
      group: SettingsGroup.storage,
      route: '/settings/storage',
      sectionId: SettingsSectionId.storage,
      keywords: ["оптимизация", "fps", "слабые", "performance", "optimize"],
    ),
    SettingsNavNode(
      id: 'notifications.preview',
      parentNavId: 'notifications',
      title: (l) => l.settingsV2Preview,
      icon: Icons.visibility_outlined,
      group: SettingsGroup.notifications,
      route: '/settings/notifications',
      sectionId: SettingsSectionId.notifications,
      keywords: ["превью", "текст уведомления", "preview"],
    ),
    // The guards under security: the rows live on the security screen now,
    // so the route leads there; the section stays Privacy, which is where a
    // two-pane layout opens them.
    SettingsNavNode(
      id: 'security.niosId',
      parentNavId: 'privacy',
      title: (l) => l.settingsNiosIdSecurity,
      icon: Icons.shield_outlined,
      group: SettingsGroup.privacy,
      route: '/settings/security',
      sectionId: SettingsSectionId.privacy,
      keywords: [
        'пароль',
        'безопасность аккаунта',
        'nios id',
        'password',
        'account security',
      ],
    ),
    SettingsNavNode(
      id: 'motion.stickers',
      parentNavId: 'chats',
      title: (l) => l.settingsV2Stickers,
      icon: Icons.sticky_note_2_outlined,
      group: SettingsGroup.chats,
      route: '/settings/chats',
      sectionId: SettingsSectionId.chats,
      keywords: [
        'стикеры',
        'анимация стикеров',
        'stickers',
        'animated stickers',
      ],
    ),
    SettingsNavNode(
      id: 'motion.emoji',
      parentNavId: 'chats',
      title: (l) => l.settingsV2Emoji,
      icon: Icons.emoji_emotions_outlined,
      group: SettingsGroup.chats,
      route: '/settings/chats',
      sectionId: SettingsSectionId.chats,
      keywords: ['эмодзи', 'анимация эмодзи', 'emoji', 'animated emoji'],
    ),
    SettingsNavNode(
      id: 'security.appLock.enabled',
      availability: () => !kIsWeb,
      parentNavId: 'privacy',
      title: (l) => l.biometricTitle,
      icon: Icons.fingerprint_rounded,
      group: SettingsGroup.privacy,
      route: '/settings/security',
      sectionId: SettingsSectionId.privacy,
      keywords: ["блокировка", "биометрия", "lock", "fingerprint"],
    ),
    // The timeout unfolds under the app-lock switch it depends on.
    SettingsNavNode(
      id: 'security.appLock.timeout',
      availability: () => !kIsWeb,
      parentNavId: 'privacy',
      title: (l) => l.settingsV2LockTimeout,
      subtitle: (l) => l.settingsV2LockTimeoutHint,
      icon: Icons.timer_outlined,
      group: SettingsGroup.privacy,
      route: '/settings/security',
      sectionId: SettingsSectionId.privacy,
      keywords: ["таймаут", "время блокировки", "timeout", "lock"],
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
    // The store is a page, not a row: plans, checkout and activation. Search
    // opens the page itself, so it carries no anchor.
    SettingsNavNode(
      id: 'plus.store',
      parentNavId: 'plus',
      anchorless: true,
      title: (l) => l.auditPlusPurchaseTitle,
      subtitle: (l) => l.settingsPlusSummary,
      icon: Icons.storefront_rounded,
      group: SettingsGroup.plus,
      route: '/settings/plus/store',
      keywords: [
        'магазин',
        'купить подписку',
        'активация',
        'оплата',
        'store',
        'purchase',
        'checkout',
      ],
    ),
  ];

  /// Rows of the settings hub, top to bottom. A section that is registered
  /// but not listed here (device diagnostics, Nios+) is reached from another
  /// one; the hub itself is grouped by the screen that renders it.
  static const List<String> _hubOrder = <String>[
    'account',
    'devices',
    'appearance',
    'chats',
    'notifications',
    'privacy',
    'storage',
    'language',
    'about',
  ];

  /// The hub rows available in the current runtime environment.
  static List<SettingsNavNode> getTopLevelSections() {
    return <SettingsNavNode>[
      for (final String id in _hubOrder)
        ..._topLevelSections.where(
          (SettingsNavNode node) => node.id == id && node.isAvailable(),
        ),
    ];
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
        // A node with its own section opens that screen, and an anchorless
        // node opens a page without rows: in both cases there is no row to
        // highlight.
        final bool noRowAnchor =
            childNode is SettingsNavNode &&
            (childNode.anchorless ||
                (childNode.sectionId != null &&
                    childNode.sectionId != parent?.sectionId));
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
            // The id of a row is its anchor on the screen.
            anchor: noRowAnchor ? null : childNode.id,
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
