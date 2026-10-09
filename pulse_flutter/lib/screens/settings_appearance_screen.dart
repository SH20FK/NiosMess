import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/core/theme/app_typography.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/circular_theme_reveal.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/settings/palette_mesh_preview.dart';
import 'package:pulse_flutter/widgets/settings/custom_color_picker_sheet.dart';

class SettingsAppearanceScreen extends StatelessWidget {
  const SettingsAppearanceScreen({
    this.isEmbedded = false,
    super.key,
  });

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
    final double messageBubbleRadius = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.messageBubbleRadius),
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
    final bool pureBlackOled = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.pureBlackOled),
    );
    final bool navBarFloating = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.navBarFloating),
    );
    final bool predictiveBackEnabled = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.predictiveBackEnabled),
    );
    final double predictiveBackStrength = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.predictiveBackStrength),
    );
    final bool optimizeForWeakDevices = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.optimizeForWeakDevices),
    );
    final bool hideBubbleTails = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.hideBubbleTails),
    );

    final PerformanceTier tier = ref.watch(
      adaptivePerformanceProvider.select((AdaptivePerformanceState s) => s.tier),
    );
    final Brightness brightness = Theme.of(context).brightness;

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final ColorScheme? dynamicScheme =
            brightness == Brightness.light ? lightDynamic : darkDynamic;
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
              : const Duration(milliseconds: 500),
          curve: M3SpringCurves.expressiveStandard,
          child: Builder(
            builder: (animatedContext) => _buildContent(
              animatedContext,
              ref,
              Theme.of(animatedContext).colorScheme,
              tier,
              meshAnchor: useSystemDynamic
                  ? targetTheme.colorScheme.secondary
                  : seedColor,
              themeMode: themeMode,
              seedColor: seedColor,
              messageBubbleRadius: messageBubbleRadius,
              uiCornerRadius: uiCornerRadius,
              fontScale: fontScale,
              paletteStyle: paletteStyle,
              pureBlackOled: pureBlackOled,
              useSystemDynamic: useSystemDynamic,
              navBarFloating: navBarFloating,
              predictiveBackEnabled: predictiveBackEnabled,
              predictiveBackStrength: predictiveBackStrength,
              optimizeForWeakDevices: optimizeForWeakDevices,
              hideBubbleTails: hideBubbleTails,
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ColorScheme scheme,
    PerformanceTier tier, {
    required Color meshAnchor,
    required ThemeMode themeMode,
    required Color seedColor,
    required double messageBubbleRadius,
    required double uiCornerRadius,
    required AppFontScale fontScale,
    required PaletteStyle paletteStyle,
    required bool pureBlackOled,
    required bool useSystemDynamic,
    required bool navBarFloating,
    required bool predictiveBackEnabled,
    required double predictiveBackStrength,
    required bool optimizeForWeakDevices,
    required bool hideBubbleTails,
  }) {
    final Widget colorField = NiosColorField(
      scheme: scheme,
      meshAnchor: meshAnchor,
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
      animateMesh: !optimizeForWeakDevices && !tier.isTierC,
      onSelectPaletteStyle: (PaletteStyle style) {
        ref.read(uiSettingsProvider.notifier).setPaletteStyle(style);
      },
    );

    final Widget themeCard = _ThemeModeSelectorCard(
      currentMode: themeMode,
      scheme: scheme,
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
      title: context.l10n.appearanceGeometry,
      subtitle: context.l10n.appearanceGeometryDesc,
      children: [
        _SliderSettingTile(
          icon: Icons.chat_bubble_outline_rounded,
          title: context.l10n.appearanceMessageRounding,
          subtitle: context.l10n.appearanceMessageRoundingDesc,
          badgeText: '${messageBubbleRadius.toInt()} dp',
          value: messageBubbleRadius,
          min: 4.0,
          max: 28.0,
          divisions: 24,
          scheme: scheme,
          onChanged: (double val) {
            ref.read(uiSettingsProvider.notifier).setMessageBubbleRadius(val);
          },
        ),
        _SliderSettingTile(
          icon: Icons.rounded_corner_rounded,
          title: context.l10n.appearanceUiRounding,
          subtitle: context.l10n.appearanceUiRoundingDesc,
          badgeText: '${uiCornerRadius.toInt()} dp',
          value: uiCornerRadius,
          min: 8.0,
          max: 28.0,
          divisions: 20,
          scheme: scheme,
          onChanged: (double val) {
            ref.read(uiSettingsProvider.notifier).setUiCornerRadius(val);
          },
        ),
        _FontScaleSliderTile(
          currentScale: fontScale,
          scheme: scheme,
          onChanged: (AppFontScale scale) {
            ref.read(uiSettingsProvider.notifier).setFontScale(scale);
          },
        ),
        SettingsSwitchTile(
          icon: Icons.bubble_chart_rounded,
          title: 'Скрывать хвосты у сообщений',
          subtitle: 'Плоские пузыри сообщений без уголков-указателей',
          iconColor: scheme.primary,
          value: hideBubbleTails,
          onChanged: (bool v) {
            ref.read(uiSettingsProvider.notifier).setHideBubbleTails(v);
          },
        ),
      ],
    );

    final Widget contrastSection = SettingsSection(
      title: context.l10n.appearanceContrastColors,
      subtitle: context.l10n.appearanceContrastColorsDesc,
      children: [
        _PaletteStyleSelectorTile(
          currentStyle: paletteStyle,
          scheme: scheme,
          onChanged: (PaletteStyle style) {
            ref.read(uiSettingsProvider.notifier).setPaletteStyle(style);
          },
        ),
        SettingsSwitchTile(
          icon: Icons.contrast_rounded,
          title: context.l10n.appearanceDeepBlackOled,
          subtitle: context.l10n.appearanceDeepBlackOledDesc,
          iconColor: scheme.primary,
          value: pureBlackOled,
          onChanged: (bool v) {
            ref.read(uiSettingsProvider.notifier).setPureBlackOled(v);
          },
        ),
        SettingsSwitchTile(
          icon: Icons.auto_awesome_rounded,
          title: context.l10n.appearanceSystemColors,
          subtitle: context.l10n.appearanceSystemColorsSubtitle,
          iconColor: scheme.secondary,
          value: useSystemDynamic,
          onChanged: (bool v) {
            ref.read(uiSettingsProvider.notifier).setUseSystemDynamic(v);
          },
        ),
      ],
    );

    final Widget navSection = SettingsSection(
      title: context.l10n.appearanceInterfaceNav,
      subtitle: context.l10n.appearanceInterfaceNavDesc,
      children: [
        SettingsSwitchTile(
          icon: Icons.dock_rounded,
          title: context.l10n.appearanceFloatingNav,
          subtitle: context.l10n.appearanceFloatingNavSubtitle,
          iconColor: scheme.primary,
          value: navBarFloating,
          onChanged: (bool v) {
            ref.read(uiSettingsProvider.notifier).setNavBarFloating(v);
          },
        ),
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
            scheme: scheme,
            onChanged: (double val) {
              ref.read(uiSettingsProvider.notifier).setPredictiveBackStrength(val);
            },
          ),
      ],
    );

    return Container(
      color: scheme.surface,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool isWide = constraints.maxWidth >= 840;

          if (isWide) {
            return SettingsShell(
              title: context.l10n.appearanceTitle,
              isEmbedded: isEmbedded,
              maxWidth: 1120,
              children: [
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          colorField,
                          const SizedBox(height: 16),
                          themeCard,
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          geometrySection,
                          const SizedBox(height: 16),
                          contrastSection,
                          const SizedBox(height: 16),
                          navSection,
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            );
          }

          return SettingsShell(
            title: context.l10n.appearanceTitle,
            isEmbedded: isEmbedded,
            maxWidth: 860,
            children: [
              const SizedBox(height: 12),
              colorField,
              const SizedBox(height: 14),
              themeCard,
              const SizedBox(height: 16),
              geometrySection,
              const SizedBox(height: 16),
              contrastSection,
              const SizedBox(height: 16),
              navSection,
              const SizedBox(height: 32),
            ],
          );
        },
      ),
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
    this.animateMesh = false,
    this.meshAnchor,
    super.key,
  });

  final ColorScheme scheme;
  final Color? meshAnchor;
  final Color seedColor;
  final bool useSystemDynamic;
  final PaletteStyle paletteStyle;
  final bool animateMesh;
  final ValueChanged<Color> onColorSelected;
  final VoidCallback onCustomColorTap;
  final ValueChanged<bool> onToggleDynamic;
  final ValueChanged<PaletteStyle> onSelectPaletteStyle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // The expressive scheme can rotate primary into a complementary hue.
    // Keep decorative fog in the chosen palette's family instead.
    final hue = HSLColor.fromColor(
      meshAnchor ?? (useSystemDynamic ? scheme.secondary : seedColor),
    ).hue;
    final dark = scheme.brightness == Brightness.dark;
    Color fogTone(double shift, double saturation, double lightness) =>
        HSLColor.fromAHSL(
          1,
          (hue + shift) % 360,
          saturation,
          lightness,
        ).toColor();
    final colors = <Color>[
      fogTone(-25, 0.12, dark ? 0.56 : 0.78),
      fogTone(-5, 0.13, dark ? 0.68 : 0.85),
      fogTone(-55, 0.19, dark ? 0.46 : 0.65),
      fogTone(35, 0.24, dark ? 0.80 : 0.91),
    ];
    final customSelected =
        !useSystemDynamic &&
        !_palettes.any((p) => p.color.toARGB32() == seedColor.toARGB32());
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 160,
                  child: PaletteMeshPreview(
                    colors: colors,
                    animate: animateMesh,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.l10n.appearancePaletteTitle,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.appearancePaletteSubtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.appearanceSystemColors),
              subtitle: Text(context.l10n.appearanceSystemColorsSubtitle),
              value: useSystemDynamic,
              onChanged: onToggleDynamic,
            ),
            const SizedBox(height: 16),
            _PalettePager(
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
                      HapticService.tap();
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
          ],
        ),
      ),
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

/// Material 3 Expressive Theme Selector Card supporting System, Light, and Dark modes
class _ThemeModeSelectorCard extends StatelessWidget {
  const _ThemeModeSelectorCard({
    required this.currentMode,
    required this.scheme,
    required this.onSelectMode,
  });

  final ThemeMode currentMode;
  final ColorScheme scheme;
  final void Function(ThemeMode mode, Offset tapOffset) onSelectMode;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final IconData modeIcon;
    final String modeDesc;

    switch (currentMode) {
      case ThemeMode.system:
        modeIcon = Icons.brightness_auto_rounded;
        modeDesc = context.l10n.appearanceThemeModeSubtitle;
        break;
      case ThemeMode.light:
        modeIcon = Icons.light_mode_rounded;
        modeDesc = context.l10n.appearanceThemeLightActive;
        break;
      case ThemeMode.dark:
        modeIcon = Icons.dark_mode_rounded;
        modeDesc = context.l10n.appearanceThemeDarkActive;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.of(context).lgRadius,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.20),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: M3SpringCurves.spatial,
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  modeIcon,
                  color: scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.profileAppearance,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      modeDesc,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Builder(
            builder: (BuildContext segContext) {
              return SegmentedButton<ThemeMode>(
                segments: <ButtonSegment<ThemeMode>>[
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    icon: const Icon(Icons.brightness_auto_rounded, size: 18),
                    label: Text(context.l10n.commonSystem),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    icon: const Icon(Icons.light_mode_rounded, size: 18),
                    label: Text(context.l10n.appearanceLabelLight),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    icon: const Icon(Icons.dark_mode_rounded, size: 18),
                    label: Text(context.l10n.appearanceLabelDark),
                  ),
                ],
                selected: <ThemeMode>{currentMode},
                onSelectionChanged: (Set<ThemeMode> selection) {
                  final RenderBox? box =
                      segContext.findRenderObject() as RenderBox?;
                  final Offset offset = box != null && box.hasSize
                      ? box.localToGlobal(box.size.center(Offset.zero))
                      : Offset.zero;
                  onSelectMode(selection.first, offset);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Generic M3 Slider Setting Tile with leading icon, title, subtitle, live badge and spring drag bounce
class _SliderSettingTile extends StatefulWidget {
  const _SliderSettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.scheme,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ColorScheme scheme;
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
    if (!_isDragging && oldWidget.value != widget.value) {
      _localValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = widget.scheme;
    final String currentBadgeText = '${_localValue.toInt()} dp';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: scheme.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedScale(
                scale: _isDragging ? 1.14 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: M3SpringCurves.bouncy,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isDragging
                        ? scheme.primary.withValues(alpha: 0.22)
                        : scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isDragging
                          ? scheme.primary.withValues(alpha: 0.35)
                          : scheme.primary.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    currentBadgeText,
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: scheme.primary,
              inactiveTrackColor: scheme.surfaceContainerHighest,
              thumbColor: scheme.primary,
              overlayColor: scheme.primary.withValues(alpha: 0.12),
              trackHeight: 4,
            ),
            child: Slider(
              value: _localValue.clamp(widget.min, widget.max),
              min: widget.min,
              max: widget.max,
              divisions: widget.divisions,
              onChangeStart: (double v) {
                setState(() {
                  _isDragging = true;
                  _localValue = v;
                });
                HapticService.selection();
              },
              onChangeEnd: (double v) {
                setState(() {
                  _isDragging = false;
                  _localValue = v;
                });
                widget.onChanged(v);
              },
              onChanged: (double v) {
                final double step = (widget.max - widget.min) / widget.divisions;
                if ((v - _localValue).abs() >= step * 0.9) {
                  HapticService.selection();
                }
                setState(() {
                  _localValue = v;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Font Scale Tile with M3 Expressive SegmentedButton and spring badge bounce
class _FontScaleSliderTile extends StatelessWidget {
  const _FontScaleSliderTile({
    required this.currentScale,
    required this.scheme,
    required this.onChanged,
  });

  final AppFontScale currentScale;
  final ColorScheme scheme;
  final ValueChanged<AppFontScale> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final int percent = (currentScale.scale * 100).toInt();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.format_size_rounded,
                  color: scheme.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.appearanceTextScale,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      context.l10n.appearanceTextScaleDesc,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$percent%',
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<AppFontScale>(
            segments: const <ButtonSegment<AppFontScale>>[
              ButtonSegment<AppFontScale>(
                value: AppFontScale.small,
                label: Text('85%', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment<AppFontScale>(
                value: AppFontScale.normal,
                label: Text('100%', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment<AppFontScale>(
                value: AppFontScale.large,
                label: Text('115%', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment<AppFontScale>(
                value: AppFontScale.extraLarge,
                label: Text('130%', style: TextStyle(fontSize: 12)),
              ),
            ],
            selected: <AppFontScale>{currentScale},
            onSelectionChanged: (Set<AppFontScale> val) {
              HapticService.selection();
              onChanged(val.first);
            },
          ),
        ],
      ),
    );
  }
}

/// Predictive Back Gesture Strength Selector Tile
class _PredictiveBackStrengthTile extends StatelessWidget {
  const _PredictiveBackStrengthTile({
    required this.strength,
    required this.scheme,
    required this.onChanged,
  });

  final double strength;
  final ColorScheme scheme;
  final ValueChanged<double> onChanged;

  String _descriptionFor(BuildContext context, double val) {
    if (val <= 0.6) {
      return context.l10n.appearancePredictiveBackSoft;
    } else if (val >= 1.4) {
      return context.l10n.appearancePredictiveBackDeep;
    }
    return context.l10n.appearancePredictiveBackStandard;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final double normalized =
        strength <= 0.75 ? 0.5 : (strength >= 1.25 ? 1.5 : 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: scheme.secondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.appearancePredictiveBackStrength,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _descriptionFor(context, strength),
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${strength.toStringAsFixed(1)}x',
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<double>(
            segments: <ButtonSegment<double>>[
              ButtonSegment<double>(
                value: 0.5,
                label: Text(context.l10n.appearancePredictiveBackSoftLabel,
                    style: const TextStyle(fontSize: 12)),
              ),
              ButtonSegment<double>(
                value: 1.0,
                label: Text(context.l10n.appearancePredictiveBackStandardLabel,
                    style: const TextStyle(fontSize: 12)),
              ),
              ButtonSegment<double>(
                value: 1.5,
                label: Text(context.l10n.appearancePredictiveBackDeepLabel,
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
            selected: <double>{normalized},
            onSelectionChanged: (Set<double> selected) {
              HapticService.selection();
              onChanged(selected.first);
            },
          ),
        ],
      ),
    );
  }
}

class _PaletteStyleSelectorTile extends StatelessWidget {
  const _PaletteStyleSelectorTile({
    required this.currentStyle,
    required this.scheme,
    required this.onChanged,
  });

  final PaletteStyle currentStyle;
  final ColorScheme scheme;
  final ValueChanged<PaletteStyle> onChanged;

  String _labelFor(BuildContext context, PaletteStyle style) {
    return switch (style) {
      PaletteStyle.expressive => context.l10n.appearancePaletteExpressive,
      PaletteStyle.vibrant => context.l10n.appearancePaletteVibrant,
      PaletteStyle.content => context.l10n.appearancePaletteContent,
      PaletteStyle.calm => context.l10n.appearancePaletteCalm,
      PaletteStyle.mono => context.l10n.appearancePaletteMono,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                context.l10n.appearancePaletteStyle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: PaletteStyle.values.map((PaletteStyle style) {
                final bool isSelected = style == currentStyle;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(_labelFor(context, style)),
                    showCheckmark: false,
                    selectedColor: scheme.primaryContainer,
                    labelStyle: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected
                            ? scheme.primary
                            : scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    onSelected: (_) {
                      HapticService.selection();
                      onChanged(style);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
