import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';

final RegExp _interactiveTokenRegExp = RegExp(
  r"""((?:https?:\/\/|niosmess:\/\/|tg:\/\/)[^\s<>"'\)]+|\b(?:t\.me|telegram\.me|ni-os\.ru)\/[^\s<>"'\)]+|@([a-zA-Z0-9_]{3,32}))""",
  caseSensitive: false,
);

class ParsedTextToken {
  const ParsedTextToken({
    required this.prefix,
    required this.bold,
    required this.token,
    required this.trailing,
    required this.isMention,
    required this.isLink,
    required this.target,
  });

  final String prefix;
  final bool bold;
  final String token;
  final String trailing;
  final bool isMention;
  final bool isLink;
  final String target;
}

class InteractiveMessageText extends StatefulWidget {
  const InteractiveMessageText({
    required this.text,
    required this.baseStyle,
    required this.isMine,
    required this.scheme,
    super.key,
  });

  final String text;
  final TextStyle baseStyle;
  final bool isMine;
  final ColorScheme scheme;

  @override
  State<InteractiveMessageText> createState() => InteractiveMessageTextState();
}

class InteractiveMessageTextState extends State<InteractiveMessageText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];
  final List<ParsedTextToken> _tokens = <ParsedTextToken>[];
  late TextSpan _cachedSpan;

  @override
  void initState() {
    super.initState();
    _parseTokens();
    _updateSpans();
  }

  @override
  void didUpdateWidget(covariant InteractiveMessageText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _disposeRecognizers();
      _parseTokens();
      _updateSpans();
    } else if (oldWidget.baseStyle != widget.baseStyle ||
        oldWidget.isMine != widget.isMine ||
        oldWidget.scheme != widget.scheme) {
      _updateSpans();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final TapGestureRecognizer recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  bool _escaped(String text, int index) {
    int slashes = 0;
    while (index > 0 && text[--index] == r'\') {
      slashes++;
    }
    return slashes.isOdd;
  }

  String _unescape(String text) =>
      text.replaceAllMapped(RegExp(r'\\([\\*_`\[\]])'), (match) => match[1]!);

  void _parseTokens() {
    _tokens.clear();
    final text = widget.text;
    int start = 0;
    int search = 0;
    while (true) {
      final open = text.indexOf('**', search);
      if (open < 0) break;
      if (_escaped(text, open)) {
        search = open + 1;
        continue;
      }
      int close = text.indexOf('**', open + 2);
      while (close >= 0 && _escaped(text, close)) {
        close = text.indexOf('**', close + 1);
      }
      if (close < 0) break;
      _parseRun(_unescape(text.substring(start, open)), false);
      _parseRun(_unescape(text.substring(open + 2, close)), true);
      start = close + 2;
      search = start;
    }
    _parseRun(_unescape(text.substring(start)), false);
  }

  void _parseRun(String text, bool bold) {
    int lastEnd = 0;
    for (final match in _interactiveTokenRegExp.allMatches(text)) {
      final prefix = text.substring(lastEnd, match.start);
      String token = match.group(0)!;
      String trailing = '';
      while (token.isNotEmpty && '.,!?;:)]'.contains(token[token.length - 1])) {
        trailing = token[token.length - 1] + trailing;
        token = token.substring(0, token.length - 1);
      }
      final isMention = token.startsWith('@');
      final target = isMention ? token.substring(1) : token;
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          if (mounted) {
            AppUrlLauncher.openUrl(context, isMention ? '/g/$target' : target);
          }
        };
      _recognizers.add(recognizer);
      _tokens.add(
        ParsedTextToken(
          prefix: prefix,
          bold: bold,
          token: token,
          trailing: trailing,
          isMention: isMention,
          isLink: !isMention,
          target: target,
        ),
      );
      lastEnd = match.end;
    }
    // A plain sentinel keeps run ordering, including runs without links.
    _tokens.add(
      ParsedTextToken(
        prefix: text.substring(lastEnd),
        bold: bold,
        token: '',
        trailing: '',
        isMention: false,
        isLink: false,
        target: '',
      ),
    );
  }

  void _updateSpans() {
    final Color linkColor = widget.isMine
        ? widget.scheme.onPrimaryContainer
        : widget.scheme.primary;

    final List<TextSpan> spans = <TextSpan>[];

    int recognizerIndex = 0;
    for (int i = 0; i < _tokens.length; i++) {
      final ParsedTextToken t = _tokens[i];
      if (t.prefix.isNotEmpty) {
        spans.add(
          TextSpan(
            text: t.prefix,
            style: t.bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
          ),
        );
      }
      if (t.token.isEmpty) continue;
      final TapGestureRecognizer recognizer = _recognizers[recognizerIndex++];
      if (t.isMention) {
        spans.add(
          TextSpan(
            text: t.token,
            style: widget.baseStyle.copyWith(
              color: linkColor,
              fontWeight: t.bold ? FontWeight.w700 : FontWeight.w600,
            ),
            recognizer: recognizer,
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: t.token,
            style: widget.baseStyle.copyWith(
              color: linkColor,
              fontWeight: t.bold ? FontWeight.w700 : FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: linkColor.withValues(alpha: 0.4),
            ),
            recognizer: recognizer,
          ),
        );
      }
      if (t.trailing.isNotEmpty) {
        spans.add(
          TextSpan(
            text: t.trailing,
            style: t.bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
          ),
        );
      }
    }

    _cachedSpan = TextSpan(style: widget.baseStyle, children: spans);
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(_cachedSpan);
  }
}
