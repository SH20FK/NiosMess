import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/utils/docx_parser.dart';

Uint8List _buildDocx(String documentXml, {int? level}) {
  final archive = Archive();
  final xmlBytes = utf8.encode(documentXml);
  archive.addFile(ArchiveFile('word/document.xml', xmlBytes.length, xmlBytes));
  return Uint8List.fromList(
    level == null
        ? ZipEncoder().encode(archive)
        : ZipEncoder().encode(archive, level: level),
  );
}

/// Runs [action] while a 2ms heartbeat timer ticks. Returns how many times the
/// UI event loop was serviced plus the longest gap. A fully blocking parse
/// yields 0 ticks because Dart timers cannot fire inside one occupied turn.
Future<({int ticks, int maxGapMs, int wallMs})> _probe(
  FutureOr<void> Function() action,
) async {
  int ticks = 0;
  int last = 0;
  int maxGap = 0;
  final Stopwatch sw = Stopwatch()..start();
  final Timer timer = Timer.periodic(const Duration(milliseconds: 2), (_) {
    ticks++;
    final int now = sw.elapsedMilliseconds;
    if (now - last > maxGap) maxGap = now - last;
    last = now;
  });
  await Future<void>.delayed(Duration.zero);
  final int before = ticks;
  try {
    await action();
  } finally {
    timer.cancel();
  }
  return (ticks: ticks - before, maxGapMs: maxGap, wallMs: sw.elapsedMilliseconds);
}

void main() {
  group('DocxParser', () {
    test('returns empty document for empty or corrupted bytes', () {
      final doc = DocxParser.parseBytes(Uint8List(0));
      expect(doc.hasContent, isFalse);
      expect(doc.blocks, isEmpty);
      expect(doc.toPlainText(), isEmpty);
    });

    test('parses headings, paragraphs, formatted runs and tables from docx archive', () {
      const xml = '''<?xml version=1.0 encoding=UTF-8 standalone=yes?>
<w:document xmlns:w=http://schemas.openxmlformats.org/wordprocessingml/2006/main>
  <w:body>
    <w:p>
      <w:pPr>
        <w:pStyle w:val=Title/>
      </w:pPr>
      <w:r>
        <w:t>Document Title</w:t>
      </w:r>
    </w:p>
    <w:p>
      <w:pPr>
        <w:pStyle w:val=Heading1/>
      </w:pPr>
      <w:r>
        <w:t>Section 1: Introduction</w:t>
      </w:r>
    </w:p>
    <w:p>
      <w:r>
        <w:rPr><w:b/></w:rPr>
        <w:t>Bold statement </w:t>
      </w:r>
      <w:r>
        <w:rPr><w:i/></w:rPr>
        <w:t>and italic text &amp; symbols.</w:t>
      </w:r>
    </w:p>
    <w:p>
      <w:pPr>
        <w:numPr/>
      </w:pPr>
      <w:r>
        <w:t>Bullet item</w:t>
      </w:r>
    </w:p>
    <w:tbl>
      <w:tr>
        <w:tc><w:p><w:r><w:t>Header A</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Header B</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:t>Value 1</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Value 2</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>
  </w:body>
</w:document>''';

      final archive = Archive();
      final xmlBytes = utf8.encode(xml);
      archive.addFile(ArchiveFile('word/document.xml', xmlBytes.length, xmlBytes));
      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));

      final doc = DocxParser.parseBytes(zipBytes);
      expect(doc.hasContent, isTrue);
      expect(doc.blocks.length, 5);

      // Block 0: Title
      expect(doc.blocks[0].type, DocxBlockType.title);
      expect(doc.blocks[0].plainText, 'Document Title');

      // Block 1: Heading 1
      expect(doc.blocks[1].type, DocxBlockType.heading1);
      expect(doc.blocks[1].plainText, 'Section 1: Introduction');

      // Block 2: Paragraph with bold and italic runs
      expect(doc.blocks[2].type, DocxBlockType.paragraph);
      expect(doc.blocks[2].runs.length, 2);
      expect(doc.blocks[2].runs[0].isBold, isTrue);
      expect(doc.blocks[2].runs[0].text, 'Bold statement ');
      expect(doc.blocks[2].runs[1].isItalic, isTrue);
      expect(doc.blocks[2].runs[1].text, 'and italic text & symbols.');

      // Block 3: Bullet Item
      expect(doc.blocks[3].type, DocxBlockType.bulletItem);
      expect(doc.blocks[3].plainText, 'Bullet item');

      // Block 4: Table
      expect(doc.blocks[4].type, DocxBlockType.table);
      expect(doc.blocks[4].tableRows.length, 2);
      expect(doc.blocks[4].tableRows[0], ['Header A', 'Header B']);
      expect(doc.blocks[4].tableRows[1], ['Value 1', 'Value 2']);

      final plain = doc.toPlainText();
      expect(plain, contains('Document Title'));
      expect(plain, contains('Header A\tHeader B'));
    });

    test('background parse matches sync parse and stays off the UI thread', () async {
      final StringBuffer xml = StringBuffer(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>',
      );
      for (int i = 0; i < 4000; i++) {
        final String style = i % 40 == 0 ? '<w:pPr><w:pStyle w:val="Heading1"/></w:pPr>' : '';
        xml.write(
          '<w:p>$style<w:r><w:t>Paragraph $i with enough text to make the '
          'regex pass realistic &amp; measurable.</w:t></w:r></w:p>',
        );
      }
      xml
        ..write('<w:tbl><w:tr><w:tc><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc>')
        ..write('<w:tc><w:p><w:r><w:t>B</w:t></w:r></w:p></w:tc></w:tr></w:tbl>')
        ..write('</w:body></w:document>');

      final Uint8List bytes = _buildDocx(
        xml.toString(),
        // Store, not deflate: keeps the fixture near the real-world size the
        // audit measured (hundreds of KB) instead of a 12KB compressed blob.
        level: DeflateLevel.none,
      );

      // Previous behaviour: the whole parse ran on the UI isolate.
      late DocxDocument syncDoc;
      final Stopwatch syncWatch = Stopwatch();
      final ({int ticks, int maxGapMs, int wallMs}) syncProbe = await _probe(() {
        syncWatch.start();
        syncDoc = DocxParser.parseBytes(bytes);
        syncWatch.stop();
      });

      late DocxDocument asyncDoc;
      final ({int ticks, int maxGapMs, int wallMs}) bgProbe =
          await _probe(() async {
        asyncDoc = await DocxParser.parseBytesAsync(bytes);
      });

      expect(asyncDoc.hasContent, isTrue);
      expect(asyncDoc.blocks.length, syncDoc.blocks.length);
      expect(syncDoc.blocks.length, 4001);
      for (int i = 0; i < syncDoc.blocks.length; i++) {
        expect(asyncDoc.blocks[i].type, syncDoc.blocks[i].type);
        expect(asyncDoc.blocks[i].plainText, syncDoc.blocks[i].plainText);
        expect(asyncDoc.blocks[i].tableRows, syncDoc.blocks[i].tableRows);
      }
      expect(asyncDoc.toPlainText(), syncDoc.toPlainText());

      expect(
        syncProbe.ticks,
        0,
        reason: 'sync parse should block the UI turn entirely',
      );
      expect(
        bgProbe.ticks,
        greaterThan(0),
        reason: 'background parse must leave the UI event loop running',
      );
      expect(
        bgProbe.maxGapMs,
        lessThan(50),
        reason: 'docx parse left a ${bgProbe.maxGapMs}ms hole in the UI loop',
      );

      // ignore: avoid_print
      print(
        'D7 docx parse ${(bytes.length / 1024).round()}KB: sync UI block '
        '${syncWatch.elapsedMilliseconds}ms (loop ticks ${syncProbe.ticks}) -> '
        'background max UI gap ${bgProbe.maxGapMs}ms '
        '(wall ${bgProbe.wallMs}ms, loop ticks ${bgProbe.ticks})',
      );
    });
  });
}
