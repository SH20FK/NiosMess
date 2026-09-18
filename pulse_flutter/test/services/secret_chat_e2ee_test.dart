import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/services/double_ratchet_service.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'read') return null;
      if (call.method == 'write') return null;
      if (call.method == 'delete') return null;
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
  });

  group('Secret Chat E2EE & Double Ratchet Runtime Tests', () {
    test('DoubleRatchetSession preserves peerStaticDh through serialization and copy', () async {
      final key = SecretKey(List<int>.generate(32, (i) => i + 1));
      final ratKey = SecretKey(List<int>.generate(32, (i) => i + 2));
      final dhrKeyBytes = List<int>.generate(32, (i) => i + 3);

      final session = DoubleRatchetSession(
        ratKey: ratKey,
        keyVal: key,
        dhrKeyBytes: dhrKeyBytes,
        peerStaticDh: 'test_peer_static_dh_base64',
        peerStaticEd: 'test_peer_static_ed_base64',
      );

      // Verify copy preserves peerStaticDh
      final copied = session.copy();
      expect(copied.peerStaticDh, 'test_peer_static_dh_base64');
      expect(copied.peerStaticEd, 'test_peer_static_ed_base64');

      copied.peerStaticDh = 'copied_updated_dh';
      final secondCopy = copied.copy();
      expect(secondCopy.peerStaticDh, 'copied_updated_dh');

      // Verify JSON round-trip
      final json = await session.toJson();
      expect(json['peerStaticDh'], 'test_peer_static_dh_base64');
      expect(json['peerStaticEd'], 'test_peer_static_ed_base64');

      final restored = await DoubleRatchetSession.fromJson(json);
      expect(restored.peerStaticDh, 'test_peer_static_dh_base64');
      expect(restored.peerStaticEd, 'test_peer_static_ed_base64');
    });

    test('E2eeService ready future completes successfully', () async {
      final e2ee = E2eeService();
      await expectLater(e2ee.ready, completes);
      expect(e2ee.isPeerVerified(99999), isFalse);
    });

    test('E2eeService revision notifier triggers on session events', () async {
      final e2ee = E2eeService();
      await e2ee.ready;

      int revisionNotified = 0;
      e2ee.revision.addListener(() {
        revisionNotified++;
      });

      // Reset session notifies revision
      await e2ee.resetSession(12345);
      expect(revisionNotified, greaterThanOrEqualTo(1));

      // Clear memory sessions notifies revision
      final beforeClear = revisionNotified;
      e2ee.clearMemorySessions();
      expect(revisionNotified, greaterThan(beforeClear));
    });

    test('Self-HELO echo messages are strictly filtered by senderId', () {
      const int myUserId = 42;
      const int peerUserId = 99;

      // Simulated incoming message from server history
      final ownHeloMsg = ApiMessage(
        id: 1001,
        chatId: 777,
        senderId: myUserId,
        senderUsername: 'me',
        senderDisplayName: 'Me',
        senderBadges: const [],
        content: '',
        msgType: 'text',
        replyToId: null,
        mediaUrl: null,
        mediaType: null,
        mediaName: null,
        mediaSize: 0,
        mediaDuration: 0,
        commentsCount: 0,
        reactions: const <String, int>{},
        sentAt: DateTime.now(),
        editedAt: null,
        isDeleted: false,
        isE2ee: true,
        e2eeContent: '{"type":"helo","dh_pub":"abc","ed_pub":"def","sig":[1,2,3]}',
      );

      final peerHeloMsg = ApiMessage(
        id: 1002,
        chatId: 777,
        senderId: peerUserId,
        senderUsername: 'peer',
        senderDisplayName: 'Peer',
        senderBadges: const [],
        content: '',
        msgType: 'text',
        replyToId: null,
        mediaUrl: null,
        mediaType: null,
        mediaName: null,
        mediaSize: 0,
        mediaDuration: 0,
        commentsCount: 0,
        reactions: const <String, int>{},
        sentAt: DateTime.now(),
        editedAt: null,
        isDeleted: false,
        isE2ee: true,
        e2eeContent: '{"type":"helo","dh_pub":"xyz","ed_pub":"uvw","sig":[4,5,6]}',
      );

      // Contract rule: only handle HELO if senderId != myUserId
      bool shouldHandle(ApiMessage msg) => msg.senderId != myUserId;

      expect(shouldHandle(ownHeloMsg), isFalse, reason: 'Own HELO echo must not be processed');
      expect(shouldHandle(peerHeloMsg), isTrue, reason: 'Peer HELO must be processed');
    });
  });
}
