import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for chat wallpaper settings
final wallpaperProvider = StateNotifierProvider<WallpaperNotifier, WallpaperState>((ref) {
  return WallpaperNotifier();
});

class WallpaperState {
  final String? wallpaperUrl;
  final bool useParallax;
  final double blurAmount;
  final double opacity;
  final bool isCustom;
  final String? localPath;

  const WallpaperState({
    this.wallpaperUrl,
    this.useParallax = true,
    this.blurAmount = 0.0,
    this.opacity = 1.0,
    this.isCustom = false,
    this.localPath,
  });

  WallpaperState copyWith({
    String? wallpaperUrl,
    bool? useParallax,
    double? blurAmount,
    double? opacity,
    bool? isCustom,
    String? localPath,
  }) {
    return WallpaperState(
      wallpaperUrl: wallpaperUrl ?? this.wallpaperUrl,
      useParallax: useParallax ?? this.useParallax,
      blurAmount: blurAmount ?? this.blurAmount,
      opacity: opacity ?? this.opacity,
      isCustom: isCustom ?? this.isCustom,
      localPath: localPath ?? this.localPath,
    );
  }

  Map<String, dynamic> toJson() => {
    'wallpaperUrl': wallpaperUrl,
    'useParallax': useParallax,
    'blurAmount': blurAmount,
    'opacity': opacity,
    'isCustom': isCustom,
    'localPath': localPath,
  };

  factory WallpaperState.fromJson(Map<String, dynamic> json) {
    return WallpaperState(
      wallpaperUrl: json['wallpaperUrl'],
      useParallax: json['useParallax'] ?? true,
      blurAmount: json['blurAmount']?.toDouble() ?? 0.0,
      opacity: json['opacity']?.toDouble() ?? 1.0,
      isCustom: json['isCustom'] ?? false,
      localPath: json['localPath'],
    );
  }
}

class WallpaperNotifier extends StateNotifier<WallpaperState> {
  static const _prefsKey = 'wallpaper_settings';

  // Preset wallpapers
  static const presetWallpapers = [
    'https://i.imgur.com/ZUfitM7.png', // Dark pattern
    'https://i.imgur.com/k9wk8YW.png', // Light pattern
    'https://i.imgur.com/0ei9Yj5.png', // Violet pattern
    'https://i.imgur.com/3QZQZQY.png', // Abstract dark
    'https://i.imgur.com/8Km9tLG.png', // Minimal
    'https://i.imgur.com/2j0X7BZ.png', // Gradient
  ];

  WallpaperNotifier() : super(const WallpaperState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString != null) {
      try {
        final data = Map<String, dynamic>.from(
          Map<String, dynamic>.fromEntries(
            jsonString.toString().split(',').where((e) => e.contains(':')).map((e) {
              final parts = e.split(':');
              return MapEntry(parts[0], parts[1]);
            }),
          ),
        );
        state = WallpaperState.fromJson(data);
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, state.toJson().toString());
  }

  void setWallpaper(String? url) {
    state = state.copyWith(
      wallpaperUrl: url,
      isCustom: url != null && !presetWallpapers.contains(url),
    );
    _save();
  }

  void setUseParallax(bool use) {
    state = state.copyWith(useParallax: use);
    _save();
  }

  void setBlurAmount(double blur) {
    state = state.copyWith(blurAmount: blur.clamp(0.0, 20.0));
    _save();
  }

  void setOpacity(double opacity) {
    state = state.copyWith(opacity: opacity.clamp(0.1, 1.0));
    _save();
  }

  void setLocalPath(String? path) {
    state = state.copyWith(localPath: path);
    _save();
  }

  void clearWallpaper() {
    state = const WallpaperState();
    _save();
  }

  void nextPreset() {
    final currentIndex = presetWallpapers.indexOf(state.wallpaperUrl ?? '');
    final nextIndex = (currentIndex + 1) % presetWallpapers.length;
    setWallpaper(presetWallpapers[nextIndex]);
  }
}
