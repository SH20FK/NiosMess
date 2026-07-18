import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/active_color_orb.dart';

class SettingsAppearanceScreen extends StatelessWidget {
  const SettingsAppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AppearanceScreen();
  }
}

enum _ThemePaletteId {
  amethyst, lagoon, meadow, ember, orchid, slate, sky, rose,
}

class _ThemePaletteEntry {
  const _ThemePaletteEntry(this.color, this.nameKey);
  final Color color;
  final String nameKey;
}

const _ThemePaletteData = <_ThemePaletteId, _ThemePaletteEntry>{
  _ThemePaletteId.amethyst: _ThemePaletteEntry(Color(0xFF6750A4), 'Amethyst'),
  _ThemePaletteId.lagoon: _ThemePaletteEntry(Color(0xFF006C5B), 'Lagoon'),
  _ThemePaletteId.meadow: _ThemePaletteEntry(Color(0xFF4C662B), 'Meadow'),
  _ThemePaletteId.ember: _ThemePaletteEntry(Color(0xFF984061), 'Ember'),
  _ThemePaletteId.orchid: _ThemePaletteEntry(Color(0xFF825500), 'Orchid'),
  _ThemePaletteId.slate: _ThemePaletteEntry(Color(0xFF0061A4), 'Slate'),
  _ThemePaletteId.sky: _ThemePaletteEntry(Color(0xFF006874), 'Sky'),
  _ThemePaletteId.rose: _ThemePaletteEntry(Color(0xFF476810), 'Rose'),
};

class _AppearanceScreen extends ConsumerStatefulWidget {
  const _AppearanceScreen();

  @override
  ConsumerState<_AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends ConsumerState<_AppearanceScreen> {
  ThemeData? _prevTheme;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(uiSettingsProvider);
    final brightness = Theme.of(context).brightness;
    final targetTheme = AppTheme.themed(settings, brightness);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_prevTheme != null && _prevTheme != targetTheme) {
        setState(() {});
      }
    });

    final prevTheme = _prevTheme ?? targetTheme;
    _prevTheme = targetTheme;

    return TweenAnimationBuilder<ThemeData>(
      tween: ThemeDataTween(begin: prevTheme, end: targetTheme),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
      builder: (_, animatedTheme, __) {
        return Theme(
          data: animatedTheme,
          child: _buildContent(settings, animatedTheme.colorScheme, animatedTheme.textTheme),
        );
      },
    );
  }

  Widget _buildContent(
    UiSettingsState settings,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.15),
            scheme.tertiaryContainer.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ),
      ),
      child: SettingsScaffold(
        title: context.l10n.appearanceTitle,
        children: [
          const SizedBox(height: 16),
          // --- 1. Mesh Gradient Hero ---
          _MeshHero(scheme: scheme),
          const SizedBox(height: 28),
          // --- 2. Theme Mode Cards ---
          _ThemeModeSelector(
            settings: settings,
            onThemeModeChanged: (mode) {
              ref.read(uiSettingsProvider.notifier).setThemeMode(mode);
            },
          ),
          const SizedBox(height: 28),
          // --- 3. Dynamic Color + Settings ---
          SettingsSection(
            title: context.l10n.appearanceAccentPalette,
            children: [
              SettingsSwitchTile(
                icon: Icons.wallpaper_rounded,
                title: context.l10n.appearanceSystemColors,
                subtitle: context.l10n.appearanceSystemColorsSubtitle,
                value: settings.useSystemDynamic,
                onChanged: (v) {
                  ref.read(uiSettingsProvider.notifier).setUseSystemDynamic(v);
                },
              ),
              SettingsSwitchTile(
                icon: Icons.dock_rounded,
                title: context.l10n.appearanceFloatingNav,
                subtitle: context.l10n.appearanceFloatingNavSubtitle,
                value: settings.navBarFloating,
                onChanged: (v) {
                  ref.read(uiSettingsProvider.notifier).setNavBarFloating(v);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // --- 4. Wallpaper Chips or Palette Grid ---
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
          child: settings.useSystemDynamic
              ? _WallpaperChips(scheme: scheme)
              : _PaletteGrid(
                  settings: settings,
                  onColorSelected: (color) {
                    ref.read(uiSettingsProvider.notifier).setSeedColor(color);
                  },
                ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// 1. Mesh Gradient Hero — interactive touch-reactive
class _MeshHero extends StatefulWidget {
  const _MeshHero({required this.scheme});
  final ColorScheme scheme;

  @override
  State<_MeshHero> createState() => _MeshHeroState();
}

class _MeshHeroState extends State<_MeshHero> {
  Offset _touchPoint = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: SizedBox(
          height: 220,
          child: ExcludeSemantics(
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _touchPoint = details.localPosition;
                });
              },
              child: Stack(
                children: <Widget>[
                  AnimatedMeshGradient(
                    colors: [
                      widget.scheme.primary,
                      widget.scheme.tertiary,
                      widget.scheme.secondary,
                      widget.scheme.surfaceContainerHighest,
                    ],
                    options: AnimatedMeshGradientOptions(
                      frequency: 3,
                      amplitude: 20,
                      speed: 1.5,
                      grain: 0.06,
                    ),
                  ),
                  if (_touchPoint != Offset.zero)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          builder: (_, value, __) {
                            return CustomPaint(
                              painter: _TouchRipplePainter(
                                center: _touchPoint,
                                progress: value,
                                color: widget.scheme.onPrimary,
                              ),
                            );
                          },
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

class _TouchRipplePainter extends CustomPainter {
  const _TouchRipplePainter({
    required this.center,
    required this.progress,
    required this.color,
  });

  final Offset center;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = progress * 80;
    final paint = Paint()
      ..color = color.withValues(alpha: (1 - progress) * 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_TouchRipplePainter old) =>
      center != old.center || progress != old.progress;
}

// 2. Theme Mode Cards
class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({
    required this.settings,
    required this.onThemeModeChanged,
  });
  final UiSettingsState settings;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _ThemeModeCard(
              icon: Icons.light_mode_rounded,
              label: context.l10n.commonLight,
              isSelected: settings.themeMode == ThemeMode.light,
              bgColor: scheme.surface,
              fgColor: scheme.onSurface,
              onTap: () => onThemeModeChanged(ThemeMode.light),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ThemeModeCard(
              icon: Icons.dark_mode_rounded,
              label: context.l10n.commonDark,
              isSelected: settings.themeMode == ThemeMode.dark,
              bgColor: const Color(0xFF1D1B20),
              fgColor: const Color(0xFFE6E1E5),
              onTap: () => onThemeModeChanged(ThemeMode.dark),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ThemeModeCard(
              icon: Icons.brightness_auto_rounded,
              label: context.l10n.commonSystem,
              isSelected: settings.themeMode == ThemeMode.system,
              bgColor: scheme.surfaceContainerHighest,
              fgColor: scheme.onSurfaceVariant,
              onTap: () => onThemeModeChanged(ThemeMode.system),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeCard extends StatelessWidget {
  const _ThemeModeCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.bgColor,
    required this.fgColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final Color bgColor;
  final Color fgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      selected: isSelected,
      button: true,
      label: label,
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      height: 76,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
          child: Transform.scale(
            scale: isSelected ? 1.0 : 0.97,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: isSelected ? scheme.primary : fgColor, size: 24),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: isSelected ? scheme.primary : fgColor,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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

// 3. Palette Grid
class _PaletteGrid extends StatelessWidget {
  const _PaletteGrid({required this.settings, required this.onColorSelected});
  final UiSettingsState settings;
  final ValueChanged<Color> onColorSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 16,
        children: _ThemePaletteData.entries.map((entry) {
          final isSelected = entry.value.color.value == settings.seedColor.value;
          return ActiveColorOrb(
            color: entry.value.color,
            selected: isSelected,
            label: entry.value.nameKey,
            onTap: () => onColorSelected(entry.value.color),
          );
        }).toList(),
      ),
    );
  }
}

// 4. Wallpaper Chips
class _WallpaperChips extends StatelessWidget {
  const _WallpaperChips({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final colors = [
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      scheme.error,
      scheme.surfaceContainerHighest,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wallpaper_rounded, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                context.l10n.appearanceWallpaperColors,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors.map((c) {
              return CircleAvatar(
                radius: 12,
                backgroundColor: c,
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.appearanceWallpaperColorsSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
