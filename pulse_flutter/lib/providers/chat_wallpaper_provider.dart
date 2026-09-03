import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/models/chat_wallpaper_config.dart';
import 'package:pulse_flutter/widgets/wallpaper/wallpaper_image_cache.dart';

const String _kGlobalWallpaperKey = 'nios_global_wallpaper_v1';
const String _kChatWallpapersKey = 'nios_chat_wallpapers_map_v1';

class ChatWallpaperState {
  const ChatWallpaperState({
    this.global = ChatWallpaperConfig.defaultPattern,
    this.chatOverrides = const <String, ChatWallpaperConfig>{},
  });

  final ChatWallpaperConfig global;
  final Map<String, ChatWallpaperConfig> chatOverrides;

  ChatWallpaperConfig forChat(String? chatId) {
    if (chatId == null || chatId.isEmpty) return global;
    return chatOverrides[chatId] ?? global;
  }

  ChatWallpaperState copyWith({
    ChatWallpaperConfig? global,
    Map<String, ChatWallpaperConfig>? chatOverrides,
  }) {
    return ChatWallpaperState(
      global: global ?? this.global,
      chatOverrides: chatOverrides ?? this.chatOverrides,
    );
  }
}

class ChatWallpaperNotifier extends Notifier<ChatWallpaperState> {
  @override
  ChatWallpaperState build() {
    _loadFromPrefs();
    return const ChatWallpaperState();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      ChatWallpaperConfig global = ChatWallpaperConfig.defaultPattern;
      final String? globalStr = prefs.getString(_kGlobalWallpaperKey);
      if (globalStr != null && globalStr.isNotEmpty) {
        global = ChatWallpaperConfig.fromJson(globalStr);
      }

      final Map<String, ChatWallpaperConfig> overrides = <String, ChatWallpaperConfig>{};
      final String? mapStr = prefs.getString(_kChatWallpapersKey);
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

      state = state.copyWith(global: global, chatOverrides: overrides);
    } catch (_) {}
  }

  Future<void> _saveToPrefs() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kGlobalWallpaperKey, state.global.toJson());
      final Map<String, dynamic> rawMap = <String, dynamic>{};
      state.chatOverrides.forEach((key, value) {
        rawMap[key] = value.toMap();
      });
      await prefs.setString(_kChatWallpapersKey, jsonEncode(rawMap));
    } catch (_) {}
  }

  void updateGlobalConfig(ChatWallpaperConfig newConfig) {
    WallpaperImageCache.clear();
    state = state.copyWith(global: newConfig);
    _saveToPrefs();
  }

  void setChatWallpaper(String chatId, ChatWallpaperConfig? config) {
    WallpaperImageCache.clear();
    final Map<String, ChatWallpaperConfig> updated =
        Map<String, ChatWallpaperConfig>.from(state.chatOverrides);
    if (config == null) {
      updated.remove(chatId);
    } else {
      updated[chatId] = config;
    }
    state = state.copyWith(chatOverrides: updated);
    _saveToPrefs();
  }

  void resetChatWallpaper(String chatId) {
    setChatWallpaper(chatId, null);
  }

  void resetAllToDefault() {
    WallpaperImageCache.clear();
    state = const ChatWallpaperState();
    _saveToPrefs();
  }
}

final NotifierProvider<ChatWallpaperNotifier, ChatWallpaperState>
    chatWallpaperProvider =
        NotifierProvider<ChatWallpaperNotifier, ChatWallpaperState>(
  ChatWallpaperNotifier.new,
);
