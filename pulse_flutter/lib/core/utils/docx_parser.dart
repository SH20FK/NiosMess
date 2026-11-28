import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;

enum DocxBlockType {
  title,
  heading1,
  heading2,
  heading3,
  paragraph,
  bulletItem,
  table,
}

class DocxRun {
  const DocxRun({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
  });

  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
}

class DocxBlock {
  const DocxBlock({
    required this.type,
    this.runs = const <DocxRun>[],
    this.tableRows = const <List<String>>[],
  });

  final DocxBlockType type;
  final List<DocxRun> runs;
  final List<List<String>> tableRows;

  String get plainText => runs.map((DocxRun r) => r.text).join();
}

class DocxDocument {
  const DocxDocument({
    required this.blocks,
    this.hasContent = true,
  });

  final List<DocxBlock> blocks;
  final bool hasContent;

  String toPlainText() {
    final StringBuffer sb = StringBuffer();
    for (final DocxBlock block in blocks) {
      if (block.type == DocxBlockType.table) {
        for (final List<String> row in block.tableRows) {
          sb.writeln(row.join('\t'));
        }
        sb.writeln();
      } else {
        sb.writeln(block.plainText);
      }
    }
    return sb.toString();
  }
}

class DocxParser {
  // Compiled once: the previous version rebuilt these inside per-paragraph and
  // per-run loops, which cost thousands of RegExp compilations per document.
  static final RegExp _elementRegex = RegExp(
    r'<w:(p|tbl)[\s>].*?<\/w:\1>',
    dotAll: true,
  );
  static final RegExp _styleRegex = RegExp(
    r'''pStyle[^>]*val=["']?([^"'\s/>]+)''',
    caseSensitive: false,
  );
  static final RegExp _runRegex = RegExp(r'<w:r[\s>].*?<\/w:r>', dotAll: true);
  static final RegExp _textRegex = RegExp(
    r'<w:t(?:\s+[^>]*)?>(.*?)<\/w:t>',
    dotAll: true,
  );
  static final RegExp _rowRegex = RegExp(r'<w:tr[\s>].*?<\/w:tr>', dotAll: true);
  static final RegExp _cellRegex = RegExp(
    r'<w:tc[\s>].*?<\/w:tc>',
    dotAll: true,
  );

  /// Parses [bytes] off the UI isolate.
  ///
  /// Zip inflate plus the XML regex passes take 20-80 ms on real documents, so
  /// the viewer must not run them inside `initState`. On web isolates are not
  /// available: we yield once first so the loading skeleton can paint, then
  /// parse on the UI thread as before.
  static Future<DocxDocument> parseBytesAsync(Uint8List bytes) async {
    if (kIsWeb) {
      await Future<void>.delayed(Duration.zero);
      return parseBytes(bytes);
    }
    return compute(_parseBytesInIsolate, bytes);
  }

  /// Parses bytes of a .docx file and returns a structured [DocxDocument].
  static DocxDocument parseBytes(Uint8List bytes) {
    try {
      final Archive archive = ZipDecoder().decodeBytes(bytes);
      final ArchiveFile? docFile = archive.findFile('word/document.xml');

      if (docFile == null) {
        return const DocxDocument(blocks: <DocxBlock>[], hasContent: false);
      }

      final String xml = utf8.decode(docFile.content as List<int>, allowMalformed: true);
      final List<DocxBlock> blocks = _parseDocumentXml(xml);

      return DocxDocument(
        blocks: blocks,
        hasContent: blocks.isNotEmpty,
      );
    } catch (_) {
      return const DocxDocument(blocks: <DocxBlock>[], hasContent: false);
    }
  }

  static List<DocxBlock> _parseDocumentXml(String xml) {
    final List<DocxBlock> blocks = <DocxBlock>[];

    // Extract top-level paragraphs <w:p>...</w:p> and tables <w:tbl>...</w:tbl>
    final Iterable<Match> matches = _elementRegex.allMatches(xml);

    for (final Match m in matches) {
      final String rawTag = m.group(1) ?? '';
      final String blockXml = m.group(0) ?? '';

      if (rawTag == 'tbl') {
        final DocxBlock? tableBlock = _parseTable(blockXml);
        if (tableBlock != null) {
          blocks.add(tableBlock);
        }
      } else if (rawTag == 'p') {
        final DocxBlock? pBlock = _parseParagraph(blockXml);
        if (pBlock != null) {
          blocks.add(pBlock);
        }
      }
    }

    return blocks;
  }

  static DocxBlock? _parseParagraph(String pXml) {
    DocxBlockType type = DocxBlockType.paragraph;

    // Detect heading styles
    final Match? styleMatch = _styleRegex.firstMatch(pXml);
    if (styleMatch != null) {
      final String styleVal = styleMatch.group(1)!.toLowerCase();
      if (styleVal.contains('title')) {
        type = DocxBlockType.title;
      } else if (styleVal.contains('heading1') ||
          styleVal.contains('heading 1') ||
          styleVal.contains('heading_1')) {
        type = DocxBlockType.heading1;
      } else if (styleVal.contains('heading2') ||
          styleVal.contains('heading 2') ||
          styleVal.contains('heading_2')) {
        type = DocxBlockType.heading2;
      } else if (styleVal.contains('heading3') ||
          styleVal.contains('heading 3') ||
          styleVal.contains('heading_3')) {
        type = DocxBlockType.heading3;
      }
    }

    // Detect bullet or numbered lists
    if (pXml.contains('numPr')) {
      type = DocxBlockType.bulletItem;
    }

    final List<DocxRun> runs = <DocxRun>[];
    final Iterable<Match> runMatches = _runRegex.allMatches(pXml);

    for (final Match rm in runMatches) {
      final String runXml = rm.group(0) ?? '';

      final bool isBold = runXml.contains('<w:b/>') || runXml.contains('<w:b ');
      final bool isItalic = runXml.contains('<w:i/>') || runXml.contains('<w:i ');
      final bool isUnderline = runXml.contains('<w:u ') || runXml.contains('<w:u/>');

      final Iterable<Match> textMatches = _textRegex.allMatches(runXml);

      for (final Match tm in textMatches) {
        String rawText = tm.group(1) ?? '';
        rawText = _unescapeXml(rawText);
        if (rawText.isNotEmpty) {
          runs.add(
            DocxRun(
              text: rawText,
              isBold: isBold,
              isItalic: isItalic,
              isUnderline: isUnderline,
            ),
          );
        }
      }
    }

    if (runs.isEmpty) {
      return null;
    }

    return DocxBlock(type: type, runs: runs);
  }

  static DocxBlock? _parseTable(String tblXml) {
    final List<List<String>> rows = <List<String>>[];
    final Iterable<Match> rowMatches = _rowRegex.allMatches(tblXml);

    for (final Match rm in rowMatches) {
      final String rowXml = rm.group(0) ?? '';
      final List<String> cells = <String>[];

      final Iterable<Match> cellMatches = _cellRegex.allMatches(rowXml);

      for (final Match cm in cellMatches) {
        final String cellXml = cm.group(0) ?? '';
        final Iterable<Match> textMatches = _textRegex.allMatches(cellXml);
        final String cellText = textMatches
            .map((Match tm) => _unescapeXml(tm.group(1) ?? ''))
            .join(' ')
            .trim();
        cells.add(cellText);
      }

      if (cells.isNotEmpty) {
        rows.add(cells);
      }
    }

    if (rows.isEmpty) return null;
    return DocxBlock(type: DocxBlockType.table, tableRows: rows);
  }

  static String _unescapeXml(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }
}

DocxDocument _parseBytesInIsolate(Uint8List bytes) => DocxParser.parseBytes(bytes);
