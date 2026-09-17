import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/identity/nios_weave.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/motion/tri_sync.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';
import 'package:pulse_flutter/providers/chat_wallpaper_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';
import 'package:pulse_flutter/widgets/wallpaper/chat_wallpaper_painter.dart';
import 'package:pulse_flutter/widgets/wallpaper/curated_wallpaper_catalog.dart';
import 'package:pulse_flutter/widgets/wallpaper/icon_sources_catalog.dart';
import 'package:pulse_flutter/widgets/wallpaper/wallpaper_color_resolver.dart';
import 'package:pulse_flutter/widgets/wallpaper/wallpaper_image_cache.dart';
import 'package:universal_io/io.dart' as io;

class SettingsWallpaperScreen extends ConsumerStatefulWidget {
  const SettingsWallpaperScreen({
    this.chatId,
    this.chatTitle,
    this.initialCode,
    this.isEmbedded = false,
    super.key,
  });

  final String? chatId;
  final String? chatTitle;
  final String? initialCode;
  final bool isEmbedded;

  @override
  ConsumerState<SettingsWallpaperScreen> createState() =>
      _SettingsWallpaperScreenState();
}

class _SettingsWallpaperScreenState extends ConsumerState<SettingsWallpaperScreen>
    with TickerProviderStateMixin {
  late ChatWallpaperConfig _draftConfig;
  late ChatWallpaperConfig _savedConfig;
  bool _userModified = false;
  bool _editingThisChatOnly = false;
  bool _showChatMockup = true;
  bool _isFullscreenPreview = false;

  ui.Picture? _previewSvgPicture;
  List<ui.Picture>? _previewPoolSvgPictures;
  Map<String, ui.Picture>? _previewPaletteSvgPictures;
  Color? _lastLoadedIconColor;
  bool _dependenciesInitialized = false;

  late AnimationController _diceAnimController;
  late Animation<double> _diceRotationAnimation;
  late AnimationController _revealAnimController;
  late Animation<double> _revealAnimation;
  Timer? _hapticThrottleTimer;

  static const List<String> _kBgRoleKeys = <String>[
    'surfaceContainerLowest',
    'surfaceContainerLow',
    'surfaceContainer',
    'surfaceContainerHigh',
    'primaryContainer',
    'secondaryContainer',
    'tertiaryContainer',
  ];

  @override
  void initState() {
    super.initState();
    _editingThisChatOnly = widget.chatId != null;
    final ChatWallpaperState wallpaperState = ref.read(chatWallpaperProvider);
    _savedConfig = wallpaperState.forChat(widget.chatId);
    _draftConfig = _savedConfig;

    _diceAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _diceRotationAnimation = CurvedAnimation(
      parent: _diceAnimController,
      curve: M3SpringCurves.bouncy,
    );

    _revealAnimController = AnimationController(
      vsync: this,
      duration: M3Durations.medium3,
    );
    _revealAnimation = CurvedAnimation(
      parent: _revealAnimController,
      curve: M3SpringCurves.spatial,
    );

    if (widget.initialCode != null && widget.initialCode!.trim().isNotEmpty) {
      final ChatWallpaperConfig? imported =
          NiosWeave.decode(widget.initialCode!.trim());
      if (imported != null) {
        _draftConfig = imported;
        _userModified = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            AppToast.showSuccess(context, 'Узор Weave загружен по ссылке');
            _triggerReveal();
          }
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color currentIconColor = WallpaperColorResolver.resolveIconColor(
      scheme,
      _draftConfig.iconColorRole,
      _draftConfig.iconAlpha,
    );
    if (!_dependenciesInitialized || _lastLoadedIconColor != currentIconColor) {
      _dependenciesInitialized = true;
      _lastLoadedIconColor = currentIconColor;
      _loadSvgPreviewIfNeeded();
    }
  }

  @override
  void dispose() {
    _hapticThrottleTimer?.cancel();
    _diceAnimController.dispose();
    _revealAnimController.dispose();
    super.dispose();
  }

  void _triggerReveal() {
    _revealAnimController.forward(from: 0.0);
  }

  void _throttledHaptic() {
    if (_hapticThrottleTimer?.isActive ?? false) return;
    TriSync.snap(ref: ref);
    _hapticThrottleTimer = Timer(const Duration(milliseconds: 55), () {});
  }

  void _updateDraft(ChatWallpaperConfig newConfig, {bool triggerReveal = false}) {
    final bool needsSvgReload =
        newConfig.iconSource != _draftConfig.iconSource ||
            newConfig.themePack != _draftConfig.themePack ||
            newConfig.seed != _draftConfig.seed ||
            newConfig.filled != _draftConfig.filled ||
            newConfig.iconAlpha != _draftConfig.iconAlpha ||
            newConfig.colorMode != _draftConfig.colorMode ||
            newConfig.iconColorRole != _draftConfig.iconColorRole ||
            newConfig.selectedGlyphs != _draftConfig.selectedGlyphs;

    setState(() {
      _userModified = true;
      _draftConfig = newConfig;
    });

    if (triggerReveal) {
      _triggerReveal();
    }

    if (needsSvgReload) {
      _loadSvgPreviewIfNeeded();
    }
  }

  Future<void> _loadSvgPreviewIfNeeded() async {
    if (!mounted) return;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color iconColor = WallpaperColorResolver.resolveIconColor(
      scheme,
      _draftConfig.iconColorRole,
      _draftConfig.iconAlpha,
    );
    _lastLoadedIconColor = iconColor;

    if (_draftConfig.iconSource == IconSource.lucide ||
        _draftConfig.iconSource == IconSource.tabler) {
      final String folder =
          _draftConfig.iconSource == IconSource.lucide ? 'lucide' : 'tabler';

      List<String> iconsToLoad = <String>[];
      if (_draftConfig.themePack != 'all' && _draftConfig.themePack != 'custom') {
        iconsToLoad = IconSourcesCatalog.getThemePackIcons(
          _draftConfig.themePack,
          source: _draftConfig.iconSource,
        );
      } else if (_draftConfig.themePack == 'custom' &&
          _draftConfig.selectedGlyphs.isNotEmpty) {
        iconsToLoad = _draftConfig.selectedGlyphs;
      }

      if (iconsToLoad.isNotEmpty) {
        final List<ui.Picture?> results = await Future.wait(
          iconsToLoad.map(
            (name) => WallpaperImageCache.loadPatternSvg(
              assetPath: 'assets/svg/pattern_icons/$folder/$name.svg',
              color: iconColor,
              filled: _draftConfig.filled,
            ),
          ),
        );
        final List<ui.Picture> pool = results.whereType<ui.Picture>().toList();

        if (mounted) {
          setState(() {
            _previewPoolSvgPictures = pool;
            _previewPaletteSvgPictures = null;
            _previewSvgPicture = null;
          });
        }
        return;
      }
    }

    if (_previewSvgPicture != null ||
        _previewPoolSvgPictures != null ||
        _previewPaletteSvgPictures != null) {
      setState(() {
        _previewSvgPicture = null;
        _previewPoolSvgPictures = null;
        _previewPaletteSvgPictures = null;
      });
    }
  }

  void _saveConfig() {
    TriSync.pop(ref: ref, context: context);
    final notifier = ref.read(chatWallpaperProvider.notifier);
    if (_editingThisChatOnly && widget.chatId != null) {
      notifier.setChatWallpaper(widget.chatId!, _draftConfig);
    } else {
      notifier.updateGlobalConfig(_draftConfig);
    }
    setState(() {
      _savedConfig = _draftConfig;
      _userModified = false;
    });
    AppToast.showSuccess(context, context.l10n.wallpaperSaved);
  }

  Future<void> _resetConfig() async {
    TriSync.tap(ref: ref);
    final bool? confirm = await showAppConfirmDialog(
      context: context,
      title: context.l10n.wallpaperResetTitle,
      subtitle: context.l10n.wallpaperResetSubtitle,
      confirmLabel: context.l10n.wallpaperResetAction,
      cancelLabel: context.l10n.wallpaperDiscard,
      destructive: true,
    );

    if (confirm != true || !mounted) return;

    final notifier = ref.read(chatWallpaperProvider.notifier);
    if (_editingThisChatOnly && widget.chatId != null) {
      notifier.resetChatWallpaper(widget.chatId!);
      _updateDraft(ref.read(chatWallpaperProvider).global, triggerReveal: true);
    } else {
      notifier.resetGlobalToDefault();
      _updateDraft(ChatWallpaperConfig.defaultPattern, triggerReveal: true);
    }
    AppToast.showSuccess(context, context.l10n.wallpaperResetAction);
  }

  void _showShareWeaveModal(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String code = NiosWeave.encode(_draftConfig);
    final String shareUrl = NiosWeave.toShareUrl(code);

    AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext sheetCtx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.auto_awesome_rounded, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Поделиться обоями',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: SizedBox(
                    height: 130,
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: CustomPaint(
                            painter: ChatWallpaperPainter(
                              config: _draftConfig,
                              scheme: scheme,
                              svgPicture: _previewSvgPicture,
                              paletteSvgPictures: _previewPaletteSvgPictures,
                              poolSvgPictures: _previewPoolSvgPictures,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          left: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.90),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              code,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        TriSync.pop(ref: ref, context: context);
                        await Clipboard.setData(ClipboardData(text: code));
                        if (sheetCtx.mounted) {
                          AppToast.showSuccess(
                              sheetCtx, 'Код обоев ($code) скопирован!');
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Скопировать код'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        TriSync.pop(ref: ref, context: context);
                        await Clipboard.setData(ClipboardData(text: shareUrl));
                        if (sheetCtx.mounted) {
                          AppToast.showSuccess(sheetCtx, 'Ссылка скопирована!');
                        }
                      },
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('Скопировать ссылку'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showImportWeaveModal(BuildContext context) {
    AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext sheetCtx) {
        return _WeaveImportSheet(
          scheme: Theme.of(context).colorScheme,
          onApply: (ChatWallpaperConfig imported) {
            TriSync.pop(ref: ref, context: context);
            _updateDraft(imported, triggerReveal: true);
            AppToast.showSuccess(context, 'Обои успешно применены!');
          },
        );
      },
    );
  }

  void _randomizeConfigWithSpin() {
    _diceAnimController.forward(from: 0.0);
    _randomizeConfig();
  }

  void _randomizeConfig() {
    TriSync.pop(ref: ref, context: context);
    final Random rng = Random();

    const List<String> m3Packs = <String>[
      CuratedWallpaperCatalog.packOrganic,
      CuratedWallpaperCatalog.packRadiance,
      CuratedWallpaperCatalog.packCookies,
      CuratedWallpaperCatalog.packGeometry,
    ];
    const List<WallpaperLayoutMode> modes = <WallpaperLayoutMode>[
      WallpaperLayoutMode.stagger,
      WallpaperLayoutMode.hex,
      WallpaperLayoutMode.scatter,
      WallpaperLayoutMode.grid,
    ];
    const List<WallpaperBackgroundStyle> bgStyles = <WallpaperBackgroundStyle>[
      WallpaperBackgroundStyle.solid,
      WallpaperBackgroundStyle.linearGradient,
      WallpaperBackgroundStyle.radialGlow,
    ];

    final String selectedPack = m3Packs[rng.nextInt(m3Packs.length)];
    final WallpaperLayoutMode selectedMode = modes[rng.nextInt(modes.length)];
    final WallpaperBackgroundStyle selectedBg =
        bgStyles[rng.nextInt(bgStyles.length)];
    final String bgRole1 = _kBgRoleKeys[rng.nextInt(_kBgRoleKeys.length)];
    final String bgRole2 = _kBgRoleKeys[rng.nextInt(_kBgRoleKeys.length)];

    final ChatWallpaperConfig previous = _draftConfig;
    final ChatWallpaperConfig randomized = _draftConfig.copyWith(
      seed: rng.nextInt(100000),
      iconSource: IconSource.niosMess,
      themePack: selectedPack,
      selectedGlyphs: const <String>[],
      useAllIcons: rng.nextBool(),
      layoutMode: selectedMode,
      cellSize: (52.0 + rng.nextInt(6) * 6.0),
      density: (0.60 + rng.nextInt(6) * 0.05).clamp(0.55, 0.85),
      gridAngle: 0.0,
      randomRotationDeg: rng.nextBool() ? 15.0 : 0.0,
      randomScaleJitter: rng.nextBool() ? 0.15 : 0.0,
      filled: rng.nextBool(),
      backgroundStyle: selectedBg,
      backgroundRole: bgRole1,
      backgroundSecondaryRole: bgRole2,
      gradientAngle: (rng.nextInt(4) * 45.0 + 45.0),
      colorMode: WallpaperColorMode.tonalAccent,
      iconAlpha: (0.12 + rng.nextInt(3) * 0.04),
      clearImagePath: true,
    );

    _updateDraft(randomized, triggerReveal: true);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.wallpaperRandomUndo),
          behavior: SnackBarBehavior.floating,
          shape: RoundedSuperellipseBorder(
            borderRadius: AppRadii.lgRadius,
          ),
          action: SnackBarAction(
            label: context.l10n.wallpaperDiscard,
            onPressed: () {
              TriSync.tap(ref: ref);
              _updateDraft(previous, triggerReveal: true);
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _pickCustomPhoto() async {
    TriSync.tap(ref: ref);
    try {
      final List<PlatformFile> result = await FilePicker.pickFiles(
        type: FileType.image,
      );
      if (result.isNotEmpty && mounted) {
        final String? path = result.first.path;
        if (path != null && path.isNotEmpty) {
          _updateDraft(_draftConfig.copyWith(imagePath: path), triggerReveal: true);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    ref.listen<ChatWallpaperState>(chatWallpaperProvider, (previous, next) {
      if (!_userModified && next.isLoaded) {
        final newConfig = next.forChat(widget.chatId);
        if (newConfig != _draftConfig) {
          setState(() {
            _savedConfig = newConfig;
            _draftConfig = newConfig;
          });
          _loadSvgPreviewIfNeeded();
        }
      }
    });

    final String screenTitle = widget.chatId != null && widget.chatTitle != null
        ? '${context.l10n.wallpaperScreenTitle}: ${widget.chatTitle}'
        : context.l10n.wallpaperScreenTitle;

    // Fullscreen interactive preview mode
    if (_isFullscreenPreview) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            setState(() => _isFullscreenPreview = false);
          }
        },
        child: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _buildPreviewBackground(scheme),
              if (_showChatMockup) const _ChatMockupView(),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        TriSync.tap(ref: ref);
                        setState(() => _isFullscreenPreview = false);
                      },
                      icon: const Icon(Icons.fullscreen_exit_rounded, size: 18),
                      label: const Text('Выйти из полноэкранного режима'),
                      style: FilledButton.styleFrom(
                        shape: RoundedSuperellipseBorder(
                          borderRadius: AppRadii.fullRadius,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: _draftConfig == _savedConfig,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final bool? discard = await showAppConfirmDialog(
          context: context,
          title: context.l10n.wallpaperDiscardConfirmTitle,
          subtitle: context.l10n.wallpaperDiscardConfirmBody,
          confirmLabel: context.l10n.wallpaperDiscardConfirmAction,
          cancelLabel: context.l10n.wallpaperDiscard,
          destructive: true,
        );
        if (discard == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(screenTitle, style: textTheme.titleMedium),
          actions: <Widget>[
            IconButton(
              tooltip: 'Вставить код',
              onPressed: () => _showImportWeaveModal(context),
              icon: const Icon(Icons.file_download_outlined),
            ),
            IconButton(
              tooltip: 'Поделиться',
              onPressed: () => _showShareWeaveModal(context),
              icon: const Icon(Icons.share_rounded),
            ),
            RotationTransition(
              turns: _diceRotationAnimation,
              child: IconButton(
                tooltip: context.l10n.wallpaperRandomize,
                onPressed: _randomizeConfigWithSpin,
                icon: const Icon(Icons.casino_rounded),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: <Widget>[
                TextButton(
                  onPressed: _resetConfig,
                  child: Text(context.l10n.wallpaperResetAction),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _saveConfig,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(context.l10n.wallpaperApply),
                  style: FilledButton.styleFrom(
                    shape: RoundedSuperellipseBorder(
                      borderRadius: AppRadii.lgRadius,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Chat Context Switcher
              if (widget.chatId != null) ...[
                SegmentedButton<bool>(
                  segments: <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: true,
                      label: Text(context.l10n.wallpaperForThisChat),
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          size: 16),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text(context.l10n.wallpaperForAllChats),
                      icon: const Icon(Icons.public_rounded, size: 16),
                    ),
                  ],
                  selected: <bool>{_editingThisChatOnly},
                  onSelectionChanged: (Set<bool> sel) {
                    TriSync.tap(ref: ref);
                    setState(() => _editingThisChatOnly = sel.first);
                  },
                ),
                const SizedBox(height: 12),
              ],

              // ── 1. Hero Immersive Live Canvas ───────────────────────────────
              Semantics(
                button: true,
                label: 'Полноэкранный просмотр обоев',
                child: TouchContainer(
                  onTap: () {
                    TriSync.pop(ref: ref, context: context);
                    setState(() => _isFullscreenPreview = true);
                  },
                  borderRadius: AppRadii.xlRadius,
                  scaleDown: 0.98,
                  releaseCurve: M3SpringCurves.spatial,
                  child: Container(
                    height: 320,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: AppRadii.xlRadius,
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        _buildLivePreviewWithReveal(scheme),
                        if (_showChatMockup) const _ChatMockupView(),

                        // Top Controls (Mockup & Fullscreen info)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.85),
                              borderRadius: AppRadii.fullRadius,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Переключить мокап сообщений',
                                  onPressed: () {
                                    TriSync.tap(ref: ref);
                                    setState(
                                        () => _showChatMockup = !_showChatMockup);
                                  },
                                  icon: Icon(
                                    _showChatMockup
                                        ? Icons.chat_bubble_rounded
                                        : Icons.chat_bubble_outline_rounded,
                                    size: 18,
                                    color: scheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _showChatMockup ? 'Чат' : 'Чистый',
                                  style: textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                            ),
                          ),
                        ),

                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.85),
                              borderRadius: AppRadii.fullRadius,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(Icons.fullscreen_rounded,
                                    size: 16, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                  'Нажмите для просмотра',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
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
              ),

              const SizedBox(height: 16),

              // ── 2. Modern M3 Expressive Style Pill Selector (52dp) ──────────
              _M3StylePillSelector(
                draftConfig: _draftConfig,
                onSelectPack: (String packId, IconSource source) {
                  TriSync.snap(ref: ref);
                  if (packId == 'my_photo') {
                    if (_draftConfig.imagePath == null) {
                      _pickCustomPhoto();
                    }
                  } else {
                    _updateDraft(
                      _draftConfig.copyWith(
                        iconSource: source,
                        themePack: packId,
                        clearImagePath: true,
                        selectedGlyphs: const <String>[],
                        useAllIcons: true,
                      ),
                      triggerReveal: true,
                    );
                  }
                },
              ),

              const SizedBox(height: 16),

              // ── 3. Consolidated M3E Control Island ──────────────────────────
              _M3ControlIsland(
                draftConfig: _draftConfig,
                onUpdateDraft: _updateDraft,
                onThrottledHaptic: _throttledHaptic,
                onPickPhoto: _pickCustomPhoto,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLivePreviewWithReveal(ColorScheme scheme) {
    final Widget bg = _buildPreviewBackground(scheme);
    return AnimatedBuilder(
      animation: _revealAnimation,
      builder: (BuildContext context, Widget? child) {
        if (_revealAnimation.value <= 0.0 || _revealAnimation.isCompleted) {
          return bg;
        }
        final double t = _revealAnimation.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(24.0 * (1.0 - t * 0.5)),
          child: Transform.scale(
            scale: 0.94 + 0.06 * t,
            alignment: Alignment.center,
            child: Opacity(
              opacity: (0.30 + 0.70 * t).clamp(0.0, 1.0),
              child: bg,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewBackground(ColorScheme scheme) {
    if (_draftConfig.imagePath != null && _draftConfig.imagePath!.isNotEmpty) {
      final io.File file = io.File(_draftConfig.imagePath!);
      if (file.existsSync()) {
        Widget img = Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackPainter(scheme),
        );
        if (_draftConfig.imageBlur > 0.01) {
          img = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: _draftConfig.imageBlur,
              sigmaY: _draftConfig.imageBlur,
            ),
            child: img,
          );
        }
        if (_draftConfig.imageDim > 0.01) {
          img = Stack(
            fit: StackFit.expand,
            children: <Widget>[
              img,
              ColoredBox(
                color: Colors.black
                    .withValues(alpha: _draftConfig.imageDim.clamp(0.0, 0.95)),
              ),
            ],
          );
        }
        return img;
      }
    }
    return _buildFallbackPainter(scheme);
  }

  Widget _buildFallbackPainter(ColorScheme scheme) {
    return CustomPaint(
      size: const Size(double.infinity, 320),
      painter: ChatWallpaperPainter(
        config: _draftConfig,
        scheme: scheme,
        svgPicture: _previewSvgPicture,
        poolSvgPictures: _previewPoolSvgPictures,
        paletteSvgPictures: _previewPaletteSvgPictures,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── M3 Expressive Style Pill Selector ─────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class _M3StylePillSelector extends StatelessWidget {
  const _M3StylePillSelector({
    required this.draftConfig,
    required this.onSelectPack,
  });

  final ChatWallpaperConfig draftConfig;
  final void Function(String packId, IconSource source) onSelectPack;

  static const List<({String id, String label, Shapes shape, IconData icon, IconSource source})>
      _kStyles = [
    (
      id: CuratedWallpaperCatalog.packOrganic,
      label: 'Органика',
      shape: Shapes.hearth,
      icon: Icons.favorite_rounded,
      source: IconSource.niosMess,
    ),
    (
      id: CuratedWallpaperCatalog.packRadiance,
      label: 'Сияние',
      shape: Shapes.soft_burst,
      icon: Icons.auto_awesome_rounded,
      source: IconSource.niosMess,
    ),
    (
      id: CuratedWallpaperCatalog.packCookies,
      label: 'Печеньки',
      shape: Shapes.c9_sided_cookie,
      icon: Icons.cookie_rounded,
      source: IconSource.niosMess,
    ),
    (
      id: CuratedWallpaperCatalog.packGeometry,
      label: 'Геометрия',
      shape: Shapes.diamond,
      icon: Icons.category_rounded,
      source: IconSource.niosMess,
    ),
    (
      id: CuratedWallpaperCatalog.packPixels,
      label: 'Пиксели',
      shape: Shapes.pixel_circle,
      icon: Icons.grid_view_rounded,
      source: IconSource.niosMess,
    ),
    (
      id: 'chat',
      label: 'Дудлы',
      shape: Shapes.flower,
      icon: Icons.chat_bubble_rounded,
      source: IconSource.materialSymbols,
    ),
    (
      id: 'my_photo',
      label: 'Своё фото',
      shape: Shapes.circle,
      icon: Icons.add_photo_alternate_rounded,
      source: IconSource.materialSymbols,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _kStyles.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _kStyles[index];
          final bool isPhoto = item.id == 'my_photo';
          final bool isSelected = isPhoto
              ? (draftConfig.imagePath != null && draftConfig.imagePath!.isNotEmpty)
              : (draftConfig.imagePath == null &&
                  draftConfig.iconSource == item.source &&
                  draftConfig.themePack == item.id);

          return TouchContainer(
            onTap: () => onSelectPack(item.id, item.source),
            borderRadius: AppRadii.fullRadius,
            scaleDown: 0.94,
            child: AnimatedContainer(
              duration: M3Durations.medium1,
              curve: M3SpringCurves.spatial,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHigh,
                borderRadius: AppRadii.fullRadius,
                border: Border.all(
                  color: isSelected
                      ? scheme.primary
                      : scheme.outlineVariant.withValues(alpha: 0.3),
                  width: isSelected ? 1.8 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (item.source == IconSource.niosMess)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CustomPaint(
                        painter: _M3MiniShapePainter(
                          shape: item.shape,
                          color: isSelected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                          filled: true,
                        ),
                      ),
                    )
                  else
                    Icon(
                      item.icon,
                      size: 18,
                      color: isSelected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    item.label,
                    style: textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── Consolidated M3E Control Island ──────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class _M3ControlIsland extends ConsumerWidget {
  const _M3ControlIsland({
    required this.draftConfig,
    required this.onUpdateDraft,
    required this.onThrottledHaptic,
    required this.onPickPhoto,
  });

  final ChatWallpaperConfig draftConfig;
  final ValueChanged<ChatWallpaperConfig> onUpdateDraft;
  final VoidCallback onThrottledHaptic;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final bool hasPhoto = draftConfig.imagePath != null &&
        draftConfig.imagePath!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadii.xlRadius,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // If custom photo is active: photo tuning controls
          if (hasPhoto) ...[
            Text('Настройки фотографии',
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'Размытие (${draftConfig.imageBlur.toStringAsFixed(1)} dp)',
              style: textTheme.labelMedium,
            ),
            Slider(
              value: draftConfig.imageBlur,
              min: 0.0,
              max: 20.0,
              divisions: 20,
              onChanged: (val) {
                onThrottledHaptic();
                onUpdateDraft(draftConfig.copyWith(imageBlur: val));
              },
            ),
            const SizedBox(height: 6),
            Text(
              'Затемнение (${(draftConfig.imageDim * 100).round()}%)',
              style: textTheme.labelMedium,
            ),
            Slider(
              value: draftConfig.imageDim,
              min: 0.0,
              max: 0.8,
              divisions: 16,
              onChanged: (val) {
                onThrottledHaptic();
                onUpdateDraft(draftConfig.copyWith(imageDim: val));
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickPhoto,
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text('Сменить фото'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedSuperellipseBorder(
                        borderRadius: AppRadii.lgRadius,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      TriSync.pop(ref: ref, context: context);
                      onUpdateDraft(draftConfig.copyWith(clearImagePath: true));
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Удалить'),
                    style: FilledButton.styleFrom(
                      shape: RoundedSuperellipseBorder(
                        borderRadius: AppRadii.lgRadius,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // ── Section 1: Shapes & Style (Outline / Fill) ───────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  draftConfig.iconSource == IconSource.niosMess
                      ? 'Фигуры коллекции'
                      : 'Тема символов',
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Контур'),
                      icon: Icon(Icons.circle_outlined, size: 14),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Заливка'),
                      icon: Icon(Icons.circle, size: 14),
                    ),
                  ],
                  selected: <bool>{draftConfig.filled},
                  onSelectionChanged: (Set<bool> sel) {
                    TriSync.tap(ref: ref);
                    onUpdateDraft(draftConfig.copyWith(filled: sel.first));
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Individual shape toggles for active M3 collection
            if (draftConfig.iconSource == IconSource.niosMess)
              _buildM3ShapeChips(scheme, textTheme, ref)
            else
              _buildDoodlePackChips(scheme, textTheme, ref),

            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // ── Section 2: Colors & Harmony ─────────────────────────────────
            Text('Цветовая палитра',
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            Row(
              children: <Widget>[
                Expanded(
                  child: SegmentedButton<WallpaperBackgroundStyle>(
                    segments: const <ButtonSegment<WallpaperBackgroundStyle>>[
                      ButtonSegment(
                        value: WallpaperBackgroundStyle.solid,
                        label: Text('Тон темы'),
                      ),
                      ButtonSegment(
                        value: WallpaperBackgroundStyle.radialGlow,
                        label: Text('Свечение'),
                      ),
                      ButtonSegment(
                        value: WallpaperBackgroundStyle.linearGradient,
                        label: Text('Градиент'),
                      ),
                    ],
                    selected: <WallpaperBackgroundStyle>{
                      draftConfig.backgroundStyle
                    },
                    onSelectionChanged: (Set<WallpaperBackgroundStyle> sel) {
                      TriSync.tap(ref: ref);
                      onUpdateDraft(
                          draftConfig.copyWith(backgroundStyle: sel.first));
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Tonal Color Swatch Strip
            _buildTonalSwatches(scheme, ref),

            const SizedBox(height: 14),

            // Opacity Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Прозрачность узора', style: textTheme.labelMedium),
                Text(
                  '${(draftConfig.iconAlpha * 100).round()}%',
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            Slider(
              value: draftConfig.iconAlpha,
              min: 0.06,
              max: 0.35,
              divisions: 29,
              onChanged: (val) {
                onThrottledHaptic();
                onUpdateDraft(draftConfig.copyWith(iconAlpha: val));
              },
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // ── Section 3: Scale & Layout ───────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Масштаб и геометрия',
                    style:
                        textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                SegmentedButton<int>(
                  segments: const <ButtonSegment<int>>[
                    ButtonSegment(value: 48, label: Text('Мелкий')),
                    ButtonSegment(value: 62, label: Text('Баланс')),
                    ButtonSegment(value: 84, label: Text('Крупный')),
                  ],
                  selected: <int>{
                    draftConfig.cellSize <= 54
                        ? 48
                        : (draftConfig.cellSize <= 72 ? 62 : 84)
                  },
                  onSelectionChanged: (Set<int> sel) {
                    TriSync.tap(ref: ref);
                    final int step = sel.first;
                    onUpdateDraft(
                      draftConfig.copyWith(
                        cellSize: step.toDouble(),
                        density: step == 48 ? 0.76 : (step == 62 ? 0.70 : 0.60),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Layout Pills (Шахматы, Соты, Россыпь, Сетка)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const <WallpaperLayoutMode>[
                WallpaperLayoutMode.stagger,
                WallpaperLayoutMode.hex,
                WallpaperLayoutMode.scatter,
                WallpaperLayoutMode.grid,
              ].map((mode) {
                final bool isSelected = draftConfig.layoutMode == mode;
                return ChoiceChip(
                  label: Text(switch (mode) {
                    WallpaperLayoutMode.stagger => 'Шахматы',
                    WallpaperLayoutMode.hex => 'Соты',
                    WallpaperLayoutMode.scatter => 'Россыпь',
                    WallpaperLayoutMode.grid => 'Сетка',
                    _ => 'Сетка',
                  }),
                  selected: isSelected,
                  onSelected: (bool sel) {
                    if (sel) {
                      TriSync.tap(ref: ref);
                      onUpdateDraft(draftConfig.copyWith(layoutMode: mode));
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildM3ShapeChips(
      ColorScheme scheme, TextTheme textTheme, WidgetRef ref) {
    final List<Shapes> shapesInPack =
        CuratedWallpaperCatalog.getShapesForPack(draftConfig.themePack);
    final Set<String> activeGlyphs = Set<String>.from(draftConfig.selectedGlyphs);

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shapesInPack.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final Shapes shape = shapesInPack[index];
          final String name = shape.name;
          final bool isIncluded =
              activeGlyphs.isEmpty || activeGlyphs.contains(name);

          return TouchContainer(
            onTap: () {
              TriSync.tap(ref: ref);
              final Set<String> updated = Set<String>.from(activeGlyphs);
              if (updated.isEmpty) {
                // Was using all shapes; clicking one selects ONLY that one
                updated.add(name);
              } else if (updated.contains(name)) {
                if (updated.length > 1) {
                  updated.remove(name);
                } else {
                  // Last one removed reverts to all
                  updated.clear();
                }
              } else {
                updated.add(name);
              }
              onUpdateDraft(draftConfig.copyWith(selectedGlyphs: updated.toList()));
            },
            borderRadius: AppRadii.fullRadius,
            scaleDown: 0.92,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isIncluded
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
                borderRadius: AppRadii.fullRadius,
                border: Border.all(
                  color: isIncluded
                      ? scheme.primary
                      : scheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CustomPaint(
                      painter: _M3MiniShapePainter(
                        shape: shape,
                        color: isIncluded
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                        filled: draftConfig.filled,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    CuratedWallpaperCatalog.shapeName(shape),
                    style: textTheme.labelSmall?.copyWith(
                      color: isIncluded
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                      fontWeight:
                          isIncluded ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDoodlePackChips(
      ColorScheme scheme, TextTheme textTheme, WidgetRef ref) {
    const List<({String id, String label, IconData icon})> packs = [
      (id: 'chat', label: 'Чат', icon: Icons.chat_bubble_rounded),
      (id: 'space', label: 'Космос', icon: Icons.rocket_launch_rounded),
      (id: 'food', label: 'Еда & Кофе', icon: Icons.coffee_rounded),
      (id: 'nature', label: 'Природа', icon: Icons.eco_rounded),
      (id: 'minimal', label: 'Минимал', icon: Icons.grain_rounded),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: packs.map((p) {
        final bool isSelected = draftConfig.themePack == p.id;
        return ChoiceChip(
          avatar: Icon(p.icon, size: 16),
          label: Text(p.label),
          selected: isSelected,
          onSelected: (bool sel) {
            if (sel) {
              TriSync.tap(ref: ref);
              onUpdateDraft(draftConfig.copyWith(themePack: p.id));
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildTonalSwatches(ColorScheme scheme, WidgetRef ref) {
    const List<String> roles = <String>[
      'surfaceContainerLowest',
      'surfaceContainerLow',
      'surfaceContainer',
      'surfaceContainerHigh',
      'primaryContainer',
      'secondaryContainer',
      'tertiaryContainer',
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: roles.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final String role = roles[index];
          final Color color =
              WallpaperColorResolver.resolveBackground(scheme, role);
          final bool isSelected = draftConfig.backgroundRole == role;

          return TouchContainer(
            onTap: () {
              TriSync.tap(ref: ref);
              onUpdateDraft(draftConfig.copyWith(backgroundRole: role));
            },
            borderRadius: AppRadii.fullRadius,
            scaleDown: 0.90,
            child: AnimatedContainer(
              duration: M3Durations.medium1,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? scheme.primary : scheme.outlineVariant,
                  width: isSelected ? 2.5 : 1.0,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: ThemeData.estimateBrightnessForColor(color) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── Mini M3 Vector Shape Painter (Zero SVG overhead) ─────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class _M3MiniShapePainter extends CustomPainter {
  const _M3MiniShapePainter({
    required this.shape,
    required this.color,
    required this.filled,
  });

  final Shapes shape;
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = M3Clipper(shape).getClip(size);
    final Paint paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = max(1.2, size.width * 0.10);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _M3MiniShapePainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.color != color ||
        oldDelegate.filled != filled;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── Chat Mockup View ─────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class _ChatMockupView extends StatelessWidget {
  const _ChatMockupView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 240),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.92),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadii.lg),
                  topRight: Radius.circular(AppRadii.lg),
                  bottomRight: Radius.circular(AppRadii.lg),
                  bottomLeft: Radius.circular(AppRadii.xs),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Material 3 Expressive',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      '14:20',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
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
              constraints: const BoxConstraints(maxWidth: 240),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadii.lg),
                  topRight: Radius.circular(AppRadii.lg),
                  bottomLeft: Radius.circular(AppRadii.lg),
                  bottomRight: Radius.circular(AppRadii.xs),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    'NiosMess Chat Wallpaper',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '14:21',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.done_all_rounded,
                        size: 14,
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// ── Weave Import Sheet ───────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class _WeaveImportSheet extends StatefulWidget {
  const _WeaveImportSheet({
    required this.scheme,
    required this.onApply,
  });

  final ColorScheme scheme;
  final ValueChanged<ChatWallpaperConfig> onApply;

  @override
  State<_WeaveImportSheet> createState() => _WeaveImportSheetState();
}

class _WeaveImportSheetState extends State<_WeaveImportSheet> {
  late final TextEditingController _controller;
  ChatWallpaperConfig? _previewConfig;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onTextChanged);
    _checkClipboard();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkClipboard() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = data?.text?.trim();
    if (text != null &&
        text.isNotEmpty &&
        (text.startsWith('nwv1:') || text.contains('/w/'))) {
      if (mounted) {
        _controller.text = text;
      }
    }
  }

  void _onTextChanged() {
    final String text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _previewConfig = null;
        _errorMessage = null;
      });
      return;
    }

    final ChatWallpaperConfig? parsed = NiosWeave.decode(text);
    setState(() {
      _previewConfig = parsed;
      _errorMessage =
          parsed == null ? 'Некорректный код или ссылка Nios Weave' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.file_download_outlined, size: 22),
              const SizedBox(width: 10),
              Text(
                'Вставить код обоев',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'nwv1:... или ni-os.ru/w/...',
              errorText: _errorMessage,
              prefixIcon: const Icon(Icons.qr_code_rounded, size: 20),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => _controller.clear(),
                    )
                  : IconButton(
                      icon: const Icon(Icons.paste_rounded, size: 18),
                      tooltip: 'Вставить из буфера',
                      onPressed: () async {
                        final ClipboardData? data =
                            await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null && mounted) {
                          _controller.text = data!.text!.trim();
                        }
                      },
                    ),
              filled: true,
              fillColor: widget.scheme.surfaceContainerLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_previewConfig != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.scheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: SizedBox(
                  height: 120,
                  child: CustomPaint(
                    painter: ChatWallpaperPainter(
                      config: _previewConfig!,
                      scheme: widget.scheme,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _previewConfig == null
                ? null
                : () {
                    widget.onApply(_previewConfig!);
                    Navigator.of(context).pop();
                  },
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Применить обои'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
