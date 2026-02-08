import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/disappearing_message.dart';
import '../../ui/nios_ui.dart';

class DisappearingTimer extends StatefulWidget {
  final DisappearingMessage message;
  final VoidCallback? onExpired;

  const DisappearingTimer({
    super.key,
    required this.message,
    this.onExpired,
  });

  @override
  State<DisappearingTimer> createState() => _DisappearingTimerState();
}

class _DisappearingTimerState extends State<DisappearingTimer> {
  Timer? _timer;
  Duration? _remaining;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant DisappearingTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.expiresAt != widget.message.expiresAt) {
      _updateRemaining();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    setState(() {
      _remaining = widget.message.remainingTime;
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
      if (_remaining == null || _remaining!.inSeconds <= 0) {
        _timer?.cancel();
        widget.onExpired?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == null || _remaining!.inSeconds <= 0) {
      return const SizedBox.shrink();
    }

    final progress = widget.message.disappearanceProgress;
    final color = _getTimerColor(progress);

    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              value: 1 - progress,
              strokeWidth: 2,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _formatDuration(_remaining!),
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) return '${duration.inDays}д';
    if (duration.inHours > 0) return '${duration.inHours}ч';
    if (duration.inMinutes > 0) return '${duration.inMinutes}м';
    return '${duration.inSeconds}с';
  }

  Color _getTimerColor(double progress) {
    if (progress < 0.3) return Colors.green;
    if (progress < 0.6) return Colors.orange;
    if (progress < 0.8) return Colors.deepOrange;
    return Colors.red;
  }
}

// Индикатор для списка чатов (показывает что в чате есть исчезающие сообщения)
class DisappearingIndicator extends StatelessWidget {
  final bool isActive;

  const DisappearingIndicator({
    super.key,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: NiosPalette.accent.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.timer_outlined,
        size: 12,
        color: NiosPalette.accent,
      ),
    );
  }
}

// Кнопка выбора времени исчезновения
class DisappearingDurationSelector extends StatelessWidget {
  final DisappearingDuration currentDuration;
  final Function(DisappearingDuration) onDurationSelected;

  const DisappearingDurationSelector({
    super.key,
    required this.currentDuration,
    required this.onDurationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NiosPalette.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Время жизни сообщений',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: NiosPalette.text,
            ),
          ),
          const SizedBox(height: 16),
          ...DisappearingDuration.values.map((duration) {
            final isSelected = duration == currentDuration;
            return ListTile(
              onTap: () {
                onDurationSelected(duration);
                Navigator.pop(context);
              },
              leading: Icon(
                duration.isEnabled ? Icons.timer : Icons.timer_off,
                color: isSelected ? NiosPalette.accent : NiosPalette.textSecondary,
              ),
              title: Text(
                duration.label,
                style: TextStyle(
                  color: isSelected ? NiosPalette.text : NiosPalette.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check, color: NiosPalette.accent)
                  : null,
            );
          }),
        ],
      ),
    );
  }
}
