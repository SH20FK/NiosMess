import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GradientIconButton extends StatelessWidget {
  final LinearGradient gradient;
  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback? onTap;

  const GradientIconButton({
    super.key,
    required this.gradient,
    required this.icon,
    this.size = 48,
    this.iconSize = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = gradient.colors.isNotEmpty ? gradient.colors.first : scheme.primaryContainer;
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: iconSize),
        style: IconButton.styleFrom(
          backgroundColor: base,
          foregroundColor: scheme.onPrimaryContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(size / 2)),
        ),
      ),
    );
  }
}

class ThemePreviewCard extends StatefulWidget {
  final String label;
  final bool isSelected;
  final Color topBarColor;
  final Color bubbleLeftColor;
  final Color bubbleRightColor;
  final VoidCallback? onTap;

  const ThemePreviewCard({
    super.key,
    required this.label,
    this.isSelected = false,
    required this.topBarColor,
    required this.bubbleLeftColor,
    required this.bubbleRightColor,
    this.onTap,
  });

  @override
  State<ThemePreviewCard> createState() => _ThemePreviewCardState();
}

class _ThemePreviewCardState extends State<ThemePreviewCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = widget.isSelected ? scheme.primary : scheme.outlineVariant;

    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _pressed ? 0.98 : 1.0,
      child: SizedBox(
        width: 160,
        height: 120,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor),
          ),
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: _setPressed,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: 120,
                      decoration: BoxDecoration(
                        color: scheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 120,
                            height: 8,
                            decoration: BoxDecoration(
                              color: widget.topBarColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.only(left: 8, right: 32),
                            child: Container(
                              width: 80,
                              height: 12,
                              decoration: BoxDecoration(
                                color: widget.bubbleLeftColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 52, right: 8),
                            child: Container(
                              width: 60,
                              height: 12,
                              decoration: BoxDecoration(
                                color: widget.bubbleRightColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  final LinearGradient gradient;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const SettingsRow({
    super.key,
    required this.gradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = gradient.colors.isNotEmpty ? gradient.colors.first : scheme.primaryContainer;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ListTile(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
        leading: CircleAvatar(
          backgroundColor: accent,
          child: Icon(icon, color: scheme.onPrimaryContainer),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class FloatingBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const FloatingBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Чаты'),
        NavigationDestination(icon: Icon(Icons.phone), label: 'Звонки'),
        NavigationDestination(icon: Icon(Icons.people), label: 'Контакты'),
        NavigationDestination(icon: Icon(Icons.settings), label: 'Настройки'),
      ],
    );
  }
}

class ProfileHeader extends StatelessWidget {
  final String name;
  final String username;
  final String phone;
  final double avatarSize;
  final bool isLarge;
  final bool useGlass;
  final VoidCallback? onAvatarTap;

  const ProfileHeader({
    super.key,
    required this.name,
    required this.username,
    required this.phone,
    this.avatarSize = 100,
    this.isLarge = false,
    this.useGlass = true,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final content = Column(
      children: [
        InkWell(
          onTap: onAvatarTap,
          borderRadius: BorderRadius.circular(avatarSize / 2),
          child: Stack(
            children: [
              CircleAvatar(
                radius: avatarSize / 2,
                backgroundColor: scheme.surfaceVariant,
                backgroundImage: const NetworkImage('https://i.pravatar.cc/300?img=11'),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: IconButton.filled(
                  onPressed: onAvatarTap,
                  icon: const Icon(Icons.camera_alt, size: 16),
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    padding: const EdgeInsets.all(6),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          name,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(username, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(phone, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );

    if (!useGlass) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16, isLarge ? 40 : 24, 16, isLarge ? 24 : 24),
        child: content,
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, isLarge ? 40 : 24, 16, isLarge ? 24 : 24),
        child: content,
      ),
    );
  }
}

class ChatListItem extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isOnline;
  final bool isGroup;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ChatListItem({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
    this.isOnline = false,
    this.isGroup = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUnread = unreadCount > 0;
    final displayCount = unreadCount > 99 ? '99+' : unreadCount.toString();

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      onLongPress: onLongPress,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: scheme.surfaceVariant,
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              child: avatarUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface),
                    )
                  : null,
            ),
            if (isOnline && !isGroup)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: scheme.tertiary,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isUnread ? scheme.onSurface : scheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isUnread ? scheme.primary : scheme.onSurfaceVariant,
                  ),
            ),
            if (isUnread) ...[
              const SizedBox(height: 6),
              Badge(
                label: Text(
                  displayCount,
                  style: TextStyle(color: scheme.onPrimary),
                ),
                backgroundColor: scheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NiosSearchBar extends StatefulWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;

  const NiosSearchBar({
    super.key,
    this.hint = 'Поиск...',
    this.onChanged,
    this.controller,
  });

  @override
  State<NiosSearchBar> createState() => _NiosSearchBarState();
}

class _NiosSearchBarState extends State<NiosSearchBar> {
  late final TextEditingController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _controller = TextEditingController();
      _ownsController = true;
    } else {
      _controller = widget.controller!;
    }
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    widget.onChanged?.call(_controller.text);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    return SearchBar(
      controller: _controller,
      hintText: widget.hint,
      leading: const Icon(Icons.search),
      trailing: hasText
          ? [
              IconButton(
                onPressed: _controller.clear,
                icon: const Icon(Icons.close),
              ),
            ]
          : null,
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
