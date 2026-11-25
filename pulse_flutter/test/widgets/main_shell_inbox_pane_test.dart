// Shell layout contract for the inbox pane (INBOX_VISUAL_AUDIT_2026-11-16):
// * compact windows never stretch the list past 640dp (centred instead);
// * tablets from 840dp get the existing list–detail split;
// * the composer FAB always clears the navigation bar, and the list pane owns
//   the same 88dp clearance the inbox reserves for it.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/platform/client_capabilities.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/screens/chat_list_screen.dart';
import 'package:pulse_flutter/screens/main_shell_screen.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';
import 'package:pulse_flutter/widgets/app_bottom_nav.dart';
import 'package:pulse_flutter/widgets/nav/app_nav_rail.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() =>
      const UiSettingsState.defaults().copyWith(soundEffects: false);
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
      accessToken: 'layout-fixture',
      userId: 42,
      username: 'preview',
      displayName: 'Александр',
    ),
  );
}

class _Chats extends ChatsNotifier {
  @override
  Future<List<ApiChatSummary>> build() async => const <ApiChatSummary>[];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpShell(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clientCapabilitiesProvider.overrideWithValue(
            const ClientCapabilities(
              isWeb: false,
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
          connectivityProvider.overrideWith((ref) => Stream<bool>.value(true)),
          liveDraftMapProvider.overrideWith(
            (ref) => Stream<Map<int, String>>.value(const <int, String>{}),
          ),
          secretChatEngineProvider.overrideWithValue(null),
          secretChatCoordinatorProvider.overrideWith((ref) async => null),
          secretChatRevisionProvider.overrideWith(
            (ref) => Stream<int>.value(0),
          ),
          ordinaryE2eeProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.themed(
            const UiSettingsState.defaults().visualTheme,
            Brightness.light,
          ),
          home: const MainShellScreen(tab: 'chats'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  }

  testWidgets('tablet split keeps the list pane narrow and the detail visible', (
    tester,
  ) async {
    await pumpShell(tester, const Size(900, 1200));

    final Rect list = tester.getRect(find.byType(ChatListScreen));
    expect(list.width, lessThanOrEqualTo(kInboxContentMaxWidth));
    // A detail pane shares the window: without the split the list would be 900.
    expect(list.width, lessThan(540));
    // Wide windows navigate from the side rail, on desktop as well as web.
    expect(find.byType(AppNavRail), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);
  });

  testWidgets('compact window centres the inbox inside 640dp', (tester) async {
    await pumpShell(tester, const Size(700, 1200));

    final Rect list = tester.getRect(find.byType(ChatListScreen));
    expect(list.width, kInboxContentMaxWidth);
    expect(list.left, (700 - kInboxContentMaxWidth) / 2);
    expect(find.byType(AppBottomNav), findsOneWidget);
    expect(find.byType(AppNavRail), findsNothing);
  });

  testWidgets('phone inbox uses the full width', (tester) async {
    await pumpShell(tester, const Size(390, 844));

    expect(tester.getSize(find.byType(ChatListScreen)).width, 390);
  });

  testWidgets('composer FAB sits inside the list pane, clear of the rail', (
    tester,
  ) async {
    await pumpShell(tester, const Size(900, 1200));

    final Finder fabFinder = find.byType(FloatingActionButton);
    final Rect fab = tester.getRect(fabFinder);
    final Rect rail = tester.getRect(find.byType(AppNavRail));
    final Rect list = tester.getRect(find.byType(ChatListScreen));
    expect(tester.getSize(fabFinder).width, 56);
    expect(tester.getSize(fabFinder).height, 56);
    // No bottom bar on a wide window: the button keeps its margin from the
    // window edge instead.
    expect(fab.bottom, lessThanOrEqualTo(1200 - kInboxComposerMargin));
    // The pane the FAB floats over is the capped list pane, not the window.
    expect(fab.left, greaterThan(rail.right));
    expect(fab.right, lessThanOrEqualTo(list.right - kInboxComposerMargin));
  });

  testWidgets('shell body is present and unpadded above the bar', (
    tester,
  ) async {
    await pumpShell(tester, const Size(390, 844));
    expect(find.byType(PulseScaffoldBody), findsOneWidget);
    final Rect fab = tester.getRect(find.byType(FloatingActionButton));
    final Rect nav = tester.getRect(find.byType(AppBottomNav));
    expect(fab.bottom, lessThanOrEqualTo(nav.top - kInboxComposerMargin));
  });
}
