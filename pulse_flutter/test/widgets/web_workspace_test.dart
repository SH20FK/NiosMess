import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/platform/client_capabilities.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/screens/main_shell_screen.dart';
import 'package:pulse_flutter/widgets/chat/chat_actions_modal.dart';
import 'package:pulse_flutter/widgets/chat/bubble/bubble_footer.dart';
import 'package:pulse_flutter/widgets/chat/chat_input_bar.dart';
import 'package:pulse_flutter/widgets/chat/voice_recording_panel.dart';
import 'package:pulse_flutter/widgets/chat_tile.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    hydrated: true,
    session: const AuthSession(
      accessToken: 'local-ui-fixture',
      userId: 42,
      username: 'preview',
      displayName: 'Preview',
    ),
  );
}

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults().copyWith(
    soundEffects: false,
    haptics: false,
  );
}

class _Chats extends ChatsNotifier {
  @override
  Future<List<ApiChatSummary>> build() async => const [
    ApiChatSummary(
      id: 1,
      name: 'Ирина',
      chatType: 'direct',
      unreadCount: 2,
      membersCount: 2,
    ),
    ApiChatSummary(
      id: 2,
      name: 'Команда',
      chatType: 'group',
      unreadCount: 0,
      membersCount: 8,
    ),
  ];
}

Widget app(Widget child) => MaterialApp(
  theme: ThemeData(useMaterial3: true),
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  final capturePath = Platform.environment['NIOS_WEB_WORKSPACE_CAPTURE_DIR'];
  if (capturePath != null) {
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
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'alpha_test_acknowledged': true,
    }),
  );
  test(
    'relative inbox time follows the screen locale, including minute and day units',
    () {
      final now = DateTime.now();
      expect(formatRelativeTime(now, localeCode: 'ru_RU'), 'сейчас');
      expect(formatRelativeTime(now, localeCode: 'en-GB'), 'now');
      expect(
        formatRelativeTime(
          now.subtract(const Duration(minutes: 7)),
          localeCode: 'ru',
        ),
        '7 мин',
      );
      expect(
        formatRelativeTime(
          now.subtract(const Duration(minutes: 7)),
          localeCode: 'en',
        ),
        '7m',
      );
      expect(
        formatRelativeTime(
          now.subtract(const Duration(days: 3)),
          localeCode: 'ru',
        ),
        '3 д',
      );
    },
  );

  for (final browser in [true, false]) {
    testWidgets('actual shell adapts navigation on resize; browser=$browser', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = GlobalKey();
      Future<void> snapshot(String size) async {
        if (capturePath == null || !browser) return;
        await tester.runAsync(() async {
          final image =
              await (capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(capturePath).create(recursive: true);
          await File(
            '$capturePath/workspace-$size.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      final router = GoRouter(
        initialLocation: '/main/chats',
        routes: [
          GoRoute(
            path: '/main/chats',
            builder: (_, _) => const MainShellScreen(tab: 'chats'),
          ),
          GoRoute(
            path: '/new-message',
            builder: (_, _) => const Scaffold(body: Text('new-conversation')),
          ),
          GoRoute(
            path: '/main/settings',
            builder: (_, _) =>
                const Scaffold(body: Text('settings-destination')),
          ),
          GoRoute(
            path: '/main/niosgram',
            builder: (_, _) => const Scaffold(body: Text('feed-destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clientCapabilitiesProvider.overrideWithValue(
              ClientCapabilities(
                isWeb: browser,
                platform: TargetPlatform.windows,
              ),
            ),
            uiSettingsProvider.overrideWith(_Settings.new),
            authProvider.overrideWith(_Auth.new),
            webSocketClientProvider.overrideWith((ref) {
              final client = WebSocketClient(
                baseUrl: 'https://fixture.invalid',
                readToken: () => null,
              );
              ref.onDispose(client.close);
              return client;
            }),
            chatsProvider.overrideWith(_Chats.new),
            connectivityProvider.overrideWith((ref) => Stream.value(true)),
            liveDraftMapProvider.overrideWith((ref) => Stream.value(const {})),
            secretChatEngineProvider.overrideWithValue(null),
            secretChatCoordinatorProvider.overrideWith((ref) async => null),
            secretChatRevisionProvider.overrideWith((ref) => Stream.value(0)),
            ordinaryE2eeProvider.overrideWithValue(null),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.themed(
              const UiSettingsState.defaults().visualTheme,
              Brightness.light,
            ),
            darkTheme: AppTheme.themed(
              const UiSettingsState.defaults().visualTheme,
              Brightness.dark,
            ),
            themeAnimationDuration: Duration.zero,
            builder: (context, child) => RepaintBoundary(
              key: capture,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
            ),
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byType(NavigationRail),
        browser ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(NavigationBar),
        browser ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await snapshot('1440-light');
      if (browser) {
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await tester.pump();
        await snapshot('1440-dark');
        tester.platformDispatcher.platformBrightnessTestValue =
            Brightness.light;
        await tester.pump();
      }
      tester.view.physicalSize = const Size(900, 700);
      await tester.pump();
      await snapshot('900');
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      await snapshot('390');
      if (browser) {
        router.go('/main/chats?chat=1');
        await tester.pump();
        expect(
          tester
              .widgetList<ChatTile>(find.byType(ChatTile))
              .singleWhere((tile) => tile.chatId == 1)
              .isSelected,
          true,
        );
        router.go('/main/chats');
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('new-conversation'), findsOneWidget);
        router.pop();
        await tester.pump();
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('read action is shown only when the chat has unread messages', (
    tester,
  ) async {
    for (final unread in [0, 2]) {
      ChatActionResult? selected;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await ChatActionsModal.show(
                  context,
                  chat: ApiChatSummary(
                    id: 1,
                    name: 'Саша',
                    chatType: 'direct',
                    unreadCount: unread,
                    membersCount: 2,
                  ),
                  avatarColor: Theme.of(context).colorScheme.primaryContainer,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        find.text('Отметить прочитанным'),
        unread > 0 ? findsOneWidget : findsNothing,
      );
      if (unread > 0) {
        await tester.tap(find.text('Отметить прочитанным'));
        await tester.pumpAndSettle();
        expect(selected, ChatActionResult.markRead);
      } else {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets(
    'delivery transitions keep the same timestamp and status geometry at large text',
    (tester) async {
      late StateSetter update;
      var sending = true, read = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
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
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return MessageBubbleFooter(
                    isMine: true,
                    isE2ee: false,
                    isEdited: false,
                    isDeleted: false,
                    isRead: read,
                    isSending: sending,
                    formattedTime: '12:30',
                    scheme: Theme.of(context).colorScheme,
                    textTheme: Theme.of(context).textTheme,
                  );
                },
              ),
            ),
          ),
        ),
      );
      final before = tester.getRect(find.text('12:30'));
      for (final state in [0, 1]) {
        update(() {
          sending = false;
          read = state == 1;
        });
        for (var frame = 0; frame < 24; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.getRect(find.text('12:30')), before);
          expect(tester.takeException(), isNull);
        }
      }
      expect(find.byTooltip('Прочитано'), findsOneWidget);
    },
  );

  testWidgets(
    'browser composer exposes attachments but no native file-path recorder',
    (tester) async {
      final input = TextEditingController(), focus = FocusNode();
      addTearDown(input.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clientCapabilitiesProvider.overrideWithValue(
              const ClientCapabilities(
                isWeb: true,
                platform: TargetPlatform.windows,
              ),
            ),
            uiSettingsProvider.overrideWith(_Settings.new),
            ordinaryE2eeProvider.overrideWithValue(null),
          ],
          child: app(
            ChatInputBar(
              inputController: input,
              inputFocusNode: focus,
              isAiProcessing: false,
              uploadingMedia: false,
              editingMessageId: null,
              editingOriginalText: null,
              replyToMessageId: null,
              replyPreviewText: null,
              onSend: () {},
              onCommitEdit: () {},
              onCancelEdit: () {},
              onClearReply: () {},
              onAttachMedia: () {},
              onAiPressed: () {},
              onVoiceSend: (_) {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.mic_rounded), findsNothing);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final locked in [false, true]) {
    testWidgets(
      'recording panel delegates feedback to its owner; locked=$locked',
      (tester) async {
        final feedback = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'HapticFeedback.vibrate') feedback.add(call);
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        var sent = 0, cancelled = 0;
        await tester.pumpWidget(
          app(
            SizedBox(
              width: 390,
              child: VoiceRecordingPanel(
                elapsed: const Duration(seconds: 3),
                dragOffset: Offset.zero,
                isLocked: locked,
                amplitudeHistory: const [.2, .5],
                onSend: () => sent++,
                onCancel: () => cancelled++,
              ),
            ),
          ),
        );
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.tap(find.byIcon(Icons.delete_outline_rounded));
        expect(sent, 1);
        expect(cancelled, 1);
        expect(
          feedback,
          isEmpty,
          reason:
              'The composer owns the global haptic preference; the panel must not vibrate twice.',
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
