import 'package:pulse_flutter/core/utils/cancellation_token.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_text.dart';
import 'dart:typed_data';
import 'package:pulse_flutter/models/interactive_message.dart';
import 'package:pulse_flutter/widgets/chat/interactive_composer.dart';
import 'package:pulse_flutter/widgets/feed_poll_card.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_picker.dart';
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
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/post_media_strip.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key, this.autoPickMedia = false});

  final bool autoPickMedia;

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final TextEditingController _textController = CustomEmojiTextController();
  PlatformFile? _selectedFile;
  List<PlatformFile> _selectedFiles = <PlatformFile>[];
  List<Uint8List> _previewBytesList = <Uint8List>[];
  bool _isLoading = false;
  bool _isPickingMedia = false;
  CancellationToken? _uploadCancellation;
  Map<String, dynamic>? _poll;
  String? _error;

  static const int _maxPostLength = 2000;
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
    _uploadCancellation?.cancel();
    _textController.dispose();
    super.dispose();
  }

  bool _isVideoFile(String name) {
    final String ext = name.split('.').last.toLowerCase();
    return ext == 'mp4' ||
        ext == 'mov' ||
        ext == 'mkv' ||
        ext == 'webm' ||
        ext == 'avi' ||
        ext == '3gp';
  }

  Future<Uint8List> _readMediaBytes(
    PlatformFile file,
    String sizeError, {
    CancellationToken? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    final length = await file.length();
    if (length <= 0 || length > _maxFileBytes) throw FormatException(sizeError);
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      cancellation?.throwIfCancelled();
      if (bytes.length + chunk.length > _maxFileBytes) {
        throw FormatException(sizeError);
      }
      bytes.add(chunk);
    }
    if (bytes.isEmpty) throw FormatException(sizeError);
    return bytes.takeBytes();
  }

  Future<void> _pickMedia() async {
    if (_isPickingMedia ||
        _isLoading ||
        ref.read(authProvider.notifier).isLoggingOut) {
      return;
    }
    final int availableSlots = 5 - _selectedFiles.length;
    if (availableSlots <= 0) return;
    _isPickingMedia = true;
    final sizeError = context.l10n.postFileTooLarge;
    final account = ref.read(authProvider).session;
    bool active() =>
        mounted &&
        !ref.read(authProvider.notifier).isLoggingOut &&
        ref.read(authProvider).session?.userId == account?.userId &&
        ref.read(authProvider).session?.accessToken == account?.accessToken;
    try {
      final result = await FilePicker.pickFiles(type: FileType.media);
      if (!active() || result.isEmpty || _isLoading) return;
      final validFiles = List<PlatformFile>.from(_selectedFiles);
      final previews = List<Uint8List>.from(_previewBytesList);
      for (final file in result.take(availableSlots)) {
        final length = await file.length();
        if (!active()) return;
        if (length <= 0 || length > _maxFileBytes) {
          setState(() => _error = sizeError);
          continue;
        }
        Uint8List previewBytes = Uint8List(0);
        if (!_isVideoFile(file.name)) {
          previewBytes = await _readMediaBytes(file, sizeError);
          if (!active()) return;
          final compressed = await ImageCompressor.compressImageBytes(
            bytes: previewBytes,
            fileName: file.name,
          );
          if (!active()) return;
          if (compressed != null) previewBytes = compressed;
        }
        validFiles.add(file);
        previews.add(previewBytes);
      }
      if (active() && validFiles.length != _selectedFiles.length) {
        setState(() {
          _selectedFiles = validFiles;
          _previewBytesList = previews;
          _selectedFile = validFiles.firstOrNull;
          _error = null;
        });
      }
    } catch (error) {
      if (active()) {
        setState(
          () => _error = AppErrorFormatter.format(
            error,
            l10n: context.l10n,
          ).toString(),
        );
      }
    } finally {
      _isPickingMedia = false;
    }
  }

  Future<void> _submit() async {
    if (_isLoading ||
        _isPickingMedia ||
        ref.read(authProvider.notifier).isLoggingOut) {
      return;
    }
    final String text = _textController.text.trim();
    if (text.isEmpty &&
        _poll == null &&
        _selectedFiles.isEmpty &&
        _selectedFile == null) {
      setState(() => _error = context.l10n.postEmptyContent);
      return;
    }

    if (ref.read(uiSettingsProvider).haptics) HapticService.tap();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final files = List<PlatformFile>.of(
      _selectedFiles.isNotEmpty ? _selectedFiles : [?_selectedFile],
    );
    final previews = List<Uint8List>.of(_previewBytesList);
    final poll = _poll == null ? null : Map<String, dynamic>.of(_poll!);
    final account = ref.read(authProvider).session;
    final repository = ref.read(chatRepositoryProvider);
    final feed = ref.read(niosgramProvider.notifier);
    final sizeError = context.l10n.postFileTooLarge;
    final cancellation = CancellationToken();
    _uploadCancellation = cancellation;
    bool active() =>
        mounted &&
        !ref.read(authProvider.notifier).isLoggingOut &&
        ref.read(authProvider).session?.userId == account?.userId &&
        ref.read(authProvider).session?.accessToken == account?.accessToken;
    try {
      final uploadIds = <String>[];
      for (var i = 0; i < files.length; i++) {
        cancellation.throwIfCancelled();
        if (!active()) return;
        final file = files[i];
        // Video previews are deliberately empty; they are never upload data.
        final bytes =
            !_isVideoFile(file.name) &&
                i < previews.length &&
                previews[i].isNotEmpty
            ? previews[i]
            : await _readMediaBytes(
                file,
                sizeError,
                cancellation: cancellation,
              );
        if (!active()) return;
        final uploadId = await repository.uploadStreamInChunks(
          bytes: bytes,
          filename: file.name.contains('.') ? file.name : '${file.name}.jpg',
          mediaSubtype: 'media',
          fileSize: bytes.length,
          onProgress: (_, _) {},
          cancellationToken: cancellation,
        );
        if (!active()) return;
        if (uploadId.isEmpty) throw StateError('empty_upload_id');
        uploadIds.add(uploadId);
      }
      if (!active()) return;
      await feed.createPost(
        text,
        uploadIds: uploadIds,
        poll: poll,
        uploadId: uploadIds.firstOrNull,
      );

      if (mounted && active()) {
        if (ref.read(uiSettingsProvider).haptics) HapticService.confirm();
        if (_textController.text.trim() == text) {
          Navigator.of(context).pop();
        } else {
          AppToast.showSuccess(context, context.l10n.auditPostPublished);
        }
      }
    } catch (e) {
      if (!mounted || !active() || cancellation.isCancelled) return;
      if (ref.read(uiSettingsProvider).haptics) HapticService.destructive();
      final String formatted = AppErrorFormatter.format(
        e,
        l10n: context.l10n,
      ).toString();
      setState(() => _error = formatted);
      if (mounted) {
        AppToast.showError(context, e);
      }
    } finally {
      if (identical(_uploadCancellation, cancellation)) {
        _uploadCancellation = null;
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isWide = screenWidth >= Breakpoints.medium;

    final AuthState auth = ref.watch(authProvider);
    final String displayName =
        auth.profile?.displayName ??
        auth.session?.displayName ??
        context.l10n.profileGuestName;

    return ListenableBuilder(
      listenable: _textController,
      builder: (BuildContext context, Widget? child) {
        final bool canRoutePop = ModalRoute.of(context)?.canPop ?? false;
        final bool hasDraft =
            _textController.text.trim().isNotEmpty ||
            _selectedFile != null ||
            _poll != null;
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
              if (_textController.text.trim().isEmpty &&
                  _poll == null &&
                  _selectedFile == null) {
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
                    ? const AppLoadingIndicator(size: 18)
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
                        ? (isDark ? scheme.surfaceContainerLow : scheme.surface)
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
                                    color: scheme.onSurfaceVariant.withValues(
                                      alpha: 0.75,
                                    ),
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
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: TextField(
                          controller: _textController,
                          maxLines: 8,
                          minLines: 1,
                          inputFormatters: [
                            CustomEmojiLengthFormatter(_maxPostLength),
                          ],
                          buildCounter:
                              (
                                _, {
                                required int currentLength,
                                required bool isFocused,
                                int? maxLength,
                              }) => null,
                          style: textTheme.bodyLarge?.copyWith(fontSize: 15),
                          decoration: InputDecoration(
                            hintText: context.l10n.postHint,
                            hintStyle: TextStyle(
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.70,
                              ),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: CustomEmojiComposerButton(
                          controller: _textController,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final kind in ['poll', 'quiz'])
                            TextButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () async {
                                      final result =
                                          await showInteractiveComposer(
                                            context,
                                            kind,
                                          );
                                      final parsed = result == null
                                          ? null
                                          : InteractiveMessage.parse(result);
                                      if (parsed != null && mounted) {
                                        setState(
                                          () =>
                                              _poll = Map<String, dynamic>.from(
                                                parsed.data,
                                              ),
                                        );
                                      }
                                    },
                              icon: InteractiveIcon(kind),
                              label: Text(
                                kind == 'quiz'
                                    ? 'Анонимная викторина'
                                    : 'Анонимный опрос',
                              ),
                            ),
                          if (_poll != null)
                            TextButton(
                              onPressed: () => setState(() => _poll = null),
                              child: const Text('Убрать опрос'),
                            ),
                        ],
                      ),
                      if (_poll != null)
                        FeedPollCard(postId: 0, poll: _poll!, preview: true),
                      // Media preview (reusable PostMediaStrip)
                      if (_previewBytesList.isNotEmpty) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${context.l10n.postAttachMedia} (${_previewBytesList.length}/5)',
                            style: textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        PostMediaStrip(
                          selectedFiles: _selectedFiles,
                          previewBytesList: _previewBytesList,
                          isLoading: _isLoading,
                          tileSize: 84,
                          onAdd: _pickMedia,
                          onRemove: (int index) {
                            setState(() {
                              _selectedFiles.removeAt(index);
                              _previewBytesList.removeAt(index);
                              _selectedFile = _selectedFiles.firstOrNull;
                            });
                          },
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
                color: scheme.outlineVariant.withValues(
                  alpha: isDark ? 0.20 : 0.35,
                ),
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
                      onPressed: _selectedFiles.length >= 5 ? null : _pickMedia,
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
                            ? (isNarrow ? 'Фото' : context.l10n.postAttachMedia)
                            : (isNarrow
                                  ? '${_selectedFiles.length}/5'
                                  : '${context.l10n.postAttachMedia} (${_selectedFiles.length}/5)'),
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
                          '${customEmojiLength(_textController.text)} / $_maxPostLength',
                          style: textTheme.bodySmall?.copyWith(
                            color:
                                customEmojiLength(_textController.text) >
                                    (_maxPostLength - 200)
                                ? scheme.error
                                : scheme.onSurfaceVariant.withValues(
                                    alpha: 0.6,
                                  ),
                            fontSize: 11,
                            fontWeight:
                                customEmojiLength(_textController.text) >
                                    (_maxPostLength - 200)
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: _isLoading
                          ? AppLoadingIndicator(
                              size: 16,
                              color: scheme.onPrimary,
                            )
                          : const Icon(Icons.send_rounded, size: 16),
                      label: Text(isNarrow ? 'Пост' : context.l10n.postPublish),
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
