import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/providers/notification_preferences_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
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
    final AppFontScale fontScale = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.fontScale),
    );
    final PaletteStyle paletteStyle = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.paletteStyle),
    );

    final Brightness brightness = Theme.of(context).brightness;

    return DynamicColorBuilder(
      // dynamic_color 1.x still uses package:flutter/material.dart types; only
      // the seed Color crosses into the material_ui theme.
      builder: (lightDynamic, darkDynamic) {
        final Color? dynamicSeed = brightness == Brightness.light
            ? lightDynamic?.primary
            : darkDynamic?.primary;
        final ThemeData targetTheme = useSystemDynamic
            ? AppTheme.themed(
                visualTheme,
                brightness,
                dynamicSeed: dynamicSeed,
              )
            : ref.watch(_appearanceThemeProvider(brightness));

        return ValueListenableBuilder<bool>(
          valueListenable: CircularThemeSwitcher.revealing,
          builder: (context, revealing, _) => AnimatedTheme(
            data: targetTheme,
            // Under a circular reveal the theme switches at once: the
            // snapshot of the old theme already carries the transition.
            duration: context.reduceMotion || revealing
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
                fontScale: fontScale,
                paletteStyle: paletteStyle,
                useSystemDynamic: useSystemDynamic,
              ),
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
    required AppFontScale fontScale,
    required PaletteStyle paletteStyle,
    required bool useSystemDynamic,
  }) {
    final Widget colorField = SettingsAnchor(
      id: 'appearance.color.source',
      child: NiosColorField(
        scheme: scheme,
        seedColor: seedColor,
        useSystemDynamic: useSystemDynamic,
        paletteStyle: paletteStyle,
        onColorSelected: (Color color, Offset origin) {
          _revealChange(
            context,
            origin,
            () => ref.read(uiSettingsProvider.notifier).setSeedColor(color),
          );
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
        _revealChange(
          context,
          tapOffset,
          () => ref.read(uiSettingsProvider.notifier).setThemeMode(newMode),
        );
      },
    );

    final Widget wallpaperSection = SettingsSection(
      children: [
        SettingsAnchor(
          id: 'appearance.wallpaper',
          child: SettingsListItem.nav(
            key: const ValueKey('settings-wallpaper-entry'),
            icon: Icons.texture_rounded,
            leading: const _WallpaperThumbnail(),
            title: context.l10n.appearanceChatWallpaperTitle,
            subtitle: context.l10n.settingsWallpaperEntryHint,
            onTap: () => openSettingsPage(context, '/settings/wallpaper'),
          ),
        ),
      ],
    );

    final Widget textAndShapeSection = SettingsSection(
      title: context.l10n.settingsV2TextShape,
      accentIcon: Icons.format_size_rounded,
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
        SettingsSearchDisclosure(
          anchor: 'ui_corner_radius',
          title: context.l10n.settingsV2Advanced,
          subtitle: context.l10n.settingsV2GeometryHint,
          children: [
            _SliderSettingTile(
              icon: Icons.rounded_corner_rounded,
              title: context.l10n.appearanceUiRounding,
              subtitle: context.l10n.appearanceUiRoundingDesc,
              value: ref.watch(
                uiSettingsProvider.select((s) => s.uiCornerRadius),
              ),
              min: 8.0,
              max: 28.0,
              divisions: 20,
              // The corners follow the thumb, so the page and the preview
              // round while it is dragged instead of after it is released.
              onChanged: (double val) {
                ref.read(uiSettingsProvider.notifier).setUiCornerRadius(val);
              },
            ),
          ],
        ),
        SettingsAnchor(
          id: 'appearance.compact',
          child: SettingsListItem.toggle(
            icon: Icons.density_small_rounded,
            title: context.l10n.appearanceCompactMode,
            subtitle: context.l10n.appearanceCompactModeSubtitle,
            value: ref.watch(uiSettingsProvider.select((s) => s.compactMode)),
            onChanged: (value) =>
                ref.read(uiSettingsProvider.notifier).setCompactMode(value),
          ),
        ),
      ],
    );

    final Widget resetSection = SettingsSection(
      title: context.l10n.settingsV2ResetSection,
      accentIcon: Icons.restart_alt_rounded,
      accentColor: scheme.errorContainer,
      accentForeground: scheme.onErrorContainer,
      children: [
        SettingsListItem.danger(
          key: const ValueKey('settings-appearance-reset-action'),
          icon: Icons.restart_alt_rounded,
          title: context.l10n.settingsV2Reset,
          subtitle: context.l10n.settingsV2ResetHint,
          onTap: () => _resetPreferences(context, ref),
        ),
      ],
    );

    return SettingsShell(
      title: context.l10n.settingsV2Appearance,
      isEmbedded: isEmbedded,
      hero: _AppearanceHeroPreview(themeMode: themeMode),
      children: [
        themeCard,
        colorField,
        wallpaperSection,
        textAndShapeSection,
        resetSection,
      ],
    );
  }

  // Theme and accent change the same way: the new look opens in a circle
  // from the control that was touched, so the selection mark and the colours
  // arrive together. The controls give their own feedback. A change made
  // while a reveal is still running lands at once under it, because the
  // switcher would otherwise drop it.
  void _revealChange(BuildContext context, Offset origin, VoidCallback apply) {
    final switcher = CircularThemeSwitcher.maybeOf(context);
    if (switcher == null || CircularThemeSwitcher.revealing.value) {
      apply();
      return;
    }
    switcher.toggleTheme(apply, tapOffset: origin, haptic: false);
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

  /// The one reset the app already offers, reached from the page that shows
  /// what it changes: confirm, write, report. No second reset path.
  Future<void> _resetPreferences(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: context.l10n.settingsV2ResetConfirm,
      subtitle: context.l10n.settingsV2ResetBody,
      confirmLabel: context.l10n.settingsV2Reset,
      cancelLabel: context.l10n.commonCancel,
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final int leftover =
          await ref.read(uiSettingsProvider.notifier).resetAll();
      // Notification categories live under their own per-account key.
      await ref.read(notificationPreferencesProvider.notifier).reset();
      if (context.mounted) {
        if (leftover > 0) {
          AppToast.showInfo(context, context.l10n.settingsStorageResetPartial);
        } else {
          AppToast.showSuccess(context, context.l10n.settingsV2ResetDone);
        }
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.showError(context, context.l10n.settingsV2ResetFailed);
      }
    }
  }
}

/// The live preview above the settings: two bubbles and a composer drawn from
/// the colours, corners and text scale that are in force right now. It reads
/// the animated theme, so a change lands in it before the page is released:
/// the seed and the palette style recolor it, `uiCornerRadius` rounds it, and
/// light/dark follows `themeMode`. Text size needs no second multiplier: the
/// app-wide `AppTextScaler` already carries the `fontScale` setting into every
/// `MediaQuery`, so the preview grows by exactly the same factor as the page.
class _AppearanceHeroPreview extends StatelessWidget {
  const _AppearanceHeroPreview({required this.themeMode});

  final ThemeMode themeMode;

  String _modeLabel(BuildContext context) => switch (themeMode) {
    ThemeMode.system => context.l10n.commonSystem,
    ThemeMode.light => context.l10n.appearanceLabelLight,
    ThemeMode.dark => context.l10n.appearanceLabelDark,
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final double radius = AppRadii.of(context).lg.clamp(12.0, 24.0);
    final Radius big = Radius.circular(radius);
    final Radius tail = Radius.circular((radius * .45).clamp(4.0, 12.0));

    Widget bubble({
      required String message,
      required bool outgoing,
    }) {
      final Color fill = outgoing
          ? scheme.primary
          : scheme.surfaceContainerHigh;
      final Color ink = outgoing ? scheme.onPrimary : scheme.onSurface;
      return Row(
        mainAxisAlignment: outgoing
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: <Widget>[
          Flexible(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: fill,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: big,
                    topRight: big,
                    // The tail sits at the reading start of an incoming
                    // bubble and at the reading end of an outgoing one.
                    bottomLeft: outgoing
                        ? (rtl ? tail : big)
                        : (rtl ? big : tail),
                    bottomRight: outgoing
                        ? (rtl ? big : tail)
                        : (rtl ? tail : big),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  message,
                  style: text.bodyMedium?.copyWith(color: ink),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SettingsHeroCard(
      label: context.l10n.appearancePreviewTitle,
      leadingIcon: Icons.forum_rounded,
      trailing: DecoratedBox(
        decoration: ShapeDecoration(
          color: scheme.secondaryContainer,
          shape: RoundedSuperellipseBorder(
            borderRadius: AppRadii.of(context).fullRadius,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 2,
            vertical: 3,
          ),
          child: Text(
            _modeLabel(context),
            style: text.labelSmall?.copyWith(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          bubble(
            message: context.l10n.appearanceIncomingPreview,
            outgoing: false,
          ),
          const SizedBox(height: AppSpacing.sm),
          bubble(
            message: context.l10n.appearancePreviewChat,
            outgoing: true,
          ),
          const SizedBox(height: AppSpacing.md),
          DecoratedBox(
            decoration: ShapeDecoration(
              color: scheme.surfaceContainerHigh,
              shape: RoundedSuperellipseBorder(
                borderRadius: AppRadii.of(context).fullRadius,
              ),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: AppSpacing.lg,
                end: AppSpacing.xs,
                top: AppSpacing.xs,
                bottom: AppSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      context.l10n.chatMessageHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      color: scheme.primary,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: AppRadii.of(context).fullRadius,
                      ),
                    ),
                    child: SizedBox.square(
                      dimension: AppHeights.controlCompact,
                      child: Center(
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          size: 20,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small tonal stand-in for the current chat wallpaper: the row says what
/// the studio opens, the swatch says there is something to open.
class _WallpaperThumbnail extends StatelessWidget {
  const _WallpaperThumbnail();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: AppHeights.sm,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              scheme.primary,
              scheme.tertiaryContainer,
              scheme.secondaryContainer,
            ],
          ),
          shape: AppRadii.superellipse(AppRadii.of(context).md),
        ),
      ),
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

  /// A ready-made accent was picked. [origin] is the centre of its swatch on
  /// screen, the point the new colours open from.
  final void Function(Color color, Offset origin) onColorSelected;
  final VoidCallback onCustomColorTap;
  final ValueChanged<bool> onToggleDynamic;
  final ValueChanged<PaletteStyle> onSelectPaletteStyle;

  @override
  Widget build(BuildContext context) {
    final customSelected =
        !useSystemDynamic &&
        !_palettes.any((p) => p.color.toARGB32() == seedColor.toARGB32());
    return SettingsSection(
      title: context.l10n.appearanceAccentPalette,
      subtitle: context.l10n.appearanceAccentPaletteSubtitle,
      accentIcon: Icons.palette_rounded,
      children: [
        if (!kIsWeb)
          SettingsListItem.toggle(
            icon: Icons.wallpaper_rounded,
            title: context.l10n.appearanceSystemColors,
            subtitle: context.l10n.appearanceSystemColorsSubtitle,
            value: useSystemDynamic,
            onChanged: onToggleDynamic,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            0,
          ),
          child: _PaletteGrid(
            choices: [
              for (final entry in _palettes)
                _PaletteChoice(
                  key: ValueKey<String>('appearance-palette-${entry.color.toARGB32()}'),
                  scheme: scheme,
                  seedColor: entry.color,
                  paletteStyle: paletteStyle,
                  label: entry.getName(context.l10n),
                  selected:
                      !useSystemDynamic &&
                      seedColor.toARGB32() == entry.color.toARGB32(),
                  onTap: (Offset origin) {
                    // The accent already in use: nothing to change or reveal.
                    if (!useSystemDynamic &&
                        seedColor.toARGB32() == entry.color.toARGB32()) {
                      return;
                    }
                    HapticService.selection();
                    onColorSelected(entry.color, origin);
                    onToggleDynamic(false);
                  },
                ),
              _PaletteChoice(
                key: const ValueKey<String>('appearance-palette-custom'),
                scheme: scheme,
                seedColor: seedColor,
                paletteStyle: paletteStyle,
                label: context.l10n.appearanceCustomColor,
                selected: customSelected,
                custom: true,
                onTap: (_) => onCustomColorTap(),
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

/// Every accent at once. The pager showed three and hid the rest behind a
/// swipe that the code itself admitted was hard to discover; a grid shows the
/// whole palette in one look and still fits a 320 dp window at 200 % text,
/// because the labels live in the tooltips.
class _PaletteGrid extends StatelessWidget {
  const _PaletteGrid({required this.choices});

  final List<_PaletteChoice> choices;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final double available = constraints.maxWidth;
      final int columns = (available / 64).floor().clamp(4, 9);
      // Each swatch carries a 3 dp ring on every side, so the cell has to
      // give that back before the tile is sized; otherwise a full row would
      // wrap one tile onto a second line.
      final double cell = (available - AppSpacing.md * (columns - 1)) / columns;
      final double size = (cell - 6).clamp(30.0, 58.0);
      return Wrap(
        key: const ValueKey('appearance-palette-strip'),
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          for (final choice in choices) choice.copyWithSize(size),
        ],
      );
    },
  );
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
    this.size = 56,
    super.key,
  });

  final ColorScheme scheme;
  final Color seedColor;
  final PaletteStyle paletteStyle;
  final String label;
  final bool selected;
  final bool custom;
  final double size;

  /// Called with the centre of the swatch in screen coordinates.
  final ValueChanged<Offset> onTap;

  _PaletteChoice copyWithSize(double size) => _PaletteChoice(
    key: key,
    scheme: scheme,
    seedColor: seedColor,
    paletteStyle: paletteStyle,
    label: label,
    selected: selected,
    custom: custom,
    onTap: onTap,
    size: size,
  );

  @override
  State<_PaletteChoice> createState() => _PaletteChoiceState();
}

class _PaletteChoiceState extends State<_PaletteChoice> {
  late ColorScheme preview;
  ColorScheme get scheme => widget.scheme;
  String get label => widget.label;
  bool get selected => widget.selected;
  bool get custom => widget.custom;

  void onTap() {
    final box = context.findRenderObject() as RenderBox?;
    widget.onTap(
      box != null && box.hasSize
          ? box.localToGlobal(box.size.center(Offset.zero))
          : Offset.zero,
    );
  }

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
  Widget build(BuildContext context) {
    final Color fill = custom ? scheme.surfaceContainerHigh : preview.primary;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: PressableSurface(
          onTap: onTap,
          // The reveal already answers the tap; a second click would double it.
          playFeedback: false,
          borderRadius: AppRadii.of(context).lgRadius,
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: context.motionDuration(M3Durations.short4),
            curve: M3SpringCurves.spatialFast,
            padding: const EdgeInsets.all(3),
            decoration: ShapeDecoration(
              shape: RoundedSuperellipseBorder(
                borderRadius: AppRadii.of(context).lgRadius,
                side: BorderSide(
                  color: selected
                      ? scheme.primary
                      : custom
                      ? scheme.outlineVariant
                      : Colors.transparent,
                  width: selected ? 2 : 1,
                ),
              ),
            ),
            child: M3Container(
              Shapes.square,
              width: widget.size,
              height: widget.size,
              color: fill,
              child: custom
                  ? Center(
                      child: Icon(
                        selected ? Icons.check_rounded : Icons.add_rounded,
                        size: widget.size * .4,
                        color: custom && selected
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        // Four roles of the palette: enough to tell two
                        // variants of the same seed apart at a glance.
                        Column(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                children: <Widget>[
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
                                children: <Widget>[
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
                        if (selected)
                          Center(
                            child: DecoratedBox(
                              decoration: ShapeDecoration(
                                color: scheme.surfaceContainerLowest,
                                shape: RoundedSuperellipseBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: widget.size * .28,
                                  color: scheme.primary,
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
    );
  }
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
    accentIcon: Icons.contrast_rounded,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
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
      SettingsListItem.value(
        icon: widget.icon,
        title: widget.title,
        subtitle: widget.subtitle,
        value: '${_localValue.toInt()} dp',
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(trackHeight: 16),
          child: Slider(
            value: _localValue.clamp(widget.min, widget.max),
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            label: '${_localValue.toInt()} dp',
            onChangeStart: (_) => setState(() => _isDragging = true),
            onChangeEnd: (_) => setState(() => _isDragging = false),
            onChanged: (value) {
              setState(() => _localValue = value);
              // Applied while dragging: the corners of the page and of the
              // preview move with the thumb.
              widget.onChanged(value);
            },
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
      SettingsListItem.value(
        icon: Icons.format_size_rounded,
        title: context.l10n.appearanceTextScale,
        subtitle: context.l10n.appearanceTextScaleDesc,
        value: '${(currentScale.scale * 100).round()}%',
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SettingsChoiceButtons<AppFontScale>(
          segments: [
            for (final scale in AppFontScale.values)
              ButtonSegment<AppFontScale>(
                value: scale,
                label: Text('${(scale.scale * 100).round()}%'),
              ),
          ],
          selected: {currentScale},
          onSelectionChanged: (selected) => onChanged(selected.first),
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
      SettingsListItem.value(
        icon: Icons.palette_outlined,
        title: context.l10n.appearancePaletteStyle,
        subtitle: context.l10n.appearanceContrastColorsDesc,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SettingsChoiceButtons<PaletteStyle>(
          segments: [
            for (final style in PaletteStyle.values)
              ButtonSegment<PaletteStyle>(
                value: style,
                label: Text(_labelFor(context, style)),
              ),
          ],
          selected: {currentStyle},
          onSelectionChanged: (selected) => onChanged(selected.first),
        ),
      ),
    ],
  );
}
