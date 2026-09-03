import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';
import 'package:pulse_flutter/providers/chat_wallpaper_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/wallpaper/chat_wallpaper_painter.dart';
import 'package:pulse_flutter/widgets/wallpaper/icon_sources_catalog.dart';
import 'package:pulse_flutter/widgets/wallpaper/material_symbols_data.dart';
import 'package:pulse_flutter/widgets/wallpaper/wallpaper_color_resolver.dart';

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
    extends ConsumerState<SettingsWallpaperScreen> {
  late ChatWallpaperConfig _config;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  ui.Picture? _previewSvgPicture;
  List<ui.Picture>? _previewPoolSvgPictures;

  @override
  void initState() {
    super.initState();
    final ChatWallpaperState wallpaperState = ref.read(chatWallpaperProvider);
    _config = wallpaperState.forChat(widget.chatId);
    _loadSvgPreviewIfNeeded();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSvgPreviewIfNeeded() async {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color iconColor = WallpaperColorResolver.resolveIconColor(
      scheme,
      _config.iconColorRole,
      _config.iconAlpha,
    );

    if (_config.useAllIcons &&
        (_config.iconSource == IconSource.lucide ||
            _config.iconSource == IconSource.tabler)) {
      final List<String> catalog = _config.iconSource == IconSource.lucide
          ? IconSourcesCatalog.lucideIcons
          : IconSourcesCatalog.tablerIcons;
      final String folder =
          _config.iconSource == IconSource.lucide ? 'lucide' : 'tabler';

      final List<ui.Picture> pool = <ui.Picture>[];
      final Random rng = Random(_config.seed);
      final int count = min(24, catalog.length);
      for (int i = 0; i < count; i++) {
        final String name = catalog[rng.nextInt(catalog.length)];
        try {
          final PictureInfo info = await vg.loadPicture(
            SvgAssetLoader(
              'assets/svg/pattern_icons/$folder/$name.svg',
              theme: SvgTheme(currentColor: iconColor),
            ),
            null,
          );
          pool.add(info.picture);
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _previewPoolSvgPictures = pool;
          _previewSvgPicture = null;
        });
      }
      return;
    }

    if (_config.svgAssetPath != null && _config.svgAssetPath!.isNotEmpty) {
      try {
        final PictureInfo info = await vg.loadPicture(
          SvgAssetLoader(
            _config.svgAssetPath!,
            theme: SvgTheme(currentColor: iconColor),
          ),
          null,
        );
        if (mounted) {
          setState(() {
            _previewSvgPicture = info.picture;
            _previewPoolSvgPictures = null;
          });
        }
      } catch (_) {}
    } else {
      if (_previewSvgPicture != null || _previewPoolSvgPictures != null) {
        setState(() {
          _previewSvgPicture = null;
          _previewPoolSvgPictures = null;
        });
      }
    }
  }

  void _updateConfig(ChatWallpaperConfig newConfig) {
    setState(() {
      _config = newConfig;
    });
    _saveConfig(newConfig);
    _loadSvgPreviewIfNeeded();
  }

  void _saveConfig(ChatWallpaperConfig newConfig) {
    final notifier = ref.read(chatWallpaperProvider.notifier);
    if (widget.chatId != null) {
      notifier.setChatWallpaper(widget.chatId!, newConfig);
    } else {
      notifier.updateGlobalConfig(newConfig);
    }
  }

  void _resetConfig() {
    HapticService.tap();
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

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final String screenTitle = widget.chatId != null
        ? 'Обои чата: ${widget.chatTitle ?? widget.chatId}'
        : 'Фон чатов';

    return SettingsScaffold(
      title: screenTitle,
      isEmbedded: widget.isEmbedded,
      children: <Widget>[
        // 1. Live Interactive Preview Canvas Card
        _buildPreviewCard(scheme, isDark),

        const SizedBox(height: 18),

        // 2. Icon Source Selector (Material Symbols, Lucide, Tabler, NiosMess)
        _buildSourceSelector(scheme, textTheme),

        const SizedBox(height: 14),

        // 3. Icon / Glyph Picker
        _buildIconPicker(scheme, textTheme),

        const SizedBox(height: 14),

        // 4. Layout Mode Selector (5 Modes)
        _buildLayoutSelector(scheme, textTheme),

        const SizedBox(height: 14),

        // 5. Geometry and Dynamics Sliders
        _buildGeometrySliders(scheme, textTheme),

        const SizedBox(height: 14),

        // 6. Color Role and Palette Selector
        _buildColorModeSection(scheme, textTheme),

        const SizedBox(height: 20),

        // 7. Reset to default button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: _resetConfig,
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text(
              widget.chatId != null
                  ? 'Сбросить к глобальному фону'
                  : 'Сбросить обои по умолчанию',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),

        const SizedBox(height: 36),
      ],
    );
  }

  Widget _buildPreviewCard(ColorScheme scheme, bool isDark) {
    return Container(
      height: 210,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Stack(
          children: <Widget>[
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
            // Dummy chat bubbles overlay to preview contrast
            Positioned(
              left: 16,
              bottom: 64,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  'Привет! Как тебе новый фон?',
                  style: TextStyle(color: scheme.onSurface, fontSize: 13),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    scheme.primary.withValues(alpha: 0.16),
                    scheme.surface,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  'Выглядит супер выразительно! ✨',
                  style: TextStyle(color: scheme.onSurface, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceSelector(ColorScheme scheme, TextTheme textTheme) {
    return SettingsSection(
      title: 'Источник иконок',
      subtitle: 'Выберите библиотеку или фирменные формы для паттерна',
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: SegmentedButton<IconSource>(
            segments: const <ButtonSegment<IconSource>>[
              ButtonSegment<IconSource>(
                value: IconSource.materialSymbols,
                label: Text('Material'),
                icon: Icon(Icons.star_outline_rounded, size: 16),
              ),
              ButtonSegment<IconSource>(
                value: IconSource.lucide,
                label: Text('Lucide'),
                icon: Icon(Icons.auto_awesome_rounded, size: 16),
              ),
              ButtonSegment<IconSource>(
                value: IconSource.tabler,
                label: Text('Tabler'),
                icon: Icon(Icons.category_rounded, size: 16),
              ),
              ButtonSegment<IconSource>(
                value: IconSource.niosMess,
                label: Text('Nios'),
                icon: Icon(Icons.shield_outlined, size: 16),
              ),
            ],
            selected: <IconSource>{_config.iconSource},
            onSelectionChanged: (Set<IconSource> val) {
              HapticService.tap();
              final IconSource src = val.first;
              String defaultGlyph = 'star';
              int defaultCode = 0xe838;
              String? svgPath;
              String? shapeName;

              if (src == IconSource.materialSymbols) {
                defaultGlyph = 'star';
                defaultCode = 0xe838;
              } else if (src == IconSource.lucide) {
                defaultGlyph = 'sparkles';
                svgPath = 'assets/svg/pattern_icons/lucide/sparkles.svg';
              } else if (src == IconSource.tabler) {
                defaultGlyph = 'sparkles';
                svgPath = 'assets/svg/pattern_icons/tabler/sparkles.svg';
              } else if (src == IconSource.niosMess) {
                defaultGlyph = 'm3_gem';
                shapeName = 'gem';
              }

              _updateConfig(
                _config.copyWith(
                  iconSource: src,
                  glyphName: defaultGlyph,
                  glyphCodepoint: defaultCode,
                  svgAssetPath: svgPath,
                  m3ShapeName: shapeName,
                ),
              );
            },
          ),
        ),
        if (_config.iconSource == IconSource.materialSymbols) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: <Widget>[
                const Text('Стиль:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<MaterialSymbolsStyle>(
                    segments: const <ButtonSegment<MaterialSymbolsStyle>>[
                      ButtonSegment<MaterialSymbolsStyle>(
                        value: MaterialSymbolsStyle.rounded,
                        label: Text('Rounded'),
                      ),
                      ButtonSegment<MaterialSymbolsStyle>(
                        value: MaterialSymbolsStyle.outlined,
                        label: Text('Outlined'),
                      ),
                      ButtonSegment<MaterialSymbolsStyle>(
                        value: MaterialSymbolsStyle.sharp,
                        label: Text('Sharp'),
                      ),
                    ],
                    selected: <MaterialSymbolsStyle>{_config.symbolsStyle},
                    onSelectionChanged: (Set<MaterialSymbolsStyle> val) {
                      HapticService.tap();
                      _updateConfig(_config.copyWith(symbolsStyle: val.first));
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIconPicker(ColorScheme scheme, TextTheme textTheme) {
    List<String> items = <String>[];
    if (_config.iconSource == IconSource.materialSymbols) {
      items = MaterialSymbolsData.allNames;
    } else if (_config.iconSource == IconSource.lucide) {
      items = IconSourcesCatalog.lucideIcons;
    } else if (_config.iconSource == IconSource.tabler) {
      items = IconSourcesCatalog.tablerIcons;
    } else if (_config.iconSource == IconSource.niosMess) {
      items = IconSourcesCatalog.niosMessItems;
    }

    final String query = _searchQuery.trim().toLowerCase();
    final List<String> filtered = query.isEmpty
        ? items.take(48).toList(growable: false)
        : items.where((name) => name.toLowerCase().contains(query)).take(48).toList(growable: false);

    return SettingsSection(
      title: 'Выбор глифов (${items.length} доступно)',
      subtitle: _config.useAllIcons
          ? 'Активны все иконки библиотеки (Telegram-стиль)'
          : 'Текущий: ${_config.glyphName}',
      children: <Widget>[
        SettingsSwitchTile(
          icon: Icons.auto_awesome_motion_rounded,
          title: 'Все иконки сразу (стиль Telegram)',
          subtitle: 'Рассеять все различные иконки из набора по фону чата',
          value: _config.useAllIcons,
          onChanged: (bool val) {
            HapticService.tap();
            _updateConfig(_config.copyWith(useAllIcons: val));
          },
        ),
        if (_config.useAllIcons)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.check_circle_rounded, size: 20, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Все ${items.length} иконок активны одновременно! Каждая клетка фона случайно выбирает отдельный символ.',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск одной конкретной иконки...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (String val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),
          SizedBox(
            height: 68,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int index) {
                final String name = filtered[index];
                final bool isSelected = _config.glyphName == name;

                return InkWell(
                  onTap: () {
                    HapticService.tap();
                    _selectGlyph(name);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 58,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? scheme.primary.withValues(alpha: 0.18)
                          : scheme.surfaceContainerHigh.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? scheme.primary
                            : scheme.outlineVariant.withValues(alpha: 0.2),
                        width: isSelected ? 2.0 : 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        _renderGlyphThumbnail(name, scheme),
                        const SizedBox(height: 2),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 8,
                            color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                            overflow: TextOverflow.ellipsis,
                          ),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  void _selectGlyph(String name) {
    if (_config.iconSource == IconSource.materialSymbols) {
      final int code = MaterialSymbolsData.codepoints[name] ?? 0xe838;
      _updateConfig(
        _config.copyWith(
          glyphName: name,
          glyphCodepoint: code,
          svgAssetPath: null,
          m3ShapeName: null,
          useAllIcons: false,
        ),
      );
    } else if (_config.iconSource == IconSource.lucide) {
      _updateConfig(
        _config.copyWith(
          glyphName: name,
          svgAssetPath: 'assets/svg/pattern_icons/lucide/$name.svg',
          m3ShapeName: null,
          useAllIcons: false,
        ),
      );
    } else if (_config.iconSource == IconSource.tabler) {
      _updateConfig(
        _config.copyWith(
          glyphName: name,
          svgAssetPath: 'assets/svg/pattern_icons/tabler/$name.svg',
          m3ShapeName: null,
          useAllIcons: false,
        ),
      );
    } else if (_config.iconSource == IconSource.niosMess) {
      if (name.startsWith('m3_')) {
        final shapeName = name.replaceFirst('m3_', '');
        _updateConfig(
          _config.copyWith(
            glyphName: name,
            m3ShapeName: shapeName,
            svgAssetPath: null,
            useAllIcons: false,
          ),
        );
      } else {
        _updateConfig(
          _config.copyWith(
            glyphName: name,
            svgAssetPath: 'assets/svg/$name.svg',
            m3ShapeName: null,
            useAllIcons: false,
          ),
        );
      }
    }
  }

  Widget _renderGlyphThumbnail(String name, ColorScheme scheme) {
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
    } else if (_config.iconSource == IconSource.lucide ||
        _config.iconSource == IconSource.tabler) {
      final String folder =
          _config.iconSource == IconSource.lucide ? 'lucide' : 'tabler';
      return SvgPicture.asset(
        'assets/svg/pattern_icons/$folder/$name.svg',
        width: 22,
        height: 22,
        colorFilter: ColorFilter.mode(scheme.primary, BlendMode.srcIn),
      );
    } else if (_config.iconSource == IconSource.niosMess) {
      if (name.startsWith('m3_')) {
        return Icon(Icons.interests_rounded, size: 22, color: scheme.primary);
      }
      return SvgPicture.asset(
        'assets/svg/$name.svg',
        width: 22,
        height: 22,
        colorFilter: ColorFilter.mode(scheme.primary, BlendMode.srcIn),
      );
    }
    return Icon(Icons.circle, size: 22, color: scheme.primary);
  }

  Widget _buildLayoutSelector(ColorScheme scheme, TextTheme textTheme) {
    final List<({WallpaperLayoutMode mode, String label, IconData icon})> modes = [
      (mode: WallpaperLayoutMode.stagger, label: 'Шахматы', icon: Icons.grid_view_rounded),
      (mode: WallpaperLayoutMode.grid, label: 'Сетка', icon: Icons.grid_on_rounded),
      (mode: WallpaperLayoutMode.scatter, label: 'Хаос', icon: Icons.bubble_chart_rounded),
      (mode: WallpaperLayoutMode.hex, label: 'Соты', icon: Icons.hexagon_outlined),
      (mode: WallpaperLayoutMode.spiral, label: 'Спираль', icon: Icons.cyclone_rounded),
    ];

    return SettingsSection(
      title: 'Раскладка сетки (5 режимов)',
      subtitle: 'Геометрический закон размещения иконок',
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: modes.map((m) {
              final bool isSelected = _config.layoutMode == m.mode;
              return ChoiceChip(
                selected: isSelected,
                label: Text(m.label),
                avatar: Icon(m.icon, size: 16),
                onSelected: (bool sel) {
                  if (sel) {
                    HapticService.tap();
                    _updateConfig(_config.copyWith(layoutMode: m.mode));
                  }
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildGeometrySliders(ColorScheme scheme, TextTheme textTheme) {
    return SettingsSection(
      title: 'Геометрия и динамика',
      subtitle: 'Размер ячейки, угол сетки, плотность и вариация',
      children: <Widget>[
        // Cell Size
        _buildSliderTile(
          title: 'Размер ячейки',
          value: _config.cellSize,
          min: 36.0,
          max: 120.0,
          divisions: 42,
          unit: 'dp',
          onChanged: (val) => _updateConfig(_config.copyWith(cellSize: val)),
        ),
        // Density
        _buildSliderTile(
          title: 'Плотность покрытия',
          value: _config.density,
          min: 0.2,
          max: 1.0,
          divisions: 16,
          unit: '%',
          displayMultiplier: 100,
          onChanged: (val) => _updateConfig(_config.copyWith(density: val)),
        ),
        // Grid angle
        _buildSliderTile(
          title: 'Угол поворота сетки',
          value: _config.gridAngle,
          min: -45.0,
          max: 45.0,
          divisions: 90,
          unit: '°',
          onChanged: (val) => _updateConfig(_config.copyWith(gridAngle: val)),
        ),
        // Random rotation jitter
        _buildSliderTile(
          title: 'Случайный разброс угла',
          value: _config.randomRotationDeg,
          min: 0.0,
          max: 180.0,
          divisions: 36,
          unit: '°',
          onChanged: (val) =>
              _updateConfig(_config.copyWith(randomRotationDeg: val)),
        ),
        // Random scale jitter
        _buildSliderTile(
          title: 'Случайный разброс масштаба',
          value: _config.randomScaleJitter,
          min: 0.0,
          max: 0.6,
          divisions: 12,
          unit: '',
          onChanged: (val) =>
              _updateConfig(_config.copyWith(randomScaleJitter: val)),
        ),
        // Icon Alpha
        _buildSliderTile(
          title: 'Прозрачность иконок',
          value: _config.iconAlpha,
          min: 0.04,
          max: 0.35,
          divisions: 31,
          unit: '',
          onChanged: (val) => _updateConfig(_config.copyWith(iconAlpha: val)),
        ),
        // Filled toggle
        SettingsSwitchTile(
          icon: Icons.format_paint_rounded,
          title: 'Сплошная заливка (Filled)',
          subtitle: 'Заполнить иконки и формы цветом',
          value: _config.filled,
          onChanged: (bool val) {
            HapticService.tap();
            _updateConfig(_config.copyWith(filled: val));
          },
        ),
      ],
    );
  }

  Widget _buildColorModeSection(ColorScheme scheme, TextTheme textTheme) {
    return SettingsSection(
      title: 'Цветовая схема темы',
      subtitle: 'Гармоничное смешивание с оттенками Material 3 Expressive',
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SegmentedButton<WallpaperColorMode>(
            segments: const <ButtonSegment<WallpaperColorMode>>[
              ButtonSegment<WallpaperColorMode>(
                value: WallpaperColorMode.singleTone,
                label: Text('Один цвет'),
                icon: Icon(Icons.circle, size: 14),
              ),
              ButtonSegment<WallpaperColorMode>(
                value: WallpaperColorMode.palette,
                label: Text('Палитра'),
                icon: Icon(Icons.palette_rounded, size: 14),
              ),
              ButtonSegment<WallpaperColorMode>(
                value: WallpaperColorMode.tonalAccent,
                label: Text('Акценты'),
                icon: Icon(Icons.auto_awesome_rounded, size: 14),
              ),
            ],
            selected: <WallpaperColorMode>{_config.colorMode},
            onSelectionChanged: (Set<WallpaperColorMode> val) {
              HapticService.tap();
              _updateConfig(_config.copyWith(colorMode: val.first));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSliderTile({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    double displayMultiplier = 1.0,
    required ValueChanged<double> onChanged,
  }) {
    final double displayVal = value * displayMultiplier;
    final String formatted = unit == '%' || unit == '°'
        ? '${displayVal.toStringAsFixed(0)}$unit'
        : '${displayVal.toStringAsFixed(unit.isEmpty ? 2 : 0)} $unit'.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Text(
                formatted,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: (double val) {
              onChanged(val);
            },
          ),
        ],
      ),
    );
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
