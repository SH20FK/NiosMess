import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SettingsAppearanceScreen extends StatelessWidget {
  const SettingsAppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VaffuruThemeSettingsScreen();
  }
}

enum _ThemePaletteId {
  amethyst,
  lagoon,
  meadow,
  ember,
  orchid,
  slate,
  sky,
  rose,
}

enum _DensityMode { soft, rich, expressive }

class VaffuruThemeSettingsScreen extends ConsumerStatefulWidget {
  const VaffuruThemeSettingsScreen({super.key});

  @override
  ConsumerState<VaffuruThemeSettingsScreen> createState() =>
      _VaffuruThemeSettingsScreenState();
}

class _DensitySpec {
  const _DensitySpec({
    required this.heroHeight,
    required this.heroTopInset,
    required this.heroBottomInset,
    required this.heroPillSpacing,
    required this.heroSurfaceRadius,
    required this.sectionSpacing,
    required this.tileVerticalPadding,
    required this.fogAmplitude,
    required this.fogBlurBoost,
  });

  final double heroHeight;
  final double heroTopInset;
  final double heroBottomInset;
  final double heroPillSpacing;
  final double heroSurfaceRadius;
  final double sectionSpacing;
  final double tileVerticalPadding;
  final double fogAmplitude;
  final double fogBlurBoost;
}

class _VaffuruThemeSettingsScreenState
    extends ConsumerState<VaffuruThemeSettingsScreen>
    with SingleTickerProviderStateMixin {
  static const Cubic _expressiveCurve = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Map<_DensityMode, _DensitySpec> _densitySpecs =
      <_DensityMode, _DensitySpec>{
        _DensityMode.soft: _DensitySpec(
          heroHeight: 268,
          heroTopInset: 18,
          heroBottomInset: 18,
          heroPillSpacing: 8,
          heroSurfaceRadius: 24,
          sectionSpacing: 12,
          tileVerticalPadding: 6,
          fogAmplitude: 0.85,
          fogBlurBoost: 0.88,
        ),
        _DensityMode.rich: _DensitySpec(
          heroHeight: 308,
          heroTopInset: 22,
          heroBottomInset: 22,
          heroPillSpacing: 10,
          heroSurfaceRadius: 28,
          sectionSpacing: 16,
          tileVerticalPadding: 8,
          fogAmplitude: 1.0,
          fogBlurBoost: 1.0,
        ),
        _DensityMode.expressive: _DensitySpec(
          heroHeight: 344,
          heroTopInset: 24,
          heroBottomInset: 24,
          heroPillSpacing: 12,
          heroSurfaceRadius: 32,
          sectionSpacing: 20,
          tileVerticalPadding: 10,
          fogAmplitude: 1.18,
          fogBlurBoost: 1.15,
        ),
      };

  static const List<_ThemePaletteId> _paletteOrder = <_ThemePaletteId>[
    _ThemePaletteId.amethyst,
    _ThemePaletteId.lagoon,
    _ThemePaletteId.meadow,
    _ThemePaletteId.ember,
    _ThemePaletteId.orchid,
    _ThemePaletteId.slate,
    _ThemePaletteId.sky,
    _ThemePaletteId.rose,
  ];

  static const Map<_ThemePaletteId, Color> _paletteSeeds =
      <_ThemePaletteId, Color>{
        _ThemePaletteId.amethyst: Color(0xFF9C27B0),
        _ThemePaletteId.lagoon: Color(0xFF00897B),
        _ThemePaletteId.meadow: Color(0xFF558B2F),
        _ThemePaletteId.ember: Color(0xFFD84315),
        _ThemePaletteId.orchid: Color(0xFFC2185B),
        _ThemePaletteId.slate: Color(0xFF546E7A),
        _ThemePaletteId.sky: Color(0xFF2F6FED),
        _ThemePaletteId.rose: Color(0xFFB3265F),
      };

  late final AnimationController _waveController;
  late _ThemePaletteId _selectedPalette;
  _DensityMode _densityMode = _DensityMode.rich;

  _DensitySpec get _density => _densitySpecs[_densityMode]!;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
    _selectedPalette = _paletteFromSeed(ref.read(uiSettingsProvider).seedColor);
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  _ThemePaletteId _paletteFromSeed(Color seed) {
    for (final MapEntry<_ThemePaletteId, Color> entry in _paletteSeeds.entries) {
      if (entry.value.toARGB32() == seed.toARGB32()) {
        return entry.key;
      }
    }
    return _ThemePaletteId.amethyst;
  }

  void _playFeedback(UiSettingsState settings) {
    ref.read(appSoundProvider).playUiTick();
    if (settings.haptics) {
      HapticFeedback.selectionClick();
    }
  }

  String _paletteLabel(_ThemePaletteId id) {
    final l10n = context.l10n;
    return switch (id) {
      _ThemePaletteId.amethyst => l10n.appearanceLabelAmethyst,
      _ThemePaletteId.lagoon => l10n.appearanceLabelLagoon,
      _ThemePaletteId.meadow => l10n.appearanceLabelMeadow,
      _ThemePaletteId.ember => l10n.appearanceLabelEmber,
      _ThemePaletteId.orchid => l10n.appearanceLabelOrchid,
      _ThemePaletteId.slate => l10n.appearanceLabelSlate,
      _ThemePaletteId.sky => l10n.appearanceLabelSky,
      _ThemePaletteId.rose => l10n.appearanceLabelRose,
    };
  }

  String _densityLabel(_DensityMode densityMode) {
    final l10n = context.l10n;
    return switch (densityMode) {
      _DensityMode.soft => l10n.appearanceDensitySoft,
      _DensityMode.rich => l10n.appearanceDensityRich,
      _DensityMode.expressive => l10n.appearanceDensityExpressive,
    };
  }

  @override
  Widget build(BuildContext context) {
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SettingsScaffold(
      title: context.l10n.appearancePersonalizationTitle,
      children: <Widget>[
        SettingsNavBanner(
          icon: Icons.palette_outlined,
          title: context.l10n.appearancePersonalizationTitle,
          subtitle: context.l10n.appearancePersonalizationSubtitle,
          iconColor: scheme.primary,
        ),
        _ThemeHeroCard(
          controller: _waveController,
          paletteLabel: _paletteLabel(_selectedPalette),
          densityLabel: _densityLabel(_densityMode),
          scheme: scheme,
          settings: settings,
          density: _density,
        ),
        SizedBox(height: _density.sectionSpacing),
        SettingsSection(
          title: context.l10n.appearancePaletteTitle,
          subtitle: context.l10n.appearancePaletteSubtitle,
          children: <Widget>[
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _paletteOrder.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (BuildContext context, int index) {
                  final _ThemePaletteId palette = _paletteOrder[index];
                  final Color seed = _paletteSeeds[palette]!;
                  final bool selected = palette == _selectedPalette;
                  final ColorScheme previewScheme = ColorScheme.fromSeed(
                    seedColor: seed,
                    brightness: scheme.brightness,
                    dynamicSchemeVariant:
                        settings.variant == Md3Variant.expressive
                        ? DynamicSchemeVariant.expressive
                        : DynamicSchemeVariant.tonalSpot,
                  );
                  return GestureDetector(
                    onTap: () {
                      _playFeedback(settings);
                      setState(() => _selectedPalette = palette);
                      ref
                          .read(uiSettingsProvider.notifier)
                          .setSeedColor(seed);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? scheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: CustomPaint(
                        painter: _PaletteOrbPainter(scheme: previewScheme),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
        SizedBox(height: _density.sectionSpacing * 0.25),
        SettingsSection(
          title: context.l10n.appearanceDensityTitle,
          subtitle: context.l10n.appearanceDensitySubtitle,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(_density.heroPillSpacing + 2),
              child: SegmentedButton<_DensityMode>(
                showSelectedIcon: false,
                segments: <ButtonSegment<_DensityMode>>[
                  ButtonSegment<_DensityMode>(
                    value: _DensityMode.soft,
                    label: Text(context.l10n.appearanceDensitySoft),
                  ),
                  ButtonSegment<_DensityMode>(
                    value: _DensityMode.rich,
                    label: Text(context.l10n.appearanceDensityRich),
                  ),
                  ButtonSegment<_DensityMode>(
                    value: _DensityMode.expressive,
                    label: Text(context.l10n.appearanceDensityExpressive),
                  ),
                ],
                selected: <_DensityMode>{_densityMode},
                onSelectionChanged: (Set<_DensityMode> values) {
                  _playFeedback(settings);
                  setState(() => _densityMode = values.first);
                },
                style: ButtonStyle(
                  shape: const WidgetStatePropertyAll<OutlinedBorder>(
                    StadiumBorder(),
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                    (Set<WidgetState> states) {
                      if (states.contains(WidgetState.selected)) {
                        return scheme.primaryContainer;
                      }
                      return scheme.surfaceContainerLow;
                    },
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith<Color?>(
                    (Set<WidgetState> states) {
                      if (states.contains(WidgetState.selected)) {
                        return scheme.onPrimaryContainer;
                      }
                      return scheme.onSurfaceVariant;
                    },
                  ),
                  side: WidgetStateProperty.resolveWith<BorderSide?>(
                    (Set<WidgetState> states) {
                      if (states.contains(WidgetState.selected)) {
                        return BorderSide(
                          color: scheme.primary.withValues(alpha: 0.18),
                        );
                      }
                      return BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.28),
                      );
                    },
                  ),
                  padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: _density.sectionSpacing * 0.25),
        SettingsSection(
          title: context.l10n.appearanceThemeParamsTitle,
          subtitle: context.l10n.appearanceThemeParamsSubtitle,
          children: <Widget>[
            _SwitchCardTile(
              title: context.l10n.appearanceDynamicColors,
              subtitle: context.l10n.appearanceDynamicColorsSubtitle,
              icon: Icons.color_lens_outlined,
              value: settings.variant == Md3Variant.expressive,
              verticalPadding: _density.tileVerticalPadding,
              onChanged: (bool value) {
                _playFeedback(settings);
                ref.read(uiSettingsProvider.notifier).setVariant(
                  value ? Md3Variant.expressive : Md3Variant.tonalSpot,
                );
              },
            ),
            _SwitchCardTile(
              title: context.l10n.appearanceDarkTheme,
              subtitle: context.l10n.appearanceDarkThemeSubtitle,
              icon: Icons.dark_mode_outlined,
              value: settings.themeMode == ThemeMode.dark,
              verticalPadding: _density.tileVerticalPadding,
              onChanged: (bool value) {
                _playFeedback(settings);
                ref.read(uiSettingsProvider.notifier).setThemeMode(
                  value ? ThemeMode.dark : ThemeMode.light,
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _ThemeHeroCard extends StatelessWidget {
  const _ThemeHeroCard({
    required this.controller,
    required this.paletteLabel,
    required this.densityLabel,
    required this.scheme,
    required this.settings,
    required this.density,
  });

  final AnimationController controller;
  final String paletteLabel;
  final String densityLabel;
  final ColorScheme scheme;
  final UiSettingsState settings;
  final _DensitySpec density;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      height: density.heroHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(density.heroSurfaceRadius + 4),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.alphaBlend(
              scheme.primary.withValues(alpha: 0.05),
              scheme.surfaceContainerHigh,
            ),
            Color.alphaBlend(
              scheme.tertiary.withValues(alpha: 0.035),
              scheme.surfaceContainerLow,
            ),
          ],
        ),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: AnimatedBuilder(
              animation: controller,
              builder: (BuildContext context, Widget? child) {
                final double t = _VaffuruThemeSettingsScreenState._expressiveCurve
                    .transform(controller.value);
                return CustomPaint(
                  painter: _AccentFogPainter(
                    progress: t,
                    scheme: scheme,
                    density: density,
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: density.heroTopInset,
            right: density.heroTopInset,
            top: density.heroTopInset,
            child: Wrap(
              spacing: density.heroPillSpacing,
              runSpacing: density.heroPillSpacing,
              children: <Widget>[
                _InfoPill(icon: Icons.auto_awesome, label: paletteLabel),
                _InfoPill(icon: Icons.tune, label: densityLabel),
                _InfoPill(
                  icon: settings.themeMode == ThemeMode.dark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                   label: settings.themeMode == ThemeMode.dark ? context.l10n.appearanceLabelDark : context.l10n.appearanceLabelLight,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteOrbPainter extends CustomPainter {
  const _PaletteOrbPainter({required this.scheme});

  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Paint paint = Paint()..style = PaintingStyle.fill;

    final List<Color> colors = <Color>[
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.primaryContainer,
    ];

    for (int i = 0; i < 4; i++) {
      paint.color = colors[i];
      canvas.drawArc(
        rect,
        (-math.pi / 2) + (i * math.pi / 2),
        math.pi / 2,
        true,
        paint,
      );
    }

    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = scheme.surface.withValues(alpha: 0.92);
    canvas.drawCircle(center, radius - 0.6, ring);
  }

  @override
  bool shouldRepaint(covariant _PaletteOrbPainter oldDelegate) {
    return oldDelegate.scheme != scheme;
  }
}

class _SwitchCardTile extends StatelessWidget {
  const _SwitchCardTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.verticalPadding,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final double verticalPadding;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: verticalPadding,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: scheme.onSecondaryContainer, size: 22),
        ),
        title: Text(
          title,
          style: textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
        trailing: AnimatedScale(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          scale: value ? 1.04 : 1.0,
          child: Switch(
            value: value,
            onChanged: onChanged,
            thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
              (Set<WidgetState> states) {
                final bool selected = states.contains(WidgetState.selected);
                return Icon(
                  selected ? Icons.check_rounded : Icons.close_rounded,
                  size: 12,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AccentFogPainter extends CustomPainter {
  const _AccentFogPainter({
    required this.progress,
    required this.scheme,
    required this.density,
  });

  final double progress;
  final ColorScheme scheme;
  final _DensitySpec density;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.045),
            scheme.surfaceContainerHighest,
          ),
          Color.alphaBlend(
            scheme.tertiary.withValues(alpha: 0.03),
            scheme.surfaceContainerLow,
          ),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, base);

    final double amp = density.fogAmplitude;
    final double blur = density.fogBlurBoost;

    _drawFogCluster(
      canvas,
      center: Offset(
        size.width * (0.22 + 0.038 * math.sin(progress * math.pi * 2) * amp),
        size.height * 0.24,
      ),
      radiusX: size.width * 0.20,
      radiusY: 32 * amp,
      color: scheme.primary.withValues(alpha: 0.15),
      blurSigma: 24 * blur,
      lobeScale: 0.94,
    );
    _drawFogCluster(
      canvas,
      center: Offset(
        size.width * (0.52 + 0.03 * math.cos(progress * math.pi * 2.1) * amp),
        size.height * 0.35,
      ),
      radiusX: size.width * 0.24,
      radiusY: 36 * amp,
      color: scheme.secondary.withValues(alpha: 0.12),
      blurSigma: 26 * blur,
      lobeScale: 1.0,
    );
    _drawFogCluster(
      canvas,
      center: Offset(
        size.width * (0.76 + 0.024 * math.sin(progress * math.pi * 2.0 + 0.9) * amp),
        size.height * 0.28,
      ),
      radiusX: size.width * 0.16,
      radiusY: 26 * amp,
      color: scheme.primaryContainer.withValues(alpha: 0.17),
      blurSigma: 22 * blur,
      lobeScale: 0.88,
    );
    _drawFogCluster(
      canvas,
      center: Offset(
        size.width * (0.42 + 0.026 * math.sin(progress * math.pi * 2.5 + 1.2) * amp),
        size.height * 0.60,
      ),
      radiusX: size.width * 0.28,
      radiusY: 42 * amp,
      color: scheme.tertiary.withValues(alpha: 0.13),
      blurSigma: 28 * blur,
      lobeScale: 1.04,
    );
    _drawFogCluster(
      canvas,
      center: Offset(
        size.width * (0.72 + 0.022 * math.cos(progress * math.pi * 2.4 + 0.8) * amp),
        size.height * 0.68,
      ),
      radiusX: size.width * 0.20,
      radiusY: 30 * amp,
      color: scheme.primary.withValues(alpha: 0.10),
      blurSigma: 24 * blur,
      lobeScale: 0.90,
    );


  }

  void _drawFogCluster(
    Canvas canvas, {
    required Offset center,
    required double radiusX,
    required double radiusY,
    required Color color,
    required double blurSigma,
    required double lobeScale,
  }) {
    final Paint corePaint = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
    final Paint edgePaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.52)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma * 0.55);

    final Path body = Path()
      ..addOval(
        Rect.fromCenter(
          center: center,
          width: radiusX * 2.0,
          height: radiusY * 2.0,
        ),
      )
      ..addOval(
        Rect.fromCenter(
          center: center.translate(-radiusX * 0.34, radiusY * 0.06),
          width: radiusX * 1.05 * lobeScale,
          height: radiusY * 1.10 * lobeScale,
        ),
      )
      ..addOval(
        Rect.fromCenter(
          center: center.translate(radiusX * 0.30, -radiusY * 0.08),
          width: radiusX * 1.18 * lobeScale,
          height: radiusY * 1.22 * lobeScale,
        ),
      )
      ..addOval(
        Rect.fromCenter(
          center: center.translate(radiusX * 0.02, -radiusY * 0.22),
          width: radiusX * 0.96 * lobeScale,
          height: radiusY * 0.92 * lobeScale,
        ),
      )
      ..addOval(
        Rect.fromCenter(
          center: center.translate(-radiusX * 0.12, radiusY * 0.20),
          width: radiusX * 1.20 * lobeScale,
          height: radiusY * 0.88 * lobeScale,
        ),
      );

    final Path accent = Path()
      ..addOval(
        Rect.fromCenter(
          center: center.translate(radiusX * 0.08, -radiusY * 0.10),
          width: radiusX * 1.10,
          height: radiusY * 0.92,
        ),
      )
      ..addOval(
        Rect.fromCenter(
          center: center.translate(-radiusX * 0.24, -radiusY * 0.04),
          width: radiusX * 0.86,
          height: radiusY * 0.82,
        ),
      );

    canvas.drawPath(body, corePaint);
    canvas.drawPath(accent, edgePaint);
  }

  @override
  bool shouldRepaint(covariant _AccentFogPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.scheme != scheme ||
        oldDelegate.density != density;
  }
}
