import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._();
  factory PermissionService() => _instance;
  PermissionService._();

  Future<bool> requestMicrophone() async {
    if (kIsWeb) return true;
    final status = await Permission.microphone.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    return false;
  }

  Future<bool> requestCamera() async {
    if (kIsWeb) return true;
    final status = await Permission.camera.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
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

  Future<bool> requestCallPermissions({bool video = false}) async {
    final micOk = await requestMicrophone();
    if (!micOk) return false;
    if (video) {
      return await requestCamera();
    }
    return true;
  }
}
