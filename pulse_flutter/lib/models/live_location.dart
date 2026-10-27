import 'dart:convert';

class LiveLocation {
  const LiveLocation({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    required this.active,
  });
  static const prefix = 'nios:location:1:';
  final String id;
  final double latitude, longitude, accuracy;
  final DateTime createdAt, updatedAt, expiresAt;
  final bool active;
  bool activeAt(DateTime now) => active && now.isBefore(expiresAt);
  String get preview => 'Геопозиция';

  String encode() =>
      '$prefix${jsonEncode({'id': id, 'lat': latitude, 'lng': longitude, 'accuracy': accuracy, 'created': createdAt.toUtc().millisecondsSinceEpoch, 'updated': updatedAt.toUtc().millisecondsSinceEpoch, 'expires': expiresAt.toUtc().millisecondsSinceEpoch, 'active': active})}';

  LiveLocation update(double lat, double lng, double precision, DateTime now) =>
      LiveLocation(
        id: id,
        latitude: lat,
        longitude: lng,
        accuracy: precision,
        createdAt: createdAt,
        updatedAt: now,
        expiresAt: expiresAt,
        active: true,
      );
  LiveLocation stop() => LiveLocation(
    id: id,
    latitude: latitude,
    longitude: longitude,
    accuracy: accuracy,
    createdAt: createdAt,
    updatedAt: updatedAt,
    expiresAt: expiresAt,
    active: false,
  );

  static LiveLocation? parse(String text) {
    if (!text.startsWith(prefix) || text.length > 2048) return null;
    try {
      final d = jsonDecode(text.substring(prefix.length));
      if (d is! Map ||
          d['id'] is! String ||
          !RegExp(r'^[a-f0-9-]{36}$').hasMatch(d['id']) ||
          d['lat'] is! num ||
          d['lng'] is! num ||
          d['accuracy'] is! num ||
          d['created'] is! int ||
          d['updated'] is! int ||
          d['expires'] is! int ||
          d['active'] is! bool) {
        return null;
      }
      final lat = (d['lat'] as num).toDouble(),
          lng = (d['lng'] as num).toDouble(),
          precision = (d['accuracy'] as num).toDouble();
      if (!lat.isFinite ||
          !lng.isFinite ||
          !precision.isFinite ||
          lat.abs() > 90 ||
          lng.abs() > 180 ||
          precision < 0 ||
          precision > 100000) {
        return null;
      }
      final created = DateTime.fromMillisecondsSinceEpoch(
        d['created'],
        isUtc: true,
      );
      final updated = DateTime.fromMillisecondsSinceEpoch(
        d['updated'],
        isUtc: true,
      );
      final expires = DateTime.fromMillisecondsSinceEpoch(
        d['expires'],
        isUtc: true,
      );
      if (created.isAfter(updated) ||
          !expires.isAfter(created) ||
          updated.isAfter(expires) ||
          expires.difference(created) > const Duration(hours: 24)) {
        return null;
      }
      return LiveLocation(
        id: d['id'],
        latitude: lat,
        longitude: lng,
        accuracy: precision,
        createdAt: created,
        updatedAt: updated,
        expiresAt: expires,
        active: d['active'],
      );
    } catch (_) {
      return null;
    }
  }
}
