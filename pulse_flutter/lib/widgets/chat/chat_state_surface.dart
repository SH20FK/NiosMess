import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';

/// Supported presentation variants for [ChatStateSurface].
enum ChatStateVariant {
  empty,
  secret,
  offline,
  error,
}

/// A unified Material 3 Expressive state presentation surface for chat viewports.
///
/// Standardizes the visual hierarchy across empty chat, secret chat features,
/// offline state, and reconnection/sync errors.
class ChatStateSurface extends StatelessWidget {
  const ChatStateSurface({
    super.key,
    required this.variant,
    required this.title,
    required this.description,
    this.icon,
    this.features,
    this.actionLabel,
    this.onAction,
  });

  /// Factory constructor for a standard empty chat.
  factory ChatStateSurface.empty({
    Key? key,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ChatStateSurface(
      key: key,
      variant: ChatStateVariant.empty,
      icon: Icons.chat_bubble_outline_rounded,
      title: title,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Factory constructor for an empty secret chat with security features.
  factory ChatStateSurface.secret({
    Key? key,
    required String title,
    required String description,
    required List<String> features,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ChatStateSurface(
      key: key,
      variant: ChatStateVariant.secret,
      icon: Icons.lock_rounded,
      title: title,
      description: description,
      features: features,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Factory constructor for an offline network state.
  factory ChatStateSurface.offline({
    Key? key,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ChatStateSurface(
      key: key,
      variant: ChatStateVariant.offline,
      icon: Icons.wifi_off_rounded,
      title: title,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Factory constructor for a connection or loading error state.
  factory ChatStateSurface.error({
    Key? key,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ChatStateSurface(
      key: key,
      variant: ChatStateVariant.error,
      icon: Icons.sync_problem_rounded,
      title: title,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  final ChatStateVariant variant;
  final String title;
  final String description;
  final IconData? icon;
  final List<String>? features;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Color containerColor = switch (variant) {
      ChatStateVariant.error => scheme.errorContainer.withValues(alpha: 0.7),
      ChatStateVariant.secret => scheme.tertiaryContainer.withValues(alpha: 0.7),
      ChatStateVariant.offline => scheme.surfaceContainerHighest.withValues(alpha: 0.7),
      ChatStateVariant.empty => scheme.primaryContainer.withValues(alpha: 0.7),
    };

    final Color iconColor = switch (variant) {
      ChatStateVariant.error => scheme.onErrorContainer,
      ChatStateVariant.secret => scheme.onTertiaryContainer,
      ChatStateVariant.offline => scheme.onSurfaceVariant,
      ChatStateVariant.empty => scheme.onPrimaryContainer,
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // M3 Expressive Morphing / Cookie Icon Badge
              M3Container(
                Shapes.c9_sided_cookie,
                width: 80,
                height: 80,
                color: containerColor,
                child: Center(
                  child: Icon(
                    icon ?? Icons.chat_bubble_outline_rounded,
                    size: 36,
                    color: iconColor,
                  ),
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.85, 0.85),
                    end: const Offset(1.0, 1.0),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                  )
                  .fadeIn(duration: const Duration(milliseconds: 250)),

              const SizedBox(height: 20),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: scheme.onSurface,
                ),
              ),

              const SizedBox(height: 6),

              // Description
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),

              // Security Features List for Secret Chat
              if (features != null && features!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: AppRadii.lgRadius,
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: features!.map((String feature) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 16,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurface,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(growable: false),
                    ),
                  ),
                ),
              ],

              // Action button
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: 22),
                FilledButton.tonal(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadii.fullRadius,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
