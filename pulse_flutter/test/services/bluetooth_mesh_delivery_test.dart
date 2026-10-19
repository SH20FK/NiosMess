import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pulse_flutter/core/storage/hive_bootstrap.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/ble_transport.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/bluetooth_mesh_service.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/mesh_history.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_codec.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';

class Radio implements BleTransport {
  final controller = StreamController<Map<String, dynamic>>.broadcast();
  Radio? other;
  @override
  Stream<Map<String, dynamic>> get events => controller.stream;
  @override
  Future<Map<String, dynamic>> start({bool requestPermission = false}) async =>
      {'state': 'active'};
  @override
  Future<void> stop() async {}
  @override
  Future<void> send(String peer, Uint8List bytes) async {
    other?.controller.add({'type': 'frame', 'peer': 'peer', 'data': bytes});
  }

  void connect() =>
      controller.add({'type': 'peer', 'peer': 'peer', 'connected': true});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'offline restart, authenticated delivery, acknowledgement, encrypted disk and cloud merge',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp(
        'nios-mesh-test-',
      );
      Hive.init(directory.path);
      HiveBootstrap.resetForTesting();
      final identities = <int, E2eJson>{}, backups = <int, String>{};
      var online = true;
      final services = <OrdinaryE2eeService>[];
      OrdinaryE2eeService makeOrdinary(
        int user, {
        String? tag,
      }) => OrdinaryE2eeService(
        user,
        (action, {payload}) async {
          if (!online) {
            throw StateError('No network request is allowed offline');
          }
          final p = payload!;
          switch (p['op']) {
            case 'status':
              return {
                'account_subject': 'subject-$user',
                'identity': identities[user],
                'backup': backups[user],
                'enabled': true,
                'mesh_relay': 1,
              };
            case 'register':
              identities[user] = OrdinaryCodec.canonical(p);
              backups[user] = p['backup'] as String;
              return {'identity': identities[user]};
            case 'chat':
              return {
                'eligible': true,
                'required': true,
                'own': identities[user],
                'peer': identities[user == 1 ? 2 : 1],
              };
            case 'mesh_permit':
              final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
              final claims = {
                'v': 1,
                'user': user,
                'epoch': identities[user]!['epoch'],
                'author': identities[user]!['ed'],
                'device': p['device'],
                'session': user,
                'iat': now,
                'exp': now + 3 * 86400,
                'nonce': p['nonce'],
              };
              return {
                'permit':
                    '${base64UrlEncode(utf8.encode(jsonEncode(claims))).replaceAll('=', '')}.${base64UrlEncode(List.filled(32, 1)).replaceAll('=', '')}',
              };
          }
          throw StateError('Unexpected operation');
        },
        isOnline: () => online,
        meshEnabled: () => true,
        offlineSessionTag: tag ?? 'session-$user',
      );
      final alice = makeOrdinary(1), bob = makeOrdinary(2);
      services.addAll([alice, bob]);
      await alice.open();
      await bob.open();
      await alice.prepare(11, force: true);
      await bob.prepare(11, force: true);
      await alice.prepareMesh();
      await bob.prepareMesh();
      online = false;
      final restarted = makeOrdinary(1);
      services.add(restarted);
      await restarted.open();
      expect(restarted.locked, isFalse);
      await expectLater(restarted.setEnabled(false), throwsStateError);
      final foreign = makeOrdinary(1, tag: 'different-login');
      services.add(foreign);
      await expectLater(foreign.open(), throwsStateError);
      final radios = [Radio(), Radio()];
      radios[0].other = radios[1];
      radios[1].other = radios[0];
      final meshes = <BluetoothMeshService>[];
      final cloud = <String, int>{};
      for (var i = 0; i < 2; i++) {
        final ordinary = i == 0 ? restarted : bob;
        meshes.add(
          BluetoothMeshService(
            userId: i + 1,
            scope: () => ordinary.meshStorageScope,
            ordinary: ordinary,
            transport: radios[i],
            enabled: () => true,
            online: () => online,
            chat: (id) => id == 11
                ? ApiChatSummary(
                    id: 11,
                    chatType: 'direct',
                    name: 'Чат',
                    unreadCount: 0,
                    membersCount: 2,
                    partnerUserId: i == 0 ? 2 : 1,
                  )
                : null,
            cloudSubmit: (packet) async {
              final h = OrdinaryCodec.header(packet.envelope);
              final id = cloud.putIfAbsent(
                h['id'] as String,
                () => cloud.length + 100,
              );
              return ApiMessage.fromJson({
                'id': id,
                'chat_id': 11,
                'sender_id': h['sender'],
                'content': '',
                'is_e2ee': true,
                'e2ee_content': packet.envelope,
                'sent_at': DateTime.now().toIso8601String(),
              });
            },
          ),
        );
      }
      try {
        await meshes[0].start();
        await meshes[1].start();
        radios[0].connect();
        radios[1].connect();
        final sent = await meshes[0].sendText(11, 'Сообщение без интернета');
        for (
          var i = 0;
          i < 150 && (!sent.acknowledged || meshes[1].messages(11).isEmpty);
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(meshes[1].messages(11).single.text, 'Сообщение без интернета');
        expect(sent.acknowledged, isTrue);
        final stored = Hive.box<String>(
          'bluetooth_mesh_ciphertext_v1',
        ).values.join();
        expect(stored, isNot(contains('Сообщение без интернета')));
        online = true;
        await meshes[0].flushCloud();
        await meshes[1].flushCloud();
        expect(cloud.length, 1);
        expect(sent.cloudId, 100);
        final local = sent.asApi(ownId: 1, senderName: 'Я');
        final negative = local.copyWith(id: sent.localId);
        expect(
          mergeMeshHistory([negative, local], [negative]).map((m) => m.id),
          [100],
        );
        await meshes[1].hide(meshes[1].messages(11).single.localId);
        await meshes[1].replay();
        expect(meshes[1].messages(11), isEmpty);
      } finally {
        for (final mesh in meshes) {
          mesh.dispose();
        }
        for (final radio in radios) {
          await radio.controller.close();
        }
        for (final ordinary in services) {
          ordinary.dispose();
        }
        await Hive.close();
        HiveBootstrap.resetForTesting();
        await directory.delete(recursive: true);
      }
    },
  );
}
