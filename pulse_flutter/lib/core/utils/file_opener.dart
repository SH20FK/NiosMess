import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:url_launcher/url_launcher.dart';

class FileOpener {
  static Future<void> openUrl(BuildContext context, String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      if (context.mounted) {
        _showError(context, 'Invalid file URL');
      }
      return;
    }

    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      _showError(context, 'Failed to open remote file');
    }
  }

  static Future<void> openFile({
    required BuildContext context,
    required String filePath,
    required String fileName,
    String? mimeType,
  }) async {
    final FileTypeInfo typeInfo = FileTypeDetector.detect(
      fileName: fileName,
      mimeType: mimeType,
      filePath: filePath,
    );

    if (!typeInfo.canOpen) {
      if (context.mounted) {
        _showError(context, 'Cannot open this file type');
      }
      return;
    }

    if (typeInfo.isApk) {
      await _openApk(context, filePath);
    } else if (typeInfo.isExe) {
      await _openExe(context, filePath);
    } else {
      await _openWithSystemApp(context, filePath, typeInfo);
    }
  }

  static Future<void> _openApk(BuildContext context, String filePath) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      if (context.mounted) {
        _showError(
          context,
          'APK files can only be installed on Android devices',
        );
      }
      return;
    }

    final OpenResult result = await OpenFile.open(filePath);
    if (result.type != ResultType.done && context.mounted) {
      _showError(context, 'Failed to open APK: ${result.message}');
    }
  }

  static Future<void> _openExe(BuildContext context, String filePath) async {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      if (context.mounted) {
        _showError(context, 'EXE files cannot be opened on mobile devices');
      }
      return;
    }

    final OpenResult result = await OpenFile.open(filePath);
    if (result.type != ResultType.done && context.mounted) {
      _showError(context, 'Failed to open EXE: ${result.message}');
    }
  }

  static Future<void> _openWithSystemApp(
    BuildContext context,
    String filePath,
    FileTypeInfo typeInfo,
  ) async {
    final OpenResult result = await OpenFile.open(filePath);

    if (result.type != ResultType.done && context.mounted) {
      _showError(context, 'No app found to open ${typeInfo.label} files');
    }
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
