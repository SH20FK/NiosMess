import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/providers/custom_emoji_provider.dart';
import 'package:pulse_flutter/widgets/chat/bubble/bubble_text_renderer.dart';

class FeedPollCard extends ConsumerStatefulWidget {
  const FeedPollCard({
    required this.postId,
    required this.poll,
    this.preview = false,
    super.key,
  });
  final int postId;
  final Map<String, dynamic> poll;
  final bool preview;
  @override
  ConsumerState<FeedPollCard> createState() => _FeedPollCardState();
}

class _FeedPollCardState extends ConsumerState<FeedPollCard> {
  late Map<String, dynamic> _poll = widget.poll;
  final _selected = <int>{};
  bool _busy = false;
  @override
  void didUpdateWidget(FeedPollCard old) {
    super.didUpdateWidget(old);
    if (old.postId != widget.postId || old.poll != widget.poll) {
      _poll = widget.poll;
      _selected.clear();
    }
  }

  Future<void> _vote(List<int> choices) async {
    if (_busy || widget.preview) return;
    setState(() => _busy = true);
    try {
      final result = await ref.read(customEmojiRequestProvider)(
        'vote_feed_poll',
        {'post_id': widget.postId, 'choices': choices},
      );
      if (mounted) {
        setState(
          () => _poll = Map<String, dynamic>.from(result['poll'] as Map),
        );
      }
    } catch (error) {
      if (mounted) AppToast.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme, theme = Theme.of(context);
    final items = (_poll['items'] as List? ?? []).cast<String>();
    final mine = (_poll['my_choices'] as List? ?? []).whereType<int>().toSet();
    final quiz = _poll['kind'] == 'quiz', multiple = _poll['multiple'] == true;
    final voted = mine.isNotEmpty, correct = _poll['correct'] as int?;
    final total = (_poll['total_voters'] as num?)?.toInt() ?? 0;
    final counts = (_poll['counts'] as List? ?? [])
        .whereType<num>()
        .map((n) => n.toInt())
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _poll['title'] as String? ?? '',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          quiz ? 'Анонимная викторина' : 'Анонимный опрос',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < items.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: mine.contains(index)
                  ? scheme.secondaryContainer
                  : scheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _busy || widget.preview || (quiz && voted)
                    ? null
                    : () {
                        if (multiple) {
                          setState(
                            () => _selected.contains(index)
                                ? _selected.remove(index)
                                : _selected.add(index),
                          );
                        } else {
                          _vote([index]);
                        }
                      },
                child: Stack(
                  children: [
                    if (voted && total > 0)
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor:
                                ((index < counts.length ? counts[index] : 0) /
                                        total)
                                    .clamp(0, 1),
                            child: ColoredBox(
                              color: scheme.primary.withValues(alpha: .12),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          if (multiple)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                _selected.contains(index) ||
                                        mine.contains(index)
                                    ? Icons.check_box_outlined
                                    : Icons.check_box_outline_blank,
                                size: 20,
                              ),
                            ),
                          Expanded(
                            child: InteractiveMessageText(
                              text: items[index],
                              baseStyle: theme.textTheme.bodyMedium!,
                              isMine: false,
                              scheme: scheme,
                            ),
                          ),
                          if (quiz && voted && correct == index)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.check_rounded, size: 20),
                            ),
                          if (voted)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                '${total == 0 ? 0 : ((index < counts.length ? counts[index] : 0) * 100 / total).round()}%',
                                style: theme.textTheme.labelMedium,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (multiple && !widget.preview)
          TextButton(
            onPressed: _busy || _selected.isEmpty
                ? null
                : () => _vote(_selected.toList()),
            child: const Text('Проголосовать'),
          ),
        if (quiz && voted && (_poll['explanation'] as String? ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _poll['explanation'] as String,
              style: theme.textTheme.bodySmall,
            ),
          ),
        Text(
          widget.preview
              ? 'Имена участников не публикуются'
              : 'Голосов: $total',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
