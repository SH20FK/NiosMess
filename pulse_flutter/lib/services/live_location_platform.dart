import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'live_location_service.dart';

class LiveLocationPlatform {
  static LocationPoint _point(Position p) =>
      (latitude: p.latitude, longitude: p.longitude, accuracy: p.accuracy);

  static Future<LocationPoint> first() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Включите геолокацию в настройках устройства');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError(
        'Разрешите NiosMess доступ к геопозиции в настройках устройства',
      );
    }
    return _point(
      await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      ),
    );
  }

  static Stream<LocationPoint> updates() {
    final LocationSettings settings;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 15),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Передача геопозиции',
          notificationText: 'Остановить передачу можно в сообщении NiosMess',
          notificationChannelName: 'Геопозиция',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }
    return Geolocator.getPositionStream(locationSettings: settings).map(_point);
  }
}
