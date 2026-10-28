import 'package:pulse_flutter/services/protocol/nios_protocol_accounts.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/providers/api_provider.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/models/api/working_hours_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/token_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';

const _one = AuthSession(
  accessToken: 'fixture-one',
  userId: 1,
  username: 'one',
  displayName: 'One',
  niosId: 'one@fixture',
);
const _two = AuthSession(
  accessToken: 'fixture-two',
  userId: 2,
  username: 'two',
  displayName: 'Two',
);
ApiProfile _profile(int id) => ApiProfile(
  id: id,
  username: 'user$id',
  displayName: 'User $id',
  bio: 'fixture',
);

class _Auth extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState.initial().copyWith(hydrated: true, session: _one);
  void switchSession(AuthSession? session) => state = state.copyWith(
    session: session,
    clearSession: session == null,
    clearProfile: true,
    clearError: true,
  );
}

class _Storage extends Fake implements FlutterSecureStorage {
  final values = <String, String>{};
  bool failWrites = false;
  bool failDeletes = false;
  @override
  dynamic noSuchMethod(Invocation call) {
    final key = call.namedArguments[#key] as String;
    if (call.memberName == #read) return Future<String?>.value(values[key]);
    if (call.memberName == #write) {
      if (failWrites) {
        return Future<void>.error(StateError('fixture storage unavailable'));
      }
      values[key] = call.namedArguments[#value] as String;
      return Future<void>.value();
    }
    if (call.memberName == #delete) {
      if (failDeletes) {
        return Future<void>.error(StateError('fixture delete failed'));
      }
      values.remove(key);
      return Future<void>.value();
    }
    return super.noSuchMethod(call);
  }
}

class _Repository extends Fake implements AuthRepository {
  final profiles = <Completer<ApiProfile>>[];
  final updates = <Completer<ApiProfile>>[];
  final logins = <Completer<AuthLoginResult>>[];
  @override
  Future<ApiProfile> getMe() {
    final c = Completer<ApiProfile>();
    profiles.add(c);
    return c.future;
  }

  @override
  Future<AuthLoginResult> loginNiosId({
    required String oauthAccessToken,
    required String deviceInfo,
  }) {
    final c = Completer<AuthLoginResult>();
    logins.add(c);
    return c.future;
  }

  @override
  Future<ApiProfile> updateProfile({
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
    final c = Completer<ApiProfile>();
    updates.add(c);
    return c.future;
  }
}

class _LogoutSocket extends WebSocketClient {
  _LogoutSocket()
    : super(baseUrl: 'https://fixture.invalid', readToken: () => null);
  bool disconnected = false;
  @override
  void disconnect() {
    disconnected = true;
  }
}

class _Cache extends CacheService {
  const _Cache();
  @override
  Future<void> clearAll() async {}
}

class _FailedCallShutdown extends CallSessionNotifier {
  @override
  CallSessionManager? build() => null;
  @override
  Future<void> shutdownForAccountExit() async =>
      throw StateError('fixture native shutdown failed');
}

class _PendingCallShutdown extends CallSessionNotifier {
  final completed = Completer<void>();
  bool started = false;
  @override
  CallSessionManager? build() => null;
  @override
  Future<void> shutdownForAccountExit() {
    started = true;
    return completed.future;
  }
}

class _ProtocolSecrets implements ProtocolSecretStore {
  int deletes = 0;
  @override
  Future<String?> read(String name) async => null;
  @override
  Future<void> write(String name, String value) async {}
  @override
  Future<void> delete(String name) async {
    deletes++;
  }
}

class _FailedAutomaticLogout extends _Auth {
  int calls = 0;
  @override
  Future<void> logout({bool eraseSecretData = true}) async {
    calls++;
    throw StateError('fixture cleanup failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory mediaDirectory;
  late CacheManager rawMedia;
  late CacheManager playbackMedia;
  late CacheManager sharedImages;
  late http.Client mediaClient;
  late void Function() restoreMedia;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  setUp(() async {
    mediaDirectory = await Directory.systemTemp.createTemp('logout-media-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathChannel,
          (_) async => mediaDirectory.path,
        );
    CacheManager cache(String name) => CacheManager(
      Config(
        '${name}_${mediaDirectory.path.hashCode}',
        repo: JsonCacheInfoRepository.withFile(
          File('${mediaDirectory.path}/$name.json'),
        ),
      ),
    );
    rawMedia = cache('raw');
    playbackMedia = cache('playback');
    sharedImages = cache('shared');
    await Future.wait([
      rawMedia.getFileFromCache('fixture'),
      playbackMedia.getFileFromCache('fixture'),
      sharedImages.getFileFromCache('fixture'),
    ]);
    mediaClient = MockClient((_) async => http.Response('', 500));
    restoreMedia = WsMediaFetcher.debugOverride(
      cacheManager: rawMedia,
      playbackCache: playbackMedia,
      sharedImageCache: sharedImages,
      httpClient: mediaClient,
      temporaryDirectory: () async => mediaDirectory,
    );
  });
  tearDown(() async {
    await WsMediaFetcher.clearPrivateCache();
    restoreMedia();
    mediaClient.close();
    await rawMedia.dispose();
    await playbackMedia.dispose();
    await sharedImages.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    await mediaDirectory.delete(recursive: true);
  });
  group('production AuthNotifier lifecycle', () {
    late ProviderContainer container;
    late _Repository repository;
    late _Storage storage;
    late _Auth auth;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = _Repository();
      storage = _Storage();
      container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          authRepositoryProvider.overrideWithValue(repository),
          authSecureStorageProvider.overrideWithValue(storage),
        ],
      );
      auth = container.read(authProvider.notifier) as _Auth;
    });
    tearDown(() => container.dispose());
    test(
      'old refresh cannot expose another account profile or error',
      () async {
        final a = auth.refreshProfile();
        auth.switchSession(_two);
        repository.profiles[0].complete(_profile(1));
        await a;
        expect(container.read(authProvider).profile, isNull);
        final b = auth.refreshProfile();
        auth.switchSession(_one);
        repository.profiles[1].completeError(StateError('old failure'));
        await b;
        expect(container.read(authProvider).error, isNull);
      },
    );
    test(
      'old edit cannot rename or persist the newly logged-in account',
      () async {
        final update = auth.updateProfile(displayName: 'changed');
        auth.switchSession(_two);
        repository.updates.single.complete(_profile(1));
        expect((await update).success, isFalse);
        expect(container.read(authProvider).session, same(_two));
        expect(storage.values, isEmpty);
      },
    );
    test(
      'successful edit preserves the NiosID and persists before publishing',
      () async {
        final update = auth.updateProfile(displayName: 'changed');
        repository.updates.single.complete(_profile(1));
        expect((await update).success, isTrue);
        expect(container.read(authProvider).session?.niosId, _one.niosId);
        expect(jsonDecode(storage.values['auth.session']!)['user_id'], 1);
      },
    );
    test(
      'latest login wins and a delayed older login cannot replace credentials',
      () async {
        final first = auth.loginWithOAuth(oauthAccessToken: 'first');
        final second = auth.loginWithOAuth(oauthAccessToken: 'second');
        repository.logins[1].complete(
          const AuthLoginResult(
            accessToken: 'second',
            userId: 2,
            username: 'two',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        repository.profiles.single.complete(_profile(2));
        expect((await second).success, isTrue);
        repository.logins[0].complete(
          const AuthLoginResult(
            accessToken: 'first',
            userId: 1,
            username: 'one',
          ),
        );
        expect((await first).success, isFalse);
        expect(container.read(authProvider).session?.userId, 2);
        expect(container.read(sessionAccessTokenProvider), 'second');
      },
    );
    test(
      'failed credential write never publishes a successful login',
      () async {
        auth.switchSession(null);
        storage.failWrites = true;
        final login = auth.loginWithOAuth(oauthAccessToken: 'fixture');
        repository.logins.single.complete(
          const AuthLoginResult(accessToken: 'new', userId: 2, username: 'two'),
        );
        expect((await login).success, isFalse);
        expect(container.read(authProvider).isAuthenticated, isFalse);
        expect(container.read(sessionAccessTokenProvider), isNull);
      },
    );
    test('disposed notifier ignores a late login response', () async {
      final login = auth.loginWithOAuth(oauthAccessToken: 'fixture');
      container.dispose();
      repository.logins.single.complete(
        const AuthLoginResult(accessToken: 'new', userId: 2, username: 'two'),
      );
      expect((await login).success, isFalse);
      expect(storage.values, isEmpty);
      container = ProviderContainer();
    });
  });
  test(
    'unreadable sign-out fence fails closed without restoring secure credentials',
    () async {
      final storage = _Storage();
      storage.values['auth.session'] = jsonEncode(_one.toJson());
      final container = ProviderContainer(
        overrides: [
          authSecureStorageProvider.overrideWithValue(storage),
          authPreferencesLoaderProvider.overrideWithValue(
            () => Future<SharedPreferences>.error(
              StateError('fixture preferences unavailable'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.notifier).ensureLoaded();
      expect(container.read(authProvider).hydrated, isTrue);
      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(
        container.read(authProvider).error,
        'AUTH_LOCAL_STATE_UNAVAILABLE',
      );
      expect(storage.values['auth.session'], isNotNull);
    },
  );
  test(
    'HTTP and socket unauthorized callbacks contain logout cleanup errors',
    () async {
      final container = ProviderContainer(
        overrides: [authProvider.overrideWith(_FailedAutomaticLogout.new)],
      );
      addTearDown(container.dispose);
      final api = container.read(apiClientProvider),
          socket = container.read(webSocketClientProvider);
      api.onUnauthorized!();
      socket.onUnauthorized!();
      await Future<void>.delayed(Duration.zero);
      expect(
        (container.read(authProvider.notifier) as _FailedAutomaticLogout).calls,
        2,
      );
    },
  );
  group('production logout persistent fence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });
    for (final failShutdown in [false, true]) {
      test(
        'logout failure still fences the session across restart (shutdown=$failShutdown)',
        () async {
          final storage = _Storage()..failDeletes = !failShutdown;
          storage.values['auth.session'] = jsonEncode(_one.toJson());
          final socket = _LogoutSocket();
          final container = ProviderContainer(
            overrides: [
              authProvider.overrideWith(_Auth.new),
              authSecureStorageProvider.overrideWithValue(storage),
              webSocketClientProvider.overrideWithValue(socket),
              cacheServiceProvider.overrideWithValue(const _Cache()),
              if (failShutdown)
                callSessionProvider.overrideWith(_FailedCallShutdown.new),
            ],
          );
          addTearDown(container.dispose);
          addTearDown(socket.close);
          if (failShutdown) container.read(callSessionProvider);
          container
              .read(sessionAccessTokenProvider.notifier)
              .setToken(_one.accessToken);
          await expectLater(
            container
                .read(authProvider.notifier)
                .logout(eraseSecretData: false),
            throwsStateError,
          );
          expect(container.read(authProvider).isAuthenticated, isFalse);
          expect(container.read(sessionAccessTokenProvider), isNull);
          expect(socket.disconnected, isTrue);
          expect(
            (await SharedPreferences.getInstance()).getBool('auth.signed_out'),
            isTrue,
          );
          // Even a failed OS delete cannot silently restore the revoked local session.
          final repository = _Repository();
          final restart = ProviderContainer(
            overrides: [
              authSecureStorageProvider.overrideWithValue(storage),
              authRepositoryProvider.overrideWithValue(repository),
            ],
          );
          addTearDown(restart.dispose);
          await restart.read(authProvider.notifier).ensureLoaded();
          expect(restart.read(authProvider).hydrated, isTrue);
          expect(restart.read(authProvider).isAuthenticated, isFalse);
          expect(repository.profiles, isEmpty);
        },
      );
    }
  });
  for (final stopFails in [false, true]) {
    test(
      'account erase waits for native call shutdown and respects failure (fail=$stopFails)',
      () async {
        SharedPreferences.setMockInitialValues({});
        FlutterSecureStorage.setMockInitialValues({});
        final directory = await Directory.systemTemp.createTemp(
          'logout-erase-order-',
        );
        final secrets = _ProtocolSecrets();
        var eraseStarted = false;
        final accounts = NiosProtocolAccounts(
          secrets: secrets,
          directory: () async {
            eraseStarted = true;
            return directory;
          },
        );
        final socket = _LogoutSocket();
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            authSecureStorageProvider.overrideWithValue(_Storage()),
            authRepositoryProvider.overrideWithValue(_Repository()),
            webSocketClientProvider.overrideWithValue(socket),
            cacheServiceProvider.overrideWithValue(const _Cache()),
            callSessionProvider.overrideWith(_PendingCallShutdown.new),
            niosProtocolAccountsProvider.overrideWithValue(accounts),
          ],
        );
        try {
          final call =
              container.read(callSessionProvider.notifier)
                  as _PendingCallShutdown;
          Object? cleanupError;
          final logout = container
              .read(authProvider.notifier)
              .logout()
              .catchError((Object error) {
                cleanupError = error;
              });
          for (var i = 0; i < 50 && !call.started; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 2));
          }
          expect(call.started, isTrue);
          await Future<void>.delayed(const Duration(milliseconds: 5));
          expect(eraseStarted, isFalse);
          expect(secrets.deletes, 0);
          if (stopFails) {
            call.completed.completeError(StateError('fixture shutdown failed'));
          } else {
            call.completed.complete();
          }
          await logout;
          expect(eraseStarted, !stopFails);
          expect(secrets.deletes, stopFails ? 0 : 1);
          expect(container.read(authProvider).isAuthenticated, isFalse);
          // This isolated fixture does not install secret/notification native
          // storage plugins. Their partial cleanup may fail independently.
          if (cleanupError != null) {
            expect(
              cleanupError,
              isA<StateError>().having(
                (e) => e.message,
                'code',
                'AUTH_LOGOUT_CLEANUP_INCOMPLETE',
              ),
            );
          }
          if (stopFails) expect(cleanupError, isNotNull);
        } finally {
          container.dispose();
          socket.close();
          await accounts.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }

  test(
    'production hydration retains legacy session when secure migration fails',
    () async {
      final storage = _Storage()..failWrites = true;
      final repository = _Repository();
      final original = jsonEncode(_one.toJson());
      SharedPreferences.setMockInitialValues({'auth.session': original});
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          authSecureStorageProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);
      final auth = container.read(authProvider.notifier);
      final loading = auth.ensureLoaded();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      repository.profiles.single.complete(_profile(1));
      await loading;
      expect(
        (await SharedPreferences.getInstance()).getString('auth.session'),
        original,
      );
    },
  );
}
