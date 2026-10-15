import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_io/io.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._();
  factory PermissionService() => _instance;
  PermissionService._();

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
    if (status.isGranted || status.isLimited) return true;
    final PermissionStatus videoStatus = await Permission.videos.request();
    if (videoStatus.isGranted || videoStatus.isLimited) return true;
    if (Platform.isAndroid) {
      final PermissionStatus storageStatus = await Permission.storage.request();
      return storageStatus.isGranted || storageStatus.isLimited;
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
    if (await Permission.photos.isGranted ||
        await Permission.photos.isLimited) {
      return true;
    }
    if (await Permission.videos.isGranted ||
        await Permission.videos.isLimited) {
      return true;
    }
    if (Platform.isAndroid) {
      final PermissionStatus storageStatus = await Permission.storage.status;
      return storageStatus.isGranted || storageStatus.isLimited;
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
