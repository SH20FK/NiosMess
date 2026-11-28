import 'package:material_ui/material_ui.dart';

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
