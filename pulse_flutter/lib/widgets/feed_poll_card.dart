import 'dart:async';
import 'package:pulse_flutter/widgets/chat/custom_emoji_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/feed_poll_vote_provider.dart';
import 'package:pulse_flutter/widgets/chat/bubble/bubble_text_renderer.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

class FeedPollCard extends ConsumerStatefulWidget {
  const FeedPollCard({
    required this.postId,
    required this.poll,
    this.preview = false,
    this.showTitle = true,
    super.key,
  });
  final int postId;
  final Map<String, dynamic> poll;
  final bool preview;
  final bool showTitle;
  @override
  ConsumerState<FeedPollCard> createState() => _FeedPollCardState();
}

class _FeedPollCardState extends ConsumerState<FeedPollCard> {
  Timer? _deadlineTimer;

  @override
  void initState() {
    super.initState();
    _scheduleDeadline();
  }

  void _scheduleDeadline() {
    _deadlineTimer?.cancel();
    final value = widget.poll['closes_at'];
    if (value is! int) return;
    final remaining = DateTime.fromMillisecondsSinceEpoch(
      value,
      isUtc: true,
    ).difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) return;
    _deadlineTimer = Timer(
      remaining > const Duration(days: 30)
          ? const Duration(days: 30)
          : remaining,
      () {
        if (!mounted) return;
        setState(() {});
        _scheduleDeadline();
      },
    );
  }

  @override
  void dispose() {
    _deadlineTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(FeedPollCard old) {
    super.didUpdateWidget(old);
    if (old.postId != widget.postId || old.poll != widget.poll) {
      _scheduleDeadline();
    }
  }

  Future<void> _vote(Set<int> choices) => ref
      .read(feedPollVotesProvider.notifier)
      .vote(widget.postId, widget.poll, choices);

  @override
  Widget build(BuildContext context) {
    final vote = widget.preview
        ? null
        : ref.watch(
            feedPollVotesProvider.select((votes) => votes[widget.postId]),
          );
    final poll = vote?.poll ?? widget.poll;
    final selected = vote?.choices;
    final busy = vote?.pending ?? false;
    final failed = vote?.failed ?? false;
    final scheme = Theme.of(context).colorScheme, theme = Theme.of(context);
    final items = (poll['items'] as List? ?? []).cast<String>();
    final mine = (poll['my_choices'] as List? ?? []).whereType<int>().toSet();
    final highlighted = selected ?? mine;
    final quiz = poll['kind'] == 'quiz', multiple = poll['multiple'] == true;
    final voted = mine.isNotEmpty, correct = poll['correct'] as int?;
    final deadline = poll['closes_at'];
    final closed =
        poll['closed'] == true ||
        (deadline is int &&
            DateTime.now().toUtc().millisecondsSinceEpoch >= deadline);
    final showResults = voted || closed;
    final total = (poll['total_voters'] as num?)?.toInt() ?? 0;
    final counts = (poll['counts'] as List? ?? [])
        .whereType<num>()
        .map((n) => n.toInt())
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showTitle) ...[
          CustomEmojiText(
            poll['title'] as String? ?? '',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          closed
              ? context.l10n.interactivePollClosed
              : quiz
              ? context.l10n.niosgramAnonymousQuiz
              : context.l10n.niosgramAnonymousPoll,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < items.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              selected: highlighted.contains(index),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Material(
                  color: highlighted.contains(index)
                      ? scheme.secondaryContainer
                      : scheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: busy || widget.preview || closed || (quiz && voted)
                        ? null
                        : () {
                            if (multiple) {
                              final next = {...highlighted};
                              next.contains(index)
                                  ? next.remove(index)
                                  : next.add(index);
                              ref
                                  .read(feedPollVotesProvider.notifier)
                                  .select(widget.postId, poll, next);
                            } else {
                              _vote({index});
                            }
                          },
                    child: Stack(
                      children: [
                        if (showResults && total > 0)
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TweenAnimationBuilder<double>(
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : M3Durations.medium1,
                                curve: M3SpringCurves.expressiveDecel,
                                tween: Tween(
                                  begin: 0,
                                  end:
                                      ((index < counts.length
                                                  ? counts[index]
                                                  : 0) /
                                              total)
                                          .clamp(0, 1),
                                ),
                                builder: (context, value, child) =>
                                    FractionallySizedBox(
                                      widthFactor: value,
                                      child: child,
                                    ),
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
                                    highlighted.contains(index)
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
                              if (showResults)
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
            ),
          ),
        if (busy)
          Semantics(liveRegion: true, child: Text(context.l10n.noticeSending)),
        if (failed)
          Semantics(
            liveRegion: true,
            child: Text(context.l10n.niosgramVoteFailed),
          ),
        if (failed && !widget.preview)
          TextButton(
            onPressed: busy || closed || (selected ?? mine).isEmpty
                ? null
                : () => _vote(selected ?? mine),
            child: Text(context.l10n.commonRetry),
          ),
        if (multiple && !widget.preview && !failed)
          TextButton(
            onPressed: busy || closed || (selected ?? mine).isEmpty
                ? null
                : () => _vote(selected ?? mine),
            child: Text(context.l10n.interactiveVote),
          ),
        if (quiz && voted && (poll['explanation'] as String? ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CustomEmojiText(
              poll['explanation'] as String,
              style: theme.textTheme.bodySmall,
            ),
          ),
        Text(
          widget.preview
              ? context.l10n.niosgramAnonymousNotice
              : '${context.l10n.interactiveVoters}: $total',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
