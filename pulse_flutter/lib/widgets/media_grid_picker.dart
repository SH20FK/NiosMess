import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:universal_io/io.dart';

class MediaGridPickerResult {
  MediaGridPickerResult({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
  });

  final String filePath;
  final String fileName;
  final int fileSize;
}

class MediaGridPicker extends StatefulWidget {
  const MediaGridPicker({super.key});

  @override
  State<MediaGridPicker> createState() => _MediaGridPickerState();
}

class _MediaGridPickerState extends State<MediaGridPicker> {
  static const int _pageSize = 80;

  List<AssetEntity> _allAssets = [];
  final Set<String> _selectedIds = {};
  final ScrollController _scrollController = ScrollController();
  AssetPathEntity? _recentAlbum;
  int _currentPage = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _loading = true;
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
        _scrollController.position.maxScrollExtent - 350) {
      _loadNextPage();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMedia() async {
    try {
      final PermissionState perm = await PhotoManager.requestPermissionExtend();
      if (!perm.isAuth) {
        setState(() => _error = 'Permission denied');
        return;
      }

      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
      );

      if (albums.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final AssetPathEntity recent = albums.first;
      _recentAlbum = recent;
      _currentPage = 0;
      final List<AssetEntity> assets = await recent.getAssetListPaged(
        page: 0,
        size: _pageSize,
      );

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
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadNextPage() async {
    final album = _recentAlbum;
    if (album == null || _loadingMore || !_hasMore) return;
    _loadingMore = true;

    try {
      final int nextPage = _currentPage + 1;
      final List<AssetEntity> nextBatch = await album.getAssetListPaged(
        page: nextPage,
        size: _pageSize,
      );
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

  Future<void> _sendSelected() async {
    if (_selectedIds.isEmpty) return;

    final List<AssetEntity> selected = _allAssets
        .where((a) => _selectedIds.contains(a.id))
        .toList();

    final List<MediaGridPickerResult> results = [];
    for (final AssetEntity asset in selected) {
      final File? file = await asset.file;
      if (file == null) continue;
      results.add(MediaGridPickerResult(
        filePath: file.path,
        fileName: (asset.title != null && asset.title!.isNotEmpty)
            ? asset.title!
            : file.path.split('/').last,
        fileSize: await file.length(),
      ));
    }

    if (results.isNotEmpty && mounted) {
      Navigator.of(context).pop(results);
    }
  }

  void _openFilePicker() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: scheme.error),
            const SizedBox(height: 8),
            Text(_error!, style: textTheme.bodyMedium?.copyWith(color: scheme.error)),
          ],
        ),
      );
    } else if (_allAssets.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 64,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(context.l10n.mediaViewerCannotPreview,
                style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    } else {
      body = Stack(
        children: [
          GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: _allAssets.length,
            itemBuilder: (context, index) {
              final AssetEntity asset = _allAssets[index];
              final bool selected = _selectedIds.contains(asset.id);
              return GestureDetector(
                onTap: () => _toggleSelection(asset.id),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _AssetThumbnail(asset: asset, scheme: scheme),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? scheme.primary : scheme.scrim.withValues(alpha: 0.38),
                          border: Border.all(
                            color: selected ? scheme.primary : scheme.surface.withValues(alpha: 0.7),
                            width: 2,
                          ),
                        ),
                        child: selected
                            ? Icon(Icons.check_rounded, size: 16, color: scheme.onPrimary)
                            : null,
                      ),
                    ),
                    if (asset.type == AssetType.video)
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.scrim.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatDuration(Duration(milliseconds: asset.duration)),
                            style: TextStyle(color: scheme.onInverseSurface, fontSize: 11, fontWeight: FontWeight.w500),
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
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Text(
                  context.l10n.filePickerGallery,
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _openFilePicker,
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: Text(context.l10n.filePickerFile),
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
                color: scheme.surface,
                border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3))),
              ),
              child: Row(
                children: [
                  Text(
                    '${_selectedIds.length} ${context.l10n.filePickerGallery}',
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _sendSelected,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      '${context.l10n.chatAttachment} (${_selectedIds.length})',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _AssetThumbnailCache {
  static final Map<String, Uint8List> _cache = <String, Uint8List>{};
  static final List<String> _lru = <String>[];
  static const int _maxSize = 250;

  static Uint8List? get(String id) {
    final data = _cache[id];
    if (data != null) {
      _lru.remove(id);
      _lru.add(id);
    }
    return data;
  }

  static void put(String id, Uint8List data) {
    if (_cache.length >= _maxSize && _lru.isNotEmpty) {
      final oldest = _lru.removeAt(0);
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
    final cached = _AssetThumbnailCache.get(widget.asset.id);
    if (cached != null) {
      _data = cached;
      _loading = false;
      return;
    }

    _data = null;
    _loading = true;
    try {
      final Uint8List? data = await widget.asset.thumbnailDataWithSize(
        const ThumbnailSize(240, 240),
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
        cacheWidth: 240,
        cacheHeight: 240,
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
