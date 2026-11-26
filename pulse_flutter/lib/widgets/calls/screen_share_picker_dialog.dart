import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:material_ui/material_ui.dart';

import '../pulse_loading_indicator.dart';

/// Result of the screen-share picker. [sourceId] is null on web/mobile where
/// the platform shows its own chooser.
class ScreenShareChoice {
  const ScreenShareChoice({this.sourceId});
  final String? sourceId;
}

bool get _isDesktopNative =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

/// Asks which screen/window to share. Desktop shows a thumbnail grid; every
/// other platform returns immediately so the OS chooser takes over.
Future<ScreenShareChoice?> showScreenSharePicker(
  BuildContext context, {
  required int maxScreenHeight,
}) async {
  if (!_isDesktopNative) return const ScreenShareChoice();
  return showDialog<ScreenShareChoice>(
    context: context,
    builder: (_) => _ScreenSharePickerDialog(maxScreenHeight: maxScreenHeight),
  );
}

class _ScreenSharePickerDialog extends StatefulWidget {
  const _ScreenSharePickerDialog({required this.maxScreenHeight});
  final int maxScreenHeight;

  @override
  State<_ScreenSharePickerDialog> createState() =>
      _ScreenSharePickerDialogState();
}

class _ScreenSharePickerDialogState extends State<_ScreenSharePickerDialog> {
  List<DesktopCapturerSource> _sources = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sources = await desktopCapturer.getSources(
        types: [SourceType.Screen, SourceType.Window],
        thumbnailSize: ThumbnailSize(320, 180),
      );
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось получить список экранов';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tier = widget.maxScreenHeight > 720
        ? '${widget.maxScreenHeight}p · NiosPlus'
        : '${widget.maxScreenHeight}p';
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Демонстрация экрана')),
          Chip(label: Text(tier)),
        ],
      ),
      content: SizedBox(
        width: 640,
        height: 420,
        child: _loading
            ? const Center(child: AppLoadingIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 16 / 11,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _sources.length,
                itemBuilder: (context, i) {
                  final s = _sources[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(
                      context,
                    ).pop(ScreenShareChoice(sourceId: s.id)),
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Expanded(
                            child: s.thumbnail != null
                                ? Image.memory(
                                    s.thumbnail!,
                                    fit: BoxFit.contain,
                                    gaplessPlayback: true,
                                  )
                                : const Icon(Icons.desktop_windows_rounded),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
      ],
    );
  }
}
