import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Provider for Focus Mode (Work/Fun chat filtering)
final focusModeProvider = StateNotifierProvider<FocusModeNotifier, FocusModeState>((ref) {
  return FocusModeNotifier();
});

enum FocusModeType { all, work, personal }

enum ChatCategory { work, fun, uncategorized }

class FocusModeState {
  final FocusModeType mode;
  final List<String> workChatIds;
  final List<String> personalChatIds;
  final bool autoCategorize;

  const FocusModeState({
    this.mode = FocusModeType.all,
    this.workChatIds = const [],
    this.personalChatIds = const [],
    this.autoCategorize = false,
  });

  FocusModeState copyWith({
    FocusModeType? mode,
    List<String>? workChatIds,
    List<String>? personalChatIds,
    bool? autoCategorize,
  }) {
    return FocusModeState(
      mode: mode ?? this.mode,
      workChatIds: workChatIds ?? this.workChatIds,
      personalChatIds: personalChatIds ?? this.personalChatIds,
      autoCategorize: autoCategorize ?? this.autoCategorize,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.index,
      'workChatIds': workChatIds,
      'personalChatIds': personalChatIds,
      'autoCategorize': autoCategorize,
    };
  }

  factory FocusModeState.fromJson(Map<String, dynamic> json) {
    return FocusModeState(
      mode: FocusModeType.values[json['mode'] ?? 0],
      workChatIds: List<String>.from(json['workChatIds'] ?? []),
      personalChatIds: List<String>.from(json['personalChatIds'] ?? []),
      autoCategorize: json['autoCategorize'] ?? false,
    );
  }

  bool isWorkChat(String chatId) => workChatIds.contains(chatId);
  bool isPersonalChat(String chatId) => personalChatIds.contains(chatId);

  bool shouldShowChat(String chatId) {
    if (mode == FocusModeType.all) return true;
    if (mode == FocusModeType.work) return workChatIds.contains(chatId);
    return personalChatIds.contains(chatId);
  }
}

class FocusModeNotifier extends StateNotifier<FocusModeState> {
  static const _prefsKey = 'focus_mode_settings_v2';

  FocusModeNotifier() : super(const FocusModeState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString != null) {
      try {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        state = FocusModeState.fromJson(data);
      } catch (e) {
        // Ignore parse errors
      }
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
  }

  void setMode(FocusModeType mode) {
    state = state.copyWith(mode: mode);
    _save();
  }

  void toggleMode() {
    final nextIndex = (state.mode.index + 1) % FocusModeType.values.length;
    final nextMode = FocusModeType.values[nextIndex];
    state = state.copyWith(mode: nextMode);
    _save();
  }

  void addWorkChat(String chatId) {
    if (!state.workChatIds.contains(chatId)) {
      final newList = [...state.workChatIds, chatId];
      state = state.copyWith(workChatIds: newList);
      _save();
    }
  }

  void removeWorkChat(String chatId) {
    final newList = state.workChatIds.where((id) => id != chatId).toList();
    state = state.copyWith(workChatIds: newList);
    _save();
  }

  void addPersonalChat(String chatId) {
    if (!state.personalChatIds.contains(chatId)) {
      final newList = [...state.personalChatIds, chatId];
      state = state.copyWith(personalChatIds: newList);
      _save();
    }
  }

  void removePersonalChat(String chatId) {
    final newList = state.personalChatIds.where((id) => id != chatId).toList();
    state = state.copyWith(personalChatIds: newList);
    _save();
  }

  void setAutoCategorize(bool auto) {
    state = state.copyWith(autoCategorize: auto);
    _save();
  }

  void clearAllCategories() {
    state = state.copyWith(workChatIds: [], personalChatIds: []);
    _save();
  }

  ChatCategory getChatCategory(String chatId) {
    if (state.workChatIds.contains(chatId)) return ChatCategory.work;
    if (state.personalChatIds.contains(chatId)) return ChatCategory.fun;
    return ChatCategory.uncategorized;
  }

  void setChatCategory(String chatId, ChatCategory category) {
    var newWorkIds = state.workChatIds.where((id) => id != chatId).toList();
    var newPersonalIds = state.personalChatIds.where((id) => id != chatId).toList();

    if (category == ChatCategory.work) {
      newWorkIds = [...newWorkIds, chatId];
    } else if (category == ChatCategory.fun) {
      newPersonalIds = [...newPersonalIds, chatId];
    }

    state = state.copyWith(workChatIds: newWorkIds, personalChatIds: newPersonalIds);
    _save();
  }
}
