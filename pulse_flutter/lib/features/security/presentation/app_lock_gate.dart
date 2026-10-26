import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/system_utils.dart';
import 'package:pulse_flutter/features/security/application/app_lock_controller.dart';
import 'package:pulse_flutter/features/security/domain/app_lock_policy.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  bool _attemptedAutoAuth = false;

  @override
  Widget build(BuildContext context) {
    final bool isAuthenticated = ref.watch(authProvider).isAuthenticated;
    final AppLockState lockState = ref.watch(appLockProvider);

    if (isAuthenticated &&
        (lockState.isInitializing || lockState.hasInitializationError)) {
      _attemptedAutoAuth = false;
      return Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: true,
            child: ExcludeSemantics(child: ExcludeFocus(child: widget.child)),
          ),
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: lockState.isInitializing
                        ? const AppLoadingIndicator()
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.l10n.auditAppLockCheckFailed,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: () => ref
                                    .read(appLockProvider.notifier)
                                    .retryInit(),
                                icon: const Icon(Icons.refresh_rounded),
                                label: Text(context.l10n.commonRetry),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // If not authenticated or not locked, render normal tree
    final bool isActuallyLocked =
        isAuthenticated && lockState.isEnabled && lockState.isLocked;

    if (!isActuallyLocked) {
      _attemptedAutoAuth = false;
      return widget.child;
    }

    // Auto-prompt on transition to locked state
    if (!_attemptedAutoAuth && !lockState.isAuthenticating) {
      _attemptedAutoAuth = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(appLockProvider.notifier)
              .authenticateAndUnlock(
                reason: context.l10n.auditAppLockDescription,
              );
        }
      });
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Obscured underlying child excluded from semantics
        Offstage(
          offstage: true,
          child: ExcludeSemantics(
            excluding: true,
            child: ExcludeFocus(child: widget.child),
          ),
        ),

        // Opaque blocking screen covering the entire viewport
        Positioned.fill(
          child: Material(
            color: scheme.surface,
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 48).clamp(
                        0,
                        double.infinity,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
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
                          context.l10n.auditAppLockTitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.l10n.auditAppLockDescription,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              elevation: 0,
                              minimumSize: const Size(0, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: lockState.isAuthenticating
                                ? null
                                : () => ref
                                      .read(appLockProvider.notifier)
                                      .authenticateAndUnlock(
                                        reason: context
                                            .l10n
                                            .auditAppLockDescription,
                                      ),
                            icon: const Icon(
                              Icons.fingerprint_rounded,
                              size: 22,
                            ),
                            label: Text(
                              lockState.isAuthenticating
                                  ? context.l10n.auditAppLockAuthenticating
                                  : context.l10n.auditAppLockUnlock,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => SystemUtils.minimizeApp(),
                            icon: const Icon(Icons.close_rounded, size: 20),
                            label: Text(context.l10n.auditAppLockMinimize),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
