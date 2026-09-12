import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/utils/docx_parser.dart';

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
  });
}
