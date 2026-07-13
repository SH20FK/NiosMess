import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pulse_flutter/screenshots/mock_app.dart';

void main() {
  runApp(const _ScreenshotCaptureApp());
}

class _ScreenshotCaptureApp extends StatefulWidget {
  const _ScreenshotCaptureApp();
  @override
  State<_ScreenshotCaptureApp> createState() => _ScreenshotCaptureAppState();
}

class _ScreenshotCaptureAppState extends State<_ScreenshotCaptureApp> {
  final _boundaryKey = GlobalKey();
  int _currentPage = 0;

  static const _names = ['chats', 'messages', 'group', 'channel', 'niosgram', 'voice', 'themes', 'profile'];
  static const _total = 8;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_capture);
  }

  Future<void> _capture(Duration _) async {
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('${Directory.current.path}/../niosmess_landing/public/screens');
      dir.createSync(recursive: true);
      File('${dir.path}/${_names[_currentPage]}.png').writeAsBytesSync(byteData!.buffer.asUint8List());
      print('Generated ${_names[_currentPage]}.png');
    } catch (e) {
      print('Error capturing ${_names[_currentPage]}: $e');
    }

    if (_currentPage + 1 < _total) {
      setState(() => _currentPage++);
    } else {
      exit(0);
    }
  }

  @override
  void didUpdateWidget(_ScreenshotCaptureApp old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback(_capture);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
      ),
      home: RepaintBoundary(
        key: _boundaryKey,
        child: MockScreenshotsApp(page: _currentPage),
      ),
    );
  }
}
