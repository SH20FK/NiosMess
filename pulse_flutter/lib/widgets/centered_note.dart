import 'package:flutter/material.dart';

class CenteredNote extends StatelessWidget {
  const CenteredNote(this.text, {this.icon, super.key});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 48, color: scheme.onSurfaceVariant),
              const SizedBox(height: 12),
            ],
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
