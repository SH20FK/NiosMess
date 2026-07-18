import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/active_color_orb.dart';

class SettingsAppearanceScreen extends StatelessWidget {
  const SettingsAppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VaffuruThemeSettingsScreen();
  }
}

enum _ThemePaletteId {
  amethyst, lagoon, meadow, ember, orchid, slate, sky, rose,
}

const Map<_ThemePaletteId, Color> _appPalettes = <_ThemePaletteId, Color>{
  _ThemePaletteId.amethyst: Color(0xFF6750A4),
  _ThemePaletteId.lagoon: Color(0xFF006C5B),
  _ThemePaletteId.meadow: Color(0xFF4C662B),
  _ThemePaletteId.ember: Color(0xFF984061),
  _ThemePaletteId.orchid: Color(0xFF825500),
  _ThemePaletteId.slate: Color(0xFF0061A4),
  _ThemePaletteId.sky: Color(0xFF006874),
  _ThemePaletteId.rose: Color(0xFF476810),
};

class VaffuruThemeSettingsScreen extends ConsumerStatefulWidget {
  const VaffuruThemeSettingsScreen({super.key});

  @override
  ConsumerState<VaffuruThemeSettingsScreen> createState() =>
      _VaffuruThemeSettingsScreenState();
}

class _VaffuruThemeSettingsScreenState extends ConsumerState<VaffuruThemeSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SettingsScaffold(
      title: context.l10n.appearanceTitle,
      children: <Widget>[
        // --- 1. MD3 Ultra-Expressive Hero ---
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _MD3ColorHero(scheme: scheme),
        ),
        const SizedBox(height: 24),

        // --- 2. Theme Mode SegmentedButton ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<ThemeMode>(
            segments: <ButtonSegment<ThemeMode>>[
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                icon: const Icon(Icons.brightness_auto_rounded),
                label: Text(context.l10n.commonSystem),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                icon: const Icon(Icons.light_mode_rounded),
                label: Text(context.l10n.commonLight),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                icon: const Icon(Icons.dark_mode_rounded),
                label: Text(context.l10n.commonDark),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (Set<ThemeMode> newSelection) {
              ref.read(uiSettingsProvider.notifier).setThemeMode(newSelection.first);
            },
          ),
        ),
        const SizedBox(height: 24),

        // --- 3. Dynamic Color Toggle ---
        SettingsSection(
          title: context.l10n.appearanceAccentPalette,
          children: [
            SettingsSwitchTile(
              icon: Icons.wallpaper_rounded,
              title: context.l10n.appearanceSystemColors,
              subtitle: context.l10n.appearanceSystemColorsSubtitle,
              value: settings.useSystemDynamic,
              onChanged: (bool value) {
                ref.read(uiSettingsProvider.notifier).setUseSystemDynamic(value);
              },
            ),
            SettingsSwitchTile(
              icon: Icons.dock_rounded,
              title: 'Плавающая навигация', // fallback if l10n is tricky
              subtitle: 'Открепить нижнюю панель от края экрана',
              value: settings.navBarFloating,
              onChanged: (bool value) {
                ref.read(uiSettingsProvider.notifier).setNavBarFloating(value);
              },
            ),
          ],
        ),

        // --- 4. Color Palette Grid ---
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: settings.useSystemDynamic
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                    ),
                    itemCount: _appPalettes.length,
                    itemBuilder: (BuildContext context, int index) {
                      final MapEntry<_ThemePaletteId, Color> entry =
                          _appPalettes.entries.elementAt(index);
                      final bool isSelected =
                          entry.value.value == settings.seedColor.value;
                      return ActiveColorOrb(
                        color: entry.value,
                        selected: isSelected,
                        onTap: () {
                          ref
                              .read(uiSettingsProvider.notifier)
                              .setSeedColor(entry.value);
                        },
                      );
                    },
                  ),
                ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _MD3ColorHero extends StatelessWidget {
  const _MD3ColorHero({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(32),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background abstract shape 1 (Primary)
          Positioned(
            top: -40,
            left: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Background abstract shape 2 (Tertiary)
          Positioned(
            bottom: -60,
            right: -20,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          // Foreground UI Pill
          Positioned(
            top: 40,
            right: 20,
            child: Container(
              width: 120,
              height: 48,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 60,
                height: 8,
                decoration: BoxDecoration(
                  color: scheme.onPrimaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          // Floating FAB
          Positioned(
            bottom: 30,
            left: 30,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.color_lens_rounded,
                color: scheme.onSecondaryContainer,
                size: 32,
              ),
            ),
          ),
          // Error dot
          Positioned(
            top: 60,
            left: 100,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: scheme.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
