import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';

/// Material 3 Expressive Resend Countdown Timer.
///
/// Displays a smooth animated circular progress ring with countdown text.
/// When the countdown expires, triggers medium impact haptics and switches to
/// an active "Resend code" action button.
class M3ResendCountdownTimer extends StatefulWidget {
  const M3ResendCountdownTimer({
    required this.onResend,
    super.key,
    this.durationSeconds = 60,
    this.autoStart = true,
    this.onExpired,
  });

  final Future<void> Function() onResend;
  final int durationSeconds;
  final bool autoStart;
  final VoidCallback? onExpired;

  @override
  State<M3ResendCountdownTimer> createState() => _M3ResendCountdownTimerState();
}

class _M3ResendCountdownTimerState extends State<M3ResendCountdownTimer> {
  late int _remainingSeconds;
  Timer? _timer;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.durationSeconds;
    if (widget.autoStart && widget.durationSeconds > 0) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
        });
        HapticService.confirm();
        widget.onExpired?.call();
      }
    });
  }

  Future<void> _handleResend() async {
    if (_isResending) return;
    HapticService.tap();
    setState(() {
      _isResending = true;
    });

    try {
      await widget.onResend();
      if (!mounted) return;
      AppToast.showSuccess(context, context.l10n.authCodeSent);
      setState(() {
        _remainingSeconds = widget.durationSeconds;
        _isResending = false;
      });
      _startTimer();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    if (_remainingSeconds > 0) {
      final double progress = widget.durationSeconds > 0
          ? _remainingSeconds / widget.durationSeconds
          : 0.0;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2.5,
                strokeCap: StrokeCap.round,
                color: scheme.primary,
                backgroundColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              context.l10n.authResendCountdown(_remainingSeconds),
              style: textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: _isResending ? null : _handleResend,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isResending)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.onPrimaryContainer,
                  ),
                )
              else
                Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
              const SizedBox(width: 8),
              Text(
                context.l10n.authResendCode,
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
