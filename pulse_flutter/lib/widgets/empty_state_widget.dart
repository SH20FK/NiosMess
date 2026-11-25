import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.isBusy = false,
    this.iconColor,
    this.compact = false,
    super.key,
  });

  /// Width reserved for the action content so switching to [isBusy] never
  /// resizes the button (it would otherwise collapse to a bare 20dp spinner).
  static const double _actionWidth = 132;

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isBusy;

  /// Glyph override — failures must not be painted in the brand accent
  /// (`scheme.error` for errors, `scheme.tertiary` for warnings). Defaults to a
  /// softened primary: the neutral "nothing here yet" tone.
  final Color? iconColor;

  /// Quiet variant for a passing state, such as a filter that matched
  /// nothing: a 56 dp glyph tile and a `titleMedium` title. The full-size one
  /// is for screens that are empty for good.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color effectiveIconColor =
        iconColor ?? scheme.primary.withValues(alpha: 0.8);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: compact ? 56 : 80,
              height: compact ? 56 : 80,
              decoration: ShapeDecoration(
                color: scheme.surfaceContainerHigh,
                // Expressive squircle, not a circle: matches the shape language
                // of the other hero/empty containers in the app.
                shape: compact
                    ? AppRadii.lgSuperellipse()
                    : AppRadii.xlSuperellipse(),
              ),
              child: Icon(
                icon,
                size: compact ? 28 : 40,
                color: effectiveIconColor,
              ),
            ),
            SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
            Text(
              title,
              style: (compact ? textTheme.titleMedium : textTheme.titleLarge)
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.tonal(
                onPressed: isBusy ? null : onAction,
                child: SizedBox(
                  width: _actionWidth,
                  child: Center(
                    child: isBusy
                        ? const AppLoadingIndicator(size: 20)
                        : Text(actionLabel!, textAlign: TextAlign.center),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
