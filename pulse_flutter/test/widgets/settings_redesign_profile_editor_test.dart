import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/working_hours_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/profile/edit_profile_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Sound extends SoundService {
  @override
  Future<void> playEvent(SoundEvent event, {double? volume}) async {}
}

class _Auth extends AuthNotifier {
  final writes = <({int? account, String? name, String? bio})>[];
  final responses = <Completer<AuthActionResult>>[];
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'isolated-editor-a',
      userId: 1,
      username: 'user_a',
      displayName: 'Test account A',
    ),
  );
  void switchAccount() => state = state.copyWith(
    session: const AuthSession(
      accessToken: 'isolated-editor-b',
      userId: 2,
      username: 'user_b',
      displayName: 'Test account B',
    ),
  );
  @override
  Future<AuthActionResult> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    String? phoneNumber,
    String? birthday,
    WorkingHours? workingHours,
    bool clearPhoneNumber = false,
    bool clearBirthday = false,
    bool clearWorkingHours = false,
  }) {
    writes.add((account: state.session?.userId, name: displayName, bio: bio));
    final response = Completer<AuthActionResult>();
    responses.add(response);
    return response.future;
  }
}

Widget _app(
  ProviderContainer container, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double scale = 1,
  VoidCallback? avatar,
  VoidCallback? extra,
}) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    theme: ThemeData(useMaterial3: true, brightness: brightness),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          child: const Text('Open profile'),
          onPressed: () => EditProfileSheet.show(
            context,
            initialName: 'Test account A',
            initialUsername: 'user_a',
            initialBio: 'Isolated initial description',
            onUploadAvatar: () async => avatar?.call(),
            actions: [
              TextButton(
                key: const ValueKey('editor-extra-action'),
                onPressed: extra,
                child: const Text('Profile link'),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

ProviderContainer _container() => ProviderContainer(
  overrides: [
    authProvider.overrideWith(_Auth.new),
    appSoundProvider.overrideWithValue(_Sound()),
  ],
);

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final brightness in Brightness.values) {
    for (final locale in [const Locale('ru'), const Locale('en')]) {
      testWidgets(
        'profile editor keeps actions reachable at 320dp / 200% keyboard $brightness $locale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          final container = _container();
          addTearDown(container.dispose);
          var extraInvoked = 0;
          await tester.pumpWidget(
            _app(
              container,
              locale: locale,
              brightness: brightness,
              scale: 2,
              extra: () => extraInvoked++,
            ),
          );
          await tester.tap(find.text('Open profile'));
          await tester.pumpAndSettle();
          tester.view.viewInsets = const FakeViewPadding(bottom: 240);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final l10n = AppLocalizations.of(
            tester.element(find.byType(EditProfileSheet)),
          )!;
          expect(
            find.widgetWithText(FilledButton, l10n.commonSave).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byTooltip(l10n.commonCancel).hitTestable(),
            findsOneWidget,
          );
          final extraAction = find.byKey(const ValueKey('editor-extra-action'));
          await tester.ensureVisible(extraAction);
          await tester.pumpAndSettle();
          await tester.tap(extraAction);
          expect(extraInvoked, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        },
      );
    }
  }

  testWidgets('profile draft from A cannot save or upload into B', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    var uploads = 0;
    await tester.pumpWidget(_app(container, avatar: () => uploads++));
    await tester.tap(find.text('Open profile'));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(EditProfileSheet)),
    )!;
    await tester.enterText(_field(l10n.profileDisplayName), 'Draft owned by A');
    final save = tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, l10n.commonSave),
        )
        .onPressed!;
    final avatar = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Change photo'))
        .onPressed!;
    (container.read(authProvider.notifier) as _Auth).switchAccount();
    await tester.pumpAndSettle();
    // Old callbacks can outlive a route frame: ownership must be enforced in code.
    save();
    avatar();
    await tester.pumpAndSettle();
    final auth = container.read(authProvider.notifier) as _Auth;
    expect(auth.writes, isEmpty);
    expect(uploads, 0);
    expect(find.byType(TextFormField), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('profile save is coalesced and failure keeps draft editable', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await tester.tap(find.text('Open profile'));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(EditProfileSheet)),
    )!;
    await tester.enterText(_field(l10n.profileDisplayName), 'Kept draft name');
    await tester.enterText(
      _field(l10n.profileDescription),
      'Kept draft description',
    );
    final saveButton = find.widgetWithText(FilledButton, l10n.commonSave);
    final save = tester.widget<FilledButton>(saveButton).onPressed!;
    save();
    save();
    await tester.pump();
    final auth = container.read(authProvider.notifier) as _Auth;
    expect(auth.writes, hasLength(1));
    expect(auth.writes.single.account, 1);
    expect(auth.writes.single.name, 'Kept draft name');
    auth.responses.single.complete(
      const AuthActionResult(success: false, message: 'Isolated save failed'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileSheet), findsOneWidget);
    expect(
      tester
          .widget<TextField>(_field(l10n.profileDisplayName))
          .controller!
          .text,
      'Kept draft name',
    );
    expect(
      tester
          .widget<TextField>(_field(l10n.profileDescription))
          .controller!
          .text,
      'Kept draft description',
    );
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });
}
