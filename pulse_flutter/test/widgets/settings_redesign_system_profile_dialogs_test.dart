import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/working_hours_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/widgets/profile/badge_picker_sheet.dart';
import 'package:pulse_flutter/widgets/profile/working_hours_planner_dialog.dart';

class _Account extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'fixture-a',
      userId: 1,
      username: 'fixture',
      displayName: 'Fixture',
    ),
  );
  @override
  Future<void> refreshProfile() async {}
  void change() => state = state.copyWith(
    session: const AuthSession(
      accessToken: 'fixture-b',
      userId: 2,
      username: 'fixtureb',
      displayName: 'Fixture B',
    ),
  );
}

class _Badges extends AuthRepository {
  _Badges(super.ref, this.load);
  final Future<List<ApiBadge>> load;
  List<int>? saved;
  @override
  Future<List<ApiBadge>> getMyBadges() => load;
  @override
  Future<List<int>> setVisibleBadges(List<int> ids) async => saved = ids;
}

const _badges = [
  ApiBadge(
    id: 1,
    name: 'Fixture badge one',
    icon: 'star',
    color: 'gold',
    description: 'A longer badge description that must remain readable',
  ),
  ApiBadge(id: 2, name: 'Fixture badge two', icon: 'code', color: 'blue'),
  ApiBadge(id: 3, name: 'Fixture badge three', icon: 'shield', color: 'green'),
];

Widget _app(
  Widget home, {
  Locale locale = const Locale('ru'),
  bool large = true,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData(useMaterial3: true),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: true,
      textScaler: TextScaler.linear(large ? 2 : 1),
    ),
    child: child!,
  ),
  home: home,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final locale in ['ru', 'en']) {
    testWidgets(
      'working-hours editor preserves other days and timezone at 320dp/200% $locale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const initial = WorkingHours(
          timezone: 'UTC',
          mon: [
            TimeInterval(start: '08:00', end: '09:00'),
            TimeInterval(start: '10:00', end: '11:00'),
            TimeInterval(start: '12:00', end: '13:00'),
            TimeInterval(start: '14:00', end: '15:00'),
          ],
          tue: [TimeInterval(start: '11:00', end: '17:00')],
        );
        WorkingHours? result;
        await tester.pumpWidget(
          ProviderScope(
            child: _app(
              Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await WorkingHoursPlannerDialog.show(
                        context,
                        initialWorkingHours: initial,
                      );
                    },
                    child: const Text('Open hours'),
                  ),
                ),
              ),
              locale: Locale(locale),
            ),
          ),
        );
        await tester.tap(find.text('Open hours'));
        await tester.pumpAndSettle();
        expect(
          find.text(locale == 'ru' ? 'Добавить интервал' : 'Add interval'),
          findsNothing,
        );
        final wednesday = find.text(locale == 'ru' ? 'Ср' : 'Wed');
        await tester.ensureVisible(wednesday);
        await tester.tap(wednesday);
        await tester.pumpAndSettle();
        final labels = AppLocalizations.of(
          tester.element(find.byType(WorkingHoursPlannerDialog)),
        )!;
        final presets = find.text(labels.settingsHoursPresets);
        // Secondary tools are deliberately collapsed until the user requests them.
        final presetGroup = find.widgetWithText(
          ExpansionTile,
          labels.settingsHoursPresets,
        );
        await tester.ensureVisible(presetGroup);
        await tester.tap(presets);
        await tester.pumpAndSettle();
        final preset = find.text('09:00–18:00');
        await tester.ensureVisible(preset);
        await tester.tap(preset);
        await tester.pumpAndSettle();
        await tester.tap(find.text(locale == 'ru' ? 'Применить' : 'Apply'));
        await tester.pumpAndSettle();
        expect(result?.timezone, 'UTC');
        expect(result?.mon, initial.mon);
        expect(result?.tue, initial.tue);
        expect(result?.wed, [const TimeInterval(start: '09:00', end: '18:00')]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'badge selection is limited to two and saves a single operation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      late _Badges repository;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_Account.new),
            authRepositoryProvider.overrideWith(
              (ref) => repository = _Badges(ref, Future.value(_badges)),
            ),
          ],
          child: _app(
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => BadgePickerSheet.show(context),
                  child: const Text('Open badges'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open badges'));
      await tester.pumpAndSettle();
      for (final badge in _badges) {
        final title = find.text(badge.name);
        await tester.ensureVisible(title);
        await tester.tap(title);
        await tester.pumpAndSettle();
      }
      expect(find.text('Выбрано: 2/2'), findsOneWidget);
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(repository.saved, [1, 2]);
      expect(find.byType(BadgePickerSheet), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('account switch ignores late badge data and disables saving', (
    tester,
  ) async {
    final load = Completer<List<ApiBadge>>();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_Account.new),
        authRepositoryProvider.overrideWith((ref) => _Badges(ref, load.future)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _app(const Scaffold(body: BadgePickerSheet()), large: false),
      ),
    );
    await tester.pump();
    (container.read(authProvider.notifier) as _Account).change();
    load.complete(_badges);
    await tester.pumpAndSettle();
    expect(find.text('Fixture badge one'), findsNothing);
    expect(find.text('Сохранить'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
