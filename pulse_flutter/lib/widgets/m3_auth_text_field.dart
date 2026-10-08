import 'package:flutter/material.dart';

/// A Material 3 Expressive authentication input field with 20dp squircle styling,
/// tonal surfaceContainerHighest background, and dynamic state-reactive borders and icons.
class M3AuthTextField extends StatefulWidget {
  const M3AuthTextField({
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.suffixIcon,
    this.onFieldSubmitted,
    this.focusNode,
    this.autofillHints,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final Widget? suffixIcon;
  final ValueChanged<String>? onFieldSubmitted;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;
  final bool enabled;

  @override
  State<M3AuthTextField> createState() => _M3AuthTextFieldState();
}

class _M3AuthTextFieldState extends State<M3AuthTextField> {
  late FocusNode _focusNode;
  bool _isFocused = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_handleFocusChange);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return FormField<String>(
      initialValue: widget.controller.text,
      validator: (val) {
        final err = widget.validator?.call(widget.controller.text);
        if (_errorText != err) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _errorText = err);
            }
          });
        }
        return err;
      },
      builder: (fieldState) {
        final bool hasError = _errorText != null && _errorText!.isNotEmpty;

        final Color borderColor = hasError
            ? scheme.error
            : (_isFocused
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.25));

        final double borderWidth = _isFocused || hasError ? 1.6 : 1.0;

        final Color prefixIconColor = hasError
            ? scheme.error
            : (_isFocused
                ? scheme.primary
                : scheme.onSurfaceVariant);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: borderColor,
                  width: borderWidth,
                ),
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                onSubmitted: widget.onFieldSubmitted,
                autofillHints: widget.autofillHints,
                enabled: widget.enabled,
                onChanged: (val) {
                  fieldState.didChange(val);
                  if (_errorText != null) {
                    setState(() {
                      _errorText = widget.validator?.call(val);
                    });
                  }
                },
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  labelText: widget.label,
                  hintText: widget.hintText,
                  labelStyle: TextStyle(
                    color: hasError
                        ? scheme.error
                        : (_isFocused
                            ? scheme.primary
                            : scheme.onSurfaceVariant.withValues(alpha: 0.8)),
                    fontSize: 14,
                  ),
                  hintStyle: TextStyle(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    widget.prefixIcon,
                    size: 20,
                    color: prefixIconColor,
                  ),
                  suffixIcon: widget.suffixIcon,
                  filled: false,
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text(
                  _errorText!,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
