import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/utils/app_error_formatter.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';

Future<BuildContext> _pumpHost(
  WidgetTester tester, {
  double keyboardInset = 0,
  bool reducedMotion = false,
  bool nestedScaffolds = false,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  late BuildContext toastContext;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          viewInsets: EdgeInsets.only(bottom: keyboardInset),
          disableAnimations: reducedMotion,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            toastContext = context;
            if (!nestedScaffolds) return const SizedBox.expand();
            return IndexedStack(
              children: [
                Scaffold(
                  body: Builder(
                    builder: (context) {
                      toastContext = context;
                      return const SizedBox.expand();
                    },
                  ),
                ),
                const Scaffold(body: Text('Inactive tab')),
              ],
            );
          },
        ),
        // A large accessory must never lift a short status into mid-screen.
        floatingActionButton: const SizedBox(width: 56, height: 240),
        bottomNavigationBar: const SizedBox(
          key: ValueKey('navigation'),
          height: 80,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return toastContext;
}

void main() {
  testWidgets('toast stays at bottom above navigation despite a tall FAB', (
    tester,
  ) async {
    final context = await _pumpHost(tester, nestedScaffolds: true);

    AppToast.showSuccess(context, 'Left chat');
    await tester.pumpAndSettle();

    expect(find.text('Left chat'), findsOneWidget);
    final toast = tester.getRect(find.byType(SnackBar));
    final navigation = tester.getRect(find.byKey(const ValueKey('navigation')));
    expect(toast.bottom, closeTo(navigation.top, 1));
    expect(toast.top, greaterThan(600));
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).elevation, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toast stays immediately above keyboard', (tester) async {
    final context = await _pumpHost(tester, keyboardInset: 300);

    AppToast.showInfo(context, 'Saved');
    await tester.pumpAndSettle();

    final toast = tester.getRect(find.byType(SnackBar));
    expect(toast.bottom, closeTo(500, 1));
    expect(toast.top, greaterThan(400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('action remains usable without animation in reduced motion', (
    tester,
  ) async {
    final context = await _pumpHost(tester, reducedMotion: true);
    var undone = false;

    AppToast.showAction(
      context,
      message: 'Chat removed',
      actionLabel: 'Undo',
      onAction: () => undone = true,
    );
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.animation!.value, 1);
    expect(snackBar.persist, isTrue);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(undone, isTrue);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error retains details and retry action at the bottom', (
    tester,
  ) async {
    final context = await _pumpHost(tester);
    var retried = false;

    AppToast.showError(
      context,
      const AppFormattedError(
        title: 'Cannot send',
        description: 'Connection interrupted',
        technicalDetails: 'network_unavailable',
      ),
      onRetry: () => retried = true,
    );
    await tester.pumpAndSettle();

    expect(find.text('Cannot send'), findsOneWidget);
    expect(find.text('Connection interrupted'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    expect(tester.getRect(find.byType(SnackBar)).bottom, closeTo(720, 1));
    await tester.tap(find.widgetWithText(SnackBarAction, 'Retry'));
    await tester.pumpAndSettle();
    expect(retried, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toast survives a route change and returns to bottom of shell', (
    tester,
  ) async {
    final context = await _pumpHost(tester, nestedScaffolds: true);
    final navigator = Navigator.of(context);
    navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Chat')),
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                AppToast.showInfo(context, 'Left chat');
                Navigator.of(context).pop();
              },
              child: const Text('Leave'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(find.text('Chat'), findsNothing);
    expect(find.text('Left chat'), findsOneWidget);
    expect(tester.getRect(find.byType(SnackBar)).bottom, closeTo(720, 1));
    expect(tester.takeException(), isNull);
  });
}
