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
  List<AssetEntity> _allAssets = [];
  Set<String> _selectedIds = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMedia();
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
      final List<AssetEntity> assets = await recent.getAssetListPaged(
        page: 0,
        size: 200,
      );

      if (mounted) {
        setState(() {
          _allAssets = assets;
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
      body = GridView.builder(
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
                      color: selected ? scheme.primary : Colors.black38,
                      border: Border.all(
                        color: selected ? scheme.primary : Colors.white70,
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
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(Duration(milliseconds: asset.duration)),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
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

class _AssetThumbnail extends StatelessWidget {
  const _AssetThumbnail({required this.asset, required this.scheme});

  final AssetEntity asset;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize(400, 400)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: scheme.surfaceContainerHighest,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final Uint8List? data = snapshot.data;
        if (data != null) {
          return Image.memory(data, fit: BoxFit.cover);
        }
        return Container(
          color: scheme.surfaceContainerHighest,
          child: Icon(Icons.broken_image_rounded, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
        );
      },
    );
  }
}
