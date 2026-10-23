import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/clipboard/pasted_image.dart';
import 'package:pulse_flutter/core/clipboard/image_paste_stub.dart'
    if (dart.library.js_interop) 'package:pulse_flutter/core/clipboard/image_paste_web.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';

class BrowserImagePasteTarget extends StatefulWidget {
  const BrowserImagePasteTarget({
    required this.focusNode,
    required this.onImages,
    required this.child,
    this.enabled = true,
    super.key,
  });
  final FocusNode focusNode;
  final ValueChanged<List<PastedImage>> onImages;
  final Widget child;
  final bool enabled;
  @override
  State<BrowserImagePasteTarget> createState() =>
      _BrowserImagePasteTargetState();
}

class _BrowserImagePasteTargetState extends State<BrowserImagePasteTarget> {
  late final VoidCallback _detach;
  bool _canHandle() =>
      mounted &&
      widget.enabled &&
      widget.focusNode.hasFocus &&
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.isCurrentOf(context) ?? true);
  @override
  void initState() {
    super.initState();
    _detach = listenForImagePaste(
      canHandle: _canHandle,
      onImages: (images) => widget.onImages(images),
      onError: (error) => AppToast.showError(
        context,
        error is ClipboardImageLimit
            ? context.l10n.pasteImageLimit
            : context.l10n.pasteImageFailed,
      ),
    );
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
