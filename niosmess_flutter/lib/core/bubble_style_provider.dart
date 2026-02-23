import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';

final bubbleStyleProvider = StateNotifierProvider<BubbleStyleNotifier, BubbleStyleState>((ref) {
  return BubbleStyleNotifier(ref);
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
}

class BubbleStyleNotifier extends StateNotifier<BubbleStyleState> {
  BubbleStyleNotifier(this.ref) : super(_fromSettings(ref.read(settingsProvider))) {
    ref.listen<Map<String, dynamic>>(settingsProvider, (prev, next) {
      final nextState = _fromSettings(next);
      if (_differs(nextState)) {
        state = nextState;
      }
    });
  }

  final Ref ref;

  static BubbleStyleState _fromSettings(Map<String, dynamic> settings) {
    final radius = (settings['bubble_radius'] as num?)?.toDouble() ?? 16.0;
    final padding = (settings['bubble_padding'] as num?)?.toDouble() ?? 12.0;
    final useGradient = settings['bubble_use_gradient'] as bool? ?? true;
    final showTail = settings['bubble_show_tail'] as bool? ?? true;
    final outgoingRaw = settings['bubble_outgoing_color'];
    final incomingRaw = settings['bubble_incoming_color'];
    return BubbleStyleState(
      cornerRadius: radius,
      bubblePadding: padding,
      useGradient: useGradient,
      showTail: showTail,
      customOutgoingColor: outgoingRaw is int ? Color(outgoingRaw) : null,
      customIncomingColor: incomingRaw is int ? Color(incomingRaw) : null,
    );
  }

  bool _differs(BubbleStyleState next) {
    return next.cornerRadius != state.cornerRadius ||
        next.bubblePadding != state.bubblePadding ||
        next.useGradient != state.useGradient ||
        next.showTail != state.showTail ||
        next.customOutgoingColor?.value != state.customOutgoingColor?.value ||
        next.customIncomingColor?.value != state.customIncomingColor?.value;
  }

  void setCornerRadius(double radius) {
    ref.read(settingsProvider.notifier).setSetting('bubble_radius', radius.clamp(8.0, 24.0));
  }

  void setUseGradient(bool use) {
    ref.read(settingsProvider.notifier).setSetting('bubble_use_gradient', use);
  }

  void setCustomOutgoingColor(Color? color) {
    ref.read(settingsProvider.notifier).setSetting('bubble_outgoing_color', color?.value);
  }

  void setCustomIncomingColor(Color? color) {
    ref.read(settingsProvider.notifier).setSetting('bubble_incoming_color', color?.value);
  }

  void setShowTail(bool show) {
    ref.read(settingsProvider.notifier).setSetting('bubble_show_tail', show);
  }

  void setBubblePadding(double padding) {
    ref.read(settingsProvider.notifier).setSetting('bubble_padding', padding.clamp(4.0, 24.0));
  }

  void resetToDefaults() {
    ref.read(settingsProvider.notifier).setSetting('bubble_radius', 16.0);
    ref.read(settingsProvider.notifier).setSetting('bubble_padding', 12.0);
    ref.read(settingsProvider.notifier).setSetting('bubble_use_gradient', true);
    ref.read(settingsProvider.notifier).setSetting('bubble_show_tail', true);
    ref.read(settingsProvider.notifier).setSetting('bubble_outgoing_color', null);
    ref.read(settingsProvider.notifier).setSetting('bubble_incoming_color', null);
  }
}
