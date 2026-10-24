import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulse_flutter/core/utils/noto_emoji.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/chat/bubble/bubble_text_renderer.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

class CommentIcon extends StatelessWidget {
  const CommentIcon(this.kind, {super.key, this.size = 20, this.color});
  final String kind;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">'
    '${switch (kind) {
      'back' => '<path d="m12 5-7 7 7 7M5 12h14"/>',
      'reply' => '<path d="m9 5-6 6 6 6M3 11h10a8 8 0 0 1 8 8"/>',
      'send' => '<path d="m5 12 7-7 7 7M12 5v15"/>',
      'close' => '<path d="m6 6 12 12M6 18 18 6"/>',
      'more' => '<circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/>',
      'like' => '<path d="M7 10H3v11h4m0-11 5-8c3 0 2 5 1 8h6a2 2 0 0 1 2 2l-2 7a3 3 0 0 1-3 2H7Z"/>',
      'heart' => '<path d="M20 5c-3-3-7-1-8 1-1-2-5-4-8-1-4 4 2 10 8 15 6-5 12-11 8-15Z"/>',
      'down' => '<path d="m6 9 6 6 6-6"/>',
      'up' => '<path d="m6 15 6-6 6 6"/>',
      'surprise' => '<circle cx="12" cy="12" r="9"/><ellipse cx="12" cy="15" rx="2" ry="3"/><path d="M8 8h.01M16 8h.01"/>',
      'sad' => '<circle cx="12" cy="12" r="9"/><path d="M8 17c2-3 6-3 8 0M8 9h.01M16 9h.01"/>',
      _ => '<circle cx="12" cy="12" r="9"/><path d="M8 14c2 3 6 3 8 0M8 9h.01M16 9h.01"/>',
    }}</svg>',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(
      color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      BlendMode.srcIn,
    ),
  );
}

class CommentItem extends StatelessWidget {
  const CommentItem({
    super.key,
    required this.comment,
    required this.isMine,
    required this.onReply,
    required this.onAuthorTap,
    required this.onReact,
    this.parent,
    this.isPostAuthor = false,
    this.depth = 0,
    this.replyCount = 0,
    this.collapsed = false,
    this.onToggleReplies,
    this.onEdit,
    this.onDelete,
    this.onQualityReport,
    this.qualityReported = false,
    this.continueParentLine = false,
  });
  final ApiMessage comment;
  final ApiMessage? parent;
  final bool isMine;
  final bool isPostAuthor;
  final int depth;
  final int replyCount;
  final bool collapsed;
  final VoidCallback onReply;
  final VoidCallback onAuthorTap;
  final VoidCallback? onToggleReplies;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onQualityReport;
  final bool qualityReported;
  final bool continueParentLine;
  final ValueChanged<String> onReact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = comment.senderDisplayName.trim().isNotEmpty
        ? comment.senderDisplayName
        : comment.senderUsername;
    final username = comment.senderUsername.trim();
    final count = comment.reactions['👍'] ?? 0;
    const reactionKinds = {
      '❤️': 'heart',
      '😂': 'laugh',
      '😮': 'surprise',
      '😢': 'sad',
    };
    return CustomPaint(
      painter: CommentBranchPainter(
        depth: depth,
        hasReplies: replyCount > 0 && !collapsed,
        continueParent: continueParentLine,
        color: scheme.outlineVariant,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16 + depth.clamp(0, 3) * 24.0, 12, 12, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              label: 'Профиль $name',
              child: InkWell(
                onTap: onAuthorTap,
                borderRadius: BorderRadius.circular(20),
                child: PulseAvatar(
                  name: name,
                  avatarUrl: comment.senderAvatarUrl,
                  radius: depth == 0 ? 18 : 15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      InkWell(
                        onTap: onAuthorTap,
                        child: Text(
                          name.isEmpty ? 'Удалённый аккаунт' : name,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ...comment.senderBadges.map(
                        (badge) => BadgeChip(
                          id: badge.id,
                          name: badge.name,
                          icon: badge.icon,
                          color: badge.color,
                          interactive: false,
                        ),
                      ),
                      if (isPostAuthor)
                        Text(
                          'Автор',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                      if (username.isNotEmpty)
                        Text(
                          '@$username',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      Tooltip(
                        message: comment.sentAt.toLocal().toString(),
                        child: Text(
                          formatMessageTime(comment.sentAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (comment.isEdited && !comment.isDeleted)
                        Text(
                          'изменено',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  if (parent != null && depth > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        'В ответ ${parent!.senderDisplayName.isNotEmpty ? parent!.senderDisplayName : parent!.senderUsername}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 5),
                  if (comment.isDeleted)
                    Text(
                      'Комментарий удалён',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  else
                    InteractiveMessageText(
                      text: comment.content,
                      baseStyle: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onSurface,
                        height: 1.4,
                      ),
                      isMine: false,
                      scheme: scheme,
                    ),
                  Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (!comment.isDeleted) ...[
                        TextButton(
                          onPressed: onReply,
                          child: const Text('Ответить'),
                        ),
                        TextButton.icon(
                          onPressed: () => onReact('like'),
                          icon: const Text(
                            '👍',
                            style: TextStyle(
                              fontFamily: NotoEmoji.fontFamily,
                              fontSize: 18,
                            ),
                          ),
                          label: Text(count > 0 ? '$count' : 'Нравится'),
                        ),
                        for (final entry in comment.reactions.entries)
                          if (entry.key != '👍' && entry.value > 0)
                            TextButton.icon(
                              onPressed: () =>
                                  onReact(reactionKinds[entry.key] ?? 'like'),
                              icon: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontFamily: NotoEmoji.fontFamily,
                                  fontSize: 18,
                                ),
                              ),
                              label: Text('${entry.value}'),
                            ),
                        PopupMenuButton<String>(
                          tooltip: 'Действия с комментарием',
                          icon: const CommentIcon('more'),
                          onSelected: (action) {
                            if (action == 'copy') {
                              Clipboard.setData(
                                ClipboardData(text: comment.content),
                              );
                            }
                            if (action == 'quality') onQualityReport?.call();
                            if (action == 'edit') onEdit?.call();
                            if (action == 'delete') onDelete?.call();
                            if (action.startsWith('reaction:')) {
                              onReact(action.substring(9));
                            }
                          },
                          itemBuilder: (_) => [
                            if (onQualityReport != null || qualityReported)
                              PopupMenuItem(
                                value: 'quality',
                                enabled: !qualityReported,
                                child: Text(
                                  qualityReported
                                      ? 'Жалоба на качество отправлена'
                                      : 'Пожаловаться на качество ответа модели',
                                ),
                              ),

                            const PopupMenuItem(
                              value: 'copy',
                              child: Text('Копировать'),
                            ),
                            for (final reaction in const {
                              'heart': 'Люблю',
                              'laugh': 'Смешно',
                              'surprise': 'Удивительно',
                              'sad': 'Грустно',
                            }.entries)
                              PopupMenuItem(
                                value: 'reaction:${reaction.key}',
                                child: Row(
                                  children: [
                                    Text(
                                      const {
                                        'heart': '❤️',
                                        'laugh': '😂',
                                        'surprise': '😮',
                                        'sad': '😢',
                                      }[reaction.key]!,
                                      style: const TextStyle(
                                        fontFamily: NotoEmoji.fontFamily,
                                        fontSize: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(reaction.value),
                                  ],
                                ),
                              ),
                            if (isMine)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Редактировать'),
                              ),
                            if (isMine)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Удалить'),
                              ),
                          ],
                        ),
                      ],
                      if (replyCount > 0)
                        TextButton.icon(
                          onPressed: onToggleReplies,
                          icon: CommentIcon(
                            collapsed ? 'down' : 'up',
                            size: 16,
                          ),
                          label: Text(
                            '${collapsed ? 'Показать' : 'Скрыть'} ответы ($replyCount)',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CommentBranchPainter extends CustomPainter {
  const CommentBranchPainter({
    required this.depth,
    required this.hasReplies,
    required this.continueParent,
    required this.color,
  });
  final int depth;
  final bool hasReplies, continueParent;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final visible = depth.clamp(0, 3), left = 16 + visible * 24.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (depth > 0) {
      final x = depth > 3
          ? left - 10
          : 16 + (visible - 1) * 24.0 + (depth == 1 ? 18 : 15);
      canvas.drawPath(
        Path()
          ..moveTo(x, 0)
          ..lineTo(x, 21)
          ..quadraticBezierTo(x, 27, left - 3, 27),
        paint,
      );
      if (continueParent) {
        canvas.drawLine(Offset(x, 21), Offset(x, size.height), paint);
      }
    }
    if (hasReplies) {
      final x = depth >= 3 ? left - 10 : left + (depth == 0 ? 18 : 15);
      canvas.drawLine(
        Offset(
          x,
          depth >= 3
              ? 40
              : depth == 0
              ? 48
              : 42,
        ),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CommentBranchPainter old) =>
      old.depth != depth ||
      old.hasReplies != hasReplies ||
      old.continueParent != continueParent ||
      old.color != color;
}
