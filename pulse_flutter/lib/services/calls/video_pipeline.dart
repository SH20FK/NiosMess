import 'dart:isolate';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

import '../../services/permission_service.dart';

/// Callback for sending an encrypted video packet.
typedef SendVideoPacket = Future<void> Function({
  required int frameType,
  required double timestamp,
  required Uint8List iv,
  required Uint8List encryptedVp8,
});

/// Callback notifying when the local [CameraController] is ready (or null when stopped).
typedef OnCameraReady = void Function(CameraController? controller);

/// Captures camera frames, encodes as JPEG, and sends via the SFU protocol.
///
/// JPEG frames are sent as Type 2 (Video) packets with frameType=0 (keyframe)
/// since we don't have VP8 delta frame encoding yet.
class VideoPipeline {
  VideoPipeline({
    required this.onSendPacket,
    this.onCameraReady,
    this.targetFps = 15,
    this.quality = 70,
    this.maxWidth = 640,
    this.maxHeight = 480,
  });

  final SendVideoPacket onSendPacket;
  final OnCameraReady? onCameraReady;
  final int targetFps;
  final int quality;
  final int maxWidth;
  final int maxHeight;

  CameraController? _controller;
  bool _started = false;
  bool _stopped = false;
  bool _capturing = false;
  int _lastFrameMs = 0;
  int _frameIntervalMs = 0;
  CameraLensDirection _currentLens = CameraLensDirection.front;

  bool get isRunning => _started && !_stopped;

  /// Exposes the underlying CameraController so the UI can render a live preview.
  CameraController? get cameraController => _controller;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _stopped = false;

    final perm = await PermissionService().requestCamera();
    if (!perm) {
      debugPrint('[VideoPipeline] Camera permission denied');
      _started = false;
      return;
    }

    _frameIntervalMs = (1000 / targetFps).round();

    await _initCamera();
  }

  Future<void> _initCamera({CameraLensDirection lens = CameraLensDirection.front}) async {
    try {
      await _controller?.dispose();
      _currentLens = lens;

      final cameras = await availableCameras();
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == lens,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      await _controller!.startImageStream(_onCameraImage);

      onCameraReady?.call(_controller);
      debugPrint('[VideoPipeline] Camera initialized: ${cam.lensDirection}');
    } catch (e) {
      debugPrint('[VideoPipeline] Camera init error: $e');
    }
  }

  Future<void> _onCameraImage(CameraImage image) async {
    if (_stopped || _capturing) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFrameMs < _frameIntervalMs) return;
    _lastFrameMs = now;
    _capturing = true;

    try {
      final Uint8List jpeg = await _convertToJpeg(image);
      if (jpeg.isEmpty) return;

      final timestamp = now / 1000.0;
      // AES-GCM requires a unique nonce per key; use a random IV like the
      // audio path does.
      final random = math.Random.secure();
      final iv = Uint8List(12);
      for (int i = 0; i < 12; i++) {
        iv[i] = random.nextInt(256);
      }

      await onSendPacket(
        frameType: 0,
        timestamp: timestamp,
        iv: iv,
        encryptedVp8: jpeg,
      );
    } catch (e) {
      debugPrint('[VideoPipeline] Frame error: $e');
    } finally {
      _capturing = false;
    }
  }

  Future<Uint8List> _convertToJpeg(CameraImage image) async {
    try {
      // Copy the raw plane bytes on the platform thread: CameraImage holds
      // native buffers that cannot cross isolate boundaries.
      final ImageFormatGroup group = image.format.group;
      final List<Uint8List> planes = <Uint8List>[
        for (final Plane plane in image.planes)
          Uint8List.fromList(plane.bytes),
      ];
      final int width = image.width;
      final int height = image.height;
      final int maxWidth = this.maxWidth;
      final int maxHeight = this.maxHeight;

      // BGRA→RGBA, resize and PNG encode are pure Dart and heavy — run them
      // off the UI thread, then JPEG-compress on the platform thread.
      final Uint8List png = await Isolate.run(() {
        return _encodeFramePng(
          planes: planes,
          width: width,
          height: height,
          group: group,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        );
      });

      final result = await FlutterImageCompress.compressWithList(
        png,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      return Uint8List.fromList(result);
    } catch (e) {
      debugPrint('[VideoPipeline] JPEG convert error: $e');
      return Uint8List(0);
    }
  }

  static Uint8List _encodeFramePng({
    required List<Uint8List> planes,
    required int width,
    required int height,
    required ImageFormatGroup group,
    required int maxWidth,
    required int maxHeight,
  }) {
    img.Image? dartImage;
    if (group == ImageFormatGroup.bgra8888) {
      final Uint8List bgraBytes = planes[0];
      final Uint8List rgbaBytes = Uint8List(bgraBytes.length);
      for (int i = 0; i < bgraBytes.length; i += 4) {
        rgbaBytes[i] = bgraBytes[i + 2];
        rgbaBytes[i + 1] = bgraBytes[i + 1];
        rgbaBytes[i + 2] = bgraBytes[i];
        rgbaBytes[i + 3] = bgraBytes[i + 3];
      }
      dartImage = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgbaBytes.buffer,
        numChannels: 4,
      );
    } else if (group == ImageFormatGroup.yuv420) {
      dartImage = img.decodeImage(_yuv420ToNv21(planes, width, height));
    } else {
      dartImage = img.decodeImage(_concatenatePlanes(planes));
    }
    if (dartImage == null) return Uint8List(0);

    if (dartImage.width <= maxWidth && dartImage.height <= maxHeight) {
      return img.encodePng(dartImage);
    }
    final double scale =
        math.min(maxWidth / dartImage.width, maxHeight / dartImage.height);
    final int w = (dartImage.width * scale).round();
    final int h = (dartImage.height * scale).round();
    return img.encodePng(img.copyResize(dartImage, width: w, height: h));
  }

  static Uint8List _yuv420ToNv21(List<Uint8List> planes, int width, int height) {
    final int ySize = width * height;
    final int uvSize = (width * height) ~/ 2;
    final Uint8List nv21 = Uint8List(ySize + uvSize);

    final Uint8List yPlane = planes[0];
    nv21.setRange(0, ySize, yPlane);

    final Uint8List uPlane = planes[1];
    final Uint8List vPlane = planes[2];
    int uvOffset = ySize;
    for (int i = 0; i < uPlane.length && uvOffset + 1 < nv21.length; i++) {
      nv21[uvOffset++] = vPlane[i];
      nv21[uvOffset++] = uPlane[i];
    }

    return nv21;
  }

  static Uint8List _concatenatePlanes(List<Uint8List> planes) {
    int totalSize = 0;
    for (final Uint8List plane in planes) {
      totalSize += plane.length;
    }
    final Uint8List all = Uint8List(totalSize);
    int offset = 0;
    for (final Uint8List plane in planes) {
      all.setRange(offset, offset + plane.length, plane);
      offset += plane.length;
    }
    return all;
  }

  Future<void> switchCamera() async {
    if (_stopped) return;
    final newLens = _currentLens == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    await _initCamera(lens: newLens);
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _capturing = false;

    try {
      await _controller?.stopImageStream();
    } catch (_) {}
    await _controller?.dispose();
    _controller = null;
    onCameraReady?.call(null);

    debugPrint('[VideoPipeline] Stopped');
  }

  void dispose() {
    stop();
  }
}
