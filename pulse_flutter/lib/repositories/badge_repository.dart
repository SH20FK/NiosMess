import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class BadgeRepository {
  const BadgeRepository(this._ref);
  final Ref _ref;

  Future<List<ApiBadge>> listBadges() async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('list_badges', payload: <String, dynamic>{});
    if (response is! Map) return const <ApiBadge>[];
    final dynamic badgesRaw = response['badges'];
    if (badgesRaw is! List) return const <ApiBadge>[];
    return badgesRaw
        .whereType<Map>()
        .map((Map item) => ApiBadge.fromJson(item.map((k, v) => MapEntry(k.toString(), v))))
        .toList(growable: false);
  }

  Future<void> createBadge({
    required String adminPassword,
    required String name,
    required String description,
    required String icon,
    required String color,
  }) async {
    await _ref.read(webSocketClientProvider).request('create_badge', payload: <String, dynamic>{
      'admin_password': adminPassword,
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
    });
  }

  Future<void> deleteBadge({
    required String adminPassword,
    required int badgeId,
  }) async {
    await _ref.read(webSocketClientProvider).request('delete_badge', payload: <String, dynamic>{
      'admin_password': adminPassword,
      'badge_id': badgeId,
    });
  }

  Future<void> awardBadge({
    required String adminPassword,
    required int userId,
    required int badgeId,
  }) async {
    await _ref.read(webSocketClientProvider).request('award_badge', payload: <String, dynamic>{
      'admin_password': adminPassword,
      'user_id': userId,
      'badge_id': badgeId,
    });
  }

  Future<void> revokeBadge({
    required String adminPassword,
    required int userId,
    required int badgeId,
  }) async {
    await _ref.read(webSocketClientProvider).request('revoke_badge', payload: <String, dynamic>{
      'admin_password': adminPassword,
      'user_id': userId,
      'badge_id': badgeId,
    });
  }
}

final Provider<BadgeRepository> badgeRepositoryProvider = Provider<BadgeRepository>((Ref ref) {
  return BadgeRepository(ref);
});
