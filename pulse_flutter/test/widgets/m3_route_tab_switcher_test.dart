import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/widgets/nav/m3_route_tab_switcher.dart';

class _Page extends StatefulWidget {
  const _Page(this.id, this.created, this.disposed);
  final int id;
  final List<int> created, disposed;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  final scroll = ScrollController();
  int counter = 0;
  @override
  void initState() {
    super.initState();
    widget.created.add(widget.id);
  }

  @override
  void dispose() {
    widget.disposed.add(widget.id);
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextButton(
        onPressed: () => setState(() => counter++),
        child: Text('page ${widget.id}: $counter'),
      ),
      Expanded(
        child: ListView(
          controller: scroll,
          children: [
            for (var i = 0; i < 100; i++)
              SizedBox(height: 48, child: Text('row ${widget.id}/$i')),
          ],
        ),
      ),
    ],
  );
}

void main() {
  var created = <int>[], disposed = <int>[];
  setUp(() {
    created = <int>[];
    disposed = <int>[];
  });
  Widget harness(
    int index, {
    bool animate = true,
    bool reduced = false,
    ValueChanged<bool>? notify,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Scaffold(
        body: M3RouteTabSwitcher(
          index: index,
          animate: animate,
          duration: const Duration(milliseconds: 250),
          onTransitionStateChanged: notify,
          children: [for (var i = 0; i < 3; i++) _Page(i, created, disposed)],
        ),
      ),
    ),
  );
  testWidgets(
    'pages initialize once and retain real state and scroll across transitions',
    (tester) async {
      await tester.pumpWidget(harness(0));
      await tester.tap(find.text('page 0: 0'));
      final state = tester.state<_PageState>(find.byType(_Page).first);
      state.scroll.jumpTo(600);
      await tester.pumpWidget(harness(1));
      await tester.pumpAndSettle();
      await tester.pumpWidget(harness(2));
      await tester.pumpAndSettle();
      await tester.pumpWidget(harness(0));
      await tester.pumpAndSettle();
      expect(tester.state<_PageState>(find.byType(_Page).first), same(state));
      expect(find.text('page 0: 1'), findsOneWidget);
      expect(state.scroll.offset, 600);
      expect(created, [0, 1, 2]);
      expect(disposed, isEmpty);
      expect(find.byType(RawImage), findsNothing);
    },
  );
  testWidgets('fade through exposes one page and no lateral slide', (
    tester,
  ) async {
    await tester.pumpWidget(harness(0));
    await tester.pumpWidget(harness(1));
    await tester.pump(const Duration(milliseconds: 35));
    expect(find.text('page 0: 0'), findsOneWidget);
    expect(find.text('page 1: 0'), findsNothing);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(find.text('page 1: 0'), findsOneWidget);
    expect(find.text('page 0: 0'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(M3RouteTabSwitcher),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
    await tester.pumpAndSettle();
    expect(disposed, isEmpty);
  });
  for (final elapsed in [25, 110, 185]) {
    testWidgets(
      'rapid return and third-tab retarget at ${elapsed}ms settles on latest selection',
      (tester) async {
        final notifications = <bool>[];
        await tester.pumpWidget(harness(0, notify: notifications.add));
        await tester.pumpWidget(harness(2, notify: notifications.add));
        await tester.pump(Duration(milliseconds: elapsed));
        await tester.pumpWidget(harness(0, notify: notifications.add));
        await tester.pump(const Duration(milliseconds: 15));
        await tester.pumpWidget(harness(1, notify: notifications.add));
        await tester.pumpAndSettle();
        expect(find.text('page 1: 0'), findsOneWidget);
        expect(find.text('page 2: 0'), findsNothing);
        expect(notifications.last, false);
        expect(created, [0, 1, 2]);
        expect(disposed, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('incoming page cannot accept taps before transition completes', (
    tester,
  ) async {
    await tester.pumpWidget(harness(0));
    await tester.pumpWidget(harness(1));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.tap(find.text('page 1: 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('page 1: 0'), findsOneWidget);
    await tester.tap(find.text('page 1: 0'));
    await tester.pump();
    expect(find.text('page 1: 1'), findsOneWidget);
  });
  testWidgets(
    'reduced motion mid-transition completes without recreating pages',
    (tester) async {
      await tester.pumpWidget(harness(0));
      await tester.pumpWidget(harness(2));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpWidget(harness(2, reduced: true));
      await tester.pump();
      expect(find.text('page 2: 0'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, false);
      expect(created, [0, 1, 2]);
      expect(disposed, isEmpty);
    },
  );
  testWidgets('disabled animation swaps instantly and preserves pages', (
    tester,
  ) async {
    await tester.pumpWidget(harness(0, animate: false));
    await tester.pumpWidget(harness(2, animate: false));
    await tester.pump();
    expect(find.text('page 2: 0'), findsOneWidget);
    expect(created, [0, 1, 2]);
    expect(disposed, isEmpty);
  });

  testWidgets('lazy background activation retains the active page', (
    tester,
  ) async {
    Widget warmHarness(bool warmed) => MaterialApp(
      home: Scaffold(
        body: M3RouteTabSwitcher(
          index: 0,
          children: [
            _Page(0, created, disposed),
            warmed ? _Page(1, created, disposed) : const SizedBox.shrink(),
          ],
        ),
      ),
    );
    await tester.pumpWidget(warmHarness(false));
    final state = tester.state<_PageState>(find.byType(_Page));
    await tester.tap(find.text('page 0: 0'));
    await tester.pumpWidget(warmHarness(true));
    await tester.pump();
    expect(tester.state<_PageState>(find.byType(_Page).first), same(state));
    expect(find.text('page 0: 1'), findsOneWidget);
    expect(created, [0, 1]);
    expect(disposed, isEmpty);
  });

  testWidgets(
    'return to original tab ends transition before and after fade boundary',
    (tester) async {
      for (final elapsed in [25, 110]) {
        await tester.pumpWidget(harness(0));
        await tester.pumpAndSettle();
        await tester.pumpWidget(harness(2));
        await tester.pump(Duration(milliseconds: elapsed));
        await tester.pumpWidget(harness(0));
        await tester.pumpAndSettle();
        expect(find.text('page 0: 0'), findsOneWidget);
        expect(find.text('page 2: 0'), findsNothing);
        expect(tester.binding.hasScheduledFrame, false);
      }
      expect(created, [0, 1, 2]);
      expect(disposed, isEmpty);
    },
  );
}
