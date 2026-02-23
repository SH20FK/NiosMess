import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repositories/api_repository.dart';
import 'session_provider.dart';
import 'storage/offline_cache.dart';

class SettingsController extends StateNotifier<Map<String, dynamic>> {
  SettingsController(this.ref) : super({..._defaults}) {
    _loadCache();
    final session = ref.read(sessionProvider);
    if (session.isAuthed) {
      loadFromServer();
    }
    ref.listen<SessionState>(sessionProvider, (prev, next) {
      if (next.isAuthed) {
        loadFromServer();
      } else {
        _pending.clear();
        _debounce?.cancel();
        state = {..._defaults};
        OfflineCache.saveSettings(state);
      }
    });
    ref.onDispose(() {
      _debounce?.cancel();
    });
  }

  final Ref ref;
  final ApiRepository _api = ApiRepository();
  Timer? _debounce;
  final Map<String, dynamic> _pending = {};

  static final Map<String, dynamic> _defaults = {
    'theme_mode': 'system',
    'seed_color': 0xFF4F46E5,
    'use_dynamic_color': false,
    'text_scale': 1.0,
    'bubble_radius': 16.0,
    'bubble_padding': 12.0,
    'bubble_use_gradient': true,
    'bubble_show_tail': true,
    'bubble_outgoing_color': null,
    'bubble_incoming_color': null,
    'notify_sound': true,
    'notify_preview': true,
    'notify_group': true,
    'notify_mentions': true,
    'notify_calls': true,
    'notify_reactions': true,
    'notify_vibrate': true,
    'quiet_hours_start': null,
    'quiet_hours_end': null,
    'last_seen_visibility': 'Все',
    'photo_visibility': 'Все',
    'message_privacy': 'Все',
    'call_privacy': 'Все',
    'show_typing': true,
    'read_receipts': true,
    'who_can_write': 'all',
    'ghost_mode': false,
    'passcode_lock': false,
    'compact_messages': false,
    'link_preview': true,
    'trim_spaces': false,
    'autosave_drafts': true,
    'enter_to_send': false,
    'auto_download_media': true,
    'auto_download_docs': false,
    'wifi_only_downloads': false,
    'data_saver': false,
    'reduce_motion': false,
    'experimental_features': false,
    'app_icon': 'Классика',
  };

  Future<void> _loadCache() async {
    final loaded = await OfflineCache.loadSettings();
    final migrated = _migrate(loaded);
    state = {..._defaults, ...migrated};
  }

  Map<String, dynamic> _migrate(Map<String, dynamic> raw) {
    final migrated = {...raw};
    if (!migrated.containsKey('notify_sound') && migrated.containsKey('sound_enabled')) {
      migrated['notify_sound'] = migrated['sound_enabled'];
    }
    if (!migrated.containsKey('notify_preview') && migrated.containsKey('preview_enabled')) {
      migrated['notify_preview'] = migrated['preview_enabled'];
    }
    if (!migrated.containsKey('notify_group') && migrated.containsKey('group_notifications')) {
      migrated['notify_group'] = migrated['group_notifications'];
    }
    if (!migrated.containsKey('notify_mentions') && migrated.containsKey('mention_notifications')) {
      migrated['notify_mentions'] = migrated['mention_notifications'];
    }
    if (migrated['message_privacy'] == 'Мои контакты') {
      migrated['message_privacy'] = 'Контакты';
    }
    if (migrated['call_privacy'] == 'Мои контакты') {
      migrated['call_privacy'] = 'Контакты';
    }
    if (migrated['last_seen_visibility'] == 'Мои контакты') {
      migrated['last_seen_visibility'] = 'Контакты';
    }
    if (migrated['photo_visibility'] == 'Мои контакты') {
      migrated['photo_visibility'] = 'Контакты';
    }
    return migrated;
  }

  Future<void> loadFromServer() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    try {
      final data = await _api.getSettings(username: session.username!, sessionToken: session.token!);
      final merged = {..._defaults, ..._migrate(data)};
      state = merged;
      await OfflineCache.saveSettings(merged);
    } catch (_) {
      await _loadCache();
    }
  }

  Future<void> setSetting(String key, dynamic value) async {
    state = {...state, key: value};
    await OfflineCache.saveSettings(state);
    _pending[key] = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _flushPending);
  }

  Future<void> _flushPending() async {
    if (_pending.isEmpty) return;
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    final payload = Map<String, dynamic>.from(_pending);
    _pending.clear();
    try {
      await _api.setSettings(
        username: session.username!,
        sessionToken: session.token!,
        settings: payload,
      );
    } catch (_) {
      _pending.addAll(payload);
    }
  }
}

final settingsProvider = StateNotifierProvider<SettingsController, Map<String, dynamic>>(
  (ref) => SettingsController(ref),
);
