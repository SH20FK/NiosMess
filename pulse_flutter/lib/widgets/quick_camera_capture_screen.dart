import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// Screen for fast photo capture directly from the attachment modal or gallery.
class QuickCameraCaptureScreen extends StatefulWidget {
  const QuickCameraCaptureScreen({super.key});

  static Future<String?> capturePhoto(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const QuickCameraCaptureScreen(),
      ),
    );
  }

  @override
  State<QuickCameraCaptureScreen> createState() =>
      _QuickCameraCaptureScreenState();
}

class _QuickCameraCaptureScreenState extends State<QuickCameraCaptureScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _availableCameras = <CameraDescription>[];
  int _currentCameraIndex = 0;
  bool _isInitialized = false;
  bool _isCapturing = false;
  FlashMode _flashMode = FlashMode.auto;

  late AnimationController _flipController;
  late Animation<double> _flipAnim;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _flipAnim = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
    );
    _initCameras();
  }

  Future<void> _initCameras() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      // Default to rear camera if available, otherwise first
      final int backIndex = _availableCameras.indexWhere(
        (CameraDescription c) => c.lensDirection == CameraLensDirection.back,
      );
      _currentCameraIndex = backIndex != -1 ? backIndex : 0;
      await _setupController(_availableCameras[_currentCameraIndex]);
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _setupController(CameraDescription description) async {
    await _controller?.dispose();
    final CameraController controller = CameraController(
      description,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setFlashMode(_flashMode);
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2 || _isCapturing) return;
    HapticService.tap();
    _flipController.forward(from: 0.0);
    _currentCameraIndex = (_currentCameraIndex + 1) % _availableCameras.length;
    await _setupController(_availableCameras[_currentCameraIndex]);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_isInitialized) return;
    HapticService.tap();
    final FlashMode nextMode = switch (_flashMode) {
      FlashMode.auto => FlashMode.always,
      FlashMode.always => FlashMode.off,
      FlashMode.off => FlashMode.auto,
      _ => FlashMode.auto,
    };
    try {
      await _controller!.setFlashMode(nextMode);
      setState(() => _flashMode = nextMode);
    } catch (_) {}
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_isInitialized || _isCapturing) return;
    HapticService.tap();
    setState(() => _isCapturing = true);

    try {
      final XFile photo = await _controller!.takePicture();
      HapticService.confirm();
      if (mounted) {
        Navigator.of(context).pop(photo.path);
      }
    } catch (_) {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.scrim,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Camera preview
            if (_isInitialized && _controller != null)
              Center(
                child: AnimatedBuilder(
                  animation: _flipAnim,
                  builder: (BuildContext context, Widget? child) {
                    final double angle = _flipAnim.value * math.pi;
                    final bool isHalfway = _flipAnim.value > 0.5;
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
                  child: CameraPreview(_controller!),
                ),
              )
            else
              Center(
                child: AppLoadingIndicator(color: scheme.onSurface),
              ),

            // Top Bar
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                children: <Widget>[
                  IconButton.filledTonal(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    icon: Icon(
                      _flashMode == FlashMode.always
                          ? Icons.flash_on_rounded
                          : _flashMode == FlashMode.auto
                              ? Icons.flash_auto_rounded
                              : Icons.flash_off_rounded,
                    ),
                    onPressed: _toggleFlash,
                  ),
                ],
              ),
            ),

            // Bottom Shutter Controls
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  // Spacer to balance flip button
                  const SizedBox(width: 56),

                  // Big shutter button
                  GestureDetector(
                    onTap: _takePhoto,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.onSurface,
                          width: 4,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Flip camera button
                  IconButton.filledTonal(
                    iconSize: 28,
                    padding: const EdgeInsets.all(14),
                    icon: const Icon(Icons.flip_camera_ios_rounded),
                    onPressed: _switchCamera,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
