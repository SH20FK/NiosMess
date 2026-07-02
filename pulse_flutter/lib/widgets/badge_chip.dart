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

enum _BadgeType { verified, developer, admin, premium, support, bot, fire, diamond, trophy, default_ }

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
  static const Map<String, IconData> _emojiToIcon = <String, IconData>{
    '\u2705': Icons.check_circle_rounded,
    '\u2714': Icons.verified_rounded,
    '\uD83D\uDC51': Icons.workspace_premium_rounded,
    '\uD83D\uDD20': Icons.code_rounded,
    '\uD83D\uDEE0': Icons.build_rounded,
    '\uD83D\uDCBB': Icons.computer_rounded,
    '\uD83D\uDC68\u200D\uD83D\uDCBB': Icons.developer_board_rounded,
    '\uD83D\uDD12': Icons.lock_rounded,
    '\uD83D\uDD35': Icons.shield_rounded,
    '\uD83D\uDEE1': Icons.shield_rounded,
    '\u2B50': Icons.star_rounded,
    '\u2B50\uFE0F': Icons.star_rounded,
    '\uD83C\uDF1F': Icons.auto_awesome_rounded,
    '\uD83E\uDD16': Icons.smart_toy_rounded,
    '\uD83D\uDC7E': Icons.smart_toy_rounded,
    '\uD83D\uDCFB': Icons.headset_mic_rounded,
    '\uD83D\uDDA5': Icons.headset_mic_rounded,
    '\uD83D\uDD25': Icons.local_fire_department_rounded,
    '\uD83D\uDD25\uFE0F': Icons.local_fire_department_rounded,
    '\uD83D\uDC8E': Icons.diamond_rounded,
    '\uD83C\uDFC6': Icons.emoji_events_rounded,
    '\uD83C\uDFC5': Icons.emoji_events_rounded,
    '\uD83C\uDFAF': Icons.gps_fixed_rounded,
    '\uD83D\uDCA1': Icons.lightbulb_rounded,
    '\uD83C\uDFA8': Icons.palette_rounded,
    '\uD83D\uDCF8': Icons.camera_alt_rounded,
    '\uD83C\uDFB5': Icons.music_note_rounded,
    '\uD83C\uDFB6': Icons.queue_music_rounded,
    '\uD83D\uDCB0': Icons.monetization_on_rounded,
    '\uD83D\uDCB3': Icons.payments_rounded,
    '\uD83D\uDCAF': Icons.bolt_rounded,
    '\u26A1': Icons.bolt_rounded,
    '\u26A1\uFE0F': Icons.bolt_rounded,
    '\uD83C\uDF81': Icons.card_giftcard_rounded,
    '\uD83D\uDCA3': Icons.whatshot_rounded,
    '\uD83D\uDC4D': Icons.thumb_up_rounded,
    '\uD83D\uDC4E': Icons.thumb_down_rounded,
    '\uD83D\uDE0D': Icons.favorite_rounded,
    '\u2764': Icons.favorite_rounded,
    '\u2764\uFE0F': Icons.favorite_rounded,
    '\uD83D\uDCAB': Icons.auto_awesome_rounded,
    '\uD83C\uDF08': Icons.auto_awesome_rounded,
    '\uD83C\uDF19': Icons.nightlight_round,
    '\uD83C\uDF1E': Icons.wb_sunny_rounded,
    '\uD83D\uDC36': Icons.pets_rounded,
    '\uD83D\uDC31': Icons.pets_rounded,
    '\uD83D\uDE80': Icons.rocket_launch_rounded,
    '\uD83D\uDD10': Icons.lock_rounded,
    '\uD83D\uDD11': Icons.key_rounded,
    '\u2139': Icons.info_rounded,
    '\u2139\uFE0F': Icons.info_rounded,
    '\u2757': Icons.error_rounded,
    '\u2753': Icons.help_rounded,
    '\u267E': Icons.accessibility_new_rounded,
    '\u267E\uFE0F': Icons.accessibility_new_rounded,
    '\uD83C\uDD98': Icons.add_moderator_rounded,
    '\uD83D\uDEAB': Icons.block_rounded,
  };

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

    // Phase 1: keyword-based resolution (most reliable)
    final _BadgeResolved? keyword = _resolveByKeywords(name, cleanIcon);
    if (keyword != null) return keyword;

    // Phase 2: emoji → try mapping, then fallback to icon
    if (_isEmoji(cleanIcon)) {
      final IconData? mapped = _emojiToIcon[cleanIcon];
      if (mapped != null) {
        return _BadgeResolved(type: _BadgeType.default_, iconData: mapped);
      }
      // Unknown emoji — still show as icon, not as text emoji
      return _BadgeResolved(type: _BadgeType.default_, emoji: cleanIcon);
    }

    // Phase 3: plain text icon field that looks like a known symbol
    if (cleanIcon == '\u2714' || cleanIcon == '\u2714\uFE0F' ||
        cleanIcon == '\u2705' || cleanIcon == '\u2713') {
      return const _BadgeResolved(type: _BadgeType.verified, iconData: Icons.verified_rounded);
    }

    // Phase 4: first-letter fallback
    final String fallback = name.trim().isNotEmpty
        ? String.fromCharCode(name.trim().runes.first).toUpperCase()
        : (cleanIcon.isNotEmpty && !_isEmoji(cleanIcon)
            ? String.fromCharCode(cleanIcon.runes.first).toUpperCase()
            : '\u2022');
    return _BadgeResolved(type: _BadgeType.default_, fallbackText: fallback);
  }

  static _BadgeResolved? _resolveByKeywords(String name, String icon) {
    final String source = '${name.toLowerCase()} ${icon.toLowerCase()}';

    if (source.contains('verified') || source.contains('check') ||
        source.contains('confirm') || source.contains('auth')) {
      return const _BadgeResolved(type: _BadgeType.verified, iconData: Icons.verified_rounded);
    }
    if (source.contains('crown') || source.contains('founder') ||
        source.contains('premium') || source.contains('vip') ||
        source.contains('king') || source.contains('queen')) {
      return const _BadgeResolved(type: _BadgeType.premium, iconData: Icons.workspace_premium_rounded);
    }
    if (source.contains('hammer') || source.contains('tool') ||
        source.contains('build') || source.contains('code') ||
        source.contains('dev') || source.contains('engineer') ||
        source.contains('developer')) {
      return const _BadgeResolved(type: _BadgeType.developer, iconData: Icons.build_rounded);
    }
    if (source.contains('shield') || source.contains('mod') ||
        source.contains('admin') || source.contains('guard')) {
      return const _BadgeResolved(type: _BadgeType.admin, iconData: Icons.shield_rounded);
    }
    if (source.contains('star') || source.contains('top') ||
        source.contains('best') || source.contains('mvp')) {
      return const _BadgeResolved(type: _BadgeType.premium, iconData: Icons.star_rounded);
    }
    if (source.contains('bot') || source.contains('ai') ||
        source.contains('auto') || source.contains('system')) {
      return const _BadgeResolved(type: _BadgeType.bot, iconData: Icons.smart_toy_rounded);
    }
    if (source.contains('support') || source.contains('help') ||
        source.contains('service')) {
      return const _BadgeResolved(type: _BadgeType.support, iconData: Icons.headset_mic_rounded);
    }
    if (source.contains('fire') || source.contains('hot') ||
        source.contains('flame') || source.contains('lit')) {
      return const _BadgeResolved(type: _BadgeType.fire, iconData: Icons.local_fire_department_rounded);
    }
    if (source.contains('diamond') || source.contains('gem') ||
        source.contains('jewel') || source.contains('elite')) {
      return const _BadgeResolved(type: _BadgeType.diamond, iconData: Icons.diamond_rounded);
    }
    if (source.contains('trophy') || source.contains('winner') ||
        source.contains('champion') || source.contains('award')) {
      return const _BadgeResolved(type: _BadgeType.trophy, iconData: Icons.emoji_events_rounded);
    }
    if (source.contains('bolt') || source.contains('lightning') ||
        source.contains('fast') || source.contains('power')) {
      return const _BadgeResolved(type: _BadgeType.default_, iconData: Icons.bolt_rounded);
    }
    if (source.contains('lock') || source.contains('secure')) {
      return const _BadgeResolved(type: _BadgeType.default_, iconData: Icons.lock_rounded);
    }
    if (source.contains('key') || source.contains('access')) {
      return const _BadgeResolved(type: _BadgeType.default_, iconData: Icons.key_rounded);
    }
    if (source.contains('info') || source.contains('notice')) {
      return const _BadgeResolved(type: _BadgeType.default_, iconData: Icons.info_rounded);
    }
    if (source.contains('alert') || source.contains('warn')) {
      return const _BadgeResolved(type: _BadgeType.default_, iconData: Icons.warning_rounded);
    }
    if (source.contains('love') || source.contains('heart')) {
      return const _BadgeResolved(type: _BadgeType.default_, iconData: Icons.favorite_rounded);
    }
    if (source.contains('new') || source.contains('fresh')) {
      return const _BadgeResolved(type: _BadgeType.default_, iconData: Icons.new_releases_rounded);
    }
    return null;
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
