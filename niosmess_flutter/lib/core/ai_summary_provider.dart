import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;


/// Provider for AI Message Summary feature
final aiSummaryProvider = StateNotifierProvider<AiSummaryNotifier, AiSummaryState>((ref) {
  return AiSummaryNotifier();
});

class AiSummaryState {
  final bool isExpanded;
  final bool isLoading;
  final List<String> summaryPoints;
  final String? error;
  final DateTime? lastUpdated;
  final int messageCount;

  const AiSummaryState({
    this.isExpanded = false,
    this.isLoading = false,
    this.summaryPoints = const [],
    this.error,
    this.lastUpdated,
    this.messageCount = 50,
  });

  AiSummaryState copyWith({
    bool? isExpanded,
    bool? isLoading,
    List<String>? summaryPoints,
    String? error,
    DateTime? lastUpdated,
    int? messageCount,
  }) {
    return AiSummaryState(
      isExpanded: isExpanded ?? this.isExpanded,
      isLoading: isLoading ?? this.isLoading,
      summaryPoints: summaryPoints ?? this.summaryPoints,
      error: error ?? this.error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      messageCount: messageCount ?? this.messageCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'isExpanded': isExpanded,
    'summaryPoints': summaryPoints,
    'lastUpdated': lastUpdated?.millisecondsSinceEpoch,
    'messageCount': messageCount,
  };

  factory AiSummaryState.fromJson(Map<String, dynamic> json) {
    return AiSummaryState(
      isExpanded: json['isExpanded'] ?? false,
      summaryPoints: List<String>.from(json['summaryPoints'] ?? []),
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['lastUpdated']) 
          : null,
      messageCount: json['messageCount'] ?? 50,
    );
  }

  bool get hasSummary => summaryPoints.isNotEmpty;
  bool get isStale => lastUpdated == null || 
      DateTime.now().difference(lastUpdated!) > const Duration(minutes: 5);
}

class AiSummaryNotifier extends StateNotifier<AiSummaryState> {
  static const _prefsKeyPrefix = 'ai_summary_';

  AiSummaryNotifier() : super(const AiSummaryState());

  Future<void> _save(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefsKeyPrefix$chatId', jsonEncode(state.toJson()));
  }

  Future<void> loadForChat(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('$_prefsKeyPrefix$chatId');
    if (jsonString != null) {
      try {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        state = AiSummaryState.fromJson(data);
      } catch (_) {
        state = const AiSummaryState();
      }
    } else {
      state = const AiSummaryState();
    }
  }

  void toggleExpanded() {
    state = state.copyWith(isExpanded: !state.isExpanded);
  }

  void setExpanded(bool expanded) {
    state = state.copyWith(isExpanded: expanded);
  }

  void setMessageCount(int count) {
    state = state.copyWith(messageCount: count.clamp(10, 200));
  }

  /// Generate AI summary from messages
  /// In a real app, this would call an AI API
  /// For now, we simulate with smart extraction
  Future<void> generateSummary(String chatId, List<Map<String, dynamic>> messages) async {
    if (messages.isEmpty) return;
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // Simulate AI processing delay
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Extract key information (simulated AI logic)
      final points = _extractKeyPoints(messages.take(state.messageCount).toList());
      
      state = state.copyWith(
        isLoading: false,
        summaryPoints: points,
        lastUpdated: DateTime.now(),
        isExpanded: true,
      );
      
      await _save(chatId);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Не удалось создать сводку',
      );
    }
  }

  List<String> _extractKeyPoints(List<Map<String, dynamic>> messages) {
    final points = <String>[];
    final texts = messages
        .map((m) => m['text']?.toString() ?? '')
        .where((t) => t.isNotEmpty && !t.startsWith('POLL:') && !t.startsWith('LOCATION:'))
        .toList();

    if (texts.isEmpty) {
      return ['Нет текстовых сообщений для анализа'];
    }

    // Simulate AI extraction with smart heuristics
    final allText = texts.join(' ').toLowerCase();
    
    // Look for questions
    final questions = texts.where((t) => t.contains('?')).toList();
    if (questions.isNotEmpty) {
      final q = questions.first;
      points.add('❓ Вопрос: ${q.length > 50 ? '${q.substring(0, 50)}...' : q}');
    }

    // Look for decisions/answers
    final decisions = texts.where((t) => 
      t.toLowerCase().contains('да') || 
      t.toLowerCase().contains('нет') ||
      t.toLowerCase().contains('ок') ||
      t.toLowerCase().contains('хорошо')
    ).toList();
    if (decisions.isNotEmpty) {
      points.add('✅ Принято решение: ${decisions.length} ответов');
    }

    // Look for time references
    final timeRefs = texts.where((t) => 
      RegExp(r'\d{1,2}[:\.]\d{2}').hasMatch(t) ||
      t.toLowerCase().contains('завтра') ||
      t.toLowerCase().contains('сегодня') ||
      t.toLowerCase().contains('вечером')
    ).toList();
    if (timeRefs.isNotEmpty) {
      final t = timeRefs.first;
      points.add('🕐 Упоминание времени: ${t.length > 40 ? '${t.substring(0, 40)}...' : t}');
    }

    // Look for links
    final links = texts.where((t) => 
      t.contains('http://') || t.contains('https://') || t.contains('www.')
    ).toList();
    if (links.isNotEmpty) {
      points.add('🔗 Поделились ${links.length} ссылками');
    }

    // Look for important keywords
    final importantWords = ['срочно', 'важно', 'встреча', 'дедлайн', 'задача', 'проект'];
    for (final word in importantWords) {
      if (allText.contains(word)) {
        final msg = texts.firstWhere(
          (t) => t.toLowerCase().contains(word),
          orElse: () => '',
        );
        if (msg.isNotEmpty) {
          points.add('⚠️ Важно: ${msg.length > 45 ? '${msg.substring(0, 45)}...' : msg}');
          break;
        }
      }
    }

    // Add general summary if few points
    if (points.length < 2) {
      final senderCount = messages.map((m) => m['sender']).toSet().length;
      points.add('💬 ${messages.length} сообщений от $senderCount участников');
    }

    // Limit to 3 points
    return points.take(3).toList();
  }

  void clearSummary() {
    state = const AiSummaryState();
  }

  void dismissError() {
    state = state.copyWith(error: null);
  }
}

/// Widget for AI Summary button in chat
class AiSummaryButton extends StatelessWidget {
  final bool isExpanded;
  final bool isLoading;
  final VoidCallback onTap;
  final int messageCount;

  const AiSummaryButton({
    super.key,
    required this.isExpanded,
    required this.isLoading,
    required this.onTap,
    required this.messageCount,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isExpanded 
              ? Theme.of(context).colorScheme.primaryContainer 
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isExpanded 
                ? Theme.of(context).colorScheme.primary 
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            else
              Icon(
                isExpanded ? Icons.expand_less : Icons.auto_awesome,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            const SizedBox(width: 6),
            Text(
              isExpanded ? 'Скрыть' : 'AI Сводка',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            if (!isExpanded) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$messageCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget for displaying AI summary points
class AiSummaryCard extends StatelessWidget {
  final List<String> points;
  final DateTime? lastUpdated;

  const AiSummaryCard({
    super.key,
    required this.points,
    this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Ключевые моменты',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              if (lastUpdated != null) ...[
                const Spacer(),
                Text(
                  _formatTime(lastUpdated!),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ...points.map((point) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 6, right: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    point,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),

        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inHours < 1) return '${diff.inMinutes}м назад';
    if (diff.inDays < 1) return '${diff.inHours}ч назад';
    return '${diff.inDays}д назад';
  }
}
