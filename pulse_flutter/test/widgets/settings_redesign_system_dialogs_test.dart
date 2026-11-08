import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/models/api/support_ticket_model.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/support_repository.dart';
import 'package:pulse_flutter/screens/settings_about_screen.dart';
import 'package:pulse_flutter/widgets/alpha_test_dialog.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/settings/about_bug_report_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TicketRepository extends SupportRepository {
  _TicketRepository(super.ref, this.response);
  final Future<SupportTicket?> response;
  int submissions = 0;
  String? submittedSubject;
  @override
  Future<SupportTicket?> createTicket({
    required String ticketType,
    required String subject,
    required String body,
  }) {
    submissions++;
    submittedSubject = subject;
    return response;
  }
}

class _TicketSocket extends WebSocketClient {
  _TicketSocket()
    : super(baseUrl: 'wss://fixture.invalid', readToken: () => 'fixture');
  int? retries;
  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    retries = maxRetries;
    return {
      'id': 4,
      'ticket_type': 'bug',
      'subject': payload?['subject'],
      'body': payload?['body'],
    };
  }
}

Widget _app(
  Widget home, {
  Brightness brightness = Brightness.light,
  bool largeText = false,
}) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData(brightness: brightness, useMaterial3: true),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: true,
      textScaler: TextScaler.linear(largeText ? 2 : 1),
    ),
    child: child!,
  ),
  home: home,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'support creation opts out of automatic replay for non-idempotent writes',
    () async {
      final socket = _TicketSocket();
      final container = ProviderContainer(
        overrides: [webSocketClientProvider.overrideWithValue(socket)],
      );
      addTearDown(container.dispose);
      final ticket = await container
          .read(supportRepositoryProvider)
          .createTicket(
            ticketType: 'bug',
            subject: 'Fixture issue',
            body: 'Fixture description',
          );
      expect(ticket?.id, 4);
      expect(socket.retries, 0);
    },
  );

  testWidgets('failed support acknowledgement retains text and permits retry', (
    tester,
  ) async {
    final response = Completer<SupportTicket?>();
    late _TicketRepository repository;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportRepositoryProvider.overrideWith(
            (ref) => repository = _TicketRepository(ref, response.future),
          ),
        ],
        child: _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAppDialog<void>(
                  context: context,
                  builder: (_) => const AboutBugReportDialog(),
                ),
                child: const Text('Open report'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open report'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Fixture issue');
    await tester.enterText(find.byType(TextField).last, 'Fixture description');
    await tester.pump();
    await tester.tap(find.text('Отправить'));
    await tester.pump();
    expect(repository.submissions, 1);
    expect(repository.submittedSubject, 'Fixture issue');
    final button = tester.widget<FilledButton>(find.byType(FilledButton).last);
    expect(button.onPressed, isNull);
    response.complete(null);
    await tester.pumpAndSettle();
    expect(find.byType(AboutBugReportDialog), findsOneWidget);
    expect(find.text('Fixture issue'), findsOneWidget);
    expect(find.text('Fixture description'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'About documents and team remain usable at 320dp/200% ${brightness.name}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ProviderScope(
            child: _app(
              const SettingsAboutScreen(isEmbedded: true),
              brightness: brightness,
              largeText: true,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        final docs = find.text('Документы');
        await Scrollable.ensureVisible(tester.element(docs));
        await tester.pump();
        await tester.tap(docs);
        await tester.pumpAndSettle();
        expect(find.text('Сторонние лицензии и библиотеки'), findsOneWidget);
        final team = find.text('Команда');
        await Scrollable.ensureVisible(tester.element(team));
        await tester.pumpAndSettle();
        await tester.tap(team);
        await tester.pumpAndSettle();
        expect(find.text('sanlsan'), findsOneWidget);
        expect(find.text('SH20FK'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'report dialog keeps its draft when close is cancelled at 320dp/200% with a keyboard',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(() {
        tester.view.resetViewInsets();
        return tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        ProviderScope(
          child: _app(
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showAppDialog<void>(
                    context: context,
                    builder: (_) => const AboutBugReportDialog(),
                  ),
                  child: const Text('Open report'),
                ),
              ),
            ),
            largeText: true,
          ),
        ),
      );
      await tester.tap(find.text('Open report'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Fixture draft');
      await tester.pump();
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отмена').last);
      await tester.pumpAndSettle();
      expect(find.byType(AboutBugReportDialog), findsOneWidget);
      expect(find.text('Fixture draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'alpha information uses readable rows and a flexible acknowledgement',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          child: _app(
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => AlphaTestDialog.show(context),
                  child: const Text('Alpha'),
                ),
              ),
            ),
            largeText: true,
          ),
        ),
      );
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(find.text('@hello_sanlsan'), findsOneWidget);
      expect(find.text('@sh20fk'), findsOneWidget);
      final button = find.widgetWithText(FilledButton, 'Понятно');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'alpha_test_acknowledged',
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
