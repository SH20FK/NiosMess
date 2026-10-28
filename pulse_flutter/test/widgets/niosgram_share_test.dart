import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/post_card.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'first',
      userId: 1,
      username: 'one',
      displayName: 'One',
    ),
  );
  void switchAccount() => state = state.copyWith(
    session: const AuthSession(
      accessToken: 'second',
      userId: 2,
      username: 'two',
      displayName: 'Two',
    ),
  );
}

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults().copyWith(
    haptics: false,
    soundEffects: false,
  );
}

class _Chats extends ChatsNotifier {
  @override
  Future<List<ApiChatSummary>> build() async => const [
    ApiChatSummary(
      id: 42,
      chatType: 'direct',
      name: 'Fixture secret',
      unreadCount: 0,
      membersCount: 2,
      isSecret: true,
    ),
  ];
}

class _Messages extends ChatMessagesNotifier {
  _Messages() : super(42);
  String? sent;
  @override
  Future<List<ApiMessage>> build() async => [];
  @override
  Future<void> send(
    String content, {
    int? replyToId,
    String? uploadId,
    String msgType = 'text',
    bool requestAi = true,
    String? localId,
    String? e2eePlaintext,
    String? e2eeFileKey,
    VoidCallback? onLocalSaved,
  }) async {
    sent = content;
    onLocalSaved?.call();
  }
}

void main() {
  testWidgets(
    'sharing selects an existing secret chat and uses its message service',
    (tester) async {
      final messages = _Messages();
      final post = NgPost(
        id: 11,
        content: 'A public fixture',
        author: const ApiProfile(
          id: 3,
          username: 'author',
          displayName: 'Author',
          bio: '',
        ),
        createdAt: DateTime.utc(2026),
        likesCount: 0,
        dislikesCount: 0,
        commentsCount: 0,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            uiSettingsProvider.overrideWith(_Settings.new),
            chatsProvider.overrideWith(_Chats.new),
            chatMessagesProvider(42).overrideWith(() => messages),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(child: PostCard(post: post)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Share post'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send to a chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fixture secret'));
      await tester.pumpAndSettle();
      expect(messages.sent, niosgramPostShareUrl(11));
      expect(find.textContaining('Added to the chat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
