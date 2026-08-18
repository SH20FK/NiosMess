import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';

class EmptyFeedWidget extends StatelessWidget {
  const EmptyFeedWidget({
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.features,
    super.key,
  });

  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final List<String>? features;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final IconData effectiveIcon = icon ?? Icons.chat_bubble_outline_rounded;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // M3 Expressive Shape Container with Icon
              M3Container(
                Shapes.c9_sided_cookie,
                width: 84,
                height: 84,
                color: scheme.primaryContainer.withValues(alpha: 0.7),
                child: Center(
                  child: Icon(
                    effectiveIcon,
                    size: 38,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.85, 0.85),
                    end: const Offset(1.0, 1.0),
                    duration: 350.ms,
                    curve: Curves.easeOutBack,
                  )
                  .fade(duration: 250.ms),

              const SizedBox(height: 20),

              // Title
              Text(
                title,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Description
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  description,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Optional Features List (e.g. for Secret Chats)
              if (features != null && features!.isNotEmpty) ...[
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: features!.map((feature) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 16,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],

              // Action Button
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 22),
                FilledButton.tonalIcon(
                  onPressed: onAction,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(
                    actionLabel!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
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
