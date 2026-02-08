import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for message bubble customization
final bubbleStyleProvider = StateNotifierProvider<BubbleStyleNotifier, BubbleStyleState>((ref) {
  return BubbleStyleNotifier();
});

class BubbleStyleState {
  final double cornerRadius;
  final bool useGradient;
  final Color? customOutgoingColor;
  final Color? customIncomingColor;
  final bool showTail;
  final double bubblePadding;

  const BubbleStyleState({
    this.cornerRadius = 16.0,
    this.useGradient = true,
    this.customOutgoingColor,
    this.customIncomingColor,
    this.showTail = true,
    this.bubblePadding = 12.0,
  });

  BubbleStyleState copyWith({
    double? cornerRadius,
    bool? useGradient,
    Color? customOutgoingColor,
    Color? customIncomingColor,
    bool? showTail,
    double? bubblePadding,
  }) {
    return BubbleStyleState(
      cornerRadius: cornerRadius ?? this.cornerRadius,
      useGradient: useGradient ?? this.useGradient,
      customOutgoingColor: customOutgoingColor ?? this.customOutgoingColor,
      customIncomingColor: customIncomingColor ?? this.customIncomingColor,
      showTail: showTail ?? this.showTail,
      bubblePadding: bubblePadding ?? this.bubblePadding,
    );
  }

  Map<String, dynamic> toJson() => {
    'cornerRadius': cornerRadius,
    'useGradient': useGradient,
    'customOutgoingColor': customOutgoingColor?.value,
    'customIncomingColor': customIncomingColor?.value,
    'showTail': showTail,
    'bubblePadding': bubblePadding,
  };

  factory BubbleStyleState.fromJson(Map<String, dynamic> json) {
    return BubbleStyleState(
      cornerRadius: json['cornerRadius']?.toDouble() ?? 16.0,
      useGradient: json['useGradient'] ?? true,
      customOutgoingColor: json['customOutgoingColor'] != null 
          ? Color(json['customOutgoingColor']) 
          : null,
      customIncomingColor: json['customIncomingColor'] != null 
          ? Color(json['customIncomingColor']) 
          : null,
      showTail: json['showTail'] ?? true,
      bubblePadding: json['bubblePadding']?.toDouble() ?? 12.0,
    );
  }
}

class BubbleStyleNotifier extends StateNotifier<BubbleStyleState> {
  static const _prefsKey = 'bubble_style_settings';

  BubbleStyleNotifier() : super(const BubbleStyleState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json != null) {
      try {
        final data = Map<String, dynamic>.from(
          Map<String, dynamic>.fromEntries(
            json.toString().split(',').map((e) {
              final parts = e.split(':');
              return MapEntry(parts[0], parts[1]);
            }),
          ),
        );
        state = BubbleStyleState.fromJson(data);
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, state.toJson().toString());
  }

  void setCornerRadius(double radius) {
    state = state.copyWith(cornerRadius: radius.clamp(0.0, 24.0));
    _save();
  }

  void setUseGradient(bool use) {
    state = state.copyWith(useGradient: use);
    _save();
  }

  void setCustomOutgoingColor(Color? color) {
    state = state.copyWith(customOutgoingColor: color);
    _save();
  }

  void setCustomIncomingColor(Color? color) {
    state = state.copyWith(customIncomingColor: color);
    _save();
  }

  void setShowTail(bool show) {
    state = state.copyWith(showTail: show);
    _save();
  }

  void setBubblePadding(double padding) {
    state = state.copyWith(bubblePadding: padding.clamp(4.0, 24.0));
    _save();
  }

  void resetToDefaults() {
    state = const BubbleStyleState();
    _save();
  }
}
