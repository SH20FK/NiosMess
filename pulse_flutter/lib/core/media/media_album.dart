import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart' show getCrc32;

typedef _AlbumRecord = ({int offset, int size, int crc});

class AlbumImage {
  const AlbumImage(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

/// Versioned STORE-only ZIP: one attachment, one encrypted message, no server
/// schema change. Older clients can download and open it as an ordinary ZIP.
/// Our reader never inflates data, follows links, or extracts files to disk.
class MediaAlbum {
  static const maxBytes = 40 * 1024 * 1024;
  static const suffix = '.niosalbum.zip';
  static bool isAlbum(String? name) =>
      name?.toLowerCase().endsWith(suffix) ?? false;
  static String? imageExtension(Uint8List b) {
    if (b.length >= 8 &&
        b[0] == 137 &&
        ascii.decode(b.sublist(1, 4), allowInvalid: true) == 'PNG') {
      return 'png';
    }
    if (b.length >= 3 && b[0] == 255 && b[1] == 216 && b[2] == 255) {
      return 'jpg';
    }
    if (b.length >= 12 &&
        ascii.decode(b.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(b.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'webp';
    }
    if (b.length >= 6 &&
        [
          'GIF87a',
          'GIF89a',
        ].contains(ascii.decode(b.sublist(0, 6), allowInvalid: true))) {
      return 'gif';
    }
    return null;
  }

  static Uint8List encode(List<AlbumImage> images) {
    if (images.length < 2 ||
        images.length > 10 ||
        images.fold<int>(0, (n, i) => n + i.bytes.length) > maxBytes) {
      throw const FormatException('album_limit');
    }
    final entries = <(String, Uint8List)>[];
    final names = <String>[];
    for (var i = 0; i < images.length; i++) {
      final ext = imageExtension(images[i].bytes);
      if (ext == null) throw const FormatException('album_image_type');
      final name = 'photo_${i + 1}.$ext';
      names.add(name);
      entries.add((name, images[i].bytes));
    }
    entries.insert(0, (
      'nios_album.json',
      Uint8List.fromList(
        utf8.encode(jsonEncode({'version': 1, 'images': names})),
      ),
    ));
    final local = BytesBuilder(copy: false),
        central = BytesBuilder(copy: false);
    for (final (name, bytes) in entries) {
      final n = utf8.encode(name), crc = getCrc32(bytes), offset = local.length;
      final h = ByteData(30)
        ..setUint32(0, 0x04034b50, Endian.little)
        ..setUint16(4, 20, Endian.little)
        ..setUint32(14, crc, Endian.little)
        ..setUint32(18, bytes.length, Endian.little)
        ..setUint32(22, bytes.length, Endian.little)
        ..setUint16(26, n.length, Endian.little);
      local.add(h.buffer.asUint8List());
      local.add(n);
      local.add(bytes);
      final c = ByteData(46)
        ..setUint32(0, 0x02014b50, Endian.little)
        ..setUint16(4, 20, Endian.little)
        ..setUint16(6, 20, Endian.little)
        ..setUint32(16, crc, Endian.little)
        ..setUint32(20, bytes.length, Endian.little)
        ..setUint32(24, bytes.length, Endian.little)
        ..setUint16(28, n.length, Endian.little)
        ..setUint32(42, offset, Endian.little);
      central.add(c.buffer.asUint8List());
      central.add(n);
    }
    final end = ByteData(22)
      ..setUint32(0, 0x06054b50, Endian.little)
      ..setUint16(8, entries.length, Endian.little)
      ..setUint16(10, entries.length, Endian.little)
      ..setUint32(12, central.length, Endian.little)
      ..setUint32(16, local.length, Endian.little);
    local.add(central.takeBytes());
    local.add(end.buffer.asUint8List());
    return local.takeBytes();
  }

  static List<AlbumImage> decode(Uint8List bytes) {
    if (bytes.length > maxBytes + 65536 || bytes.length < 22) {
      throw const FormatException('album_size');
    }
    final data = ByteData.sublistView(bytes), files = <String, Uint8List>{};
    final records = <String, _AlbumRecord>{};
    var offset = 0, total = 0;
    while (offset + 30 <= bytes.length &&
        data.getUint32(offset, Endian.little) == 0x04034b50) {
      if (files.length >= 11 ||
          data.getUint16(offset + 6, Endian.little) != 0 ||
          data.getUint16(offset + 8, Endian.little) != 0) {
        throw const FormatException('album_compression');
      }
      final size = data.getUint32(offset + 18, Endian.little);
      final nameLength = data.getUint16(offset + 26, Endian.little);
      final extraLength = data.getUint16(offset + 28, Endian.little);
      final start = offset + 30 + nameLength + extraLength;
      total += size;
      if (size != data.getUint32(offset + 22, Endian.little) ||
          total > maxBytes + 4096 ||
          start > bytes.length ||
          size > bytes.length - start) {
        throw const FormatException('album_entry_size');
      }
      final name = utf8.decode(
        bytes.sublist(offset + 30, offset + 30 + nameLength),
      );
      if (!RegExp(
            r'^(nios_album\.json|photo_[0-9]{1,2}\.(png|jpg|webp|gif))$',
          ).hasMatch(name) ||
          files.containsKey(name)) {
        throw const FormatException('album_entry_name');
      }
      final content = Uint8List.sublistView(bytes, start, start + size);
      if (getCrc32(content) != data.getUint32(offset + 14, Endian.little)) {
        throw const FormatException('album_crc');
      }
      records[name] = (
        offset: offset,
        size: size,
        crc: data.getUint32(offset + 14, Endian.little),
      );
      files[name] = content;
      offset = start + size;
    }
    _verifyDirectory(bytes, data, offset, records);
    final manifest = files.remove('nios_album.json');
    if (manifest == null ||
        manifest.length > 4096 ||
        files.length < 2 ||
        offset + 4 > bytes.length ||
        data.getUint32(offset, Endian.little) != 0x02014b50) {
      throw const FormatException('album_manifest');
    }
    final decoded = jsonDecode(utf8.decode(manifest));
    if (decoded is! Map ||
        decoded['version'] != 1 ||
        decoded['images'] is! List) {
      throw const FormatException('album_version');
    }
    final names = (decoded['images'] as List).whereType<String>().toList();
    if (names.length != files.length ||
        names.toSet().length != files.length ||
        names.any((n) => !files.containsKey(n))) {
      throw const FormatException('album_manifest_files');
    }
    if (names.any((name) => imageExtension(files[name]!) == null)) {
      throw const FormatException('album_image');
    }
    return [for (final name in names) AlbumImage(name, files[name]!)];
  }

  /// STORE entries must agree with their central directory and EOCD. Reading
  /// local headers alone would also accept a truncated or contradictory ZIP.
  static void _verifyDirectory(
    Uint8List bytes,
    ByteData data,
    int offset,
    Map<String, _AlbumRecord> records,
  ) {
    final centralStart = offset;
    final names = <String>{};
    while (offset + 4 <= bytes.length &&
        data.getUint32(offset, Endian.little) == 0x02014b50) {
      if (offset + 46 > bytes.length || names.length >= records.length) {
        throw const FormatException('album_directory');
      }
      final nameLength = data.getUint16(offset + 28, Endian.little);
      final extraLength = data.getUint16(offset + 30, Endian.little);
      final commentLength = data.getUint16(offset + 32, Endian.little);
      final next = offset + 46 + nameLength + extraLength + commentLength;
      if (next > bytes.length ||
          data.getUint16(offset + 8, Endian.little) != 0 ||
          data.getUint16(offset + 10, Endian.little) != 0 ||
          data.getUint16(offset + 34, Endian.little) != 0) {
        throw const FormatException('album_directory');
      }
      final name = utf8.decode(
        Uint8List.sublistView(bytes, offset + 46, offset + 46 + nameLength),
      );
      final record = records[name];
      if (record == null ||
          !names.add(name) ||
          data.getUint32(offset + 16, Endian.little) != record.crc ||
          data.getUint32(offset + 20, Endian.little) != record.size ||
          data.getUint32(offset + 24, Endian.little) != record.size ||
          data.getUint32(offset + 42, Endian.little) != record.offset) {
        throw const FormatException('album_directory_entry');
      }
      offset = next;
    }
    if (names.length != records.length ||
        offset + 22 > bytes.length ||
        data.getUint32(offset, Endian.little) != 0x06054b50 ||
        data.getUint16(offset + 4, Endian.little) != 0 ||
        data.getUint16(offset + 6, Endian.little) != 0 ||
        data.getUint16(offset + 8, Endian.little) != names.length ||
        data.getUint16(offset + 10, Endian.little) != names.length ||
        data.getUint32(offset + 12, Endian.little) != offset - centralStart ||
        data.getUint32(offset + 16, Endian.little) != centralStart ||
        offset + 22 + data.getUint16(offset + 20, Endian.little) !=
            bytes.length) {
      throw const FormatException('album_directory_end');
    }
  }
}
