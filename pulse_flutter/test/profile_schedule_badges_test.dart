import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/models/api/working_hours_model.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/widgets/profile/badge_selector_dialog.dart';
import 'package:pulse_flutter/widgets/profile/working_hours_planner_dialog.dart';
import 'package:pulse_flutter/widgets/profile/working_hours_widget.dart';

class _FakeWebSocketClient extends WebSocketClient {
  _FakeWebSocketClient()
      : super(baseUrl: 'wss://test', readToken: () => 'test_token');

  final List<Map<String, dynamic>> requests = <Map<String, dynamic>>[];
  dynamic nextResponse;

  @override
  Future<dynamic> request(
    String action, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
  }) async {
    requests.add(<String, dynamic>{'action': action, 'payload': payload});
    return nextResponse ?? <String, dynamic>{};
  }
}

void main() {
  group('WorkingHours & TimeInterval Models', () {
    test('TimeInterval serialization & format', () {
      final TimeInterval interval = TimeInterval.fromJson(<dynamic>['10:00', '19:00']);
      expect(interval.start, '10:00');
      expect(interval.end, '19:00');
      expect(interval.toJson(), <String>['10:00', '19:00']);
      expect(interval.toString(), '10:00 - 19:00');
      expect(interval.startMinutes, 600);
      expect(interval.endMinutes, 1140);
      expect(interval.isValid, true);

      const TimeInterval invalid = TimeInterval(start: '20:00', end: '10:00');
      expect(invalid.isValid, false);
    });

    test('WorkingHours json parse & isOpenNow calculation', () {
      final WorkingHours hours = WorkingHours.fromJson(<String, dynamic>{
        'timezone': 'Europe/Moscow',
        'mon': <dynamic>[
          <dynamic>['09:00', '18:00']
        ],
        'tue': <dynamic>[],
        'wed': <dynamic>[
          <dynamic>['10:00', '14:00'],
          <dynamic>['15:00', '19:00']
        ],
        'thu': <dynamic>[
          <dynamic>['08:00', '10:00'],
          <dynamic>['10:30', '12:30'],
          <dynamic>['13:00', '15:00'],
          <dynamic>['15:30', '17:30'],
          <dynamic>['18:00', '20:00'], // 5th interval should be truncated by take(4)
        ],
      });

      expect(hours.timezone, 'Europe/Moscow');
      expect(hours.mon.length, 1);
      expect(hours.mon.first.start, '09:00');
      expect(hours.tue.isEmpty, true);
      expect(hours.wed.length, 2);
      expect(hours.thu.length, 4); // Capped at 4 intervals per day

      // Mon 12:00 -> Open
      final DateTime monOpen = DateTime(2026, 9, 7, 12, 0); // Mon
      expect(hours.isOpenNow(monOpen), true);
      expect(hours.getStatusText(monOpen), 'Открыто до 18:00');

      // Mon 20:00 -> Closed
      final DateTime monClosed = DateTime(2026, 9, 7, 20, 0);
      expect(hours.isOpenNow(monClosed), false);
      expect(hours.getStatusText(monClosed), contains('Откроется в ср в 10:00'));

      // Wed 14:30 -> Break between intervals
      final DateTime wedBreak = DateTime(2026, 9, 9, 14, 30); // Wed
      expect(hours.isOpenNow(wedBreak), false);
      expect(hours.getStatusText(wedBreak), 'Откроется сегодня в 15:00');
    });

    test('WorkingHours empty schedule returns Closed', () {
      const WorkingHours empty = WorkingHours(timezone: 'UTC');
      expect(empty.isEmpty, true);
      expect(empty.isOpenNow(), false);
      expect(empty.getStatusText(), 'Закрыто');
    });

    test('ApiBadge with description and copyWith', () {
      const ApiBadge badge = ApiBadge(
        id: 10,
        name: 'VIP',
        icon: 'star',
        color: 'gold',
        description: 'VIP подписчик',
      );

      expect(badge.id, 10);
      expect(badge.description, 'VIP подписчик');
      expect(badge.toJson()['description'], 'VIP подписчик');

      final ApiBadge parsed = ApiBadge.fromJson(<String, dynamic>{
        'id': 10,
        'name': 'VIP',
        'icon': 'star',
        'color': 'gold',
        'description': 'VIP подписчик',
      });
      expect(parsed, badge);

      final ApiBadge modified = badge.copyWith(name: 'VIP+');
      expect(modified.name, 'VIP+');
      expect(modified.description, 'VIP подписчик');
    });
  });


  group('ApiProfile Extended Fields & Badges', () {
    test('ApiProfile serialization with phone, birthday, workingHours and visible badges', () {
      final ApiProfile profile = ApiProfile.fromJson(<String, dynamic>{
        'id': 42,
        'username': 'alex',
        'display_name': 'Alex',
        'bio': 'Software Engineer',
        'phone_number': '+79991234567',
        'birthday': '1995-05-15',
        'working_hours': <String, dynamic>{
          'timezone': 'UTC',
          'mon': <dynamic>[<dynamic>['09:00', '18:00']],
        },
        'badges': <dynamic>[
          <String, dynamic>{'id': 1, 'name': 'Verified', 'icon': 'verified', 'color': 'primary'},
          <String, dynamic>{'id': 2, 'name': 'Dev', 'icon': 'code', 'color': 'secondary'},
          <String, dynamic>{'id': 3, 'name': 'Tester', 'icon': 'bug', 'color': 'tertiary'},
        ],
        'visible_badge_ids': <dynamic>[2, 3],
      });

      expect(profile.phoneNumber, '+79991234567');
      expect(profile.birthday, '1995-05-15');
      expect(profile.workingHours, isNotNull);
      expect(profile.workingHours!.mon.length, 1);
      expect(profile.visibleBadges.length, 2);
      expect(profile.visibleBadges.map((ApiBadge b) => b.id), <int>[2, 3]);

      final Map<String, dynamic> json = profile.toJson();
      expect(json['phone_number'], '+79991234567');
      expect(json['birthday'], '1995-05-15');
      expect(json['visible_badge_ids'], <int>[2, 3]);
    });
  });

  group('AuthRepository Gateway Actions', () {
    late ProviderContainer container;
    late _FakeWebSocketClient fakeWs;
    late AuthRepository repository;

    setUp(() {
      fakeWs = _FakeWebSocketClient();
      container = ProviderContainer(
        overrides: [
          webSocketClientProvider.overrideWithValue(fakeWs),
        ],
      );
      repository = container.read(authRepositoryProvider);
    });

    tearDown(() => container.dispose());

    test('updateProfile sends phone_number, birthday and working_hours', () async {
      fakeWs.nextResponse = <String, dynamic>{
        'id': 10,
        'username': 'test',
        'display_name': 'Test User',
        'bio': 'Bio',
        'phone_number': '+1234567890',
        'birthday': '2000-01-01',
      };

      final ApiProfile updated = await repository.updateProfile(
        phoneNumber: '+1234567890',
        birthday: '2000-01-01',
        workingHours: const WorkingHours(
          timezone: 'UTC',
          mon: <TimeInterval>[TimeInterval(start: '10:00', end: '18:00')],
        ),
      );

      expect(updated.phoneNumber, '+1234567890');
      expect(fakeWs.requests.last['action'], 'update_profile');
      final Map<String, dynamic> payload = fakeWs.requests.last['payload'] as Map<String, dynamic>;
      expect(payload['phone_number'], '+1234567890');
      expect(payload['birthday'], '2000-01-01');
      expect(payload['working_hours'], isNotNull);
    });

    test('getMyBadges & setVisibleBadges actions', () async {
      fakeWs.nextResponse = <String, dynamic>{
        'badges': <dynamic>[
          <String, dynamic>{'id': 1, 'name': 'VIP', 'icon': 'star', 'color': 'gold'},
          <String, dynamic>{'id': 2, 'name': 'Staff', 'icon': 'shield', 'color': 'blue'},
        ],
      };

      final List<ApiBadge> badges = await repository.getMyBadges();
      expect(badges.length, 2);
      expect(badges.first.name, 'VIP');
      expect(fakeWs.requests.last['action'], 'get_my_badges');

      fakeWs.nextResponse = <String, dynamic>{
        'badge_ids': <dynamic>[1, 2],
      };

      final List<int> savedIds = await repository.setVisibleBadges(<int>[1, 2, 3]);
      expect(savedIds, <int>[1, 2]); // Max 2 badges trimmed
      expect(fakeWs.requests.last['action'], 'set_visible_badges');
      final Map<String, dynamic> setPayload = fakeWs.requests.last['payload'] as Map<String, dynamic>;
      expect(setPayload['badge_ids'], <int>[1, 2]);
    });
    test('uploadAvatar sends filename and isVideo, validates 8MB limit', () async {
      fakeWs.nextResponse = <String, dynamic>{
        'avatar_url': 'https://storage/avatars/me.jpg',
      };

      final String url = await repository.uploadAvatar(
        <int>[1, 2, 3, 4],
        filename: 'avatar.jpg',
        isVideo: false,
      );
      expect(url, 'https://storage/avatars/me.jpg');
      expect(fakeWs.requests.last['action'], 'upload_avatar');
      final Map<String, dynamic> payload = fakeWs.requests.last['payload'] as Map<String, dynamic>;
      expect(payload['filename'], 'avatar.jpg');
      expect(payload['is_video'], isNull);

      // Video avatar
      fakeWs.nextResponse = <String, dynamic>{
        'avatar_url': 'https://storage/avatars/video.mp4',
      };
      final String videoUrl = await repository.uploadAvatar(
        <int>[5, 6, 7, 8],
        filename: 'video.mp4',
        isVideo: true,
      );
      expect(videoUrl, 'https://storage/avatars/video.mp4');
      final Map<String, dynamic> videoPayload = fakeWs.requests.last['payload'] as Map<String, dynamic>;
      expect(videoPayload['is_video'], true);

      // Reject > 8MB
      final List<int> oversized = List<int>.filled(8 * 1024 * 1024 + 1, 0);
      expect(
        () => repository.uploadAvatar(oversized, filename: 'large.mp4'),
        throwsException,
      );
    });
  });

  group('UI Widgets for Profile, Schedule & Badges', () {
    testWidgets('WorkingHoursWidget renders status and expands', (WidgetTester tester) async {
      const WorkingHours hours = WorkingHours(
        timezone: 'UTC',
        mon: <TimeInterval>[TimeInterval(start: '09:00', end: '18:00')],
      );

      final DateTime mondayNoon = DateTime(2026, 9, 7, 12, 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkingHoursWidget(
              workingHours: hours,
              isEditable: true,
              now: mondayNoon,
            ),
          ),
        ),
      );

      expect(find.text('График работы'), findsOneWidget);
      expect(find.text('Открыто до 18:00'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);

      // Tap to expand
      await tester.tap(find.text('График работы'));
      await tester.pumpAndSettle();

      expect(find.text('Понедельник'), findsOneWidget);
      expect(find.text('09:00 – 18:00'), findsOneWidget);
      expect(find.text('Вторник'), findsOneWidget);
      expect(find.text('Выходной'), findsWidgets);
    });

    testWidgets('WorkingHoursPlannerDialog renders days and action buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WorkingHoursPlannerDialog(),
          ),
        ),
      );

      expect(find.text('График работы'), findsOneWidget);
      expect(find.text('Пн'), findsOneWidget);
      expect(find.text('Вт'), findsOneWidget);
      expect(find.text('Добавить интервал'), findsOneWidget);
      expect(find.text('Применить'), findsOneWidget);
    });

    testWidgets('BadgeSelectorDialog renders title and actions', (WidgetTester tester) async {
      final _FakeWebSocketClient fakeWs = _FakeWebSocketClient();
      fakeWs.nextResponse = <String, dynamic>{
        'badges': <dynamic>[
          <String, dynamic>{
            'id': 1,
            'name': 'VIP',
            'icon': 'star',
            'color': 'gold',
            'description': 'VIP статус аккаунта'
          },
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            webSocketClientProvider.overrideWithValue(fakeWs),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: BadgeSelectorDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Выбор бейджей'), findsOneWidget);
      expect(find.text('VIP'), findsOneWidget);
      expect(find.text('VIP статус аккаунта'), findsOneWidget);
      expect(find.text('Сохранить'), findsOneWidget);
    });
  });
}

