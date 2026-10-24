import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/services/calls/call_devices.dart';
import 'package:pulse_flutter/services/calls/microphone_meter_stub.dart'
    if (dart.library.js_interop) 'package:pulse_flutter/services/calls/microphone_meter_web.dart';
import 'package:pulse_flutter/services/calls/output_tone_stub.dart'
    if (dart.library.js_interop) 'package:pulse_flutter/services/calls/output_tone_web.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

Future<bool> showCallDevicesDialog(
  BuildContext context, {
  bool video = true,
  bool preflight = false,
  Future<void> Function(CallDevices)? onApply,
}) async =>
    await AppModal.showDialog<bool>(
      context: context,
      maxWidth: 560,
      builder: (_) => CallDevicesDialog(
        video: video,
        preflight: preflight,
        onApply: onApply,
      ),
    ) ??
    false;

class CallDevicesDialog extends ConsumerStatefulWidget {
  const CallDevicesDialog({
    this.video = true,
    this.preflight = false,
    this.onApply,
    super.key,
  });
  final bool video, preflight;
  final Future<void> Function(CallDevices)? onApply;
  @override
  ConsumerState<CallDevicesDialog> createState() => _CallDevicesDialogState();
}

class _CallDevicesDialogState extends ConsumerState<CallDevicesDialog> {
  late CallDevices _selection;
  List<MediaDeviceInfo> _devices = [];
  final _renderer = RTCVideoRenderer();
  Future<void>? _rendererInit;
  MediaStream? _stream;
  MicrophoneMeter? _meter;
  Timer? _timer;
  bool _ready = false, _busy = false, _toneBusy = false, _reading = false;
  String? _error;
  double? _level;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _selection = ref.read(callDevicesProvider);
    unawaited(_enumerate());
  }

  Future<void> _enumerate() async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      if (mounted) setState(() => _devices = devices);
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.callDevicesUnavailable);
    }
  }

  Future<void> _releasePreview() async {
    _timer?.cancel();
    _timer = null;
    final meter = _meter;
    _meter = null;
    final stream = _stream;
    _stream = null;
    if (_ready) _renderer.srcObject = null;
    try {
      await meter?.dispose();
    } catch (_) {}
    if (stream != null) {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
    }
  }

  Future<void> _test() async {
    if (_busy) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _level = null;
    });
    try {
      await _releasePreview();
      await (_rendererInit ??= _renderer.initialize().then((_) {
        _ready = true;
      }));
      if (!mounted || generation != _generation) return;
      final stream = await navigator.mediaDevices.getUserMedia(
        _selection.constraints(video: widget.video),
      );
      if (!mounted || generation != _generation) {
        for (final track in stream.getTracks()) {
          await track.stop();
        }
        await stream.dispose();
        return;
      }
      _stream = stream;
      if (widget.video) _renderer.srcObject = stream;
      try {
        final meter = await openMicrophoneMeter(stream);
        if (!mounted || generation != _generation) {
          await meter.dispose();
          return;
        }
        _meter = meter;
      } catch (_) {}
      await _enumerate();
      if (!mounted || generation != _generation) return;
      _timer = Timer.periodic(const Duration(milliseconds: 120), (_) async {
        if (_reading || !mounted || _meter == null) return;
        _reading = true;
        try {
          final level = await _meter!.readLevel();
          if (mounted && generation == _generation) {
            setState(() => _level = level);
          }
        } catch (_) {
        } finally {
          _reading = false;
        }
      });
    } catch (_) {
      await _releasePreview();
      if (mounted) setState(() => _error = context.l10n.callDevicesPermission);
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      ++_generation;
      await _releasePreview(); // Release test capture before starting real call capture.
      await widget.onApply?.call(_selection);
      ref.read(callDevicesProvider.notifier).select(_selection);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.callDevicesApplyFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _selector(
    String kind,
    String title,
    String selected,
    ValueChanged<String> onChange,
  ) {
    final devices = _devices
        .where((d) => d.kind == kind && d.deviceId.isNotEmpty)
        .toList();
    final ids = <String>{};
    devices.removeWhere((d) => !ids.add(d.deviceId));
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownMenu<String>(
        key: ValueKey('$kind:$selected:${devices.length}'),
        expandedInsets: EdgeInsets.zero,
        initialSelection: selected,
        enabled: !_busy,
        label: Text(title),
        dropdownMenuEntries: [
          DropdownMenuEntry(value: '', label: context.l10n.callDeviceDefault),
          if (selected.isNotEmpty && !ids.contains(selected))
            DropdownMenuEntry(
              value: selected,
              label: '$title (${context.l10n.callDeviceMissing})',
              enabled: false,
            ),
          for (var i = 0; i < devices.length; i++)
            DropdownMenuEntry(
              value: devices[i].deviceId,
              label: devices[i].label.isEmpty
                  ? '$title ${i + 1}'
                  : devices[i].label,
            ),
        ],
        onSelected: (id) {
          if (id == null) return;
          setState(() => onChange(id));
          if (_stream != null) unawaited(_test());
        },
      ),
    );
  }

  @override
  void dispose() {
    ++_generation;
    _timer?.cancel();
    unawaited(
      _releasePreview().whenComplete(() async {
        try {
          await _rendererInit;
        } catch (_) {}
        if (_ready) await _renderer.dispose();
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, scheme = Theme.of(context).colorScheme;
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
                l.callDevicesTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(l.callDevicesLocalHint),
              _selector(
                'audioinput',
                l.callDeviceMicrophone,
                _selection.microphone,
                (v) => _selection = CallDevices(
                  microphone: v,
                  camera: _selection.camera,
                  output: _selection.output,
                ),
              ),
              if (widget.video)
                _selector(
                  'videoinput',
                  l.callDeviceCamera,
                  _selection.camera,
                  (v) => _selection = CallDevices(
                    microphone: _selection.microphone,
                    camera: v,
                    output: _selection.output,
                  ),
                ),
              _selector(
                'audiooutput',
                l.callDeviceOutput,
                _selection.output,
                (v) => _selection = CallDevices(
                  microphone: _selection.microphone,
                  camera: _selection.camera,
                  output: v,
                ),
              ),
              const SizedBox(height: 12),
              if (_stream != null) ...[
                if (widget.video)
                  SizedBox(
                    height: 180,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: RTCVideoView(_renderer, mirror: true),
                    ),
                  ),
                Text(
                  _level == null
                      ? l.callDeviceLevelUnavailable
                      : l.callDeviceSpeak,
                ),
                if (_level != null)
                  Semantics(
                    label: l.callDeviceMicrophone,
                    value: '${(_level! * 100).round()}%',
                    child: Row(
                      children: [
                        for (var i = 0; i < 16; i++)
                          Expanded(
                            child: Container(
                              height: 12,
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: i / 16 < _level!
                                    ? scheme.primary
                                    : scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_error!, style: TextStyle(color: scheme.error)),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _busy || widget.onApply != null ? null : _test,
                    icon: const Icon(Icons.mic_rounded),
                    label: Text(l.callDeviceTest),
                  ),
                  TextButton.icon(
                    onPressed: _busy || _toneBusy || widget.onApply != null
                        ? null
                        : () async {
                            setState(() => _toneBusy = true);
                            try {
                              await playOutputTest(_selection.output);
                            } catch (_) {
                              if (mounted) {
                                setState(
                                  () => _error = l.callDeviceOutputUnavailable,
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _toneBusy = false);
                            }
                          },
                    icon: const Icon(Icons.volume_up_rounded),
                    label: Text(
                      kIsWeb
                          ? l.callDeviceTestSound
                          : l.callDeviceTestSystemSound,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OverflowBar(
                spacing: 8,
                overflowSpacing: 8,
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: Text(l.commonCancel),
                  ),
                  FilledButton.icon(
                    onPressed: _busy || _toneBusy ? null : _apply,
                    icon: _busy
                        ? const AppLoadingIndicator(size: 20)
                        : Icon(
                            widget.preflight
                                ? Icons.call_rounded
                                : Icons.check_rounded,
                          ),
                    label: Text(
                      widget.preflight ? l.callDeviceStart : l.commonSave,
                    ),
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
