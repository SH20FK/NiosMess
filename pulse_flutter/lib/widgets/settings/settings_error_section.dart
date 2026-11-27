import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';

/// The failed form of a settings group: what went wrong, and one way back.
///
/// It is a tonal card on the same surface ladder as [SettingsSection]
/// (`surfaceContainerLow`, no shadow, no outline), with the failure in an
/// [ColorScheme.errorContainer] squircle and a single tonal retry button. The
/// retry label comes from `l10n.commonRetry` unless the caller names the
/// action more precisely.
///
/// ```dart
/// SettingsAsyncSwitcher(
///   value: form,
///   loading: () => const SettingsSkeleton(rows: 2),
///   data: (data) => _Form(data),
///   error: (error, _) => SettingsErrorSection(
///     title: l10n.settingsV2StorageError,
///     message: error.toString(),
///     onRetry: ref.invalidate(formProvider),
///   ),
/// )
/// ```
class SettingsErrorSection extends StatelessWidget {
  const SettingsErrorSection({
    required this.message,
    this.title,
    this.onRetry,
    this.retryLabel,
    this.icon = Icons.error_outline_rounded,
    super.key,
  });

  /// What went wrong, in the user's words.
  final String message;

  /// Optional short headline above [message].
  final String? title;

  /// Rebuilds the group. Without it the card is informational only.
  final VoidCallback? onRetry;

  /// Label of the retry control; `l10n.commonRetry` when not given.
  final String? retryLabel;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: scheme.surfaceContainerLow,
          // Same radius as SettingsSection so a failed group keeps the
          // silhouette of the group it replaces.
          shape: AppRadii.superellipse(
            (AppRadii.of(context).lg + 4).clamp(12.0, 32.0),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      color: scheme.errorContainer,
                      shape: AppRadii.superellipse(AppRadii.of(context).md),
                    ),
                    child: SizedBox.square(
                      dimension: AppHeights.sm,
                      child: Center(
                        child: Icon(
                          icon,
                          size: 20,
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (title?.trim().isNotEmpty == true) ...[
                          Text(
                            title!,
                            style: text.titleSmall?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        Text(
                          message,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.tonalIcon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(retryLabel ?? context.l10n.commonRetry),
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
