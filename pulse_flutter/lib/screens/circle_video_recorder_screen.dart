import 'dart:async';
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
    extends State<CircleVideoRecorderScreen> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isRecording = false;
  bool _initialized = false;
  Timer? _recordingTimer;
  int _elapsedSec = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    final List<CameraDescription> cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final CameraDescription back = cameras.firstWhere(
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
        _pulseController.repeat(reverse: true);
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
    _pulseController.stop();
    _pulseController.reset();

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
    final CameraDescription next = cameras.firstWhere(
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
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _pulseController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String formatted =
        '${(_elapsedSec ~/ 60).toString().padLeft(2, '0')}:${(_elapsedSec % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          // Camera preview area — proper circle centered
          if (_initialized && _controller != null && _controller!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipOval(
                  child: CameraPreview(_controller!),
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: context.l10n.commonCancel,
                    ),
                  ),
                  const Spacer(),
                  // Timer badge
                  if (_isRecording)
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (BuildContext context, Widget? child) {
                        return Transform.scale(
                          scale: _pulseAnim.value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6,
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
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
                      onPressed: _switchCamera,
                      tooltip: context.l10n.mediaViewerFlipCamera,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 32,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Record button
                GestureDetector(
                  onLongPressStart: (_) => _startRecording(),
                  onLongPressEnd: (_) => _stopRecording(),
                  onTapUp: (_) {
                    if (_isRecording) _stopRecording();
                  },
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (BuildContext context, Widget? child) {
                      final double outerSize = _isRecording
                          ? 72 * _pulseAnim.value
                          : 80;
                      return Container(
                        width: outerSize,
                        height: outerSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isRecording ? Colors.red : Colors.white70,
                            width: 4,
                          ),
                        ),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOutCubic,
                            width: _isRecording ? 24 : 36,
                            height: _isRecording ? 24 : 36,
                            decoration: BoxDecoration(
                              color: _isRecording ? Colors.red : Colors.white,
                              borderRadius: BorderRadius.circular(
                                _isRecording ? 6 : 18,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Hint text
                Text(
                  _isRecording
                      ? context.l10n.mediaViewerRecording
                      : context.l10n.chatCircleVideoHoldHint,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
