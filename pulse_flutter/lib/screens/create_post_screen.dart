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
  Uint8List? _previewBytes;
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

  Future<void> _pickMedia() async {
    final List<PlatformFile> result = await FilePicker.pickFiles(
      type: FileType.media,
    );
    if (result.isEmpty) return;
    final PlatformFile file = result.first;
    if ((await file.length()) > _maxFileBytes) {
      setState(() => _error = context.l10n.postFileTooLarge);
      return;
    }

    Uint8List previewBytes = await file.readAsBytes();
    final Uint8List? compressed = await ImageCompressor.compressImageBytes(
      bytes: previewBytes,
      fileName: file.name,
    );
    if (compressed != null) previewBytes = compressed;

    setState(() {
      _selectedFile = file;
      _previewBytes = previewBytes;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final String text = _textController.text.trim();
    if (text.isEmpty && _selectedFile == null) {
      setState(() => _error = context.l10n.postEmptyContent);
      return;
    }

    if (ref.read(uiSettingsProvider).haptics) HapticService.tap();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      int? uploadId;
      if (_selectedFile != null) {
        final PlatformFile file = _selectedFile!;
        final Uint8List fileBytes = await file.readAsBytes();
        final String uploadIdStr = await ref
            .read(chatRepositoryProvider)
            .uploadStreamInChunks(
              bytes: fileBytes,
              filename: file.name,
              mediaSubtype: 'media',
              fileSize: fileBytes.length,
              onProgress: (_, _) {},
            );
        uploadId = int.tryParse(uploadIdStr);
      }

      await ref.read(niosgramProvider.notifier).createPost(
            text,
            uploadId: uploadId,
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
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

                      // Media preview
                      if (_previewBytes != null) ...<Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: <Widget>[
                              Container(
                                width: double.infinity,
                                constraints: const BoxConstraints(
                                  maxHeight: 420,
                                  minHeight: 160,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: scheme.outlineVariant
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Image.memory(
                                  _previewBytes!,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                ),
                              ),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.60),
                                  shape: const CircleBorder(),
                                  child: Tooltip(
                                    message: context.l10n.postRemove,
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () => setState(() {
                                        _selectedFile = null;
                                        _previewBytes = null;
                                      }),
                                      child: const Padding(
                                        padding: EdgeInsets.all(7),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Bottom action toolbar
                      Row(
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: _pickMedia,
                            icon: const Icon(Icons.image_outlined, size: 20),
                            label: Text(
                              _selectedFile == null
                                  ? context.l10n.postAttachMedia
                                  : 'Заменить фото',
                            ),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (_textController.text.isNotEmpty)
                            Text(
                              '${_textController.text.length} симв.',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),

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
      ),
    );
  }
}
