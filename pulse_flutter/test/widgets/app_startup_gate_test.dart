import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/widgets/app_logo_mark.dart';
import 'package:pulse_flutter/widgets/app_startup_gate.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class _ReadyChild extends StatelessWidget {
  const _ReadyChild({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return const MaterialApp(home: Scaffold(body: Text('Ready child')));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first frame paints while bootstrap remains pending', (
    tester,
  ) async {
    final pending = Completer<void>();
    var attempts = 0;
    var childBuilds = 0;
    await tester.pumpWidget(
      AppStartupGate(
        initialize: () {
          // Initialization runs after the first frame has mounted its content.
          expect(find.byType(AppLogoMark), findsOneWidget);
          expect(find.byType(AppLoadingIndicator), findsOneWidget);
          attempts++;
          return pending.future;
        },
        child: _ReadyChild(onBuild: () => childBuilds++),
      ),
    );
    await tester.pump(const Duration(seconds: 5));

    expect(attempts, 1);
    expect(childBuilds, 0);
    expect(find.byType(AppLogoMark), findsOneWidget);
    expect(find.byType(AppLoadingIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final locale in const [Locale('ru'), Locale('en')]) {
    testWidgets('bootstrap failure and retry are localized for $locale', (
      tester,
    ) async {
      tester.binding.platformDispatcher.localesTestValue = [locale];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          locale.languageCode == 'ru' ? Brightness.dark : Brightness.light;
      addTearDown(
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
      );
      final l10n = await AppLocalizations.delegate.load(locale);
      final first = Completer<void>();
      final retry = Completer<void>();
      final reported = <Object>[];
      var attempts = 0;
      var childBuilds = 0;
      await tester.pumpWidget(
        AppStartupGate(
          initialize: () => ++attempts == 1 ? first.future : retry.future,
          onError: (error, stack) => reported.add(error),
          child: _ReadyChild(onBuild: () => childBuilds++),
        ),
      );

      final failure = StateError('storage_unavailable');
      first.completeError(failure);
      await tester.pump();
      expect(reported, [same(failure)]);
      expect(find.text(l10n.splashInitError), findsOneWidget);
      expect(find.text(l10n.splashInitErrorSubtitle), findsOneWidget);
      expect(find.text(l10n.commonRetry), findsOneWidget);
      expect(childBuilds, 0);
      expect(find.byType(AppLoadingIndicator), findsNothing);
      final retryButton = find.byType(FilledButton);
      expect(tester.getSize(retryButton).height, greaterThanOrEqualTo(48));

      await tester.tap(retryButton);
      await tester.pump();
      expect(attempts, 2);
      expect(childBuilds, 0);
      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      retry.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Ready child'), findsOneWidget);
      expect(find.byType(AppLoadingIndicator), findsNothing);
      expect(childBuilds, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('two retry taps before a rebuild start one attempt', (
    tester,
  ) async {
    final first = Completer<void>();
    final retry = Completer<void>();
    var attempts = 0;
    await tester.pumpWidget(
      AppStartupGate(
        initialize: () => ++attempts == 1 ? first.future : retry.future,
        child: const SizedBox.shrink(),
      ),
    );
    first.completeError(StateError('storage_unavailable'));
    await tester.pump();

    final button = find.byType(FilledButton);
    await tester.tap(button);
    await tester.tap(button);
    expect(attempts, 2);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    retry.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposed gate catches and reports a late bootstrap error', (
    tester,
  ) async {
    final pending = Completer<void>();
    final reported = <Object>[];
    var childBuilds = 0;
    await tester.pumpWidget(
      AppStartupGate(
        initialize: () => pending.future,
        onError: (error, stack) => reported.add(error),
        child: _ReadyChild(onBuild: () => childBuilds++),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    final failure = StateError('late_storage_failure');
    pending.completeError(failure);
    await tester.pump();

    expect(reported, [same(failure)]);
    expect(childBuilds, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposed gate never mounts child on late bootstrap success', (
    tester,
  ) async {
    final pending = Completer<void>();
    var childBuilds = 0;
    await tester.pumpWidget(
      AppStartupGate(
        initialize: () => pending.future,
        child: _ReadyChild(onBuild: () => childBuilds++),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete();
    await tester.pump();

    expect(childBuilds, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('synchronous bootstrap and reporter errors remain recoverable', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      AppStartupGate(
        initialize: () {
          attempts++;
          if (attempts == 1) throw StateError('synchronous_bootstrap_failure');
          return Future<void>.value();
        },
        onError: (error, stack) => throw StateError('diagnostics_failed'),
        child: const MaterialApp(home: Text('Ready child')),
      ),
    );
    await tester.pump();
    expect(find.byType(FilledButton), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump();
    expect(attempts, 2);
    expect(find.text('Ready child'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
