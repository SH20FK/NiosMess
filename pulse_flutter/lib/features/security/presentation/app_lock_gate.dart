import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/system_utils.dart';
import 'package:pulse_flutter/features/security/application/app_lock_controller.dart';
import 'package:pulse_flutter/features/security/domain/app_lock_policy.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';

class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockGate({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  bool _attemptedAutoAuth = false;

  @override
  Widget build(BuildContext context) {
    final bool isAuthenticated = ref.watch(authProvider).isAuthenticated;
    final AppLockState lockState = ref.watch(appLockProvider);

    // If not authenticated or not locked, render normal tree
    final bool isActuallyLocked = isAuthenticated && lockState.isEnabled && lockState.isLocked;

    if (!isActuallyLocked) {
      _attemptedAutoAuth = false;
      return widget.child;
    }

    // Auto-prompt on transition to locked state
    if (!_attemptedAutoAuth && !lockState.isAuthenticating) {
      _attemptedAutoAuth = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(appLockProvider.notifier).authenticateAndUnlock();
        }
      });
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Obscured underlying child excluded from semantics
        ExcludeSemantics(
          excluding: true,
          child: FocusScope(
            canRequestFocus: false,
            child: widget.child,
          ),
        ),

        // Opaque blocking screen covering the entire viewport
        Positioned.fill(
          child: Material(
            color: scheme.surface,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Spacer(),
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(28.0),
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 44,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'NiosMess заблокирован',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Подтвердите личность для доступа к сообщениям и данным',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: lockState.isAuthenticating
                            ? null
                            : () => ref
                                .read(appLockProvider.notifier)
                                .authenticateAndUnlock(),
                        icon: const Icon(Icons.fingerprint_rounded, size: 22),
                        label: Text(
                          lockState.isAuthenticating
                              ? 'Проверка...'
                              : 'Разблокировать',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => SystemUtils.minimizeApp(),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        label: const Text('Свернуть'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
