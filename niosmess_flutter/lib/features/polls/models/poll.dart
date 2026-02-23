import 'package:flutter/foundation.dart';

/// Улучшенная модель опроса
@immutable
class Poll {
  final String id;
  final String question;
  final List<PollOption> options;
  final PollType type;
  final bool isAnonymous;
  final bool allowMultipleAnswers;
  final int? maxChoices; // Для множественного выбора
  final DateTime createdAt;
  final DateTime? closesAt; // Автоматическое закрытие
  final String creatorId;
  final PollStatus status;
  final int totalVotes;
  final List<String> votedUsers;

  const Poll({
    required this.id,
    required this.question,
    required this.options,
    required this.type,
    this.isAnonymous = false,
    this.allowMultipleAnswers = false,
    this.maxChoices,
    required this.createdAt,
    this.closesAt,
    required this.creatorId,
    this.status = PollStatus.active,
    this.totalVotes = 0,
    this.votedUsers = const [],
  });

  /// Проверка, закрыт ли опрос
  bool get isClosed =>
      status == PollStatus.closed ||
      (closesAt != null && DateTime.now().isAfter(closesAt!));

  /// Проверка, проголосовал ли пользователь
  bool hasUserVoted(String userId) => votedUsers.contains(userId);

  /// Оставшееся время до закрытия
  Duration? get timeRemaining {
    if (closesAt == null) return null;
    final diff = closesAt!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  factory Poll.fromJson(Map<String, dynamic> json) {
    return Poll(
      id: json['id'] as String,
      question: json['question'] as String,
      options: (json['options'] as List<dynamic>)
          .map((e) => PollOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      type: PollType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PollType.regular,
      ),
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      allowMultipleAnswers: json['allow_multiple_answers'] as bool? ?? false,
      maxChoices: json['max_choices'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      closesAt: json['closes_at'] != null
          ? DateTime.parse(json['closes_at'] as String)
          : null,
      creatorId: json['creator_id'] as String,
      status: PollStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PollStatus.active,
      ),
      totalVotes: json['total_votes'] as int? ?? 0,
      votedUsers: (json['voted_users'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options.map((e) => e.toJson()).toList(),
      'type': type.name,
      'is_anonymous': isAnonymous,
      'allow_multiple_answers': allowMultipleAnswers,
      'max_choices': maxChoices,
      'created_at': createdAt.toIso8601String(),
      'closes_at': closesAt?.toIso8601String(),
      'creator_id': creatorId,
      'status': status.name,
      'total_votes': totalVotes,
      'voted_users': votedUsers,
    };
  }

  Poll copyWith({
    String? id,
    String? question,
    List<PollOption>? options,
    PollType? type,
    bool? isAnonymous,
    bool? allowMultipleAnswers,
    int? maxChoices,
    DateTime? createdAt,
    DateTime? closesAt,
    String? creatorId,
    PollStatus? status,
    int? totalVotes,
    List<String>? votedUsers,
  }) {
    return Poll(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      type: type ?? this.type,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      allowMultipleAnswers: allowMultipleAnswers ?? this.allowMultipleAnswers,
      maxChoices: maxChoices ?? this.maxChoices,
      createdAt: createdAt ?? this.createdAt,
      closesAt: closesAt ?? this.closesAt,
      creatorId: creatorId ?? this.creatorId,
      status: status ?? this.status,
      totalVotes: totalVotes ?? this.totalVotes,
      votedUsers: votedUsers ?? this.votedUsers,
    );
  }
}

/// Вариант ответа в опросе
@immutable
class PollOption {
  final String id;
  final String text;
  final int votes;
  final List<String> voters; // Для неанонимных опросов
  final bool? isCorrect; // Для квиз-режима

  const PollOption({
    required this.id,
    required this.text,
    this.votes = 0,
    this.voters = const [],
    this.isCorrect,
  });

  /// Процент голосов
  double getPercentage(int totalVotes) {
    if (totalVotes == 0) return 0.0;
    return (votes / totalVotes) * 100;
  }

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id'] as String,
      text: json['text'] as String,
      votes: json['votes'] as int? ?? 0,
      voters: (json['voters'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isCorrect: json['is_correct'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'votes': votes,
      'voters': voters,
      'is_correct': isCorrect,
    };
  }

  PollOption copyWith({
    String? id,
    String? text,
    int? votes,
    List<String>? voters,
    bool? isCorrect,
  }) {
    return PollOption(
      id: id ?? this.id,
      text: text ?? this.text,
      votes: votes ?? this.votes,
      voters: voters ?? this.voters,
      isCorrect: isCorrect ?? this.isCorrect,
    );
  }
}

/// Тип опроса
enum PollType {
  regular, // Обычный опрос
  quiz, // Квиз с правильными ответами
  anonymous, // Анонимный
}

/// Статус опроса
enum PollStatus {
  active, // Активен
  closed, // Закрыт
  draft, // Черновик
}

/// Результат голосования пользователя
@immutable
class PollVote {
  final String pollId;
  final String userId;
  final List<String> optionIds;
  final DateTime votedAt;

  const PollVote({
    required this.pollId,
    required this.userId,
    required this.optionIds,
    required this.votedAt,
  });

  factory PollVote.fromJson(Map<String, dynamic> json) {
    return PollVote(
      pollId: json['poll_id'] as String,
      userId: json['user_id'] as String,
      optionIds: (json['option_ids'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      votedAt: DateTime.parse(json['voted_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'poll_id': pollId,
      'user_id': userId,
      'option_ids': optionIds,
      'voted_at': votedAt.toIso8601String(),
    };
  }
}

/// Аналитика опроса
@immutable
class PollAnalytics {
  final String pollId;
  final int totalVotes;
  final int uniqueVoters;
  final Map<String, int> votesPerOption;
  final Map<String, double> percentagePerOption;
  final String? winningOptionId;
  final DateTime? lastVoteAt;

  const PollAnalytics({
    required this.pollId,
    required this.totalVotes,
    required this.uniqueVoters,
    required this.votesPerOption,
    required this.percentagePerOption,
    this.winningOptionId,
    this.lastVoteAt,
  });

  factory PollAnalytics.fromPoll(Poll poll) {
    final votesMap = <String, int>{};
    final percentageMap = <String, double>{};
    String? winningId;
    int maxVotes = 0;

    for (final option in poll.options) {
      votesMap[option.id] = option.votes;
      percentageMap[option.id] = option.getPercentage(poll.totalVotes);

      if (option.votes > maxVotes) {
        maxVotes = option.votes;
        winningId = option.id;
      }
    }

    return PollAnalytics(
      pollId: poll.id,
      totalVotes: poll.totalVotes,
      uniqueVoters: poll.votedUsers.length,
      votesPerOption: votesMap,
      percentagePerOption: percentageMap,
      winningOptionId: winningId,
      lastVoteAt: null, // TODO: Добавить из БД
    );
  }
}
