import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';

final Provider<List<ApiChatSummary>> callableChatsProvider =
    Provider<List<ApiChatSummary>>((Ref ref) {
      final List<ApiChatSummary> chats =
          ref.watch(chatsProvider).value ?? const <ApiChatSummary>[];
      return chats;
    });
