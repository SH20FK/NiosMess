import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for Ghost Reading Mode (read without sending read receipts)
final ghostModeProvider = StateNotifierProvider<GhostModeNotifier, GhostModeState>((ref) {
  return GhostModeNotifier();
});

class GhostModeState {
  final bool isActive;
  final String? peekChatId;
  final String? peekChatName;
  final List<String> readMessageIds;
  final DateTime? peekStartTime;
  final double glowIntensity;
  final bool isGlowing;

  const GhostModeState({
    this.isActive = false,
    this.peekChatId,
    this.peekChatName,
    this.readMessageIds = const [],
    this.peekStartTime,
    this.glowIntensity = 0.0,
    this.isGlowing = false,
  });

  GhostModeState copyWith({
    bool? isActive,
    String? peekChatId,
    String? peekChatName,
    List<String>? readMessageIds,
    DateTime? peekStartTime,
    double? glowIntensity,
    bool? isGlowing,
  }) {
    return GhostModeState(
      isActive: isActive ?? this.isActive,
      peekChatId: peekChatId ?? this.peekChatId,
      peekChatName: peekChatName ?? this.peekChatName,
      readMessageIds: readMessageIds ?? this.readMessageIds,
      peekStartTime: peekStartTime ?? this.peekStartTime,
      glowIntensity: glowIntensity ?? this.glowIntensity,
      isGlowing: isGlowing ?? this.isGlowing,
    );
  }


  Map<String, dynamic> toJson() => {
    'isActive': isActive,
    'peekChatId': peekChatId,
    'peekChatName': peekChatName,
    'readMessageIds': readMessageIds,
    'peekStartTime': peekStartTime?.millisecondsSinceEpoch,
  };

  factory GhostModeState.fromJson(Map<String, dynamic> json) {
    return GhostModeState(
      isActive: json['isActive'] ?? false,
      peekChatId: json['peekChatId'],
      peekChatName: json['peekChatName'],
      readMessageIds: List<String>.from(json['readMessageIds'] ?? []),
      peekStartTime: json['peekStartTime'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['peekStartTime']) 
          : null,
      glowIntensity: (json['glowIntensity'] as num?)?.toDouble() ?? 0.0,
      isGlowing: json['isGlowing'] ?? false,
    );
  }

}

class GhostModeNotifier extends StateNotifier<GhostModeState> {
  static const _prefsKey = 'ghost_mode_settings';

  GhostModeNotifier() : super(const GhostModeState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString != null) {
      try {
        final data = <String, dynamic>{};
        final pairs = jsonString.replaceAll('{', '').replaceAll('}', '').split(',');
        for (final pair in pairs) {
          if (pair.contains(':')) {
            final parts = pair.split(':');
            final key = parts[0].trim();
            final value = parts[1].trim();
            if (key == 'isActive') {
              data[key] = value == 'true';
            } else if (key == 'peekStartTime' && value != 'null') {
              data[key] = int.tryParse(value);
            } else if (key != 'readMessageIds') {
              data[key] = value == 'null' ? null : value;
            }
          }
        }
        state = GhostModeState.fromJson(data);
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, state.toJson().toString());
  }

  void startGhostPeek(String chatId, String chatName) {
    state = GhostModeState(
      isActive: true,
      peekChatId: chatId,
      peekChatName: chatName,
      readMessageIds: [],
      peekStartTime: DateTime.now(),
    );
    _save();
  }

  void endGhostPeek() {
    state = const GhostModeState();
    _save();
  }

  void markMessageRead(String messageId) {
    if (!state.readMessageIds.contains(messageId)) {
      state = state.copyWith(
        readMessageIds: [...state.readMessageIds, messageId],
      );
      _save();
    }
  }

  void clearReadMessages() {
    state = state.copyWith(readMessageIds: []);
    _save();
  }

  bool isMessageReadInGhostMode(String messageId) {
    return state.readMessageIds.contains(messageId);
  }

  /// Activate ghost mode without peeking a specific chat
  void activate() {
    state = state.copyWith(isActive: true, isGlowing: true, glowIntensity: 1.0);
    _startGlowAnimation();
    _save();
  }

  /// Deactivate ghost mode
  void deactivate() {
    state = state.copyWith(isActive: false, isGlowing: false, glowIntensity: 0.0);
    _save();
  }

  /// Start glow animation
  void _startGlowAnimation() {
    // Glow intensity will be animated by the UI using AnimationController
    // This just sets the initial state
    state = state.copyWith(isGlowing: true, glowIntensity: 1.0);
  }

  /// Update glow intensity (called by animation)
  void updateGlowIntensity(double intensity) {
    if (state.isGlowing) {
      state = state.copyWith(glowIntensity: intensity.clamp(0.0, 1.0));
    }
  }

  /// Toggle glow effect
  void toggleGlow() {
    state = state.copyWith(isGlowing: !state.isGlowing);
    _save();
  }


  Duration? get peekDuration {

    if (state.peekStartTime == null) return null;
    return DateTime.now().difference(state.peekStartTime!);
  }

  String get peekDurationText {
    final duration = peekDuration;
    if (duration == null) return '';
    if (duration.inMinutes < 1) return '${duration.inSeconds}с';
    if (duration.inHours < 1) return '${duration.inMinutes}м';
    return '${duration.inHours}ч ${duration.inMinutes % 60}м';
  }
}

/// Widget to wrap around chat screen to enable ghost mode
class GhostModeOverlay extends StatelessWidget {
  final Widget child;
  final VoidCallback onClose;

  const GhostModeOverlay({
    super.key,
    required this.child,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.visibility_off,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Призрачный режим',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Чтение без отметки "прочитано"',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
