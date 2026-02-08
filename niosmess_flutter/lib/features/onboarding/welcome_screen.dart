import 'package:flutter/material.dart';
import '../../ui/nios_ui.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onLogin, required this.onRegister});

  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return NiosScaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🦊', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 12),
              Text('NiosMess', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: NiosPalette.text)),
              const SizedBox(height: 8),
              Text('Премиальный мессенджер с продуманной приватностью', style: TextStyle(color: NiosPalette.textSecondary)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NiosPrimaryButton(label: 'Войти', onTap: onLogin),
                  const SizedBox(width: 12),
                  NiosGhostButton(label: 'Создать аккаунт', onTap: onRegister),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
