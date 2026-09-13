import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Maximum recording duration for circle video (60 seconds).
const int _kMaxRecordSeconds = 60;

class CircleVideoRecorderScreen extends ConsumerStatefulWidget {
  const CircleVideoRecorderScreen({
    this.autoStart = false,
    super.key,
  });

  /// If true, recording starts automatically after camera initializes.
  final bool autoStart;

  @override
  ConsumerState<CircleVideoRecorderScreen> createState() =>
      _CircleVideoRecorderScreenState();
}

class _CircleVideoRecorderScreenState
    extends ConsumerState<CircleVideoRecorderScreen> with TickerProviderStateMixin {
  static const String _kCameraLensPrefKey = 'circle_video_preferred_lens';

  CameraController? _controller;
  List<CameraDescription> _availableCameras = <CameraDescription>[];
  CameraLensDirection _currentLensDirection = CameraLensDirection.front;
  bool _isSwitchingCamera = false;
  bool _isRecording = false;
  bool _initialized = false;
  Timer? _recordingTimer;
  int _elapsedSec = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _progressController;
  late AnimationController _scrimController;
  late Animation<double> _scrimAnim;
  late AnimationController _flipController;
  late Animation<double> _flipAnim;

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

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _flipAnim = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
    );

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedLens = prefs.getString(_kCameraLensPrefKey);
      final CameraLensDirection targetDirection = savedLens == 'back'
          ? CameraLensDirection.back
          : CameraLensDirection.front;

      final CameraDescription defaultCam = _availableCameras.firstWhere(
        (CameraDescription c) => c.lensDirection == targetDirection,
        orElse: () => _availableCameras.firstWhere(
          (CameraDescription c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => _availableCameras.first,
        ),
      );

      _currentLensDirection = defaultCam.lensDirection;

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
          Future<void>.delayed(const Duration(milliseconds: 350), () {
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
    if (_controller == null || _isSwitchingCamera) return;
    if (_availableCameras.length < 2) {
      try {
        _availableCameras = await availableCameras();
      } catch (_) {}
      if (_availableCameras.length < 2) return;
    }

    HapticService.tap();
    _flipController.forward(from: 0.0);

    final CameraDescription current = _controller!.description;
    final CameraDescription next = _availableCameras.firstWhere(
      (CameraDescription c) => c.lensDirection != current.lensDirection,
      orElse: () => _availableCameras.firstWhere(
        (CameraDescription c) => c != current,
        orElse: () => current,
      ),
    );
    if (next == current) return;

    setState(() => _isSwitchingCamera = true);

    final bool useCamera2 = ref.read(uiSettingsProvider).camera2Api;

    try {
      if (useCamera2) {
        // Fast seamless hardware switch via Camera2 API (setDescription preserves surface & audio)
        try {
          await _controller!.setDescription(next);
          _currentLensDirection = next.lensDirection;
        } catch (e) {
          debugPrint('[CircleVideoRecorder] Camera2 live switch fallback: $e');
          await _reinitializeController(next);
        }
      } else {
        // Standard full re-initialization (legacy / fallback)
        await _reinitializeController(next);
      }

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kCameraLensPrefKey,
        _currentLensDirection == CameraLensDirection.back ? 'back' : 'front',
      );
    } catch (e) {
      debugPrint('[CircleVideoRecorder] Camera switch error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSwitchingCamera = false);
      }
    }
  }

  Future<void> _reinitializeController(CameraDescription description) async {
    final bool wasRecording = _controller?.value.isRecordingVideo ?? false;
    await _controller?.dispose();
    _controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
    _currentLensDirection = description.lensDirection;
    if (wasRecording && mounted) {
      try {
        await _controller!.startVideoRecording();
      } catch (_) {}
    }
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
    _flipController.dispose();
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

                        // Camera preview clipped strictly into circle with double-tap flip
                        GestureDetector(
                          onDoubleTap: _switchCamera,
                          child: ClipOval(
                            child: SizedBox(
                              width: circleSize,
                              height: circleSize,
                              child: AnimatedBuilder(
                                animation: _flipAnim,
                                builder: (BuildContext context, Widget? child) {
                                  final double value = _flipAnim.value;
                                  final double angle = value * math.pi;
                                  final bool isHalfway = value > 0.5;
                                  return Transform(
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, 0.0015)
                                      ..rotateY(angle),
                                    alignment: Alignment.center,
                                    child: Transform(
                                      transform: Matrix4.identity()
                                        ..rotateY(isHalfway ? math.pi : 0.0),
                                      alignment: Alignment.center,
                                      child: child,
                                    ),
                                  );
                                },
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
                      // Timer badge or Camera Lens indicator badge
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
                        )
                      else
                        // Lens indicator badge (Front / Rear)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.50),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                _currentLensDirection ==
                                        CameraLensDirection.front
                                    ? Icons.face_rounded
                                    : Icons.photo_camera_back_rounded,
                                size: 16,
                                color: scheme.onSurface.withValues(alpha: 0.85),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _currentLensDirection ==
                                        CameraLensDirection.front
                                    ? 'Фронтальная'
                                    : 'Основная',
                                style: textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurface.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      // Symmetrical spacer to balance the close button on the left
                      const SizedBox(width: 44, height: 44),
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
                      // Controls row: [SizedBox spacer, Record/Stop button, Flip button]
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            // Left spacer to symmetrically balance right flip button
                            const SizedBox(width: 48, height: 48),

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
                                            : scheme.onSurface
                                                .withValues(alpha: 0.6),
                                        width: 4,
                                      ),
                                    ),
                                    child: Center(
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
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

                            // Flip camera button right next to user's thumb
                            _CircleButton(
                              icon: Icons.cameraswitch_rounded,
                              tooltip: context.l10n.mediaViewerFlipCamera,
                              onTap: _switchCamera,
                              scheme: scheme,
                              size: 48,
                              iconSize: 24,
                            ),
                          ],
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
    this.tooltip,
    this.size = 44,
    this.iconSize = 24,
  });

  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final String? tooltip;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    Widget button = Material(
      color: scheme.surface.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Icon(icon, color: scheme.onSurface, size: iconSize),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
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
