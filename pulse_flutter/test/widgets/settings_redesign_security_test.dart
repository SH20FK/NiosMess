import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/storage/encrypted_message_cache.dart';
import 'package:pulse_flutter/core/storage/hive_bootstrap.dart';
import 'package:pulse_flutter/core/storage/local_storage_service.dart';
import 'package:pulse_flutter/features/sessions/application/sessions_controller.dart';
import 'package:pulse_flutter/features/sessions/data/sessions_repository.dart';
import 'package:pulse_flutter/features/sessions/domain/session_model.dart';
import 'package:pulse_flutter/features/sessions/presentation/session_details_sheet.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/privacy_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/privacy_repository.dart';
import 'package:pulse_flutter/services/bluetooth_mesh/bluetooth_mesh_service.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_service.dart';
import 'package:pulse_flutter/widgets/settings/ordinary_e2ee_settings.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'isolated-a',
      userId: 1,
      username: 'a',
      displayName: 'A',
    ),
  );
  void use(int? id) => state = const AuthState.initial().copyWith(
    session: id == null
        ? null
        : AuthSession(
            accessToken: 'isolated-$id',
            userId: id,
            username: 'u$id',
            displayName: 'Account $id',
          ),
  );
}

class _Ws extends WebSocketClient {
  _Ws() : super(baseUrl: 'wss://isolated.invalid', readToken: () => null);
}

class _Chats extends ChatsNotifier {
  @override
  Future<List<ApiChatSummary>> build() async => const [];
  @override
  Future<void> refresh() async {}
}

AccountSession _session(int id, {bool current = false}) => AccountSession(
  id: id,
  isCurrent: current,
  deviceName: current
      ? 'Current device'
      : 'Another Android device with a long name',
  platform: 'Android',
  ipAddress: '2001:db8:1234:5678:1111:2222:3333:4444',
  appVersion: '3.125.0+4280',
  approximateRegion: 'Test region with a long localized description',
  createdAt: DateTime.utc(2026, 11, 8),
  lastActiveAt: DateTime.utc(2026, 11, 8, 10),
);

typedef _SessionResult = ({
  int? currentSessionId,
  List<AccountSession> sessions,
});

class _SessionsRepo extends SessionsRepository {
  _SessionsRepo(super.ref);
  bool deferLoads = false;
  final loads = <Completer<_SessionResult>>[];
  final revoke = Completer<void>();
  int revokeCalls = 0;
  @override
  Future<_SessionResult> getSessions() async {
    if (deferLoads) {
      final next = Completer<_SessionResult>();
      loads.add(next);
      return next.future;
    }
    return (
      currentSessionId: 1,
      sessions: [_session(1, current: true), _session(2)],
    );
  }

  @override
  Future<void> revokeSession(int sessionId) {
    revokeCalls++;
    return revoke.future;
  }
}

class _PrivacyRepo extends PrivacyRepository {
  _PrivacyRepo(super.ref);
  bool deferLoads = false;
  final loads = <Completer<PrivacySnapshot>>[];
  final write = Completer<PrivacyRuleResult>();
  int writes = 0;
  PrivacySnapshot snapshot = const PrivacySnapshot(
    rules: {'calls': PrivacyRule(key: 'calls', policy: PrivacyPolicy.contacts)},
    revision: 1,
  );
  @override
  Future<PrivacySnapshot> getPrivacySnapshot() {
    if (!deferLoads) return Future.value(snapshot);
    final next = Completer<PrivacySnapshot>();
    loads.add(next);
    return next.future;
  }

  @override
  Future<List<BlockedUser>> listBlockedUsers() async => const [];
  @override
  Future<PrivacyRuleResult> setPrivacy({
    required String key,
    required PrivacyPolicy policy,
    List<int> alwaysAllow = const [],
    List<int> neverAllow = const [],
    int? expectedRevision,
  }) {
    writes++;
    return write.future;
  }
}

class _Encryption extends OrdinaryE2eeService {
  _Encryption(int userId)
    : super(userId, (_, {payload}) async => <String, dynamic>{}) {
    initialised = true;
  }
  final recovery = Completer<String>();
  @override
  String get identityEpoch => 'isolated-epoch-$userId';
  @override
  Future<void> open() async {}
  @override
  Future<String> recoveryCode() => recovery.future;
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings storage safety on a real isolated filesystem', () {
    late Directory root;
    late Directory temp;
    late Directory docs;
    late Directory support;
    late LocalStorageService service;
    Future<File> write(Directory parent, String name, String contents) async {
      final file = File(p.join(parent.path, name));
      await file.parent.create(recursive: true);
      return file.writeAsString(contents);
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      root = await Directory.systemTemp.createTemp('nios_settings_storage_');
      temp = await Directory(p.join(root.path, 'temp')).create();
      docs = await Directory(p.join(root.path, 'documents')).create();
      support = await Directory(p.join(root.path, 'support')).create();
      LocalStorageService.invalidateSnapshotCache();
      service = LocalStorageService(
        temporaryDirectory: () async => temp,
        documentsDirectory: () async => docs,
        supportDirectory: () async => support,
        sandboxedDocuments: false,
      );
    });
    tearDown(() async {
      LocalStorageService.invalidateSnapshotCache();
      await root.delete(recursive: true);
    });
    test(
      'cache cleanup preserves user Temp, pending recordings, outbox and documents',
      () async {
        final foreign = await write(temp, 'other-app/report.txt', 'foreign');
        final recording = await write(
          temp,
          'voice_pending.m4a',
          'pending audio',
        );
        final shared = await write(
          temp,
          'libCachedImageData/other-flutter-app.png',
          'not ours',
        );
        final outbox = await write(
          docs,
          'bluetooth_mesh_ciphertext_v1.hive',
          'queued ciphertext',
        );
        final original = await write(
          docs,
          'secret_attachments/original.enc',
          'protected original',
        );
        final cache = await write(
          temp,
          'nios_private_media_v1/download.png',
          'downloaded copy',
        );
        final playback = await write(
          temp,
          'secret_playback_v2/video.mp4',
          'playback copy',
        );
        expect(
          await service.clearTemporaryFiles(),
          'downloaded copy'.length + 'playback copy'.length,
        );
        expect(await cache.exists(), isFalse);
        expect(await playback.exists(), isFalse);
        for (final file in [foreign, recording, shared, outbox, original]) {
          expect(await file.exists(), isTrue, reason: file.path);
        }
        expect(await outbox.readAsString(), 'queued ciphertext');
        expect(await original.readAsString(), 'protected original');
      },
    );
    test(
      'category cleanup never treats Documents or an unknown hive file as cache',
      () async {
        final original = await write(
          docs,
          'pending/photo.png',
          'original image',
        );
        final history = await write(
          temp,
          'nios_private_media_v1/messages.hive',
          'unexpected history',
        );
        final cached = await write(
          temp,
          'nios_private_media_v1/photo.png',
          'cached image',
        );
        await service.clearCategoryFiles(StorageCategory.images);
        expect(await cached.exists(), isFalse);
        expect(await original.readAsString(), 'original image');
        await service.clearCategoryFiles(StorageCategory.other);
        expect(await history.readAsString(), 'unexpected history');
      },
    );
    test(
      'usage scans app-owned cache roots and never the desktop Documents tree',
      () async {
        await write(docs, 'private_documents/photo.png', 'personal');
        await write(temp, 'other_app/data.bin', 'foreign');
        await write(temp, 'nios_private_media_v1/photo.png', 'cache');
        await write(
          support,
          'nios_protocol/account/attachment.enc',
          'owned data',
        );
        final snapshot = await service.snapshot(forceRefresh: true);
        expect(snapshot.documentsBytes, 0);
        expect(snapshot.temporaryBytes, 'cache'.length);
        expect(snapshot.supportBytes, 'owned data'.length);
        expect(snapshot.totalBytes, 'cache'.length + 'owned data'.length);
      },
    );
    test(
      'cache root and nested symbolic links cannot delete an external file',
      () async {
        final victim = await write(docs, 'original.txt', 'keep');
        try {
          await Link(p.join(temp.path, 'secret_playback_v2')).create(docs.path);
          final cache = await Directory(
            p.join(temp.path, 'nios_private_media_v1'),
          ).create();
          await Link(p.join(cache.path, 'outside.txt')).create(victim.path);
        } on FileSystemException {
          markTestSkipped(
            'Creating isolated symlinks requires OS support or Developer Mode',
          );
          return;
        }
        await service.clearTemporaryFiles();
        expect(await victim.readAsString(), 'keep');
      },
    );
  });

  group('Media cleanup preserves unmigrated secret history', () {
    late Directory directory;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Hive.close();
      directory = await Directory.systemTemp.createTemp(
        'nios_settings_sender_',
      );
      Hive.init(directory.path);
      HiveBootstrap.resetForTesting();
      FlutterSecureStorage.setMockInitialValues({});
      EncryptedMessageCache.resetMemoryForTesting();
      await EncryptedMessageCache.ensureInitialized();
    });
    tearDown(() async {
      await Hive.close();
      HiveBootstrap.resetForTesting();
      EncryptedMessageCache.resetMemoryForTesting();
      await directory.delete(recursive: true);
    });

    Future<({LocalStorageService service, File media})>
    createMediaCache() async {
      final temporary = await Directory(
        p.join(directory.path, 'temp'),
      ).create();
      final cache = await Directory(
        p.join(temporary.path, 'nios_private_media_v1'),
      ).create();
      final media = await File(
        p.join(cache.path, 'download.jpg'),
      ).writeAsString('disposable media');
      return (
        service: LocalStorageService(
          temporaryDirectory: () async => temporary,
          documentsDirectory: () async => directory,
          supportDirectory: () async => directory,
          sandboxedDocuments: false,
        ),
        media: media,
      );
    }

    Future<void> writeLegacyIncoming() async {
      // This old unscoped record is the only source used by the pre-import
      // fallback. The corresponding durable history intentionally stays empty.
      await EncryptedMessageCache.saveMessages(99, [
        ApiMessage.fromJson({
          'id': 7,
          'chat_id': 99,
          'sender_id': 2,
          'content': 'synthetic old incoming',
          'msg_type': 'text',
          'sent_at': '2026-11-08T00:00:00Z',
        }),
      ], isSecretChat: true);
      final archive = await EncryptedHistoryArchive.open(1, 99);
      expect(await archive.read(), isEmpty);
      expect(Hive.box<String>('enc_messages_v1').get('99'), isNotNull);
    }

    Future<void> expectLegacyIncoming() async {
      final messages = await EncryptedMessageCache.loadMessages(
        99,
        userId: 1,
        legacyOwnerUserId: 1,
        strict: true,
      );
      expect(messages.single.senderId, 2);
      expect(messages.single.content, 'synthetic old incoming');
    }

    test(
      'temporary cleanup preserves legacy incoming, own text, history, keys and outbox across restart',
      () async {
        final cache = await createMediaCache();
        await writeLegacyIncoming();
        await EncryptedMessageCache.saveSenderPlaintext(
          chatId: 41,
          messageId: 42,
          plaintext: 'synthetic own text',
          userId: 1,
        );
        final outbox = await Hive.openBox<String>(
          'bluetooth_mesh_ciphertext_v1',
        );
        await outbox.put('queued', 'synthetic ciphertext');
        final archive = await EncryptedHistoryArchive.open(1, 41);
        await archive.write([
          ApiMessage.fromJson({
            'id': 42,
            'chat_id': 41,
            'sender_id': 1,
            'content': 'synthetic own text',
            'msg_type': 'text',
            'sent_at': '2026-11-08T00:00:00Z',
          }),
        ]);
        final keys = await const FlutterSecureStorage().readAll();
        expect(
          await cache.service.clearTemporaryFiles(),
          'disposable media'.length,
        );
        expect(await cache.media.exists(), isFalse);
        await expectLegacyIncoming();
        expect(await const FlutterSecureStorage().readAll(), keys);
        await Hive.close();
        EncryptedMessageCache.resetMemoryForTesting();
        Hive.init(directory.path);
        await EncryptedMessageCache.ensureInitialized();
        await expectLegacyIncoming();
        expect(
          await EncryptedMessageCache.getSenderPlaintext(
            chatId: 41,
            messageId: 42,
            userId: 1,
          ),
          'synthetic own text',
        );
        expect(
          (await Hive.openBox<String>(
            'bluetooth_mesh_ciphertext_v1',
          )).get('queued'),
          'synthetic ciphertext',
        );
        final reopened = await EncryptedHistoryArchive.open(1, 41);
        expect((await reopened.read()).single.content, 'synthetic own text');
        expect(
          await (await EncryptedHistoryArchive.open(1, 99)).read(),
          isEmpty,
        );
      },
    );

    test(
      'media category cleanup preserves legacy incoming and an in-flight sender write',
      () async {
        final cache = await createMediaCache();
        await writeLegacyIncoming();
        final pending = EncryptedMessageCache.saveSenderPlaintext(
          chatId: 41,
          messageId: 43,
          plaintext: 'still saving',
          userId: 1,
        );
        expect(
          await cache.service.clearCategoryFiles(StorageCategory.images),
          'disposable media'.length,
        );
        expect(await cache.media.exists(), isFalse);
        await pending;
        EncryptedMessageCache.resetMemoryForTesting();
        await expectLegacyIncoming();
        expect(
          await EncryptedMessageCache.getSenderPlaintext(
            chatId: 41,
            messageId: 43,
            userId: 1,
          ),
          'still saving',
        );
      },
    );
  });

  group('Settings account isolation and pending actions', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    test(
      'late device-list response from account A cannot replace account B or logout',
      () async {
        late _SessionsRepo repo;
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            sessionsRepositoryProvider.overrideWith(
              (ref) => repo = _SessionsRepo(ref)..deferLoads = true,
            ),
          ],
        );
        addTearDown(container.dispose);
        container.read(sessionsControllerProvider);
        await _flush();
        (container.read(authProvider.notifier) as _Auth).use(2);
        container.read(sessionsControllerProvider);
        await _flush();
        repo.loads[1].complete((
          currentSessionId: 22,
          sessions: [_session(22, current: true)],
        ));
        await _flush();
        repo.loads[0].complete((
          currentSessionId: 11,
          sessions: [_session(11, current: true)],
        ));
        await _flush();
        expect(
          (container.read(sessionsControllerProvider) as SessionsReady)
              .sessions
              .single
              .id,
          22,
        );
        (container.read(authProvider.notifier) as _Auth).use(null);
        expect(
          (container.read(sessionsControllerProvider) as SessionsReady)
              .sessions,
          isEmpty,
        );
        expect(
          await container
              .read(sessionsControllerProvider.notifier)
              .revokeSession(22),
          isFalse,
        );
        expect(repo.revokeCalls, 0);
      },
    );
    test(
      'repeated revoke is suppressed and refresh cannot clear its pending state',
      () async {
        late _SessionsRepo repo;
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            sessionsRepositoryProvider.overrideWith(
              (ref) => repo = _SessionsRepo(ref),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.read(sessionsControllerProvider);
        await _flush();
        final controller = container.read(sessionsControllerProvider.notifier);
        final pending = controller.revokeSession(2);
        expect(await controller.revokeSession(2), isFalse);
        await controller.load();
        expect(
          (container.read(sessionsControllerProvider) as SessionsReady)
              .revokingIds,
          {2},
        );
        expect(repo.revokeCalls, 1);
        repo.revoke.complete();
        expect(await pending, isTrue);
        expect(
          (container.read(sessionsControllerProvider) as SessionsReady).sessions
              .map((s) => s.id),
          [1],
        );
      },
    );
    test(
      'late revoke acknowledgement cannot remove a same-ID device from account B',
      () async {
        late _SessionsRepo repo;
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            sessionsRepositoryProvider.overrideWith(
              (ref) => repo = _SessionsRepo(ref),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.read(sessionsControllerProvider);
        await _flush();
        final pending = container
            .read(sessionsControllerProvider.notifier)
            .revokeSession(2);
        (container.read(authProvider.notifier) as _Auth).use(2);
        container.read(sessionsControllerProvider);
        await _flush();
        repo.revoke.complete();
        expect(await pending, isFalse);
        expect(
          (container.read(sessionsControllerProvider) as SessionsReady).sessions
              .map((s) => s.id),
          [1, 2],
        );
      },
    );

    test(
      'late privacy snapshot cannot carry rules into a different account',
      () async {
        late _PrivacyRepo repo;
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            webSocketClientProvider.overrideWithValue(_Ws()),
            privacyRepositoryProvider.overrideWith(
              (ref) => repo = _PrivacyRepo(ref)..deferLoads = true,
            ),
          ],
        );
        addTearDown(container.dispose);
        container.read(privacyProvider);
        await _flush();
        (container.read(authProvider.notifier) as _Auth).use(2);
        container.read(privacyProvider);
        await _flush();
        repo.loads[1].complete(
          const PrivacySnapshot(
            rules: {
              'calls': PrivacyRule(key: 'calls', policy: PrivacyPolicy.nobody),
            },
            revision: 2,
          ),
        );
        await _flush();
        repo.loads[0].complete(repo.snapshot);
        await _flush();
        expect(
          container.read(privacyProvider).policyFor('calls'),
          PrivacyPolicy.nobody,
        );
        (container.read(authProvider.notifier) as _Auth).use(null);
        expect(container.read(privacyProvider).rules, isEmpty);
      },
    );
    test(
      'late privacy write acknowledgement cannot replace account B rules',
      () async {
        late _PrivacyRepo repo;
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            webSocketClientProvider.overrideWithValue(_Ws()),
            privacyRepositoryProvider.overrideWith(
              (ref) => repo = _PrivacyRepo(ref),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.read(privacyProvider);
        await _flush();
        final pending = container
            .read(privacyProvider.notifier)
            .updateRule(key: 'calls', policy: PrivacyPolicy.nobody);
        (container.read(authProvider.notifier) as _Auth).use(2);
        container.read(privacyProvider);
        await _flush();
        repo.write.complete(
          const PrivacyRuleResult(
            rule: PrivacyRule(key: 'calls', policy: PrivacyPolicy.nobody),
            revision: 5,
          ),
        );
        await pending;
        expect(
          container.read(privacyProvider).policyFor('calls'),
          PrivacyPolicy.contacts,
        );
        expect(container.read(privacyProvider).revision, 1);
        expect(container.read(privacyProvider).pendingRules, isEmpty);
      },
    );

    test(
      'failed privacy write restores rule and pending state without a second write',
      () async {
        late _PrivacyRepo repo;
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            webSocketClientProvider.overrideWithValue(_Ws()),
            chatsProvider.overrideWith(_Chats.new),
            privacyRepositoryProvider.overrideWith(
              (ref) => repo = _PrivacyRepo(ref),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.read(privacyProvider);
        await _flush();
        final controller = container.read(privacyProvider.notifier);
        final pending = controller.updateRule(
          key: 'calls',
          policy: PrivacyPolicy.nobody,
        );
        expect(
          container.read(privacyProvider).policyFor('calls'),
          PrivacyPolicy.nobody,
        );
        expect(container.read(privacyProvider).pendingRules, {'calls'});
        await expectLater(
          controller.updateRule(key: 'calls', policy: PrivacyPolicy.everyone),
          throwsStateError,
        );
        final check = expectLater(pending, throwsStateError);
        repo.write.completeError(StateError('synthetic failure'));
        await check;
        expect(repo.writes, 1);
        expect(
          container.read(privacyProvider).policyFor('calls'),
          PrivacyPolicy.contacts,
        );
        expect(container.read(privacyProvider).pendingRules, isEmpty);
      },
    );
  });

  testWidgets('a pending recovery key never appears after changing accounts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final first = _Encryption(1);
    final second = _Encryption(2);
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_Auth.new),
        ordinaryE2eeProvider.overrideWithValue(first),
        bluetoothMeshProvider.overrideWithValue(null),
        chatsProvider.overrideWith(_Chats.new),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(useMaterial3: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(child: OrdinaryE2eeSettings()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Show recovery key'));
    await tester.tap(find.text('Show recovery key'));
    await tester.pump();
    container.updateOverrides([
      authProvider.overrideWith(_Auth.new),
      ordinaryE2eeProvider.overrideWithValue(second),
      bluetoothMeshProvider.overrideWithValue(null),
      chatsProvider.overrideWith(_Chats.new),
    ]);
    await tester.pumpAndSettle();
    first.recovery.complete('old-account-recovery-must-stay-hidden');
    await tester.pumpAndSettle();
    expect(find.text('old-account-recovery-must-stay-hidden'), findsNothing);
    expect(find.text('Personal chats · E2E preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final brightness in Brightness.values) {
    for (final language in ['ru', 'en']) {
      testWidgets(
        'session detail fits 320dp and 200% text: $brightness $language',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authProvider.overrideWith(_Auth.new),
                sessionsRepositoryProvider.overrideWith(_SessionsRepo.new),
              ],
              child: MaterialApp(
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: ThemeData(
                  useMaterial3: true,
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xff6750a4),
                    brightness: brightness,
                  ),
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(2),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: SessionDetailsSheet(
                      session: _session(2),
                      accountId: 1,
                      accountToken: 'isolated-a',
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text('2001:db8:1234:5678:1111:2222:3333:4444'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
