import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/models/api/working_hours_model.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
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
  group('Adversarial Stress Test: WorkingHours & TimeInterval', () {
    test('Midnight boundary intervals: 00:00 start, 23:59 end', () {
      final TimeInterval midnightStart = TimeInterval.fromJson(<dynamic>['00:00', '08:00']);
      expect(midnightStart.startMinutes, 0);
      expect(midnightStart.endMinutes, 480);
      expect(midnightStart.isValid, true);

      final TimeInterval endOfDay = TimeInterval.fromJson(<dynamic>['20:00', '23:59']);
      expect(endOfDay.startMinutes, 1200);
      expect(endOfDay.endMinutes, 1439);
      expect(endOfDay.isValid, true);

      final TimeInterval fullDay = TimeInterval.fromJson(<dynamic>['00:00', '23:59']);
      expect(fullDay.startMinutes, 0);
      expect(fullDay.endMinutes, 1439);
      expect(fullDay.isValid, true);

      final TimeInterval invertedMidnight = TimeInterval.fromJson(<dynamic>['23:59', '00:00']);
      expect(invertedMidnight.startMinutes, 1439);
      expect(invertedMidnight.endMinutes, 0);
      expect(invertedMidnight.isValid, false, reason: 'startMinutes must be strictly less than endMinutes');

      final TimeInterval zeroDuration = TimeInterval.fromJson(<dynamic>['12:00', '12:00']);
      expect(zeroDuration.isValid, false, reason: 'Zero duration interval must be invalid');
    });

    test('Multiday overnight interval wrapping is marked invalid within single-day model', () {
      final TimeInterval overnight = TimeInterval.fromJson(<dynamic>['22:00', '06:00']);
      expect(overnight.startMinutes, 1320);
      expect(overnight.endMinutes, 360);
      expect(overnight.isValid, false);
    });

    test('Sunday to Monday status transitions and multiday lookahead', () {
      // Monday opens at 08:00, all other days closed
      const WorkingHours monOnly = WorkingHours(
        timezone: 'UTC',
        mon: <TimeInterval>[TimeInterval(start: '08:00', end: '17:00')],
      );

      // Sunday night 23:30 (2026-09-13 is Sunday)
      final DateTime sundayNight = DateTime(2026, 9, 13, 23, 30);
      expect(sundayNight.weekday, DateTime.sunday);
      expect(monOnly.isOpenNow(sundayNight), false);
      expect(monOnly.getStatusText(sundayNight), 'Откроется в пн в 08:00');

      // Sunday morning 07:00 with Sunday opening at 10:00
      const WorkingHours sunAndMon = WorkingHours(
        timezone: 'UTC',
        mon: <TimeInterval>[TimeInterval(start: '08:00', end: '17:00')],
        sun: <TimeInterval>[TimeInterval(start: '10:00', end: '16:00')],
      );
      final DateTime sundayMorning = DateTime(2026, 9, 13, 7, 0);
      expect(sunAndMon.isOpenNow(sundayMorning), false);
      expect(sunAndMon.getStatusText(sundayMorning), 'Откроется сегодня в 10:00');

      // Sunday open at 12:00
      final DateTime sundayNoon = DateTime(2026, 9, 13, 12, 0);
      expect(sunAndMon.isOpenNow(sundayNoon), true);
      expect(sunAndMon.getStatusText(sundayNoon), 'Открыто до 16:00');

      // Sunday after close at 18:00 -> should look ahead to Monday
      final DateTime sundayEvening = DateTime(2026, 9, 13, 18, 0);
      expect(sunAndMon.isOpenNow(sundayEvening), false);
      expect(sunAndMon.getStatusText(sundayEvening), 'Откроется в пн в 08:00');

      // Sunday only schedule: Monday looking ahead 6 days to next Sunday
      const WorkingHours sunOnly = WorkingHours(
        timezone: 'UTC',
        sun: <TimeInterval>[TimeInterval(start: '10:00', end: '18:00')],
      );
      final DateTime mondayMorning = DateTime(2026, 9, 14, 9, 0);
      expect(mondayMorning.weekday, DateTime.monday);
      expect(sunOnly.isOpenNow(mondayMorning), false);
      expect(sunOnly.getStatusText(mondayMorning), 'Откроется в вс в 10:00');
    });

    test('4-interval daily schedule with 3 breaks between shifts', () {
      const WorkingHours fourShifts = WorkingHours(
        timezone: 'UTC',
        tue: <TimeInterval>[
          TimeInterval(start: '08:00', end: '10:00'),
          TimeInterval(start: '11:00', end: '13:00'),
          TimeInterval(start: '14:00', end: '16:00'),
          TimeInterval(start: '17:00', end: '19:00'),
        ],
      );

      // Tuesday test dates (2026-09-08 is Tuesday)
      final DateTime tueBefore = DateTime(2026, 9, 8, 7, 30);
      expect(fourShifts.isOpenNow(tueBefore), false);
      expect(fourShifts.getStatusText(tueBefore), 'Откроется сегодня в 08:00');

      final DateTime tueShift1 = DateTime(2026, 9, 8, 9, 0);
      expect(fourShifts.isOpenNow(tueShift1), true);
      expect(fourShifts.getStatusText(tueShift1), 'Открыто до 10:00');

      final DateTime tueBreak1 = DateTime(2026, 9, 8, 10, 30);
      expect(fourShifts.isOpenNow(tueBreak1), false);
      expect(fourShifts.getStatusText(tueBreak1), 'Откроется сегодня в 11:00');

      final DateTime tueShift2 = DateTime(2026, 9, 8, 12, 0);
      expect(fourShifts.isOpenNow(tueShift2), true);
      expect(fourShifts.getStatusText(tueShift2), 'Открыто до 13:00');

      final DateTime tueBreak2 = DateTime(2026, 9, 8, 13, 15);
      expect(fourShifts.isOpenNow(tueBreak2), false);
      expect(fourShifts.getStatusText(tueBreak2), 'Откроется сегодня в 14:00');

      final DateTime tueShift3 = DateTime(2026, 9, 8, 15, 0);
      expect(fourShifts.isOpenNow(tueShift3), true);
      expect(fourShifts.getStatusText(tueShift3), 'Открыто до 16:00');

      final DateTime tueBreak3 = DateTime(2026, 9, 8, 16, 45);
      expect(fourShifts.isOpenNow(tueBreak3), false);
      expect(fourShifts.getStatusText(tueBreak3), 'Откроется сегодня в 17:00');

      final DateTime tueShift4 = DateTime(2026, 9, 8, 18, 30);
      expect(fourShifts.isOpenNow(tueShift4), true);
      expect(fourShifts.getStatusText(tueShift4), 'Открыто до 19:00');

      final DateTime tueAfter = DateTime(2026, 9, 8, 20, 0);
      expect(fourShifts.isOpenNow(tueAfter), false);
      expect(fourShifts.getStatusText(tueAfter), 'Откроется в вт в 08:00');
    });

    test('Malformed and corrupt JSON input handling in WorkingHours', () {
      final WorkingHours parsed = WorkingHours.fromJson(<String, dynamic>{
        'timezone': 'Europe/Paris',
        'mon': 'not-a-list',
        'tue': <dynamic>[null, 123, 'string'],
        'wed': <dynamic>[
          <dynamic>['invalid', 'time'],
          <dynamic>['10:00', '18:00'],
        ],
        'thu': <dynamic>[
          <dynamic>['08:00', '10:00'],
          <dynamic>['10:30', '12:30'],
          <dynamic>['13:00', '15:00'],
          <dynamic>['15:30', '17:30'],
          <dynamic>['18:00', '20:00'], // 5th interval
          <dynamic>['20:30', '22:00'], // 6th interval
        ],
      });

      expect(parsed.mon, isEmpty, reason: 'Non-list raw value must result in empty interval list');
      expect(parsed.tue, isEmpty, reason: 'List of primitives/nulls must filter out to empty');
      expect(parsed.wed.length, 2);
      expect(parsed.wed.first.isValid, false);
      expect(parsed.wed.last.isValid, true);
      expect(parsed.thu.length, 4, reason: 'Must strictly cap intervals at 4');
    });

    test('TimeInterval fallback behavior on empty or malformed list', () {
      // When an inner list item has length < 2, TimeInterval.fromJson defaults to 09:00-18:00
      final TimeInterval defEmpty = TimeInterval.fromJson(<dynamic>[]);
      expect(defEmpty.start, '09:00');
      expect(defEmpty.end, '18:00');
      expect(defEmpty.isValid, true);

      final TimeInterval defSingle = TimeInterval.fromJson(<dynamic>['11:00']);
      expect(defSingle.start, '09:00');
      expect(defSingle.end, '18:00');

      final TimeInterval defNulls = TimeInterval.fromJson(<dynamic>[null, null]);
      expect(defNulls.start, '09:00');
      expect(defNulls.end, '18:00');
    });

    test('parseMinutes edge cases and robustness', () {
      expect(WorkingHours.parseMinutes('00:00'), 0);
      expect(WorkingHours.parseMinutes('0:0'), 0);
      expect(WorkingHours.parseMinutes('23:59'), 1439);
      expect(WorkingHours.parseMinutes('12:30'), 750);
      expect(WorkingHours.parseMinutes(''), isNull);
      expect(WorkingHours.parseMinutes('abc'), isNull);
      expect(WorkingHours.parseMinutes('12'), isNull);
      expect(WorkingHours.parseMinutes('12:'), isNull);
      expect(WorkingHours.parseMinutes(':30'), isNull);
      expect(WorkingHours.parseMinutes('12:30:45'), isNull);
    });

  });

  group('Adversarial Stress Test: ApiProfile.visibleBadges & Limits', () {
    test('Null, empty, and excessive badge lists handling', () {
      // Empty profile
      const ApiProfile emptyProfile = ApiProfile(
        id: 1,
        username: 'user1',
        displayName: 'User 1',
        bio: '',
      );
      expect(emptyProfile.badges, isEmpty);
      expect(emptyProfile.visibleBadgeIds, isEmpty);
      expect(emptyProfile.visibleBadges, isEmpty);

      // User has 3 badges, visibleBadgeIds empty -> defaults to first 2 badges
      const ApiBadge b1 = ApiBadge(id: 1, name: 'B1', icon: 'i1', color: 'c1');
      const ApiBadge b2 = ApiBadge(id: 2, name: 'B2', icon: 'i2', color: 'c2');
      const ApiBadge b3 = ApiBadge(id: 3, name: 'B3', icon: 'i3', color: 'c3');

      final ApiProfile profileWithBadges = emptyProfile.copyWith(
        badges: <ApiBadge>[b1, b2, b3],
      );
      expect(profileWithBadges.visibleBadges.length, 2);
      expect(profileWithBadges.visibleBadges, <ApiBadge>[b1, b2]);

      // visibleBadgeIds specified in reverse order [3, 1]
      final ApiProfile reverseBadges = profileWithBadges.copyWith(
        visibleBadgeIds: <int>[3, 1],
      );
      expect(reverseBadges.visibleBadges.length, 2);
      expect(reverseBadges.visibleBadges, <ApiBadge>[b3, b1]);

      // visibleBadgeIds contains IDs not in user badges -> falls back safely
      final ApiProfile ghostBadges = profileWithBadges.copyWith(
        visibleBadgeIds: <int>[999, 888],
      );
      expect(ghostBadges.visibleBadges.length, 2);
      expect(ghostBadges.visibleBadges, <ApiBadge>[b1, b2]);

      // visibleBadgeIds contains 1 valid and 1 invalid -> returns the 1 valid
      final ApiProfile partialGhost = profileWithBadges.copyWith(
        visibleBadgeIds: <int>[2, 999],
      );
      expect(partialGhost.visibleBadges.length, 1);
      expect(partialGhost.visibleBadges.first, b2);

      // visibleBadgeIds has >2 entries [3, 2, 1] -> capped at 2
      final ApiProfile excessiveVisible = profileWithBadges.copyWith(
        visibleBadgeIds: <int>[3, 2, 1],
      );
      expect(excessiveVisible.visibleBadges.length, 2);
      expect(excessiveVisible.visibleBadges, <ApiBadge>[b3, b2]);
    });

    test('ApiProfile.fromJson handles non-integer, null, and corrupt visible_badge_ids', () {
      final ApiProfile parsed = ApiProfile.fromJson(<String, dynamic>{
        'id': 100,
        'username': 'corrupt_test',
        'display_name': 'Corrupt Test',
        'bio': 'Test',
        'badges': <dynamic>[
          <String, dynamic>{'id': 10, 'name': 'Ten', 'icon': 'star', 'color': 'gold'},
          <String, dynamic>{'id': 20, 'name': 'Twenty', 'icon': 'shield', 'color': 'silver'},
          <String, dynamic>{'id': 30, 'name': 'Thirty', 'icon': 'crown', 'color': 'bronze'},
        ],
        'visible_badge_ids': <dynamic>['10', null, 'invalid', 30, 20],
      });

      // '10' parses to 10, 30 parses to 30, take(2) caps it
      expect(parsed.visibleBadgeIds, <int>[10, 30]);
      expect(parsed.visibleBadges.map((ApiBadge b) => b.id), <int>[10, 30]);
    });
  });

  group('Adversarial Stress Test: uploadAvatar 8MB Boundary & Video Avatar', () {
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

    test('Exact 8MB boundary: 8 * 1024 * 1024 bytes is ALLOWED', () async {
      fakeWs.nextResponse = <String, dynamic>{
        'avatar_url': 'https://storage/avatars/exact_8mb.jpg',
      };

      final Uint8List exact8MB = Uint8List(8 * 1024 * 1024);
      final String url = await repository.uploadAvatar(
        exact8MB,
        filename: 'exact_8mb.jpg',
      );
      expect(url, 'https://storage/avatars/exact_8mb.jpg');
      expect(fakeWs.requests.last['action'], 'upload_avatar');
    });

    test('8MB + 1 byte is REJECTED with Exception', () async {
      final Uint8List over8MB = Uint8List(8 * 1024 * 1024 + 1);
      expect(
        () => repository.uploadAvatar(over8MB, filename: 'over_limit.jpg'),
        throwsA(isA<Exception>()),
      );
    });

    test('Invalid fileBytes type throws ArgumentError', () async {
      expect(
        () => repository.uploadAvatar('invalid_string_bytes', filename: 'test.jpg'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Video avatar payload sets is_video flag to true', () async {
      fakeWs.nextResponse = <String, dynamic>{
        'avatar_url': 'https://storage/avatars/video_avatar.mp4',
      };

      final Uint8List videoBytes = Uint8List.fromList(<int>[0x00, 0x00, 0x00, 0x1C, 0x66, 0x74, 0x79, 0x70]);
      final String url = await repository.uploadAvatar(
        videoBytes,
        filename: 'avatar.mp4',
        isVideo: true,
      );

      expect(url, 'https://storage/avatars/video_avatar.mp4');
      final Map<String, dynamic> payload = fakeWs.requests.last['payload'] as Map<String, dynamic>;
      expect(payload['is_video'], true);
      expect(payload['filename'], 'avatar.mp4');
      expect(payload['data_base64'], base64Encode(videoBytes));
    });

    test('Static photo avatar payload does NOT include is_video', () async {
      fakeWs.nextResponse = <String, dynamic>{
        'avatar_url': 'https://storage/avatars/photo.jpg',
      };

      final Uint8List photoBytes = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF]);
      final String url = await repository.uploadAvatar(
        photoBytes,
        filename: 'photo.jpg',
        isVideo: false,
      );

      expect(url, 'https://storage/avatars/photo.jpg');
      final Map<String, dynamic> payload = fakeWs.requests.last['payload'] as Map<String, dynamic>;
      expect(payload.containsKey('is_video'), false);
    });
  });

  group('Adversarial Stress Test: WorkingHoursWidget Deterministic Clocks', () {
    testWidgets('Widget renders closed state and lookahead correctly on Sunday night', (WidgetTester tester) async {
      const WorkingHours schedule = WorkingHours(
        timezone: 'UTC',
        mon: <TimeInterval>[TimeInterval(start: '09:00', end: '18:00')],
      );

      final DateTime sunday2300 = DateTime(2026, 9, 13, 23, 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkingHoursWidget(
              workingHours: schedule,
              now: sunday2300,
            ),
          ),
        ),
      );

      expect(find.text('График работы'), findsOneWidget);
      expect(find.text('Откроется в пн в 09:00'), findsOneWidget);
    });

    testWidgets('Widget renders completely empty schedule as SizedBox when not editable', (WidgetTester tester) async {
      const WorkingHours empty = WorkingHours(timezone: 'UTC');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WorkingHoursWidget(
              workingHours: empty,
              isEditable: false,
            ),
          ),
        ),
      );

      expect(find.text('График работы'), findsNothing);
    });

    testWidgets('Widget renders empty state prompt when editable and empty', (WidgetTester tester) async {
      const WorkingHours empty = WorkingHours(timezone: 'UTC');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WorkingHoursWidget(
              workingHours: empty,
              isEditable: true,
            ),
          ),
        ),
      );

      expect(find.text('График работы не настроен'), findsOneWidget);
      expect(find.text('Нажмите, чтобы добавить расписание'), findsOneWidget);
    });
  });
}
