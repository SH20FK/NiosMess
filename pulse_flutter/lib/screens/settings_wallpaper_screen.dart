import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pulse_flutter/core/identity/nios_weave.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/motion/tri_sync.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';
import 'package:pulse_flutter/providers/chat_wallpaper_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';
import 'package:pulse_flutter/widgets/wallpaper/chat_wallpaper_painter.dart';
import 'package:pulse_flutter/widgets/wallpaper/cupertino_icons_data.dart';
import 'package:pulse_flutter/widgets/wallpaper/icon_sources_catalog.dart';
import 'package:pulse_flutter/widgets/wallpaper/material_symbols_data.dart';
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

class _SettingsWallpaperScreenState
    extends ConsumerState<SettingsWallpaperScreen>
    with TickerProviderStateMixin {
  late ChatWallpaperConfig _draftConfig;
  late ChatWallpaperConfig _savedConfig;
  bool _userModified = false;
  bool _editingThisChatOnly = false;
  bool _showChatMockup = true;

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
      final ChatWallpaperConfig? imported = NiosWeave.decode(widget.initialCode!.trim());
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
    HapticService.selection();
    _hapticThrottleTimer = Timer(const Duration(milliseconds: 60), () {});
  }

  void _updateDraft(ChatWallpaperConfig newConfig, {bool triggerReveal = false}) {
    final bool needsSvgReload = newConfig.iconSource != _draftConfig.iconSource ||
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
      } else if (_draftConfig.useAllIcons || _draftConfig.themePack == 'all') {
        final List<String> catalog = _draftConfig.iconSource == IconSource.lucide
            ? IconSourcesCatalog.lucideIcons
            : IconSourcesCatalog.tablerIcons;
        final Random rng = Random(_draftConfig.seed);
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
              filled: _draftConfig.filled,
            ),
          ),
        );
        final List<ui.Picture> pool = results.whereType<ui.Picture>().toList();

        Map<String, ui.Picture>? paletteMap;
        if (_draftConfig.colorMode != WallpaperColorMode.singleTone) {
          final List<String> activeRoles =
              ChatWallpaperPainter.resolveActiveRoles(_draftConfig);
          final String sampleAsset =
              'assets/svg/pattern_icons/$folder/${iconsToLoad.first}.svg';
          paletteMap = <String, ui.Picture>{};
          for (final String role in activeRoles) {
            final Color roleColor = WallpaperColorResolver.resolveIconColor(
              scheme,
              role,
              _draftConfig.iconAlpha,
            );
            final ui.Picture? pic = await WallpaperImageCache.loadPatternSvg(
              assetPath: sampleAsset,
              color: roleColor,
              filled: _draftConfig.filled,
            );
            if (pic != null) {
              paletteMap[role] = pic;
            }
          }
        }

        if (mounted) {
          setState(() {
            _previewPoolSvgPictures = pool;
            _previewPaletteSvgPictures = paletteMap;
            _previewSvgPicture = null;
          });
        }
        return;
      }

      if (_draftConfig.svgAssetPath != null &&
          _draftConfig.svgAssetPath!.isNotEmpty) {
        final ui.Picture? pic = await WallpaperImageCache.loadPatternSvg(
          assetPath: _draftConfig.svgAssetPath!,
          color: iconColor,
          filled: _draftConfig.filled,
        );
        if (mounted) {
          setState(() {
            _previewSvgPicture = pic;
            _previewPoolSvgPictures = null;
            _previewPaletteSvgPictures = null;
          });
        }
      }
    } else {
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
  }

  void _saveConfig() {
    HapticService.confirm();
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
    HapticService.tap();
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
      _updateDraft(ref.read(chatWallpaperProvider).global);
    } else {
      notifier.resetGlobalToDefault();
      _updateDraft(ChatWallpaperConfig.defaultPattern);
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
              // Live Mini Preview Tile
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest.withValues(alpha: 0.90),
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
                        TriSync.pop(ref: ref);
                        await Clipboard.setData(ClipboardData(text: code));
                        if (sheetCtx.mounted) {
                          AppToast.showSuccess(sheetCtx, 'Код обоев ($code) скопирован!');
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Скопировать код'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        TriSync.pop(ref: ref);
                        await Clipboard.setData(ClipboardData(text: shareUrl));
                        if (sheetCtx.mounted) {
                          AppToast.showSuccess(sheetCtx, 'Ссылка скопирована!');
                        }
                      },
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('Скопировать ссылку'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            TriSync.pop(ref: ref);
            _updateDraft(imported);
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

    final IconSource randomSource = sources[rng.nextInt(sources.length)];
    final WallpaperBackgroundStyle randomBg =
        bgStyles[rng.nextInt(bgStyles.length)];
    final String bgRole1 = _kBgRoleKeys[rng.nextInt(_kBgRoleKeys.length)];
    final String bgRole2 = _kBgRoleKeys[rng.nextInt(_kBgRoleKeys.length)];

    final ChatWallpaperConfig previous = _draftConfig;
    final ChatWallpaperConfig randomized = _draftConfig.copyWith(
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
      clearImagePath: true,
    );

    _updateDraft(randomized);

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
              HapticService.tap();
              _updateDraft(previous);
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _pickCustomPhoto() async {
    HapticService.tap();
    try {
      final List<PlatformFile> result = await FilePicker.pickFiles(
        type: FileType.image,
      );
      if (result.isNotEmpty && mounted) {
        final String? path = result.first.path;
        if (path != null && path.isNotEmpty) {
          _updateDraft(_draftConfig.copyWith(imagePath: path));
          _openPhotoTuningSheet();
        }
      }
    } catch (_) {}
  }

  void _openPhotoTuningSheet() {
    AppBottomSheets.show(
      context: context,
      builder: (BuildContext sheetCtx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setSheetState) {
            final scheme = Theme.of(ctx).colorScheme;
            final textTheme = Theme.of(ctx).textTheme;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    context.l10n.wallpaperMyPhoto,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${context.l10n.wallpaperPhotoBlur} (${_draftConfig.imageBlur.toStringAsFixed(1)} dp)',
                    style: textTheme.labelLarge,
                  ),
                  Slider(
                    value: _draftConfig.imageBlur,
                    min: 0.0,
                    max: 20.0,
                    divisions: 20,
                    onChanged: (val) {
                      _throttledHaptic();
                      _updateDraft(_draftConfig.copyWith(imageBlur: val));
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${context.l10n.wallpaperPhotoDim} (${(_draftConfig.imageDim * 100).round()}%)',
                    style: textTheme.labelLarge,
                  ),
                  Slider(
                    value: _draftConfig.imageDim,
                    min: 0.0,
                    max: 0.8,
                    divisions: 16,
                    onChanged: (val) {
                      _throttledHaptic();
                      _updateDraft(_draftConfig.copyWith(imageDim: val));
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(sheetCtx).pop();
                            _pickCustomPhoto();
                          },
                          icon: const Icon(Icons.photo_library_rounded, size: 18),
                          label: Text(context.l10n.wallpaperChoosePhoto),
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
                            _updateDraft(_draftConfig.copyWith(clearImagePath: true));
                            Navigator.of(sheetCtx).pop();
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: Text(context.l10n.wallpaperRemovePhoto),
                          style: FilledButton.styleFrom(
                            shape: RoundedSuperellipseBorder(
                              borderRadius: AppRadii.lgRadius,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openCustomGlyphPicker(BuildContext context, ColorScheme scheme) {
    HapticService.tap();
    final List<String> catalog = switch (_draftConfig.iconSource) {
      IconSource.lucide => IconSourcesCatalog.lucideIcons,
      IconSource.tabler => IconSourcesCatalog.tablerIcons,
      IconSource.cupertino => CupertinoIconsData.allNames,
      _ => MaterialSymbolsData.allNames,
    };

    final Set<String> selected = Set<String>.from(_draftConfig.selectedGlyphs);
    String filterQuery = '';

    AppBottomSheets.show(
      context: context,
      builder: (BuildContext sheetCtx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            final textTheme = Theme.of(ctx).textTheme;
            final List<String> matches = filterQuery.isEmpty
                ? catalog.take(90).toList()
                : catalog
                    .where((s) => s.toLowerCase().contains(filterQuery))
                    .take(90)
                    .toList();

            return Container(
              height: MediaQuery.sizeOf(ctx).height * 0.75,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        '${context.l10n.wallpaperCustomSetTitle} (${selected.length} / 12)',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: selected.isEmpty
                            ? null
                            : () {
                                _updateDraft(
                                  _draftConfig.copyWith(
                                    selectedGlyphs: selected.toList(),
                                    themePack: 'custom',
                                  ),
                                );
                                Navigator.of(sheetCtx).pop();
                              },
                        child: Text(
                          context.l10n.wallpaperSaveSet,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (val) {
                      setModalState(() {
                        filterQuery = val.trim().toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: context.l10n.wallpaperSearchGlyphs,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppRadii.lgRadius,
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      itemCount: matches.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.0,
                      ),
                      itemBuilder: (context, index) {
                        final String name = matches[index];
                        final bool isChecked = selected.contains(name);

                        return TouchContainer(
                          borderRadius: AppRadii.mdRadius,
                          onTap: () {
                            HapticService.tap();
                            setModalState(() {
                              if (isChecked) {
                                selected.remove(name);
                              } else {
                                if (selected.length < 12) {
                                  selected.add(name);
                                } else {
                                  AppToast.showInfo(
                                    ctx,
                                    context.l10n.wallpaperCustomSetLimit,
                                  );
                                }
                              }
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isChecked
                                  ? scheme.primaryContainer
                                  : scheme.surfaceContainerHigh,
                              borderRadius: AppRadii.mdRadius,
                              border: Border.all(
                                color: isChecked
                                    ? scheme.primary
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: <Widget>[
                                _renderMiniThumbnail(name, scheme),
                                if (isChecked)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: scheme.primary,
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
  }

  Widget _renderMiniThumbnail(String name, ColorScheme scheme) {
    if (_draftConfig.iconSource == IconSource.lucide ||
        _draftConfig.iconSource == IconSource.tabler) {
      final String folder =
          _draftConfig.iconSource == IconSource.lucide ? 'lucide' : 'tabler';
      return SvgPicture.asset(
        'assets/svg/pattern_icons/$folder/$name.svg',
        width: 22,
        height: 22,
        colorFilter: ColorFilter.mode(scheme.onSurface, BlendMode.srcIn),
      );
    } else if (_draftConfig.iconSource == IconSource.cupertino) {
      final int? code = CupertinoIconsData.codepoints[name];
      if (code == null) {
        return Icon(Icons.star_rounded, size: 20, color: scheme.onSurface);
      }
      return SizedBox(
        width: 20,
        height: 20,
        child: Center(
          child: Text(
            String.fromCharCode(code),
            style: TextStyle(
              fontFamily: 'CupertinoIcons',
              package: 'cupertino_icons',
              fontSize: 20,
              height: 1.0,
              color: scheme.onSurface,
            ),
          ),
        ),
      );
    } else {
      final int? code = MaterialSymbolsData.codepoints[name];
      if (code == null) {
        return Icon(Icons.star_rounded, size: 20, color: scheme.onSurface);
      }
      return SizedBox(
        width: 20,
        height: 20,
        child: Center(
          child: Text(
            String.fromCharCode(code),
            style: TextStyle(
              fontFamily: 'MaterialSymbolsRounded',
              fontSize: 20,
              height: 1.0,
              color: scheme.onSurface,
            ),
          ),
        ),
      );
    }
  }

  void _openPatternEditorSheet() {
    AppBottomSheets.show(
      context: context,
      builder: (BuildContext sheetCtx) {
        return _WallpaperEditorSheet(
          draftConfig: _draftConfig,
          onUpdateDraft: _updateDraft,
          onOpenCustomGlyphPicker: () =>
              _openCustomGlyphPicker(context, Theme.of(context).colorScheme),
          onThrottledHaptic: _throttledHaptic,
        );
      },
    );
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Context switcher if editing in a chat
              if (widget.chatId != null) ...[
                SegmentedButton<bool>(
                  segments: <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: true,
                      label: Text(context.l10n.wallpaperForThisChat),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text(context.l10n.wallpaperForAllChats),
                      icon: const Icon(Icons.public_rounded, size: 16),
                    ),
                  ],
                  selected: <bool>{_editingThisChatOnly},
                  onSelectionChanged: (Set<bool> sel) {
                    HapticService.tap();
                    setState(() {
                      _editingThisChatOnly = sel.first;
                    });
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Live Preview Card
              Container(
                height: 280,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: AppRadii.xlRadius,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _buildLivePreviewWithReveal(scheme),
                    if (_showChatMockup) const _ChatMockupView(),
                    // Top controls
                    Positioned(
                      top: 10,
                      left: 10,
                      child: IconButton.filledTonal(
                        tooltip: context.l10n.wallpaperMockupToggle,
                        onPressed: () {
                          HapticService.tap();
                          setState(() => _showChatMockup = !_showChatMockup);
                        },
                        icon: Icon(
                          _showChatMockup
                              ? Icons.chat_bubble_rounded
                              : Icons.chat_bubble_outline_rounded,
                          size: 18,
                        ),
                      ),
                    ),
                    // Customize Button
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: FilledButton.tonalIcon(
                        onPressed: _openPatternEditorSheet,
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: Text(context.l10n.wallpaperCustomize),
                        style: FilledButton.styleFrom(
                          shape: RoundedSuperellipseBorder(
                            borderRadius: AppRadii.lgRadius,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Preset Wallpapers & My Photo Carousel
              Text(
                context.l10n.wallpaperTabPattern,
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    // Card 1: My Photo
                    _MyPhotoThumbnailCard(
                      imagePath: _draftConfig.imagePath,
                      onTap: _pickCustomPhoto,
                      onSettingsTap: _draftConfig.imagePath != null
                          ? _openPhotoTuningSheet
                          : null,
                    ),
                    const SizedBox(width: 10),

                    // Cards 2..8: Presets with live rendered miniatures
                    ...kDefaultWallpaperPresets.map((preset) {
                      final bool isSelected = _draftConfig.imagePath == null &&
                          _draftConfig.seed == preset.config.seed &&
                          _draftConfig.iconSource == preset.config.iconSource &&
                          _draftConfig.themePack == preset.config.themePack &&
                          _draftConfig.backgroundStyle == preset.config.backgroundStyle;

                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _PresetThumbnailCard(
                          preset: preset,
                          isSelected: isSelected,
                          onTap: () {
                            TriSync.pop(context: context);
                            _updateDraft(preset.config, triggerReveal: true);
                          },
                        ),
                      );
                    }),

                    // Card 9: Custom Set
                    _CustomPatternCard(
                      isSelected: _draftConfig.themePack == 'custom',
                      onTap: () {
                        _openCustomGlyphPicker(context, scheme);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
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
        // MOM-6: Spatial expansion reveal originating from the thumbnail carousel below
        return ClipRRect(
          borderRadius: BorderRadius.circular(24.0 * (1.0 - t * 0.5)),
          child: Transform.scale(
            scale: 0.93 + 0.07 * t,
            alignment: Alignment.bottomCenter,
            child: Opacity(
              opacity: (0.35 + 0.65 * t).clamp(0.0, 1.0),
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
      size: const Size(double.infinity, 280),
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

class _PresetThumbnailCard extends StatelessWidget {
  const _PresetThumbnailCard({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  final ChatWallpaperPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      selected: isSelected,
      button: true,
      label: _presetName(context, preset.id),
      child: TouchContainer(
        onTap: onTap,
        borderRadius: AppRadii.lgRadius,
        scaleDown: 0.92,
        releaseCurve: M3SpringCurves.bouncy,
        child: AnimatedContainer(
          duration: M3Durations.medium1,
          curve: M3SpringCurves.spatial,
          width: 104,
          height: 156,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: AppRadii.lgRadius,
            border: Border.all(
              color: isSelected
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.4),
              width: isSelected ? 2.5 : 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              FutureBuilder<ui.Image?>(
                future: WallpaperImageCache.render(
                  config: preset.config,
                  scheme: scheme,
                  size: const Size(104, 156),
                  pixelRatio: 1.0,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return RawImage(
                      image: snapshot.data,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    );
                  }
                  return Container(
                    color: scheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(
                      preset.icon,
                      size: 24,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: <Color>[
                        Colors.black.withValues(alpha: 0.75),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Text(
                    _presetName(context, preset.id),
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyPhotoThumbnailCard extends StatelessWidget {
  const _MyPhotoThumbnailCard({
    required this.imagePath,
    required this.onTap,
    required this.onSettingsTap,
  });

  final String? imagePath;
  final VoidCallback onTap;
  final VoidCallback? onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bool hasPhoto = imagePath != null && imagePath!.isNotEmpty;

    return Semantics(
      button: true,
      label: context.l10n.wallpaperMyPhoto,
      child: TouchContainer(
        onTap: onTap,
        borderRadius: AppRadii.lgRadius,
        child: Container(
          width: 104,
          height: 156,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: AppRadii.lgRadius,
            border: Border.all(
              color: hasPhoto
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.4),
              width: hasPhoto ? 2.5 : 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (hasPhoto && io.File(imagePath!).existsSync())
                Image.file(
                  io.File(imagePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildPlaceholder(scheme),
                )
              else
                _buildPlaceholder(scheme),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: <Color>[
                        Colors.black.withValues(alpha: 0.75),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Text(
                    context.l10n.wallpaperMyPhoto,
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight:
                          hasPhoto ? FontWeight.bold : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              if (hasPhoto)
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    onPressed: onSettingsTap,
                    icon: const Icon(Icons.tune_rounded, size: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme scheme) {
    return Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.add_photo_alternate_rounded,
        size: 28,
        color: scheme.primary,
      ),
    );
  }
}

class _CustomPatternCard extends StatelessWidget {
  const _CustomPatternCard({
    required this.isSelected,
    required this.onTap,
  });

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: isSelected,
      label: context.l10n.wallpaperPackCustom,
      child: TouchContainer(
        onTap: onTap,
        borderRadius: AppRadii.lgRadius,
        child: Container(
          width: 104,
          height: 156,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: AppRadii.lgRadius,
            border: Border.all(
              color: isSelected
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.4),
              width: isSelected ? 2.5 : 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Container(
                color: scheme.surfaceContainerHigh,
                alignment: Alignment.center,
                child: Icon(
                  Icons.draw_rounded,
                  size: 28,
                  color: scheme.primary,
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: <Color>[
                        Colors.black.withValues(alpha: 0.75),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Text(
                    context.l10n.wallpaperPackCustom,
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
                color: scheme.surfaceContainerHighest,
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
                color: scheme.primaryContainer,
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
                          color: scheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.done_all_rounded,
                        size: 14,
                        color: scheme.onPrimaryContainer
                            .withValues(alpha: 0.7),
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

class _WallpaperEditorSheet extends StatefulWidget {
  const _WallpaperEditorSheet({
    required this.draftConfig,
    required this.onUpdateDraft,
    required this.onOpenCustomGlyphPicker,
    required this.onThrottledHaptic,
  });

  final ChatWallpaperConfig draftConfig;
  final ValueChanged<ChatWallpaperConfig> onUpdateDraft;
  final VoidCallback onOpenCustomGlyphPicker;
  final VoidCallback onThrottledHaptic;

  @override
  State<_WallpaperEditorSheet> createState() => _WallpaperEditorSheetState();
}

class _WallpaperEditorSheetState extends State<_WallpaperEditorSheet> {
  int _selectedTabIndex = 0;
  bool _isAdvancedExpanded = false;

  static const List<IconSource> _kSources = <IconSource>[
    IconSource.materialSymbols,
    IconSource.lucide,
    IconSource.tabler,
    IconSource.cupertino,
    IconSource.niosMess,
  ];

  static const List<String> _kPacks = <String>[
    'all',
    'chat',
    'tech',
    'space',
    'food',
    'nature',
    'minimal',
    'custom',
  ];

  static const List<WallpaperLayoutMode> _kLayoutModes = <WallpaperLayoutMode>[
    WallpaperLayoutMode.grid,
    WallpaperLayoutMode.stagger,
    WallpaperLayoutMode.scatter,
    WallpaperLayoutMode.hex,
    WallpaperLayoutMode.spiral,
  ];

  static const List<String> _kBgRoles = <String>[
    'surfaceContainerLowest',
    'surfaceContainerLow',
    'surfaceContainer',
    'surfaceContainerHigh',
    'primaryContainer',
    'secondaryContainer',
    'tertiaryContainer',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cfg = widget.draftConfig;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.65,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SegmentedButton<int>(
            segments: <ButtonSegment<int>>[
              ButtonSegment<int>(
                value: 0,
                label: Text(context.l10n.wallpaperTabPattern),
                icon: const Icon(Icons.grid_on_rounded, size: 16),
              ),
              ButtonSegment<int>(
                value: 1,
                label: Text(context.l10n.wallpaperTabColors),
                icon: const Icon(Icons.palette_rounded, size: 16),
              ),
              ButtonSegment<int>(
                value: 2,
                label: Text(context.l10n.wallpaperTabGeometry),
                icon: const Icon(Icons.category_rounded, size: 16),
              ),
            ],
            selected: <int>{_selectedTabIndex},
            onSelectionChanged: (Set<int> sel) {
              HapticService.tap();
              setState(() => _selectedTabIndex = sel.first);
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: switch (_selectedTabIndex) {
                0 => _buildPatternTab(scheme, textTheme, cfg),
                1 => _buildColorsTab(scheme, textTheme, cfg),
                _ => _buildGeometryTab(scheme, textTheme, cfg),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternTab(
    ColorScheme scheme,
    TextTheme textTheme,
    ChatWallpaperConfig cfg,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.wallpaperTabPattern,
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kSources.map((source) {
            final bool isSelected = cfg.iconSource == source;
            return ChoiceChip(
              label: Text(_sourceName(context, source)),
              selected: isSelected,
              onSelected: (bool sel) {
                if (sel) {
                  HapticService.tap();
                  widget.onUpdateDraft(cfg.copyWith(iconSource: source));
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.wallpaperPresetCosmos,
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kPacks.map((pack) {
            final bool isSelected = cfg.themePack == pack;
            return ChoiceChip(
              label: Text(_packName(context, pack)),
              selected: isSelected,
              onSelected: (bool sel) {
                if (sel) {
                  HapticService.tap();
                  if (pack == 'custom') {
                    widget.onOpenCustomGlyphPicker();
                  } else {
                    widget.onUpdateDraft(
                      cfg.copyWith(
                        themePack: pack,
                        useAllIcons: pack == 'all',
                      ),
                    );
                  }
                }
              },
            );
          }).toList(),
        ),
        if (cfg.themePack == 'custom') ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.onOpenCustomGlyphPicker,
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: Text(
              '${context.l10n.wallpaperCustomSetTitle} (${cfg.selectedGlyphs.length})',
            ),
            style: OutlinedButton.styleFrom(
              shape: RoundedSuperellipseBorder(
                borderRadius: AppRadii.lgRadius,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildColorsTab(
    ColorScheme scheme,
    TextTheme textTheme,
    ChatWallpaperConfig cfg,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.wallpaperBgGradient,
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SegmentedButton<WallpaperBackgroundStyle>(
          segments: WallpaperBackgroundStyle.values.map((style) {
            return ButtonSegment<WallpaperBackgroundStyle>(
              value: style,
              label: Text(_bgStyleName(context, style)),
            );
          }).toList(),
          selected: <WallpaperBackgroundStyle>{cfg.backgroundStyle},
          onSelectionChanged: (Set<WallpaperBackgroundStyle> sel) {
            HapticService.tap();
            widget.onUpdateDraft(cfg.copyWith(backgroundStyle: sel.first));
          },
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.wallpaperBaseColor,
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildColorDotsRow(
          scheme: scheme,
          selectedRole: cfg.backgroundRole,
          onSelected: (role) {
            HapticService.tap();
            widget.onUpdateDraft(cfg.copyWith(backgroundRole: role));
          },
        ),
        if (cfg.backgroundStyle != WallpaperBackgroundStyle.solid) ...[
          const SizedBox(height: 16),
          Text(
            context.l10n.wallpaperSecondaryColor,
            style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildColorDotsRow(
            scheme: scheme,
            selectedRole: cfg.backgroundSecondaryRole,
            onSelected: (role) {
              HapticService.tap();
              widget.onUpdateDraft(cfg.copyWith(backgroundSecondaryRole: role));
            },
          ),
        ],
        const SizedBox(height: 16),
        Text(
          context.l10n.wallpaperColorModePalette,
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SegmentedButton<WallpaperColorMode>(
          segments: WallpaperColorMode.values.map((mode) {
            return ButtonSegment<WallpaperColorMode>(
              value: mode,
              label: Text(_colorModeName(context, mode)),
            );
          }).toList(),
          selected: <WallpaperColorMode>{cfg.colorMode},
          onSelectionChanged: (Set<WallpaperColorMode> sel) {
            HapticService.tap();
            widget.onUpdateDraft(cfg.copyWith(colorMode: sel.first));
          },
        ),
        const SizedBox(height: 16),
        Text(
          '${context.l10n.wallpaperOpacity} (${(cfg.iconAlpha * 100).round()}%)',
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Slider(
          value: cfg.iconAlpha,
          min: 0.04,
          max: 0.40,
          divisions: 18,
          onChanged: (val) {
            widget.onThrottledHaptic();
            widget.onUpdateDraft(cfg.copyWith(iconAlpha: val));
          },
        ),
      ],
    );
  }

  Widget _buildGeometryTab(
    ColorScheme scheme,
    TextTheme textTheme,
    ChatWallpaperConfig cfg,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.wallpaperTabGeometry,
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kLayoutModes.map((mode) {
            final bool isSelected = cfg.layoutMode == mode;
            return ChoiceChip(
              label: Text(_layoutName(context, mode)),
              selected: isSelected,
              onSelected: (bool sel) {
                if (sel) {
                  HapticService.tap();
                  widget.onUpdateDraft(cfg.copyWith(layoutMode: mode));
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text(
          '${context.l10n.wallpaperCellSize} (${cfg.cellSize.round()} dp)',
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Slider(
          value: cfg.cellSize,
          min: 36.0,
          max: 120.0,
          divisions: 21,
          onChanged: (val) {
            widget.onThrottledHaptic();
            widget.onUpdateDraft(cfg.copyWith(cellSize: val));
          },
        ),
        const SizedBox(height: 12),
        Text(
          '${context.l10n.wallpaperDensity} (${(cfg.density * 100).round()}%)',
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Slider(
          value: cfg.density,
          min: 0.30,
          max: 1.0,
          divisions: 14,
          onChanged: (val) {
            widget.onThrottledHaptic();
            widget.onUpdateDraft(cfg.copyWith(density: val));
          },
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.wallpaperFilled, style: textTheme.bodyMedium),
          value: cfg.filled,
          onChanged: (val) {
            HapticService.tap();
            widget.onUpdateDraft(cfg.copyWith(filled: val));
          },
        ),
        const Divider(),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              context.l10n.wallpaperAdvanced,
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            initiallyExpanded: _isAdvancedExpanded,
            onExpansionChanged: (val) => setState(() => _isAdvancedExpanded = val),
            children: <Widget>[
              const SizedBox(height: 8),
              Text(
                '${context.l10n.wallpaperGridAngle} (${cfg.gridAngle.round()}°)',
                style: textTheme.labelLarge,
              ),
              Slider(
                value: cfg.gridAngle,
                min: -45.0,
                max: 45.0,
                divisions: 18,
                onChanged: (val) {
                  widget.onThrottledHaptic();
                  widget.onUpdateDraft(cfg.copyWith(gridAngle: val));
                },
              ),
              const SizedBox(height: 8),
              Text(
                '${context.l10n.wallpaperRandomRotation} (${cfg.randomRotationDeg.round()}°)',
                style: textTheme.labelLarge,
              ),
              Slider(
                value: cfg.randomRotationDeg,
                min: 0.0,
                max: 60.0,
                divisions: 12,
                onChanged: (val) {
                  widget.onThrottledHaptic();
                  widget.onUpdateDraft(cfg.copyWith(randomRotationDeg: val));
                },
              ),
              const SizedBox(height: 8),
              Text(
                '${context.l10n.wallpaperRandomScale} (${(cfg.randomScaleJitter * 100).round()}%)',
                style: textTheme.labelLarge,
              ),
              Slider(
                value: cfg.randomScaleJitter,
                min: 0.0,
                max: 0.40,
                divisions: 8,
                onChanged: (val) {
                  widget.onThrottledHaptic();
                  widget.onUpdateDraft(cfg.copyWith(randomScaleJitter: val));
                },
              ),
              if (cfg.iconSource == IconSource.materialSymbols) ...[
                const SizedBox(height: 8),
                Text(context.l10n.wallpaperSourceMaterial, style: textTheme.labelLarge),
                const SizedBox(height: 6),
                Row(
                  children: MaterialSymbolsStyle.values.map((style) {
                    final bool isSelected = cfg.symbolsStyle == style;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: isSelected,
                        label: Text(style.name),
                        onSelected: (bool sel) {
                          if (sel) {
                            HapticService.tap();
                            widget.onUpdateDraft(cfg.copyWith(symbolsStyle: style));
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  '${context.l10n.wallpaperWeight} (${cfg.weight.round()})',
                  style: textTheme.labelLarge,
                ),
                Slider(
                  value: cfg.weight,
                  min: 100.0,
                  max: 700.0,
                  divisions: 6,
                  onChanged: (val) {
                    widget.onThrottledHaptic();
                    widget.onUpdateDraft(cfg.copyWith(weight: val));
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColorDotsRow({
    required ColorScheme scheme,
    required String selectedRole,
    required ValueChanged<String> onSelected,
  }) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _kBgRoles.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final String role = _kBgRoles[index];
          final Color color = WallpaperColorResolver.resolveBackground(scheme, role);
          final bool isSelected = selectedRole == role;

          return TouchContainer(
            onTap: () => onSelected(role),
            borderRadius: AppRadii.fullRadius,
            child: Container(
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

String _presetName(BuildContext context, String id) {
  final l10n = context.l10n;
  return switch (id) {
    'cosmos' => l10n.wallpaperPresetCosmos,
    'cyberpunk' => l10n.wallpaperPresetCyberpunk,
    'sunset' => l10n.wallpaperPresetSunset,
    'oled_minimal' => l10n.wallpaperPresetOled,
    'cupertino' => l10n.wallpaperPresetCupertino,
    'pastel' => l10n.wallpaperPresetPastel,
    'nios_matrix' => l10n.wallpaperPresetMatrix,
    _ => id,
  };
}

String _packName(BuildContext context, String pack) {
  final l10n = context.l10n;
  return switch (pack) {
    'all' => l10n.wallpaperPackAll,
    'chat' => l10n.wallpaperPackChat,
    'tech' => l10n.wallpaperPackTech,
    'space' => l10n.wallpaperPackSpace,
    'food' => l10n.wallpaperPackFood,
    'nature' => l10n.wallpaperPackNature,
    'minimal' => l10n.wallpaperPackMinimal,
    'custom' => l10n.wallpaperPackCustom,
    _ => pack,
  };
}

String _sourceName(BuildContext context, IconSource source) {
  final l10n = context.l10n;
  return switch (source) {
    IconSource.materialSymbols => l10n.wallpaperSourceMaterial,
    IconSource.lucide => l10n.wallpaperSourceLucide,
    IconSource.tabler => l10n.wallpaperSourceTabler,
    IconSource.cupertino => l10n.wallpaperSourceCupertino,
    IconSource.niosMess => l10n.wallpaperSourceShapes,
    IconSource.phosphor => 'Phosphor',
  };
}

String _layoutName(BuildContext context, WallpaperLayoutMode mode) {
  final l10n = context.l10n;
  return switch (mode) {
    WallpaperLayoutMode.grid => l10n.wallpaperLayoutGrid,
    WallpaperLayoutMode.stagger => l10n.wallpaperLayoutStagger,
    WallpaperLayoutMode.scatter => l10n.wallpaperLayoutScatter,
    WallpaperLayoutMode.hex => l10n.wallpaperLayoutHex,
    WallpaperLayoutMode.spiral => l10n.wallpaperLayoutSpiral,
  };
}

String _bgStyleName(BuildContext context, WallpaperBackgroundStyle style) {
  final l10n = context.l10n;
  return switch (style) {
    WallpaperBackgroundStyle.solid => l10n.wallpaperBgSolid,
    WallpaperBackgroundStyle.linearGradient => l10n.wallpaperBgGradient,
    WallpaperBackgroundStyle.radialGlow => l10n.wallpaperBgGlow,
  };
}

String _colorModeName(BuildContext context, WallpaperColorMode mode) {
  final l10n = context.l10n;
  return switch (mode) {
    WallpaperColorMode.singleTone => l10n.wallpaperColorModeSingle,
    WallpaperColorMode.tonalAccent => l10n.wallpaperColorModeAccents,
    WallpaperColorMode.palette => l10n.wallpaperColorModePalette,
  };
}

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
