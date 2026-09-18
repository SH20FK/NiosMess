import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// Material 3 Expressive security status card displayed at the top of secret chats.
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
        final bool isVerified = e2ee.isPeerVerified(chatId);

        Color bg;
        Color fg;
        Color border;
        IconData icon;
        String title;
        String subtitle;

        switch (status) {
          case E2eeSessionStatus.compromised:
            bg = scheme.errorContainer.withValues(alpha: 0.35);
            fg = scheme.error;
            border = scheme.error.withValues(alpha: 0.4);
            icon = Icons.warning_amber_rounded;
            title = 'Угроза безопасности';
            subtitle = 'Ключ устройства собеседника изменился';
            break;
          case E2eeSessionStatus.connecting:
            bg = scheme.surfaceContainerHigh.withValues(alpha: 0.7);
            fg = scheme.primary;
            border = scheme.outlineVariant.withValues(alpha: 0.25);
            icon = Icons.sync_lock_rounded;
            title = 'Установка соединения';
            subtitle = 'Выполняется Double Ratchet рукопожатие...';
            break;
          case E2eeSessionStatus.secured:
            if (isVerified) {
              bg = scheme.tertiaryContainer.withValues(alpha: 0.30);
              fg = scheme.tertiary;
              border = scheme.tertiary.withValues(alpha: 0.35);
              icon = Icons.verified_user_rounded;
              title = 'Ключи верифицированы';
              subtitle = 'Сквозное шифрование Double Ratchet v2';
            } else {
              bg = scheme.primaryContainer.withValues(alpha: 0.25);
              fg = scheme.primary;
              border = scheme.primary.withValues(alpha: 0.25);
              icon = Icons.lock_rounded;
              title = context.l10n.chatE2eeBanner;
              subtitle = 'Нажмите для сверки отпечатков ключей';
            }
            break;
          case E2eeSessionStatus.none:
            bg = scheme.surfaceContainerLow;
            fg = scheme.onSurfaceVariant;
            border = scheme.outlineVariant.withValues(alpha: 0.2);
            icon = Icons.lock_clock_rounded;
            title = 'Секретный чат';
            subtitle = 'Нажмите для проверки параметров защиты';
            break;
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: TouchContainer(
            borderRadius: BorderRadius.circular(16),
            color: bg,
            onTap: () {
              HapticService.tap();
              onTap();
            },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: status == E2eeSessionStatus.connecting
                    ? const AppLoadingIndicator(size: 20)
                    : Icon(icon, size: 20, color: fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
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
