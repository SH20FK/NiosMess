import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:web/web.dart' as web;
import 'pasted_image.dart';

void Function() listenForFileDrop({
  required Rect? Function() bounds,
  required bool Function() canHandle,
  required void Function(bool) onHover,
  required void Function(List<PastedImage>) onFiles,
  required void Function(Object) onError,
}) {
  var active = true, reading = false;
  bool claims(web.DragEvent e) =>
      active &&
      canHandle() &&
      (e.dataTransfer?.types.toDart.any((v) => v.toDart == 'Files') ?? false) &&
      (bounds()?.contains(Offset(e.clientX.toDouble(), e.clientY.toDouble())) ??
          false);
  final hover = ((web.Event raw) {
    final e = raw as web.DragEvent;
    if (!claims(e)) {
      if (active) onHover(false);
      return;
    }
    e.preventDefault();
    e.stopImmediatePropagation();
    e.dataTransfer?.dropEffect = 'copy';
    onHover(true);
  }).toJS;
  final leave = ((web.Event raw) {
    final e = raw as web.DragEvent;
    if (active && (e.relatedTarget == null || !claims(e))) onHover(false);
  }).toJS;
  final drop = ((web.Event raw) {
    final e = raw as web.DragEvent;
    if (!claims(e)) return;
    e.preventDefault();
    e.stopImmediatePropagation();
    onHover(false);
    if (reading) return;
    final files = <web.File>[];
    final source = e.dataTransfer!;
    for (var i = 0; i < source.files.length; i++) {
      final file = source.files.item(i);
      if (file != null) files.add(file);
    }
    if (files.isEmpty) return;
    if (files.length > 10 ||
        files.fold<int>(0, (n, f) => n + f.size) > 100 * 1024 * 1024) {
      onError(const ClipboardImageLimit());
      return;
    }
    reading = true;
    () async {
      try {
        final results = <PastedImage>[];
        for (final file in files) {
          final buffer = await file.arrayBuffer().toDart;
          if (!active || !canHandle()) return;
          results.add(
            PastedImage(
              bytes: Uint8List.view(buffer.toDart),
              name: file.name,
              mimeType: file.type,
            ),
          );
        }
        if (active && canHandle()) onFiles(results);
      } catch (error) {
        if (active && canHandle()) onError(error);
      } finally {
        reading = false;
      }
    }();
  }).toJS;
  for (final event in ['dragenter', 'dragover']) {
    web.document.addEventListener(event, hover, true.toJS);
  }
  web.document.addEventListener('dragleave', leave, true.toJS);
  web.document.addEventListener('drop', drop, true.toJS);
  return () {
    active = false;
    for (final event in ['dragenter', 'dragover']) {
      web.document.removeEventListener(event, hover, true.toJS);
    }
    web.document.removeEventListener('dragleave', leave, true.toJS);
    web.document.removeEventListener('drop', drop, true.toJS);
  };
}
