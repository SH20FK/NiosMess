import 'package:flutter/material.dart';

class M3Badge extends StatelessWidget {
  const M3Badge({
    required this.count,
    this.backgroundColor,
    this.textColor,
    super.key,
  });

  final int count;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor ?? scheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: textColor ?? scheme.onPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
