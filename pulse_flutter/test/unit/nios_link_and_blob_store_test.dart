import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/blob_store_models.dart';
import 'package:pulse_flutter/models/nios_link_models.dart';
import 'package:pulse_flutter/services/blob_hasher.dart';
import 'package:pulse_flutter/services/nios_link_service.dart';

void main() {
  group('NiosLink Protocol Suite', () {
    test('Parse native nios://chat/<token>', () {
      final parsed = NiosLinkService.parseLink('nios://chat/nl_chat_abc123.def456');
      expect(parsed, isNotNull);
      expect(parsed!.type, equals(NiosLinkType.chat));
      expect(parsed.token, equals('nl_chat_abc123.def456'));
      expect(parsed.canonicalNativeUri, equals('nios://chat/nl_chat_abc123.def456'));
      expect(parsed.canonicalWebUrl, equals('https://ni-os.ru/l/c/nl_chat_abc123.def456'));
    });

    test('Parse native nios://device/pair/<token>', () {
      final parsed = NiosLinkService.parseLink('nios://device/pair/nl_pair_qr777.sig888');
      expect(parsed, isNotNull);
      expect(parsed!.type, equals(NiosLinkType.pair));
      expect(parsed.token, equals('nl_pair_qr777.sig888'));
      expect(parsed.canonicalNativeUri, equals('nios://device/pair/nl_pair_qr777.sig888'));
      expect(parsed.canonicalWebUrl, equals('https://ni-os.ru/l/pair/nl_pair_qr777.sig888'));
    });

    test('Parse native nios://message/<token>', () {
      final parsed = NiosLinkService.parseLink('nios://message/nl_msg_001.sig002');
      expect(parsed, isNotNull);
      expect(parsed!.type, equals(NiosLinkType.message));
      expect(parsed.token, equals('nl_msg_001.sig002'));
    });

    test('Parse native nios://file/<token>', () {
      final parsed = NiosLinkService.parseLink('nios://file/nl_file_doc.sig');
      expect(parsed, isNotNull);
      expect(parsed!.type, equals(NiosLinkType.file));
      expect(parsed.token, equals('nl_file_doc.sig'));
    });

    test('Parse native nios://transfer/<token>', () {
      final parsed = NiosLinkService.parseLink('nios://transfer/nl_tx_sess.sig');
      expect(parsed, isNotNull);
      expect(parsed!.type, equals(NiosLinkType.transfer));
    });

    test('Parse web fallback URLs on ni-os.ru', () {
      final wChat = NiosLinkService.parseLink('https://ni-os.ru/l/c/nl_chat_w1.sig');
      expect(wChat, isNotNull);
      expect(wChat!.type, equals(NiosLinkType.chat));
      expect(wChat.token, equals('nl_chat_w1.sig'));

      final wFile = NiosLinkService.parseLink('https://ni-os.ru/l/f/nl_file_w2.sig');
      expect(wFile, isNotNull);
      expect(wFile!.type, equals(NiosLinkType.file));
      expect(wFile.token, equals('nl_file_w2.sig'));

      final wPair = NiosLinkService.parseLink('https://ni-os.ru/l/pair/nl_pair_w3.sig');
      expect(wPair, isNotNull);
      expect(wPair!.type, equals(NiosLinkType.pair));
      expect(wPair.token, equals('nl_pair_w3.sig'));
    });

    test('Reject invalid or foreign links', () {
      expect(NiosLinkService.parseLink(''), isNull);
      expect(NiosLinkService.parseLink('https://google.com'), isNull);
      expect(NiosLinkService.parseLink('https://ni-os.ru/random_page'), isNull);
    });

    test('NiosLinkResolution model parsing', () {
      final resJson = <String, dynamic>{
        'status': 'valid',
        'token_type': 'chat',
        'target_type': 'chat',
        'target_id': '42',
        'chat': <String, dynamic>{'id': 42, 'title': 'Test Group'},
      };
      final resolution = NiosLinkResolution.fromJson(resJson);
      expect(resolution.status, equals('valid'));
      expect(resolution.chatId, equals(42));
      expect(resolution.tokenType, equals('chat'));
    });
  });

  group('NiosBlobStore & Content-Addressed Storage Suite', () {
    test('Adaptive chunk sizing thresholds', () {
      expect(BlobHasher.determineChunkSize(500 * 1024), equals(256 * 1024));
      expect(BlobHasher.determineChunkSize(50 * 1024 * 1024), equals(1024 * 1024));
      expect(BlobHasher.determineChunkSize(200 * 1024 * 1024), equals(4 * 1024 * 1024));
    });

    test('BlobCheckResult model parsing', () {
      final hit = BlobCheckResult.fromJson(<String, dynamic>{
        'already_exists': true,
        'blob_id': 'blb_hit123',
        'status': 'ready',
        'missing_chunks': <dynamic>[],
      });
      expect(hit.alreadyExists, isTrue);
      expect(hit.missingChunks, isEmpty);

      final miss = BlobCheckResult.fromJson(<String, dynamic>{
        'already_exists': false,
        'blob_id': 'blb_miss456',
        'status': 'uploading',
        'missing_chunks': <dynamic>[0, 2, 5],
      });
      expect(miss.alreadyExists, isFalse);
      expect(miss.missingChunks, equals(<int>[0, 2, 5]));
    });

    test('BlobCommitResult model parsing', () {
      final commit = BlobCommitResult.fromJson(<String, dynamic>{
        'blob_id': 'blb_ready',
        'status': 'ready',
        'size': 8192,
        'content_hash': 'sha256hexabc',
      });
      expect(commit.status, equals('ready'));
      expect(commit.size, equals(8192));
      expect(commit.blobId, equals('blb_ready'));
    });

    test('BlobAttachResult model parsing', () {
      final attach = BlobAttachResult.fromJson(<String, dynamic>{
        'ref_id': 'att_999',
        'blob_id': 'blb_ready',
        'filename': 'archive.zip',
        'size': 8192,
        'mime_type': 'application/zip',
      });
      expect(attach.refId, equals('att_999'));
      expect(attach.filename, equals('archive.zip'));
    });
  });
}
