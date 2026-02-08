import 'package:flutter/material.dart';
import '../../ui/nios_ui.dart';

class FrozenScreen extends StatelessWidget {
  const FrozenScreen({super.key, required this.reason, required this.onBack});

  final String reason;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return NiosScaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🥶🦊', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text('Аккаунт заморожен', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: NiosPalette.text)),
              const SizedBox(height: 8),
              Text(reason, textAlign: TextAlign.center, style: TextStyle(color: NiosPalette.textSecondary)),
              const SizedBox(height: 20),
              NiosPrimaryButton(label: 'Назад', onTap: onBack),
            ],
          ),
        ),
      ),
    );
  }
}
