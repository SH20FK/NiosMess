import 'package:pulse_flutter/core/media/media_album.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_text.dart';
import 'package:pulse_flutter/core/clipboard/pasted_image.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

Future<void> showPastedImagesDialog(
  BuildContext context, {
  required List<PastedImage> images,
  required String caption,
  required Future<void> Function(PastedImage image, String caption) onSend,
  Future<void> Function(List<PastedImage>, String)? onSendAlbum,
}) => AppModal.showDialog<void>(
  context: context,
  maxWidth: 640,
  isDismissible: false,
  builder: (_) => PastedImagesDialog(
    images: images,
    initialCaption: caption,
    onSend: onSend,
    onSendAlbum: onSendAlbum,
  ),
);

class PastedImagesDialog extends StatefulWidget {
  const PastedImagesDialog({
    required this.images,
    required this.initialCaption,
    required this.onSend,
    this.onSendAlbum,
    super.key,
  });
  final List<PastedImage> images;
  final String initialCaption;
  final Future<void> Function(PastedImage image, String caption) onSend;
  final Future<void> Function(List<PastedImage>, String)? onSendAlbum;
  @override
  State<PastedImagesDialog> createState() => _PastedImagesDialogState();
}

class _PastedImagesDialogState extends State<PastedImagesDialog> {
  late final _caption = CustomEmojiTextController(text: widget.initialCaption);
  late final _remaining = List<PastedImage>.of(widget.images);
  bool _busy = false;
  bool _album = true;
  int _preview = 0;
  bool get _canAlbum =>
      widget.onSendAlbum != null &&
      _remaining.length > 1 &&
      _remaining.length <= 10 &&
      _remaining.every((i) => MediaAlbum.imageExtension(i.bytes) != null) &&
      _remaining.fold<int>(0, (n, i) => n + i.bytes.length) <=
          MediaAlbum.maxBytes;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_album && _canAlbum) {
        await widget.onSendAlbum!(List.of(_remaining), _caption.text);
        if (!mounted) return;
        _remaining.clear();
      }
      while (_remaining.isNotEmpty) {
        final image = _remaining.first;
        await widget.onSend(image, _caption.text);
        if (!mounted) return;
        setState(() {
          _remaining.removeAt(0);
          _caption.clear();
        });
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, context.l10n.pasteImageSendFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _remaining.length == 1
                    ? context.l10n.pasteImageTitle
                    : context.l10n.chatBatchTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (_remaining.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: SizedBox(
                      height: (MediaQuery.sizeOf(context).height * .3).clamp(
                        100,
                        260,
                      ),
                      child:
                          MediaAlbum.imageExtension(
                                _remaining[_preview.clamp(
                                      0,
                                      _remaining.length - 1,
                                    )]
                                    .bytes,
                              ) ==
                              null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  _remaining[_preview.clamp(
                                        0,
                                        _remaining.length - 1,
                                      )]
                                      .name,
                                ),
                              ),
                            )
                          : Image.memory(
                              _remaining[_preview.clamp(
                                    0,
                                    _remaining.length - 1,
                                  )]
                                  .bytes,
                              fit: BoxFit.contain,
                              cacheWidth: 1600,
                              gaplessPlayback: true,
                              errorBuilder: (_, _, _) => Center(
                                child: Text(context.l10n.pasteImageFailed),
                              ),
                            ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              if (_remaining.length > 1)
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _remaining.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => SizedBox(
                      width: 88,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: InkWell(
                              onTap: _busy
                                  ? null
                                  : () => setState(() => _preview = index),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child:
                                    MediaAlbum.imageExtension(
                                          _remaining[index].bytes,
                                        ) !=
                                        null
                                    ? Image.memory(
                                        _remaining[index].bytes,
                                        cacheWidth: 176,
                                        fit: BoxFit.contain,
                                      )
                                    : Center(
                                        child: Text(
                                          _remaining[index].name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton.filledTonal(
                              tooltip: context.l10n.chatBatchRemove,
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                      _remaining.removeAt(index);
                                      _preview = 0;
                                    }),
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_canAlbum)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.chatBatchAlbum),
                  value: _album,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _album = value),
                ),
              if (_remaining.length > 1)
                Text(context.l10n.pasteImageCount(_remaining.length)),
              TextField(
                controller: _caption,
                readOnly: _busy,
                minLines: 1,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.l10n.pasteImageCaption,
                ),
              ),
              const SizedBox(height: 20),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 12,
                overflowSpacing: 8,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: Text(context.l10n.commonCancel),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: _busy ? null : _send,
                    icon: _busy
                        ? const AppLoadingIndicator(size: 20)
                        : const Icon(Icons.send_rounded),
                    label: Text(context.l10n.interactiveSend),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
