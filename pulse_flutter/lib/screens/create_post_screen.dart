import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/image_compressor.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/core/utils/app_error_formatter.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key, this.autoPickMedia = false});

  final bool autoPickMedia;

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final TextEditingController _textController = TextEditingController();
  PlatformFile? _selectedFile;
  List<PlatformFile> _selectedFiles = <PlatformFile>[];
  List<Uint8List> _previewBytesList = <Uint8List>[];
  bool _isLoading = false;
  String? _error;

  static const int _maxFileBytes = 10 * 1024 * 1024; // 10 MB

  @override
  void initState() {
    super.initState();
    if (widget.autoPickMedia) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickMedia();
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool _isVideoFile(String name) {
    final String ext = name.split('.').last.toLowerCase();
    return ext == 'mp4' || ext == 'mov' || ext == 'mkv' || ext == 'webm' || ext == 'avi' || ext == '3gp';
  }

  Future<void> _pickMedia() async {
    final int availableSlots = 5 - _selectedFiles.length;
    if (availableSlots <= 0) {
      AppToast.showInfo(context, 'Максимум 5 фотографий');
      return;
    }

    final List<PlatformFile> result = await FilePicker.pickFiles(
      type: FileType.media,
    );
    if (result.isEmpty) return;

    final List<PlatformFile> picked = result.take(availableSlots).toList();
    final List<PlatformFile> validFiles = List<PlatformFile>.from(_selectedFiles);
    final List<Uint8List> previews = List<Uint8List>.from(_previewBytesList);

    for (final PlatformFile file in picked) {
      if ((await file.length()) > _maxFileBytes) {
        setState(() => _error = context.l10n.postFileTooLarge);
        continue;
      }
      final bool isVideo = _isVideoFile(file.name);
      Uint8List previewBytes;
      if (isVideo) {
        previewBytes = Uint8List(0);
      } else {
        previewBytes = await file.readAsBytes();
        final Uint8List? compressed = await ImageCompressor.compressImageBytes(
          bytes: previewBytes,
          fileName: file.name,
        );
        if (compressed != null) previewBytes = compressed;
      }
      validFiles.add(file);
      previews.add(previewBytes);
    }

    if (validFiles.length != _selectedFiles.length) {
      setState(() {
        _selectedFiles = validFiles;
        _previewBytesList = previews;
        _selectedFile = validFiles.firstOrNull;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    final String text = _textController.text.trim();
    if (text.isEmpty && _selectedFiles.isEmpty && _selectedFile == null) {
      setState(() => _error = context.l10n.postEmptyContent);
      return;
    }

    if (ref.read(uiSettingsProvider).haptics) HapticService.tap();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<String>? uploadIds;
      if (_selectedFiles.isNotEmpty) {
        uploadIds = <String>[];
        for (int i = 0; i < _selectedFiles.length; i++) {
          final PlatformFile file = _selectedFiles[i];
          final Uint8List fileBytes = (i < _previewBytesList.length)
              ? _previewBytesList[i]
              : await file.readAsBytes();
          String filename = file.name;
          if (!filename.contains('.')) {
            filename = '$filename.jpg';
          }
          final String uploadIdStr = await ref
              .read(chatRepositoryProvider)
              .uploadStreamInChunks(
                bytes: fileBytes,
                filename: filename,
                mediaSubtype: 'media',
                fileSize: fileBytes.length,
                onProgress: (_, _) {},
              );
          if (uploadIdStr.isNotEmpty) {
            uploadIds.add(uploadIdStr);
          }
        }
      } else if (_selectedFile != null) {
        final PlatformFile file = _selectedFile!;
        final Uint8List fileBytes = _previewBytesList.isNotEmpty
            ? _previewBytesList.first
            : await file.readAsBytes();
        String filename = file.name;
        if (!filename.contains('.')) {
          filename = '$filename.jpg';
        }
        final String uploadIdStr = await ref
            .read(chatRepositoryProvider)
            .uploadStreamInChunks(
              bytes: fileBytes,
              filename: filename,
              mediaSubtype: 'media',
              fileSize: fileBytes.length,
              onProgress: (_, _) {},
            );
        if (uploadIdStr.isNotEmpty) {
          uploadIds = <String>[uploadIdStr];
        }
      }

      await ref.read(niosgramProvider.notifier).createPost(
            text,
            uploadIds: uploadIds,
            uploadId: uploadIds?.firstOrNull,
          );

      if (mounted) {
        if (ref.read(uiSettingsProvider).haptics) HapticService.confirm();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (ref.read(uiSettingsProvider).haptics) HapticService.destructive();
      final String formatted = AppErrorFormatter.format(e).toString();
      setState(() => _error = formatted);
      if (mounted) {
        AppToast.showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isWide = screenWidth >= 760;

    final AuthState auth = ref.watch(authProvider);
    final String displayName = auth.profile?.displayName ??
        auth.session?.displayName ??
        context.l10n.profileGuestName;

    return ListenableBuilder(
      listenable: _textController,
      builder: (BuildContext context, Widget? child) {
        final bool canRoutePop = ModalRoute.of(context)?.canPop ?? false;
        final bool hasDraft =
            _textController.text.trim().isNotEmpty || _selectedFile != null;
        return PopScope(
          canPop: canRoutePop && !hasDraft,
          onPopInvokedWithResult: (bool didPop, Object? result) async {
            if (didPop) return;
            if (!hasDraft) {
              if (canRoutePop) {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              } else {
                try {
                  context.go('/main/niosgram');
                } catch (_) {
                  Navigator.maybePop(context);
                }
              }
              return;
            }
            final bool? confirm = await showAppConfirmDialog(
              context: context,
              title: context.l10n.commonDiscardChanges,
              subtitle: context.l10n.commonDiscardChangesDesc,
              confirmLabel: context.l10n.commonDiscardChangesConfirm,
              cancelLabel: context.l10n.commonCancel,
            );
            if (confirm == true && context.mounted) {
              if (canRoutePop) {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              } else {
                try {
                  context.go('/main/niosgram');
                } catch (_) {
                  Navigator.maybePop(context);
                }
              }
            }
          },
          child: child!,
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.postNewPost),
          centerTitle: isWide,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              if (_textController.text.trim().isEmpty && _selectedFile == null) {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/main/niosgram');
                }
                return;
              }
              final bool? confirm = await showAppConfirmDialog(
                context: context,
                title: context.l10n.commonDiscardChanges,
                subtitle: context.l10n.commonDiscardChangesDesc,
                confirmLabel: context.l10n.commonDiscardChangesConfirm,
                cancelLabel: context.l10n.commonCancel,
              );
              if (confirm == true && context.mounted) {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/main/niosgram');
                }
              }
            },
          ),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.l10n.postPublish),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 24 : 16,
                  vertical: 12,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: isWide
                        ? (isDark
                            ? scheme.surfaceContainerLow
                            : scheme.surface)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    border: isWide
                        ? Border.all(
                            color: scheme.outlineVariant.withValues(
                              alpha: isDark ? 0.20 : 0.40,
                            ),
                          )
                        : null,
                    boxShadow: isWide && !isDark
                        ? <BoxShadow>[
                            BoxShadow(
                              color: scheme.shadow.withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  padding: EdgeInsets.all(isWide ? 20 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Author Row
                      Row(
                        children: <Widget>[
                          PulseAvatar(
                            name: displayName,
                            avatarUrl: auth.profile?.avatarUrl,
                            radius: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  displayName,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Публикация в NiosGram',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Text input
                      Container(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(
                            alpha: isDark ? 0.35 : 0.40,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: TextField(
                          controller: _textController,
                          maxLines: 8,
                          minLines: 4,
                          style: textTheme.bodyLarge?.copyWith(fontSize: 15),
                          decoration: InputDecoration(
                            hintText: context.l10n.postHint,
                            hintStyle: TextStyle(
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.70),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Media preview (compact horizontal strip ~84dp)
                      if (_previewBytesList.isNotEmpty) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Прикрепленные фото (${_previewBytesList.length}/5)',
                            style: textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 84,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _previewBytesList.length +
                                (_previewBytesList.length < 5 ? 1 : 0),
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (BuildContext context, int index) {
                              if (index == _previewBytesList.length) {
                                // [+] Slot to add more photos
                                return Material(
                                  color: scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(14),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: _pickMedia,
                                    child: Container(
                                      width: 84,
                                      height: 84,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: scheme.outlineVariant
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: <Widget>[
                                          Icon(
                                            Icons.add_photo_alternate_rounded,
                                            size: 24,
                                            color: scheme.primary,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Ещё фото',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: scheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final bool isVideo = _isVideoFile(_selectedFiles[index].name);
                              return Stack(
                                children: <Widget>[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: isVideo
                                        ? Container(
                                            width: 84,
                                            height: 84,
                                            decoration: BoxDecoration(
                                              color: scheme.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            alignment: Alignment.center,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: <Widget>[
                                                Icon(Icons.videocam_rounded, size: 30, color: scheme.primary),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Видео',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: scheme.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : Image.memory(
                                            _previewBytesList[index],
                                            width: 84,
                                            height: 84,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Material(
                                      color: scheme.scrim.withValues(alpha: 0.65),
                                      shape: const CircleBorder(),
                                      child: Tooltip(
                                        message: 'Удалить',
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: () => setState(() {
                                            _selectedFiles.removeAt(index);
                                            _previewBytesList.removeAt(index);
                                            _selectedFile =
                                                _selectedFiles.firstOrNull;
                                          }),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Icon(
                                              Icons.close_rounded,
                                              size: 14,
                                              color: scheme.onPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Error message
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: scheme.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: scheme.onErrorContainer,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? scheme.surfaceContainerLow : scheme.surface,
            border: Border(
              top: BorderSide(
                color: scheme.outlineVariant
                    .withValues(alpha: isDark ? 0.20 : 0.35),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool isNarrow = constraints.maxWidth < 360;
                final bool isVeryNarrow = constraints.maxWidth < 310;
                return Row(
                  children: <Widget>[
                    FilledButton.tonalIcon(
                      onPressed:
                          _selectedFiles.length >= 5 ? null : _pickMedia,
                      icon: Badge(
                        isLabelVisible: _selectedFiles.isNotEmpty,
                        label: Text('${_selectedFiles.length}'),
                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 19,
                        ),
                      ),
                      label: Text(
                        _selectedFiles.isEmpty
                            ? (isNarrow ? 'Фото' : 'Добавить фото')
                            : (isNarrow
                                ? '${_selectedFiles.length}/5'
                                : 'Фото (${_selectedFiles.length}/5)'),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 10 : 14,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_textController.text.isNotEmpty && !isVeryNarrow)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(
                          '${_textController.text.length} симв.',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: _isLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 16),
                      label: Text(
                        isNarrow ? 'Пост' : context.l10n.postPublish,
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 12 : 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
