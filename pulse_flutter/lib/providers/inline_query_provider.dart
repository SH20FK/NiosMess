import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/inline_query_model.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/bot_repository.dart';

@immutable
class InlineQueryState {
  const InlineQueryState({
    this.isActive = false,
    this.chatId,
    this.botUsername = '',
    this.query = '',
    this.inlineQueryId,
    this.results = const <InlineQueryResult>[],
    this.isLoading = false,
    this.error,
  });

  final bool isActive;
  final int? chatId;
  final String botUsername;
  final String query;
  final String? inlineQueryId;
  final List<InlineQueryResult> results;
  final bool isLoading;
  final String? error;

  InlineQueryState copyWith({
    bool? isActive,
    int? chatId,
    String? botUsername,
    String? query,
    String? inlineQueryId,
    List<InlineQueryResult>? results,
    bool? isLoading,
    String? error,
  }) {
    return InlineQueryState(
      isActive: isActive ?? this.isActive,
      chatId: chatId ?? this.chatId,
      botUsername: botUsername ?? this.botUsername,
      query: query ?? this.query,
      inlineQueryId: inlineQueryId ?? this.inlineQueryId,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InlineQueryState &&
          runtimeType == other.runtimeType &&
          isActive == other.isActive &&
          chatId == other.chatId &&
          botUsername == other.botUsername &&
          query == other.query &&
          inlineQueryId == other.inlineQueryId &&
          isLoading == other.isLoading &&
          error == other.error &&
          listEquals(results, other.results);

  @override
  int get hashCode => Object.hash(
        isActive,
        chatId,
        botUsername,
        query,
        inlineQueryId,
        isLoading,
        error,
        Object.hashAll(results),
      );
}

class InlineQueryNotifier extends Notifier<InlineQueryState> {
  static final RegExp inlineRegex =
      RegExp(r'^@([a-zA-Z0-9_]{3,32})\s+(.*)$', dotAll: true);

  Timer? _debounceTimer;
  StreamSubscription<Map<String, dynamic>>? _pushSubscription;
  bool _disposed = false;

  @override
  InlineQueryState build() {
    _disposed = false;
    _pushSubscription = ref
        .read(webSocketClientProvider)
        .pushStream
        .listen(_handlePush);

    ref.onDispose(() {
      _disposed = true;
      _debounceTimer?.cancel();
      _pushSubscription?.cancel();
    });

    return const InlineQueryState();
  }

  void onInputChanged({required int? chatId, required String text}) {
    final Match? match = inlineRegex.firstMatch(text);
    if (match == null) {
      if (state.isActive) {
        clear();
      }
      return;
    }

    final String botUsername = match.group(1)!;
    final String query = (match.group(2) ?? '').trim();

    if (!state.isActive ||
        state.botUsername != botUsername ||
        state.query != query ||
        state.chatId != chatId) {
      state = state.copyWith(
        isActive: true,
        chatId: chatId,
        botUsername: botUsername,
        query: query,
        isLoading: true,
        error: null,
      );

      _scheduleQuery(chatId: chatId, botUsername: botUsername, query: query);
    }
  }

  void _scheduleQuery({
    required int? chatId,
    required String botUsername,
    required String query,
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_disposed || !state.isActive) return;
      _executeQuery(chatId: chatId, botUsername: botUsername, query: query);
    });
  }

  Future<void> _executeQuery({
    required int? chatId,
    required String botUsername,
    required String query,
  }) async {
    try {
      final InlineQueryResponse response = await ref
          .read(botRepositoryProvider)
          .sendInlineQuery(
            chatId: chatId,
            botUsername: botUsername,
            query: query,
          );

      if (_disposed || !state.isActive) return;

      if (response.results.isNotEmpty) {
        state = state.copyWith(
          inlineQueryId: response.inlineQueryId,
          results: response.results,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          inlineQueryId: response.inlineQueryId,
        );
      }
    } catch (e) {
      if (_disposed || !state.isActive) return;
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void _handlePush(Map<String, dynamic> event) {
    if (_disposed) return;
    if (event['action'] != 'inline_query_results') return;

    final dynamic rawPayload = event['payload'];
    if (rawPayload is! Map) return;
    final Map<String, dynamic> payload =
        rawPayload.map((dynamic k, dynamic v) => MapEntry(k.toString(), v));

    final String? pushQueryId = payload['inline_query_id']?.toString();
    final int? pushChatId = int.tryParse(payload['chat_id']?.toString() ?? '');

    final bool queryMatches;
    if (state.inlineQueryId != null && state.inlineQueryId!.isNotEmpty) {
      queryMatches = pushQueryId == state.inlineQueryId;
    } else {
      queryMatches = pushChatId != null && pushChatId == state.chatId;
    }

    if (state.isActive && queryMatches) {
      final dynamic rawResults = payload['results'];
      if (rawResults is List) {
        final List<InlineQueryResult> results = rawResults
            .whereType<Map>()
            .map((dynamic m) => InlineQueryResult.fromJson(
                  (m as Map).map(
                      (dynamic k, dynamic v) => MapEntry(k.toString(), v)),
                ))
            .toList(growable: false);

        state = state.copyWith(
          results: results,
          isLoading: false,
        );
      }
    }
  }

  void clear() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    state = const InlineQueryState();
  }
}

final NotifierProvider<InlineQueryNotifier, InlineQueryState>
    inlineQueryProvider =
    NotifierProvider<InlineQueryNotifier, InlineQueryState>(
  InlineQueryNotifier.new,
);
