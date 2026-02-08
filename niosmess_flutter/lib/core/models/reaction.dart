import 'package:flutter/material.dart';

class Reaction {
  final String emoji;
  final String username;
  final DateTime timestamp;

  const Reaction({
    required this.emoji,
    required this.username,
    required this.timestamp,
  });

  factory Reaction.fromJson(Map<String, dynamic> json) {
    return Reaction(
      emoji: json['emoji'] as String,
      username: json['username'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emoji': emoji,
      'username': username,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class ReactionGroup {
  final String emoji;
  final int count;
  final List<String> usernames;
  final bool isCurrentUser;

  const ReactionGroup({
    required this.emoji,
    required this.count,
    required this.usernames,
    this.isCurrentUser = false,
  });
}

// Доступные реакции
const List<String> availableReactions = ['👍', '❤️', '😂', '😮', '😢', '😡', '🎉', '🔥'];

// Цвета для реакций
Color getReactionColor(String emoji) {
  switch (emoji) {
    case '👍':
      return const Color(0xFF4CAF50);
    case '❤️':
    case '💖':
      return const Color(0xFFE91E63);
    case '😂':
      return const Color(0xFFFFC107);
    case '😮':
      return const Color(0xFF9C27B0);
    case '😢':
      return const Color(0xFF2196F3);
    case '😡':
      return const Color(0xFFF44336);
    case '🎉':
      return const Color(0xFFFF9800);
    case '🔥':
      return const Color(0xFFFF5722);
    default:
      return Colors.grey;
  }
}
