import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/router/app_navigation.dart';

void main() {
  Widget opener(ValueChanged<String?> onResult) => Builder(
    builder: (BuildContext context) => TextButton(
      onPressed: () async => onResult(
        await pushAppRoute<String>(
          context,
          '/target',
          fallback: (_) => const _Target(label: 'fallback'),
        ),
      ),
      child: const Text('open'),
    ),
  );

  GoRouter router(Widget home) {
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (_, _) => Scaffold(body: home)),
        GoRoute(
          path: '/target',
          pageBuilder: (_, GoRouterState state) => MaterialPage<String>(
            key: state.pageKey,
            child: const _Target(label: 'routed'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    return router;
  }

  testWidgets('goes through the router and returns the typed pop result', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router(opener((v) => result = v))),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('routed'), findsOneWidget);
    expect(find.text('fallback'), findsNothing);

    await tester.tap(find.text('routed'));
    await tester.pumpAndSettle();
    expect(result, 'routed');
    expect(find.text('open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a router the fallback screen is pushed', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: opener((v) => result = v))),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('fallback'), findsOneWidget);

    await tester.tap(find.text('fallback'));
    await tester.pumpAndSettle();
    expect(result, 'fallback');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a page pushed from a bottom sheet lands above the sheet', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router(
          Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                useRootNavigator: true,
                builder: (_) => SizedBox(
                  height: 200,
                  child: Center(child: opener((v) => result = v)),
                ),
              ),
              child: const Text('sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('routed').hitTestable(), findsOneWidget);

    await tester.tap(find.text('routed'));
    await tester.pumpAndSettle();
    expect(result, 'routed');
    // The sheet is still open under the page that was just popped.
    expect(find.text('open').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Target extends StatelessWidget {
  const _Target({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).pop(label),
          child: Text(label),
        ),
      ),
    );
  }
}
