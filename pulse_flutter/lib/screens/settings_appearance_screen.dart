import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
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

const _ThemePaletteData = <_ThemePaletteId, Color>{
  _ThemePaletteId.amethyst: Color(0xFF6750A4),
  _ThemePaletteId.lagoon: Color(0xFF006C5B),
  _ThemePaletteId.meadow: Color(0xFF4C662B),
  _ThemePaletteId.ember: Color(0xFF984061),
  _ThemePaletteId.orchid: Color(0xFF825500),
  _ThemePaletteId.slate: Color(0xFF0061A4),
  _ThemePaletteId.sky: Color(0xFF006874),
  _ThemePaletteId.rose: Color(0xFF476810),
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
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final theme = Theme.of(context);
    final prevTheme = _prevTheme ?? theme;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_prevTheme != theme) {
        setState(() {
          _prevTheme = theme;
        });
      }
    });

    return TweenAnimationBuilder<ThemeData>(
      tween: ThemeDataTween(begin: prevTheme, end: theme),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
      builder: (_, animatedTheme, __) {
        return Theme(
          data: animatedTheme,
          child: _buildContent(settings, scheme, textTheme),
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
          _ThemeModeSelector(settings: settings),
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
                title: 'Плавающая навигация',
                subtitle: 'Открепить нижнюю панель от края экрана',
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
                    scheme: scheme,
                  ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// 1. Mesh Gradient Hero
// ──────────────────────────────────────────
class _MeshHero extends StatelessWidget {
  const _MeshHero({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: SizedBox(
          height: 220,
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
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// 2. Theme Mode Cards
// ──────────────────────────────────────────
class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({required this.settings});
  final UiSettingsState settings;

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
              mode: ThemeMode.light,
              icon: Icons.light_mode_rounded,
              label: context.l10n.commonLight,
              isSelected: settings.themeMode == ThemeMode.light,
              bgColor: scheme.surface,
              fgColor: scheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ThemeModeCard(
              mode: ThemeMode.dark,
              icon: Icons.dark_mode_rounded,
              label: context.l10n.commonDark,
              isSelected: settings.themeMode == ThemeMode.dark,
              bgColor: const Color(0xFF1D1B20),
              fgColor: const Color(0xFFE6E1E5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ThemeModeCard(
              mode: ThemeMode.system,
              icon: Icons.brightness_auto_rounded,
              label: context.l10n.commonSystem,
              isSelected: settings.themeMode == ThemeMode.system,
              bgColor: scheme.surfaceContainerHighest,
              fgColor: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeCard extends StatelessWidget {
  const _ThemeModeCard({
    required this.mode,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.bgColor,
    required this.fgColor,
  });

  final ThemeMode mode;
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color bgColor;
  final Color fgColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedContainer(
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
          onTap: () {
            context
                .read(uiSettingsProvider.notifier)
                .setThemeMode(mode);
          },
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
    );
  }
}

// ──────────────────────────────────────────
// 3. Palette Grid
// ──────────────────────────────────────────
class _PaletteGrid extends StatelessWidget {
  const _PaletteGrid({required this.settings, required this.scheme});
  final UiSettingsState settings;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: _ThemePaletteData.length,
        itemBuilder: (_, index) {
          final entry = _ThemePaletteData.entries.elementAt(index);
          final isSelected = entry.value.value == settings.seedColor.value;
          return ActiveColorOrb(
            color: entry.value,
            selected: isSelected,
            onTap: () {
              context
                  .read(uiSettingsProvider.notifier)
                  .setSeedColor(entry.value);
            },
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────
// 4. Wallpaper Chips
// ──────────────────────────────────────────
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
                'Цвета из обоев',
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
            'Обновляются автоматически при смене обоев',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
