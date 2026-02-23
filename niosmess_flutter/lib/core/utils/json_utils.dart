import 'dart:convert';

typedef JsonCleanup = void Function();

T? safeJsonDecode<T>(String raw, {JsonCleanup? onError, String? context}) {
  if (raw.isEmpty) return null;
  var input = raw;
  if (input.startsWith('\uFEFF')) {
    input = input.substring(1);
  }
  if (input == 'null' || input == 'undefined') return null;
  try {
    return jsonDecode(input) as T;
  } catch (e, st) {
    final label = context == null ? '' : ' ($context)';
    print('[JSON] decode failed$label: $e');
    print('[JSON] raw: ${_preview(raw)}');
    print(st.toString());
    try {
      onError?.call();
    } catch (_) {}
    return null;
  }
}

String _preview(String raw) {
  const maxLen = 200;
  final trimmed = raw.replaceAll('\n', '\\n');
  if (trimmed.length <= maxLen) return trimmed;
  return '${trimmed.substring(0, maxLen)}...<truncated>';
}
