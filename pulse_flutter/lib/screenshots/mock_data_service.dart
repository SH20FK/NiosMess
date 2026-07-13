import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';

class MockDataService {
  MockDataService._();

  static final AuthSession session = AuthSession(
    accessToken: 'mock_token_dev_mode',
    userId: 1,
    username: 'developer',
    displayName: 'Developer',
  );

  static final ApiProfile profile = ApiProfile(
    id: 1,
    username: 'developer',
    displayName: 'Developer',
    bio: 'Mock data mode',
    twoFaEnabled: false,
    spamBlock: false,
  );

  static final List<ApiChatSummary> chats = [
    ApiChatSummary(
      id: 101,
      chatType: 'private',
      name: 'Alina',
      unreadCount: 2,
      membersCount: 2,
      username: 'alina_dev',
      lastMessage: _lastMsg(101, 'Alina', 'Привет! Как дела? 😊'),
      isSecret: false,
    ),
    ApiChatSummary(
      id: 102,
      chatType: 'group',
      name: 'Dev Chat',
      unreadCount: 5,
      membersCount: 12,
      description: 'Обсуждение разработки',
      lastMessage: _lastMsg(102, 'Mike', 'Mike: Сделал рефакторинг'),
      isSecret: false,
    ),
    ApiChatSummary(
      id: 103,
      chatType: 'channel',
      name: 'Tech News',
      unreadCount: 0,
      membersCount: 340,
      username: 'tech_news',
      description: 'Новости технологий',
      lastMessage: _lastMsg(103, 'Tech News', 'Flutter 4.0 вышел!'),
      isSecret: false,
    ),
    ApiChatSummary(
      id: 104,
      chatType: 'private',
      name: 'Marina',
      unreadCount: 0,
      membersCount: 2,
      username: 'marina_design',
      lastMessage: _lastMsg(104, 'Marina', 'Голосовое сообщение'),
      isSecret: false,
    ),
    ApiChatSummary(
      id: 105,
      chatType: 'private',
      name: 'Mike',
      unreadCount: 1,
      membersCount: 2,
      username: 'mike_codes',
      lastMessage: _lastMsg(105, 'Mike', 'Го завтра встретимся?'),
      isSecret: false,
    ),
    ApiChatSummary(
      id: 106,
      chatType: 'private',
      name: 'Dmitry',
      unreadCount: 0,
      membersCount: 2,
      username: 'dmitry_backend',
      lastMessage: _lastMsg(106, 'Dmitry', 'Ок, я за'),
      isSecret: false,
    ),
  ];

  static final Map<int, List<ApiMessage>> messages = {
    101: [
      _msg(1, 101, 2, 'Alina', 'alina_dev', 'Привет! Как дела?', false),
      _msg(2, 101, 1, 'Developer', 'developer', 'Привет! Всё отлично, у тебя как?', true),
      _msg(3, 101, 1, 'Developer', 'developer', 'Тоже норм! Гулял сегодня в парке, погода супер', true),
      _msg(4, 101, 2, 'Alina', 'alina_dev', 'Класс! Я тоже хочу выбраться на выходных', false),
      _msg(5, 101, 2, 'Alina', 'alina_dev', 'Давай сходим куда-нибудь? 🎬', false, isRead: false),
      _msg(6, 101, 1, 'Developer', 'developer', 'Отличная идея! Давай', true),
    ],
    102: [
      _msg(7, 102, 3, 'Mike', 'mike_codes', 'Сделал рефакторинг модуля авторизации', false),
      _msg(8, 102, 2, 'Alina', 'alina_dev', 'Отлично, Mike! Я посмотрю код', false),
      _msg(9, 102, 4, 'Dmitry', 'dmitry_backend', 'Ребят, кто завтра деплой делает?', false),
      _msg(10, 102, 3, 'Mike', 'mike_codes', 'Я могу, если никто не против', false),
      _msg(11, 102, 2, 'Alina', 'alina_dev', 'Давай, я потом проверю', false),
    ],
    103: [
      _msg(12, 103, 5, 'Tech News', 'tech_news', 'Flutter 4.0 вышел! Новая версия с Impeller на iOS, улучшенным веб-рендерингом и новыми виджетами.', false),
      _msg(13, 103, 5, 'Tech News', 'tech_news', 'Dart 4.0 бета — Macros, pattern matching v2 и значительные улучшения производительности.', false),
    ],
    104: [
      _msg(14, 104, 5, 'Marina', 'marina_design', 'Привет! Как твой проект?', false),
      _msg(15, 104, 1, 'Developer', 'developer', 'Привет! Всё хорошо, скоро релиз', true),
    ],
    105: [
      _msg(16, 105, 3, 'Mike', 'mike_codes', 'Привет! Есть минутка?', false),
      _msg(17, 105, 1, 'Developer', 'developer', 'Да, что случилось?', true),
      _msg(18, 105, 3, 'Mike', 'mike_codes', 'Го завтра встретимся? Обсудим новый функционал', false, isRead: false),
    ],
    106: [
      _msg(19, 106, 4, 'Dmitry', 'dmitry_backend', 'Пулл-реквест готов, посмотришь?', false),
      _msg(20, 106, 1, 'Developer', 'developer', 'Да, гляну сегодня вечером', true),
      _msg(21, 106, 4, 'Dmitry', 'dmitry_backend', 'Ок, я за', false),
    ],
  };

  static List<ApiChatSummary> chatsForUserId(int _) => chats;

  static List<ApiMessage> messagesForChat(int chatId) =>
      messages[chatId] ?? const <ApiMessage>[];

  static ApiMessage _lastMsg(int chatId, String sender, String content) {
    return ApiMessage(
      id: chatId * 100,
      chatId: chatId,
      senderId: chatId,
      senderUsername: sender.toLowerCase().replaceAll(' ', '_'),
      senderDisplayName: sender,
      senderBadges: const [],
      content: content,
      msgType: 'text',
      replyToId: null,
      mediaUrl: null,
      mediaType: null,
      mediaName: null,
      mediaSize: null,
      mediaDuration: null,
      commentsCount: 0,
      reactions: const {},
      sentAt: DateTime.now().subtract(const Duration(minutes: 5)),
      editedAt: null,
      isDeleted: false,
      senderAvatarUrl: null,
      isSending: false,
      isFailed: false,
      isE2ee: false,
      isRead: true,
    );
  }

  static ApiMessage _msg(
    int id,
    int chatId,
    int senderId,
    String displayName,
    String username,
    String content,
    bool isOutgoing, {
    bool isRead = true,
  }) {
    return ApiMessage(
      id: id,
      chatId: chatId,
      senderId: isOutgoing ? 1 : senderId,
      senderUsername: isOutgoing ? 'developer' : username,
      senderDisplayName: isOutgoing ? 'Developer' : displayName,
      senderBadges: const [],
      content: content,
      msgType: 'text',
      replyToId: null,
      mediaUrl: null,
      mediaType: null,
      mediaName: null,
      mediaSize: null,
      mediaDuration: null,
      commentsCount: 0,
      reactions: const {},
      sentAt: DateTime.now().subtract(Duration(minutes: 60 - id)),
      editedAt: null,
      isDeleted: false,
      senderAvatarUrl: null,
      isSending: false,
      isFailed: false,
      isE2ee: false,
      isRead: isRead,
    );
  }
}
