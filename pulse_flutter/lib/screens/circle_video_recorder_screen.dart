import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

class CircleVideoRecorderScreen extends StatefulWidget {
  const CircleVideoRecorderScreen({super.key});

  @override
  State<CircleVideoRecorderScreen> createState() =>
      _CircleVideoRecorderScreenState();
}

class _CircleVideoRecorderScreenState
    extends State<CircleVideoRecorderScreen> {
  CameraController? _controller;
  bool _isRecording = false;
  bool _initialized = false;
  Timer? _recordingTimer;
  int _elapsedSec = 0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final List<CameraDescription> cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final CameraDescription? back = cameras.firstWhere(
      (CameraDescription c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } catch (_) {}

    if (mounted) setState(() => _initialized = true);
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      await _controller!.startVideoRecording();
      if (mounted) {
        setState(() => _isRecording = true);
        _elapsedSec = 0;
        _recordingTimer = Timer.periodic(
          const Duration(seconds: 1),
          (_) {
            if (mounted) setState(() => _elapsedSec++);
          },
        );
      }
    } catch (_) {}
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _controller == null) return;
    _recordingTimer?.cancel();

    try {
      final XFile video = await _controller!.stopVideoRecording();
      if (mounted) {
        Navigator.of(context).pop(video.path);
      }
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _switchCamera() async {
    if (_controller == null) return;
    final CameraDescription current = _controller!.description;
    final List<CameraDescription> cameras = await availableCameras();
    final CameraDescription? next = cameras.firstWhere(
      (CameraDescription c) => c.lensDirection != current.lensDirection,
      orElse: () => cameras.first,
    );
    if (next == current) return;

    await _controller!.dispose();
    _controller = CameraController(
      next,
      ResolutionPreset.high,
      enableAudio: true,
    );
    try {
      await _controller!.initialize();
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String formatted =
        '${(_elapsedSec ~/ 60).toString().padLeft(2, '0')}:${(_elapsedSec % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(context.l10n.mediaViewerTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: _initialized && _controller != null
          ? Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // Camera preview in 1:1 square
                AspectRatio(
                  aspectRatio: 1.0,
                  child: _controller!.value.isInitialized
                      ? ClipOval(
                          child: CameraPreview(_controller!),
                        )
                      : const SizedBox.shrink(),
                ),
                // Timer overlay
                if (_isRecording)
                  Positioned(
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatted,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Bottom record button
                Positioned(
                  bottom: 40,
                  child: GestureDetector(
                    onLongPressStart: (_) => _startRecording(),
                    onLongPressEnd: (_) => _stopRecording(),
                    onTapUp: (_) {
                      if (_isRecording) _stopRecording();
                    },
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isRecording ? Colors.red : Colors.white,
                          width: 4,
                        ),
                      ),
                      child: _isRecording
                          ? Center(
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.videocam_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
