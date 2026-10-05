import 'package:flutter/material.dart';

enum ChatEmptyStateVariant {
  empty,
  secret,
  offline,
  error,
}

/// Compact, elegant Material 3 empty and error state for chat viewports.
/// Replaces oversized AI cookie-shapes with a clean 58dp tonal container,
/// smooth subtle fade + scale (0.98 -> 1.0), and zero unnecessary nested cards.
class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({
    super.key,
    required this.variant,
    required this.title,
    required this.description,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  factory ChatEmptyState.empty({
    Key? key,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ChatEmptyState(
      key: key,
      variant: ChatEmptyStateVariant.empty,
      icon: Icons.chat_bubble_outline_rounded,
      title: title,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  factory ChatEmptyState.secret({
    Key? key,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ChatEmptyState(
      key: key,
      variant: ChatEmptyStateVariant.secret,
      icon: Icons.lock_rounded,
      title: title,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  factory ChatEmptyState.offline({
    Key? key,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ChatEmptyState(
      key: key,
      variant: ChatEmptyStateVariant.offline,
      icon: Icons.wifi_off_rounded,
      title: title,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  factory ChatEmptyState.error({
    Key? key,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ChatEmptyState(
      key: key,
      variant: ChatEmptyStateVariant.error,
      icon: Icons.sync_problem_rounded,
      title: title,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  final ChatEmptyStateVariant variant;
  final String title;
  final String description;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final Color containerColor = switch (variant) {
      ChatEmptyStateVariant.error => scheme.errorContainer.withValues(alpha: 0.7),
      ChatEmptyStateVariant.secret => scheme.secondaryContainer.withValues(alpha: 0.6),
      ChatEmptyStateVariant.offline => scheme.surfaceContainerHighest.withValues(alpha: 0.7),
      ChatEmptyStateVariant.empty => scheme.primaryContainer.withValues(alpha: 0.6),
    };

    final Color iconColor = switch (variant) {
      ChatEmptyStateVariant.error => scheme.onErrorContainer,
      ChatEmptyStateVariant.secret => scheme.onSecondaryContainer,
      ChatEmptyStateVariant.offline => scheme.onSurfaceVariant,
      ChatEmptyStateVariant.empty => scheme.onPrimaryContainer,
    };

    if (variant == ChatEmptyStateVariant.secret) {
      return _buildSecretEmptyCard(context, scheme, textTheme);
    }

    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.98 + (0.02 * value),
              child: child,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Compact tonal icon container
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon ?? Icons.chat_bubble_outline_rounded,
                  size: 28,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecretEmptyCard(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scheme.outlineVariant,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.lock_rounded,
                    size: 26,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title.isNotEmpty ? title : 'Секретный чат',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description.isNotEmpty
                      ? description
                      : 'Здесь используется сквозное шифрование',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: scheme.outlineVariant,
                ),
                const SizedBox(height: 14),
                _buildSecurityRow(
                  scheme: scheme,
                  textTheme: textTheme,
                  icon: Icons.enhanced_encryption_rounded,
                  title: 'Сквозное шифрование',
                  subtitle: 'Curve25519 + Double Ratchet (AES-256)',
                ),
                const SizedBox(height: 10),
                _buildSecurityRow(
                  scheme: scheme,
                  textTheme: textTheme,
                  icon: Icons.cloud_off_rounded,
                  title: 'Без следов на сервере',
                  subtitle: 'Сервер передаёт только шифрованные данные',
                ),
                const SizedBox(height: 10),
                _buildSecurityRow(
                  scheme: scheme,
                  textTheme: textTheme,
                  icon: Icons.timer_outlined,
                  title: 'Таймер самоуничтожения',
                  subtitle: 'Сообщения сгорают после прочтения',
                ),
                const SizedBox(height: 10),
                _buildSecurityRow(
                  scheme: scheme,
                  textTheme: textTheme,
                  icon: Icons.block_rounded,
                  title: 'Запрет пересылки и копирования',
                  subtitle: 'Контент защищён от экспорта из чата',
                ),
                const SizedBox(height: 10),
                _buildSecurityRow(
                  scheme: scheme,
                  textTheme: textTheme,
                  icon: Icons.screenshot_outlined,
                  title: 'Защита от скриншотов',
                  subtitle: 'Уведомление при попытке фиксации экрана',
                ),
                if (actionLabel != null && onAction != null) ...<Widget>[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: onAction,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: Text(
                        actionLabel!,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityRow({
    required ColorScheme scheme,
    required TextTheme textTheme,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          icon,
          size: 18,
          color: scheme.secondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
