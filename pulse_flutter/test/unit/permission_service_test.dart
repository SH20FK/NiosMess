import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pulse_flutter/services/permission_service.dart';
import 'package:universal_io/io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final requested = <List<int>>[];
  var microphoneGranted = true;

  setUp(() {
    requested.clear();
    microphoneGranted = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'requestPermissions') {
        throw StateError('Unexpected permission operation: ${call.method}');
      }
      final values = List<int>.from(call.arguments as List);
      requested.add(values);
      return <int, int>{
        for (final value in values)
          value: value == Permission.microphone.value && !microphoneGranted
              ? 0
              : 1,
      };
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('constructing the service never requests permissions', () async {
    expect(identical(PermissionService(), PermissionService()), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(requested, isEmpty);
  });

  test('voice action requests microphone only', () async {
    expect(await PermissionService().requestCallPermissions(), isTrue);
    expect(requested, <List<int>>[
      [Permission.microphone.value],
    ]);
  });

  test('video action requests microphone then camera', () async {
    expect(
      await PermissionService().requestCallPermissions(video: true),
      isTrue,
    );
    expect(requested, <List<int>>[
      [Permission.microphone.value],
      [Permission.camera.value],
    ]);
  });

  test('denied microphone does not trigger a second camera prompt', () async {
    microphoneGranted = false;
    expect(
      await PermissionService().requestCallPermissions(video: true),
      isFalse,
    );
    expect(requested, <List<int>>[
      [Permission.microphone.value],
    ]);
  });

  test(
    'bootstrap does not request native permissions behind the action prompt',
    () {
      final shell = File(
        'lib/screens/main_shell_screen.dart',
      ).readAsStringSync();
      final push = File(
        'lib/core/services/push_notification_service.dart',
      ).readAsStringSync();
      expect(shell, isNot(contains('requestInitialPermissionsIfNeeded')));
      expect(push, contains('requestAlertPermission: false'));
      expect(push, contains('requestBadgePermission: false'));
      expect(push, contains('requestSoundPermission: false'));
    },
  );
}
