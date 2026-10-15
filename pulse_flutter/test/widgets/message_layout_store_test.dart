import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/storage/chat_history_anchor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/media/animated_media_controller_pool.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/widgets/chat/chat_message_list.dart';

ApiMessage _message(int id) => ApiMessage.fromJson({
  'id': id,
  'chat_id': 42,
  'sender_id': id.isEven ? 1 : 2,
  'content': 'Message $id',
  'msg_type': 'text',
  'sent_at': DateTime.utc(
    2026,
    10,
    15,
  ).add(Duration(minutes: id)).toIso8601String(),
});

void _expectSameLayout(MessageLayoutStore store, List<ApiMessage> messages) {
  final baseline = MessageLayoutStore()..reset(messages);
  expect(store.byId, baseline.byId);
  expect(store.idToIndex, baseline.idToIndex);
  for (var i = 0; i < messages.length; i++) {
    expect(store.layout[i].showDateSep, baseline.layout[i].showDateSep);
    expect(store.layout[i].isPrevSame, baseline.layout[i].isPrevSame);
    expect(store.layout[i].isNextSame, baseline.layout[i].isNextSame);
  }
}

class _Performance extends AdaptivePerformanceNotifier {
  @override
  AdaptivePerformanceState build() => const AdaptivePerformanceState(
    mode: PerformanceMode.balanced,
    targetFps: 60,
    targetFrameBudgetMs: 16.67,
    recentJankRatio: 0,
    isDegraded: false,
  );
}

Widget _historyHarness(
  List<ApiMessage> messages,
  ScrollController scroll, {
  int? highlight,
  ChatHistoryAnchor? initialAnchor,
  ValueChanged<ChatHistoryAnchor>? onAnchor,
}) => ProviderScope(
  overrides: [adaptivePerformanceProvider.overrideWith(_Performance.new)],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ChatMessageList(
        messages: messages,
        scrollController: scroll,
        followingLatest: false,
        highlightMessageId: highlight,
        initialScrollAnchor: initialAnchor,
        onScrollAnchorChanged: onAnchor,
        authUserId: 1,
        amAdminOrOwner: false,
        isChannel: false,
        onOpenMedia: (_) {},
        onLongPressMedia: (_, _, _) {},
        onLongPress: (_, _, _, _) {},
        onSwipeToReply: (_) {},
        onCallbackQuery: (_, _) {},
        onRetrySend: (_) {},
        displayTextBuilder: (m) => m.content,
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
    ),
  ),
);

Finder _anchor(int id) => find.byWidgetPredicate(
  (w) =>
      w.runtimeType.toString() == '_HistoryAnchor' &&
      w.key == ValueKey<int>(id),
);

void main() {
  testWidgets(
    'actual list scroll notifications pause media and debounce resumption',
    (tester) async {
      final pool = AnimatedMediaControllerPool.instance;
      final otherList = Object();
      pool.setFastScrolling(false);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final messages = [
        for (var i = 0; i < 100; i++)
          _message(i).copyWith(content: '📞 Call $i'),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adaptivePerformanceProvider.overrideWith(_Performance.new),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ChatMessageList(
                messages: messages,
                scrollController: scroll,
                authUserId: 1,
                amAdminOrOwner: false,
                isChannel: false,
                onOpenMedia: (_) {},
                onLongPressMedia: (_, _, _) {},
                onLongPress: (_, _, _, _) {},
                onSwipeToReply: (_) {},
                onCallbackQuery: (_, _) {},
                onRetrySend: (_) {},
                displayTextBuilder: (m) => m.content,
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
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.fling(find.byType(Scrollable), const Offset(0, 500), 4000);
      await tester.pump(const Duration(milliseconds: 16));
      expect(pool.isFastScrolling, isTrue);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 180));
      expect(pool.isFastScrolling, isFalse);
      // Removing this list must not release an unrelated list's fling lease.
      pool.setFastScrolling(true, source: otherList);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(pool.isFastScrolling, isTrue);
      pool.setFastScrolling(false, source: otherList);
    },
  );

  testWidgets(
    'variable-height rows retain their measured anchor across both window directions',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final all = [
        for (var id = 1; id <= 500; id++)
          _message(id).copyWith(content: '📞 row $id${'\nline' * (id % 4)}'),
      ];
      var window = all.sublist(150, 450);
      await tester.pumpWidget(_historyHarness(window, scroll));
      await tester.pump();
      scroll.jumpTo(scroll.position.maxScrollExtent / 2);
      await tester.pump();
      final candidates = window
          .where((m) => _anchor(m.id).evaluate().isNotEmpty)
          .where((m) {
            final rect = tester.getRect(_anchor(m.id));
            return rect.top >= 0 && rect.bottom <= 600;
          })
          .toList();
      expect(candidates, isNotEmpty);
      final id = candidates[candidates.length ~/ 2].id;
      final original = tester.getRect(_anchor(id));
      window = all.sublist(100, 400);
      await tester.pumpWidget(_historyHarness(window, scroll));
      await tester.pump();
      expect(tester.getRect(_anchor(id)).top, closeTo(original.top, 0.5));
      window = all.sublist(150, 450);
      await tester.pumpWidget(_historyHarness(window, scroll));
      await tester.pump();
      expect(tester.getRect(_anchor(id)).top, closeTo(original.top, 0.5));
      await tester.drag(find.byType(Scrollable), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'highlight jumps to an exact distant row without average height estimates',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final rows = [
        for (var id = 1; id <= 300; id++)
          _message(id).copyWith(content: '📞 row $id${'\nline' * (id % 4)}'),
      ];
      await tester.pumpWidget(_historyHarness(rows, scroll));
      await tester.pump();
      expect(_anchor(12), findsNothing);
      await tester.pumpWidget(_historyHarness(rows, scroll, highlight: 12));
      await tester.pumpAndSettle();
      expect(_anchor(12), findsOneWidget);
      final rect = tester.getRect(_anchor(12));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(600));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'closing and reopening restores an exact measured variable-height row',
    (tester) async {
      final first = ScrollController();
      final second = ScrollController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final rows = [
        for (var id = 1; id <= 300; id++)
          _message(id).copyWith(content: '📞 row $id${'\nline' * (id % 4)}'),
      ];
      ChatHistoryAnchor? saved;
      await tester.pumpWidget(
        _historyHarness(rows, first, onAnchor: (anchor) => saved = anchor),
      );
      await tester.pump();
      first.jumpTo(first.position.maxScrollExtent / 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(saved, isNotNull);
      final anchor = saved!;
      final before = tester.getRect(_anchor(anchor.messageId));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _historyHarness(rows, second, initialAnchor: anchor),
      );
      await tester.pump();
      expect(
        tester.getRect(_anchor(anchor.messageId)).bottom,
        closeTo(before.bottom, 0.5),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _historyHarness(rows, second, initialAnchor: anchor, highlight: 12),
      );
      await tester.pumpAndSettle();
      expect(_anchor(12), findsOneWidget);
      final highlighted = tester.getRect(_anchor(12));
      expect(highlighted.top, greaterThanOrEqualTo(0));
      expect(highlighted.bottom, lessThanOrEqualTo(600));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'reverse indexes remain correct across append, prepend, edit and removal',
    () {
      var messages = [for (var i = 10; i < 20; i++) _message(i)];
      final store = MessageLayoutStore()..reset(messages);
      final indexView = store.idToIndex;
      for (var i = 20; i < 30; i++) {
        messages = [...messages, _message(i)];
        store.sync(messages);
        _expectSameLayout(store, messages);
        expect(identical(indexView, store.idToIndex), isTrue);
      }
      messages = [for (var i = 0; i < 10; i++) _message(i), ...messages];
      store.sync(messages);
      _expectSameLayout(store, messages);
      messages = [...messages]..[13] = messages[13].copyWith(content: 'Edited');
      store.sync(messages);
      _expectSameLayout(store, messages);
      messages = [...messages]..removeAt(14);
      store.sync(messages);
      _expectSameLayout(store, messages);
    },
  );

  test(
    'edit in the retained middle is not lost during concurrent append/prepend',
    () {
      final initial = [for (var i = 10; i < 20; i++) _message(i)];
      final store = MessageLayoutStore()..reset(initial);
      final appended = [...initial, _message(20)];
      appended[5] = appended[5].copyWith(content: 'Edited during append');
      store.sync(appended);
      _expectSameLayout(store, appended);
      expect(store.byId[15]?.content, 'Edited during append');
      final prepended = [_message(9), ...appended];
      prepended[7] = prepended[7].copyWith(content: 'Edited during page');
      store.sync(prepended);
      _expectSameLayout(store, prepended);
      expect(store.byId[16]?.content, 'Edited during page');
    },
  );
}
