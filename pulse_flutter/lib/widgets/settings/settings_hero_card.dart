import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/motion/m3_entrance.dart';

/// The large opening card of a settings page.
///
/// A hero block is a single tonal panel — `surfaceContainerLow` over the
/// page's `surfaceContainerLowest` — with the expressive extra-large corner
/// ([AppRadii.xl], 28-32 dp). It never casts a shadow: the step in the surface
/// ladder is the elevation. Use it for a live preview, a summary or anything
/// the user should see before the first group of rows.
///
/// ```dart
/// SettingsShell(
///   title: l10n.settingsV2Appearance,
///   hero: SettingsHeroCard(
///     label: l10n.appearancePreviewTitle,
///     child: _LiveChatPreview(),
///   ),
///   children: <Widget>[ ... ],
/// )
/// ```
class SettingsHeroCard extends StatelessWidget {
  const SettingsHeroCard({
    required this.child,
    this.label,
    this.trailing,
    this.leadingIcon,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.animateEntrance = true,
    super.key,
  });

  final Widget child;

  /// Small uppercase caption above [child], such as `LIVE PREVIEW`.
  final String? label;

  /// Optional control at the top trailing edge, such as a badge or a button.
  final Widget? trailing;

  /// Optional glyph shown before [label] in a squircle tile.
  final IconData? leadingIcon;

  final EdgeInsetsGeometry padding;

  /// Fill of the card; [ColorScheme.surfaceContainerLow] when not given.
  final Color? color;

  /// Lift the card in when the page is built. Skipped under reduced motion.
  final bool animateEntrance;

  /// Corner of the card, following the `uiCornerRadius` setting inside the
  /// 28-32 dp window that makes a panel read as a hero rather than a row.
  static double radiusOf(BuildContext context) =>
      (AppRadii.of(context).xl + 4).clamp(28.0, 32.0);

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final bool hasHeader =
        label?.trim().isNotEmpty == true ||
        trailing != null ||
        leadingIcon != null;

    final Widget body = DecoratedBox(
      decoration: ShapeDecoration(
        color: color ?? scheme.surfaceContainerLow,
        shape: AppRadii.superellipse(radiusOf(context)),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (hasHeader) ...[
              Row(
                children: <Widget>[
                  if (leadingIcon != null) ...<Widget>[
                    _HeroIcon(icon: leadingIcon!),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  if (label?.trim().isNotEmpty == true)
                    Expanded(
                      child: Text(
                        label!.toUpperCase(),
                        style: text.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  ?trailing,
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            child,
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      child: animateEntrance ? M3Entrance(offsetY: 14, child: body) : body,
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.primaryContainer,
        shape: AppRadii.superellipse(AppRadii.of(context).sm),
      ),
      child: SizedBox.square(
        dimension: 24,
        child: Center(
          child: Icon(icon, size: 15, color: scheme.onPrimaryContainer),
        ),
      ),
    );
  }
}
