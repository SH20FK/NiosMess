import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
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

class _DensitySpec {
  const _DensitySpec({
    required this.heroHeight,
    required this.heroTopInset,
    required this.heroBottomInset,
    required this.heroPillSpacing,
    required this.heroSurfaceRadius,
    required this.sectionSpacing,
    required this.tileVerticalPadding,
  });

  final double heroHeight;
  final double heroTopInset;
  final double heroBottomInset;
  final double heroPillSpacing;
  final double heroSurfaceRadius;
  final double sectionSpacing;
  final double tileVerticalPadding;
}

class VaffuruThemeSettingsScreen extends ConsumerStatefulWidget {
  const VaffuruThemeSettingsScreen({super.key});

  @override
  ConsumerState<VaffuruThemeSettingsScreen> createState() =>
      _VaffuruThemeSettingsScreenState();
}

class _VaffuruThemeSettingsScreenState
    extends ConsumerState<VaffuruThemeSettingsScreen> {
  static const Map<_DensityMode, _DensitySpec> _densitySpecs =
      <_DensityMode, _DensitySpec>{
    _DensityMode.soft: _DensitySpec(
      heroHeight: 260,
      heroTopInset: 18,
      heroBottomInset: 18,
      heroPillSpacing: 8,
      heroSurfaceRadius: 24,
      sectionSpacing: 12,
      tileVerticalPadding: 6,
    ),
    _DensityMode.rich: _DensitySpec(
      heroHeight: 300,
      heroTopInset: 22,
      heroBottomInset: 22,
      heroPillSpacing: 10,
      heroSurfaceRadius: 28,
      sectionSpacing: 16,
      tileVerticalPadding: 8,
    ),
    _DensityMode.expressive: _DensitySpec(
      heroHeight: 340,
      heroTopInset: 24,
      heroBottomInset: 24,
      heroPillSpacing: 12,
      heroSurfaceRadius: 32,
      sectionSpacing: 20,
      tileVerticalPadding: 10,
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

  late final PageController _palettePageController;
  late _ThemePaletteId _selectedPalette;
  _DensityMode _densityMode = _DensityMode.rich;

  Map<_ThemePaletteId, ColorScheme> _previewSchemes = {};
  Brightness? _cachedBrightness;
  Md3Variant? _cachedVariant;

  _DensitySpec get _density => _densitySpecs[_densityMode]!;

  @override
  void initState() {
    super.initState();
    _selectedPalette = _paletteFromSeed(ref.read(uiSettingsProvider).seedColor);
    _palettePageController = PageController(
      initialPage: _paletteOrder.indexOf(_selectedPalette),
      viewportFraction: 0.28,
    );
  }

  @override
  void dispose() {
    _palettePageController.dispose();
    super.dispose();
  }

  _ThemePaletteId _paletteFromSeed(Color seed) {
    for (final MapEntry<_ThemePaletteId, Color> entry
        in _paletteSeeds.entries) {
      if (entry.value.toARGB32() == seed.toARGB32()) {
        return entry.key;
      }
    }
    return _ThemePaletteId.amethyst;
  }

  void _playFeedback(UiSettingsState settings) {
    ref.read(appSoundProvider).playUiTick();
    if (settings.haptics) {
      HapticService.tap();
    }
  }

  Widget _themeModeSelector(BuildContext context, UiSettingsState settings) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.dark_mode_outlined, color: scheme.onSecondaryContainer, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(context.l10n.appearanceThemeMode, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface)),
                      const SizedBox(height: 2),
                      Text(context.l10n.appearanceThemeModeSubtitle, style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: <ButtonSegment<ThemeMode>>[
                ButtonSegment<ThemeMode>(value: ThemeMode.system, label: Text(context.l10n.commonSystem, style: TextStyle(fontSize: 13))),
                ButtonSegment<ThemeMode>(value: ThemeMode.light, label: Text(context.l10n.appearanceLabelLight, style: TextStyle(fontSize: 13))),
                ButtonSegment<ThemeMode>(value: ThemeMode.dark, label: Text(context.l10n.appearanceLabelDark, style: TextStyle(fontSize: 13))),
              ],
              selected: <ThemeMode>{settings.themeMode},
              onSelectionChanged: (Set<ThemeMode> values) {
                _playFeedback(settings);
                ref.read(uiSettingsProvider.notifier).setThemeMode(values.first);
              },
              style: ButtonStyle(
                shape: const WidgetStatePropertyAll(StadiumBorder()),
                backgroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) return scheme.primaryContainer;
                  return scheme.surfaceContainerLow;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) return scheme.onPrimaryContainer;
                  return scheme.onSurfaceVariant;
                }),
                side: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) return BorderSide(color: scheme.primary.withValues(alpha: 0.18));
                  return BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.28));
                }),
                padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<_ThemePaletteId, ColorScheme> _buildPreviewSchemes(
    Brightness brightness,
    Md3Variant variant,
  ) {
    if (_cachedBrightness == brightness && _cachedVariant == variant) {
      return _previewSchemes;
    }
    _cachedBrightness = brightness;
    _cachedVariant = variant;
    _previewSchemes = {
      for (final _ThemePaletteId id in _paletteOrder)
        id: ColorScheme.fromSeed(
          seedColor: _paletteSeeds[id]!,
          brightness: brightness,
          dynamicSchemeVariant: switch (variant) {
            Md3Variant.tonalSpot => DynamicSchemeVariant.tonalSpot,
            Md3Variant.vibrant => DynamicSchemeVariant.vibrant,
            Md3Variant.expressive => DynamicSchemeVariant.expressive,
            Md3Variant.neutral => DynamicSchemeVariant.neutral,
            Md3Variant.monochrome => DynamicSchemeVariant.monochrome,
            Md3Variant.fidelity => DynamicSchemeVariant.fidelity,
          },
        ),
    };
    return _previewSchemes;
  }

  void _onPaletteSelected(int index) {
    final palette = _paletteOrder[index];
    if (_selectedPalette == palette) return;
    setState(() => _selectedPalette = palette);
    final seed = _paletteSeeds[palette]!;
    ref.read(uiSettingsProvider.notifier).setSeedColor(seed);
  }

  @override
  Widget build(BuildContext context) {
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Brightness brightness = scheme.brightness;
    final previewSchemes = _buildPreviewSchemes(brightness, settings.variant);
    final previewScheme = previewSchemes[_selectedPalette]!;

    return SettingsScaffold(
      title: context.l10n.appearancePersonalizationTitle,
      children: [
        SettingsNavBanner(
          icon: Icons.palette_outlined,
          title: context.l10n.appearancePersonalizationTitle,
          subtitle: context.l10n.appearancePersonalizationSubtitle,
          iconColor: scheme.primary,
        ),
        // 1. Живой предпросмотр чата с 3D tilt и анимированным переходом
        _TiltCard(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                ),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: _LiveChatPreview(
              key: ValueKey(_selectedPalette),
              scheme: previewScheme,
            ),
          ),
        ),
        SizedBox(height: _density.sectionSpacing),
        // 2. Интерактивные компоненты
        RepaintBoundary(
          child: _InteractiveComponentsPreview(scheme: previewScheme),
        ),
        SizedBox(height: _density.sectionSpacing),
        // 3. Выбор палитры
        SettingsSection(
          title: context.l10n.appearancePaletteTitle,
          subtitle: context.l10n.appearancePaletteSubtitle,
          children: [
            SizedBox(
              height: 120,
              child: PageView.builder(
                controller: _palettePageController,
                itemCount: _paletteOrder.length,
                onPageChanged: _onPaletteSelected,
                padEnds: true,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final palette = _paletteOrder[index];
                  final selected = palette == _selectedPalette;
                  final paletteScheme = previewSchemes[palette]!;
                  return GestureDetector(
                    onTap: () {
                      _playFeedback(settings);
                      _palettePageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCubic,
                      );
                      _onPaletteSelected(index);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? scheme.primary
                              : Colors.transparent,
                          width: selected ? 3.5 : 0,
                        ),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: CustomPaint(
                        painter: _PaletteOrbPainter(scheme: paletteScheme),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_paletteOrder.length, (index) {
                final selected =
                    index == _paletteOrder.indexOf(_selectedPalette);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: selected ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary
                        : scheme.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
          ],
        ),
        SizedBox(height: _density.sectionSpacing * 0.25),
        // 4. Плотность
        SettingsSection(
          title: context.l10n.appearanceDensityTitle,
          subtitle: context.l10n.appearanceDensitySubtitle,
          children: [
            Padding(
              padding: EdgeInsets.all(_density.heroPillSpacing + 2),
              child: SegmentedButton<_DensityMode>(
                showSelectedIcon: false,
                segments: <ButtonSegment<_DensityMode>>[
                  ButtonSegment<_DensityMode>(
                    value: _DensityMode.soft,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(context.l10n.appearanceDensitySoft, style: const TextStyle(fontSize: 13), maxLines: 1),
                    ),
                  ),
                  ButtonSegment<_DensityMode>(
                    value: _DensityMode.rich,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(context.l10n.appearanceDensityRich, style: const TextStyle(fontSize: 13), maxLines: 1),
                    ),
                  ),
                  ButtonSegment<_DensityMode>(
                    value: _DensityMode.expressive,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(context.l10n.appearanceDensityExpressive, style: const TextStyle(fontSize: 13), maxLines: 1),
                    ),
                  ),
                ],
                selected: <_DensityMode>{_densityMode},
                onSelectionChanged: (Set<_DensityMode> values) {
                  _playFeedback(settings);
                  setState(() => _densityMode = values.first);
                },
                style: ButtonStyle(
                  shape: const WidgetStatePropertyAll(
                    StadiumBorder(),
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (Set<WidgetState> states) {
                      if (states.contains(WidgetState.selected)) {
                        return scheme.primaryContainer;
                      }
                      return scheme.surfaceContainerLow;
                    },
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (Set<WidgetState> states) {
                      if (states.contains(WidgetState.selected)) {
                        return scheme.onPrimaryContainer;
                      }
                      return scheme.onSurfaceVariant;
                    },
                  ),
                  side: WidgetStateProperty.resolveWith(
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
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: _density.sectionSpacing * 0.25),
        // 5. Theme & Colors
        SettingsSection(
          title: context.l10n.appearanceThemeParamsTitle,
          subtitle: context.l10n.appearanceThemeParamsSubtitle,
          children: [
            _SwitchCardTile(
              title: context.l10n.appearanceSystemColors,
              subtitle: context.l10n.appearanceSystemColorsSubtitle,
              icon: Icons.wallpaper_outlined,
              value: settings.useSystemDynamic,
              verticalPadding: _density.tileVerticalPadding,
              onChanged: (bool value) {
                _playFeedback(settings);
                ref.read(uiSettingsProvider.notifier).setUseSystemDynamic(value);
              },
            ),
            _themeModeSelector(context, settings),
          ],
        ),
      ],
    );
  }
}

class _TiltCard extends StatefulWidget {
  const _TiltCard({super.key, required this.child});

  final Widget child;

  @override
  State<_TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<_TiltCard> {
  double _tiltX = 0;
  double _tiltY = 0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        final size = context.size;
        if (size != null) {
          setState(() {
            _tiltX = (event.localPosition.dy / size.height - 0.5) * 0.1;
            _tiltY = (event.localPosition.dx / size.width - 0.5) * -0.1;
          });
        }
      },
      onExit: (_) => setState(() {
        _tiltX = 0;
        _tiltY = 0;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(_tiltX)
          ..rotateY(_tiltY),
        transformAlignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}

class _LiveChatPreview extends StatelessWidget {
  const _LiveChatPreview({super.key, required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: scheme.primary,
                  child: Icon(Icons.person, color: scheme.onPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Алексей', style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    )),
                    Text('был(а) недавно', style: TextStyle(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                      fontSize: 12,
                    )),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text('Привет! Как дела?',
                        style: TextStyle(color: scheme.onSurface)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text('Всё супер! 😊',
                        style: TextStyle(color: scheme.onPrimary)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(height: 4),
        ],
      ),
    );
  }
}

class _InteractiveComponentsPreview extends StatefulWidget {
  const _InteractiveComponentsPreview({super.key, required this.scheme});

  final ColorScheme scheme;

  @override
  State<_InteractiveComponentsPreview> createState() =>
      _InteractiveComponentsPreviewState();
}

class _InteractiveComponentsPreviewState
    extends State<_InteractiveComponentsPreview> {
  bool _switchValue = true;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(colorScheme: widget.scheme),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Фото'),
                  selected: true,
                  onSelected: (_) {},
                  selectedColor: widget.scheme.primaryContainer,
                  checkmarkColor: widget.scheme.onPrimaryContainer,
                ),
                FilterChip(
                  label: const Text('Видео'),
                  selected: false,
                  onSelected: (_) {},
                ),
                FilterChip(
                  label: const Text('Файлы'),
                  selected: false,
                  onSelected: (_) {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {},
                    child: const Text('Подтвердить'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Отмена'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Уведомления',
                  style: TextStyle(color: widget.scheme.onSurface)),
                Switch(
                  value: _switchValue,
                  onChanged: (v) => setState(() => _switchValue = v),
                ),
              ],
            ),
          ],
        ),
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
