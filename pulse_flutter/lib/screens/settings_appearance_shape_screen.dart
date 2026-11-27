import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

/// The geometry page of the appearance settings: the two radii the interface
/// listens to. The UI radius rounds every card, dialog and system panel; the
/// message radius shapes the chat bubbles — a setting that existed in the
/// state all along but nothing offered to change, alive here.
class SettingsAppearanceShapeScreen extends ConsumerWidget {
  const SettingsAppearanceShapeScreen({this.isEmbedded = false, super.key});

  final bool isEmbedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double uiCornerRadius = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.uiCornerRadius),
    );
    final double messageBubbleRadius = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.messageBubbleRadius),
    );

    return SettingsShell(
      title: context.l10n.settingsV2Advanced,
      isEmbedded: isEmbedded,
      hero: _ShapeHeroPreview(messageBubbleRadius: messageBubbleRadius),
      children: [
        SettingsSection(
          children: [
            SettingsAnchor(
              id: 'ui_corner_radius',
              child: _SliderSettingTile(
                icon: Icons.rounded_corner_rounded,
                title: context.l10n.appearanceUiRounding,
                subtitle: context.l10n.appearanceUiRoundingDesc,
                value: uiCornerRadius,
                min: 8.0,
                max: 28.0,
                divisions: 20,
                // The corners follow the thumb, so the page and the preview
                // round while it is dragged instead of after it is released.
                onChanged: (double val) {
                  ref.read(uiSettingsProvider.notifier).setUiCornerRadius(val);
                },
              ),
            ),
            _SliderSettingTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: context.l10n.appearanceMessageRounding,
              subtitle: context.l10n.appearanceMessageRoundingDesc,
              value: messageBubbleRadius,
              min: 8.0,
              max: 28.0,
              divisions: 20,
              // The bubbles in the hero above change with the thumb, the
              // same live answer the UI radius gives to the page itself.
              onChanged: (double val) {
                ref
                    .read(uiSettingsProvider.notifier)
                    .setMessageBubbleRadius(val);
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// One line of chat as the live answer of the message radius: an incoming
/// and an outgoing bubble, drawn with the same proportions the real bubbles
/// use — the full radius on the outer corners, half of it on the tail — so
/// the slider has something to move the moment it is touched.
class _ShapeHeroPreview extends StatelessWidget {
  const _ShapeHeroPreview({required this.messageBubbleRadius});

  /// The radius the real bubbles round with, straight from the setting.
  final double messageBubbleRadius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final double radius = messageBubbleRadius;
    final Radius big = Radius.circular(radius);
    final Radius tail = Radius.circular((radius * .5).clamp(4.0, 16.0));

    Widget bubble({required String message, required bool outgoing}) {
      final Color fill = outgoing
          ? scheme.primary
          : scheme.surfaceContainerHigh;
      final Color ink = outgoing ? scheme.onPrimary : scheme.onSurface;
      return Flexible(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: fill,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.only(
                topLeft: big,
                topRight: big,
                // The tail sits at the reading start of an incoming
                // bubble and at the reading end of an outgoing one.
                bottomLeft: outgoing
                    ? (rtl ? tail : big)
                    : (rtl ? big : tail),
                bottomRight: outgoing
                    ? (rtl ? big : tail)
                    : (rtl ? tail : big),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(color: ink),
            ),
          ),
        ),
      );
    }

    return SettingsHeroCard(
      label: context.l10n.appearancePreviewTitle,
      leadingIcon: Icons.forum_rounded,
      child: Row(
        children: <Widget>[
          bubble(
            message: context.l10n.appearanceIncomingPreview,
            outgoing: false,
          ),
          const SizedBox(width: AppSpacing.sm),
          bubble(message: context.l10n.appearancePreviewChat, outgoing: true),
        ],
      ),
    );
  }
}

class _SliderSettingTile extends StatefulWidget {
  const _SliderSettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  @override
  State<_SliderSettingTile> createState() => _SliderSettingTileState();
}

class _SliderSettingTileState extends State<_SliderSettingTile> {
  bool _isDragging = false;
  late double _localValue;
  @override
  void initState() {
    super.initState();
    _localValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant _SliderSettingTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) _localValue = widget.value;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SettingsListItem.value(
        icon: widget.icon,
        title: widget.title,
        subtitle: widget.subtitle,
        value: '${_localValue.toInt()} dp',
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(trackHeight: 16),
          child: Slider(
            value: _localValue.clamp(widget.min, widget.max),
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            label: '${_localValue.toInt()} dp',
            onChangeStart: (_) => setState(() => _isDragging = true),
            onChangeEnd: (_) => setState(() => _isDragging = false),
            onChanged: (value) {
              setState(() => _localValue = value);
              // Applied while dragging: the corners of the page and of the
              // preview move with the thumb.
              widget.onChanged(value);
            },
          ),
        ),
      ),
    ],
  );
}
