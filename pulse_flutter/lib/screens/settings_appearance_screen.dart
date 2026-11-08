import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
    final double uiCornerRadius = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.uiCornerRadius),
    );
    final AppFontScale fontScale = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.fontScale),
    );
    final PaletteStyle paletteStyle = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.paletteStyle),
    );
    final bool predictiveBackEnabled = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.predictiveBackEnabled),
    );
    final double predictiveBackStrength = ref.watch(
      uiSettingsProvider.select(
        (UiSettingsState s) => s.predictiveBackStrength,
      ),
    );

    final Brightness brightness = Theme.of(context).brightness;

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final ColorScheme? dynamicScheme = brightness == Brightness.light
            ? lightDynamic
            : darkDynamic;
        final ThemeData targetTheme = useSystemDynamic
            ? AppTheme.themed(
                visualTheme,
                brightness,
                dynamicScheme: dynamicScheme,
              )
            : ref.watch(_appearanceThemeProvider(brightness));

        return AnimatedTheme(
          data: targetTheme,
          duration: MediaQuery.disableAnimationsOf(context)
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
              uiCornerRadius: uiCornerRadius,
              fontScale: fontScale,
              paletteStyle: paletteStyle,
              useSystemDynamic: useSystemDynamic,
              predictiveBackEnabled: predictiveBackEnabled,
              predictiveBackStrength: predictiveBackStrength,
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
    required double uiCornerRadius,
    required AppFontScale fontScale,
    required PaletteStyle paletteStyle,
    required bool useSystemDynamic,
    required bool predictiveBackEnabled,
    required double predictiveBackStrength,
  }) {
    final Widget colorField = SettingsAnchor(
      id: 'appearance.color.source',
      child: NiosColorField(
        scheme: scheme,
        seedColor: seedColor,
        useSystemDynamic: useSystemDynamic,
        paletteStyle: paletteStyle,
        onColorSelected: (Color color) {
          ref.read(uiSettingsProvider.notifier).setSeedColor(color);
        },
        onCustomColorTap: () {
          _openCustomColorPicker(context, ref, seedColor);
        },
        onToggleDynamic: (bool val) {
          ref.read(uiSettingsProvider.notifier).setUseSystemDynamic(val);
        },
        onSelectPaletteStyle: (PaletteStyle style) {
          ref.read(uiSettingsProvider.notifier).setPaletteStyle(style);
        },
      ),
    );

    final Widget themeCard = _ThemeModeSelectorCard(
      currentMode: themeMode,
      onSelectMode: (ThemeMode newMode, Offset tapOffset) {
        if (newMode == themeMode) return;
        final switcher = CircularThemeSwitcher.maybeOf(context);
        if (switcher != null) {
          switcher.toggleTheme(
            () => ref.read(uiSettingsProvider.notifier).setThemeMode(newMode),
            tapOffset: tapOffset,
          );
        } else {
          HapticService.lightImpact();
          ref.read(uiSettingsProvider.notifier).setThemeMode(newMode);
        }
      },
    );

    final Widget geometrySection = SettingsSection(
      title: context.l10n.settingsV2Density,
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
          id: 'appearance.compact',
          child: SettingsSwitchTile(
            icon: Icons.density_small_rounded,
            title: context.l10n.appearanceCompactMode,
            subtitle: context.l10n.appearanceCompactModeSubtitle,
            value: ref.watch(uiSettingsProvider.select((s) => s.compactMode)),
            onChanged: (value) =>
                ref.read(uiSettingsProvider.notifier).setCompactMode(value),
          ),
        ),
        SettingsSearchDisclosure(
          anchor: 'ui_corner_radius',
          title: context.l10n.settingsV2Advanced,
          subtitle: context.l10n.settingsV2GeometryHint,
          children: [
            _SliderSettingTile(
              icon: Icons.rounded_corner_rounded,
              title: context.l10n.appearanceUiRounding,
              subtitle: context.l10n.appearanceUiRoundingDesc,
              value: uiCornerRadius,
              min: 8.0,
              max: 28.0,
              divisions: 20,
              onChanged: (double val) {
                ref.read(uiSettingsProvider.notifier).setUiCornerRadius(val);
              },
            ),
          ],
        ),
      ],
    );

    final Widget navSection = SettingsSection(
      title: context.l10n.appearanceInterfaceNav,
      subtitle: context.l10n.appearanceInterfaceNavDesc,
      children: [
        SettingsSwitchTile(
          icon: Icons.swipe_left_rounded,
          title: context.l10n.appearancePredictiveBack,
          subtitle: context.l10n.appearancePredictiveBackDesc,
          iconColor: scheme.secondary,
          value: predictiveBackEnabled,
          onChanged: (bool v) {
            ref.read(uiSettingsProvider.notifier).setPredictiveBackEnabled(v);
          },
        ),
        if (predictiveBackEnabled)
          _PredictiveBackStrengthTile(
            strength: predictiveBackStrength,
            onChanged: (double val) {
              ref
                  .read(uiSettingsProvider.notifier)
                  .setPredictiveBackStrength(val);
            },
          ),
      ],
    );

    return SettingsShell(
      title: context.l10n.settingsV2Appearance,
      isEmbedded: isEmbedded,
      children: [
        themeCard,
        colorField,
        geometrySection,
        if (!kIsWeb) navSection,
      ],
    );
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

class NiosColorField extends StatelessWidget {
  const NiosColorField({
    required this.scheme,
    required this.seedColor,
    required this.useSystemDynamic,
    required this.paletteStyle,
    required this.onColorSelected,
    required this.onCustomColorTap,
    required this.onToggleDynamic,
    required this.onSelectPaletteStyle,
    super.key,
  });

  final ColorScheme scheme;
  final Color seedColor;
  final bool useSystemDynamic;
  final PaletteStyle paletteStyle;
  final ValueChanged<Color> onColorSelected;
  final VoidCallback onCustomColorTap;
  final ValueChanged<bool> onToggleDynamic;
  final ValueChanged<PaletteStyle> onSelectPaletteStyle;

  @override
  Widget build(BuildContext context) {
    final customSelected =
        !useSystemDynamic &&
        !_palettes.any((p) => p.color.toARGB32() == seedColor.toARGB32());
    return SettingsSection(
      title: context.l10n.appearancePaletteTitle,
      subtitle: context.l10n.appearancePaletteSubtitle,
      children: [
        if (!kIsWeb)
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              secondary: const Icon(Icons.wallpaper_rounded),
              title: Text(context.l10n.appearanceSystemColors),
              subtitle: Text(context.l10n.appearanceSystemColorsSubtitle),
              value: useSystemDynamic,
              onChanged: onToggleDynamic,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
          child: _PalettePager(
            scheme: scheme,
            children: [
              for (final entry in _palettes)
                _PaletteChoice(
                  scheme: scheme,
                  seedColor: entry.color,
                  paletteStyle: paletteStyle,
                  label: entry.getName(context.l10n),
                  selected:
                      !useSystemDynamic &&
                      seedColor.toARGB32() == entry.color.toARGB32(),
                  onTap: () {
                    HapticService.selection();
                    onColorSelected(entry.color);
                    onToggleDynamic(false);
                  },
                ),
              _PaletteChoice(
                scheme: scheme,
                seedColor: seedColor,
                paletteStyle: paletteStyle,
                label: context.l10n.appearanceCustomColor,
                selected: customSelected,
                custom: true,
                onTap: onCustomColorTap,
              ),
            ],
          ),
        ),
        _PaletteStyleSelectorTile(
          currentStyle: paletteStyle,
          onChanged: onSelectPaletteStyle,
        ),
      ],
    );
  }
}

/// Full-width pages keep all three swatches inside the card at rest.
class _PalettePager extends StatefulWidget {
  const _PalettePager({required this.scheme, required this.children});
  final ColorScheme scheme;
  final List<_PaletteChoice> children;

  @override
  State<_PalettePager> createState() => _PalettePagerState();
}

class _PalettePagerState extends State<_PalettePager> {
  late final PageController _controller;
  late int _page;
  int get _pageCount => (widget.children.length / 3).ceil();

  @override
  void initState() {
    super.initState();
    final selected = widget.children.indexWhere((choice) => choice.selected);
    _page = selected < 0 ? 0 : selected ~/ 3;
    _controller = PageController(initialPage: _page);
  }

  void _goTo(int page) {
    HapticService.selection();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(
        page,
        duration: M3Durations.long1,
        curve: M3SpringCurves.bouncy,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final labelStyle = Theme.of(context).textTheme.labelMedium!;
      final labelHeight =
          MediaQuery.textScalerOf(context).scale(labelStyle.fontSize!) *
          1.4 *
          2;
      final diameter = ((constraints.maxWidth - 8) / 3 - 12).clamp(48.0, 72.0);
      return Column(
        children: [
          SizedBox(
            height: diameter + 8 + labelHeight + 12,
            child: PageView.builder(
              key: const ValueKey('appearance-palette-strip'),
              controller: _controller,
              itemCount: _pageCount,
              physics: MediaQuery.disableAnimationsOf(context)
                  ? const PageScrollPhysics()
                  : const _PalettePagePhysics(),
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, page) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int slot = 0; slot < 3; slot++)
                      Expanded(
                        child: page * 3 + slot < widget.children.length
                            ? widget.children[page * 3 + slot].withDiameter(
                                diameter,
                              )
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int page = 0; page < _pageCount; page++)
                Semantics(
                  button: true,
                  selected: _page == page,
                  label: MaterialLocalizations.of(
                    context,
                  ).tabLabel(tabIndex: page + 1, tabCount: _pageCount),
                  child: InkWell(
                    key: ValueKey('appearance-palette-page-$page'),
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _goTo(page),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : M3Durations.medium2,
                          curve: M3SpringCurves.snappy,
                          width: _page == page ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _page == page
                                ? widget.scheme.primary
                                : widget.scheme.outlineVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );
}

class _PalettePagePhysics extends PageScrollPhysics {
  const _PalettePagePhysics({super.parent});

  @override
  SpringDescription get spring => M3Spring.bouncy;

  @override
  _PalettePagePhysics applyTo(ScrollPhysics? ancestor) =>
      _PalettePagePhysics(parent: buildParent(ancestor));
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
    this.diameter = 72,
  });
  final ColorScheme scheme;
  final Color seedColor;
  final PaletteStyle paletteStyle;
  final String label;
  final bool selected;
  final bool custom;
  final double diameter;

  _PaletteChoice withDiameter(double diameter) => _PaletteChoice(
    scheme: scheme,
    seedColor: seedColor,
    paletteStyle: paletteStyle,
    label: label,
    selected: selected,
    custom: custom,
    onTap: onTap,
    diameter: diameter,
  );
  final VoidCallback onTap;

  @override
  State<_PaletteChoice> createState() => _PaletteChoiceState();
}

class _PaletteChoiceState extends State<_PaletteChoice> {
  late ColorScheme preview;
  ColorScheme get scheme => widget.scheme;
  String get label => widget.label;
  bool get selected => widget.selected;
  bool get custom => widget.custom;
  VoidCallback get onTap => widget.onTap;

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
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: Tooltip(
      message: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              Material(
                color: selected
                    ? scheme.secondaryContainer
                    : scheme.surfaceContainerHigh,
                shape: CircleBorder(
                  side: BorderSide(
                    color: selected ? scheme.primary : scheme.outlineVariant,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: SizedBox(
                    width: widget.diameter,
                    height: widget.diameter,
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: ClipOval(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
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
                                      children: [
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
                            ),
                            if (selected || custom)
                              Center(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: preview.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(5),
                                    child: Icon(
                                      selected
                                          ? Icons.check_rounded
                                          : Icons.add_rounded,
                                      size: 20,
                                      color: preview.onPrimary,
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
              ),
              ...[
                const SizedBox(height: 8),
                ExcludeSemantics(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      height: 1.4,
                      color: selected
                          ? scheme.onSecondaryContainer
                          : scheme.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
    subtitle: switch (currentMode) {
      ThemeMode.system => context.l10n.appearanceThemeModeSubtitle,
      ThemeMode.light => context.l10n.appearanceThemeLightActive,
      ThemeMode.dark => context.l10n.appearanceThemeDarkActive,
    },
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
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
      SettingsInfoTile(
        icon: widget.icon,
        title: widget.title,
        subtitle: widget.subtitle,
        value: '${_localValue.toInt()} dp',
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(trackHeight: 16),
          child: Slider(
            value: _localValue.clamp(widget.min, widget.max),
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            label: '${_localValue.toInt()} dp',
            onChangeStart: (_) => setState(() => _isDragging = true),
            onChangeEnd: (value) {
              setState(() => _isDragging = false);
              widget.onChanged(value);
            },
            onChanged: (value) => setState(() => _localValue = value),
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
      SettingsInfoTile(
        icon: Icons.format_size_rounded,
        title: context.l10n.appearanceTextScale,
        subtitle: context.l10n.appearanceTextScaleDesc,
        value: '${(currentScale.scale * 100).round()}%',
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SettingsChoiceButtons<AppFontScale>(
          segments: [
            for (final scale in AppFontScale.values)
              ButtonSegment<AppFontScale>(
                value: scale,
                label: Text('${(scale.scale * 100).round()}%'),
              ),
          ],
          selected: {currentScale},
          onSelectionChanged: (selected) {
            HapticService.selection();
            onChanged(selected.first);
          },
        ),
      ),
    ],
  );
}

class _PredictiveBackStrengthTile extends StatelessWidget {
  const _PredictiveBackStrengthTile({
    required this.strength,
    required this.onChanged,
  });
  final double strength;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SettingsInfoTile(
        icon: Icons.tune_rounded,
        title: context.l10n.appearancePredictiveBackStrength,
        subtitle: strength <= .6
            ? context.l10n.appearancePredictiveBackSoft
            : strength >= 1.4
            ? context.l10n.appearancePredictiveBackDeep
            : context.l10n.appearancePredictiveBackStandard,
        value: '${strength.toStringAsFixed(1)}×',
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SettingsChoiceButtons<double>(
          segments: [
            ButtonSegment<double>(
              value: .5,
              label: Text(context.l10n.appearancePredictiveBackSoftLabel),
            ),
            ButtonSegment<double>(
              value: 1,
              label: Text(context.l10n.appearancePredictiveBackStandardLabel),
            ),
            ButtonSegment<double>(
              value: 1.5,
              label: Text(context.l10n.appearancePredictiveBackDeepLabel),
            ),
          ],
          selected: {
            strength <= .75
                ? .5
                : strength >= 1.25
                ? 1.5
                : 1.0,
          },
          onSelectionChanged: (selected) {
            HapticService.selection();
            onChanged(selected.first);
          },
        ),
      ),
    ],
  );
}

class _PaletteStyleSelectorTile extends StatelessWidget {
  const _PaletteStyleSelectorTile({
    required this.currentStyle,
    required this.onChanged,
  });
  final PaletteStyle currentStyle;
  final ValueChanged<PaletteStyle> onChanged;
  String _labelFor(BuildContext context, PaletteStyle style) => switch (style) {
    PaletteStyle.expressive => context.l10n.appearancePaletteExpressive,
    PaletteStyle.vibrant => context.l10n.appearancePaletteVibrant,
    PaletteStyle.content => context.l10n.appearancePaletteContent,
    PaletteStyle.calm => context.l10n.appearancePaletteCalm,
    PaletteStyle.mono => context.l10n.appearancePaletteMono,
  };
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: Text(context.l10n.appearancePaletteStyle),
          subtitle: Text(context.l10n.appearanceContrastColorsDesc),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SettingsChoiceButtons<PaletteStyle>(
          segments: [
            for (final style in PaletteStyle.values)
              ButtonSegment<PaletteStyle>(
                value: style,
                label: Text(_labelFor(context, style)),
              ),
          ],
          selected: {currentStyle},
          onSelectionChanged: (selected) {
            HapticService.selection();
            onChanged(selected.first);
          },
        ),
      ),
    ],
  );
}
