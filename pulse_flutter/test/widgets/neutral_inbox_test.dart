import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/theme/app_surfaces.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
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
import 'package:pulse_flutter/providers/chat_list_fab_provider.dart';
import 'package:pulse_flutter/widgets/chat/bubble/bubble_footer.dart';
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
      partnerBadges: i == 1
          ? const [ApiBadge(id: 1, name: 'Bot', icon: 'bot', color: 'primary')]
          : const [],
      chatType: i == 4 ? 'group' : 'direct',
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
        'sender_display_name': i == 4 ? 'Ирина' : 'Preview',
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
        if (i == 3 || i == 5) 'e2ee_content': 'never-display-ciphertext',
        if (i == 3 || i == 5) 'is_e2ee': true,
        if (i == 3) 'is_decrypted': true,
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

  testWidgets('hidden composer is absent from accessibility navigation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final container = ProviderContainer(
        overrides: [uiSettingsProvider.overrideWith(_Settings.new)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(floatingActionButton: InboxComposeButton()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final label = tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .tooltip!;
      bool containsComposer() {
        var found = false;
        void visit(SemanticsNode node) {
          final data = node.getSemanticsData();
          found |= data.label.contains(label) || data.tooltip == label;
          node.visitChildren((child) {
            visit(child);
            return true;
          });
        }

        visit(
          tester
              .binding
              .renderViews
              .first
              .owner!
              .semanticsOwner!
              .rootSemanticsNode!,
        );
        return found;
      }

      expect(containsComposer(), isTrue);
      container.read(chatListFabVisibleProvider.notifier).hide();
      await tester.pumpAndSettle();
      expect(containsComposer(), isFalse);
    } finally {
      semantics.dispose();
    }
  });

  for (final locale in ['ru', 'en']) {
    testWidgets(
      'pending footer stays readable and retry has a usable hit target $locale',
      (tester) async {
        var attempts = 0;
        var failed = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            theme: ThemeData(useMaterial3: true),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 240,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      update = setState;
                      return MessageBubbleFooter(
                        isMine: true,
                        isE2ee: true,
                        isEdited: true,
                        isDeleted: false,
                        isRead: false,
                        formattedTime: '12:30',
                        scheme: Theme.of(context).colorScheme,
                        textTheme: Theme.of(context).textTheme,
                        isSending: !failed,
                        isFailed: failed,
                        onRetrySend: () => attempts++,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(locale == 'ru' ? 'Ожидает отправки' : 'Waiting to send'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        update(() => failed = true);
        await tester.pumpAndSettle();
        final retry = find.byType(TextButton);
        expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
        await tester.tap(retry);
        expect(attempts, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

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
            var soundInitializations = 0;
            final router = GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => StatefulBuilder(
                    builder: (context, setState) => RepaintBoundary(
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
                  path: '/new-message',
                  builder: (_, _) =>
                      const Scaffold(body: Text('compose-person')),
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
                  appSoundProvider.overrideWith((ref) {
                    soundInitializations++;
                    throw StateError("Disabled audio must stay uninitialized");
                  }),
                  authProvider.overrideWith(_Auth.new),
                  chatsProvider.overrideWith(_Chats.new),
                  liveDraftMapProvider.overrideWith(
                    (ref) => Stream.value(const {}),
                  ),
                  secretChatEngineProvider.overrideWithValue(null),
                  secretChatRevisionProvider.overrideWith(
                    (ref) => Stream.value(0),
                  ),
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
                    child: RepaintBoundary(key: capture, child: child!),
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

            Future<void> captureStep(String name) async {
              if (output == null || scale != 1) return;
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
                    '$output/${name}_${brightness.name}_$locale.png',
                  ).writeAsBytes(bytes!.buffer.asUint8List());
                } finally {
                  image.dispose();
                }
              });
            }

            await captureStep('01-inbox');
            expect(find.byType(FilterChip), findsNWidgets(3));
            expect(find.text('never-display-ciphertext'), findsNothing);
            await tester.tap(find.byIcon(Icons.more_vert_rounded));
            await tester.pumpAndSettle();
            await tester.tap(
              find.text(locale == 'ru' ? 'Создать…' : 'Create…'),
            );
            await tester.pumpAndSettle();
            expect(
              find.text(
                locale == 'ru' ? 'Начать общение' : 'Start a conversation',
              ),
              findsOneWidget,
            );
            expect(
              find.text(
                locale == 'ru' ? 'Вступить по ссылке' : 'Join with a link',
              ),
              findsOneWidget,
            );
            expect(
              find.text(
                locale == 'ru' ? 'Создать личный чат' : 'Create direct chat',
              ),
              findsNothing,
            );
            await captureStep('02-create');
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            await tester.tap(find.byType(FloatingActionButton));
            await tester.pumpAndSettle();
            expect(find.text('compose-person'), findsOneWidget);
            router.pop();
            await tester.pumpAndSettle();
            final typeLabel = locale == 'ru' ? 'Тип чата' : 'Chat type';
            final groupsLabel = locale == 'ru' ? 'Группы' : 'Groups';
            await tester.tap(find.widgetWithText(FilterChip, typeLabel));
            await tester.pumpAndSettle();
            await tester.tap(find.widgetWithText(MenuItemButton, groupsLabel));
            await tester.pumpAndSettle();
            expect(find.byType(ChatTile), findsOneWidget);
            expect(
              find.text('Ирина: Обсуждаем планы на выходные'),
              findsOneWidget,
            );
            await tester.tap(find.widgetWithText(FilterChip, groupsLabel));
            await tester.pumpAndSettle();
            await tester.tap(
              find.widgetWithText(
                MenuItemButton,
                locale == 'ru' ? 'Каналы' : 'Channels',
              ),
            );
            await tester.pumpAndSettle();
            expect(
              find.text(
                locale == 'ru'
                    ? 'В этой категории пока нет чатов'
                    : 'No chats in this category yet',
              ),
              findsOneWidget,
            );
            await tester.tap(
              find.widgetWithText(
                FilterChip,
                locale == 'ru' ? 'Каналы' : 'Channels',
              ),
            );
            await tester.pumpAndSettle();
            // Resolve the existing localized label from the category menu.
            final directItem = find.byType(MenuItemButton).first;
            await tester.tap(directItem);
            await tester.pumpAndSettle();
            expect(find.text('NiosAI'), findsNothing);
            expect(find.text('Хорошо, договорились'), findsOneWidget);
            expect(
              find.text(
                locale == 'ru'
                    ? 'Зашифрованное сообщение'
                    : 'Encrypted message',
              ),
              findsOneWidget,
            );
            await captureStep('03-direct');
            final unreadLabel = locale == 'ru' ? 'Непрочитанные' : 'Unread';
            await tester.tap(find.widgetWithText(FilterChip, unreadLabel));
            await tester.pumpAndSettle();
            expect(find.byType(ChatTile), findsNWidgets(2));
            await tester.longPress(find.text('Ирина'));
            await tester.pumpAndSettle();
            expect(find.byType(BottomSheet), findsOneWidget);
            await captureStep('04-actions');
            await tester.tap(find.text(locale == 'ru' ? 'Удалить' : 'Delete'));
            await tester.pumpAndSettle();
            expect(
              find.text(
                locale == 'ru'
                    ? 'Удалить чат «Ирина»?'
                    : 'Delete chat “Ирина”?',
              ),
              findsOneWidget,
            );
            await captureStep('05-delete-named');
            await tester.tap(find.text(locale == 'ru' ? 'Отмена' : 'Cancel'));
            await tester.pumpAndSettle();
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
            expect(soundInitializations, 0);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}
