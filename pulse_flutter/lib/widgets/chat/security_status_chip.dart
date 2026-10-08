import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';

/// Single source of truth security status chip displayed in [ChatDetailAppBar].
/// Replaces multiple redundant locks and action buttons with one expressive,
/// compact status chip reflecting the Double Ratchet E2EE state.
class SecurityStatusChip extends ConsumerWidget {
  const SecurityStatusChip({
    required this.chatId,
    required this.onTap,
    super.key,
  });

  final int chatId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final E2eeService e2ee = ref.watch(e2eeServiceProvider);

    return ValueListenableBuilder<int>(
      valueListenable: e2ee.revision,
      builder: (BuildContext context, int _, Widget? child) {
        final E2eeSessionStatus status = e2ee.getSessionStatus(chatId);
        final bool isVerified = e2ee.isPeerVerified(chatId);

        Color bg;
        Color fg;
        IconData icon;
        String label;

        switch (status) {
          case E2eeSessionStatus.compromised:
            bg = scheme.errorContainer.withValues(alpha: 0.7);
            fg = scheme.error;
            icon = Icons.warning_amber_rounded;
            label = 'Угроза';
            break;
          case E2eeSessionStatus.connecting:
            bg = scheme.surfaceContainerHighest.withValues(alpha: 0.8);
            fg = scheme.primary;
            icon = Icons.sync_lock_rounded;
            label = 'Защита...';
            break;
          case E2eeSessionStatus.secured:
            if (isVerified) {
              bg = scheme.tertiaryContainer.withValues(alpha: 0.65);
              fg = scheme.onTertiaryContainer;
              icon = Icons.verified_user_rounded;
              label = 'E2EE';
            } else {
              bg = scheme.primaryContainer.withValues(alpha: 0.6);
              fg = scheme.onPrimaryContainer;
              icon = Icons.lock_rounded;
              label = 'E2EE';
            }
            break;
          case E2eeSessionStatus.none:
            bg = scheme.surfaceContainerHighest.withValues(alpha: 0.6);
            fg = scheme.onSurfaceVariant.withValues(alpha: 0.75);
            icon = Icons.lock_outline_rounded;
            label = 'E2EE';
            break;
        }

        return Tooltip(
          message: context.l10n.chatE2eeBanner,
          child: TouchContainer(
            onTap: () {
              HapticService.tap();
              onTap();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: fg.withValues(alpha: 0.25),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 14, color: fg),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
