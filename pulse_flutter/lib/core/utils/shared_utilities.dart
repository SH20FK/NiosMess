import 'package:flutter/material.dart';

Map<String, dynamic> asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic val) => MapEntry(key.toString(), val),
    );
  }
  return <String, dynamic>{};
}

IconData getIconForFileType(String? mimeType, {String? fileName}) {
  final String type = (mimeType ?? '').toLowerCase();
  final String ext = (fileName ?? '').toLowerCase();

  if (type.contains('image') || ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') || ext.endsWith('.gif') || ext.endsWith('.webp')) {
    return Icons.image_rounded;
  }
  if (type.contains('video') || ext.endsWith('.mp4') || ext.endsWith('.mov') || ext.endsWith('.avi') || ext.endsWith('.mkv')) {
    return Icons.videocam_rounded;
  }
  if (type.contains('audio') || ext.endsWith('.mp3') || ext.endsWith('.wav') || ext.endsWith('.ogg') || ext.endsWith('.m4a')) {
    return Icons.audio_file_rounded;
  }
  if (type.contains('pdf') || ext.endsWith('.pdf')) {
    return Icons.picture_as_pdf_rounded;
  }
  if (ext.endsWith('.doc') || ext.endsWith('.docx')) {
    return Icons.description_rounded;
  }
  if (ext.endsWith('.xls') || ext.endsWith('.xlsx') || ext.endsWith('.csv')) {
    return Icons.table_chart_rounded;
  }
  if (ext.endsWith('.ppt') || ext.endsWith('.pptx')) {
    return Icons.slideshow_rounded;
  }
  if (ext.endsWith('.zip') || ext.endsWith('.rar') || ext.endsWith('.7z') || ext.endsWith('.tar') || ext.endsWith('.gz')) {
    return Icons.archive_rounded;
  }
  if (ext.endsWith('.txt') || ext.endsWith('.md') || ext.endsWith('.json') || ext.endsWith('.xml') || ext.endsWith('.yaml') || ext.endsWith('.yml')) {
    return Icons.text_snippet_rounded;
  }
  if (ext.endsWith('.dart') || ext.endsWith('.py') || ext.endsWith('.js') || ext.endsWith('.ts') || ext.endsWith('.java') || ext.endsWith('.cpp') || ext.endsWith('.c') || ext.endsWith('.rs') || ext.endsWith('.go')) {
    return Icons.code_rounded;
  }
  return Icons.insert_drive_file_rounded;
}

Color getIconColorForFileType(String? mimeType, {String? fileName, required ColorScheme scheme}) {
  final String type = (mimeType ?? '').toLowerCase();
  final String ext = (fileName ?? '').toLowerCase();

  if (type.contains('image') || ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') || ext.endsWith('.gif') || ext.endsWith('.webp')) {
    return scheme.primary;
  }
  if (type.contains('video') || ext.endsWith('.mp4') || ext.endsWith('.mov')) {
    return scheme.tertiary;
  }
  if (type.contains('audio') || ext.endsWith('.mp3') || ext.endsWith('.wav')) {
    return scheme.secondary;
  }
  if (type.contains('pdf') || ext.endsWith('.pdf')) {
    return scheme.error;
  }
  if (ext.endsWith('.zip') || ext.endsWith('.rar') || ext.endsWith('.7z')) {
    return scheme.tertiary;
  }
  return scheme.onSurfaceVariant;
}

IconData getIconDataByName(String iconName) {
  switch (iconName) {
    case 'image':
      return Icons.image_rounded;
    case 'videocam':
      return Icons.videocam_rounded;
    case 'audiotrack':
      return Icons.audiotrack_rounded;
    case 'description':
      return Icons.description_rounded;
    case 'android':
      return Icons.android_rounded;
    case 'desktop_windows':
      return Icons.desktop_windows_rounded;
    case 'folder_zip':
      return Icons.folder_zip_rounded;
    case 'text_snippet':
      return Icons.text_snippet_rounded;
    case 'code':
      return Icons.code_rounded;
    default:
      return Icons.insert_drive_file_rounded;
  }
}
