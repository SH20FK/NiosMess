import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/circular_theme_reveal.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/settings/custom_color_picker_sheet.dart';

/// The fast page of the appearance settings: theme, accent and text scale —
/// everything a user touches week to week. The deep accent controls (system
/// colours, palette style, HEX) live on the accent sub-screen and the corner
/// radii on the shape sub-screen; both open from here.
class SettingsAppearanceScreen extends StatelessWidget {
  const SettingsAppearanceScreen({this.isEmbedded = false, super.key});

  final bool isEmbedded;

  @override
  Widget build(BuildContext context) {
    return _AppearanceScreen(isEmbedded: isEmbedded);
  }
}

class _PaletteEntry {
  const _PaletteEntry(this.color, this.getName);
  final Color color;
  final String Function(AppLocalizations l10n) getName;
}

final _palettes = <_PaletteEntry>[
  _PaletteEntry(const Color(0xFF6750A4), (l) => l.appearanceLabelAmethyst),
  _PaletteEntry(const Color(0xFF006C5B), (l) => l.appearanceLabelLagoon),
  _PaletteEntry(const Color(0xFF4C662B), (l) => l.appearanceLabelMeadow),
  _PaletteEntry(const Color(0xFFB3261E), (l) => l.appearanceLabelEmber),
  _PaletteEntry(const Color(0xFF7D5260), (l) => l.appearanceLabelOrchid),
  _PaletteEntry(const Color(0xFF475569), (l) => l.appearanceLabelSlate),
  _PaletteEntry(const Color(0xFF006874), (l) => l.appearanceLabelSky),
  _PaletteEntry(const Color(0xFF984061), (l) => l.appearanceLabelRose),
];

final _appearanceThemeProvider = Provider.autoDispose
    .family<ThemeData, Brightness>((ref, brightness) {
      final VisualThemeSettings visual = ref.watch(
        uiSettingsProvider.select((UiSettingsState s) => s.visualTheme),
      );
      return AppTheme.themed(visual, brightness);
    });

class _AppearanceScreen extends ConsumerWidget {
  const _AppearanceScreen({this.isEmbedded = false});

  final bool isEmbedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VisualThemeSettings visualTheme = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.visualTheme),
    );
    final bool useSystemDynamic = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.useSystemDynamic),
    );
    final ThemeMode themeMode = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.themeMode),
    );
    final Color seedColor = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.seedColor),
    );
    final AppFontScale fontScale = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.fontScale),
    );
    final PaletteStyle paletteStyle = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.paletteStyle),
    );
    final double messageBubbleRadius = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.messageBubbleRadius),
    );

    final Brightness brightness = Theme.of(context).brightness;

    return DynamicColorBuilder(
      // dynamic_color 1.x still uses package:flutter/material.dart types; only
      // the seed Color crosses into the material_ui theme.
      builder: (lightDynamic, darkDynamic) {
        final Color? dynamicSeed = brightness == Brightness.light
            ? lightDynamic?.primary
            : darkDynamic?.primary;
        final ThemeData targetTheme = useSystemDynamic
            ? AppTheme.themed(
                visualTheme,
                brightness,
                dynamicSeed: dynamicSeed,
              )
            : ref.watch(_appearanceThemeProvider(brightness));

        return ValueListenableBuilder<bool>(
          valueListenable: CircularThemeSwitcher.revealing,
          builder: (context, revealing, _) => AnimatedTheme(
            data: targetTheme,
            // Under a circular reveal the theme switches at once: the
            // snapshot of the old theme already carries the transition.
            duration: context.reduceMotion || revealing
                ? Duration.zero
                : M3Durations.long2,
            curve: M3SpringCurves.expressiveStandard,
            child: Builder(
              builder: (animatedContext) => _buildContent(
                animatedContext,
                ref,
                Theme.of(animatedContext).colorScheme,
                themeMode: themeMode,
                seedColor: seedColor,
                fontScale: fontScale,
                paletteStyle: paletteStyle,
                useSystemDynamic: useSystemDynamic,
                messageBubbleRadius: messageBubbleRadius,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ColorScheme scheme, {
    required ThemeMode themeMode,
    required Color seedColor,
    required AppFontScale fontScale,
    required PaletteStyle paletteStyle,
    required bool useSystemDynamic,
    required double messageBubbleRadius,
  }) {
    final bool customSelected =
        !useSystemDynamic &&
        !_palettes.any((p) => p.color.toARGB32() == seedColor.toARGB32());

    final Widget themeCard = _ThemeModeSelectorCard(
      currentMode: themeMode,
      onSelectMode: (ThemeMode newMode, Offset tapOffset) {
        if (newMode == themeMode) return;
        _revealChange(
          context,
          tapOffset,
          () => ref.read(uiSettingsProvider.notifier).setThemeMode(newMode),
        );
      },
    );

    final Widget accentSection = SettingsAnchor(
      id: 'appearance.color.source',
      child: SettingsSection(
        title: context.l10n.appearanceAccentPalette,
        accentIcon: Icons.palette_rounded,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              0,
            ),
            child: _PaletteGrid(
              choices: [
                for (final entry in _palettes)
                  _PaletteChoice(
                    key: ValueKey<String>(
                      'appearance-palette-${entry.color.toARGB32()}',
                    ),
                    scheme: scheme,
                    seedColor: entry.color,
                    paletteStyle: paletteStyle,
                    label: entry.getName(context.l10n),
                    selected:
                        !useSystemDynamic &&
                        seedColor.toARGB32() == entry.color.toARGB32(),
                    onTap: (Offset origin) {
                      // The accent already in use: nothing to change or reveal.
                      if (!useSystemDynamic &&
                          seedColor.toARGB32() == entry.color.toARGB32()) {
                        return;
                      }
                      HapticService.selection();
                      // setSeedColor also switches system colours off in the
                      // same state change, so no separate call is needed.
                      _revealChange(
                        context,
                        origin,
                        () => ref
                            .read(uiSettingsProvider.notifier)
                            .setSeedColor(entry.color),
                      );
                    },
                  ),
                _PaletteChoice(
                  key: const ValueKey<String>('appearance-palette-custom'),
                  scheme: scheme,
                  seedColor: seedColor,
                  paletteStyle: paletteStyle,
                  label: context.l10n.appearanceCustomColor,
                  selected: customSelected,
                  custom: true,
                  onTap: (_) => _openCustomColorPicker(context, ref, seedColor),
                ),
              ],
            ),
          ),
          SettingsListItem.nav(
            icon: Icons.tune_rounded,
            title: context.l10n.appearancePaletteStyle,
            subtitle: context.l10n.appearanceAccentEditorDesc,
            onTap: () => openSettingsPage(context, '/settings/appearance/accent'),
          ),
        ],
      ),
    );

    final Widget textSection = SettingsSection(
      title: context.l10n.settingsV2TextShape,
      accentIcon: Icons.format_size_rounded,
      children: [
        SettingsAnchor(
          id: 'appearance.font.scale',
          child: _FontScaleSliderTile(
            currentScale: fontScale,
            onChanged: (AppFontScale scale) {
              ref.read(uiSettingsProvider.notifier).setFontScale(scale);
            },
          ),
        ),
        SettingsAnchor(
          id: 'ui_corner_radius',
          child: SettingsListItem.nav(
            icon: Icons.rounded_corner_rounded,
            title: context.l10n.settingsV2Advanced,
            subtitle: context.l10n.settingsV2GeometryHint,
            onTap: () => openSettingsPage(context, '/settings/appearance/shape'),
          ),
        ),
      ],
    );

    return SettingsShell(
      title: context.l10n.settingsV2Appearance,
      isEmbedded: isEmbedded,
      hero: _AppearanceHeroPreview(messageBubbleRadius: messageBubbleRadius),
      children: [
        themeCard,
        accentSection,
        textSection,
      ],
    );
  }

  // Theme and accent change the same way: the new look opens in a circle
  // from the control that was touched, so the selection mark and the colours
  // arrive together. The controls give their own feedback. A change made
  // while a reveal is still running lands at once under it, because the
  // switcher would otherwise drop it.
  void _revealChange(BuildContext context, Offset origin, VoidCallback apply) {
    final switcher = CircularThemeSwitcher.maybeOf(context);
    if (switcher == null || CircularThemeSwitcher.revealing.value) {
      apply();
      return;
    }
    switcher.toggleTheme(apply, tapOffset: origin, haptic: false);
  }

  void _openCustomColorPicker(
    BuildContext context,
    WidgetRef ref,
    Color initialColor,
  ) {
    AppModal.showSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        return CustomColorPickerSheet(
          initialColor: initialColor,
          onApplyColor: (Color color) {
            if (!context.mounted) return;
            ref.read(uiSettingsProvider.notifier).setSeedColor(color);
          },
        );
      },
    );
  }
}

/// The live preview above the settings: one line of chat — an incoming and
/// an outgoing bubble — drawn from the colours and corners in force right
/// now. The bubbles borrow the message radius setting itself, full on the
/// outer corners and half on the tail, exactly like the chat; the hero card
/// behind them answers to the UI radius. Text size needs no second
/// multiplier: the app-wide `AppTextScaler` already carries the `fontScale`
/// setting into every `MediaQuery`.
class _AppearanceHeroPreview extends StatelessWidget {
  const _AppearanceHeroPreview({required this.messageBubbleRadius});

  /// The radius the real bubbles round with, so the preview answers to the
  /// «Скругление сообщений» setting instead of a chrome token.
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

/// Every accent at once. The pager showed three and hid the rest behind a
/// swipe that the code itself admitted was hard to discover; a grid shows the
/// whole palette in one look and still fits a 320 dp window at 200 % text,
/// because the labels live in the tooltips.
class _PaletteGrid extends StatelessWidget {
  const _PaletteGrid({required this.choices});

  final List<_PaletteChoice> choices;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final double available = constraints.maxWidth;
      final int columns = (available / 64).floor().clamp(4, 9);
      // Each swatch carries a 3 dp ring on every side, so the cell has to
      // give that back before the tile is sized; otherwise a full row would
      // wrap one tile onto a second line.
      final double cell = (available - AppSpacing.md * (columns - 1)) / columns;
      final double size = (cell - 6).clamp(30.0, 58.0);
      return Wrap(
        key: const ValueKey('appearance-palette-strip'),
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          for (final choice in choices) choice.copyWithSize(size),
        ],
      );
    },
  );
}

class _PaletteChoice extends StatefulWidget {
  const _PaletteChoice({
    required this.scheme,
    required this.seedColor,
    required this.paletteStyle,
    required this.label,
    required this.selected,
    required this.onTap,
    this.custom = false,
    this.size = 56,
    super.key,
  });

  final ColorScheme scheme;
  final Color seedColor;
  final PaletteStyle paletteStyle;
  final String label;
  final bool selected;
  final bool custom;
  final double size;

  /// Called with the centre of the swatch in screen coordinates.
  final ValueChanged<Offset> onTap;

  _PaletteChoice copyWithSize(double size) => _PaletteChoice(
    key: key,
    scheme: scheme,
    seedColor: seedColor,
    paletteStyle: paletteStyle,
    label: label,
    selected: selected,
    custom: custom,
    onTap: onTap,
    size: size,
  );

  @override
  State<_PaletteChoice> createState() => _PaletteChoiceState();
}

class _PaletteChoiceState extends State<_PaletteChoice> {
  late ColorScheme preview;
  ColorScheme get scheme => widget.scheme;
  String get label => widget.label;
  bool get selected => widget.selected;
  bool get custom => widget.custom;

  void onTap() {
    final box = context.findRenderObject() as RenderBox?;
    widget.onTap(
      box != null && box.hasSize
          ? box.localToGlobal(box.size.center(Offset.zero))
          : Offset.zero,
    );
  }

  void _updatePreview() {
    preview = ColorScheme.fromSeed(
      seedColor: widget.seedColor,
      brightness: widget.scheme.brightness,
      dynamicSchemeVariant: widget.paletteStyle.variant,
    );
  }

  @override
  void initState() {
    super.initState();
    _updatePreview();
  }

  @override
  void didUpdateWidget(covariant _PaletteChoice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seedColor != widget.seedColor ||
        oldWidget.scheme.brightness != widget.scheme.brightness ||
        oldWidget.paletteStyle != widget.paletteStyle) {
      _updatePreview();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color fill = custom ? scheme.surfaceContainerHigh : preview.primary;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: PressableSurface(
          onTap: onTap,
          // The reveal already answers the tap; a second click would double it.
          playFeedback: false,
          borderRadius: AppRadii.of(context).lgRadius,
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: context.motionDuration(M3Durations.short4),
            curve: M3SpringCurves.spatialFast,
            padding: const EdgeInsets.all(3),
            decoration: ShapeDecoration(
              shape: RoundedSuperellipseBorder(
                borderRadius: AppRadii.of(context).lgRadius,
                side: BorderSide(
                  color: selected
                      ? scheme.primary
                      : custom
                      ? scheme.outlineVariant
                      : Colors.transparent,
                  width: selected ? 2 : 1,
                ),
              ),
            ),
            child: M3Container(
              Shapes.square,
              width: widget.size,
              height: widget.size,
              color: fill,
              child: custom
                  ? Center(
                      child: Icon(
                        selected ? Icons.check_rounded : Icons.add_rounded,
                        size: widget.size * .4,
                        color: custom && selected
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        // Four roles of the palette: enough to tell two
                        // variants of the same seed apart at a glance.
                        Column(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: ColoredBox(
                                      color: preview.primary,
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                  Expanded(
                                    child: ColoredBox(
                                      color: preview.tertiaryContainer,
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: ColoredBox(
                                      color: preview.secondaryContainer,
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                  Expanded(
                                    child: ColoredBox(
                                      color: preview.primaryContainer,
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (selected)
                          Center(
                            child: DecoratedBox(
                              decoration: ShapeDecoration(
                                color: scheme.surfaceContainerLowest,
                                shape: RoundedSuperellipseBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: widget.size * .28,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Theme choices share the connected settings group instead of a nested card.
class _ThemeModeSelectorCard extends StatelessWidget {
  const _ThemeModeSelectorCard({
    required this.currentMode,
    required this.onSelectMode,
  });
  final ThemeMode currentMode;
  final void Function(ThemeMode mode, Offset tapOffset) onSelectMode;

  @override
  Widget build(BuildContext context) => SettingsSection(
    title: context.l10n.appearanceThemeMode,
    accentIcon: Icons.contrast_rounded,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Builder(
          builder: (choiceContext) => SettingsChoiceButtons<ThemeMode>(
            segments: [
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                icon: const Icon(Icons.brightness_auto_rounded),
                label: Text(context.l10n.commonSystem),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                icon: const Icon(Icons.light_mode_rounded),
                label: Text(context.l10n.appearanceLabelLight),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                icon: const Icon(Icons.dark_mode_rounded),
                label: Text(context.l10n.appearanceLabelDark),
              ),
            ],
            selected: {currentMode},
            onSelectionChanged: (selection) {
              final box = choiceContext.findRenderObject() as RenderBox?;
              final offset = box != null && box.hasSize
                  ? box.localToGlobal(box.size.center(Offset.zero))
                  : Offset.zero;
              onSelectMode(selection.first, offset);
            },
          ),
        ),
      ),
    ],
  );
}

class _FontScaleSliderTile extends StatelessWidget {
  const _FontScaleSliderTile({
    required this.currentScale,
    required this.onChanged,
  });
  final AppFontScale currentScale;
  final ValueChanged<AppFontScale> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SettingsListItem.value(
        icon: Icons.format_size_rounded,
        title: context.l10n.appearanceTextScale,
        subtitle: context.l10n.appearanceTextScaleDesc,
        value: '${(currentScale.scale * 100).round()}%',
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SettingsChoiceButtons<AppFontScale>(
          segments: [
            for (final scale in AppFontScale.values)
              ButtonSegment<AppFontScale>(
                value: scale,
                label: Text('${(scale.scale * 100).round()}%'),
              ),
          ],
          selected: {currentScale},
          onSelectionChanged: (selected) => onChanged(selected.first),
        ),
      ),
    ],
  );
}
