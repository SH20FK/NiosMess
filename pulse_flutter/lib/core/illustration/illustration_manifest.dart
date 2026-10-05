import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/illustration/illustration_asset.dart';

class IllustrationManifest {
  IllustrationManifest._();

  static const IllustrationAsset account = IllustrationAsset(
    id: 'account',
    assetPath: 'assets/svg/settings_account.svg',
    title: 'Аккаунт',
    fallbackIcon: Icons.person_rounded,
  );

  static const IllustrationAsset privacy = IllustrationAsset(
    id: 'privacy',
    assetPath: 'assets/svg/settings_privacy.svg',
    title: 'Конфиденциальность',
    fallbackIcon: Icons.lock_rounded,
  );

  static const IllustrationAsset storage = IllustrationAsset(
    id: 'storage',
    assetPath: 'assets/svg/settings_storage.svg',
    title: 'Хранилище',
    fallbackIcon: Icons.storage_rounded,
  );

  static const IllustrationAsset appearance = IllustrationAsset(
    id: 'appearance',
    assetPath: 'assets/svg/settings_appearance.svg',
    title: 'Оформление',
    fallbackIcon: Icons.palette_rounded,
  );

  static const IllustrationAsset language = IllustrationAsset(
    id: 'language',
    assetPath: 'assets/svg/settings_language.svg',
    title: 'Язык и регион',
    fallbackIcon: Icons.language_rounded,
  );

  static const IllustrationAsset preferences = IllustrationAsset(
    id: 'preferences',
    assetPath: 'assets/svg/settings_preferences.svg',
    title: 'Настройки чатов',
    fallbackIcon: Icons.tune_rounded,
  );

  static const IllustrationAsset sessions = IllustrationAsset(
    id: 'sessions',
    assetPath: 'assets/svg/settings_sessions.svg',
    title: 'Устройства и сессии',
    fallbackIcon: Icons.devices_rounded,
  );

  static const IllustrationAsset e2ee = IllustrationAsset(
    id: 'e2ee',
    assetPath: 'assets/svg/settings_e2ee.svg',
    title: 'Сквозное шифрование',
    fallbackIcon: Icons.enhanced_encryption_rounded,
  );

  static const IllustrationAsset about = IllustrationAsset(
    id: 'about',
    assetPath: 'assets/svg/settings_about.svg',
    title: 'О программе',
    fallbackIcon: Icons.info_outline_rounded,
  );

  static const IllustrationAsset emptyFeed = IllustrationAsset(
    id: 'empty_feed',
    assetPath: 'assets/svg/illustration_empty_feed.svg',
    title: 'Лента пуста',
    fallbackIcon: Icons.dynamic_feed_rounded,
    width: 180,
    height: 180,
  );

  static const IllustrationAsset mediaError = IllustrationAsset(
    id: 'media_error',
    assetPath: 'assets/svg/illustration_media_error.svg',
    title: 'Ошибка медиа',
    fallbackIcon: Icons.broken_image_rounded,
    width: 140,
    height: 140,
  );

  static const IllustrationAsset mediaPlaceholder = IllustrationAsset(
    id: 'media_placeholder',
    assetPath: 'assets/svg/illustration_media_placeholder.svg',
    title: 'Загрузка медиа',
    fallbackIcon: Icons.image_rounded,
    width: 140,
    height: 140,
  );

  static const List<IllustrationAsset> all = <IllustrationAsset>[
    account,
    privacy,
    storage,
    appearance,
    language,
    preferences,
    sessions,
    e2ee,
    about,
    emptyFeed,
    mediaError,
    mediaPlaceholder,
  ];

  static IllustrationAsset? findById(String id) {
    for (final IllustrationAsset asset in all) {
      if (asset.id == id) return asset;
    }
    return null;
  }
}
