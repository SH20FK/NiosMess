import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'pasted_image.dart';

/// Uses only data offered by the user's paste event. Never reads the clipboard
/// in the background or fetches image URLs embedded in copied HTML.
void Function() listenForImagePaste({
  required bool Function() canHandle,
  required void Function(List<PastedImage>) onImages,
  required void Function(Object) onError,
}) {
  var active = true;
  var reading = false;
  final listener = ((web.Event event) {
    if (!active || !canHandle()) return;
    final paste = event as web.ClipboardEvent;
    final data = paste.clipboardData;
    if (data == null) return;
    final files = <web.File>[];
    for (var i = 0; i < data.items.length; i++) {
      final item = data.items[i];
      if (item.kind != 'file' || !item.type.startsWith('image/')) continue;
      final file = item.getAsFile();
      if (file != null) files.add(file);
    }
    if (files.isEmpty) return; // Let Flutter/browser paste plain text normally.
    paste.preventDefault();
    paste.stopImmediatePropagation();
    if (reading) return;
    final total = files.fold<int>(0, (n, file) => n + file.size);
    if (files.length > 8 || total > 40 * 1024 * 1024) {
      onError(const ClipboardImageLimit());
      return;
    }
    reading = true;
    () async {
      try {
        final images = <PastedImage>[];
        for (final file in files) {
          final data = await file.arrayBuffer().toDart;
          if (!active || !canHandle()) return;
          final extension = switch (file.type) {
            'image/jpeg' => 'jpg',
            'image/webp' => 'webp',
            'image/gif' => 'gif',
            _ => 'png',
          };
          images.add(
            PastedImage(
              bytes: Uint8List.view(data.toDart),
              name: file.name.isEmpty ? 'screenshot.$extension' : file.name,
              mimeType: file.type,
            ),
          );
        }
        if (active && canHandle()) onImages(images);
      } catch (error) {
        if (active && canHandle()) onError(error);
      } finally {
        reading = false;
      }
    }();
  }).toJS;
  web.document.addEventListener('paste', listener, true.toJS);
  return () {
    active = false;
    web.document.removeEventListener('paste', listener, true.toJS);
  };
}
