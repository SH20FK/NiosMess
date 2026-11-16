import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

class OrdinaryE2eeNotice extends ConsumerWidget {
  const OrdinaryE2eeNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(ordinaryE2eeProvider);
    if (service == null) return const SizedBox.shrink();
    final l = context.l10n;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final bool visible = service.initialised && service.locked;
        return AnimatedSize(
          // The banner appears/disappears with key sync: grow, never pop.
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: M3SpringCurves.gentle,
          alignment: Alignment.topCenter,
          child: visible
              ? _NoticeSurface(
                  message: service.autoWaiting
                      ? l.inboxE2eeWaitingActiveDevice
                      : l.inboxE2eeWaitingKeys,
                  actionLabel: l.noticeOpen,
                  onOpen: () => context.push('/settings/e2ee'),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Passive key notice rendered as a low-tonal surface instead of a full-bleed
/// text line: it must read as chrome, not as a message in the inbox.
class _NoticeSurface extends StatelessWidget {
  const _NoticeSurface({
    required this.message,
    required this.actionLabel,
    required this.onOpen,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        decoration: ShapeDecoration(
          color: scheme.surfaceContainerLow,
          shape: AppRadii.lgSuperellipse(
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.18),
            ),
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: onOpen,
              style: TextButton.styleFrom(
                visualDensity: const VisualDensity(
                  horizontal: -2,
                  vertical: -2,
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                minimumSize: const Size(0, AppHeights.controlCompact),
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
