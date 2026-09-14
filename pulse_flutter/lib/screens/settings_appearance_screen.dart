import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/circular_theme_reveal.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

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

const _customColorPresets = <Color>[
  Color(0xFF6750A4), // Amethyst Violet
  Color(0xFF3F51B5), // Indigo
  Color(0xFF2563EB), // Royal Blue
  Color(0xFF0284C7), // Sky
  Color(0xFF00838F), // Cyan
  Color(0xFF006C5B), // Lagoon Teal
  Color(0xFF16A34A), // Emerald
  Color(0xFF65A30D), // Lime
  Color(0xFFD97706), // Amber
  Color(0xFFEA580C), // Orange
  Color(0xFFE11D48), // Crimson
  Color(0xFFDB2777), // Pink
  Color(0xFFA21CAF), // Fuchsia
  Color(0xFF7C3AED), // Vivid Purple
  Color(0xFF475569), // Slate
  Color(0xFF78350F), // Bronze
];

class _AppearanceScreen extends ConsumerWidget {
  const _AppearanceScreen({this.isEmbedded = false});

  final bool isEmbedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final PerformanceTier tier = ref.watch(
      adaptivePerformanceProvider.select((AdaptivePerformanceState s) => s.tier),
    );
    final Brightness brightness = Theme.of(context).brightness;

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final ColorScheme? dynamicScheme =
            brightness == Brightness.light ? lightDynamic : darkDynamic;
        final ThemeData targetTheme = AppTheme.themed(
          settings.visualTheme,
          brightness,
          dynamicScheme: settings.useSystemDynamic ? dynamicScheme : null,
        );

        return AnimatedTheme(
          data: targetTheme,
          duration: const Duration(milliseconds: 350),
          curve: M3SpringCurves.expressiveStandard,
          child: _buildContent(
            context,
            ref,
            settings,
            targetTheme.colorScheme,
            tier,
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    UiSettingsState settings,
    ColorScheme scheme,
    PerformanceTier tier,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Widget heroBanner = _ConnectedMeshAndPaletteBanner(
      scheme: scheme,
      settings: settings,
      tier: tier,
      onColorSelected: (Color color) {
        ref.read(uiSettingsProvider.notifier).setSeedColor(color);
      },
      onCustomColorTap: () {
        _openCustomColorPicker(context, ref, settings.seedColor);
      },
    );

    final Widget themeCard = _AuthStyleThemeToggleCard(
      isDark: isDark,
      scheme: scheme,
      onToggle: (Offset tapOffset) {
        final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
        final switcher = CircularThemeSwitcher.maybeOf(context);
        if (switcher != null) {
          switcher.toggleTheme(
            () => ref.read(uiSettingsProvider.notifier).setThemeMode(newMode),
            tapOffset: tapOffset,
          );
        } else {
          HapticFeedback.lightImpact();
          ref.read(uiSettingsProvider.notifier).setThemeMode(newMode);
        }
      },
    );

    final Widget geometrySection = SettingsSection(
      title: context.l10n.appearanceGeometry,
      subtitle: context.l10n.appearanceGeometryDesc,
      children: [
        // Message Bubble Radius Slider
        _SliderSettingTile(
          icon: Icons.chat_bubble_outline_rounded,
          title: context.l10n.appearanceMessageRounding,
          subtitle: context.l10n.appearanceMessageRoundingDesc,
          badgeText: '${settings.messageBubbleRadius.toInt()} dp',
          value: settings.messageBubbleRadius,
          min: 4.0,
          max: 28.0,
          divisions: 24,
          scheme: scheme,
          onChanged: (double val) {
            ref.read(uiSettingsProvider.notifier).setMessageBubbleRadius(val);
          },
        ),

        // UI Corner Radius Slider
        _SliderSettingTile(
          icon: Icons.rounded_corner_rounded,
          title: context.l10n.appearanceUiRounding,
          subtitle: context.l10n.appearanceUiRoundingDesc,
          badgeText: '${settings.uiCornerRadius.toInt()} dp',
          value: settings.uiCornerRadius,
          min: 8.0,
          max: 28.0,
          divisions: 20,
          scheme: scheme,
          onChanged: (double val) {
            ref.read(uiSettingsProvider.notifier).setUiCornerRadius(val);
          },
        ),

        // Font Scale Slider
        _FontScaleSliderTile(
          currentScale: settings.fontScale,
          scheme: scheme,
          onChanged: (AppFontScale scale) {
            ref.read(uiSettingsProvider.notifier).setFontScale(scale);
          },
        ),
      ],
    );

    final Widget contrastSection = SettingsSection(
      title: context.l10n.appearanceContrastColors,
      subtitle: context.l10n.appearanceContrastColorsDesc,
      children: [
        SettingsSwitchTile(
          icon: Icons.contrast_rounded,
          title: context.l10n.appearanceDeepBlackOled,
          subtitle: context.l10n.appearanceDeepBlackOledDesc,
          iconColor: scheme.primary,
          value: settings.pureBlackOled,
          onChanged: (bool v) {
            ref.read(uiSettingsProvider.notifier).setPureBlackOled(v);
          },
        ),
        SettingsSwitchTile(
          icon: Icons.auto_awesome_rounded,
          title: context.l10n.appearanceSystemColors,
          subtitle: context.l10n.appearanceSystemColorsSubtitle,
          iconColor: scheme.secondary,
          value: settings.useSystemDynamic,
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
          value: settings.navBarFloating,
          onChanged: (bool v) {
            ref.read(uiSettingsProvider.notifier).setNavBarFloating(v);
          },
        ),
        SettingsSwitchTile(
          icon: Icons.swipe_left_rounded,
          title: context.l10n.appearancePredictiveBack,
          subtitle: context.l10n.appearancePredictiveBackDesc,
          iconColor: scheme.secondary,
          value: settings.predictiveBackEnabled,
          onChanged: (bool v) {
            ref.read(uiSettingsProvider.notifier).setPredictiveBackEnabled(v);
          },
        ),
        if (settings.predictiveBackEnabled)
          _PredictiveBackStrengthTile(
            strength: settings.predictiveBackStrength,
            scheme: scheme,
            onChanged: (double val) {
              ref.read(uiSettingsProvider.notifier).setPredictiveBackStrength(val);
            },
          ),
      ],
    );

    final Widget wallpaperSection = SettingsSection(
      title: context.l10n.appearanceChatWallpaperTitle,
      subtitle: context.l10n.appearanceChatWallpaperDesc,
      children: <Widget>[
        SettingsTile(
          icon: Icons.texture_rounded,
          title: context.l10n.appearanceWallpaperGenerator,
          subtitle: context.l10n.appearanceWallpaperGeneratorDesc,
          iconColor: scheme.primary,
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: scheme.onSurfaceVariant,
          ),
          onTap: () {
            context.push('/settings/wallpaper');
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
                          heroBanner,
                          const SizedBox(height: 16),
                          themeCard,
                          const SizedBox(height: 16),
                          wallpaperSection,
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
              heroBanner,
              const SizedBox(height: 14),
              themeCard,
              const SizedBox(height: 16),
              geometrySection,
              const SizedBox(height: 16),
              contrastSection,
              const SizedBox(height: 16),
              navSection,
              const SizedBox(height: 16),
              wallpaperSection,
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return _CustomColorPickerSheet(
          initialColor: initialColor,
          onApplyColor: (Color color) {
            ref.read(uiSettingsProvider.notifier).setSeedColor(color);
          },
        );
      },
    );
  }
}

/// Large Mesh Gradient Banner (195dp) with seamless attached docked bottom capsule
/// holding 8 curated color orbs + 9th rainbow «+» custom color orb.
/// The top has rounded corners (28dp) and flat bottom; the bottom capsule has flat top
/// and rounded bottom (28dp), creating a unified, continuous Material 3 Expressive block.
class _ConnectedMeshAndPaletteBanner extends StatefulWidget {
  const _ConnectedMeshAndPaletteBanner({
    required this.scheme,
    required this.settings,
    required this.tier,
    required this.onColorSelected,
    required this.onCustomColorTap,
  });

  final ColorScheme scheme;
  final UiSettingsState settings;
  final PerformanceTier tier;
  final ValueChanged<Color> onColorSelected;
  final VoidCallback onCustomColorTap;

  @override
  State<_ConnectedMeshAndPaletteBanner> createState() =>
      _ConnectedMeshAndPaletteBannerState();
}

class _ConnectedMeshAndPaletteBannerState
    extends State<_ConnectedMeshAndPaletteBanner> {
  Offset _touchPos = Offset.zero;
  bool _isTouching = false;
  bool _isShaderReady = false;

  @override
  void initState() {
    super.initState();
    // Warm up the fragment shader immediately for zero pop-in delay
    ShaderBuilder.precacheShader(
      'packages/mesh_gradient/shaders/animated_mesh_gradient.frag',
    ).then((_) {
      if (mounted) setState(() => _isShaderReady = true);
    }).catchError((_) {
      if (mounted) setState(() => _isShaderReady = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = widget.scheme;
    final UiSettingsState settings = widget.settings;
    final PerformanceTier tier = widget.tier;
    final bool optimize =
        settings.optimizeForWeakDevices || tier == PerformanceTier.tierC || kIsWeb;

    final bool isPresetSelected = _palettes.any(
      (_PaletteEntry p) => p.color.toARGB32() == settings.seedColor.toARGB32(),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double bannerWidth = constraints.maxWidth;

        return RepaintBoundary(
          child: Column(
            children: [
              // 1. Large Mesh Gradient Canvas (195dp, rounded top corners) without 3D Parallax Tilt
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                child: SizedBox(
                  height: 195,
                  child: GestureDetector(
                    onPanStart: (DragStartDetails details) {
                      setState(() {
                        _touchPos = details.localPosition;
                        _isTouching = true;
                      });
                    },
                    onPanUpdate: (DragUpdateDetails details) {
                      setState(() {
                        _touchPos = details.localPosition;
                        _isTouching = true;
                      });
                    },
                    onPanEnd: (_) => setState(() => _isTouching = false),
                    onPanCancel: () => setState(() => _isTouching = false),
                    child: Stack(
                      children: [
                        // Smooth static linear fallback matching exact mesh tone palette
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  scheme.primary,
                                  scheme.tertiary,
                                  scheme.secondary,
                                  scheme.surfaceContainerHighest,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        ),

                        // Single, optimized GPU AnimatedMeshGradient (Tier A & B)
                        if (!optimize)
                          Positioned.fill(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              opacity: _isShaderReady ? 1.0 : 0.0,
                              child: ExcludeSemantics(
                                child: AnimatedMeshGradient(
                                  colors: [
                                    scheme.primary,
                                    scheme.tertiary,
                                    scheme.secondary,
                                    scheme.surfaceContainerHighest,
                                  ],
                                  options: AnimatedMeshGradientOptions(
                                    frequency: 4.5,
                                    amplitude: 28,
                                    speed: 2.2,
                                    grain: 0.03,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),

                        // Soft Vignette Overlay
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment.center,
                                  radius: 0.85,
                                  colors: [
                                    Colors.transparent,
                                    scheme.surface.withValues(alpha: 0.08),
                                    scheme.surface.withValues(alpha: 0.24),
                                  ],
                                  stops: const [0.4, 0.75, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Interactive Touch Reactive Glow with dynamic bannerWidth
                        if (_isTouching)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment(
                                      bannerWidth > 0
                                          ? (_touchPos.dx / bannerWidth - 0.5) * 2
                                          : 0.0,
                                      (_touchPos.dy / 195.0 - 0.5) * 2,
                                    ),
                                    radius: 0.5,
                                    colors: [
                                      scheme.primary.withValues(alpha: 0.25),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Seamless Attached Docked Bottom Capsule (flat top, rounded bottom 28dp)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(28)),
                child: Container(
                  height: 58,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    border: Border(
                      left: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.25),
                        width: 1,
                      ),
                      right: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.25),
                        width: 1,
                      ),
                      bottom: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                  ),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _palettes.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (BuildContext context, int index) {
                      if (index < _palettes.length) {
                        final _PaletteEntry entry = _palettes[index];
                        final bool isSelected = entry.color.toARGB32() ==
                            settings.seedColor.toARGB32();
                        return _ColorOrbItem(
                          color: entry.color,
                          label: entry.getName(context.l10n),
                          isSelected: isSelected,
                          onTap: () {
                            HapticService.tap();
                            widget.onColorSelected(entry.color);
                          },
                        );
                      }

                      // 9th Rainbow / Custom Color Orb
                      final bool isCustomSelected =
                          !isPresetSelected && !settings.useSystemDynamic;
                      return _RainbowCustomOrbItem(
                        isSelected: isCustomSelected,
                        currentColor: settings.seedColor,
                        onTap: () {
                          HapticService.tap();
                          widget.onCustomColorTap();
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ColorOrbItem extends StatefulWidget {
  const _ColorOrbItem({
    required this.color,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_ColorOrbItem> createState() => _ColorOrbItemState();
}

class _ColorOrbItemState extends State<_ColorOrbItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isLightOrb =
        ThemeData.estimateBrightnessForColor(widget.color) == Brightness.light;
    final Color checkColor = isLightOrb
        ? (isDark ? scheme.surface : scheme.onSurface)
        : (isDark ? scheme.onSurface : scheme.surface);
    final Color ringColor = widget.isSelected
        ? (isLightOrb
            ? (isDark ? scheme.surface : scheme.outline)
            : (isDark ? scheme.onSurface : scheme.surface))
        : Colors.transparent;

    return Center(
      child: Tooltip(
        message: widget.label,
        child: Listener(
          onPointerDown: (_) => setState(() => _isPressed = true),
          onPointerUp: (_) => setState(() => _isPressed = false),
          onPointerCancel: (_) => setState(() => _isPressed = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedScale(
              scale: _isPressed ? 0.90 : (widget.isSelected ? 1.15 : 1.0),
              duration: const Duration(milliseconds: 220),
              curve: M3SpringCurves.bouncy,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: M3SpringCurves.spatial,
                width: widget.isSelected ? 38 : 32,
                height: widget.isSelected ? 38 : 32,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ringColor,
                    width: widget.isSelected ? 2.5 : 0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: widget.isSelected ? 0.45 : 0.20),
                      blurRadius: widget.isSelected ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: widget.isSelected
                    ? Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: checkColor,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RainbowCustomOrbItem extends StatefulWidget {
  const _RainbowCustomOrbItem({
    required this.isSelected,
    required this.currentColor,
    required this.onTap,
  });

  final bool isSelected;
  final Color currentColor;
  final VoidCallback onTap;

  @override
  State<_RainbowCustomOrbItem> createState() => _RainbowCustomOrbItemState();
}

class _RainbowCustomOrbItemState extends State<_RainbowCustomOrbItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isLightColor =
        ThemeData.estimateBrightnessForColor(widget.currentColor) == Brightness.light;
    final Color iconColor = widget.isSelected
        ? (isLightColor
            ? (isDark ? scheme.surface : scheme.onSurface)
            : (isDark ? scheme.onSurface : scheme.surface))
        : (isDark ? scheme.onSurface : scheme.surface);
    final Color ringColor = widget.isSelected
        ? (isLightColor
            ? (isDark ? scheme.surface : scheme.outline)
            : (isDark ? scheme.onSurface : scheme.surface))
        : Colors.transparent;

    return Center(
      child: Tooltip(
        message: context.l10n.appearanceCustomColor,
        child: Listener(
          onPointerDown: (_) => setState(() => _isPressed = true),
          onPointerUp: (_) => setState(() => _isPressed = false),
          onPointerCancel: (_) => setState(() => _isPressed = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedScale(
              scale: _isPressed ? 0.90 : (widget.isSelected ? 1.15 : 1.0),
              duration: const Duration(milliseconds: 220),
              curve: M3SpringCurves.bouncy,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: M3SpringCurves.spatial,
                width: widget.isSelected ? 38 : 32,
                height: widget.isSelected ? 38 : 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.isSelected
                      ? null
                      : const SweepGradient(
                          colors: [
                            Color(0xFFE11D48),
                            Color(0xFFEA580C),
                            Color(0xFFEAB308),
                            Color(0xFF16A34A),
                            Color(0xFF0284C7),
                            Color(0xFF7C3AED),
                            Color(0xFFE11D48),
                          ],
                        ),
                  color: widget.isSelected ? widget.currentColor : null,
                  border: Border.all(
                    color: ringColor,
                    width: widget.isSelected ? 2.5 : 0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isSelected ? widget.currentColor : const Color(0xFF7C3AED))
                          .withValues(alpha: widget.isSelected ? 0.45 : 0.25),
                      blurRadius: widget.isSelected ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  widget.isSelected ? Icons.palette_rounded : Icons.add_rounded,
                  size: widget.isSelected ? 20 : 18,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact Theme Switcher Card matching the style of the Nios ID Auth Screen
/// with circular expansion animation originating from the button coordinates.
class _AuthStyleThemeToggleCard extends StatefulWidget {
  const _AuthStyleThemeToggleCard({
    required this.isDark,
    required this.scheme,
    required this.onToggle,
  });

  final bool isDark;
  final ColorScheme scheme;
  final void Function(Offset tapOffset) onToggle;

  @override
  State<_AuthStyleThemeToggleCard> createState() =>
      _AuthStyleThemeToggleCardState();
}

class _AuthStyleThemeToggleCardState extends State<_AuthStyleThemeToggleCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = widget.scheme;
    final isDark = widget.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Theme icon inside a soft squircle container
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: M3SpringCurves.spatial,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: scheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Title and Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.appearanceThemeDark,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDark
                      ? context.l10n.appearanceThemeDarkActive
                      : context.l10n.appearanceThemeLightActive,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Action Button triggering Circular Reveal Animation with spring bouncy feedback
          Builder(
            builder: (BuildContext btnContext) {
              return Listener(
                onPointerDown: (_) => setState(() => _isPressed = true),
                onPointerUp: (_) => setState(() => _isPressed = false),
                onPointerCancel: (_) => setState(() => _isPressed = false),
                child: GestureDetector(
                  onTap: () {
                    final RenderBox? box =
                        btnContext.findRenderObject() as RenderBox?;
                    final Offset offset = box != null && box.hasSize
                        ? box.localToGlobal(box.size.center(Offset.zero))
                        : Offset.zero;
                    widget.onToggle(offset);
                  },
                  child: AnimatedScale(
                    scale: _isPressed ? 0.90 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: _isPressed
                        ? M3SpringCurves.snappy
                        : M3SpringCurves.bouncy,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: M3SpringCurves.bouncy,
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.surfaceContainerHighest,
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.35),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.shadow.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: CurvedAnimation(
                              parent: anim,
                              curve: M3SpringCurves.bouncy,
                            ),
                            child: child,
                          ),
                          child: Icon(
                            isDark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            key: ValueKey<bool>(isDark),
                            color: scheme.primary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = widget.scheme;

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
                    boxShadow: _isDragging
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: CurvedAnimation(
                        parent: anim,
                        curve: M3SpringCurves.bouncy,
                      ),
                      child: child,
                    ),
                    child: Text(
                      widget.badgeText,
                      key: ValueKey<String>(widget.badgeText),
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
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
              value: widget.value.clamp(widget.min, widget.max),
              min: widget.min,
              max: widget.max,
              divisions: widget.divisions,
              onChangeStart: (_) {
                setState(() => _isDragging = true);
                HapticService.selection();
              },
              onChangeEnd: (_) {
                setState(() => _isDragging = false);
              },
              onChanged: (double v) {
                if (v != widget.value) {
                  HapticService.selection();
                  widget.onChanged(v);
                }
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
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: CurvedAnimation(
                      parent: anim,
                      curve: M3SpringCurves.bouncy,
                    ),
                    child: child,
                  ),
                  child: Text(
                    '$percent%',
                    key: ValueKey<int>(percent),
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
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

/// Custom Color Picker Bottom Sheet with 16 curated M3 accents + direct HEX code entry
class _CustomColorPickerSheet extends StatefulWidget {
  const _CustomColorPickerSheet({
    required this.initialColor,
    required this.onApplyColor,
  });

  final Color initialColor;
  final ValueChanged<Color> onApplyColor;

  @override
  State<_CustomColorPickerSheet> createState() =>
      _CustomColorPickerSheetState();
}

class _CustomColorPickerSheetState extends State<_CustomColorPickerSheet> {
  late Color _selectedColor;
  late TextEditingController _hexController;
  String? _hexError;
  Color? _pressedColor;
  bool _isApplyPressed = false;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _hexController = TextEditingController(text: _colorToHex(_selectedColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  void _onHexChanged(String value) {
    String clean = value.trim();
    if (!clean.startsWith('#')) clean = '#$clean';

    final RegExp hexRegex = RegExp(r'^#?([0-9a-fA-F]{6})$');
    if (hexRegex.hasMatch(clean)) {
      final String hexOnly = clean.replaceFirst('#', '');
      final int? intVal = int.tryParse('FF$hexOnly', radix: 16);
      if (intVal != null) {
        setState(() {
          _selectedColor = Color(intVal);
          _hexError = null;
        });
        return;
      }
    }
    setState(() {
      _hexError = mounted ? context.l10n.appearanceInvalidHex : 'Invalid HEX';
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title & Live Preview swatch
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _selectedColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _selectedColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.appearanceCustomColor,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      context.l10n.appearanceSelectHexPrompt,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 16 Curated M3 Accent Swatches
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: _customColorPresets.map((Color c) {
              final bool isDark =
                  Theme.of(context).brightness == Brightness.dark;
              final bool isSelected =
                  c.toARGB32() == _selectedColor.toARGB32();
              final bool isLightColor =
                  ThemeData.estimateBrightnessForColor(c) == Brightness.light;
              final Color iconColor = isLightColor
                  ? (isDark ? scheme.surface : scheme.onSurface)
                  : (isDark ? scheme.onSurface : scheme.surface);
              final Color ringColor = isSelected
                  ? (isLightColor
                      ? (isDark ? scheme.surface : scheme.outline)
                      : (isDark ? scheme.onSurface : scheme.surface))
                  : Colors.transparent;
              final bool isPressed = _pressedColor == c;

              return Listener(
                onPointerDown: (_) => setState(() => _pressedColor = c),
                onPointerUp: (_) => setState(() => _pressedColor = null),
                onPointerCancel: (_) => setState(() => _pressedColor = null),
                child: GestureDetector(
                  onTap: () {
                    HapticService.tap();
                    setState(() {
                      _selectedColor = c;
                      _hexController.text = _colorToHex(c);
                      _hexError = null;
                    });
                  },
                  child: AnimatedScale(
                    scale: isPressed ? 0.90 : (isSelected ? 1.15 : 1.0),
                    duration: const Duration(milliseconds: 220),
                    curve: M3SpringCurves.bouncy,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ringColor,
                          width: isSelected ? 2.5 : 0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: c.withValues(alpha: isSelected ? 0.5 : 0.2),
                            blurRadius: isSelected ? 8 : 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: iconColor,
                            )
                          : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Direct HEX Input Field
          TextField(
            controller: _hexController,
            inputFormatters: [
              LengthLimitingTextInputFormatter(7),
              FilteringTextInputFormatter.allow(RegExp(r'[#a-fA-F0-9]')),
            ],
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: context.l10n.appearanceHexLabel,
              hintText: '#6750A4',
              errorText: _hexError,
              prefixIcon: const Icon(Icons.colorize_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
              fillColor: scheme.surface,
            ),
            onChanged: _onHexChanged,
          ),

          const SizedBox(height: 20),

          // Apply Button with tactile spring scale
          Listener(
            onPointerDown: (_) => setState(() => _isApplyPressed = true),
            onPointerUp: (_) => setState(() => _isApplyPressed = false),
            onPointerCancel: (_) => setState(() => _isApplyPressed = false),
            child: AnimatedScale(
              scale: _isApplyPressed ? 0.96 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: _isApplyPressed ? M3SpringCurves.snappy : M3SpringCurves.bouncy,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  context.l10n.appearanceApply,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onPressed: () {
                  HapticService.confirm();
                  widget.onApplyColor(_selectedColor);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
