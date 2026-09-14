import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';
import 'package:pulse_flutter/providers/chat_wallpaper_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/wallpaper/chat_wallpaper_painter.dart';
import 'package:pulse_flutter/widgets/wallpaper/icon_sources_catalog.dart';
import 'package:pulse_flutter/widgets/wallpaper/cupertino_icons_data.dart';
import 'package:pulse_flutter/widgets/wallpaper/material_symbols_data.dart';
import 'package:pulse_flutter/widgets/wallpaper/wallpaper_color_resolver.dart';
import 'package:pulse_flutter/widgets/wallpaper/wallpaper_image_cache.dart';

class SettingsWallpaperScreen extends ConsumerStatefulWidget {
  const SettingsWallpaperScreen({
    this.chatId,
    this.chatTitle,
    this.isEmbedded = false,
    super.key,
  });

  final String? chatId;
  final String? chatTitle;
  final bool isEmbedded;

  @override
  ConsumerState<SettingsWallpaperScreen> createState() =>
      _SettingsWallpaperScreenState();
}

class _SettingsWallpaperScreenState
    extends ConsumerState<SettingsWallpaperScreen>
    with SingleTickerProviderStateMixin {
  late ChatWallpaperConfig _config;
  Timer? _debounceSaveTimer;
  ui.Picture? _previewSvgPicture;
  List<ui.Picture>? _previewPoolSvgPictures;
  bool _dependenciesInitialized = false;
  Color? _lastLoadedIconColor;
  bool _showChatMockup = false;

  late AnimationController _diceAnimController;
  late Animation<double> _diceRotationAnimation;

  @override
  void initState() {
    super.initState();
    final ChatWallpaperState wallpaperState = ref.read(chatWallpaperProvider);
    _config = wallpaperState.forChat(widget.chatId);

    _diceAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _diceRotationAnimation = CurvedAnimation(
      parent: _diceAnimController,
      curve: M3SpringCurves.bouncy,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color currentIconColor = WallpaperColorResolver.resolveIconColor(
      scheme,
      _config.iconColorRole,
      _config.iconAlpha,
    );
    if (!_dependenciesInitialized || _lastLoadedIconColor != currentIconColor) {
      _dependenciesInitialized = true;
      _lastLoadedIconColor = currentIconColor;
      _loadSvgPreviewIfNeeded();
    }
  }

  @override
  void dispose() {
    _debounceSaveTimer?.cancel();
    _diceAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadSvgPreviewIfNeeded() async {
    if (!mounted) return;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color iconColor = WallpaperColorResolver.resolveIconColor(
      scheme,
      _config.iconColorRole,
      _config.iconAlpha,
    );
    _lastLoadedIconColor = iconColor;

    if (_config.iconSource == IconSource.lucide ||
        _config.iconSource == IconSource.tabler) {
      final String folder =
          _config.iconSource == IconSource.lucide ? 'lucide' : 'tabler';

      List<String> iconsToLoad = <String>[];
      if (_config.themePack != 'all' && _config.themePack != 'custom') {
        iconsToLoad = IconSourcesCatalog.getThemePackIcons(
          _config.themePack,
          source: _config.iconSource,
        );
      } else if (_config.themePack == 'custom' &&
          _config.selectedGlyphs.isNotEmpty) {
        iconsToLoad = _config.selectedGlyphs;
      } else if (_config.useAllIcons || _config.themePack == 'all') {
        final List<String> catalog = _config.iconSource == IconSource.lucide
            ? IconSourcesCatalog.lucideIcons
            : IconSourcesCatalog.tablerIcons;
        final Random rng = Random(_config.seed);
        final int count = min(28, catalog.length);
        for (int i = 0; i < count; i++) {
          iconsToLoad.add(catalog[rng.nextInt(catalog.length)]);
        }
      }

      if (iconsToLoad.isNotEmpty) {
        final List<ui.Picture?> results = await Future.wait(
          iconsToLoad.map(
            (name) => WallpaperImageCache.loadPatternSvg(
              assetPath: 'assets/svg/pattern_icons/$folder/$name.svg',
              color: iconColor,
              filled: _config.filled,
            ),
          ),
        );
        final List<ui.Picture> pool = results.whereType<ui.Picture>().toList();
        if (mounted) {
          setState(() {
            _previewPoolSvgPictures = pool;
            _previewSvgPicture = null;
          });
        }
        return;
      }

      if (_config.svgAssetPath != null && _config.svgAssetPath!.isNotEmpty) {
        final ui.Picture? pic = await WallpaperImageCache.loadPatternSvg(
          assetPath: _config.svgAssetPath!,
          color: iconColor,
          filled: _config.filled,
        );
        if (mounted) {
          setState(() {
            _previewSvgPicture = pic;
            _previewPoolSvgPictures = null;
          });
        }
      }
    } else {
      if (_previewSvgPicture != null || _previewPoolSvgPictures != null) {
        setState(() {
          _previewSvgPicture = null;
          _previewPoolSvgPictures = null;
        });
      }
    }
  }

  void _updateConfig(ChatWallpaperConfig newConfig,
      {bool immediateSave = false}) {
    final bool needsSvgReload =
        newConfig.iconSource != _config.iconSource ||
        newConfig.themePack != _config.themePack ||
        newConfig.selectedGlyphs != _config.selectedGlyphs ||
        newConfig.svgAssetPath != _config.svgAssetPath ||
        newConfig.seed != _config.seed ||
        newConfig.filled != _config.filled ||
        newConfig.useAllIcons != _config.useAllIcons;

    final bool alphaOrColorChanged =
        newConfig.iconAlpha != _config.iconAlpha ||
        newConfig.iconColorRole != _config.iconColorRole;

    setState(() {
      _config = newConfig;
    });

    if (immediateSave) {
      _debounceSaveTimer?.cancel();
      _saveConfig(newConfig);
      if (alphaOrColorChanged && !needsSvgReload) {
        _loadSvgPreviewIfNeeded();
      }
    } else {
      _debounceSaveTimer?.cancel();
      _debounceSaveTimer = Timer(const Duration(milliseconds: 300), () {
        _saveConfig(newConfig);
        if (alphaOrColorChanged && !needsSvgReload) {
          _loadSvgPreviewIfNeeded();
        }
      });
    }

    if (needsSvgReload) {
      _loadSvgPreviewIfNeeded();
    }
  }

  void _saveConfig(ChatWallpaperConfig newConfig) {
    final notifier = ref.read(chatWallpaperProvider.notifier);
    if (widget.chatId != null) {
      notifier.setChatWallpaper(widget.chatId!, newConfig);
    } else {
      notifier.updateGlobalConfig(newConfig);
    }
  }

  Future<void> _resetConfig() async {
    HapticService.tap();
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Сбросить обои?',
      subtitle:
          'Все параметры раскладки, плотности и символов вернутся к значениям по умолчанию.',
      confirmLabel: 'Сбросить',
      cancelLabel: 'Отмена',
      icon: Icons.restart_alt_rounded,
      destructive: true,
    );

    if (confirmed == true && mounted) {
      _debounceSaveTimer?.cancel();
      final notifier = ref.read(chatWallpaperProvider.notifier);
      if (widget.chatId != null) {
        notifier.resetChatWallpaper(widget.chatId!);
        final globalConfig = ref.read(chatWallpaperProvider).global;
        setState(() {
          _config = globalConfig;
        });
      } else {
        notifier.resetAllToDefault();
        setState(() {
          _config = ChatWallpaperConfig.defaultPattern;
        });
      }
      _loadSvgPreviewIfNeeded();
    }
  }

  void _randomizeConfigWithSpin() {
    _diceAnimController.forward(from: 0.0);
    _randomizeConfig();
  }

  void _randomizeConfig() {
    HapticService.confirm();
    final Random rng = Random();
    const List<WallpaperLayoutMode> modes = WallpaperLayoutMode.values;
    const List<IconSource> sources = <IconSource>[
      IconSource.materialSymbols,
      IconSource.lucide,
      IconSource.tabler,
      IconSource.cupertino,
      IconSource.niosMess,
    ];
    const List<String> packs = <String>[
      'chat',
      'tech',
      'space',
      'food',
      'nature',
      'minimal',
    ];
    const List<WallpaperBackgroundStyle> bgStyles =
        WallpaperBackgroundStyle.values;
    const List<String> bgRoles = <String>[
      'surfaceContainerLowest',
      'surfaceContainerLow',
      'surfaceContainer',
      'surfaceContainerHigh',
      'primaryContainer',
      'secondaryContainer',
      'tertiaryContainer',
    ];

    final IconSource randomSource = sources[rng.nextInt(sources.length)];
    final WallpaperBackgroundStyle randomBg =
        bgStyles[rng.nextInt(bgStyles.length)];
    final String bgRole1 = bgRoles[rng.nextInt(bgRoles.length)];
    final String bgRole2 = bgRoles[rng.nextInt(bgRoles.length)];

    final ChatWallpaperConfig randomized = _config.copyWith(
      seed: rng.nextInt(100000),
      iconSource: randomSource,
      layoutMode: modes[rng.nextInt(modes.length)],
      cellSize: (44.0 + rng.nextInt(18) * 4.0).toDouble(),
      density: (0.50 + rng.nextInt(10) * 0.05).clamp(0.4, 0.95),
      gridAngle: (rng.nextInt(13) * 5.0 - 30.0).toDouble(),
      randomRotationDeg: (rng.nextInt(8) * 5.0).toDouble(),
      randomScaleJitter: (rng.nextInt(6) * 0.05).toDouble(),
      themePack: packs[rng.nextInt(packs.length)],
      useAllIcons: rng.nextBool(),
      filled: rng.nextBool(),
      backgroundStyle: randomBg,
      backgroundRole: bgRole1,
      backgroundSecondaryRole: bgRole2,
      gradientAngle: (rng.nextInt(8) * 45.0).toDouble(),
    );

    _updateConfig(randomized, immediateSave: true);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String screenTitle = widget.chatId != null
        ? 'Обои чата: ${widget.chatTitle ?? widget.chatId}'
        : 'Фон чатов';

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= 840;

        if (isWide) {
          return SettingsShell(
            title: screenTitle,
            isEmbedded: widget.isEmbedded,
            maxWidth: 1120,
            children: <Widget>[
              const SizedBox(height: 10),
              _buildPresetsCarousel(scheme, textTheme),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _buildPreviewCard(scheme, textTheme, height: 280),
                        const SizedBox(height: 16),
                        _buildActionButtons(scheme),
                        const SizedBox(height: 16),
                        _buildColorSection(scheme, textTheme),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _buildLayoutSelector(scheme, textTheme),
                        const SizedBox(height: 16),
                        _buildPacksAndSourceSection(scheme, textTheme),
                        const SizedBox(height: 16),
                        _buildGeometrySection(scheme, textTheme),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
            ],
          );
        }

        return SettingsShell(
          title: screenTitle,
          isEmbedded: widget.isEmbedded,
          maxWidth: 860,
          children: <Widget>[
            _buildPresetsCarousel(scheme, textTheme),
            const SizedBox(height: 14),
            _buildPreviewCard(scheme, textTheme, height: 230),
            const SizedBox(height: 14),
            _buildLayoutSelector(scheme, textTheme),
            const SizedBox(height: 14),
            _buildPacksAndSourceSection(scheme, textTheme),
            const SizedBox(height: 14),
            _buildGeometrySection(scheme, textTheme),
            const SizedBox(height: 14),
            _buildColorSection(scheme, textTheme),
            const SizedBox(height: 20),
            _buildActionButtons(scheme),
            const SizedBox(height: 36),
          ],
        );
      },
    );
  }

  Widget _buildPresetsCarousel(ColorScheme scheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Готовые стили (1-тап)',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 104,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: kDefaultWallpaperPresets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (BuildContext context, int index) {
              final ChatWallpaperPreset preset =
                  kDefaultWallpaperPresets[index];
              final bool isSelected = _config.seed == preset.config.seed &&
                  _config.iconSource == preset.config.iconSource &&
                  _config.themePack == preset.config.themePack &&
                  _config.backgroundStyle == preset.config.backgroundStyle;

              return InkWell(
                onTap: () {
                  HapticService.tap();
                  _updateConfig(preset.config, immediateSave: true);
                },
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: M3SpringCurves.spatial,
                  width: 130,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primaryContainer.withValues(alpha: 0.75)
                        : scheme.surfaceContainerHigh.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? scheme.primary
                          : scheme.outlineVariant.withValues(alpha: 0.25),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.22),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? scheme.primary
                                  : scheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              preset.icon,
                              size: 16,
                              color: isSelected
                                  ? scheme.onPrimary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: scheme.primary,
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        preset.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preset.description,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected
                              ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                              : scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChatMockupOverlay(ColorScheme scheme) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 240),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh.withValues(alpha: 0.94),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                      bottomLeft: Radius.circular(4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Привет! Как тебе новый фон? 👀',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          '10:42',
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                scheme.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 250),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Выглядит просто космически! 🔥',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: scheme.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '10:43',
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.onPrimary.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.done_all_rounded,
                            size: 14,
                            color: scheme.onPrimary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 220),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh.withValues(alpha: 0.94),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                      bottomLeft: Radius.circular(4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'И текст читается идеально ✨',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          '10:43',
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                scheme.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme scheme) {
    return _WallpaperActionButtons(
      diceRotationAnimation: _diceRotationAnimation,
      onRandomize: _randomizeConfigWithSpin,
      onReset: _resetConfig,
    );
  }

  // ── 1. Live Interactive Preview Card (Clean wallpaper canvas) ──────────────
  Widget _buildPreviewCard(ColorScheme scheme, TextTheme textTheme, {double height = 220}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: _randomizeConfigWithSpin,
      child: Container(
        height: height,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Stack(
              children: <Widget>[
                // Clean Wallpaper Canvas
                Positioned.fill(
                  child: CustomPaint(
                    painter: ChatWallpaperPainter(
                      config: _config,
                      scheme: scheme,
                      svgPicture: _previewSvgPicture,
                      poolSvgPictures: _previewPoolSvgPictures,
                    ),
                  ),
                ),

                // Live Chat Mockup Overlay
                if (_showChatMockup) _buildChatMockupOverlay(scheme),

                // Subtle edge fade gradient overlay
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            scheme.surface.withValues(alpha: 0.28),
                            Colors.transparent,
                            Colors.transparent,
                            scheme.surface.withValues(alpha: 0.36),
                          ],
                          stops: const [0.0, 0.20, 0.78, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                // Top Left: Floating Layout Badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getLayoutIcon(_config.layoutMode),
                          size: 15,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_getLayoutLabel(_config.layoutMode)} • ${_config.cellSize.toInt()} dp',
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Top Right: Actions (Mockup Toggle + Fullscreen)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: _showChatMockup ? 'Скрыть чат' : 'Примерка чата',
                        child: Material(
                          color: _showChatMockup
                              ? scheme.primary
                              : scheme.surface.withValues(alpha: 0.88),
                          shape: const CircleBorder(),
                          elevation: 1,
                          child: InkWell(
                            onTap: () {
                              HapticService.tap();
                              setState(() {
                                _showChatMockup = !_showChatMockup;
                              });
                            },
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(
                                _showChatMockup
                                    ? Icons.chat_rounded
                                    : Icons.chat_bubble_outline_rounded,
                                size: 17,
                                color: _showChatMockup
                                    ? scheme.onPrimary
                                    : scheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: () => _openFullScreenPreview(context, scheme),
                        icon: const Icon(Icons.fullscreen_rounded, size: 16),
                        label: const Text('Примерить',
                            style: TextStyle(fontSize: 12)),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: const Size(0, 34),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Left: Double-tap Hint Badge
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_rounded,
                            size: 13, color: scheme.primary),
                        const SizedBox(width: 5),
                        Text(
                          '2x тап для генерации ✨',
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Right: Quick Dice Spin Button
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Tooltip(
                    message: 'Случайный узор',
                    child: Material(
                      color: scheme.surface.withValues(alpha: 0.90),
                      shape: const CircleBorder(),
                      elevation: 2,
                      shadowColor: scheme.shadow.withValues(alpha: 0.2),
                      child: InkWell(
                        onTap: _randomizeConfigWithSpin,
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(9.0),
                          child: RotationTransition(
                            turns: _diceRotationAnimation,
                            child: Icon(
                              Icons.casino_rounded,
                              size: 19,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
          ),
        ),
      ),
    );
  }

  // ── Full-Screen Interactive Preview (Clean canvas, no chat bubbles) ─────────
  void _openFullScreenPreview(BuildContext context, ColorScheme scheme) {
    HapticService.tap();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (BuildContext ctx) {
          return StatefulBuilder(
            builder: (BuildContext innerCtx, StateSetter setModalState) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Примерка обоев'),
                  leading: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(innerCtx).pop(),
                  ),
                  actions: <Widget>[
                    IconButton(
                      icon: Icon(
                        _showChatMockup
                            ? Icons.chat_rounded
                            : Icons.chat_bubble_outline_rounded,
                        color: _showChatMockup ? scheme.primary : null,
                      ),
                      tooltip: _showChatMockup ? 'Скрыть чат' : 'Примерка чата',
                      onPressed: () {
                        HapticService.tap();
                        setModalState(() {
                          _showChatMockup = !_showChatMockup;
                        });
                        setState(() {});
                      },
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(innerCtx).pop();
                        _saveConfig(_config);
                      },
                      child: const Text('Готово',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                body: Stack(
                  children: <Widget>[
                    // Clean Fullscreen Canvas
                    Positioned.fill(
                      child: CustomPaint(
                        painter: ChatWallpaperPainter(
                          config: _config,
                          scheme: scheme,
                          svgPicture: _previewSvgPicture,
                          poolSvgPictures: _previewPoolSvgPictures,
                        ),
                      ),
                    ),

                    // Live Chat Mockup Overlay
                    if (_showChatMockup) _buildChatMockupOverlay(scheme),

                    // Bottom Floating Information Capsule with Quick Randomize
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 32,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest
                              .withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                scheme.outlineVariant.withValues(alpha: 0.35),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.shadow.withValues(alpha: 0.15),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getLayoutIcon(_config.layoutMode),
                                color: scheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Раскладка: ${_getLayoutLabel(_config.layoutMode)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Размер: ${_config.cellSize.toInt()} dp • Плотность: ${(_config.density * 100).toInt()}%',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () {
                                _randomizeConfig();
                                setModalState(() {});
                              },
                              icon: const Icon(Icons.casino_rounded, size: 16),
                              label: const Text('Случайный',
                                  style: TextStyle(fontSize: 12)),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                minimumSize: const Size(0, 36),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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
            },
          );
        },
      ),
    );
  }

  // ── 2. Layout Mode Selector (Expressive Cards) ─────────────────────────────
  Widget _buildLayoutSelector(ColorScheme scheme, TextTheme textTheme) {
    const List<({WallpaperLayoutMode mode, String label, IconData icon})>
        modes = [
      (
        mode: WallpaperLayoutMode.stagger,
        label: 'Шахматы',
        icon: Icons.grid_view_rounded,
      ),
      (
        mode: WallpaperLayoutMode.grid,
        label: 'Сетка',
        icon: Icons.grid_on_rounded,
      ),
      (
        mode: WallpaperLayoutMode.hex,
        label: 'Соты',
        icon: Icons.hexagon_outlined,
      ),
      (
        mode: WallpaperLayoutMode.spiral,
        label: 'Спираль',
        icon: Icons.cyclone_rounded,
      ),
      (
        mode: WallpaperLayoutMode.scatter,
        label: 'Хаос',
        icon: Icons.bubble_chart_rounded,
      ),
    ];

    return SettingsSection(
      title: 'Раскладка сетки',
      subtitle: 'Геометрический алгоритм расположения элементов узора',
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            children: modes.map((m) {
              final bool isSelected = _config.layoutMode == m.mode;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _LayoutModeCard(
                    mode: m.mode,
                    label: m.label,
                    icon: m.icon,
                    isSelected: isSelected,
                    scheme: scheme,
                    onTap: () {
                      HapticService.tap();
                      _updateConfig(
                        _config.copyWith(layoutMode: m.mode),
                        immediateSave: true,
                      );
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── 3. Theme Packs & Icon Source ──────────────────────────────────────────
  Widget _buildPacksAndSourceSection(ColorScheme scheme, TextTheme textTheme) {
    const List<({String key, String label, IconData icon})> packs = [
      (key: 'all', label: 'Все', icon: Icons.all_inclusive_rounded),
      (key: 'chat', label: 'Чат', icon: Icons.chat_bubble_outline_rounded),
      (key: 'tech', label: 'IT & Код', icon: Icons.terminal_rounded),
      (key: 'space', label: 'Космос', icon: Icons.rocket_launch_outlined),
      (key: 'food', label: 'Еда', icon: Icons.coffee_rounded),
      (key: 'nature', label: 'Природа', icon: Icons.eco_outlined),
      (key: 'minimal', label: 'Минимал', icon: Icons.interests_outlined),
      (key: 'custom', label: 'Свой выбор', icon: Icons.tune_rounded),
    ];

    final int customCount = _config.selectedGlyphs.length;

    return SettingsSection(
      title: 'Символы и паки',
      subtitle: 'Библиотека векторных символов и тематические коллекции',
      children: <Widget>[
        // Icon Sources Expressive Pill Selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <({
                IconSource source,
                String label,
                String count,
                IconData icon
              })>[
                (
                  source: IconSource.materialSymbols,
                  label: 'Material',
                  count: '4.2k',
                  icon: Icons.layers_rounded,
                ),
                (
                  source: IconSource.lucide,
                  label: 'Lucide',
                  count: '1.8k',
                  icon: Icons.auto_fix_high_rounded,
                ),
                (
                  source: IconSource.tabler,
                  label: 'Tabler',
                  count: '5.1k',
                  icon: Icons.widgets_rounded,
                ),
                (
                  source: IconSource.cupertino,
                  label: 'Cupertino',
                  count: '1.3k',
                  icon: Icons.apple_rounded,
                ),
                (
                  source: IconSource.niosMess,
                  label: 'Формы M3',
                  count: 'Шейпы',
                  icon: Icons.interests_rounded,
                ),
              ].map((s) {
                final bool isSelected = _config.iconSource == s.source;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    selected: isSelected,
                    showCheckmark: false,
                    avatar: Icon(
                      s.icon,
                      size: 15,
                      color: isSelected ? scheme.onPrimary : scheme.primary,
                    ),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          s.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? scheme.onPrimary : null,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? scheme.onPrimary.withValues(alpha: 0.22)
                                : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s.count,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? scheme.onPrimary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (_) {
                      HapticService.tap();
                      _updateConfig(
                        _config.copyWith(iconSource: s.source),
                        immediateSave: true,
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Packs Chips
        if (_config.iconSource != IconSource.niosMess) ...<Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: packs.map((p) {
                final bool isSelected = _config.themePack == p.key;
                String chipLabel = p.label;
                if (p.key == 'custom' && customCount > 0) {
                  chipLabel = 'Свой ($customCount)';
                }

                return ChoiceChip(
                  selected: isSelected,
                  label: Text(chipLabel, style: const TextStyle(fontSize: 12)),
                  avatar: Icon(p.icon, size: 14),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (bool sel) {
                    HapticService.tap();
                    if (p.key == 'custom') {
                      _updateConfig(_config.copyWith(themePack: 'custom'),
                          immediateSave: true);
                      _openCustomGlyphPicker(context, scheme);
                    } else {
                      _updateConfig(
                        _config.copyWith(
                          themePack: p.key,
                          useAllIcons: p.key == 'all',
                        ),
                        immediateSave: true,
                      );
                    }
                  },
                );
              }).toList(),
            ),
          ),
          if (_config.themePack == 'custom')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: OutlinedButton.icon(
                onPressed: () => _openCustomGlyphPicker(context, scheme),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: Text(
                  customCount > 0
                      ? 'Изменить набор ($customCount выбрано)'
                      : 'Выбрать иконки для набора',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  // ── Custom Glyph Picker Modal Sheet ───────────────────────────────────────
  void _openCustomGlyphPicker(BuildContext context, ColorScheme scheme) {
    HapticService.tap();
    final List<String> catalog = switch (_config.iconSource) {
      IconSource.lucide => IconSourcesCatalog.lucideIcons,
      IconSource.tabler => IconSourcesCatalog.tablerIcons,
      IconSource.cupertino => CupertinoIconsData.allNames,
      _ => MaterialSymbolsData.allNames,
    };

    final Set<String> selected = Set<String>.from(_config.selectedGlyphs);
    String filterQuery = '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext sheetCtx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            final List<String> matches = filterQuery.isEmpty
                ? catalog.take(90).toList()
                : catalog
                    .where((s) => s.toLowerCase().contains(filterQuery))
                    .take(90)
                    .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (_, ScrollController scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: <Widget>[
                      const SizedBox(height: 12),
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            'Свой набор (${selected.length} / 12)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              _updateConfig(
                                _config.copyWith(
                                  selectedGlyphs: selected.toList(),
                                  themePack: 'custom',
                                ),
                                immediateSave: true,
                              );
                              Navigator.of(sheetCtx).pop();
                            },
                            child: const Text('Сохранить',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Поиск символа...',
                          prefixIcon:
                              const Icon(Icons.search_rounded, size: 20),
                          filled: true,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (String q) {
                          setModalState(() {
                            filterQuery = q.trim().toLowerCase();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: GridView.builder(
                          controller: scrollController,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 1.0,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: matches.length,
                          itemBuilder: (BuildContext _, int idx) {
                            final String name = matches[idx];
                            final bool isChecked = selected.contains(name);

                            return InkWell(
                              onTap: () {
                                HapticService.selection();
                                setModalState(() {
                                  if (isChecked) {
                                    selected.remove(name);
                                  } else {
                                    if (selected.length < 12) {
                                      selected.add(name);
                                    }
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: M3SpringCurves.spatial,
                                decoration: BoxDecoration(
                                  color: isChecked
                                      ? scheme.primary.withValues(alpha: 0.16)
                                      : scheme.surfaceContainerHigh
                                          .withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isChecked
                                        ? scheme.primary
                                        : scheme.outlineVariant
                                            .withValues(alpha: 0.2),
                                    width: isChecked ? 2.0 : 1.0,
                                  ),
                                ),
                                child: Stack(
                                  children: <Widget>[
                                    Center(
                                      child:
                                          _renderMiniThumbnail(name, scheme),
                                    ),
                                    if (isChecked)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Icon(
                                          Icons.check_circle_rounded,
                                          size: 16,
                                          color: scheme.primary,
                                        ),
                                      ),
                                    Positioned(
                                      bottom: 4,
                                      left: 4,
                                      right: 4,
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: isChecked
                                              ? scheme.primary
                                              : scheme.onSurfaceVariant,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _renderMiniThumbnail(String name, ColorScheme scheme) {
    if (_config.iconSource == IconSource.materialSymbols) {
      final int code = MaterialSymbolsData.codepoints[name] ?? 0xe838;
      final String fontFamily = _resolveFontFamily(_config.symbolsStyle);
      return Text(
        String.fromCharCode(code),
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: 22,
          color: scheme.primary,
        ),
      );
    } else if (_config.iconSource == IconSource.cupertino) {
      final int code =
          CupertinoIconsData.resolveCodepoint(name, filled: _config.filled);
      return Text(
        String.fromCharCode(code),
        style: TextStyle(
          fontFamily: 'packages/cupertino_icons/CupertinoIcons',
          fontSize: 22,
          color: scheme.primary,
        ),
      );
    } else if (_config.iconSource == IconSource.lucide ||
        _config.iconSource == IconSource.tabler) {
      final String folder =
          _config.iconSource == IconSource.lucide ? 'lucide' : 'tabler';
      return SvgPicture.asset(
        'assets/svg/pattern_icons/$folder/$name.svg',
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(scheme.primary, BlendMode.srcIn),
      );
    }
    return Icon(Icons.star_rounded, size: 20, color: scheme.primary);
  }

  // ── 4. Geometry & Dynamics ────────────────────────────────────────────────
  Widget _buildGeometrySection(ColorScheme scheme, TextTheme textTheme) {
    return SettingsSection(
      title: 'Геометрия и динамика',
      subtitle: 'Размер элементов, плотность покрытия и угол поворота',
      children: <Widget>[
        _buildSliderRow(
          title: 'Размер ячейки',
          value: _config.cellSize,
          min: 32.0,
          max: 128.0,
          divisions: 24,
          unit: 'dp',
          onChanged: (val) => _updateConfig(_config.copyWith(cellSize: val)),
        ),
        _buildSliderRow(
          title: 'Плотность покрытия',
          value: _config.density,
          min: 0.20,
          max: 1.0,
          divisions: 16,
          unit: '%',
          displayMultiplier: 100,
          onChanged: (val) => _updateConfig(_config.copyWith(density: val)),
        ),
        _buildSliderRow(
          title: 'Угол поворота сетки',
          value: _config.gridAngle,
          min: -45.0,
          max: 45.0,
          divisions: 36,
          unit: '°',
          onChanged: (val) => _updateConfig(_config.copyWith(gridAngle: val)),
        ),
        _buildSliderRow(
          title: 'Разброс угла иконки',
          value: _config.randomRotationDeg,
          min: 0.0,
          max: 90.0,
          divisions: 18,
          unit: '°',
          onChanged: (val) =>
              _updateConfig(_config.copyWith(randomRotationDeg: val)),
        ),
        _buildSliderRow(
          title: 'Разброс масштаба',
          value: _config.randomScaleJitter,
          min: 0.0,
          max: 0.5,
          divisions: 10,
          unit: '',
          onChanged: (val) =>
              _updateConfig(_config.copyWith(randomScaleJitter: val)),
        ),
        _buildSliderRow(
          title: 'Прозрачность',
          value: _config.iconAlpha,
          min: 0.04,
          max: 0.35,
          divisions: 31,
          unit: '',
          onChanged: (val) => _updateConfig(_config.copyWith(iconAlpha: val)),
        ),
        SettingsSwitchTile(
          icon: Icons.format_paint_rounded,
          title: 'Сплошная заливка (Filled)',
          subtitle: 'Сплошное заполнение контура символов',
          value: _config.filled,
          onChanged: (bool val) {
            HapticService.tap();
            _updateConfig(_config.copyWith(filled: val), immediateSave: true);
          },
        ),
      ],
    );
  }

  // ── 5. Colors and Background Style ────────────────────────────────────────
  Widget _buildColorSection(ColorScheme scheme, TextTheme textTheme) {
    return SettingsSection(
      title: 'Цвета и стиль фона',
      subtitle: 'Подложка, градиенты и режим окрашивания символов',
      children: <Widget>[
        // Background Style: Solid, Linear Gradient, Radial Glow
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: SegmentedButton<WallpaperBackgroundStyle>(
            segments: const <ButtonSegment<WallpaperBackgroundStyle>>[
              ButtonSegment<WallpaperBackgroundStyle>(
                value: WallpaperBackgroundStyle.solid,
                label: Text('Сплошной', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.square_rounded, size: 16),
              ),
              ButtonSegment<WallpaperBackgroundStyle>(
                value: WallpaperBackgroundStyle.linearGradient,
                label: Text('Градиент', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.gradient_rounded, size: 16),
              ),
              ButtonSegment<WallpaperBackgroundStyle>(
                value: WallpaperBackgroundStyle.radialGlow,
                label: Text('Свечение', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.lens_blur_rounded, size: 16),
              ),
            ],
            selected: <WallpaperBackgroundStyle>{_config.backgroundStyle},
            onSelectionChanged: (Set<WallpaperBackgroundStyle> val) {
              HapticService.tap();
              _updateConfig(
                _config.copyWith(backgroundStyle: val.first),
                immediateSave: true,
              );
            },
          ),
        ),

        // If Gradient or Radial Glow: secondary tone selector & angle slider
        if (_config.backgroundStyle != WallpaperBackgroundStyle.solid) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              _config.backgroundStyle == WallpaperBackgroundStyle.radialGlow
                  ? 'Внешний тон свечения:'
                  : 'Второй цвет градиента:',
              style: textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <({String role, String label})>[
                  (role: 'surfaceContainerLowest', label: 'Глубокий темный'),
                  (role: 'surfaceContainerLow', label: 'Мягкий фон'),
                  (role: 'surfaceContainerHigh', label: 'Контрастный'),
                  (role: 'primaryContainer', label: 'Основной акцент'),
                  (role: 'secondaryContainer', label: 'Вторичный'),
                  (role: 'tertiaryContainer', label: 'Теплый тон'),
                ].map((item) {
                  final bool isSelected =
                      _config.backgroundSecondaryRole == item.role;
                  final Color c = WallpaperColorResolver.resolveBackground(
                      scheme, item.role);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      selected: isSelected,
                      avatar: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: scheme.outlineVariant
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      label: Text(item.label,
                          style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      onSelected: (bool sel) {
                        if (sel) {
                          HapticService.tap();
                          _updateConfig(
                            _config.copyWith(
                                backgroundSecondaryRole: item.role),
                            immediateSave: true,
                          );
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          if (_config.backgroundStyle ==
              WallpaperBackgroundStyle.linearGradient)
            _buildSliderRow(
              title: 'Угол градиента',
              value: _config.gradientAngle,
              min: -180.0,
              max: 180.0,
              divisions: 24,
              unit: '°',
              onChanged: (val) =>
                  _updateConfig(_config.copyWith(gradientAngle: val)),
            ),
          const SizedBox(height: 6),
        ],

        // Icon coloring mode
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text(
            'Окрашивание символов:',
            style: textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: SegmentedButton<WallpaperColorMode>(
            segments: const <ButtonSegment<WallpaperColorMode>>[
              ButtonSegment<WallpaperColorMode>(
                value: WallpaperColorMode.singleTone,
                label: Text('Один цвет', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment<WallpaperColorMode>(
                value: WallpaperColorMode.tonalAccent,
                label: Text('Акценты', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment<WallpaperColorMode>(
                value: WallpaperColorMode.palette,
                label: Text('Палитра', style: TextStyle(fontSize: 12)),
              ),
            ],
            selected: <WallpaperColorMode>{_config.colorMode},
            onSelectionChanged: (Set<WallpaperColorMode> val) {
              HapticService.tap();
              _updateConfig(
                _config.copyWith(colorMode: val.first),
                immediateSave: true,
              );
            },
          ),
        ),

        // Live Color Preview Dots & Explanation
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: M3SpringCurves.spatial,
            switchOutCurve: Curves.easeOut,
            child:
                _buildColorModePreview(scheme, textTheme, _config.colorMode),
          ),
        ),
      ],
    );
  }

  Widget _buildColorModePreview(
      ColorScheme scheme, TextTheme textTheme, WallpaperColorMode mode) {
    final (List<Color> dots, String description) = switch (mode) {
      WallpaperColorMode.singleTone => (
          [scheme.primary],
          'Единый акцентный тон темы для спокойного, монохромного фона',
        ),
      WallpaperColorMode.tonalAccent => (
          [scheme.primary, scheme.tertiary],
          'Чередование основного и третичного тонов для выразительного ритма',
        ),
      WallpaperColorMode.palette => (
          [
            scheme.primary,
            scheme.secondary,
            scheme.tertiary,
            scheme.surfaceContainerHighest,
          ],
          'Полноцветный спектр темы для насыщенного, динамичного паттерна',
        ),
    };

    return Container(
      key: ValueKey<WallpaperColorMode>(mode),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: dots
                .map(
                  (c) => Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: c.withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── M3 Expressive Slider Row with Spring Badge Bounce ─────────────────────
  Widget _buildSliderRow({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    double displayMultiplier = 1.0,
    required ValueChanged<double> onChanged,
  }) {
    return _M3WallpaperSliderRow(
      title: title,
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      unit: unit,
      displayMultiplier: displayMultiplier,
      onChanged: onChanged,
    );
  }

  IconData _getLayoutIcon(WallpaperLayoutMode mode) {
    return switch (mode) {
      WallpaperLayoutMode.stagger => Icons.grid_view_rounded,
      WallpaperLayoutMode.grid => Icons.grid_on_rounded,
      WallpaperLayoutMode.hex => Icons.hexagon_outlined,
      WallpaperLayoutMode.spiral => Icons.cyclone_rounded,
      WallpaperLayoutMode.scatter => Icons.bubble_chart_rounded,
    };
  }

  String _getLayoutLabel(WallpaperLayoutMode mode) {
    return switch (mode) {
      WallpaperLayoutMode.stagger => 'Шахматы',
      WallpaperLayoutMode.grid => 'Сетка',
      WallpaperLayoutMode.hex => 'Соты',
      WallpaperLayoutMode.spiral => 'Спираль',
      WallpaperLayoutMode.scatter => 'Хаос',
    };
  }

  String _resolveFontFamily(MaterialSymbolsStyle style) {
    switch (style) {
      case MaterialSymbolsStyle.outlined:
        return 'MaterialSymbolsOutlined';
      case MaterialSymbolsStyle.rounded:
        return 'MaterialSymbolsRounded';
      case MaterialSymbolsStyle.sharp:
        return 'MaterialSymbolsSharp';
    }
  }
}

/// Action buttons for wallpaper randomize and reset with M3 bouncy spring press feedback
class _WallpaperActionButtons extends StatefulWidget {
  const _WallpaperActionButtons({
    required this.diceRotationAnimation,
    required this.onRandomize,
    required this.onReset,
  });

  final Animation<double> diceRotationAnimation;
  final VoidCallback onRandomize;
  final VoidCallback onReset;

  @override
  State<_WallpaperActionButtons> createState() =>
      _WallpaperActionButtonsState();
}

class _WallpaperActionButtonsState extends State<_WallpaperActionButtons> {
  bool _isRandomizePressed = false;
  bool _isResetPressed = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Listener(
            onPointerDown: (_) => setState(() => _isRandomizePressed = true),
            onPointerUp: (_) => setState(() => _isRandomizePressed = false),
            onPointerCancel: (_) => setState(() => _isRandomizePressed = false),
            child: AnimatedScale(
              scale: _isRandomizePressed ? 0.96 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: _isRandomizePressed
                  ? M3SpringCurves.snappy
                  : M3SpringCurves.bouncy,
              child: FilledButton.tonalIcon(
                onPressed: widget.onRandomize,
                icon: RotationTransition(
                  turns: widget.diceRotationAnimation,
                  child: const Icon(Icons.casino_rounded, size: 20),
                ),
                label: const Text('Случайный узор'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Listener(
            onPointerDown: (_) => setState(() => _isResetPressed = true),
            onPointerUp: (_) => setState(() => _isResetPressed = false),
            onPointerCancel: (_) => setState(() => _isResetPressed = false),
            child: AnimatedScale(
              scale: _isResetPressed ? 0.96 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: _isResetPressed
                  ? M3SpringCurves.snappy
                  : M3SpringCurves.bouncy,
              child: OutlinedButton.icon(
                onPressed: widget.onReset,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Сбросить'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Slider row with drag state expansion and M3 spring badge bounce
class _M3WallpaperSliderRow extends StatefulWidget {
  const _M3WallpaperSliderRow({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.unit,
    this.displayMultiplier = 1.0,
    required this.onChanged,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String unit;
  final double displayMultiplier;
  final ValueChanged<double> onChanged;

  @override
  State<_M3WallpaperSliderRow> createState() => _M3WallpaperSliderRowState();
}

class _M3WallpaperSliderRowState extends State<_M3WallpaperSliderRow> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final double displayVal = widget.value * widget.displayMultiplier;
    final String formatted = widget.unit == '%' || widget.unit == '°'
        ? '${displayVal.toStringAsFixed(0)}${widget.unit}'
        : '${displayVal.toStringAsFixed(widget.unit.isEmpty ? 2 : 0)} ${widget.unit}'.trim();
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          AnimatedScale(
            scale: _isDragging ? 1.14 : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: M3SpringCurves.bouncy,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _isDragging
                    ? scheme.primary.withValues(alpha: 0.22)
                    : scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
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
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: anim,
                    curve: M3SpringCurves.bouncy,
                  ),
                  child: child,
                ),
                child: Text(
                  formatted,
                  key: ValueKey<String>(formatted),
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: SliderTheme(
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
          ),
        ],
      ),
    );
  }
}

/// Expressive Layout Card with mini geometry preview and spring physics
class _LayoutModeCard extends StatefulWidget {
  const _LayoutModeCard({
    required this.mode,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.scheme,
    required this.onTap,
  });

  final WallpaperLayoutMode mode;
  final String label;
  final IconData icon;
  final bool isSelected;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  State<_LayoutModeCard> createState() => _LayoutModeCardState();
}

class _LayoutModeCardState extends State<_LayoutModeCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final isSelected = widget.isSelected;

    return Listener(
      onPointerDown: (_) => setState(() => _isPressed = true),
      onPointerUp: (_) => setState(() => _isPressed = false),
      onPointerCancel: (_) => setState(() => _isPressed = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.94 : (isSelected ? 1.04 : 1.0),
          duration: const Duration(milliseconds: 240),
          curve: M3SpringCurves.bouncy,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: M3SpringCurves.spatial,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? scheme.primaryContainer.withValues(alpha: 0.55)
                  : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? scheme.primary
                    : scheme.outlineVariant.withValues(alpha: 0.28),
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.16),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Visual Geometry Miniature
                SizedBox(
                  height: 30,
                  width: 30,
                  child: CustomPaint(
                    painter: _LayoutMiniaturePainter(
                      mode: widget.mode,
                      color: isSelected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      accentColor: scheme.tertiary,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                // Label
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? scheme.primary : scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                // Active Indicator Pill
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 3,
                  width: isSelected ? 12 : 0,
                  decoration: BoxDecoration(
                    color: isSelected ? scheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
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

/// Custom painter rendering a distinctive visual miniature of the geometric algorithm
class _LayoutMiniaturePainter extends CustomPainter {
  const _LayoutMiniaturePainter({
    required this.mode,
    required this.color,
    required this.accentColor,
  });

  final WallpaperLayoutMode mode;
  final Color color;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double w = size.width;
    final double h = size.height;
    final double r = w * 0.10;

    switch (mode) {
      case WallpaperLayoutMode.stagger:
        // Chess pattern: alternating offset rows
        canvas.drawCircle(Offset(w * 0.28, h * 0.28), r, paint);
        canvas.drawCircle(Offset(w * 0.72, h * 0.28), r, paint);
        canvas.drawCircle(Offset(w * 0.50, h * 0.72), r, paint);
        break;

      case WallpaperLayoutMode.grid:
        // Regular 2x2 grid
        canvas.drawCircle(Offset(w * 0.30, h * 0.30), r, paint);
        canvas.drawCircle(Offset(w * 0.70, h * 0.30), r, paint);
        canvas.drawCircle(Offset(w * 0.30, h * 0.70), r, paint);
        canvas.drawCircle(Offset(w * 0.70, h * 0.70), r, paint);
        break;

      case WallpaperLayoutMode.hex:
        // Hexagonal honeycomb (center dot + 5 surrounding)
        canvas.drawCircle(Offset(w * 0.50, h * 0.50), r * 1.1, paint);
        canvas.drawCircle(Offset(w * 0.50, h * 0.20), r * 0.9, paint);
        canvas.drawCircle(Offset(w * 0.76, h * 0.35), r * 0.9, paint);
        canvas.drawCircle(Offset(w * 0.76, h * 0.65), r * 0.9, paint);
        canvas.drawCircle(Offset(w * 0.50, h * 0.80), r * 0.9, paint);
        canvas.drawCircle(Offset(w * 0.24, h * 0.65), r * 0.9, paint);
        canvas.drawCircle(Offset(w * 0.24, h * 0.35), r * 0.9, paint);
        break;

      case WallpaperLayoutMode.spiral:
        // Spiral dots along a swirl
        canvas.drawCircle(Offset(w * 0.50, h * 0.50), r * 0.8, paint);
        canvas.drawCircle(Offset(w * 0.65, h * 0.45), r * 0.9, paint);
        canvas.drawCircle(Offset(w * 0.60, h * 0.70), r * 1.0, paint);
        canvas.drawCircle(Offset(w * 0.30, h * 0.72), r * 1.1, paint);
        canvas.drawCircle(Offset(w * 0.22, h * 0.35), r * 1.2, paint);
        break;

      case WallpaperLayoutMode.scatter:
        // Chaotic scatter with varying radii
        canvas.drawCircle(Offset(w * 0.25, h * 0.35), r * 1.2, paint);
        canvas.drawCircle(Offset(w * 0.68, h * 0.25), r * 0.8, paint);
        canvas.drawCircle(Offset(w * 0.52, h * 0.55), r * 1.1, paint);
        canvas.drawCircle(Offset(w * 0.75, h * 0.75), r * 1.3, paint);
        canvas.drawCircle(Offset(w * 0.30, h * 0.78), r * 0.7, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _LayoutMiniaturePainter oldDelegate) {
    return oldDelegate.mode != mode || oldDelegate.color != color;
  }
}
