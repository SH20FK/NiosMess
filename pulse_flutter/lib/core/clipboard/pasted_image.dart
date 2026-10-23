import 'dart:typed_data';

class PastedImage {
  const PastedImage({
    required this.bytes,
    required this.name,
    required this.mimeType,
  });
  final Uint8List bytes;
  final String name, mimeType;
}

class ClipboardImageLimit implements Exception {
  const ClipboardImageLimit();
}
