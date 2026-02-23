import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_lock_provider.dart';

class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key, this.onUnlocked});

  final VoidCallback? onUnlocked;

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  final _pinController = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      setState(() => _error = 'Введите 4 цифры');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await ref.read(appLockProvider.notifier).unlock(pin);
    if (mounted) {
      setState(() => _loading = false);
    }
    if (ok) {
      widget.onUnlocked?.call();
    } else {
      setState(() => _error = 'Неверный PIN');
    }
  }

  Future<void> _unlockWithBiometrics() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await ref.read(appLockProvider.notifier).unlockWithBiometrics();
    if (mounted) {
      setState(() => _loading = false);
    }
    if (ok) {
      widget.onUnlocked?.call();
    } else {
      setState(() => _error = 'Биометрия недоступна');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lock = ref.watch(appLockProvider);
    final pinLength = _pinController.text.length.clamp(0, 4);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 56, color: scheme.primary),
              const SizedBox(height: 16),
              Text('Введите PIN', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < pinLength;
                  return Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? scheme.primary : scheme.surfaceContainerHighest,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(counterText: ''),
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _unlock(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loading ? null : _unlock,
                child: Text(_loading ? 'Проверка...' : 'Разблокировать'),
              ),
              if (lock.biometricAvailable && lock.biometricEnabled) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _loading ? null : _unlockWithBiometrics,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Войти по биометрии'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
