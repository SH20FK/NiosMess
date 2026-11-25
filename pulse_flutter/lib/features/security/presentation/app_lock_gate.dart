import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/system_utils.dart';
import 'package:pulse_flutter/features/security/application/app_lock_controller.dart';
import 'package:pulse_flutter/features/security/domain/app_lock_policy.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/motion/m3_entrance.dart';
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

    final bool isActuallyLocked =
        isAuthenticated && lockState.isEnabled && lockState.isLocked;

    if (!isActuallyLocked) {
      _attemptedAutoAuth = false;
    } else if (!_attemptedAutoAuth && !lockState.isAuthenticating) {
      // Auto-prompt on transition to locked state
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
        // The child keeps the same place in the tree while locked and
        // unlocked, so unlocking does not rebuild the app under the cover.
        Offstage(
          offstage: isActuallyLocked,
          child: ExcludeSemantics(
            excluding: isActuallyLocked,
            child: ExcludeFocus(
              excluding: isActuallyLocked,
              child: widget.child,
            ),
          ),
        ),

        // Opaque blocking screen covering the entire viewport
        _LockCover(
          locked: isActuallyLocked,
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
                      // Only the content animates in: the opaque surface
                      // behind it covers the app from the first frame.
                    ).entrance(scaleFrom: 0.94),
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

/// Lock screen layer. It appears without a transition, so the app is covered
/// from the first frame, and fades out after unlocking.
class _LockCover extends StatelessWidget {
  const _LockCover({required this.locked, required this.child});

  final bool locked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // A leaving lock screen must not start another unlock.
      ignoring: !locked,
      child: ExcludeSemantics(
        excluding: !locked,
        child: AnimatedSwitcher(
          duration: Duration.zero,
          reverseDuration: context.motionDuration(M3Durations.effectsDefault),
          switchOutCurve: M3SpringCurves.effectsDefault,
          layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
            fit: StackFit.expand,
            children: <Widget>[...previous, ?current],
          ),
          child: locked
              ? KeyedSubtree(
                  key: const ValueKey<String>('app-lock-cover'),
                  child: child,
                )
              : const SizedBox.shrink(key: ValueKey<String>('app-lock-open')),
        ),
      ),
    );
  }
}
