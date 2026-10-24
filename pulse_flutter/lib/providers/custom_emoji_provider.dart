import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/models/api/custom_emoji_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

Future<Map<String, dynamic>> emojiRequest(
  Ref ref,
  String action,
  Map<String, dynamic> payload,
) async {
  final dynamic response = await ref
      .read(webSocketClientProvider)
      .request(action, payload: payload);
  if (response is! Map) throw StateError('Не удалось загрузить эмодзи');
  if (response['error'] != null) throw StateError(response['error'].toString());
  return Map<String, dynamic>.from(response);
}

class CustomEmojiSets extends AsyncNotifier<List<ApiCustomEmojiSet>> {
  @override
  Future<List<ApiCustomEmojiSet>> build() async {
    final account = ref.watch(authProvider.select((a) => a.session?.userId));
    if (account == null) return const [];
    final prefs = await SharedPreferences.getInstance();
    final key = 'custom_emoji_sets_v1_$account';
    List<ApiCustomEmojiSet> cached = const [];
    try {
      cached = (jsonDecode(prefs.getString(key) ?? '[]') as List)
          .whereType<Map>()
          .map((e) => ApiCustomEmojiSet.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (cached.isNotEmpty) state = AsyncData(cached);
    } catch (_) {
      /* A damaged optional UI cache can be refetched. */
    }
    final subscription = ref
        .read(webSocketClientProvider)
        .onConnected
        .listen((_) => unawaited(refresh().catchError((Object _) {})));
    ref.onDispose(subscription.cancel);
    try {
      final result = await emojiRequest(ref, 'list_emoji_sets', {});
      final sets = (result['sets'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ApiCustomEmojiSet.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      await prefs.setString(
        key,
        jsonEncode(sets.map((e) => e.toJson()).toList()),
      );
      return sets;
    } catch (_) {
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<void> refresh() async {
    final account = ref.read(authProvider).session?.userId;
    final result = await emojiRequest(ref, 'list_emoji_sets', {});
    if (account != ref.read(authProvider).session?.userId) return;
    state = AsyncData(
      (result['sets'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ApiCustomEmojiSet.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

final customEmojiSetsProvider =
    AsyncNotifierProvider<CustomEmojiSets, List<ApiCustomEmojiSet>>(
      CustomEmojiSets.new,
    );

/// Shared bounded resolver batches visible codes instead of issuing a request per glyph.
class CustomEmojiCatalog extends Notifier<Map<String, ApiCustomEmoji>> {
  final _pending = <String>{}, _missing = <String>{}, _retry = <String>{};
  Timer? _timer;
  bool _fetching = false;
  int _epoch = 0;
  @override
  Map<String, ApiCustomEmoji> build() {
    ref.watch(authProvider.select((a) => a.session?.userId));
    _pending.clear();
    _missing.clear();
    _retry.clear();
    _epoch++;
    _fetching = false;
    _timer?.cancel();
    final reconnect = ref.read(webSocketClientProvider).onConnected.listen((_) {
      if (ref.mounted) {
        final retry = _retry.toList();
        _retry.clear();
        ensure(retry);
      }
    });
    ref.onDispose(() {
      _timer?.cancel();
      reconnect.cancel();
      _epoch++;
    });
    ref.listen(customEmojiSetsProvider, (previous, next) {
      if (next.value != null) {
        _merge([for (final pack in next.value!) ...pack.emojis]);
      }
    });
    return {
      for (final pack
          in ref.read(customEmojiSetsProvider).value ?? <ApiCustomEmojiSet>[])
        for (final emoji in pack.emojis) emoji.shortcode: emoji,
    };
  }

  void _merge(Iterable<ApiCustomEmoji> items) {
    final updated = {
      ...state,
      for (final emoji in items) emoji.shortcode: emoji,
    };
    while (updated.length > 2048) {
      updated.remove(updated.keys.first);
    }
    state = updated;
  }

  void ensure(Iterable<String> codes) {
    _pending.addAll(
      codes.where((c) => !state.containsKey(c) && !_missing.contains(c)),
    );
    if (_pending.isEmpty || _fetching || _timer?.isActive == true) return;
    _timer = Timer(
      const Duration(milliseconds: 30),
      () => unawaited(_resolve()),
    );
  }

  Future<void> _resolve() async {
    final epoch = _epoch;
    final codes = _pending.take(100).toList();
    _pending.removeAll(codes);
    if (codes.isEmpty) return;
    _fetching = true;
    try {
      final result = await emojiRequest(ref, 'resolve_custom_emojis', {
        'shortcodes': codes,
      });
      if (!ref.mounted || epoch != _epoch) return;
      final emojis = (result['emojis'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ApiCustomEmoji.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _missing.addAll(codes.where((c) => !emojis.any((e) => e.shortcode == c)));
      if (_missing.length > 2048) _missing.clear();
      _merge(emojis);
    } catch (_) {
      if (epoch == _epoch) {
        _retry.addAll(codes);
        while (_retry.length > 2048) {
          _retry.remove(_retry.first);
        }
      }
    } finally {
      if (epoch == _epoch) {
        _fetching = false;
        if (_pending.isNotEmpty) ensure(const []);
      }
    }
  }
}

final customEmojiCatalogProvider =
    NotifierProvider<CustomEmojiCatalog, Map<String, ApiCustomEmoji>>(
      CustomEmojiCatalog.new,
    );

final customEmojiRequestProvider =
    Provider<
      Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
    >(
      (ref) =>
          (action, payload) => emojiRequest(ref, action, payload),
    );
