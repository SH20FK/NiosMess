import 'package:pulse_flutter/core/clipboard/file_drop_stub.dart'
    if (dart.library.js_interop) 'package:pulse_flutter/core/clipboard/file_drop_web.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/clipboard/pasted_image.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';

class ChatFileDropTarget extends StatefulWidget {
  const ChatFileDropTarget({
    required this.conversationId,
    required this.child,
    required this.onFiles,
    this.enabled = true,
    super.key,
  });
  final int conversationId;
  final Widget child;
  final bool enabled;
  final ValueChanged<List<PastedImage>> onFiles;
  @override
  State<ChatFileDropTarget> createState() => _ChatFileDropTargetState();
}

class _ChatFileDropTargetState extends State<ChatFileDropTarget> {
  bool _hover = false, _reading = false;
  int _generation = 0;
  late VoidCallback _detach;
  Rect? _bounds() {
    final render = context.findRenderObject();
    return render is RenderBox && render.hasSize
        ? render.localToGlobal(Offset.zero) & render.size
        : null;
  }

  void _listen() {
    _detach = listenForFileDrop(
      bounds: _bounds,
      canHandle: () => _active,
      onHover: (value) {
        if (mounted && value != _hover) setState(() => _hover = value);
      },
      onFiles: (files) => widget.onFiles(files),
      onError: (error) {
        if (mounted) {
          AppToast.showError(
            context,
            error is ClipboardImageLimit
                ? context.l10n.chatBatchLimit
                : context.l10n.chatDropError,
          );
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _listen();
  }

  bool get _active =>
      (kIsWeb ||
          {
            TargetPlatform.windows,
            TargetPlatform.macOS,
            TargetPlatform.linux,
          }.contains(defaultTargetPlatform)) &&
      mounted &&
      widget.enabled &&
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.isCurrentOf(context) ?? true);
  @override
  void didUpdateWidget(covariant ChatFileDropTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _detach();
      _listen();
      _generation++;
      _hover = false;
      _reading = false;
    }
  }

  Future<void> _drop(DropDoneDetails details) async {
    setState(() => _hover = false);
    if (!_active || _reading || details.files.isEmpty) return;
    final generation = _generation;
    _reading = true;
    try {
      if (details.files.length > 10) throw const ClipboardImageLimit();
      var total = 0;
      for (final file in details.files) {
        total += await file.length();
        if (total > 100 * 1024 * 1024) throw const ClipboardImageLimit();
      }
      final files = <PastedImage>[];
      for (final file in details.files) {
        final bytes = await file.readAsBytes();
        if (!_active || generation != _generation) return;
        files.add(
          PastedImage(
            bytes: bytes,
            name: file.name,
            mimeType: file.mimeType ?? 'application/octet-stream',
          ),
        );
      }
      if (_active && generation == _generation) widget.onFiles(files);
    } catch (error) {
      if (mounted && _active && generation == _generation) {
        AppToast.showError(
          context,
          error is ClipboardImageLimit
              ? context.l10n.chatBatchLimit
              : context.l10n.chatDropError,
        );
      }
    } finally {
      if (generation == _generation) _reading = false;
    }
  }

  @override
  void dispose() {
    _detach();
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (_hover)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHigh.withValues(alpha: .94),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.file_upload_outlined,
                          size: 56,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.chatDropFiles,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    if (kIsWeb) return surface;
    return DropTarget(
      enable: _active,
      onDragEntered: (_) {
        if (_active) setState(() => _hover = true);
      },
      onDragExited: (_) {
        if (mounted) setState(() => _hover = false);
      },
      onDragDone: (details) => unawaited(_drop(details)),
      child: surface,
    );
  }
}
