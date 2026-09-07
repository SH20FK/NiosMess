import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/privacy_model.dart';
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
  @override
  PrivacyState build() {
    final client = ref.read(webSocketClientProvider);
    if (client.isConnected) {
      Future<void>.microtask(() => _loadInitial());
      return const PrivacyState(isLoading: true);
    }
    return const PrivacyState(isLoading: false);
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

  Future<bool> blockUser(int userId) async {
    try {
      final PrivacyRepository repo = ref.read(privacyRepositoryProvider);
      final bool success = await repo.blockUser(userId);
      if (success) {
        final List<BlockedUser> updated = await repo.listBlockedUsers();
        state = state.copyWith(blockedUsers: updated);
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: '$e');
      return false;
    }
  }

  Future<bool> unblockUser(int userId) async {
    try {
      final PrivacyRepository repo = ref.read(privacyRepositoryProvider);
      final bool success = await repo.unblockUser(userId);
      if (success) {
        final List<BlockedUser> updated = state.blockedUsers
            .where((BlockedUser u) => u.id != userId)
            .toList(growable: false);
        state = state.copyWith(blockedUsers: updated);
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: '$e');
      return false;
    }
  }
}

final NotifierProvider<PrivacyNotifier, PrivacyState> privacyProvider =
    NotifierProvider<PrivacyNotifier, PrivacyState>(() => PrivacyNotifier());
