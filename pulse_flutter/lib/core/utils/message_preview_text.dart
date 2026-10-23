import 'package:markdown/markdown.dart' as md;

/// Plain text projection only. Never changes persisted content or ciphertext.
String messagePreviewText(String source) {
  final buffer = StringBuffer();
  void write(md.Node node) {
    if (node is md.Text) {
      buffer.write(node.text);
      return;
    }
    if (node is! md.Element) return;
    if (node.tag == 'img') {
      buffer.write(node.attributes['alt'] ?? '');
      return;
    }
    if (node.tag == 'br') {
      buffer.write(' ');
      return;
    }
    for (final child in node.children ?? const <md.Node>[]) {
      write(child);
    }
    if (const {
      'p',
      'li',
      'pre',
      'blockquote',
      'h1',
      'h2',
      'h3',
    }.contains(node.tag)) {
      buffer.write(' ');
    }
  }

  final document = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  );
  for (final node in document.parseLines(source.split('\n'))) {
    write(node);
  }
  final plain = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  return plain;
}

/// Owned by one inbox screen and cleared when its authenticated account changes.
class MessagePreviewFormatter {
  final _cache = <String, String>{};
  void clear() => _cache.clear();
  String format(String source, {bool cache = true}) {
    if (!cache) return messagePreviewText(source);
    final previous = _cache[source];
    if (previous != null) return previous;
    final result = messagePreviewText(source);
    if (_cache.length >= 512) _cache.remove(_cache.keys.first);
    _cache[source] = result;
    return result;
  }
}
