import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// Maximum recording duration for circle video (60 seconds).
const int _kMaxRecordSeconds = 60;

class CircleVideoRecorderScreen extends StatefulWidget {
  const CircleVideoRecorderScreen({
    this.autoStart = false,
    super.key,
  });

  /// If true, recording starts automatically after camera initializes.
  final bool autoStart;

  @override
  State<CircleVideoRecorderScreen> createState() =>
      _CircleVideoRecorderScreenState();
}

class _CircleVideoRecorderScreenState
    extends State<CircleVideoRecorderScreen> with TickerProviderStateMixin {
  CameraController? _controller;
  bool _isRecording = false;
  bool _initialized = false;
  Timer? _recordingTimer;
  int _elapsedSec = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _progressController;
  late AnimationController _scrimController;
  late Animation<double> _scrimAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _kMaxRecordSeconds),
    );

    _scrimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scrimAnim = CurvedAnimation(
      parent: _scrimController,
      curve: Curves.easeOut,
    );

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      final CameraDescription defaultCam = cameras.firstWhere(
        (CameraDescription c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        defaultCam,
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() => _initialized = true);
        _scrimController.forward();

        if (widget.autoStart) {
          // Small delay for smooth animation before auto-start
          Future<void>.delayed(const Duration(milliseconds: 300), () {
            if (mounted && !_isRecording) _startRecording();
          });
        }
      }
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      await _controller!.startVideoRecording();
      HapticService.tap();
      if (mounted) {
        setState(() => _isRecording = true);
        _elapsedSec = 0;
        _pulseController.repeat(reverse: true);
        _progressController.forward();
        _recordingTimer = Timer.periodic(
          const Duration(seconds: 1),
          (_) {
            if (mounted) {
              setState(() => _elapsedSec++);
              if (_elapsedSec >= _kMaxRecordSeconds) {
                _stopRecording();
              }
            }
          },
        );
      }
    } catch (_) {
      // Camera may not support recording
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _controller == null) return;
    _recordingTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    _progressController.stop();

    try {
      HapticService.confirm();
      final XFile video = await _controller!.stopVideoRecording();
      if (mounted) {
        Navigator.of(context).pop(video.path);
      }
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _switchCamera() async {
    if (_controller == null || _isRecording) return;
    HapticService.tap();
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

  void _cancelAndPop() {
    HapticService.destructive();
    if (_isRecording) {
      _recordingTimer?.cancel();
      _pulseController.stop();
      _progressController.stop();
      _controller?.stopVideoRecording().catchError((_) => XFile(''));
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _pulseController.dispose();
    _progressController.dispose();
    _scrimController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double circleSize = screenWidth * 0.78;

    final String formatted =
        '${(_elapsedSec ~/ 60).toString().padLeft(2, '0')}:${(_elapsedSec % 60).toString().padLeft(2, '0')}';

    final double previewW;
    final double previewH;
    if (_initialized && _controller != null && _controller!.value.isInitialized) {
      final Size pSize = _controller!.value.previewSize!;
      // On mobile camera preview is usually reported landscape (width > height)
      if (pSize.width > pSize.height) {
        previewW = pSize.height;
        previewH = pSize.width;
      } else {
        previewW = pSize.width;
        previewH = pSize.height;
      }
    } else {
      previewW = circleSize;
      previewH = circleSize;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.expand(
        child: FadeTransition(
          opacity: _scrimAnim,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: scheme.scrim.withValues(alpha: 0.90),
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: <Widget>[
                // ── Camera circle with progress ring (True Screen Center) ──
                Center(
                  child: SizedBox(
                    width: circleSize + 16,
                    height: circleSize + 16,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        // Circular progress indicator
                        if (_isRecording)
                          AnimatedBuilder(
                            animation: _progressController,
                            builder: (BuildContext context, Widget? child) {
                              return CustomPaint(
                                size: Size(circleSize + 16, circleSize + 16),
                                painter: _CircleProgressPainter(
                                  progress: _progressController.value,
                                  strokeWidth: 4.5,
                                  activeColor: scheme.error,
                                  trackColor:
                                      scheme.onSurface.withValues(alpha: 0.20),
                                ),
                              );
                            },
                          )
                        else
                          // Idle ring
                          Container(
                            width: circleSize + 10,
                            height: circleSize + 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: scheme.onSurface.withValues(alpha: 0.25),
                                width: 3.0,
                              ),
                            ),
                          ),

                        // Camera preview clipped strictly into circle
                        ClipOval(
                          child: SizedBox(
                            width: circleSize,
                            height: circleSize,
                            child: _initialized &&
                                    _controller != null &&
                                    _controller!.value.isInitialized
                                ? FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: previewW,
                                      height: previewH,
                                      child: CameraPreview(_controller!),
                                    ),
                                  )
                                : Container(
                                    color: scheme.surfaceContainerHighest,
                                    child: Center(
                                      child: AppLoadingIndicator(
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Top bar (Screen Top with SafeArea) ──
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: <Widget>[
                      // Close button
                      _CircleButton(
                        icon: Icons.close_rounded,
                        onTap: _cancelAndPop,
                        scheme: scheme,
                      ),
                      const Spacer(),
                      // Timer badge
                      if (_isRecording)
                        AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (BuildContext context, Widget? child) {
                            return Transform.scale(
                              scale: _pulseAnim.value,
                              child: child,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surface.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: scheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatted,
                                  style: textTheme.labelLarge?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const <FontFeature>[
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const Spacer(),
                      // Flip camera button (hidden during recording)
                      if (!_isRecording)
                        _CircleButton(
                          icon: Icons.flip_camera_ios_rounded,
                          onTap: _switchCamera,
                          scheme: scheme,
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),

                // ── Bottom controls (Screen Bottom with SafeArea) ──
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 32,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Record / Stop button
                      GestureDetector(
                        onTap: () {
                          if (_isRecording) {
                            _stopRecording();
                          } else {
                            _startRecording();
                          }
                        },
                        child: AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (BuildContext context, Widget? child) {
                            final double outerSize =
                                _isRecording ? 72 * _pulseAnim.value : 80;
                            return Container(
                              width: outerSize,
                              height: outerSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _isRecording
                                      ? scheme.error
                                      : scheme.onSurface.withValues(alpha: 0.6),
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
                                    color: _isRecording
                                        ? scheme.error
                                        : scheme.onSurface,
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
                      const SizedBox(height: 14),
                      // Hint text
                      Text(
                        _isRecording
                            ? context.l10n.mediaViewerRecording
                            : context.l10n.chatCircleVideoHoldHint,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.70),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Circular translucent icon button ──
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    required this.scheme,
  });

  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surface.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: scheme.onSurface, size: 24),
        ),
      ),
    );
  }
}

// ── Circular progress ring painter ──
class _CircleProgressPainter extends CustomPainter {
  _CircleProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.activeColor,
    required this.trackColor,
  });

  final double progress;
  final double strokeWidth;
  final Color activeColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width - strokeWidth) / 2;

    // Track
    final Paint trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Active arc
    if (progress > 0) {
      final Paint activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // Start from top
        2 * math.pi * progress,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CircleProgressPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.activeColor != activeColor;
}
