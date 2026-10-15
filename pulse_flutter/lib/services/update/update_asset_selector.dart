/// Select only the process ABI, or a universal APK, never a different split.
Map<String, dynamic>? selectUpdateAsset(
  List<dynamic> assets, {
  required bool windows,
  String? androidAbi,
}) {
  final entries = assets.whereType<Map<String, dynamic>>().toList();
  if (windows) {
    return entries
            .where((e) => e['name'] == 'niosmess-windows-setup.exe')
            .firstOrNull ??
        entries
            .where((e) => (e['name'] as String? ?? '').endsWith('.exe'))
            .firstOrNull;
  }
  if (androidAbi != null) {
    final split = entries
        .where((e) => e['name'] == 'niosmess-$androidAbi.apk')
        .firstOrNull;
    if (split != null) return split;
  }
  return entries.where((e) => e['name'] == 'niosmess.apk').firstOrNull ??
      entries.where((e) => e['name'] == 'app-release.apk').firstOrNull;
}

String? updateSha256(Object? value) {
  final digest = value?.toString().replaceFirst('sha256:', '').toLowerCase();
  return digest != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)
      ? digest
      : null;
}

/// GitHub may spell a tag's '+' as either '+' or '%2B' in download URLs.
bool sameUpdateAssetUrl(Object? first, Object? second) {
  if (first is! String || second is! String) return false;
  final a = Uri.tryParse(first);
  final b = Uri.tryParse(second);
  if (a == null ||
      b == null ||
      a.scheme != b.scheme ||
      a.host != b.host ||
      a.port != b.port ||
      a.userInfo != b.userInfo ||
      a.query != b.query ||
      a.fragment != b.fragment ||
      a.pathSegments.length != b.pathSegments.length) {
    return false;
  }
  for (var i = 0; i < a.pathSegments.length; i++) {
    if (a.pathSegments[i] != b.pathSegments[i]) return false;
  }
  return true;
}
