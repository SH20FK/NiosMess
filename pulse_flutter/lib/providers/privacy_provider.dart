import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/privacy_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/privacy_repository.dart';

class PrivacyState {
  const PrivacyState({
    this.rules = const <String, PrivacyRule>{},
    this.blockedUsers = const <BlockedUser>[],
    this.revision = 0,
    this.isLoading = false,
    this.error,
    this.pendingRules = const {},
    this.pendingUsers = const {},
  });

  final Map<String, PrivacyRule> rules;
  final List<BlockedUser> blockedUsers;
  final int revision;
  final bool isLoading;
  final String? error;
  final Set<String> pendingRules;
  final Set<int> pendingUsers;

  PrivacyPolicy policyFor(String key) {
    return rules[key]?.policy ?? PrivacyPolicy.everyone;
  }

  bool get readReceiptsEnabled =>
      policyFor('read_receipts') != PrivacyPolicy.nobody;

  bool get typingIndicatorsEnabled =>
      policyFor('typing_indicators') != PrivacyPolicy.nobody;

  bool isUserBlocked(int userId) {
    return blockedUsers.any((BlockedUser u) => u.id == userId);
  }

  bool isBlocked(int userId) => isUserBlocked(userId);

  PrivacyState copyWith({
    Map<String, PrivacyRule>? rules,
    List<BlockedUser>? blockedUsers,
    int? revision,
    bool? isLoading,
    String? error,
    Set<String>? pendingRules,
    Set<int>? pendingUsers,
  }) {
    return PrivacyState(
      rules: rules ?? this.rules,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      revision: revision ?? this.revision,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      pendingRules: pendingRules ?? this.pendingRules,
      pendingUsers: pendingUsers ?? this.pendingUsers,
    );
  }
}

class PrivacyNotifier extends Notifier<PrivacyState> {
  StreamSubscription<Map<String, dynamic>>? _eventsSub;
  int _epoch = 0;
  (int?, String?) _account = (null, null);
  int _loadGeneration = 0;

  bool _current(int epoch) =>
      ref.mounted &&
      epoch == _epoch &&
      _account ==
          (
            ref.read(authProvider).session?.userId,
            ref.read(authProvider).session?.accessToken,
          ) &&
      ref.read(authProvider).isAuthenticated &&
      !ref.read(authProvider.notifier).isLoggingOut;

  bool get _mutating =>
      state.pendingRules.isNotEmpty || state.pendingUsers.isNotEmpty;

  @override
  PrivacyState build() {
    final account = ref.watch(
      authProvider.select((a) => (a.session?.userId, a.session?.accessToken)),
    );
    _account = account;
    final epoch = ++_epoch;
    _loadGeneration++;
    _eventsSub?.cancel();
    if (account.$1 == null || account.$2?.isNotEmpty != true) {
      return const PrivacyState();
    }
    final client = ref.watch(webSocketClientProvider);
    final subscription = client.pushStream.listen((event) {
      if (_current(epoch)) _onWebSocketEvent(event);
    });
    _eventsSub = subscription;
    ref.onDispose(() {
      subscription.cancel();
      if (_epoch == epoch) _epoch++;
    });
    unawaited(Future<void>.microtask(() => _loadInitial(epoch)));
    return const PrivacyState(isLoading: true);
  }

  void _onWebSocketEvent(Map<String, dynamic> event) {
    final action = event['action'];
    if (action == 'user_blocked' ||
        action == 'user_unblocked' ||
        action == 'block_status_updated') {
      unawaited(refresh());
      unawaited(ref.read(chatsProvider.notifier).refresh());
    }
  }

  Future<void> _loadInitial(int epoch) async {
    if (!_current(epoch) || _mutating) return;
    final load = ++_loadGeneration;
    try {
      final repo = ref.read(privacyRepositoryProvider);
      final (snapshot, blocked) = await (
        repo.getPrivacySnapshot(),
        repo.listBlockedUsers(),
      ).wait;
      if (!_current(epoch) || load != _loadGeneration || _mutating) return;
      state = state.copyWith(
        rules: snapshot.rules,
        revision: snapshot.revision,
        blockedUsers: blocked,
        isLoading: false,
      );
      final lastSeenRule = snapshot.rules['last_seen'];
      if (lastSeenRule != null) {
        ref
            .read(uiSettingsProvider.notifier)
            .setHideOnline(lastSeenRule.policy == PrivacyPolicy.nobody);
      }
    } catch (_) {
      if (_current(epoch) && load == _loadGeneration) {
        state = state.copyWith(isLoading: false, error: 'privacy_load_failed');
      }
    }
  }

  Future<void> refresh() => _loadInitial(_epoch);

  bool get readReceiptsEnabled =>
      state.policyFor('read_receipts') != PrivacyPolicy.nobody;

  bool get typingIndicatorsEnabled =>
      state.policyFor('typing_indicators') != PrivacyPolicy.nobody;

  Future<void> setReadReceipts(bool enabled) async {
    await updateRule(
      key: 'read_receipts',
      policy: enabled ? PrivacyPolicy.everyone : PrivacyPolicy.nobody,
    );
  }

  Future<void> setTypingIndicators(bool enabled) async {
    await updateRule(
      key: 'typing_indicators',
      policy: enabled ? PrivacyPolicy.everyone : PrivacyPolicy.nobody,
    );
  }

  Future<void> updateRule({
    required String key,
    required PrivacyPolicy policy,
    List<int>? alwaysAllow,
    List<int>? neverAllow,
  }) async {
    final epoch = _epoch;
    if (!_current(epoch) || _mutating) {
      throw StateError('privacy_account_unavailable_or_busy');
    }
    final repo = ref.read(privacyRepositoryProvider);
    final previous = state.rules[key];
    final current =
        previous ?? PrivacyRule(key: key, policy: PrivacyPolicy.everyone);
    final optimistic = current.copyWith(
      policy: policy,
      alwaysAllow: alwaysAllow ?? current.alwaysAllow,
      neverAllow: neverAllow ?? current.neverAllow,
    );
    _loadGeneration++;
    state = state.copyWith(
      rules: {...state.rules, key: optimistic},
      pendingRules: {key},
    );
    if (key == 'last_seen') {
      ref
          .read(uiSettingsProvider.notifier)
          .setHideOnline(policy == PrivacyPolicy.nobody);
    }
    try {
      final result = await repo.setPrivacy(
        key: key,
        policy: policy,
        alwaysAllow: optimistic.alwaysAllow,
        neverAllow: optimistic.neverAllow,
        expectedRevision: state.revision,
      );
      if (!_current(epoch)) return;
      state = state.copyWith(
        rules: {...state.rules, key: result.rule},
        revision: result.revision,
        pendingRules: const {},
      );
    } catch (_) {
      if (!_current(epoch)) return;
      final restored = {...state.rules};
      if (previous == null) {
        restored.remove(key);
      } else {
        restored[key] = previous;
      }
      state = state.copyWith(
        rules: restored,
        pendingRules: const {},
        error: 'privacy_save_failed',
      );
      if (key == 'last_seen') {
        ref
            .read(uiSettingsProvider.notifier)
            .setHideOnline(current.policy == PrivacyPolicy.nobody);
      }
      unawaited(_loadInitial(epoch));
      rethrow;
    }
  }

  Future<bool> blockUser(int userId, {BlockedUser? user}) =>
      _setBlocked(userId, true, user: user);

  Future<bool> unblockUser(int userId) => _setBlocked(userId, false);

  Future<bool> _setBlocked(
    int userId,
    bool blocked, {
    BlockedUser? user,
  }) async {
    final epoch = _epoch;
    if (!_current(epoch) || _mutating) return false;
    final previous = state.blockedUsers;
    final optimistic = previous.where((u) => u.id != userId).toList();
    if (blocked) {
      optimistic.add(
        user ??
            BlockedUser(
              id: userId,
              username: 'id$userId',
              displayName: 'ID: $userId',
            ),
      );
    }
    _loadGeneration++;
    state = state.copyWith(blockedUsers: optimistic, pendingUsers: {userId});
    try {
      final repo = ref.read(privacyRepositoryProvider);
      final success = blocked
          ? await repo.blockUser(userId)
          : await repo.unblockUser(userId);
      if (!_current(epoch)) return false;
      state = state.copyWith(
        blockedUsers: success ? optimistic : previous,
        pendingUsers: const {},
        error: success ? null : 'privacy_save_failed',
      );
      if (success) {
        unawaited(ref.read(chatsProvider.notifier).refresh());
        unawaited(_loadInitial(epoch));
      }
      return success;
    } catch (_) {
      if (_current(epoch)) {
        state = state.copyWith(
          blockedUsers: previous,
          pendingUsers: const {},
          error: 'privacy_save_failed',
        );
      }
      return false;
    }
  }
}

final NotifierProvider<PrivacyNotifier, PrivacyState> privacyProvider =
    NotifierProvider<PrivacyNotifier, PrivacyState>(() => PrivacyNotifier());
