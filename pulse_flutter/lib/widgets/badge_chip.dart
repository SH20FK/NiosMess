import 'package:flutter/material.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';

enum BadgeDisplayMode {
  /// Рядом с именем: свечение, только иконка
  statusIcon,
  /// Под ником: тонкая капсула 8% прозрачности, иконка + текст
  infoLabel,
  /// В углу аватарки: круг с иконкой
  avatarBadge,
}

enum _BadgeType { verified, developer, admin, premium, support, bot, default_ }

class _BadgeResolved {
  const _BadgeResolved({
    required this.type,
    this.iconData,
    this.emoji,
    this.fallbackText = '\u2022',
  });

  final _BadgeType type;
  final IconData? iconData;
  final String? emoji;
  final String fallbackText;

  bool get hasIcon => iconData != null;
  bool get hasEmoji => emoji != null;
}

class BadgeResolver {
  static bool _isEmoji(String text) {
    if (text.isEmpty) return false;
    for (final int rune in text.runes) {
      if (rune >= 0x1F300 && rune <= 0x1F9FF) return true;
      if (rune >= 0x2600 && rune <= 0x27BF) return true;
      if (rune >= 0x1F600 && rune <= 0x1F64F) return true;
      if (rune >= 0x1F680 && rune <= 0x1F6FF) return true;
      if (rune >= 0x1F1E6 && rune <= 0x1F1FF) return true;
      if (rune >= 0x2B50 && rune <= 0x2B50) return true;
      if (rune >= 0x2300 && rune <= 0x23FF) return true;
      if (rune >= 0x2900 && rune <= 0x29FF) return true;
      if (rune >= 0x3030 && rune <= 0x303D) return true;
    }
    return false;
  }

  static _BadgeResolved resolve(String name, String icon) {
    final String cleanIcon = icon.trim();
    if (_isEmoji(cleanIcon)) {
      return _BadgeResolved(type: _BadgeType.default_, emoji: cleanIcon);
    }

    final String source = '${name.toLowerCase()} ${icon.toLowerCase()}';

    if (source.contains('verified') || source.contains('check') ||
        icon.contains('\u2714') || icon.contains('\u2705')) {
      return const _BadgeResolved(
        type: _BadgeType.verified,
        iconData: Icons.verified_rounded,
      );
    }
    if (source.contains('crown') || source.contains('founder') ||
        source.contains('premium') || icon.contains('\uD83D\uDC51')) {
      return const _BadgeResolved(
        type: _BadgeType.premium,
        iconData: Icons.workspace_premium_rounded,
      );
    }
    if (source.contains('hammer') || source.contains('tool') ||
        source.contains('build') || icon.contains('\uD83D\uDD20') ||
        source.contains('code') || source.contains('dev')) {
      return const _BadgeResolved(
        type: _BadgeType.developer,
        iconData: Icons.code_rounded,
      );
    }
    if (source.contains('shield') || source.contains('mod') ||
        source.contains('admin')) {
      return const _BadgeResolved(
        type: _BadgeType.admin,
        iconData: Icons.shield_rounded,
      );
    }
    if (source.contains('star')) {
      return const _BadgeResolved(
        type: _BadgeType.premium,
        iconData: Icons.star_rounded,
      );
    }
    if (source.contains('bot')) {
      return const _BadgeResolved(
        type: _BadgeType.bot,
        iconData: Icons.smart_toy_rounded,
      );
    }
    if (source.contains('support')) {
      return const _BadgeResolved(
        type: _BadgeType.support,
        iconData: Icons.headset_mic_rounded,
      );
    }

    final String fallback = name.trim().isNotEmpty
        ? String.fromCharCode(name.trim().runes.first).toUpperCase()
        : (cleanIcon.isNotEmpty
            ? String.fromCharCode(cleanIcon.runes.first).toUpperCase()
            : '\u2022');

    if (_isEmoji(fallback)) {
      return _BadgeResolved(type: _BadgeType.default_, emoji: fallback);
    }
    return _BadgeResolved(type: _BadgeType.default_, fallbackText: fallback);
  }

  static bool isStatusBadge(ApiBadge badge) {
    final res = resolve(badge.name, badge.icon);
    // Founder, Premium, Verified, Admin go to the name line as status icons
    return res.type == _BadgeType.verified ||
           res.type == _BadgeType.premium ||
           res.type == _BadgeType.admin;
  }
}

class BadgeChip extends StatelessWidget {
  const BadgeChip({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.mode = BadgeDisplayMode.infoLabel,
    this.showName = false,
    this.interactive = true,
    super.key,
  });

  final int id;
  final String name;
  final String icon;
  final String color;
  final BadgeDisplayMode mode;
  final bool showName;
  final bool interactive;

  Widget _buildIcon(
    _BadgeResolved resolved,
    Color color,
    double size, {
    bool isAvatar = false,
  }) {
    if (resolved.hasIcon) {
      return Icon(resolved.iconData, color: color, size: size);
    } else if (resolved.hasEmoji) {
      return Text(
        resolved.emoji!,
        style: TextStyle(fontSize: size * 0.9, height: 1),
        textAlign: TextAlign.center,
      );
    } else {
      return Text(
        resolved.fallbackText,
        style: TextStyle(
          color: color,
          fontSize: size * 0.85,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
        textAlign: TextAlign.center,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final _BadgeResolved resolved = BadgeResolver.resolve(name, icon);

    Widget child;

    switch (mode) {
      case BadgeDisplayMode.statusIcon:
        // A. Блок Имени: Монохромный глянцевый значок со свечением
        child = Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.35),
                blurRadius: 10,
                spreadRadius: -2,
              ),
            ],
          ),
          child: _buildIcon(resolved, scheme.primary, 18),
        );
        break;

      case BadgeDisplayMode.avatarBadge:
        // Б. Блок Аватара: Круглый бейдж в углу
        child = Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: scheme.tertiary,
            shape: BoxShape.circle,
            border: Border.all(
              color: scheme.surfaceContainerLow,
              width: 2.5,
            ),
          ),
          alignment: Alignment.center,
          child: _buildIcon(resolved, scheme.onTertiary, 12, isAvatar: true),
        );
        break;

      case BadgeDisplayMode.infoLabel:
        // В. Блок Под Именем: Тонкая капсула-невидимка
        Color effectiveColor = scheme.primary;
        if (color.isNotEmpty) {
          try {
            final String hex = color.replaceFirst('#', '').replaceFirst('0x', '');
            final int? value = int.tryParse(hex, radix: 16);
            if (value != null) {
              effectiveColor = Color(hex.length <= 6 ? (value | 0xFF000000) : value);
            }
          } catch (_) {}
        }
        child = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIcon(resolved, effectiveColor, 12),
              if (showName && name.trim().isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  name.trim(),
                  style: textTheme.labelSmall?.copyWith(
                    color: effectiveColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        );
        break;
    }

    if (!interactive || mode == BadgeDisplayMode.avatarBadge) {
      return Semantics(
        label: name.trim().isEmpty ? 'Badge' : name.trim(),
        child: child,
      );
    }

    return Tooltip(
      message: name.trim().isEmpty ? 'Badge' : name.trim(),
      child: Semantics(
        label: name.trim().isEmpty ? 'Badge' : name.trim(),
        child: child,
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        '+$count',
        style: textTheme.labelSmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
