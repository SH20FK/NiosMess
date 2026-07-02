import 'package:flutter/material.dart';

class CodePreview extends StatelessWidget {
  const CodePreview({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Row(
      children: List<Widget>.generate(6, (int index) {
        final bool filled = index < code.length;
        final bool isCurrent = index == code.length;

        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.only(right: index == 5 ? 0 : 10),
            height: 64,
            decoration: BoxDecoration(
              color: filled
                  ? scheme.primaryContainer.withValues(alpha: 0.9)
                  : (isCurrent ? scheme.surface : scheme.surfaceContainerLow),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                width: isCurrent ? 2 : 1,
                color: filled
                    ? scheme.primary.withValues(alpha: 0.4)
                    : (isCurrent
                        ? scheme.primary
                        : scheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              boxShadow: isCurrent ? [
                BoxShadow(color: scheme.primary.withValues(alpha: 0.1), blurRadius: 8, spreadRadius: 1)
              ] : null,
            ),
            alignment: Alignment.center,
            child: Text(
              filled ? code[index] : (isCurrent ? '' : '•'),
              style: textTheme.headlineMedium?.copyWith(
                color: filled
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant.withValues(alpha: 0.4),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      }),
    );
  }
}
