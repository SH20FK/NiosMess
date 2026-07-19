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

class _PaletteEntry {
  const _PaletteEntry(this.color, this.name);
  final Color color;
  final String name;
}

const _palettes = <_PaletteEntry>[
  _PaletteEntry(Color(0xFF6750A4), 'Amethyst'),
  _PaletteEntry(Color(0xFF006C5B), 'Lagoon'),
  _PaletteEntry(Color(0xFF4C662B), 'Meadow'),
  _PaletteEntry(Color(0xFFB3261E), 'Ember'),
  _PaletteEntry(Color(0xFF7D5260), 'Orchid'),
  _PaletteEntry(Color(0xFF475569), 'Slate'),
  _PaletteEntry(Color(0xFF006874), 'Sky'),
  _PaletteEntry(Color(0xFF984061), 'Rose'),
];

class _AppearanceScreen extends ConsumerWidget {
  const _AppearanceScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(uiSettingsProvider);
    final brightness = Theme.of(context).brightness;
    final targetTheme = AppTheme.themed(settings, brightness);

    return TweenAnimationBuilder<ThemeData>(
      tween: ThemeDataTween(begin: targetTheme, end: targetTheme),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
      builder: (_, animatedTheme, _) {
        return Theme(
          data: animatedTheme,
          child: _buildContent(context, ref, settings, animatedTheme.colorScheme),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    UiSettingsState settings,
    ColorScheme scheme,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.12),
            scheme.surface,
          ],
        ),
      ),
      child: SettingsScaffold(
        title: context.l10n.appearanceTitle,
        children: [
          const SizedBox(height: 16),

          // Mesh hero + orbs in one block
          _MeshWithOrbs(
            scheme: scheme,
            settings: settings,
            onColorSelected: (color) {
              ref.read(uiSettingsProvider.notifier).setSeedColor(color);
            },
          ),

          const SizedBox(height: 24),

          // Theme mode cards
          _ThemeModeSelector(
            settings: settings,
            onThemeModeChanged: (mode) {
              ref.read(uiSettingsProvider.notifier).setThemeMode(mode);
            },
          ),

          const SizedBox(height: 24),

          // Settings switches
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

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// Mesh hero + horizontal scrollable orbs
class _MeshWithOrbs extends StatelessWidget {
  const _MeshWithOrbs({
    required this.scheme,
    required this.settings,
    required this.onColorSelected,
  });

  final ColorScheme scheme;
  final UiSettingsState settings;
  final ValueChanged<Color> onColorSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Mesh gradient hero with fallback
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              height: 200,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          scheme.primary.withValues(alpha: 0.30),
                          scheme.tertiary.withValues(alpha: 0.20),
                          scheme.secondary.withValues(alpha: 0.20),
                          scheme.surfaceContainerHighest,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  ExcludeSemantics(
                    child: AnimatedMeshGradient(
                      colors: [
                        scheme.primary,
                        scheme.tertiary,
                        scheme.secondary,
                        scheme.surfaceContainerHighest,
                      ],
                      options: AnimatedMeshGradientOptions(
                        frequency: 3,
                        amplitude: 20,
                        speed: 1.5,
                        grain: 0.06,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Horizontal scrollable color orbs
          if (!settings.useSystemDynamic)
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: _palettes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (_, index) {
                  final entry = _palettes[index];
                  final isSelected = entry.color.toARGB32() == settings.seedColor.toARGB32();
                  return ActiveColorOrb(
                    color: entry.color,
                    selected: isSelected,
                    label: entry.name,
                    onTap: () => onColorSelected(entry.color),
                  );
                },
              ),
            ),

          // Wallpaper chips when dynamic color is on
          if (settings.useSystemDynamic)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
            ),
        ],
      ),
    );
  }
}

// Theme mode cards
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
    final darkScheme = ColorScheme.fromSeed(
      seedColor: settings.seedColor,
      brightness: Brightness.dark,
    );

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
              bgColor: darkScheme.surface,
              fgColor: darkScheme.onSurface,
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
