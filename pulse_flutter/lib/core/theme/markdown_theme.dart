import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:material_ui/material_ui.dart';

/// Builds the markdown style sheet from our own [ThemeData].
///
/// `flutter_markdown_plus` still exposes `MarkdownStyleSheet.fromTheme` typed
/// against `package:flutter/material.dart`. The app is on `material_ui`, so
/// passing our theme there would be a type mismatch — and the two `ThemeData`
/// classes are not interchangeable. This mirrors the package's mapping
/// one-to-one, which keeps the rendered markdown identical.
MarkdownStyleSheet buildMarkdownStyleSheet(ThemeData theme) {
  final TextTheme text = theme.textTheme;
  final ColorScheme scheme = theme.colorScheme;
  final double baseSize = text.bodyMedium?.fontSize ?? 14;

  return MarkdownStyleSheet(
    a: TextStyle(color: scheme.primary),
    p: text.bodyMedium,
    pPadding: EdgeInsets.zero,
    code: text.bodyMedium?.copyWith(
      backgroundColor: theme.cardTheme.color,
      fontFamily: 'monospace',
      fontSize: baseSize * 0.85,
    ),
    h1: text.headlineSmall,
    h1Padding: EdgeInsets.zero,
    h2: text.titleLarge,
    h2Padding: EdgeInsets.zero,
    h3: text.titleMedium,
    h3Padding: EdgeInsets.zero,
    h4: text.bodyLarge,
    h4Padding: EdgeInsets.zero,
    h5: text.bodyLarge,
    h5Padding: EdgeInsets.zero,
    h6: text.bodyLarge,
    h6Padding: EdgeInsets.zero,
    em: const TextStyle(fontStyle: FontStyle.italic),
    strong: const TextStyle(fontWeight: FontWeight.bold),
    del: const TextStyle(decoration: TextDecoration.lineThrough),
    blockquote: text.bodyMedium,
    img: text.bodyMedium,
    checkbox: text.bodyMedium?.copyWith(color: theme.primaryColor),
    blockSpacing: 8.0,
    listIndent: 24.0,
    listBullet: text.bodyMedium,
    listBulletPadding: const EdgeInsets.only(right: 4),
    tableHead: const TextStyle(fontWeight: FontWeight.w600),
    tableBody: text.bodyMedium,
    tableHeadAlign: TextAlign.center,
    tablePadding: const EdgeInsets.only(bottom: 4.0),
    tableBorder: TableBorder.all(color: theme.dividerColor),
    tableColumnWidth: const FlexColumnWidth(),
    tableCellsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    tableCellsDecoration: const BoxDecoration(),
    blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    blockquoteDecoration: BoxDecoration(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(3),
      border: Border(
        left: BorderSide(color: scheme.primary, width: 3),
      ),
    ),
    codeblockPadding: const EdgeInsets.all(8.0),
    codeblockDecoration: BoxDecoration(
      color: theme.cardTheme.color ?? theme.cardColor,
      borderRadius: BorderRadius.circular(2.0),
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(
        top: BorderSide(width: 5.0, color: theme.dividerColor),
      ),
    ),
  );
}
