import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/quick_camera_capture_screen.dart';
import 'package:universal_io/io.dart';

class MediaGridPickerResult {
  MediaGridPickerResult({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    this.caption,
    this.sendAsDocument = false,
  });

  final String filePath;
  final String fileName;
  final int fileSize;
  final String? caption;
  final bool sendAsDocument;
}

class MediaGridPicker extends StatefulWidget {
  const MediaGridPicker({
    this.onSelected,
    super.key,
  });

  final ValueChanged<List<MediaGridPickerResult>>? onSelected;

  @override
  State<MediaGridPicker> createState() => _MediaGridPickerState();
}

class _MediaGridPickerState extends State<MediaGridPicker> {
  static const int _pageSize = 90;

  List<AssetEntity> _allAssets = <AssetEntity>[];
  final List<String> _selectedIds = <String>[];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _captionController = TextEditingController();

  List<AssetPathEntity> _albums = <AssetPathEntity>[];
  AssetPathEntity? _recentAlbum;
  int _currentPage = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _loading = true;
  bool _sendAsDocument = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMedia();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadNextPage();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _loadMedia() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final bool isSupported =
        !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);
    if (!isSupported) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
      return;
    }

    try {
      final PermissionState perm = await PhotoManager.requestPermissionExtend()
          .timeout(const Duration(seconds: 45), onTimeout: () => PermissionState.denied);
      if (!perm.isAuth) {
        if (mounted) {
          setState(() {
            _error = 'Разрешение на доступ к галерее не предоставлено';
            _loading = false;
          });
        }
        return;
      }

      List<AssetPathEntity> albums = <AssetPathEntity>[];
      try {
        albums = await PhotoManager.getAssetPathList(
          type: RequestType.common,
          hasAll: true,
          filterOption: FilterOptionGroup(
            orders: const <OrderOption>[
              OrderOption(type: OrderOptionType.createDate, asc: false),
            ],
          ),
        ).timeout(const Duration(seconds: 15), onTimeout: () => <AssetPathEntity>[]);
      } catch (_) {}

      if (albums.isEmpty) {
        try {
          albums = await PhotoManager.getAssetPathList(
            type: RequestType.image,
            hasAll: true,
            filterOption: FilterOptionGroup(
              orders: const <OrderOption>[
                OrderOption(type: OrderOptionType.createDate, asc: false),
              ],
            ),
          ).timeout(const Duration(seconds: 10), onTimeout: () => <AssetPathEntity>[]);
        } catch (_) {}
      }

      if (albums.isEmpty) {
        try {
          albums = await PhotoManager.getAssetPathList(
            type: RequestType.all,
            hasAll: true,
          ).timeout(const Duration(seconds: 10), onTimeout: () => <AssetPathEntity>[]);
        } catch (_) {}
      }

      if (albums.isEmpty) {
        if (mounted) {
          setState(() {
            _albums = <AssetPathEntity>[];
            _allAssets = <AssetEntity>[];
            _loading = false;
          });
        }
        return;
      }

      _albums = albums;
      final AssetPathEntity recent = albums.first;
      _recentAlbum = recent;
      _currentPage = 0;
      final List<AssetEntity> assets = await recent.getAssetListPaged(
        page: 0,
        size: _pageSize,
      ).timeout(const Duration(seconds: 15), onTimeout: () => <AssetEntity>[]);

      // Sort newest first by createDateTime in Dart
      assets.sort((AssetEntity a, AssetEntity b) {
        final DateTime da = a.createDateTime;
        final DateTime db = b.createDateTime;
        return db.compareTo(da);
      });

      if (mounted) {
        setState(() {
          _allAssets = assets;
          _hasMore = assets.length >= _pageSize;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Не удалось загрузить галерею: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _switchAlbum(AssetPathEntity album) async {
    if (_recentAlbum?.id == album.id) return;
    HapticService.tap();
    setState(() {
      _recentAlbum = album;
      _loading = true;
      _currentPage = 0;
      _allAssets = <AssetEntity>[];
      _hasMore = true;
    });

    try {
      final List<AssetEntity> assets = await album.getAssetListPaged(
        page: 0,
        size: _pageSize,
      ).timeout(const Duration(seconds: 15), onTimeout: () => <AssetEntity>[]);

      assets.sort((AssetEntity a, AssetEntity b) {
        final DateTime da = a.createDateTime;
        final DateTime db = b.createDateTime;
        return db.compareTo(da);
      });

      if (mounted) {
        setState(() {
          _allAssets = assets;
          _hasMore = assets.length >= _pageSize;
          _loading = false;
        });
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadNextPage() async {
    final AssetPathEntity? album = _recentAlbum;
    if (album == null || _loadingMore || !_hasMore) return;
    _loadingMore = true;

    try {
      final int nextPage = _currentPage + 1;
      final List<AssetEntity> nextBatch = await album.getAssetListPaged(
        page: nextPage,
        size: _pageSize,
      ).timeout(const Duration(seconds: 5), onTimeout: () => <AssetEntity>[]);

      nextBatch.sort((AssetEntity a, AssetEntity b) {
        final DateTime da = a.createDateTime;
        final DateTime db = b.createDateTime;
        return db.compareTo(da);
      });

      if (mounted) {
        setState(() {
          _currentPage = nextPage;
          _allAssets.addAll(nextBatch);
          _hasMore = nextBatch.length >= _pageSize;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _openCameraCapture() async {
    HapticService.tap();
    final String? photoPath =
        await QuickCameraCaptureScreen.capturePhoto(context);
    if (photoPath == null || !mounted) return;

    final File file = File(photoPath);
    final int size = await file.length();
    final String name = photoPath.split('/').last.split('\\').last;

    final MediaGridPickerResult captured = MediaGridPickerResult(
      filePath: photoPath,
      fileName: name,
      fileSize: size,
      caption: _captionController.text.trim(),
      sendAsDocument: _sendAsDocument,
    );

    final List<MediaGridPickerResult> resultList = <MediaGridPickerResult>[
      captured,
    ];
    if (widget.onSelected != null) {
      widget.onSelected!(resultList);
    }
    if (!mounted) return;
    Navigator.of(context).pop(resultList);
  }

  Future<void> _openMediaPreview(int initialIndex) async {
    HapticService.tap();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _MediaPreviewScreen(
          assets: _allAssets,
          initialIndex: initialIndex,
          selectedIds: _selectedIds,
          onToggleSelection: _toggleSelection,
          onSendDirect: (AssetEntity asset, String caption, bool asDocument) async {
            final File? file = await asset.file;
            if (file == null || !mounted) return;
            final MediaGridPickerResult result = MediaGridPickerResult(
              filePath: file.path,
              fileName: (asset.title != null && asset.title!.isNotEmpty)
                  ? asset.title!
                  : file.path.split('/').last.split('\\').last,
              fileSize: await file.length(),
              caption: caption.isNotEmpty ? caption : null,
              sendAsDocument: asDocument,
            );
            if (!mounted) return;
            if (widget.onSelected != null) {
              widget.onSelected!(<MediaGridPickerResult>[result]);
            }
            Navigator.of(context).pop(<MediaGridPickerResult>[result]);
          },
          scheme: Theme.of(context).colorScheme,
        ),
      ),
    );
  }

  Future<void> _sendSelected() async {
    if (_selectedIds.isEmpty) return;
    HapticService.confirm();

    final List<AssetEntity> selected = _allAssets
        .where((AssetEntity a) => _selectedIds.contains(a.id))
        .toList();

    selected.sort((AssetEntity a, AssetEntity b) {
      return _selectedIds.indexOf(a.id).compareTo(_selectedIds.indexOf(b.id));
    });

    final String caption = _captionController.text.trim();
    final List<MediaGridPickerResult> results = <MediaGridPickerResult>[];

    for (final AssetEntity asset in selected) {
      final File? file = await asset.file;
      if (file == null) continue;
      results.add(
        MediaGridPickerResult(
          filePath: file.path,
          fileName: (asset.title != null && asset.title!.isNotEmpty)
              ? asset.title!
              : file.path.split('/').last.split('\\').last,
          fileSize: await file.length(),
          caption: caption,
          sendAsDocument: _sendAsDocument,
        ),
      );
    }

    if (results.isNotEmpty && mounted) {
      if (widget.onSelected != null) {
        widget.onSelected!(results);
      }
      Navigator.of(context).pop(results);
    }
  }

  void _showAlbumSelector() {
    if (_albums.isEmpty) return;
    HapticService.tap();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) {
        final ColorScheme scheme = Theme.of(ctx).colorScheme;
        final TextTheme textTheme = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: <Widget>[
                    Text(
                      'Альбомы',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: _albums.length,
                  itemBuilder: (BuildContext context, int index) {
                    final AssetPathEntity album = _albums[index];
                    final bool isSelected = album.id == _recentAlbum?.id;
                    return ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _AlbumLeadingThumbnail(
                          album: album,
                          scheme: scheme,
                        ),
                      ),
                      title: Text(
                        album.name,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color:
                              isSelected ? scheme.primary : scheme.onSurface,
                        ),
                      ),
                      trailing: FutureBuilder<int>(
                        future: album.assetCountAsync,
                        builder:
                            (BuildContext context, AsyncSnapshot<int> snapshot) {
                          return Text(
                            snapshot.hasData ? '${snapshot.data}' : '',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                      selected: isSelected,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _switchAlbum(album);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openFilePicker() async {
    HapticService.tap();
    try {
      final List<PlatformFile> picked = await FilePicker.pickFiles(
        type: FileType.media,
      );
      if (picked.isEmpty || !mounted) return;

      final List<MediaGridPickerResult> results = <MediaGridPickerResult>[];
      for (final PlatformFile file in picked) {
        final String? path = file.path;
        if (path != null && path.isNotEmpty) {
          int fileSize = 0;
          try {
            fileSize = await File(path).length();
          } catch (_) {}

          results.add(
            MediaGridPickerResult(
              filePath: path,
              fileName: file.name,
              fileSize: fileSize,
              caption: _captionController.text.trim(),
              sendAsDocument: _sendAsDocument,
            ),
          );
        }
      }

      if (results.isNotEmpty && mounted) {
        if (widget.onSelected != null) {
          widget.onSelected!(results);
        }
        Navigator.of(context).pop(results);
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Ошибка выбора файлов: $e');
      }
    }
  }

  Widget _buildSelectionBadge(String id, ColorScheme scheme) {
    final int index = _selectedIds.indexOf(id);
    final bool selected = index != -1;
    final int number = index + 1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected
            ? scheme.primary
            : scheme.scrim.withValues(alpha: 0.38),
        border: Border.all(
          color: selected
              ? scheme.primary
              : scheme.surface.withValues(alpha: 0.85),
          width: 2,
        ),
      ),
      child: Center(
        child: selected
            ? Text(
                '$number',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final bool showCameraTile = _recentAlbum?.isAll ?? true;

    final Widget body;
    if (_loading) {
      body = Center(child: AppLoadingIndicator(color: scheme.primary));
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.photo_library_outlined, size: 48, color: scheme.error),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () => PhotoManager.openSetting(),
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: const Text('Настройки'),
                  ),
                  FilledButton.icon(
                    onPressed: _openFilePicker,
                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                    label: const Text('Проводник'),
                  ),
                  TextButton.icon(
                    onPressed: _loadMedia,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Повторить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else if (_allAssets.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.photo_library_outlined,
                size: 52,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 12),
              Text(
                'В галерее нет медиафайлов или доступ ограничен',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  FilledButton.tonalIcon(
                    onPressed: _openCameraCapture,
                    icon: const Icon(Icons.photo_camera_rounded, size: 16),
                    label: const Text('Камера'),
                  ),
                  FilledButton.icon(
                    onPressed: _openFilePicker,
                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                    label: const Text('Проводник'),
                  ),
                  TextButton.icon(
                    onPressed: _loadMedia,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Повторить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      final int totalGridItems = _allAssets.length + (showCameraTile ? 1 : 0);
      body = Stack(
        children: <Widget>[
          GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: totalGridItems,
            itemBuilder: (BuildContext context, int index) {
              if (showCameraTile && index == 0) {
                return GestureDetector(
                  onTap: _openCameraCapture,
                  child: Container(
                    color: scheme.surfaceContainerHighest,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.photo_camera_rounded,
                          size: 32,
                          color: scheme.primary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Камера',
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final int assetIndex = showCameraTile ? index - 1 : index;
              final AssetEntity asset = _allAssets[assetIndex];

              return GestureDetector(
                onTap: () => _openMediaPreview(assetIndex),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _AssetThumbnail(asset: asset, scheme: scheme),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticService.tap();
                          _toggleSelection(asset.id);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: _buildSelectionBadge(asset.id, scheme),
                        ),
                      ),
                    ),
                    if (asset.type == AssetType.video)
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.scrim.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatDuration(
                              Duration(milliseconds: asset.duration),
                            ),
                            style: TextStyle(
                              color: scheme.onInverseSurface,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          if (_loadingMore)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: scheme.surface.withValues(alpha: 0.75),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: AppLoadingIndicator(
                  size: 20,
                  color: scheme.primary,
                ),
              ),
            ),
        ],
      );
    }

    final double maxHeight = MediaQuery.sizeOf(context).height * 0.50;

    return SafeArea(
      child: SizedBox(
        height: maxHeight,
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
              children: <Widget>[
                InkWell(
                  onTap: _showAlbumSelector,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _recentAlbum?.name ?? context.l10n.filePickerGallery,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: _openFilePicker,
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('Проводник'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: body),
          if (_selectedIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.25),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _captionController,
                          decoration: InputDecoration(
                            hintText: 'Добавить подпись...',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                            hintStyle: TextStyle(
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          minLines: 1,
                        ),
                      ),
                      FilterChip(
                        label: Text(_sendAsDocument ? 'Как файл' : 'Фото'),
                        selected: _sendAsDocument,
                        showCheckmark: false,
                        avatar: Icon(
                          _sendAsDocument
                              ? Icons.insert_drive_file_outlined
                              : Icons.photo_outlined,
                          size: 16,
                        ),
                        onSelected: (bool val) {
                          HapticService.tap();
                          setState(() => _sendAsDocument = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Выбрано: ${_selectedIds.length}',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _sendSelected,
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: Text('Отправить (${_selectedIds.length})'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

  String _formatDuration(Duration d) {
    final String minutes = d.inMinutes.toString().padLeft(2, '0');
    final String seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _AlbumLeadingThumbnail extends StatelessWidget {
  const _AlbumLeadingThumbnail({required this.album, required this.scheme});
  final AssetPathEntity album;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AssetEntity>>(
      future: album.getAssetListPaged(page: 0, size: 1),
      builder:
          (BuildContext context, AsyncSnapshot<List<AssetEntity>> snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          return _AssetThumbnail(asset: snapshot.data!.first, scheme: scheme);
        }
        return Icon(
          Icons.photo_library_outlined,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
        );
      },
    );
  }
}

class _MediaPreviewScreen extends StatefulWidget {
  const _MediaPreviewScreen({
    required this.assets,
    required this.initialIndex,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.onSendDirect,
    required this.scheme,
  });

  final List<AssetEntity> assets;
  final int initialIndex;
  final List<String> selectedIds;
  final void Function(String id) onToggleSelection;
  final void Function(AssetEntity asset, String caption, bool asDocument) onSendDirect;
  final ColorScheme scheme;

  @override
  State<_MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<_MediaPreviewScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  final TextEditingController _captionController = TextEditingController();
  bool _sendAsDocument = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AssetEntity currentAsset = widget.assets[_currentIndex];
    final bool isSelected = widget.selectedIds.contains(currentAsset.id);
    final int selectNum = widget.selectedIds.indexOf(currentAsset.id) + 1;

    return Scaffold(
      backgroundColor: widget.scheme.scrim,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            PageView.builder(
              controller: _pageController,
              itemCount: widget.assets.length,
              onPageChanged: (int index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (BuildContext context, int index) {
                final AssetEntity asset = widget.assets[index];
                return Center(
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: _AssetFullView(asset: asset, scheme: widget.scheme),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Row(
                children: <Widget>[
                  IconButton.filledTonal(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: widget.scheme.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_currentIndex + 1} из ${widget.assets.length}',
                      style: TextStyle(
                        color: widget.scheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      HapticService.tap();
                      widget.onToggleSelection(currentAsset.id);
                      setState(() {});
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? widget.scheme.primary
                            : widget.scheme.surface.withValues(alpha: 0.5),
                        border: Border.all(
                          color: isSelected
                              ? widget.scheme.primary
                              : widget.scheme.onSurface,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: isSelected
                            ? Text(
                                '$selectNum',
                                style: TextStyle(
                                  color: widget.scheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: <Color>[
                      widget.scheme.scrim.withValues(alpha: 0.95),
                      widget.scheme.scrim.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: widget.scheme.surface.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _captionController,
                          style: TextStyle(color: widget.scheme.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Добавить подпись...',
                            hintStyle: TextStyle(
                              color: widget.scheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _sendAsDocument
                            ? Icons.insert_drive_file_rounded
                            : Icons.photo_rounded,
                        color: _sendAsDocument
                            ? widget.scheme.primary
                            : widget.scheme.onSurface,
                      ),
                      tooltip: _sendAsDocument
                          ? 'Как файл (без сжатия)'
                          : 'Как фото',
                      onPressed: () {
                        HapticService.tap();
                        setState(() => _sendAsDocument = !_sendAsDocument);
                      },
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(14),
                      ),
                      onPressed: () {
                        HapticService.confirm();
                        Navigator.of(context).pop();
                        widget.onSendDirect(
                          currentAsset,
                          _captionController.text.trim(),
                          _sendAsDocument,
                        );
                      },
                      child: const Icon(Icons.send_rounded, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetFullView extends StatelessWidget {
  const _AssetFullView({required this.asset, required this.scheme});
  final AssetEntity asset;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize(1920, 1920)),
      builder:
          (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.contain,
          );
        }
        return Center(
          child: AppLoadingIndicator(color: scheme.onSurface),
        );
      },
    );
  }
}

class _AssetThumbnailCache {
  static final Map<String, Uint8List> _cache = <String, Uint8List>{};
  static final List<String> _lru = <String>[];
  static const int _maxSize = 350;

  static Uint8List? get(String id) {
    final Uint8List? data = _cache[id];
    if (data != null) {
      _lru.remove(id);
      _lru.add(id);
    }
    return data;
  }

  static void put(String id, Uint8List data) {
    if (_cache.length >= _maxSize && _lru.isNotEmpty) {
      final String oldest = _lru.removeAt(0);
      _cache.remove(oldest);
    }
    _cache[id] = data;
    _lru.remove(id);
    _lru.add(id);
  }
}

class _AssetThumbnail extends StatefulWidget {
  const _AssetThumbnail({required this.asset, required this.scheme});

  final AssetEntity asset;
  final ColorScheme scheme;

  @override
  State<_AssetThumbnail> createState() => _AssetThumbnailState();
}

class _AssetThumbnailState extends State<_AssetThumbnail> {
  Uint8List? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkCacheAndLoad();
  }

  @override
  void didUpdateWidget(covariant _AssetThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _data = null;
      _checkCacheAndLoad();
    }
  }

  Future<void> _checkCacheAndLoad() async {
    final Uint8List? cached = _AssetThumbnailCache.get(widget.asset.id);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _data = cached;
          _loading = false;
        });
      } else {
        _data = cached;
        _loading = false;
      }
      return;
    }

    _data = null;
    _loading = true;
    try {
      final Uint8List? data = await widget.asset.thumbnailDataWithSize(
        const ThumbnailSize(280, 280),
      );
      if (mounted) {
        if (data != null) {
          _AssetThumbnailCache.put(widget.asset.id, data);
        }
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data != null) {
      return Image.memory(
        _data!,
        fit: BoxFit.cover,
        cacheWidth: 280,
        cacheHeight: 280,
      );
    }

    if (_loading) {
      return Container(
        color: widget.scheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.photo_outlined,
            color: widget.scheme.onSurfaceVariant.withValues(alpha: 0.3),
            size: 24,
          ),
        ),
      );
    }

    return Container(
      color: widget.scheme.surfaceContainerHighest,
      child: Icon(
        Icons.broken_image_rounded,
        color: widget.scheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),
    );
  }
}
