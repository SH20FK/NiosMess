import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/models/api/privacy_model.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class PrivacyRepository {
  const PrivacyRepository(this._ref);

  final Ref _ref;

  Future<Map<String, PrivacyRule>> getPrivacy() async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('get_privacy', payload: <String, dynamic>{});
    final Map<String, dynamic> map = asStringMap(response);

    final Map<String, PrivacyRule> result = <String, PrivacyRule>{};

    // Support either map of rules or list of rules
    final dynamic rulesRaw = map['rules'] ?? map['privacy'];
    if (rulesRaw is List) {
      for (final dynamic item in rulesRaw) {
        if (item is Map) {
          final PrivacyRule rule =
              PrivacyRule.fromJson(asStringMap(item));
          if (rule.key.isNotEmpty) {
            result[rule.key] = rule;
          }
        }
      }
    } else if (map.isNotEmpty) {
      for (final MapEntry<String, dynamic> entry in map.entries) {
        if (entry.value is Map) {
          final Map<String, dynamic> ruleMap = asStringMap(entry.value);
          ruleMap['key'] = entry.key;
          result[entry.key] = PrivacyRule.fromJson(ruleMap);
        } else if (entry.value is String) {
          result[entry.key] = PrivacyRule(
            key: entry.key,
            policy: PrivacyPolicy.fromString(entry.value as String),
          );
        }
      }
    }

    // Fill defaults for any missing keys
    for (final String key in PrivacyRule.allKeys) {
      result.putIfAbsent(
        key,
        () => PrivacyRule(key: key, policy: PrivacyPolicy.everyone),
      );
    }

    return result;
  }

  Future<PrivacyRule> setPrivacy({
    required String key,
    required PrivacyPolicy policy,
    List<int> alwaysAllow = const <int>[],
    List<int> neverAllow = const <int>[],
  }) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'set_privacy',
          payload: <String, dynamic>{
            'key': key,
            'default_policy': policy.apiValue,
            'always_allow': alwaysAllow.take(500).toList(),
            'never_allow': neverAllow.take(500).toList(),
          },
        );

    final Map<String, dynamic> map = asStringMap(response);
    if (map.containsKey('key')) {
      return PrivacyRule.fromJson(map);
    }

    return PrivacyRule(
      key: key,
      policy: policy,
      alwaysAllow: alwaysAllow,
      neverAllow: neverAllow,
    );
  }

  Future<bool> blockUser(int userId) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('block_user', payload: <String, dynamic>{'user_id': userId});
    final Map<String, dynamic> map = asStringMap(response);
    return (map['blocked'] == true) || (map['success'] as bool? ?? true);
  }

  Future<bool> unblockUser(int userId) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('unblock_user', payload: <String, dynamic>{'user_id': userId});
    final Map<String, dynamic> map = asStringMap(response);
    return (map['blocked'] == false) || (map['success'] as bool? ?? true);
  }

  Future<List<BlockedUser>> listBlockedUsers() async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('list_blocked_users', payload: <String, dynamic>{});
    final Map<String, dynamic> map = asStringMap(response);
    final dynamic usersRaw = map['blocked_users'] ?? map['users'];
    if (usersRaw is List && usersRaw.isNotEmpty) {
      final List<BlockedUser> list = <BlockedUser>[];
      for (final dynamic item in usersRaw) {
        if (item is Map) {
          list.add(BlockedUser.fromJson(asStringMap(item)));
        } else if (item is num) {
          list.add(BlockedUser(
            id: item.toInt(),
            username: 'id${item.toInt()}',
            displayName: 'ID: ${item.toInt()}',
          ));
        }
      }
      if (list.isNotEmpty) return list;
    }

    final dynamic userIdsRaw = map['user_ids'];
    if (userIdsRaw is List && userIdsRaw.isNotEmpty) {
      return userIdsRaw
          .whereType<num>()
          .map((num id) => BlockedUser(
                id: id.toInt(),
                username: 'id${id.toInt()}',
                displayName: 'ID: ${id.toInt()}',
              ))
          .toList(growable: false);
    }

    return const <BlockedUser>[];
  }
}

final Provider<PrivacyRepository> privacyRepositoryProvider =
    Provider<PrivacyRepository>((Ref ref) => PrivacyRepository(ref));
