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

/// The accent editor: everything about where the palette comes from — the
/// system's dynamic colours, the ready-made seeds, an own HEX code, and the
/// tonal character the scheme is built with. The appearance screen keeps the
/// quick grid and sends anything deeper here.
class SettingsAppearanceAccentScreen extends StatelessWidget {
  const SettingsAppearanceAccentScreen({this.isEmbedded = false, super.key});

  final bool isEmbedded;

  @override
  Widget build(BuildContext context) {
    return _AccentScreen(isEmbedded: isEmbedded);
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

class _AccentScreen extends ConsumerWidget {
  const _AccentScreen({this.isEmbedded = false});

  final bool isEmbedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VisualThemeSettings visualTheme = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.visualTheme),
    );
    final bool useSystemDynamic = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.useSystemDynamic),
    );
    final Color seedColor = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.seedColor),
    );
    final PaletteStyle paletteStyle = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.paletteStyle),
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
                seedColor: seedColor,
                paletteStyle: paletteStyle,
                useSystemDynamic: useSystemDynamic,
                dynamicSeed: dynamicSeed,
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
    required Color seedColor,
    required PaletteStyle paletteStyle,
    required bool useSystemDynamic,
    required Color? dynamicSeed,
  }) {
    final bool customSelected =
        !useSystemDynamic &&
        !_palettes.any((p) => p.color.toARGB32() == seedColor.toARGB32());
    // The swatches of the style chips answer for the seed actually in force,
    // which is the dynamic one while system colours are on.
    final Color effectiveSeed = useSystemDynamic
        ? (dynamicSeed ?? seedColor)
        : seedColor;

    return SettingsShell(
      title: context.l10n.appearanceAccentPalette,
      isEmbedded: isEmbedded,
      children: [
        SettingsSection(
          title: context.l10n.appearanceAccentPalette,
          subtitle: context.l10n.appearanceAccentPaletteSubtitle,
          accentIcon: Icons.palette_rounded,
          children: [
            // The row exists only where the system really offers a palette:
            // without a seed the toggle would promise an undeliverable look.
            if (dynamicSeed != null)
              SettingsAnchor(
                id: 'appearance.color.source',
                child: SettingsListItem.toggle(
                  icon: Icons.wallpaper_rounded,
                  title: context.l10n.appearanceSystemColors,
                  subtitle: context.l10n.appearanceSystemColorsSubtitle,
                  value: useSystemDynamic,
                  onChanged: (bool value) => ref
                      .read(uiSettingsProvider.notifier)
                      .setUseSystemDynamic(value),
                ),
              ),
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
                        // The accent already in use: nothing to change or
                        // reveal.
                        if (!useSystemDynamic &&
                            seedColor.toARGB32() == entry.color.toARGB32()) {
                          return;
                        }
                        HapticService.selection();
                        // setSeedColor also switches system colours off in
                        // the same state change, so no separate call follows.
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
              icon: Icons.colorize_rounded,
              title: context.l10n.appearanceHexLabel,
              value:
                  '#${seedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
              onTap: () => _openCustomColorPicker(context, ref, seedColor),
            ),
          ],
        ),
        _PaletteStyleSelectorTile(
          currentStyle: paletteStyle,
          seedColor: effectiveSeed,
          brightness: scheme.brightness,
          onChanged: (PaletteStyle style) {
            ref.read(uiSettingsProvider.notifier).setPaletteStyle(style);
          },
        ),
      ],
    );
  }

  // An accent change opens in a circle from the swatch that was touched, so
  // the selection mark and the colours arrive together. A change made while
  // a reveal is still running lands at once under it, because the switcher
  // would otherwise drop it.
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

/// Every accent at once, as on the appearance screen: a grid shows the whole
/// palette in one look and still fits a 320 dp window at 200 % text, because
/// the labels live in the tooltips.
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

/// The palette's tonal character. Each pill answers with its own two-tone
/// swatch — the primary and container the style would build from the seed
/// in force — so the choice can be made by eye, not by name.
class _PaletteStyleSelectorTile extends StatelessWidget {
  const _PaletteStyleSelectorTile({
    required this.currentStyle,
    required this.seedColor,
    required this.brightness,
    required this.onChanged,
  });
  final PaletteStyle currentStyle;
  final Color seedColor;
  final Brightness brightness;
  final ValueChanged<PaletteStyle> onChanged;

  String _labelFor(BuildContext context, PaletteStyle style) => switch (style) {
    PaletteStyle.expressive => context.l10n.appearancePaletteExpressive,
    PaletteStyle.vibrant => context.l10n.appearancePaletteVibrant,
    PaletteStyle.content => context.l10n.appearancePaletteContent,
    PaletteStyle.calm => context.l10n.appearancePaletteCalm,
    PaletteStyle.mono => context.l10n.appearancePaletteMono,
  };

  @override
  Widget build(BuildContext context) => SettingsSection(
    title: context.l10n.appearancePaletteStyle,
    subtitle: context.l10n.appearancePaletteStyleDesc,
    accentIcon: Icons.palette_outlined,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SettingsChoiceButtons<PaletteStyle>(
          segments: [
            for (final style in PaletteStyle.values)
              ButtonSegment<PaletteStyle>(
                value: style,
                icon: _PaletteStyleSwatch(
                  seedColor: seedColor,
                  style: style,
                  brightness: brightness,
                ),
                label: Text(_labelFor(context, style)),
              ),
          ],
          selected: {currentStyle},
          onSelectionChanged: (selected) => onChanged(selected.first),
        ),
      ),
    ],
  );
}

/// Two tones of the style, side by side, in the avatar slot of a choice
/// pill. The pill's tonal fill around it answers the selection, so the
/// swatch itself only has to tell the styles apart.
class _PaletteStyleSwatch extends StatelessWidget {
  const _PaletteStyleSwatch({
    required this.seedColor,
    required this.style,
    required this.brightness,
  });

  final Color seedColor;
  final PaletteStyle style;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ColorScheme preview = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      dynamicSchemeVariant: style.variant,
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          borderRadius: AppRadii.xsRadius,
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .6)),
        ),
      ),
      child: SizedBox(
        width: 18,
        height: 12,
        child: Row(
          children: <Widget>[
            Expanded(
              child: ColoredBox(color: preview.primary),
            ),
            Expanded(
              child: ColoredBox(color: preview.primaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}
