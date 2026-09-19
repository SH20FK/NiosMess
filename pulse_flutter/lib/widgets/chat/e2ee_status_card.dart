import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';

/// Material 3 Expressive security banner for secret chats.
/// Automatically collapses when session is [secured], and only displays
/// persistent alert banners for [connecting] or [compromised] states.
class E2eeStatusCard extends ConsumerWidget {
  const E2eeStatusCard({
    required this.chatId,
    required this.onTap,
    super.key,
  });

  final int chatId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final e2ee = ref.watch(e2eeServiceProvider);

    return ValueListenableBuilder<int>(
      valueListenable: e2ee.revision,
      builder: (BuildContext context, int _, Widget? child) {
        final E2eeSessionStatus status = e2ee.getSessionStatus(chatId);

        // Auto-collapse for secured or default states — status is handled by SecurityStatusChip in header
        if (status == E2eeSessionStatus.secured || status == E2eeSessionStatus.none) {
          return const SizedBox.shrink();
        }

        final bool isCompromised = status == E2eeSessionStatus.compromised;
        final Color bg = isCompromised
            ? scheme.errorContainer.withValues(alpha: 0.35)
            : scheme.surfaceContainerHigh.withValues(alpha: 0.75);
        final Color fg = isCompromised ? scheme.error : scheme.primary;
        final Color border = isCompromised
            ? scheme.error.withValues(alpha: 0.4)
            : scheme.outlineVariant.withValues(alpha: 0.25);
        final IconData icon = isCompromised
            ? Icons.warning_amber_rounded
            : Icons.sync_lock_rounded;
        final String title = isCompromised
            ? 'Угроза безопасности'
            : context.l10n.chatConnecting;
        final String subtitle = isCompromised
            ? 'Ключ устройства собеседника изменился'
            : context.l10n.chatReconnecting;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: TouchContainer(
            borderRadius: BorderRadius.circular(14),
            color: bg,
            onTap: () {
              HapticService.tap();
              onTap();
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: <Widget>[
                  Icon(icon, color: fg, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          style: textTheme.titleSmall?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: fg.withValues(alpha: 0.6),
                    size: 18,
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
