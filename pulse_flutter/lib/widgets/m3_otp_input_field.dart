import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';

/// Material 3 Expressive OTP Input Field.
///
/// Features 6 discrete squircle boxes with animated scale and glow on focus,
/// filled primary container tinting, error shake animation, and native
/// OS autofill / keyboard / clipboard integration.
class M3OtpInputField extends StatefulWidget {
  const M3OtpInputField({
    required this.controller,
    super.key,
    this.length = 6,
    this.focusNode,
    this.onChanged,
    this.onCompleted,
    this.hasError = false,
    this.autoFocus = true,
    this.enabled = true,
    this.boxSize = 48,
  });

  final TextEditingController controller;
  final int length;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool hasError;
  final bool autoFocus;
  final bool enabled;
  final double boxSize;

  @override
  State<M3OtpInputField> createState() => _M3OtpInputFieldState();
}

class _M3OtpInputFieldState extends State<M3OtpInputField>
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  String _lastCompletedCode = '';

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: 10, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: 8, end: -4), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: -4, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.easeInOutSine,
      ),
    );

    widget.controller.addListener(_onControllerChange);

    if (widget.hasError) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant M3OtpInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChange);
      widget.controller.addListener(_onControllerChange);
    }
    if (widget.hasError && !oldWidget.hasError) {
      HapticService.destructive();
      _shakeController.forward(from: 0);
    }
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  String _lastChangedText = '';

  void _onControllerChange() {
    final String text = _cleanText(widget.controller.text);
    if (text != _lastChangedText) {
      _lastChangedText = text;
      widget.onChanged?.call(text);
    }
    if (text.length == widget.length && text != _lastCompletedCode) {
      _lastCompletedCode = text;
      HapticService.tap();
      widget.onCompleted?.call(text);
    } else if (text.length < widget.length) {
      _lastCompletedCode = '';
    }
    if (mounted) {
      setState(() {});
    }
  }

  String _cleanText(String input) {
    return input.replaceAll(RegExp(r'\D'), '');
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    _shakeController.dispose();
    super.dispose();
  }

  void _onBoxTap() {
    if (!widget.enabled) return;
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String currentCode = _cleanText(widget.controller.text);
    final bool hasFocus = _focusNode.hasFocus;

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Visual Squircle Boxes
          GestureDetector(
            onTap: _onBoxTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.length, (index) {
                final bool isFilled = index < currentCode.length;
                final bool isCurrentFocus = hasFocus &&
                    (index == currentCode.length ||
                        (index == widget.length - 1 &&
                            currentCode.length == widget.length));
                final String digit = isFilled ? currentCode[index] : '';

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: _OtpBoxCell(
                    digit: digit,
                    isFilled: isFilled,
                    isFocused: isCurrentFocus,
                    hasError: widget.hasError,
                    size: widget.boxSize,
                    scheme: scheme,
                    textTheme: textTheme,
                  ),
                );
              }),
            ),
          ),

          // Hidden native text field for keyboard, autofill, and paste
          Opacity(
            opacity: 0.0,
            child: SizedBox(
              width: (widget.boxSize + 8) * widget.length,
              height: widget.boxSize,
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                autofocus: widget.autoFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                enableSuggestions: false,
                autocorrect: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                onChanged: (val) {
                  final clean = _cleanText(val);
                  widget.onChanged?.call(clean);
                },
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpBoxCell extends StatelessWidget {
  const _OtpBoxCell({
    required this.digit,
    required this.isFilled,
    required this.isFocused,
    required this.hasError,
    required this.size,
    required this.scheme,
    required this.textTheme,
  });

  final String digit;
  final bool isFilled;
  final bool isFocused;
  final bool hasError;
  final double size;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    // Determine 4 distinct visual states:
    // 1. Error state
    // 2. Focused state (active cell)
    // 3. Filled state
    // 4. Inactive Empty state

    final double scale = isFocused && !hasError ? 1.06 : 1.0;

    Color backgroundColor;
    Border border;
    List<BoxShadow> shadows = [];

    if (hasError) {
      backgroundColor = scheme.errorContainer.withValues(alpha: 0.25);
      border = Border.all(color: scheme.error, width: 2.0);
      shadows = [
        BoxShadow(
          color: scheme.error.withValues(alpha: 0.2),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ];
    } else if (isFocused) {
      backgroundColor = scheme.surfaceContainerHigh.withValues(alpha: 0.9);
      border = Border.all(color: scheme.primary, width: 2.0);
      shadows = [
        BoxShadow(
          color: scheme.primary.withValues(alpha: 0.3),
          blurRadius: 10,
          spreadRadius: 1,
        ),
      ];
    } else if (isFilled) {
      backgroundColor = scheme.primaryContainer;
      border = Border.all(
        color: scheme.primary.withValues(alpha: 0.5),
        width: 1.5,
      );
    } else {
      backgroundColor = scheme.surfaceContainerHigh.withValues(alpha: 0.45);
      border = Border.all(
        color: scheme.outlineVariant.withValues(alpha: 0.3),
        width: 1.0,
      );
    }

    final TextStyle? digitStyle = isFilled
        ? (textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: hasError ? scheme.error : scheme.onPrimaryContainer,
          ) ??
          TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: hasError ? scheme.error : scheme.onPrimaryContainer,
          ))
        : null;

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: size,
        height: size + 6,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: border,
          boxShadow: shadows,
        ),
        alignment: Alignment.center,
        child: isFilled
            ? Text(
                digit,
                style: digitStyle,
              )
            : (isFocused && !hasError
                ? _CursorPulse(color: scheme.primary)
                : Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  )),
      ),
    );
  }
}

class _CursorPulse extends StatelessWidget {
  const _CursorPulse({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
