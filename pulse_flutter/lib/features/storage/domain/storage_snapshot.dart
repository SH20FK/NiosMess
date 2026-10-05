import 'package:flutter/foundation.dart';

enum StorageCategory {
  images,
  videos,
  audio,
  files,
  stickers,
  avatars,
  drafts,
  secretChatCache,
  other;

  String get labelRu {
    switch (this) {
      case StorageCategory.images:
        return 'Изображения';
      case StorageCategory.videos:
        return 'Видео';
      case StorageCategory.audio:
        return 'Аудио и голосовые';
      case StorageCategory.files:
        return 'Файлы и документы';
      case StorageCategory.stickers:
        return 'Стикеры';
      case StorageCategory.avatars:
        return 'Аватары';
      case StorageCategory.drafts:
        return 'Черновики';
      case StorageCategory.secretChatCache:
        return 'Секретные чаты';
      case StorageCategory.other:
        return 'Прочее';
    }
  }

  String get labelEn {
    switch (this) {
      case StorageCategory.images:
        return 'Images';
      case StorageCategory.videos:
        return 'Videos';
      case StorageCategory.audio:
        return 'Audio & Voice';
      case StorageCategory.files:
        return 'Files & Documents';
      case StorageCategory.stickers:
        return 'Stickers';
      case StorageCategory.avatars:
        return 'Avatars';
      case StorageCategory.drafts:
        return 'Drafts';
      case StorageCategory.secretChatCache:
        return 'Secret chats';
      case StorageCategory.other:
        return 'Other';
    }
  }

  static StorageCategory detectFromFilePath(String path) {
    final String lower = path.toLowerCase();

    if (lower.contains('avatar') || lower.contains('profile_photo')) {
      return StorageCategory.avatars;
    }
    if (lower.contains('sticker') || lower.endsWith('.tgs')) {
      return StorageCategory.stickers;
    }
    if (lower.contains('secret_chat') || lower.contains('encrypted_messages')) {
      return StorageCategory.secretChatCache;
    }

    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.bmp')) {
      return StorageCategory.images;
    }

    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.avi')) {
      return StorageCategory.videos;
    }

    if (lower.endsWith('.mp3') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.opus') ||
        lower.endsWith('.flac')) {
      return StorageCategory.audio;
    }

    if (lower.endsWith('.pdf') ||
        lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.zip') ||
        lower.endsWith('.tar') ||
        lower.endsWith('.gz') ||
        lower.endsWith('.apk') ||
        lower.endsWith('.txt')) {
      return StorageCategory.files;
    }

    return StorageCategory.other;
  }
}

@immutable
class DetailedStorageSnapshot {
  const DetailedStorageSnapshot({
    required this.categoryBytes,
    required this.documentsBytes,
    required this.supportBytes,
    required this.temporaryBytes,
    required this.draftBytes,
    required this.draftCount,
    required this.secretChatBytes,
  });

  const DetailedStorageSnapshot.empty()
      : categoryBytes = const <StorageCategory, int>{},
        documentsBytes = 0,
        supportBytes = 0,
        temporaryBytes = 0,
        draftBytes = 0,
        draftCount = 0,
        secretChatBytes = 0;

  final Map<StorageCategory, int> categoryBytes;
  final int documentsBytes;
  final int supportBytes;
  final int temporaryBytes;
  final int draftBytes;
  final int draftCount;
  final int secretChatBytes;

  int bytesFor(StorageCategory category) => categoryBytes[category] ?? 0;

  int get totalBytes {
    int sum = 0;
    for (final int b in categoryBytes.values) {
      sum += b;
    }
    return sum;
  }
}
