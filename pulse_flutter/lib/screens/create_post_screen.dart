import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/image_compressor.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

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
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.media,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final PlatformFile file = result.files.first;
    if ((file.size) > _maxFileBytes) {
      setState(() => _error = context.l10n.postFileTooLarge);
      return;
    }

    Uint8List? previewBytes = file.bytes;
    if (previewBytes != null) {
      final Uint8List? compressed = await ImageCompressor.compressImageBytes(
        bytes: previewBytes,
        fileName: file.name,
      );
      if (compressed != null) previewBytes = compressed;
    }

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

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      int? uploadId;
      if (_selectedFile != null) {
        final PlatformFile file = _selectedFile!;
        final String ext =
            file.name.contains('.') ? file.name.split('.').last : '';
        final String mediaSubtype = _mediaSubtype(ext);
        final String uploadIdStr = await ref
            .read(chatRepositoryProvider)
            .uploadStreamInChunks(
              readStream: Stream<List<int>>.value(file.bytes!),
              filename: file.name,
              mediaSubtype: mediaSubtype,
              fileSize: file.size,
              onProgress: (_, _) {},
            );
        uploadId = int.tryParse(uploadIdStr);
      }

      await ref.read(niosgramProvider.notifier).createPost(
            text,
            uploadId: uploadId,
          );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mediaSubtype(String ext) {
    const Map<String, String> map = <String, String>{
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'mp3': 'audio/mpeg',
      'aac': 'audio/aac',
    };
    return map[ext.toLowerCase()] ?? 'application/octet-stream';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: _textController.text.trim().isEmpty && _selectedFile == null,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final bool? confirm = await showAppConfirmDialog(
          context: context,
          title: context.l10n.commonDiscardChanges,
          subtitle: context.l10n.commonDiscardChangesDesc,
          confirmLabel: context.l10n.commonDiscardChangesConfirm,
          cancelLabel: context.l10n.commonCancel,
        );
        if (confirm == true && mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.postNewPost),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            // Text input
            TextField(
              controller: _textController,
              maxLines: 8,
              minLines: 4,
              decoration: InputDecoration(
                hintText: context.l10n.postHint,
                filled: true,
                fillColor: scheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 12),

            // Media preview
            if (_previewBytes != null) ...<Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _previewBytes!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _selectedFile = null;
                    _previewBytes = null;
                  }),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: Text(context.l10n.postRemove),
                ),
              ),
            ],

            // Attach button
            if (_previewBytes == null)
              OutlinedButton.icon(
                onPressed: _pickMedia,
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(context.l10n.postAttachMedia),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

            // Error
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: scheme.error),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
