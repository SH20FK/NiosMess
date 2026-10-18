import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:iroh_quic/iroh_quic.dart' as iroh;
import 'package:nios_iroh/nios_iroh.dart';
import 'package:nios_sdk/link.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  test(
    'native Postcard rendezvous interoperates with the real Python service',
    () async {
      await iroh.Iroh.init();
      final temporary = await Directory.systemTemp.createTemp(
        'nios_rendezvous_',
      );
      final aliceSecret = iroh.SecretKey.generate();
      final bobSecret = iroh.SecretKey.generate();
      final aliceLink = await crypto.Ed25519().newKeyPair();
      final bobLink = await crypto.Ed25519().newKeyPair();
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();
      final repository = Directory.current.parent.parent.absolute;
      final process = await Process.start(
        Platform.environment['NIOS_PROTOCOL_TEST_PYTHON']!,
        ['-c', _pythonDirectory, temporary.path, '$port'],
        environment: {
          'PYTHONPATH': '${repository.path}/backend_changes/protocol_v1',
        },
      );
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());
      process.stdin.write(
        jsonEncode({
          'alice': {
            'link': base64Encode((await aliceLink.extractPublicKey()).bytes),
            'endpoint': base64Encode(aliceSecret.publicKey.asBytes()),
          },
          'bob': {
            'link': base64Encode((await bobLink.extractPublicKey()).bytes),
            'endpoint': base64Encode(bobSecret.publicKey.asBytes()),
          },
        }),
      );
      await process.stdin.close();
      final uri = Uri.parse('http://127.0.0.1:$port');
      final a = _client(uri, 'alice');
      final b = _client(uri, 'bob');
      IrohLinkTransport? alice;
      IrohLinkTransport? bob;
      try {
        final probe = http.Client();
        try {
          var ready = false;
          for (var attempt = 0; attempt < 100; attempt++) {
            try {
              final response = await probe
                  .get(
                    uri.resolve('/v1/protocols'),
                    headers: {'authorization': 'Bearer token-alice'},
                  )
                  .timeout(const Duration(seconds: 1));
              if (response.statusCode == 200) {
                ready = true;
                break;
              }
            } catch (_) {
              // The child is still binding its loopback socket.
            }
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
          if (!ready) throw StateError('python_rendezvous_not_ready');
        } finally {
          probe.close();
        }
        alice = await IrohLinkTransport.bind(
          deviceId: 'alice',
          identity: aliceSecret,
          onOperation: (value) async => _ack(value),
          onAcknowledgement: (_) async {},
        );
        bob = await IrohLinkTransport.bind(
          deviceId: 'bob',
          identity: bobSecret,
          onOperation: (value) async => _ack(value),
          onAcknowledgement: (_) async {},
        );
        await _waitAddress(alice);
        await _waitAddress(bob);
        await a.publish(
          address: alice.address,
          endpointIdentity: aliceSecret,
          linkSigningKey: aliceLink,
          revision: 1,
        );
        await b.publish(
          address: bob.address,
          endpointIdentity: bobSecret,
          linkSigningKey: bobLink,
          revision: 1,
        );
        alice.setPeer(
          (await a.lookup(
            peerAccountId: 'account-bob',
            peerDeviceId: 'bob',
            pinnedEndpointId: bob.endpointId,
            pinnedLinkSigningKey: await bobLink.extractPublicKey(),
            chatId: 77,
          )).peer,
        );
        bob.setPeer(
          (await b.lookup(
            peerAccountId: 'account-alice',
            peerDeviceId: 'alice',
            pinnedEndpointId: alice.endpointId,
            pinnedLinkSigningKey: await aliceLink.extractPublicKey(),
            chatId: 77,
          )).peer,
        );
        final receipt = await alice.deliver(_operation());
        expect(receipt.acknowledgement!.context.kind, 'ack');
      } finally {
        await a.close();
        await b.close();
        await alice?.close();
        await bob?.close();
        process.kill(ProcessSignal.sigkill);
        await process.exitCode.timeout(const Duration(seconds: 10));
        await temporary.delete(recursive: true);
      }
    },
    skip: Platform.environment['NIOS_PROTOCOL_TEST_PYTHON'] == null
        ? 'Set NIOS_PROTOCOL_TEST_PYTHON; this interoperability test is mandatory in CI.'
        : false,
    timeout: const Timeout(Duration(seconds: 45)),
  );
}

IrohRendezvousClient _client(Uri uri, String device) => IrohRendezvousClient(
  baseUri: uri,
  accountId: 'account-$device',
  deviceId: device,
  bearerToken: 'token-$device',
  allowInsecureLoopback: true,
);

Future<void> _waitAddress(IrohLinkTransport transport) async {
  for (var i = 0; i < 500; i++) {
    if (transport.address.ipAddrs.isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  throw StateError('native_iroh_address_unavailable');
}

EncryptedEnvelope _operation() => EncryptedEnvelope(
  context: const EnvelopeContext(
    senderId: 'alice',
    recipientId: 'bob',
    sessionId: 'test',
    operationId: 'one',
    sequence: 1,
  ),
  nonce: List.filled(12, 0),
  ciphertext: [1],
  mac: List.filled(16, 0),
);

EncryptedEnvelope _ack(EncryptedEnvelope operation) => EncryptedEnvelope(
  context: EnvelopeContext(
    senderId: operation.context.recipientId,
    recipientId: operation.context.senderId,
    sessionId: operation.context.sessionId,
    operationId: operation.context.operationId,
    sequence: operation.context.sequence,
    kind: 'ack',
  ),
  nonce: List.filled(12, 0),
  ciphertext: [2],
  mac: List.filled(16, 0),
);

const _pythonDirectory = r"""
import asyncio,json,sys,time
from pathlib import Path
import uvicorn
from fastapi import HTTPException
from nios_protocol.app import create_app
from nios_protocol.auth import Principal,canonical
from nios_protocol.store import ProtocolStore
from nios_protocol.iroh import create_iroh_router
config=json.load(sys.stdin)
root=Path(sys.argv[1])
store=ProtocolStore(root/'protocol.sqlite3',root/'data')
async def seed():
    def insert(conn):
        for number,(device,keys) in enumerate(config.items(),1):
            account='account-'+device
            conn.execute('INSERT INTO identities VALUES(?,?,?)',(account,keys['link'],int(time.time()*1000)))
            conn.execute('''INSERT INTO devices(device_id,account_id,user_id,session_id,identity_key,link_key,endpoint_key,capabilities,created_at,updated_at)
                VALUES(?,?,?,?,?,?,?,?,?,?)''',(device,account,number,100+number,keys['link'],keys['link'],keys['endpoint'],canonical({'link':[1],'irohAlpn':['nios.link/1']}).decode(),0,0))
    await store.transaction(insert)
asyncio.run(seed())
async def auth(request):
    token=request.headers.get('authorization','')
    for number,device in enumerate(config,1):
        if token=='Bearer token-'+device:
            return Principal('account-'+device,number,100+number)
    raise HTTPException(401,'unauthorized')
async def authorize(principal,chat_id,target):
    return chat_id==77 and target in config
app=create_app(store,auth)
app.include_router(create_iroh_router(store,auth,authorize))
uvicorn.run(app,host='127.0.0.1',port=int(sys.argv[2]),log_level='critical',access_log=False)
""";
