import 'package:flutter/material.dart';

class BadgeChip extends StatelessWidget {
  const BadgeChip({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.showName = false,
    this.interactive = true,
    super.key,
  });

  final int id;
  final String name;
  final String icon;
  final String color;
  final bool showName;
  final bool interactive;

  bool _isEmoji(String text) {
    if (text.isEmpty) return false;
    for (final int rune in text.runes) {
      if (rune >= 0x1F300 && rune <= 0x1F9FF) return true; // Symbols, Pictographs, Emoticons, Supplemental
      if (rune >= 0x2600 && rune <= 0x27BF) return true;   // Misc Symbols, Dingbats
      if (rune >= 0x1F600 && rune <= 0x1F64F) return true; // Emoticons
      if (rune >= 0x1F680 && rune <= 0x1F6FF) return true; // Transport/Map
      if (rune >= 0x1F1E6 && rune <= 0x1F1FF) return true; // Flags
      if (rune >= 0x2B50 && rune <= 0x2B50) return true;   // Star ⭐
      if (rune >= 0x2300 && rune <= 0x23FF) return true;   // Misc Technical
      if (rune >= 0x2900 && rune <= 0x29FF) return true;   // Supplemental Equations
      if (rune >= 0x3030 && rune <= 0x303D) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color badgeColor = _parseColor(color, scheme);
    final _BadgeVisual visual = _resolveVisual();

    final Widget content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: showName ? 8 : 4,
        vertical: showName ? 4 : 3,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(badgeColor.withValues(alpha: 0.15), scheme.surfaceContainerHigh),
            Color.alphaBlend(badgeColor.withValues(alpha: 0.05), scheme.surfaceContainerHigh),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.28),
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.08),
            blurRadius: 6,
            spreadRadius: 0.5,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: showName ? 20 : 18,
            height: showName ? 20 : 18,
            decoration: BoxDecoration(
              color: visual.emoji != null
                  ? Colors.transparent
                  : badgeColor.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: visual.emoji != null
                ? Text(
                    visual.emoji!,
                    style: TextStyle(
                      fontSize: showName ? 13 : 11.5,
                      height: 1.1,
                    ),
                  )
                : Text(
                    visual.fallbackText,
                    style: textTheme.labelSmall?.copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
          ),
          if (showName && name.trim().isNotEmpty) ...<Widget>[
            const SizedBox(width: 6),
            Text(
              name.trim(),
              style: textTheme.labelSmall?.copyWith(
                color: badgeColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );

    if (!interactive) return content;

    return Tooltip(
      message: name.trim().isEmpty ? 'Badge' : name.trim(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => _showDetails(context, badgeColor, visual),
          child: content,
        ),
      ),
    );
  }

  Future<void> _showDetails(
    BuildContext context,
    Color badgeColor,
    _BadgeVisual visual,
  ) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: scheme.surfaceContainerHigh,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.22),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: visual.emoji != null
                        ? Text(
                            visual.emoji!,
                            style: const TextStyle(
                              fontSize: 32,
                            ),
                          )
                        : Text(
                            visual.fallbackText,
                            style: textTheme.headlineSmall?.copyWith(
                              color: badgeColor,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name.trim().isEmpty ? 'Server badge' : name.trim(),
                          style: textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Account tag shown in lists, chats, and profiles.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(_descriptionText(), style: textTheme.bodyMedium),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _detailPill(context, badgeColor, 'Profile'),
                  _detailPill(context, badgeColor, 'Chats'),
                  _detailPill(context, badgeColor, 'Messages'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailPill(BuildContext context, Color badgeColor, String label) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: textTheme.labelMedium?.copyWith(
          color: badgeColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _descriptionText() {
    final String badgeName = name.trim();
    if (badgeName.isEmpty) {
      return 'This badge highlights a role, account status, or recognition inside NiosMess.';
    }

    return '$badgeName highlights a role, account status, or recognition inside NiosMess.';
  }

  _BadgeVisual _resolveVisual() {
    final String cleanIcon = icon.trim();
    if (_isEmoji(cleanIcon)) {
      return _BadgeVisual(emoji: cleanIcon);
    }

    final String source = '${name.toLowerCase()} ${icon.toLowerCase()}';

    if (source.contains('verified') ||
        source.contains('check') ||
        icon.contains('✔') ||
        icon.contains('✅')) {
      return const _BadgeVisual(emoji: '✅');
    }
    if (source.contains('crown') ||
        source.contains('premium') ||
        icon.contains('👑')) {
      return const _BadgeVisual(emoji: '👑');
    }
    if (source.contains('hammer') ||
        source.contains('tool') ||
        source.contains('build') ||
        icon.contains('🛠')) {
      return const _BadgeVisual(emoji: '🛠');
    }
    if (source.contains('shield') ||
        source.contains('mod') ||
        source.contains('admin')) {
      return const _BadgeVisual(emoji: '🛡');
    }
    if (source.contains('star')) {
      return const _BadgeVisual(emoji: '⭐');
    }
    if (source.contains('bot')) {
      return const _BadgeVisual(emoji: '🤖');
    }
    if (source.contains('support')) {
      return const _BadgeVisual(emoji: '💬');
    }
    if (source.contains('code') || source.contains('dev')) {
      return const _BadgeVisual(emoji: '💻');
    }

    final String fallback = name.trim().isNotEmpty
        ? String.fromCharCode(name.trim().runes.first).toUpperCase()
        : (cleanIcon.isNotEmpty
              ? String.fromCharCode(cleanIcon.runes.first).toUpperCase()
              : '•');

    if (_isEmoji(fallback)) {
      return _BadgeVisual(emoji: fallback);
    }
    return _BadgeVisual(fallbackText: fallback);
  }

  Color _parseColor(String hexColor, ColorScheme scheme) {
    if (hexColor.isEmpty) return scheme.primary;
    try {
      final String cleanHex = hexColor.replaceAll('#', '');
      if (cleanHex.length == 6) return Color(int.parse('0xFF$cleanHex'));
      if (cleanHex.length == 8) return Color(int.parse('0x$cleanHex'));
      return scheme.primary;
    } catch (_) {
      return scheme.primary;
    }
  }
}

class BadgeOverflowChip extends StatelessWidget {
  const BadgeOverflowChip({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.16),
        ),
      ),
      child: Text(
        '+$count',
        style: textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BadgeVisual {
  const _BadgeVisual({this.emoji, this.fallbackText = '•'});

  final String? emoji;
  final String fallbackText;
}
