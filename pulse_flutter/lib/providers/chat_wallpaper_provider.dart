import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/wallpaper/wallpaper_image_cache.dart';

const String _kGlobalWallpaperKey = 'nios_global_wallpaper_v1';
const String _kChatWallpapersKey = 'nios_chat_wallpapers_map_v1';

class ChatWallpaperState {
  const ChatWallpaperState({
    this.global = ChatWallpaperConfig.defaultPattern,
    this.chatOverrides = const <String, ChatWallpaperConfig>{},
    this.isLoaded = false,
    this.undoConfig,
  });

  final ChatWallpaperConfig global;
  final Map<String, ChatWallpaperConfig> chatOverrides;
  final bool isLoaded;
  final ChatWallpaperConfig? undoConfig;

  ChatWallpaperConfig forChat(String? chatId) {
    if (chatId == null || chatId.isEmpty) return global;
    return chatOverrides[chatId] ?? global;
  }

  ChatWallpaperState copyWith({
    ChatWallpaperConfig? global,
    Map<String, ChatWallpaperConfig>? chatOverrides,
    bool? isLoaded,
    ChatWallpaperConfig? undoConfig,
    bool clearUndo = false,
  }) {
    return ChatWallpaperState(
      global: global ?? this.global,
      chatOverrides: chatOverrides ?? this.chatOverrides,
      isLoaded: isLoaded ?? this.isLoaded,
      undoConfig: clearUndo ? null : (undoConfig ?? this.undoConfig),
    );
  }
}

class ChatWallpaperNotifier extends Notifier<ChatWallpaperState> {
  int _currentUserId = -1;

  @override
  ChatWallpaperState build() {
    final int userId = ref.watch(
      authProvider.select((AuthState s) => s.session?.userId ?? -1),
    );
    _currentUserId = userId;
    _loadFromPrefs(userId);
    return const ChatWallpaperState();
  }

  String _getGlobalKey(int userId) =>
      userId > 0 ? '${_kGlobalWallpaperKey}_$userId' : _kGlobalWallpaperKey;

  String _getChatMapKey(int userId) =>
      userId > 0 ? '${_kChatWallpapersKey}_$userId' : _kChatWallpapersKey;

  Future<void> _loadFromPrefs(int userId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      ChatWallpaperConfig global = ChatWallpaperConfig.defaultPattern;

      final String globalKey = _getGlobalKey(userId);
      String? globalStr = prefs.getString(globalKey);
      // Backwards-compatible fallback to un-namespaced key
      if ((globalStr == null || globalStr.isEmpty) && userId > 0) {
        globalStr = prefs.getString(_kGlobalWallpaperKey);
      }
      if (globalStr != null && globalStr.isNotEmpty) {
        global = ChatWallpaperConfig.fromJson(globalStr);
      }

      final Map<String, ChatWallpaperConfig> overrides =
          <String, ChatWallpaperConfig>{};
      final String mapKey = _getChatMapKey(userId);
      String? mapStr = prefs.getString(mapKey);
      if ((mapStr == null || mapStr.isEmpty) && userId > 0) {
        mapStr = prefs.getString(_kChatWallpapersKey);
      }
      if (mapStr != null && mapStr.isNotEmpty) {
        final dynamic decoded = jsonDecode(mapStr);
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((key, value) {
            if (value is Map<String, dynamic>) {
              overrides[key] = ChatWallpaperConfig.fromMap(value);
            }
          });
        }
      }

      state = state.copyWith(
        global: global,
        chatOverrides: overrides,
        isLoaded: true,
      );
    } catch (_) {
      state = state.copyWith(isLoaded: true);
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String globalKey = _getGlobalKey(_currentUserId);
      final String mapKey = _getChatMapKey(_currentUserId);

      await prefs.setString(globalKey, state.global.toJson());
      final Map<String, dynamic> rawMap = <String, dynamic>{};
      state.chatOverrides.forEach((key, value) {
        rawMap[key] = value.toMap();
      });
      await prefs.setString(mapKey, jsonEncode(rawMap));
    } catch (_) {}
  }

  void updateGlobalConfig(
    ChatWallpaperConfig newConfig, {
    ChatWallpaperConfig? previousConfig,
  }) {
    WallpaperImageCache.clear();
    state = state.copyWith(
      global: newConfig,
      undoConfig: previousConfig ?? state.global,
    );
    _saveToPrefs();
  }

  void setChatWallpaper(
    String chatId,
    ChatWallpaperConfig? config, {
    ChatWallpaperConfig? previousConfig,
  }) {
    WallpaperImageCache.clear();
    final Map<String, ChatWallpaperConfig> updated =
        Map<String, ChatWallpaperConfig>.from(state.chatOverrides);
    final ChatWallpaperConfig? old = updated[chatId];
    if (config == null) {
      updated.remove(chatId);
    } else {
      updated[chatId] = config;
    }
    state = state.copyWith(
      chatOverrides: updated,
      undoConfig: previousConfig ?? old,
    );
    _saveToPrefs();
  }

  bool undoLastChange(String? chatId) {
    final ChatWallpaperConfig? undo = state.undoConfig;
    if (undo == null) return false;
    if (chatId != null && chatId.isNotEmpty) {
      setChatWallpaper(chatId, undo);
    } else {
      updateGlobalConfig(undo);
    }
    state = state.copyWith(clearUndo: true);
    return true;
  }

  void resetChatWallpaper(String chatId) {
    setChatWallpaper(chatId, null);
  }

  void resetGlobalToDefault() {
    WallpaperImageCache.clear();
    state = state.copyWith(
      global: ChatWallpaperConfig.defaultPattern,
      undoConfig: state.global,
    );
    _saveToPrefs();
  }

  void resetAllToDefault() {
    WallpaperImageCache.clear();
    state = const ChatWallpaperState(isLoaded: true);
    _saveToPrefs();
  }
}

final NotifierProvider<ChatWallpaperNotifier, ChatWallpaperState>
    chatWallpaperProvider =
        NotifierProvider<ChatWallpaperNotifier, ChatWallpaperState>(
  ChatWallpaperNotifier.new,
);
