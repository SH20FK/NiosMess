import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._();
  factory PermissionService() => _instance;
  PermissionService._();

  static const String initialPermissionsRequestedKey =
      'has_requested_initial_permissions';

  /// Requests all essential permissions on first app launch if not previously requested.
  /// This prompts for notifications, camera, microphone, and photos/storage.
  Future<void> requestInitialPermissionsIfNeeded() async {
    if (kIsWeb) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool alreadyRequested =
          prefs.getBool(initialPermissionsRequestedKey) ?? false;
      if (alreadyRequested) return;

      // Mark as requested so subsequent launches do not re-prompt in bulk.
      await prefs.setBool(initialPermissionsRequestedKey, true);

      if (Platform.isAndroid || Platform.isIOS) {
        final List<Permission> permissions = <Permission>[
          Permission.notification,
          Permission.camera,
          Permission.microphone,
          Permission.photos,
        ];
        await permissions.request();
      }
    } catch (e) {
      debugPrint(
        '[PermissionService] requestInitialPermissionsIfNeeded error: $e',
      );
    }
  }

  Future<bool> requestMicrophone() async {
    if (kIsWeb) return true;
    final PermissionStatus status = await Permission.microphone.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    return false;
  }

  Future<bool> requestCamera() async {
    if (kIsWeb) return true;
    final PermissionStatus status = await Permission.camera.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    return false;
  }

  Future<bool> requestNotifications() async {
    if (kIsWeb) return true;
    final PermissionStatus status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> requestPhotos() async {
    if (kIsWeb) return true;
    final PermissionStatus status = await Permission.photos.request();
    if (status.isGranted) return true;
    if (Platform.isAndroid) {
      final PermissionStatus storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }
    return false;
  }

  Future<bool> hasMicrophone() async {
    if (kIsWeb) return true;
    return await Permission.microphone.isGranted;
  }

  Future<bool> hasCamera() async {
    if (kIsWeb) return true;
    return await Permission.camera.isGranted;
  }

  Future<bool> hasNotifications() async {
    if (kIsWeb) return true;
    return await Permission.notification.isGranted;
  }

  Future<bool> hasPhotos() async {
    if (kIsWeb) return true;
    if (await Permission.photos.isGranted) return true;
    if (Platform.isAndroid) {
      return await Permission.storage.isGranted;
    }
    return false;
  }

  Future<bool> requestCallPermissions({bool video = false}) async {
    final bool micOk = await requestMicrophone();
    if (!micOk) return false;
    if (video) {
      return await requestCamera();
    }
    return true;
  }
}

