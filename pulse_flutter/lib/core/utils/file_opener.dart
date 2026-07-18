import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:url_launcher/url_launcher.dart';

class FileOpener {
  static Future<void> openUrl(BuildContext context, String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      if (context.mounted) {
        _showError(context, context.l10n.fileOpenerInvalidUrl);
      }
      return;
    }

    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      _showError(context, context.l10n.fileOpenerFailedOpenRemote);
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
        _showError(context, context.l10n.fileOpenerCannotOpenType);
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
          context.l10n.fileOpenerApkAndroidOnly,
        );
      }
      return;
    }

    final OpenResult result = await OpenFile.open(filePath);
    if (result.type != ResultType.done && context.mounted) {
      _showError(context, context.l10n.fileOpenerFailedApk(result.message));
    }
  }

  static Future<void> _openExe(BuildContext context, String filePath) async {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      if (context.mounted) {
        _showError(context, context.l10n.fileOpenerExeNotOnMobile);
      }
      return;
    }

    final OpenResult result = await OpenFile.open(filePath);
    if (result.type != ResultType.done && context.mounted) {
      _showError(context, context.l10n.fileOpenerFailedExe(result.message));
    }
  }

  static Future<void> _openWithSystemApp(
    BuildContext context,
    String filePath,
    FileTypeInfo typeInfo,
  ) async {
    final OpenResult result = await OpenFile.open(filePath);

    if (result.type != ResultType.done && context.mounted) {
      _showError(context, context.l10n.fileOpenerNoAppFound(typeInfo.label));
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
