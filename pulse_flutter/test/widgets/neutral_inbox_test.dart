import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/theme/app_surfaces.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/typing_provider.dart';
import 'package:pulse_flutter/screens/chat_list_screen.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';
import 'package:pulse_flutter/widgets/app_bottom_nav.dart';
import 'package:pulse_flutter/widgets/chat/inbox_compose_button.dart';
import 'package:pulse_flutter/widgets/chat/chat_search_field.dart';
import 'package:pulse_flutter/widgets/chat_tile.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';
import 'package:pulse_flutter/widgets/wallpaper/chat_wallpaper_background.dart';
import 'package:universal_io/io.dart';

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults().copyWith(
    navBarFloating: true,
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
      userId: 42,
      username: 'preview',
      displayName: 'Preview',
    ),
  );
}

class _Chats extends ChatsNotifier {
  @override
  Future<List<ApiChatSummary>> build() async => _chats;
}

class _QuietTyping extends TypingNotifier {
  _QuietTyping(super.chatId);
  @override
  TypingState build() => const TypingState();
}

final _chats = <ApiChatSummary>[
  for (var i = 0; i < 6; i++)
    ApiChatSummary(
      id: i + 1,
      chatType: i == 1
          ? 'bot'
          : i == 4
          ? 'group'
          : 'direct',
      name: [
        'Ирина',
        'NiosAI',
        'Support',
        'Сухарик',
        'Наша группа',
        'Секретный диалог',
      ][i],
      unreadCount: i == 0
          ? 2
          : i == 2
          ? 3
          : 0,
      membersCount: i == 4 ? 12 : 2,
      isSecret: i == 5,
      isOnline: i == 0,
      lastMessage: ApiMessage.fromJson({
        'id': i + 101,
        'chat_id': i + 1,
        'sender_id': i == 3 ? 42 : 2,
        'sender_username': 'preview',
        'sender_display_name': 'Preview',
        'content': [
          'До встречи вечером!',
          'Помогу с текстом и переводом',
          'Чем можем помочь?',
          'Хорошо, договорились',
          'Обсуждаем планы на выходные',
          'Сообщение сохранено на устройстве',
        ][i],
        'msg_type': 'text',
        'sent_at': DateTime.now().toIso8601String(),
        'is_read': true,
      }),
    ),
];

void main() {
  final output = Platform.environment['NIOS_INBOX_CAPTURE_DIR'];
  if (output != null) {
    setUpAll(() async {
      for (final entry in {
        'Onest': 'assets/fonts/onest/Onest-Variable.ttf',
        'GolosText': 'assets/fonts/golos_text/GolosText-Variable.ttf',
        'BricolageGrotesque':
            'assets/fonts/bricolage_grotesque/BricolageGrotesque-Variable.ttf',
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      }.entries) {
        await (FontLoader(
          entry.key,
        )..addFont(rootBundle.load(entry.value))).load();
      }
    });
  }

  test(
    'neutral surfaces preserve selected accents for every palette and theme',
    () {
      for (final brightness in Brightness.values) {
        for (final seed in [const Color(0xff006c5b), const Color(0xffab342e)]) {
          final base = ColorScheme.fromSeed(
            seedColor: seed,
            brightness: brightness,
          );
          final neutral = AppSurfaces.neutralize(base);
          expect(neutral.primary, base.primary);
          expect(neutral.secondary, base.secondary);
          expect(neutral.tertiary, base.tertiary);
          for (final color in [
            neutral.surface,
            neutral.surfaceContainerLow,
            neutral.surfaceContainer,
            neutral.surfaceContainerHigh,
            neutral.surfaceContainerHighest,
          ]) {
            final argb = color.toARGB32();
            expect((argb >> 16) & 255, (argb >> 8) & 255);
            expect((argb >> 8) & 255, argb & 255);
          }
        }
      }
    },
  );

  testWidgets(
    'page and chat backdrop never create painters or read wallpaper storage',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PulseScaffoldBody(
            expand: true,
            child: const ChatWallpaperBackground(chatId: 'example'),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(PulseScaffoldBody),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    for (final locale in ['ru', 'en']) {
      for (final scale in [1.0, 1.8]) {
        testWidgets(
          'real inbox, avatars and docked nav $brightness $locale font=$scale',
          (tester) async {
            tester.view.physicalSize = const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final capture = GlobalKey();
            var index = 0;
            final router = GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => StatefulBuilder(
                    builder: (context, setState) => RepaintBoundary(
                      key: capture,
                      child: Scaffold(
                        body: const ChatListScreen(),
                        floatingActionButton: const InboxComposeButton(),
                        bottomNavigationBar: AppBottomNav(
                          currentIndex: index,
                          onTap: (value) => setState(() => index = value),
                          hapticsEnabled: false,
                        ),
                      ),
                    ),
                  ),
                ),
                GoRoute(
                  path: '/chats/search',
                  builder: (_, _) =>
                      const Scaffold(body: Text('search-destination')),
                ),
                GoRoute(
                  path: '/chat/:id',
                  builder: (_, state) => Scaffold(
                    body: Text('chat-${state.pathParameters['id']}'),
                  ),
                ),
                GoRoute(
                  path: '/main/settings',
                  builder: (_, _) =>
                      const Scaffold(body: Text('settings-destination')),
                ),
              ],
            );
            addTearDown(router.dispose);
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  uiSettingsProvider.overrideWith(_Settings.new),
                  authProvider.overrideWith(_Auth.new),
                  chatsProvider.overrideWith(_Chats.new),
                  ordinaryE2eeProvider.overrideWithValue(null),
                  for (final chat in _chats)
                    typingProvider(
                      chat.id,
                    ).overrideWith(() => _QuietTyping(chat.id)),
                ],
                child: MaterialApp.router(
                  routerConfig: router,
                  locale: Locale(locale),
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  theme: AppTheme.themed(
                    const UiSettingsState.defaults().visualTheme,
                    brightness,
                  ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.descendant(
                of: find.byType(ChatTile),
                matching: find.byType(PulseAvatar),
              ),
              findsWidgets,
            );
            final nav = find.byType(NavigationBar);
            expect(nav, findsOneWidget);
            expect(tester.getSize(nav).width, 390);
            expect(tester.getSize(nav).height, 66);
            expect(tester.getBottomLeft(nav).dx, 0);
            expect(tester.getBottomLeft(nav).dy, 844);

            if (output != null && scale == 1) {
              await tester.runAsync(() async {
                final boundary =
                    capture.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 1.5);
                try {
                  final bytes = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await Directory(output).create(recursive: true);
                  await File(
                    '$output/inbox_${brightness.name}_$locale.png',
                  ).writeAsBytes(bytes!.buffer.asUint8List());
                } finally {
                  image.dispose();
                }
              });
            }
            final unreadLabel = locale == 'ru' ? 'Непрочитанные' : 'Unread';
            await tester.tap(find.widgetWithText(FilterChip, unreadLabel));
            await tester.pumpAndSettle();
            expect(find.byType(ChatTile), findsNWidgets(2));
            await tester.tap(find.byType(NavigationDestination).last);
            await tester.pumpAndSettle();
            expect(tester.widget<NavigationBar>(nav).selectedIndex, 2);
            await tester.tap(find.text('Ирина'));
            await tester.pumpAndSettle();
            expect(find.text('chat-1'), findsOneWidget);
            router.pop();
            await tester.pumpAndSettle();
            await tester.tap(find.byIcon(Icons.search_rounded));
            await tester.pumpAndSettle();
            expect(find.text('search-destination'), findsOneWidget);
            router.pop();
            await tester.pumpAndSettle();
            await tester.tap(
              find.descendant(
                of: find.byType(ChatSearchField),
                matching: find.byType(IconButton),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('settings-destination'), findsOneWidget);
            router.go('/');
            await tester.pumpAndSettle();
            tester.view.physicalSize = const Size(1024, 768);
            await tester.pumpAndSettle();
            expect(tester.getSize(nav).width, 1024);
            tester.view.viewPadding = const FakeViewPadding(bottom: 34);
            addTearDown(tester.view.resetViewPadding);
            await tester.pumpAndSettle();
            expect(tester.getSize(nav).height, 100);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}
