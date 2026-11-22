// Visual dump harness for the inbox (chat list) screen.
//
// This file is NOT a behavioural test: it renders `ChatListScreen` with a rich
// fixture set and writes real PNGs so the inbox can be reviewed visually
// (typography, spacing, badges, dark/light, phone/tablet).
//
// Usage:
//   flutter test test/visual/inbox_screenshot_dump_test.dart
//
// Output defaults to `C:/Hermes/cache/scratch/inbox_shots` on Windows and can
// be redirected with `NIOS_INBOX_SHOTS_DIR`. On non-Windows hosts the test is
// skipped unless that variable is set, so CI never writes stray files.
//
// Real fonts matter: `flutter_test` replaces every unresolved family with
// Ahem (solid squares). The families below are the ones the app's own
// typography (AppFonts) asks for, loaded straight from the bundle.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/chat_productivity.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/chat_muted_provider.dart';
import 'package:pulse_flutter/providers/chat_productivity_provider.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/providers/typing_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/screens/chat_list_screen.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';
import 'package:pulse_flutter/widgets/app_bottom_nav.dart';
import 'package:pulse_flutter/widgets/chat/inbox_compose_button.dart';
import 'package:pulse_flutter/widgets/chat_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Output
// ---------------------------------------------------------------------------

const String _kDefaultOutput = 'C:/Hermes/cache/scratch/inbox_shots';

String get _outputDir =>
    Platform.environment['NIOS_INBOX_SHOTS_DIR'] ?? _kDefaultOutput;

bool get _enabled =>
    Platform.environment['NIOS_INBOX_SHOTS_DIR'] != null || Platform.isWindows;

// ---------------------------------------------------------------------------
// Fonts
// ---------------------------------------------------------------------------

/// [family, asset] pairs the app typography actually references.
const Map<String, String> _bundleFonts = <String, String>{
  'Onest': 'assets/fonts/onest/Onest-Variable.ttf',
  'GolosText': 'assets/fonts/golos_text/GolosText-Variable.ttf',
  'BricolageGrotesque':
      'assets/fonts/bricolage_grotesque/BricolageGrotesque-Variable.ttf',
  'PlusJakartaSans':
      'assets/fonts/plus_jakarta_sans/PlusJakartaSans-Variable.ttf',
  'Inter': 'assets/fonts/inter/Inter-Variable.ttf',
  'NotoColorEmoji': 'assets/fonts/noto_color_emoji/NotoColorEmoji.ttf',
};

/// Icon glyphs are a font too: without it every `Icon` renders as tofu.
Future<void> _loadIconFont() async {
  for (final String asset in <String>[
    'fonts/MaterialIcons-Regular.otf',
    'fonts/materialicons-regular.otf',
  ]) {
    try {
      final ByteData data = await rootBundle.load(asset);
      await (FontLoader('MaterialIcons')..addFont(Future.value(data))).load();
      return;
    } catch (_) {
      // try next candidate
    }
  }
  // Fall back to the Flutter SDK cache (flutter_tester lives in
  // <flutter>/bin/cache/artifacts/engine/...).
  Directory? dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8 && dir != null; i++) {
    final File candidate = File(
      '${dir.path}/material_fonts/materialicons-regular.otf',
    );
    if (candidate.existsSync()) {
      final Uint8List bytes = await candidate.readAsBytes();
      await (FontLoader('MaterialIcons')
            ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes))))
          .load();
      return;
    }
    dir = dir.parent;
  }
  // ignore: avoid_print
  print('[inbox-shot] WARNING: MaterialIcons font not found, icons may be tofu');
}

Future<void> _loadFonts() async {
  for (final MapEntry<String, String> entry in _bundleFonts.entries) {
    try {
      await (FontLoader(entry.key)..addFont(rootBundle.load(entry.value))).load();
    } catch (error) {
      // ignore: avoid_print
      print('[inbox-shot] WARNING: font ${entry.key} failed: $error');
    }
  }
  await _loadIconFont();
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const int _kMyUserId = 42;
final DateTime _now = DateTime.now();

ApiMessage _msg({
  required int id,
  required int chatId,
  int senderId = 2,
  String senderName = 'Ирина Соколова',
  String senderUsername = 'irina',
  String content = '',
  String msgType = 'text',
  String? mediaType,
  String? mediaUrl,
  String? mediaName,
  bool isRead = true,
  bool isSending = false,
  bool isE2ee = false,
  int minutesAgo = 5,
}) {
  final Map<String, dynamic> json = <String, dynamic>{
    'id': id,
    'chat_id': chatId,
    'sender_id': senderId,
    'sender_username': senderUsername,
    'sender_display_name': senderName,
    'content': content,
    'msg_type': msgType,
    'sent_at': _now
        .subtract(Duration(minutes: minutesAgo))
        .toUtc()
        .toIso8601String(),
    'is_read': isRead,
    'is_sending': isSending,
    if (isE2ee) 'is_e2ee': true,
    if (isE2ee) 'is_decrypted': true,
  };
  if (mediaType != null) json['media_type'] = mediaType;
  if (mediaUrl != null) json['media_url'] = mediaUrl;
  if (mediaName != null) json['media_name'] = mediaName;
  return ApiMessage.fromJson(json);
}

final List<ApiChatSummary> _chats = <ApiChatSummary>[
  // 1. Saved messages (hoisted to the very top by the screen).
  ApiChatSummary(
    id: 1,
    chatType: 'direct',
    name: 'Saved',
    unreadCount: 0,
    membersCount: 1,
    isSaved: true,
    lastMessage: _msg(
      id: 101,
      chatId: 1,
      senderId: _kMyUserId,
      senderName: 'Александр',
      content: 'Заметки по релизу 3.130 и пароли от стенда',
      minutesAgo: 26,
    ),
  ),
  // 2. Direct + online + 1 unread.
  ApiChatSummary(
    id: 2,
    chatType: 'direct',
    name: 'Ирина Соколова',
    unreadCount: 1,
    membersCount: 2,
    isOnline: true,
    lastMessage: _msg(
      id: 102,
      chatId: 2,
      content: 'До встречи вечером! Захвачу тот самый чай 🌿',
      minutesAgo: 2,
    ),
  ),
  // 3. Group + 12 unread.
  ApiChatSummary(
    id: 3,
    chatType: 'group',
    name: 'Наша группа',
    unreadCount: 12,
    membersCount: 12,
    lastMessage: _msg(
      id: 103,
      chatId: 3,
      senderId: 7,
      senderName: 'Марат',
      content: 'Обсуждаем планы на выходные, кто за город?',
      minutesAgo: 9,
    ),
  ),
  // 4. Draft in a group.
  ApiChatSummary(
    id: 4,
    chatType: 'group',
    name: 'Дизайн-ревью',
    unreadCount: 3,
    membersCount: 8,
    lastMessage: _msg(
      id: 104,
      chatId: 4,
      senderId: 9,
      senderName: 'Лена',
      content: 'Скинула новую сетку инбокса в Figma',
      minutesAgo: 21,
    ),
  ),
  // 5. Typing indicator.
  ApiChatSummary(
    id: 5,
    chatType: 'direct',
    name: 'Сухарик',
    unreadCount: 0,
    membersCount: 2,
    lastMessage: _msg(
      id: 105,
      chatId: 5,
      content: 'Хорошо, договорились',
      minutesAgo: 44,
    ),
  ),
  // 6. Secret chat.
  ApiChatSummary(
    id: 6,
    chatType: 'direct',
    name: 'Секретный диалог',
    unreadCount: 0,
    membersCount: 2,
    isSecret: true,
    lastMessage: _msg(
      id: 106,
      chatId: 6,
      content: 'ciphertext-never-shown',
      isE2ee: true,
      minutesAgo: 63,
    ),
  ),
  // 7. Channel + 120 unread + muted.
  ApiChatSummary(
    id: 7,
    chatType: 'channel',
    name: 'NiosGram News',
    unreadCount: 120,
    membersCount: 18420,
    description: 'Официальный канал новостей NiosMess',
    lastMessage: _msg(
      id: 107,
      chatId: 7,
      senderId: 100,
      senderName: 'NiosMess',
      content:
          'Вышел релиз 3.130: ускоренный инбокс, новые реакции и полноценные '
          'папки чатов для всех платформ',
      minutesAgo: 95,
    ),
  ),
  // 8. Unread 7, muted + badge.
  ApiChatSummary(
    id: 8,
    chatType: 'direct',
    name: 'Тимур',
    unreadCount: 7,
    membersCount: 2,
    partnerBadges: const <ApiBadge>[
      ApiBadge(id: 1, name: 'Verified', icon: 'verified', color: 'primary'),
    ],
    lastMessage: _msg(
      id: 108,
      chatId: 8,
      senderId: 12,
      senderName: 'Тимур',
      content: 'Созвон в 15:00? Нужно сверить API',
      minutesAgo: 180,
    ),
  ),
  // 9. My own last message, already read (double check).
  ApiChatSummary(
    id: 9,
    chatType: 'direct',
    name: 'Мария Ковалёва',
    unreadCount: 0,
    membersCount: 2,
    lastMessage: _msg(
      id: 109,
      chatId: 9,
      senderId: _kMyUserId,
      senderName: 'Александр',
      content: 'Отправил финальные макеты, посмотри пожалуйста',
      minutesAgo: 240,
    ),
  ),
  // 10. Bot + verified badge.
  ApiChatSummary(
    id: 10,
    chatType: 'bot',
    name: 'NiosAI',
    unreadCount: 0,
    membersCount: 2,
    partnerBadges: const <ApiBadge>[
      ApiBadge(id: 2, name: 'Bot', icon: 'bot', color: 'primary'),
    ],
    lastMessage: _msg(
      id: 110,
      chatId: 10,
      senderId: 900,
      senderName: 'NiosAI',
      content: 'Помогу с текстом, переводом и суммаризацией переписки',
      minutesAgo: 300,
    ),
  ),
  // 11. Long name + long preview.
  ApiChatSummary(
    id: 11,
    chatType: 'direct',
    name: 'Александра Вельяминова-Полянская',
    unreadCount: 2,
    membersCount: 2,
    isOnline: true,
    lastMessage: _msg(
      id: 111,
      chatId: 11,
      senderId: 15,
      senderName: 'Александра',
      content:
          'Привет! Посмотрела твой вариант инбокса — честно говоря, вторая '
          'итерация с крупными аватарами и разделителями читается заметно '
          'легче, но я бы ещё подняла контраст времени и выровняла бейджи.',
      minutesAgo: 1500,
    ),
  ),
  // 12. Photo preview.
  ApiChatSummary(
    id: 12,
    chatType: 'group',
    name: 'Команда «Вектор»',
    unreadCount: 0,
    membersCount: 24,
    lastMessage: _msg(
      id: 112,
      chatId: 12,
      senderId: 18,
      senderName: 'Олег',
      msgType: 'image',
      mediaType: 'image/jpeg',
      mediaUrl: 'https://cdn.niosmess.example/attachments/img_1042.jpg',
      mediaName: 'IMG_20261116_1042.jpg',
      minutesAgo: 2600,
    ),
  ),
  // 13. Channel, muted, no unread.
  ApiChatSummary(
    id: 13,
    chatType: 'channel',
    name: 'NiosPlus',
    unreadCount: 0,
    membersCount: 5231,
    description: 'Подписка NiosPlus: возможности и обновления',
    lastMessage: _msg(
      id: 113,
      chatId: 13,
      senderId: 500,
      senderName: 'NiosPlus',
      content: 'Новые возможности подписки уже доступны всем пользователям',
      minutesAgo: 4000,
    ),
  ),
  // 14. Sending (optimistic) last message.
  ApiChatSummary(
    id: 14,
    chatType: 'direct',
    name: 'Support',
    unreadCount: 0,
    membersCount: 2,
    lastMessage: _msg(
      id: 114,
      chatId: 14,
      senderId: _kMyUserId,
      senderName: 'Александр',
      content: 'Спасибо, вопрос решён',
      isSending: true,
      minutesAgo: 4400,
    ),
  ),
  // 15. Group, quiet.
  ApiChatSummary(
    id: 15,
    chatType: 'group',
    name: 'Семья',
    unreadCount: 0,
    membersCount: 6,
    lastMessage: _msg(
      id: 115,
      chatId: 15,
      senderId: 21,
      senderName: 'Мама',
      content: 'Позвони, как освободишься',
      minutesAgo: 5900,
    ),
  ),
];

const Set<int> _mutedChatIds = <int>{7, 8, 13};
const Map<int, String> _drafts = <int, String>{
  4: 'давайте перенесём ревью на четверг и соберём полный список правок по макетам',
  11: 'Напишу подробный ответ вечером, сейчас на созвоне',
};
const Set<int> _typingChatIds = <int>{5};

// ---------------------------------------------------------------------------
// Provider fakes
// ---------------------------------------------------------------------------

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults().copyWith(
    soundEffects: false,
    haptics: false,
  );
}

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    hydrated: true,
    busy: false,
    pendingIdentifier: null,
    error: null,
    profile: null,
    session: AuthSession(
      accessToken: 'local-ui-fixture',
      userId: _kMyUserId,
      username: 'preview',
      displayName: 'Александр',
    ),
  );
}

class _Chats extends ChatsNotifier {
  @override
  Future<List<ApiChatSummary>> build() async => _chats;
}

class _Typing extends TypingNotifier {
  _Typing(super.chatId);
  @override
  TypingState build() => TypingState(
    typingUserIds: _typingChatIds.contains(chatId) ? <int>{2} : const <int>{},
  );
}

class _MuteHub extends ChatMuteHub {
  @override
  Future<Set<int>> build() async => _mutedChatIds;
}

class _Folders extends ChatFoldersNotifier {
  @override
  Future<List<ChatFolder>> build() async => const <ChatFolder>[];
}

// ---------------------------------------------------------------------------
// Screenshot plumbing
// ---------------------------------------------------------------------------

/// One rendered inbox variant.
class _Variant {
  const _Variant({
    required this.name,
    required this.size,
    required this.brightness,
  });

  final String name;
  final Size size;
  final Brightness brightness;
}

const List<_Variant> _variants = <_Variant>[
  _Variant(
    name: 'inbox_light_phone',
    size: Size(390, 844),
    brightness: Brightness.light,
  ),
  _Variant(
    name: 'inbox_dark_phone',
    size: Size(390, 844),
    brightness: Brightness.dark,
  ),
  _Variant(
    name: 'inbox_light_tablet',
    size: Size(900, 1200),
    brightness: Brightness.light,
  ),
  _Variant(
    name: 'inbox_dark_tablet',
    size: Size(900, 1200),
    brightness: Brightness.dark,
  ),
];

Future<void> _writePng(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String path,
) async {
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    try {
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final File file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
      // ignore: avoid_print
      print(
        '[inbox-shot] ${file.path} '
        '${(file.lengthSync() / 1024).toStringAsFixed(1)} KB '
        '(${image.width}x${image.height})',
      );
    } finally {
      image.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!_enabled) return;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _loadFonts();
  });

  for (final _Variant variant in _variants) {
    testWidgets(
      'inbox visual dump: ${variant.name}',
      (WidgetTester tester) async {
        if (!_enabled) {
          // ignore: avoid_print
          print('[inbox-shot] skipped: set NIOS_INBOX_SHOTS_DIR to enable');
          return;
        }
        tester.view.physicalSize = variant.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final GlobalKey boundaryKey = GlobalKey();
        final GoRouter router = GoRouter(
          routes: <RouteBase>[
            GoRoute(
              path: '/',
              builder: (BuildContext context, GoRouterState state) =>
                  Scaffold(
                    body: const ChatListScreen(),
                    floatingActionButton: const InboxComposeButton(),
                    bottomNavigationBar: AppBottomNav(
                      currentIndex: 0,
                      onTap: (_) {},
                      hapticsEnabled: false,
                    ),
                  ),
            ),
            GoRoute(
              path: '/new-message',
              builder: (_, _) => const Scaffold(body: Text('compose')),
            ),
            GoRoute(
              path: '/chat/:id',
              builder: (_, GoRouterState state) =>
                  Scaffold(body: Text('chat-${state.pathParameters['id']}')),
            ),
            GoRoute(
              path: '/main/settings',
              builder: (_, _) => const Scaffold(body: Text('settings')),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              uiSettingsProvider.overrideWith(_Settings.new),
              appSoundProvider.overrideWith((Ref ref) {
                throw StateError('audio must stay uninitialized in a screenshot');
              }),
              authProvider.overrideWith(_Auth.new),
              chatsProvider.overrideWith(_Chats.new),
              chatMuteHubProvider.overrideWith(_MuteHub.new),
              chatFoldersProvider.overrideWith(_Folders.new),
              liveDraftMapProvider.overrideWith(
                (Ref ref) => Stream<Map<int, String>>.value(_drafts),
              ),
              secretChatEngineProvider.overrideWithValue(null),
              secretChatRevisionProvider.overrideWith(
                (Ref ref) => Stream<int>.value(0),
              ),
              ordinaryE2eeProvider.overrideWithValue(null),
              for (final ApiChatSummary chat in _chats)
                typingProvider(chat.id).overrideWith(() => _Typing(chat.id)),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              locale: const Locale('ru'),
              debugShowCheckedModeBanner: false,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: AppTheme.themed(
                const UiSettingsState.defaults().visualTheme,
                variant.brightness,
              ),
              builder: (BuildContext context, Widget? child) =>
                  RepaintBoundary(key: boundaryKey, child: child!),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final Size expected = variant.size;
        final RenderBox surface =
            boundaryKey.currentContext!.findRenderObject()! as RenderBox;
        expect(surface.size, expected);
        expect(tester.getSize(find.byType(ChatListScreen)).width, expected.width);
        expect(find.byType(ChatTile), findsWidgets);

        await _writePng(
          tester,
          boundaryKey,
          '$_outputDir/${variant.name}.png',
        );
      },
    );
  }
}
