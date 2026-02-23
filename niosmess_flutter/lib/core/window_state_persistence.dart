import 'dart:async';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Saves and restores desktop window size, position, and maximized state.
class WindowStatePersistence {
  static const _keyX = 'window_x';
  static const _keyY = 'window_y';
  static const _keyW = 'window_w';
  static const _keyH = 'window_h';
  static const _keyMaximized = 'window_maximized';
  static const _keyChatListWidth = 'window_chat_list_width';

  /// Restore window geometry from SharedPreferences.
  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isMaximized = prefs.getBool(_keyMaximized) ?? true;
      if (isMaximized) {
        await windowManager.maximize();
        return;
      }
      final x = prefs.getDouble(_keyX);
      final y = prefs.getDouble(_keyY);
      final w = prefs.getDouble(_keyW) ?? 1280;
      final h = prefs.getDouble(_keyH) ?? 800;
      if (x != null && y != null) {
        await windowManager.setBounds(
          Rect.fromLTWH(x, y, w.clamp(900, 9999), h.clamp(650, 9999)),
        );
      } else {
        await windowManager.setSize(Size(w.clamp(900, 9999), h.clamp(650, 9999)));
        await windowManager.center();
      }
    } catch (_) {}
  }

  /// Persist current window geometry.
  static Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isMaximized = await windowManager.isMaximized();
      await prefs.setBool(_keyMaximized, isMaximized);
      if (!isMaximized) {
        final bounds = await windowManager.getBounds();
        await prefs.setDouble(_keyX, bounds.left);
        await prefs.setDouble(_keyY, bounds.top);
        await prefs.setDouble(_keyW, bounds.width);
        await prefs.setDouble(_keyH, bounds.height);
      }
    } catch (_) {}
  }

  /// Save chat list panel width (from drag resize).
  static Future<void> saveChatListWidth(double width) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyChatListWidth, width);
    } catch (_) {}
  }

  /// Load saved chat list panel width, or return null for default.
  static Future<double?> loadChatListWidth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_keyChatListWidth);
    } catch (_) {
      return null;
    }
  }
}
