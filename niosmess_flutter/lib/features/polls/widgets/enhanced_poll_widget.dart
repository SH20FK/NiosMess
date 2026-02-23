import 'package:flutter/material.dart';
import '../models/poll.dart';

/// Улучшенный виджет опроса
class EnhancedPollWidget extends StatefulWidget {
  final Poll poll;
  final String currentUserId;
  final Function(List<String> optionIds) onVote;
  final VoidCallback? onViewResults;

  const EnhancedPollWidget({
    super.key,
    required this.poll,
    required this.currentUserId,
    required this.onVote,
    this.onViewResults,
  });

  @override
  State<EnhancedPollWidget> createState() => _EnhancedPollWidgetState();
}

class _EnhancedPollWidgetState extends State<EnhancedPollWidget>
    with SingleTickerProviderStateMixin {
  final Set<String> _selectedOptions = {};
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  bool get _hasVoted => widget.poll.hasUserVoted(widget.currentUserId);
  bool get _canVote => !_hasVoted && !widget.poll.isClosed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок опроса
            _buildHeader(theme),
            const SizedBox(height: 12),

            // Вопрос
            Text(
              widget.poll.question,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Варианты ответов
            ..._buildOptions(theme),

            const SizedBox(height: 12),

            // Нижняя панель
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Icon(
          _getPollIcon(),
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          _getPollTypeName(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (widget.poll.isAnonymous)
          Chip(
            label: const Text('Анонимный'),
            avatar: const Icon(Icons.visibility_off, size: 16),
            visualDensity: VisualDensity.compact,
          ),
        if (widget.poll.closesAt != null) ...[
          const SizedBox(width: 8),
          _buildTimer(theme),
        ],
      ],
    );
  }

  IconData _getPollIcon() {
    switch (widget.poll.type) {
      case PollType.quiz:
        return Icons.quiz;
      case PollType.anonymous:
        return Icons.visibility_off;
      default:
        return Icons.poll;
    }
  }

  String _getPollTypeName() {
    switch (widget.poll.type) {
      case PollType.quiz:
        return 'Квиз';
      case PollType.anonymous:
        return 'Анонимный опрос';
      default:
        return 'Опрос';
    }
  }

  Widget _buildTimer(ThemeData theme) {
    final remaining = widget.poll.timeRemaining;
    if (remaining == null || remaining == Duration.zero) {
      return Chip(
        label: const Text('Закрыт'),
        avatar: const Icon(Icons.lock, size: 16),
        visualDensity: VisualDensity.compact,
        backgroundColor: theme.colorScheme.errorContainer,
      );
    }

    return Chip(
      label: Text(_formatDuration(remaining)),
      avatar: const Icon(Icons.timer, size: 16),
      visualDensity: VisualDensity.compact,
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} дн';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} ч';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} мин';
    } else {
      return '${duration.inSeconds} сек';
    }
  }

  List<Widget> _buildOptions(ThemeData theme) {
    return widget.poll.options.map((option) {
      final isSelected = _selectedOptions.contains(option.id);
      final percentage = option.getPercentage(widget.poll.totalVotes);

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _hasVoted
            ? _buildResultOption(option, percentage, theme)
            : _buildVoteOption(option, isSelected, theme),
      );
    }).toList();
  }

  Widget _buildVoteOption(
    PollOption option,
    bool isSelected,
    ThemeData theme,
  ) {
    return InkWell(
      onTap: _canVote
          ? () {
              setState(() {
                if (widget.poll.allowMultipleAnswers) {
                  if (isSelected) {
                    _selectedOptions.remove(option.id);
                  } else {
                    if (widget.poll.maxChoices != null &&
                        _selectedOptions.length >= widget.poll.maxChoices!) {
                      // Достигнут лимит выборов
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Максимум ${widget.poll.maxChoices} вариантов',
                          ),
                        ),
                      );
                      return;
                    }
                    _selectedOptions.add(option.id);
                  }
                } else {
                  _selectedOptions.clear();
                  _selectedOptions.add(option.id);
                }
              });
            }
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? theme.colorScheme.primaryContainer.withOpacity(0.3)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              widget.poll.allowMultipleAnswers
                  ? (isSelected ? Icons.check_box : Icons.check_box_outline_blank)
                  : (isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              color: isSelected ? theme.colorScheme.primary : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.text,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultOption(
    PollOption option,
    double percentage,
    ThemeData theme,
  ) {
    final isCorrect = option.isCorrect == true;
    final isWrong = widget.poll.type == PollType.quiz &&
        option.isCorrect == false &&
        _selectedOptions.contains(option.id);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect
              ? Colors.green
              : isWrong
                  ? Colors.red
                  : theme.colorScheme.outline,
        ),
        color: isCorrect
            ? Colors.green.withOpacity(0.1)
            : isWrong
                ? Colors.red.withOpacity(0.1)
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isCorrect)
                const Icon(Icons.check_circle, color: Colors.green, size: 20)
              else if (isWrong)
                const Icon(Icons.cancel, color: Colors.red, size: 20),
              if (isCorrect || isWrong) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  option.text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isCorrect ? FontWeight.bold : null,
                  ),
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Прогресс бар
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0.0, end: percentage / 100),
            builder: (context, value, child) {
              return LinearProgressIndicator(
                value: value,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  isCorrect
                      ? Colors.green
                      : isWrong
                          ? Colors.red
                          : theme.colorScheme.primary,
                ),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              );
            },
          ),
          if (!widget.poll.isAnonymous && option.voters.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${option.votes} ${_pluralize(option.votes, "голос", "голоса", "голосов")}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Row(
      children: [
        Text(
          '${widget.poll.totalVotes} ${_pluralize(widget.poll.totalVotes, "голос", "голоса", "голосов")}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        if (_canVote && _selectedOptions.isNotEmpty)
          FilledButton(
            onPressed: () {
              widget.onVote(_selectedOptions.toList());
              setState(() {});
            },
            child: const Text('Проголосовать'),
          ),
        if (_hasVoted && widget.onViewResults != null)
          TextButton(
            onPressed: widget.onViewResults,
            child: const Text('Детали'),
          ),
      ],
    );
  }

  String _pluralize(int count, String one, String few, String many) {
    if (count % 10 == 1 && count % 100 != 11) return one;
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
      return few;
    }
    return many;
  }
}
