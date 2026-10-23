import 'package:flutter/material.dart';
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
}) => AppModal.showDialog<void>(
  context: context,
  maxWidth: 640,
  isDismissible: false,
  builder: (_) => PastedImagesDialog(
    images: images,
    initialCaption: caption,
    onSend: onSend,
  ),
);

class PastedImagesDialog extends StatefulWidget {
  const PastedImagesDialog({
    required this.images,
    required this.initialCaption,
    required this.onSend,
    super.key,
  });
  final List<PastedImage> images;
  final String initialCaption;
  final Future<void> Function(PastedImage image, String caption) onSend;
  @override
  State<PastedImagesDialog> createState() => _PastedImagesDialogState();
}

class _PastedImagesDialogState extends State<PastedImagesDialog> {
  late final _caption = TextEditingController(text: widget.initialCaption);
  late final _remaining = List<PastedImage>.of(widget.images);
  bool _busy = false;
  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.pasteImageTitle,
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
                    child: Image.memory(
                      _remaining.first.bytes,
                      fit: BoxFit.contain,
                      cacheWidth: 1600,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) =>
                          Center(child: Text(context.l10n.pasteImageFailed)),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
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
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
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
    );
  }
}
