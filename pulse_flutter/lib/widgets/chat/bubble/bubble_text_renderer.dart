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
    required this.token,
    required this.trailing,
    required this.isMention,
    required this.isLink,
    required this.target,
  });

  final String prefix;
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
  String _trailingText = '';
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

  void _parseTokens() {
    _tokens.clear();
    final String text = widget.text;
    final int lastMatch = text.length;
    int lastEnd = 0;

    for (final RegExpMatch match in _interactiveTokenRegExp.allMatches(text)) {
      final String prefix = match.start > lastEnd ? text.substring(lastEnd, match.start) : '';
      final String rawToken = match.group(0)!;
      String token = rawToken;
      String trailingPunctuation = '';

      while (token.isNotEmpty &&
          (token.endsWith('.') ||
              token.endsWith(',') ||
              token.endsWith('!') ||
              token.endsWith('?') ||
              token.endsWith(';') ||
              token.endsWith(':') ||
              token.endsWith(')') ||
              token.endsWith(']'))) {
        trailingPunctuation = token[token.length - 1] + trailingPunctuation;
        token = token.substring(0, token.length - 1);
      }

      final bool isMention = token.startsWith('@');
      final String target = isMention ? token.substring(1) : token;

      final TapGestureRecognizer recognizer = TapGestureRecognizer()
        ..onTap = () {
          if (mounted) {
            AppUrlLauncher.openUrl(context, isMention ? '/g/$target' : target);
          }
        };
      _recognizers.add(recognizer);

      _tokens.add(ParsedTextToken(
        prefix: prefix,
        token: token,
        trailing: trailingPunctuation,
        isMention: isMention,
        isLink: !isMention,
        target: target,
      ));

      lastEnd = match.end;
    }

    _trailingText = lastEnd < lastMatch ? text.substring(lastEnd) : '';
  }

  void _updateSpans() {
    final Color linkColor = widget.isMine
        ? widget.scheme.onPrimaryContainer
        : widget.scheme.primary;

    final List<TextSpan> spans = <TextSpan>[];

    for (int i = 0; i < _tokens.length; i++) {
      final ParsedTextToken t = _tokens[i];
      if (t.prefix.isNotEmpty) {
        spans.add(TextSpan(text: t.prefix));
      }
      final TapGestureRecognizer recognizer = _recognizers[i];
      if (t.isMention) {
        spans.add(TextSpan(
          text: t.token,
          style: widget.baseStyle.copyWith(
            color: linkColor,
            fontWeight: FontWeight.w600,
          ),
          recognizer: recognizer,
        ));
      } else {
        spans.add(TextSpan(
          text: t.token,
          style: widget.baseStyle.copyWith(
            color: linkColor,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: linkColor.withValues(alpha: 0.4),
          ),
          recognizer: recognizer,
        ));
      }
      if (t.trailing.isNotEmpty) {
        spans.add(TextSpan(text: t.trailing));
      }
    }

    if (_trailingText.isNotEmpty) {
      spans.add(TextSpan(text: _trailingText));
    }

    _cachedSpan = TextSpan(
      style: widget.baseStyle,
      children: spans,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(_cachedSpan);
  }
}

