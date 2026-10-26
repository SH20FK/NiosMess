import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/custom_emoji_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/custom_emoji_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => _account(1);
  void replaceAccount() => state = _account(2);
  AuthState _account(int id) => const AuthState.initial().copyWith(
    session: AuthSession(
      accessToken: 'fixture-$id',
      userId: id,
      username: 'fixture$id',
      displayName: 'Fixture $id',
    ),
  );
}

class _Sets extends CustomEmojiSets {
  @override
  Future<List<ApiCustomEmojiSet>> build() async => const [];
  @override
  Future<void> refresh() async {}
}

void main() {
  late ProviderContainer container;
  late GlobalKey<CustomEmojiPickerState> picker;
  late List<(String, Map<String, dynamic>)> requests;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests = [];
    picker = GlobalKey<CustomEmojiPickerState>();
    container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_Auth.new),
        customEmojiSetsProvider.overrideWith(_Sets.new),
        customEmojiRequestProvider.overrideWithValue((action, payload) async {
          requests.add((action, Map<String, dynamic>.from(payload)));
          return {'id': 9};
        }),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> mount(WidgetTester tester, {bool narrow = false}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(narrow ? 320 : 600, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(useMaterial3: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(narrow ? 2 : 1)),
            child: child!,
          ),
          home: Scaffold(
            body: CustomEmojiPicker(key: picker, onSelected: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openForm(WidgetTester tester, {bool save = false}) async {
    unawaited(picker.currentState!.showManagement());
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(CustomEmojiPicker)).l10n;
    await tester.tap(
      find.text(save ? l10n.customAddSet : l10n.customCreateSet),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  }

  Finder fields() => find.descendant(
    of: find.byType(AppDialog),
    matching: find.byType(TextField),
  );

  testWidgets(
    'keyboard next/done retains form data through the closing route',
    (tester) async {
      await mount(tester);
      await openForm(tester);
      await tester.enterText(fields().at(0), '  My pack  ');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      final lastEditable = tester.widget<EditableText>(
        find.descendant(
          of: fields().at(1),
          matching: find.byType(EditableText),
        ),
      );
      expect(lastEditable.focusNode.hasFocus, isTrue);
      await tester.enterText(fields().at(1), '  MY_PACK  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(requests.single.$1, 'create_emoji_set');
      expect(requests.single.$2, {
        'title': 'My pack',
        'name': 'my_pack',
        'is_public': true,
      });
      expect(find.byType(AppDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('narrow keyboard cancellation keeps the picker search intact', (
    tester,
  ) async {
    await mount(tester, narrow: true);
    await tester.enterText(find.byType(TextField), 'search draft');
    await openForm(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.enterText(fields().at(0), 'unsaved pack');
    await tester.tap(find.text('Отмена'));
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'search draft',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final save in [false, true]) {
    testWidgets(
      'account replacement cancels ${save ? "save" : "create"} form',
      (tester) async {
        await mount(tester);
        await openForm(tester, save: save);
        for (var index = 0; index < (save ? 1 : 2); index++) {
          await tester.enterText(fields().at(index), 'old_account_data');
        }
        (container.read(authProvider.notifier) as _Auth).replaceAccount();
        await tester.pump();
        await tester.tap(find.text('Продолжить'));
        await tester.pumpAndSettle();
        expect(requests, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
