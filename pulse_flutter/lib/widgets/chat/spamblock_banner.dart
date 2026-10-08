import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SpamBlockBanner extends StatefulWidget {
  const SpamBlockBanner({
    super.key,
    this.until,
    this.reason,
    this.onContactSupport,
  });

  final DateTime? until;
  final String? reason;
  final VoidCallback? onContactSupport;

  @override
  State<SpamBlockBanner> createState() => _SpamBlockBannerState();
}

class _SpamBlockBannerState extends State<SpamBlockBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.until != null) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatRemaining() {
    if (widget.until == null) return 'Бессрочно';
    final Duration diff = widget.until!.difference(DateTime.now());
    if (diff.isNegative) return 'Срок истёк';
    if (diff.inDays > 0) {
      return '${diff.inDays} дн. ${diff.inHours % 24} ч.';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} ч. ${diff.inMinutes % 60} мин.';
    } else {
      return '${diff.inMinutes} мин.';
    }
  }

  String _formatUntilLocal() {
    if (widget.until == null) return 'Бессрочно';
    final DateTime local = widget.until!.toLocal();
    final DateFormat formatter = DateFormat('dd.MM.yyyy HH:mm');
    return formatter.format(local);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String reasonText = (widget.reason != null && widget.reason!.trim().isNotEmpty)
        ? widget.reason!.trim()
        : 'Нарушение правил сообщества';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.error.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.error.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.error,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_clock_rounded,
                  color: scheme.onError,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Аккаунт временно ограничен (Спамблок)',
                      style: textTheme.titleSmall?.copyWith(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Причина: $reasonText',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer.withValues(alpha: 0.9),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Истекает: ${_formatUntilLocal()}',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Осталось: ${_formatRemaining()}',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.block_rounded,
                    size: 14,
                    color: scheme.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Отправка сообщений заблокирована',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (widget.onContactSupport != null)
                TextButton(
                  onPressed: widget.onContactSupport,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Поддержка',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
