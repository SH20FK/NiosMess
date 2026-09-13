import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/privacy_model.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/privacy_repository.dart';

class PrivacyState {
  const PrivacyState({
    this.rules = const <String, PrivacyRule>{},
    this.blockedUsers = const <BlockedUser>[],
    this.isLoading = false,
    this.error,
  });

  final Map<String, PrivacyRule> rules;
  final List<BlockedUser> blockedUsers;
  final bool isLoading;
  final String? error;

  PrivacyPolicy policyFor(String key) {
    return rules[key]?.policy ?? PrivacyPolicy.everyone;
  }

  bool isUserBlocked(int userId) {
    return blockedUsers.any((BlockedUser u) => u.id == userId);
  }

  bool isBlocked(int userId) => isUserBlocked(userId);

  PrivacyState copyWith({
    Map<String, PrivacyRule>? rules,
    List<BlockedUser>? blockedUsers,
    bool? isLoading,
    String? error,
  }) {
    return PrivacyState(
      rules: rules ?? this.rules,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PrivacyNotifier extends Notifier<PrivacyState> {
  StreamSubscription<Map<String, dynamic>>? _eventsSub;

  @override
  PrivacyState build() {
    final client = ref.read(webSocketClientProvider);
    _eventsSub?.cancel();
    _eventsSub = client.pushStream.listen(_onWebSocketEvent);
    ref.onDispose(() {
      _eventsSub?.cancel();
    });

    if (client.isConnected) {
      Future<void>.microtask(() => _loadInitial());
      return const PrivacyState(isLoading: true);
    }
    return const PrivacyState(isLoading: false);
  }

  void _onWebSocketEvent(Map<String, dynamic> event) {
    final String? action = event['action'] as String?;
    final dynamic rawPayload = event['payload'];
    final Map<String, dynamic> payload = rawPayload is Map
        ? rawPayload.map((k, v) => MapEntry(k.toString(), v))
        : const <String, dynamic>{};

    if (action == 'user_blocked') {
      final int uid = int.tryParse(payload['user_id']?.toString() ?? '') ?? 0;
      if (uid > 0 && !state.isUserBlocked(uid)) {
        refresh();
      }
    } else if (action == 'user_unblocked') {
      final int uid = int.tryParse(payload['user_id']?.toString() ?? '') ?? 0;
      if (uid > 0) {
        final updated = state.blockedUsers
            .where((BlockedUser u) => u.id != uid)
            .toList(growable: false);
        state = state.copyWith(blockedUsers: updated);
      }
    } else if (action == 'block_status_updated') {
      ref.read(chatsProvider.notifier).refresh();
    }
  }

  Future<void> _loadInitial() async {
    try {
      final client = ref.read(webSocketClientProvider);
      if (!client.isConnected) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final PrivacyRepository repo = ref.read(privacyRepositoryProvider);
      final Map<String, PrivacyRule> rules = await repo.getPrivacy();
      final List<BlockedUser> blocked = await repo.listBlockedUsers();
      state = state.copyWith(
        rules: rules,
        blockedUsers: blocked,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  Future<void> refresh() async {
    await _loadInitial();
  }

  Future<void> updateRule({
    required String key,
    required PrivacyPolicy policy,
    List<int>? alwaysAllow,
    List<int>? neverAllow,
  }) async {
    try {
      final PrivacyRepository repo = ref.read(privacyRepositoryProvider);
      final PrivacyRule current = state.rules[key] ??
          PrivacyRule(key: key, policy: PrivacyPolicy.everyone);

      final PrivacyRule updated = await repo.setPrivacy(
        key: key,
        policy: policy,
        alwaysAllow: alwaysAllow ?? current.alwaysAllow,
        neverAllow: neverAllow ?? current.neverAllow,
      );

      final Map<String, PrivacyRule> newRules =
          Map<String, PrivacyRule>.from(state.rules);
      newRules[key] = updated;
      state = state.copyWith(rules: newRules);
    } catch (e) {
      state = state.copyWith(error: '$e');
      rethrow;
    }
  }

  Future<bool> blockUser(int userId, {BlockedUser? user}) async {
    // Optimistic add
    final List<BlockedUser> current = List<BlockedUser>.from(state.blockedUsers);
    if (!current.any((BlockedUser u) => u.id == userId)) {
      current.add(
        user ??
            BlockedUser(
              id: userId,
              username: 'id$userId',
              displayName: 'Пользователь #$userId',
            ),
      );
      state = state.copyWith(blockedUsers: current);
    }

    try {
      final PrivacyRepository repo = ref.read(privacyRepositoryProvider);
      final bool success = await repo.blockUser(userId);
      if (success) {
        final List<BlockedUser> updated = await repo.listBlockedUsers();
        state = state.copyWith(blockedUsers: updated);
        ref.read(chatsProvider.notifier).refresh();
      } else {
        await refresh();
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: '$e');
      await refresh();
      return false;
    }
  }

  Future<bool> unblockUser(int userId) async {
    // Optimistic remove
    final List<BlockedUser> updated = state.blockedUsers
        .where((BlockedUser u) => u.id != userId)
        .toList(growable: false);
    state = state.copyWith(blockedUsers: updated);

    try {
      final PrivacyRepository repo = ref.read(privacyRepositoryProvider);
      final bool success = await repo.unblockUser(userId);
      if (success) {
        final List<BlockedUser> fresh = await repo.listBlockedUsers();
        state = state.copyWith(blockedUsers: fresh);
        ref.read(chatsProvider.notifier).refresh();
      } else {
        await refresh();
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: '$e');
      await refresh();
      return false;
    }
  }
}

final NotifierProvider<PrivacyNotifier, PrivacyState> privacyProvider =
    NotifierProvider<PrivacyNotifier, PrivacyState>(() => PrivacyNotifier());
