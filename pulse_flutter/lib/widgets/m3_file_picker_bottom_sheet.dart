import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/widgets/media_grid_picker.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/quick_camera_capture_screen.dart';
import 'package:universal_io/io.dart';

/// Result item from the M3 Attachment / File picker.
class M3FilePickerResult {
  M3FilePickerResult({
    required this.fileName,
    required this.fileSize,
    required this.mediaSubtype,
    this.filePath,
    this.fileBytes,
    this.caption,
    this.sendAsDocument = false,
  });

  final String fileName;
  final int fileSize;
  final String mediaSubtype;
  final String? filePath;
  final Uint8List? fileBytes;
  final String? caption;
  final bool sendAsDocument;

  FileTypeInfo get typeInfo => FileTypeDetector.detect(fileName: fileName);
  String get formattedSize => FileTypeDetector.formatFileSize(fileSize);
}

/// Opens the Telegram-style attachment bottom sheet with recent media grid,
/// quick camera capture tile, full gallery album access, and document/audio pickers.
Future<List<M3FilePickerResult>?> showM3FilePicker(BuildContext context) async {
  return AppBottomSheets.show<List<M3FilePickerResult>>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext ctx) => const M3AttachmentBottomSheet(),
  );
}

class M3AttachmentBottomSheet extends StatefulWidget {
  const M3AttachmentBottomSheet({super.key});

  @override
  State<M3AttachmentBottomSheet> createState() => _M3AttachmentBottomSheetState();
}

class _M3AttachmentBottomSheetState extends State<M3AttachmentBottomSheet> {
  final List<AssetEntity> _recentAssets = <AssetEntity>[];
  final List<AssetEntity> _selectedAssets = <AssetEntity>[];
  final TextEditingController _captionController = TextEditingController();

  bool _isLoading = true;
  bool _hasPermission = true;
  bool _sendAsDocument = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadRecentMedia();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentMedia() async {
    final bool isSupported =
        !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);
    if (!isSupported) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasPermission = true;
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
            _hasPermission = false;
            _isLoading = false;
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

      if (albums.isNotEmpty) {
        final List<AssetEntity> assets = await albums.first.getAssetListRange(
          start: 0,
          end: 45,
        ).timeout(const Duration(seconds: 15), onTimeout: () => <AssetEntity>[]);

        // Sort newest first by createDateTime in Dart
        assets.sort((AssetEntity a, AssetEntity b) {
          final DateTime da = a.createDateTime;
          final DateTime db = b.createDateTime;
          return db.compareTo(da);
        });

        if (mounted) {
          setState(() {
            _recentAssets.clear();
            _recentAssets.addAll(assets);
            _hasPermission = true;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _recentAssets.clear();
            _hasPermission = true;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasPermission = true;
          _isLoading = false;
        });
      }
    }
  }

  void _toggleAssetSelection(AssetEntity asset) {
    HapticService.tap();
    setState(() {
      if (_selectedAssets.any((a) => a.id == asset.id)) {
        _selectedAssets.removeWhere((a) => a.id == asset.id);
      } else {
        _selectedAssets.add(asset);
      }
    });
  }

  Future<void> _openCamera() async {
    HapticService.tap();
    final String? photoPath = await QuickCameraCaptureScreen.capturePhoto(context);
    if (photoPath == null || !mounted) return;

    final File file = File(photoPath);
    final int fileSize = await file.length();
    final String fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'camera_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final M3FilePickerResult result = M3FilePickerResult(
      filePath: photoPath,
      fileName: fileName,
      fileSize: fileSize,
      mediaSubtype: _sendAsDocument ? 'document' : 'photo',
      caption: _captionController.text.trim(),
      sendAsDocument: _sendAsDocument,
    );

    if (!mounted) return;
    Navigator.of(context).pop(<M3FilePickerResult>[result]);
  }

  Future<void> _openFullGallery() async {
    HapticService.tap();
    final bool isSupported =
        !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);
    if (!isSupported) {
      await _pickFile(
        type: FileType.media,
        mediaSubtype: 'media',
      );
      return;
    }

    final List<MediaGridPickerResult>? results =
        await AppBottomSheets.show<List<MediaGridPickerResult>?>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.50,
        child: const MediaGridPicker(),
      ),
    );

    if (results == null || results.isEmpty || !mounted) return;

    final List<M3FilePickerResult> converted = results
        .where((r) => r.filePath.isNotEmpty)
        .map((r) => M3FilePickerResult(
              filePath: r.filePath,
              fileName: r.fileName,
              fileSize: r.fileSize,
              mediaSubtype: r.sendAsDocument ? 'document' : 'media',
              caption: r.caption,
              sendAsDocument: r.sendAsDocument,
            ))
        .toList();

    if (converted.isEmpty || !mounted) return;
    Navigator.of(context).pop(converted);
  }

  Future<void> _pickFile({
    required FileType type,
    List<String>? allowedExtensions,
    required String mediaSubtype,
  }) async {
    HapticService.tap();
    final List<PlatformFile> result = await FilePicker.pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
    );

    if (result.isEmpty || !mounted) return;

    final List<M3FilePickerResult> pickerResults = <M3FilePickerResult>[];
    final String caption = _captionController.text.trim();

    for (int i = 0; i < result.length; i++) {
      final PlatformFile file = result[i];
      final String? filePath = file.path;
      Uint8List? fileBytes;
      try {
        fileBytes = await file.readAsBytes();
      } catch (_) {}

      final int fileSize = fileBytes?.length ??
          (filePath != null ? await file.length() : 0);

      pickerResults.add(
        M3FilePickerResult(
          filePath: filePath,
          fileBytes: fileBytes,
          fileName: file.name,
          fileSize: fileSize,
          mediaSubtype: _sendAsDocument ? 'document' : mediaSubtype,
          caption: i == 0 ? caption : null,
          sendAsDocument: _sendAsDocument,
        ),
      );
    }

    if (pickerResults.isEmpty) return;
    if (!mounted) return;
    Navigator.of(context).pop(pickerResults);
  }

  Future<void> _sendSelected() async {
    if (_selectedAssets.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    HapticService.confirm();

    final List<M3FilePickerResult> results = <M3FilePickerResult>[];
    final String caption = _captionController.text.trim();

    for (int i = 0; i < _selectedAssets.length; i++) {
      final AssetEntity asset = _selectedAssets[i];
      final File? file = await asset.file;
      if (file != null) {
        final int fileSize = await file.length();
        final String fileName = asset.title ?? file.uri.pathSegments.last;
        final String mediaSubtype = _sendAsDocument
            ? 'document'
            : (asset.type == AssetType.video ? 'video' : 'photo');

        results.add(
          M3FilePickerResult(
            filePath: file.path,
            fileName: fileName,
            fileSize: fileSize,
            mediaSubtype: mediaSubtype,
            caption: i == 0 && caption.isNotEmpty ? caption : null,
            sendAsDocument: _sendAsDocument,
          ),
        );
      }
    }

    if (!mounted) return;
    if (results.isNotEmpty) {
      Navigator.of(context).pop(results);
    } else {
      setState(() => _isSending = false);
      AppToast.showError(context, 'Не удалось загрузить выбранные файлы');
    }
  }

  void _previewAsset(int index) {
    HapticService.tap();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _RecentPreviewScreen(
          assets: _recentAssets,
          initialIndex: index,
          selectedAssets: _selectedAssets,
          onToggle: (AssetEntity asset) {
            _toggleAssetSelection(asset);
          },
          onSendSingle: (AssetEntity asset, String caption, bool asDoc) async {
            final File? file = await asset.file;
            if (file == null || !mounted) return;
            final int fileSize = await file.length();
            final String fileName = asset.title ?? file.uri.pathSegments.last;
            final M3FilePickerResult single = M3FilePickerResult(
              filePath: file.path,
              fileName: fileName,
              fileSize: fileSize,
              mediaSubtype: asDoc
                  ? 'document'
                  : (asset.type == AssetType.video ? 'video' : 'photo'),
              caption: caption.isNotEmpty ? caption : null,
              sendAsDocument: asDoc,
            );
            if (!mounted) return;
            Navigator.of(context).pop(<M3FilePickerResult>[single]);
          },
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool hasSelection = _selectedAssets.isNotEmpty;
    final double maxSheetHeight = MediaQuery.sizeOf(context).height * 0.50;

    return SafeArea(
      child: SizedBox(
        height: maxSheetHeight,
        child: Column(
          children: <Widget>[
          // ── Category Pills Row ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _CategoryActionPill(
                    icon: Icons.photo_library_rounded,
                    label: context.l10n.filePickerGallery,
                    color: scheme.primaryContainer,
                    iconColor: scheme.onPrimaryContainer,
                    onTap: _openFullGallery,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CategoryActionPill(
                    icon: Icons.insert_drive_file_rounded,
                    label: context.l10n.filePickerDocument,
                    color: scheme.secondaryContainer,
                    iconColor: scheme.onSecondaryContainer,
                    onTap: () => _pickFile(
                      type: FileType.custom,
                      allowedExtensions: const <String>[
                        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'zip', 'apk'
                      ],
                      mediaSubtype: 'media',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CategoryActionPill(
                    icon: Icons.music_note_rounded,
                    label: context.l10n.filePickerAudio,
                    color: scheme.tertiaryContainer,
                    iconColor: scheme.onTertiaryContainer,
                    onTap: () => _pickFile(
                      type: FileType.audio,
                      mediaSubtype: 'media',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Recent Media Strip / Grid ──────────────────────────────
          if (!kIsWeb && _hasPermission) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: <Widget>[
                  Text(
                    'Недавние медиа',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _openFullGallery,
                    child: Text(
                      'Все альбомы',
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: PulseLoadingIndicator(size: 32),
                    )
                  : _recentAssets.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.photo_library_outlined,
                                size: 36,
                                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Нет недавних фото или альбом пуст',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: <Widget>[
                                  FilledButton.tonalIcon(
                                    onPressed: _openCamera,
                                    icon: const Icon(Icons.camera_alt_rounded, size: 16),
                                    label: const Text('Камера'),
                                  ),
                                  FilledButton.icon(
                                    onPressed: () => _pickFile(
                                      type: FileType.media,
                                      mediaSubtype: 'media',
                                    ),
                                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                                    label: const Text('Проводник'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                          ),
                          // Camera tile at index 0, followed by recent assets
                          itemCount: _recentAssets.length + 1,
                          itemBuilder: (BuildContext context, int index) {
                            if (index == 0) {
                              return _CameraCaptureTile(
                                scheme: scheme,
                                onTap: _openCamera,
                              );
                            }
                            final int assetIndex = index - 1;
                            final AssetEntity asset = _recentAssets[assetIndex];
                            final int selectedIndex = _selectedAssets
                                .indexWhere((a) => a.id == asset.id);
                            final bool isSelected = selectedIndex >= 0;

                            return _RecentAssetThumbnailTile(
                              asset: asset,
                              isSelected: isSelected,
                              selectedNumber: selectedIndex + 1,
                              scheme: scheme,
                              onTap: () => _previewAsset(assetIndex),
                              onToggleSelect: () =>
                                  _toggleAssetSelection(asset),
                            );
                          },
                        ),
            ),
          ],
          if (!kIsWeb && !_hasPermission)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.photo_library_outlined,
                        size: 40,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Доступ к галерее не предоставлен',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Разрешите доступ в настройках или выберите файлы через проводник',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
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
                            onPressed: () => _pickFile(
                              type: FileType.media,
                              mediaSubtype: 'media',
                            ),
                            icon: const Icon(Icons.folder_open_rounded, size: 16),
                            label: const Text('Проводник'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Bottom Action / Send Bar ───────────────────────────────
          if (hasSelection)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: _captionController,
                            style: TextStyle(color: scheme.onSurface),
                            decoration: InputDecoration(
                              hintText: 'Добавить подпись...',
                              hintStyle: TextStyle(
                                color: scheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
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
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: _isSending ? null : _sendSelected,
                        child: _isSending
                            ? AppLoadingIndicator(
                                size: 18,
                                color: Theme.of(context).colorScheme.onPrimary,
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(Icons.send_rounded, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_selectedAssets.length}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
}

class _CategoryActionPill extends StatelessWidget {
  const _CategoryActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: iconColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraCaptureTile extends StatelessWidget {
  const _CameraCaptureTile({
    required this.scheme,
    required this.onTap,
  });

  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                color: scheme.primary,
                size: 26,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Камера',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentAssetThumbnailTile extends StatelessWidget {
  const _RecentAssetThumbnailTile({
    required this.asset,
    required this.isSelected,
    required this.selectedNumber,
    required this.scheme,
    required this.onTap,
    required this.onToggleSelect,
  });

  final AssetEntity asset;
  final bool isSelected;
  final int selectedNumber;
  final ColorScheme scheme;
  final VoidCallback onTap;
  final VoidCallback onToggleSelect;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GestureDetector(
            onTap: onTap,
            child: FutureBuilder<Uint8List?>(
              future: asset.thumbnailDataWithSize(const ThumbnailSize(250, 250)),
              builder: (BuildContext context, AsyncSnapshot<Uint8List?> snap) {
                if (snap.connectionState == ConnectionState.done &&
                    snap.data != null) {
                  return Image.memory(
                    snap.data!,
                    fit: BoxFit.cover,
                  );
                }
                return Container(
                  color: scheme.surfaceContainerHighest,
                );
              },
            ),
          ),
          if (asset.type == AssetType.video)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.scrim.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.videocam_rounded,
                      color: scheme.onSurface,
                      size: 11,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _formatDuration(asset.duration),
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onToggleSelect,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? scheme.primary
                      : scheme.surface.withValues(alpha: 0.45),
                  border: Border.all(
                    color: isSelected ? scheme.primary : scheme.onSurface,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isSelected
                      ? Text(
                          '$selectedNumber',
                          style: TextStyle(
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remaining = seconds % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }
}

/// Fullscreen zoomable preview for recent photos right from the attachment bottom sheet.
class _RecentPreviewScreen extends StatefulWidget {
  const _RecentPreviewScreen({
    required this.assets,
    required this.initialIndex,
    required this.selectedAssets,
    required this.onToggle,
    required this.onSendSingle,
  });

  final List<AssetEntity> assets;
  final int initialIndex;
  final List<AssetEntity> selectedAssets;
  final ValueChanged<AssetEntity> onToggle;
  final void Function(AssetEntity asset, String caption, bool asDoc) onSendSingle;

  @override
  State<_RecentPreviewScreen> createState() => _RecentPreviewScreenState();
}

class _RecentPreviewScreenState extends State<_RecentPreviewScreen> {
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AssetEntity currentAsset = widget.assets[_currentIndex];
    final int selectIndex =
        widget.selectedAssets.indexWhere((a) => a.id == currentAsset.id);
    final bool isSelected = selectIndex >= 0;

    return Scaffold(
      backgroundColor: scheme.scrim,
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
                    child: FutureBuilder<Uint8List?>(
                      future: asset.thumbnailDataWithSize(
                        const ThumbnailSize(1920, 1920),
                      ),
                      builder: (BuildContext context,
                          AsyncSnapshot<Uint8List?> snap) {
                        if (snap.connectionState == ConnectionState.done &&
                            snap.data != null) {
                          return Image.memory(
                            snap.data!,
                            fit: BoxFit.contain,
                          );
                        }
                        return const Center(
                          child: PulseLoadingIndicator(size: 36),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            // Header bar
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_currentIndex + 1} из ${widget.assets.length}',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      HapticService.tap();
                      widget.onToggle(currentAsset);
                      setState(() {});
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? scheme.primary
                            : scheme.surface.withValues(alpha: 0.5),
                        border: Border.all(
                          color: isSelected ? scheme.primary : scheme.onSurface,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: isSelected
                            ? Text(
                                '${selectIndex + 1}',
                                style: TextStyle(
                                  color: scheme.onPrimary,
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
            // Bottom bar
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
                      scheme.scrim.withValues(alpha: 0.95),
                      scheme.scrim.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _captionController,
                          style: TextStyle(color: scheme.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Добавить подпись...',
                            hintStyle: TextStyle(
                              color:
                                  scheme.onSurface.withValues(alpha: 0.6),
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
                            ? scheme.primary
                            : scheme.onSurface,
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
                        widget.onSendSingle(
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
