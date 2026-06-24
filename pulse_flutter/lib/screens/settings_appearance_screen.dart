import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SettingsAppearanceScreen extends ConsumerWidget {
  const SettingsAppearanceScreen({super.key});

  static const List<Color> _seedOptions = <Color>[
    Color(0xFF6750A4),
    Color(0xFF005E8A),
    Color(0xFF1F6B45),
    Color(0xFF9B4E00),
    Color(0xFF8C3A63),
    Color(0xFF2F6FED),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    void tap(VoidCallback cb) {
      ref.read(appSoundProvider).playUiTick();
      if (settings.haptics) HapticFeedback.selectionClick();
      cb();
    }

    return SettingsScaffold(
      title: context.l10n.appearanceTitle,
      children: <Widget>[
        SettingsNavBanner(
          icon: Icons.palette_rounded,
          title: context.l10n.appearanceTitle,
          subtitle: context.l10n.appearanceStudioSubtitle,
          iconColor: Colors.purple,
        ),

        // --- Новый компактный редактор тем ---
        _ThemeEditorCard(
          settings: settings,
          scheme: scheme,
          textTheme: textTheme,
          onSeedSelected: (Color color) {
            tap(() => ref.read(uiSettingsProvider.notifier).setSeedColor(color));
          },
          onVariantSelected: (Md3Variant variant) {
            tap(() => ref.read(uiSettingsProvider.notifier).setVariant(variant));
          },
        ),
        const SizedBox(height: 16),

        // --- Взаимодействие (Компактный список) ---
        SettingsSection(
          title: context.l10n.appearanceInteraction,
          children: <Widget>[
            // Выбор темы (Системная / Светлая / Темная) через Dropdown-Tile
            Builder(
              builder: (BuildContext context) {
                return SettingsTile(
                  icon: Icons.brightness_medium_rounded,
                  title: context.l10n.appearanceThemeMode,
                  subtitle: _themeModeLabel(context, settings.themeMode),
                  trailing: Icon(
                    Icons.arrow_drop_down_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                  onTap: () async {
                    final RenderBox button = context.findRenderObject() as RenderBox;
                    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
                    final RelativeRect position = RelativeRect.fromRect(
                      Rect.fromPoints(
                        button.localToGlobal(Offset.zero, ancestor: overlay),
                        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
                      ),
                      Offset.zero & overlay.size,
                    );
                    final ThemeMode? selectedMode = await showMenu<ThemeMode>(
                      context: context,
                      position: position,
                      items: <PopupMenuEntry<ThemeMode>>[
                        PopupMenuItem<ThemeMode>(
                          value: ThemeMode.system,
                          child: Text(context.l10n.commonSystem),
                        ),
                        PopupMenuItem<ThemeMode>(
                          value: ThemeMode.light,
                          child: Text(context.l10n.commonLight),
                        ),
                        PopupMenuItem<ThemeMode>(
                          value: ThemeMode.dark,
                          child: Text(context.l10n.commonDark),
                        ),
                      ],
                    );
                    if (selectedMode != null) {
                      tap(() => ref.read(uiSettingsProvider.notifier).setThemeMode(selectedMode));
                    }
                  },
                );
              },
            ),
            SettingsTile(
              icon: Icons.language_rounded,
              title: context.l10n.appearanceLanguageRegion,
              subtitle: context.l10n.appearanceLanguageRegionSubtitle,
              iconColor: Colors.teal,
              onTap: () => context.push('/settings/language-region'),
            ),
            SettingsSwitchTile(
              icon: Icons.compress_rounded,
              title: context.l10n.appearanceCompactMode,
              subtitle: context.l10n.appearanceCompactModeSubtitle,
              iconColor: Colors.blueGrey,
              value: settings.compactMode,
              onChanged: (bool v) =>
                  tap(() => ref.read(uiSettingsProvider.notifier).setCompactMode(v)),
            ),
            SettingsSwitchTile(
              icon: Icons.speed_rounded,
              title: context.l10n.appearanceOptimizeWeakDevices,
              subtitle: context.l10n.appearanceOptimizeWeakDevicesSubtitle,
              iconColor: Colors.orange,
              value: settings.optimizeForWeakDevices,
              onChanged: (bool v) => tap(
                () => ref
                    .read(uiSettingsProvider.notifier)
                    .setOptimizeForWeakDevices(v),
              ),
            ),
            SettingsSwitchTile(
              icon: Icons.touch_app_rounded,
              title: context.l10n.profileHaptics,
              subtitle: context.l10n.appearanceHapticsSubtitle,
              iconColor: Colors.purple,
              value: settings.haptics,
              onChanged: (bool v) =>
                  tap(() => ref.read(uiSettingsProvider.notifier).setHaptics(v)),
            ),
            SettingsSwitchTile(
              icon: Icons.volume_up_rounded,
              title: context.l10n.appearanceSoundEffects,
              subtitle: context.l10n.appearanceSoundEffectsSubtitle,
              iconColor: Colors.green,
              value: settings.soundEffects,
              onChanged: (bool v) {
                if (settings.haptics) HapticFeedback.selectionClick();
                ref.read(uiSettingsProvider.notifier).setSoundEffects(v);
                ref.read(appSoundProvider).setEnabled(v);
                if (v) ref.read(appSoundProvider).playUiTick();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Вспомогательные функции ────────────────────────────────────────────────

String _themeModeLabel(BuildContext context, ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => context.l10n.commonSystem,
    ThemeMode.light => context.l10n.commonLight,
    ThemeMode.dark => context.l10n.commonDark,
  };
}

String _variantLabel(BuildContext context, Md3Variant variant) {
  return switch (variant) {
    Md3Variant.tonalSpot => context.l10n.appearanceVariantTonalSpot,
    Md3Variant.vibrant => context.l10n.appearanceVariantVibrant,
    Md3Variant.expressive => context.l10n.appearanceVariantExpressive,
    Md3Variant.neutral => context.l10n.appearanceVariantNeutral,
    Md3Variant.monochrome => context.l10n.appearanceVariantMonochrome,
    Md3Variant.fidelity => context.l10n.appearanceVariantFidelity,
  };
}

// ─── Виджеты ────────────────────────────────────────────────────────────────

class _ThemeEditorCard extends StatefulWidget {
  const _ThemeEditorCard({
    required this.settings,
    required this.scheme,
    required this.textTheme,
    required this.onSeedSelected,
    required this.onVariantSelected,
  });

  final UiSettingsState settings;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final ValueChanged<Color> onSeedSelected;
  final ValueChanged<Md3Variant> onVariantSelected;

  @override
  State<_ThemeEditorCard> createState() => _ThemeEditorCardState();
}

class _ThemeEditorCardState extends State<_ThemeEditorCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Декоративный PageView с контекстами приложения (Чат / Канал / Профиль)
            SizedBox(
              height: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (int page) {
                    setState(() => _currentPage = page);
                  },
                  children: <Widget>[
                    // Слайд 0: Превью Чата
                    _buildPreviewBackground(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildPreviewHeader(
                            icon: Icons.person_rounded,
                            title: 'SH20FK',
                          ),
                          const Spacer(),
                          _buildBubble(
                            text: context.l10n.appearanceIncomingPreview,
                            isMine: false,
                          ),
                          const SizedBox(height: 6),
                          _buildBubble(
                            text: context.l10n.appearanceAccentPreview,
                            isMine: true,
                          ),
                        ],
                      ),
                    ),
                    // Слайд 1: Превью Новостей/Канала
                    _buildPreviewBackground(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildPreviewHeader(
                            icon: Icons.campaign_rounded,
                            title: 'NiosMess News',
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: widget.scheme.surfaceContainerHigh.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Оформление M3 Expressive',
                                  style: widget.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: widget.scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Новые индикаторы и плавные переходы уже доступны в этой версии!',
                                  style: widget.textTheme.bodySmall?.copyWith(
                                    color: widget.scheme.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Слайд 2: Превью Профиля
                    _buildPreviewBackground(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: widget.scheme.primaryContainer,
                            foregroundColor: widget.scheme.onPrimaryContainer,
                            child: const Text('S', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'SH20FK',
                            style: widget.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: widget.scheme.onSurface,
                            ),
                          ),
                          Text(
                            '@sh20fk',
                            style: widget.textTheme.bodySmall?.copyWith(
                              color: widget.scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Индикаторы страниц (Dots)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (int index) {
                final bool active = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 16 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? widget.scheme.primary
                        : widget.scheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),
            // Сплит-круги выбора цветов акцента
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: SettingsAppearanceScreen._seedOptions.map((Color option) {
                final bool selected =
                    option.toARGB32() == widget.settings.seedColor.toARGB32();
                return _SwatchCircle(
                  color: option,
                  selected: selected,
                  onTap: () => widget.onSeedSelected(option),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            // Горизонтальный скролл вариантов стилей Material 3
            _VariantChipsRow(
              selectedVariant: widget.settings.variant,
              onSelected: widget.onVariantSelected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewBackground({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient(widget.scheme),
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }

  Widget _buildPreviewHeader({required IconData icon, required String title}) {
    return Row(
      children: <Widget>[
        Icon(Icons.arrow_back_rounded, color: widget.scheme.onSurface, size: 18),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 11,
          backgroundColor: widget.scheme.primary.withValues(alpha: 0.18),
          child: Icon(icon, size: 12, color: widget.scheme.primary),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: widget.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: widget.scheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildBubble({required String text, required bool isMine}) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(
          color: isMine
              ? widget.scheme.primary
              : widget.scheme.surfaceContainerHighest.withValues(alpha: 0.85),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMine ? 12 : 3),
            bottomRight: Radius.circular(isMine ? 3 : 12),
          ),
        ),
        child: Text(
          text,
          style: widget.textTheme.bodySmall?.copyWith(
            color: isMine ? widget.scheme.onPrimary : widget.scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _SwatchCircle extends StatelessWidget {
  const _SwatchCircle({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme currentScheme = Theme.of(context).colorScheme;

    final ColorScheme seedScheme = ColorScheme.fromSeed(
      seedColor: color,
      brightness: Theme.of(context).brightness,
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? currentScheme.primary : Colors.transparent,
            width: 2.5,
          ),
        ),
        padding: const EdgeInsets.all(3.5),
        child: ClipOval(
          child: Row(
            children: <Widget>[
              Expanded(child: Container(color: seedScheme.primary)),
              Expanded(child: Container(color: seedScheme.primaryContainer)),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariantChipsRow extends StatelessWidget {
  const _VariantChipsRow({
    required this.selectedVariant,
    required this.onSelected,
  });

  final Md3Variant selectedVariant;
  final ValueChanged<Md3Variant> onSelected;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: Md3Variant.values.map((Md3Variant variant) {
          final bool selected = variant == selectedVariant;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              visualDensity: VisualDensity.compact,
              label: Text(_variantLabel(context, variant)),
              selected: selected,
              onSelected: (_) => onSelected(variant),
              labelStyle: textTheme.labelMedium?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
