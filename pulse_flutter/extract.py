import re

with open('lib/widgets/message_bubble.dart', 'r') as f:
    content = f.read()

# I will write the extracted classes to the bottom of the file
classes_to_add = """
class _MessageBubbleHeader extends StatelessWidget {
  const _MessageBubbleHeader({
    required this.isMine,
    required this.senderDisplayName,
    required this.senderAvatarUrl,
    required this.visibleBadges,
    required this.hiddenBadgeCount,
    required this.scheme,
    required this.textTheme,
  });

  final bool isMine;
  final String? senderDisplayName;
  final String? senderAvatarUrl;
  final List<ApiBadge> visibleBadges;
  final int hiddenBadgeCount;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    if (isMine || ((senderDisplayName ?? '').trim().isEmpty && visibleBadges.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: <Widget>[
          if (senderAvatarUrl != null && senderAvatarUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: senderAvatarUrl!,
                width: 16,
                height: 16,
                memCacheWidth: 32,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          if ((senderDisplayName ?? '').trim().isNotEmpty)
            Text(
              senderDisplayName!,
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
          ...visibleBadges.map(
            (ApiBadge badge) => BadgeChip(
              id: badge.id,
              name: badge.name,
              icon: badge.icon,
              color: badge.color,
              interactive: false,
            ),
          ),
          if (hiddenBadgeCount > 0)
            BadgeOverflowChip(count: hiddenBadgeCount),
        ],
      ),
    );
  }
}

class _MessageBubbleFooter extends StatelessWidget {
  const _MessageBubbleFooter({
    required this.isMine,
    required this.isE2ee,
    required this.isEdited,
    required this.isDeleted,
    required this.isRead,
    required this.formattedTime,
    required this.scheme,
    required this.textTheme,
  });

  final bool isMine;
  final bool isE2ee;
  final bool isEdited;
  final bool isDeleted;
  final bool isRead;
  final String formattedTime;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (isE2ee) ...[
          Icon(
            Icons.lock_rounded,
            size: 11,
            color: Colors.green.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 3),
        ],
        if (isEdited)
          Text(
            context.l10n.chatEdited,
            style: textTheme.labelSmall?.copyWith(
              fontSize: 11,
              color: scheme.onSurfaceVariant.withValues(
                alpha: 0.7,
              ),
            ),
          ),
        if (isEdited) const SizedBox(width: 4),
        Text(
          formattedTime,
          style: textTheme.labelSmall?.copyWith(
            fontSize: 11,
            color: scheme.onSurfaceVariant.withValues(
              alpha: 0.7,
            ),
          ),
        ),
        if (isMine && !isDeleted) ...<Widget>[
          const SizedBox(width: 3),
          Icon(
            isRead
                ? Icons.done_all_rounded
                : Icons.check_rounded,
            size: 13,
            color: scheme.primary.withValues(alpha: 0.8),
          ),
        ],
      ],
    );
  }
}
"""

if "_MessageBubbleHeader" not in content:
    content += classes_to_add

old_header = """                        if (!isMine &&
                            ((senderDisplayName ?? '').trim().isNotEmpty ||
                                visibleBadges.isNotEmpty)) ...<Widget>[
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            runSpacing: 4,
                            children: <Widget>[
                              if (senderAvatarUrl != null && senderAvatarUrl!.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CachedNetworkImage(
                                    imageUrl: senderAvatarUrl!,
                                    width: 16,
                                    height: 16,
                                    memCacheWidth: 32,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                                  ),
                                ),
                              if ((senderDisplayName ?? '').trim().isNotEmpty)
                                Text(
                                  senderDisplayName!,
                                  style: textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: scheme.primary,
                                  ),
                                ),
                              ...visibleBadges.map(
                                (ApiBadge badge) => BadgeChip(
                                  id: badge.id,
                                  name: badge.name,
                                  icon: badge.icon,
                                  color: badge.color,
                                  interactive: false,
                                ),
                              ),
                              if (hiddenBadgeCount > 0)
                                BadgeOverflowChip(count: hiddenBadgeCount),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],"""

new_header = """                        _MessageBubbleHeader(
                          isMine: isMine,
                          senderDisplayName: senderDisplayName,
                          senderAvatarUrl: senderAvatarUrl,
                          visibleBadges: visibleBadges,
                          hiddenBadgeCount: hiddenBadgeCount,
                          scheme: scheme,
                          textTheme: textTheme,
                        ),"""

content = content.replace(old_header, new_header)

old_footer = """                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (isE2ee) ...[
                            Icon(
                              Icons.lock_rounded,
                              size: 11,
                              color: Colors.green.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 3),
                          ],
                          if (isEdited)
                            Text(
                              context.l10n.chatEdited,
                              style: textTheme.labelSmall?.copyWith(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          if (isEdited) const SizedBox(width: 4),
                          Text(
                            formattedTime,
                            style: textTheme.labelSmall?.copyWith(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          if (isMine && !isDeleted) ...<Widget>[
                            const SizedBox(width: 3),
                            Icon(
                              isRead
                                  ? Icons.done_all_rounded
                                  : Icons.check_rounded,
                              size: 13,
                              color: scheme.primary.withValues(alpha: 0.8),
                            ),
                          ],
                        ],
                      ),
                    ),"""

new_footer = """                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: _MessageBubbleFooter(
                        isMine: isMine,
                        isE2ee: isE2ee,
                        isEdited: isEdited,
                        isDeleted: isDeleted,
                        isRead: isRead,
                        formattedTime: formattedTime,
                        scheme: scheme,
                        textTheme: textTheme,
                      ),
                    ),"""

content = content.replace(old_footer, new_footer)

with open('lib/widgets/message_bubble.dart', 'w') as f:
    f.write(content)
