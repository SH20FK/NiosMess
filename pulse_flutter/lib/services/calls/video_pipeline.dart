import 'dart:async';
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

/// Captures camera frames, encodes as JPEG, and sends via the SFU protocol.
///
/// JPEG frames are sent as Type 2 (Video) packets with frameType=0 (keyframe)
/// since we don't have VP8 delta frame encoding yet.
class VideoPipeline {
  VideoPipeline({
    required this.onSendPacket,
    this.targetFps = 15,
    this.quality = 70,
    this.maxWidth = 640,
    this.maxHeight = 480,
  });

  final SendVideoPacket onSendPacket;
  final int targetFps;
  final int quality;
  final int maxWidth;
  final int maxHeight;

  CameraController? _controller;
  StreamSubscription<CameraImage>? _imageSub;
  bool _started = false;
  bool _stopped = false;
  bool _capturing = false;
  int _frameCount = 0;
  Timer? _fpsTimer;
  int _lastFrameMs = 0;
  int _frameIntervalMs = 0;
  CameraLensDirection _currentLens = CameraLensDirection.front;

  bool get isRunning => _started && !_stopped;

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
      final iv = Uint8List(12);
      for (int i = 0; i < 12; i++) {
        iv[i] = _frameCount & 0xFF;
        _frameCount++;
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
      img.Image? dartImage;

      if (image.format.group == ImageFormatGroup.bgra8888) {
        final Uint8List bgraBytes = image.planes[0].bytes;
        final Uint8List rgbaBytes = Uint8List(bgraBytes.length);
        for (int i = 0; i < bgraBytes.length; i += 4) {
          rgbaBytes[i] = bgraBytes[i + 2];
          rgbaBytes[i + 1] = bgraBytes[i + 1];
          rgbaBytes[i + 2] = bgraBytes[i];
          rgbaBytes[i + 3] = bgraBytes[i + 3];
        }
        dartImage = img.Image.fromBytes(
          width: image.width,
          height: image.height,
          bytes: rgbaBytes.buffer,
          numChannels: 4,
        );
      } else if (image.format.group == ImageFormatGroup.yuv420) {
        final Uint8List nv21 = _yuv420ToNv21(image);
        dartImage = img.decodeImage(nv21);
      } else {
        final Uint8List raw = _concatenatePlanes(image);
        dartImage = img.decodeImage(raw);
      }

      if (dartImage == null) return Uint8List(0);

      final img.Image resized = _resizeIfNeeded(dartImage);

      final result = await FlutterImageCompress.compressWithList(
        img.encodePng(resized),
        quality: quality,
        format: CompressFormat.jpeg,
      );

      return Uint8List.fromList(result);
    } catch (e) {
      debugPrint('[VideoPipeline] JPEG convert error: $e');
      return Uint8List(0);
    }
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = (width * height) ~/ 2;
    final Uint8List nv21 = Uint8List(ySize + uvSize);

    final Plane yPlane = image.planes[0];
    nv21.setRange(0, ySize, yPlane.bytes);

    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];
    int uvOffset = ySize;
    for (int i = 0; i < uPlane.bytes.length && uvOffset + 1 < nv21.length; i++) {
      nv21[uvOffset++] = vPlane.bytes[i];
      nv21[uvOffset++] = uPlane.bytes[i];
    }

    return nv21;
  }

  Uint8List _concatenatePlanes(CameraImage image) {
    int totalSize = 0;
    for (final plane in image.planes) {
      totalSize += plane.bytes.length;
    }
    final Uint8List all = Uint8List(totalSize);
    int offset = 0;
    for (final plane in image.planes) {
      all.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }
    return all;
  }

  img.Image _resizeIfNeeded(img.Image src) {
    if (src.width <= maxWidth && src.height <= maxHeight) return src;
    final scale = math.min(maxWidth / src.width, maxHeight / src.height);
    final w = (src.width * scale).round();
    final h = (src.height * scale).round();
    return img.copyResize(src, width: w, height: h);
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
    _fpsTimer?.cancel();

    await _imageSub?.cancel();
    _imageSub = null;

    try {
      await _controller?.stopImageStream();
    } catch (_) {}
    await _controller?.dispose();
    _controller = null;

    debugPrint('[VideoPipeline] Stopped');
  }

  void dispose() {
    stop();
  }
}
