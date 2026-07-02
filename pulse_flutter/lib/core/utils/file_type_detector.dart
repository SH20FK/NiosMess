import 'package:flutter/foundation.dart';

enum FileTypeCategory {
  image,
  video,
  audio,
  document,
  apk,
  exe,
  archive,
  text,
  code,
  unknown,
}

class FileTypeInfo {
  const FileTypeInfo({
    required this.category,
    required this.label,
    required this.icon,
    required this.color,
    required this.extensions,
    required this.mimeTypes,
  });

  final FileTypeCategory category;
  final String label;
  final String icon;
  final int color;
  final List<String> extensions;
  final List<String> mimeTypes;

  bool get canPreview =>
      category == FileTypeCategory.image ||
      category == FileTypeCategory.video ||
      category == FileTypeCategory.audio ||
      category == FileTypeCategory.document ||
      category == FileTypeCategory.text ||
      category == FileTypeCategory.code;

  bool get canPlay =>
      category == FileTypeCategory.video || category == FileTypeCategory.audio;

  bool get isImage => category == FileTypeCategory.image;

  bool get isVideo => category == FileTypeCategory.video;

  bool get isAudio => category == FileTypeCategory.audio;

  bool get isDocument => category == FileTypeCategory.document;

  bool get isPdf => extensions.contains('pdf');

  bool get isExecutable =>
      category == FileTypeCategory.apk || category == FileTypeCategory.exe;

  bool get isApk => category == FileTypeCategory.apk;

  bool get isExe => category == FileTypeCategory.exe;

  bool get canInstall =>
      category == FileTypeCategory.apk &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;

  bool get canOpen => category != FileTypeCategory.unknown;
}

class FileTypeDetector {
  static const Map<FileTypeCategory, FileTypeInfo> _typeMap = {
    FileTypeCategory.image: FileTypeInfo(
      category: FileTypeCategory.image,
      label: 'Image',
      icon: 'image',
      color: 0xFF4CAF50,
      extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg', 'ico'],
      mimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
    ),
    FileTypeCategory.video: FileTypeInfo(
      category: FileTypeCategory.video,
      label: 'Video',
      icon: 'videocam',
      color: 0xFFE91E63,
      extensions: ['mp4', 'avi', 'mov', 'mkv', 'webm', 'flv', 'wmv'],
      mimeTypes: ['video/mp4', 'video/x-msvideo', 'video/quicktime'],
    ),
    FileTypeCategory.audio: FileTypeInfo(
      category: FileTypeCategory.audio,
      label: 'Audio',
      icon: 'audiotrack',
      color: 0xFFFF9800,
      extensions: ['mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma'],
      mimeTypes: ['audio/mpeg', 'audio/wav', 'audio/aac'],
    ),
    FileTypeCategory.document: FileTypeInfo(
      category: FileTypeCategory.document,
      label: 'Document',
      icon: 'description',
      color: 0xFF2196F3,
      extensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt'],
      mimeTypes: [
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument',
      ],
    ),
    FileTypeCategory.apk: FileTypeInfo(
      category: FileTypeCategory.apk,
      label: 'APK',
      icon: 'android',
      color: 0xFF3DDC84,
      extensions: ['apk'],
      mimeTypes: ['application/vnd.android.package-archive'],
    ),
    FileTypeCategory.exe: FileTypeInfo(
      category: FileTypeCategory.exe,
      label: 'EXE',
      icon: 'desktop_windows',
      color: 0xFF607D8B,
      extensions: ['exe', 'msi'],
      mimeTypes: ['application/x-msdownload'],
    ),
    FileTypeCategory.archive: FileTypeInfo(
      category: FileTypeCategory.archive,
      label: 'Archive',
      icon: 'folder_zip',
      color: 0xFF795548,
      extensions: ['zip', 'rar', '7z', 'tar', 'gz', 'bz2'],
      mimeTypes: ['application/zip', 'application/x-rar-compressed'],
    ),
    FileTypeCategory.text: FileTypeInfo(
      category: FileTypeCategory.text,
      label: 'Text',
      icon: 'text_snippet',
      color: 0xFF9E9E9E,
      extensions: ['txt', 'rtf', 'md', 'log'],
      mimeTypes: ['text/plain', 'text/markdown'],
    ),
    FileTypeCategory.code: FileTypeInfo(
      category: FileTypeCategory.code,
      label: 'Code',
      icon: 'code',
      color: 0xFF673AB7,
      extensions: [
        'js',
        'ts',
        'dart',
        'py',
        'java',
        'cpp',
        'c',
        'html',
        'css',
        'json',
        'xml',
        'yaml',
        'yml',
      ],
      mimeTypes: [
        'application/javascript',
        'text/html',
        'text/css',
        'application/json',
      ],
    ),
    FileTypeCategory.unknown: FileTypeInfo(
      category: FileTypeCategory.unknown,
      label: 'File',
      icon: 'insert_drive_file',
      color: 0xFF9E9E9E,
      extensions: [],
      mimeTypes: [],
    ),
  };

  static FileTypeInfo detectFromFileName(String fileName) {
    final String extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';

    if (extension.isEmpty) {
      return _typeMap[FileTypeCategory.unknown]!;
    }

    for (final FileTypeInfo info in _typeMap.values) {
      if (info.extensions.contains(extension)) {
        return info;
      }
    }

    return _typeMap[FileTypeCategory.unknown]!;
  }

  static FileTypeInfo detectFromMimeType(String? mimeType) {
    if (mimeType == null || mimeType.isEmpty) {
      return _typeMap[FileTypeCategory.unknown]!;
    }

    for (final FileTypeInfo info in _typeMap.values) {
      if (info.mimeTypes.any((mt) => mimeType.startsWith(mt))) {
        return info;
      }
    }

    return _typeMap[FileTypeCategory.unknown]!;
  }

  static FileTypeInfo detect({
    required String fileName,
    String? mimeType,
    String? filePath,
  }) {
    if (mimeType != null && mimeType.isNotEmpty) {
      final FileTypeInfo fromMime = detectFromMimeType(mimeType);
      if (fromMime.category != FileTypeCategory.unknown) {
        return fromMime;
      }
    }

    final FileTypeInfo fromName = detectFromFileName(fileName);
    if (fromName.category != FileTypeCategory.unknown) {
      return fromName;
    }

    if (filePath != null && filePath.isNotEmpty) {
      final FileTypeInfo fromPath = detectFromFileName(filePath);
      if (fromPath.category != FileTypeCategory.unknown) {
        return fromPath;
      }
    }

    return _typeMap[FileTypeCategory.unknown]!;
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  static String formatDuration(int? seconds) {
    if (seconds == null || seconds < 0) {
      return '--:--';
    }

    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    final int secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
