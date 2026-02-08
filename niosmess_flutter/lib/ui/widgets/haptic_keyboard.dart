import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// HapticKeyboard - клавиатура с тактильной обратной связью
/// Фича #2: Haptic Keyboard
/// 
/// Предоставляет вибрацию при нажатии клавиш с разной интенсивностью
class HapticKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool autofocus;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final Widget? prefix;
  final Widget? suffix;
  final EdgeInsets contentPadding;

  const HapticKeyboard({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.autofocus = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.enabled = true,
    this.prefix,
    this.suffix,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  @override
  State<HapticKeyboard> createState() => _HapticKeyboardState();
}

class _HapticKeyboardState extends State<HapticKeyboard> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  /// Генерирует легкую вибрацию при вводе текста
  void _onTextChanged(String value) {
    // Легкая вибрация при каждом символе
    HapticFeedback.lightImpact();
    widget.onChanged?.call(value);
  }

  /// Вибрация при отправке
  void _onSubmitted(String value) {
    HapticFeedback.mediumImpact();
    widget.onSubmitted?.call(value);
  }

  /// Вибрация при фокусе
  void _onTap() {
    HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(_isFocused ? 16 : 24),
        border: Border.all(
          color: _isFocused
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withValues(alpha: 0.2),
          width: _isFocused ? 2 : 1,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: _onTextChanged,
        onSubmitted: _onSubmitted,
        onTap: _onTap,
        autofocus: widget.autofocus,
        readOnly: widget.readOnly,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        maxLength: widget.maxLength,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        inputFormatters: widget.inputFormatters,
        enabled: widget.enabled,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 16,
          ),
          prefixIcon: widget.prefix,
          suffixIcon: widget.suffix,
          contentPadding: widget.contentPadding,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
      ),
    );
  }
}

/// HapticButton - кнопка с тактильной обратной связью
class HapticButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final HapticFeedbackType feedbackType;
  final EdgeInsets padding;

  const HapticButton({
    super.key,
    required this.child,
    this.onPressed,
    this.feedbackType = HapticFeedbackType.lightImpact,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _performHaptic(feedbackType);
        onPressed?.call();
      },
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }

  void _performHaptic(HapticFeedbackType type) {
    switch (type) {
      case HapticFeedbackType.lightImpact:
        HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.mediumImpact:
        HapticFeedback.mediumImpact();
        break;
      case HapticFeedbackType.heavyImpact:
        HapticFeedback.heavyImpact();
        break;
      case HapticFeedbackType.selectionClick:
        HapticFeedback.selectionClick();
        break;
      case HapticFeedbackType.vibrate:
        HapticFeedback.vibrate();
        break;
    }
  }
}

enum HapticFeedbackType {
  lightImpact,
  mediumImpact,
  heavyImpact,
  selectionClick,
  vibrate,
}

/// HapticIconButton - иконка-кнопка с вибрацией
class HapticIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final HapticFeedbackType feedbackType;

  const HapticIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 24,
    this.color,
    this.feedbackType = HapticFeedbackType.lightImpact,
  });

  @override
  Widget build(BuildContext context) {
    return HapticButton(
      feedbackType: feedbackType,
      onPressed: onPressed,
      padding: const EdgeInsets.all(8),
      child: Icon(
        icon,
        size: size,
        color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
