// Device-only profile measurements of real app components, not synthetic FPS.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/screens/settings_appearance_screen.dart';
import 'package:pulse_flutter/widgets/nav/m3_route_tab_switcher.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/widgets/chat/chat_message_list.dart';

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults();
  @override
  void setSeedColor(Color color) =>
      state = state.copyWith(seedColor: color, useSystemDynamic: false);
}

class _AnonymousAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(hydrated: true);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('appearance scrolling, cloud palettes and persistent tabs', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        uiSettingsProvider.overrideWith(_Settings.new),
        authProvider.overrideWith(_AnonymousAuth.new),
      ],
    );
    addTearDown(container.dispose);
    final tab = ValueNotifier(0);
    addTearDown(tab.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            final settings = ref.watch(uiSettingsProvider);
            return MaterialApp(
              theme: AppTheme.themed(settings.visualTheme, Brightness.light),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ValueListenableBuilder<int>(
                valueListenable: tab,
                builder: (context, index, _) => M3RouteTabSwitcher(
                  index: index,
                  children: const [SettingsAppearanceScreen(), _Conversation()],
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await binding.watchPerformance(() async {
      for (var i = 0; i < 12; i++) {
        tab.value = i % 2;
        await tester.pump(const Duration(milliseconds: 450));
        final scrollable = find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  (widget.axisDirection == AxisDirection.down ||
                      widget.axisDirection == AxisDirection.up),
            )
            .hitTestable()
            .last;
        if (i.isEven) {
          // Exercise color baking while the preview is actually visible.
          final position = tester.state<ScrollableState>(scrollable).position;
          position.jumpTo(position.minScrollExtent);
          await tester.pump(const Duration(milliseconds: 16));
          (container.read(uiSettingsProvider.notifier) as _Settings)
              .setSeedColor(Color.fromARGB(255, 70 + i * 10, 90 + i * 5, 180));
          await tester.pump(const Duration(milliseconds: 600));
        }
        await tester.fling(scrollable, Offset(0, i.isEven ? -450 : 450), 1800);
        await tester.pump(const Duration(milliseconds: 600));
      }
    }, reportKey: 'appearance_tabs_frames');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Conversation extends StatefulWidget {
  const _Conversation();
  @override
  State<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<_Conversation> {
  final _scroll = ScrollController();
  // Fixture content is deterministic; frame timings come from real rendering.
  final _messages = List.generate(
    1000,
    (index) => ApiMessage.fromJson({
      'id': index + 1,
      'chat_id': 42,
      'sender_id': index.isEven ? 1 : 2,
      'content': 'Benchmark message $index: scroll, grouping and layout.',
      'msg_type': 'text',
      'sent_at': DateTime.utc(
        2026,
        10,
        15,
      ).add(Duration(minutes: index)).toIso8601String(),
    }),
  );
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ChatMessageList(
      messages: _messages,
      scrollController: _scroll,
      authUserId: 1,
      amAdminOrOwner: false,
      isChannel: false,
      onOpenMedia: (_) {},
      onLongPressMedia: (_, _, _) {},
      onLongPress: (_, _, _, _) {},
      onSwipeToReply: (_) {},
      onCallbackQuery: (_, _) {},
      onRetrySend: (_) {},
      displayTextBuilder: (message) => message.content,
      mediaUrlBuilder: (_) => null,
      isImageMediaBuilder: (_, _) => false,
      mediaLabelBuilder: (_, _) => null,
      replyPreviewBuilder: (_, _) => null,
      dateSeparatorBuilder: (_, _) => const SizedBox.shrink(),
      animatedMessageBuilder:
          ({
            required messageId,
            required animate,
            required isMine,
            required child,
          }) => child,
    ),
  );
}
