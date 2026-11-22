import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/storage/local_storage_service.dart';
import 'package:pulse_flutter/features/settings/application/settings_health_controller.dart';
import 'package:pulse_flutter/features/settings/domain/settings_issue.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/ota_update_provider.dart';
import 'package:pulse_flutter/providers/push_permission_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends AuthNotifier {
  _Auth(this.pendingDeletion);
  final bool pendingDeletion;

  @override
  AuthState build() => AuthState(
    hydrated: true,
    busy: false,
    session: const AuthSession(
      accessToken: 'fixture',
      userId: 1,
      username: 'account1',
      displayName: 'Account 1',
    ),
    pendingIdentifier: null,
    error: null,
    profile: ApiProfile(
      id: 1,
      username: 'account1',
      displayName: 'Account 1',
      bio: '',
      isPendingDeletion: pendingDeletion,
      deletionScheduledAt: pendingDeletion ? DateTime.utc(2026, 12, 23) : null,
    ),
  );
}

class _Permission extends PushPermissionNotifier {
  _Permission(this.granted);
  final bool? granted;

  @override
  Future<bool?> build() async => granted;
}

class _Storage extends StorageSnapshotNotifier {
  _Storage(this.cacheBytes);
  final int cacheBytes;

  @override
  Future<LocalStorageSnapshot> build() async => LocalStorageSnapshot(
    documentsBytes: 0,
    supportBytes: 0,
    temporaryBytes: cacheBytes,
    draftBytes: 0,
    draftCount: 0,
  );
}

class _Ota extends OtaUpdateNotifier {
  _Ota(this.status);
  final OtaStatus status;

  @override
  OtaUpdateState build() => OtaUpdateState(status: status);
}

const int _gb = 1024 * 1024 * 1024;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<SettingsHealthIssue>> issues({
    bool? permission = true,
    bool notifications = true,
    int cacheBytes = 0,
    OtaStatus ota = OtaStatus.idle,
    TargetPlatform platform = TargetPlatform.android,
    bool pendingDeletion = false,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'ui.notifications': notifications,
    });
    UiSettingsNotifier.cachedPrefs = await SharedPreferences.getInstance();
    addTearDown(() => UiSettingsNotifier.cachedPrefs = null);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => _Auth(pendingDeletion)),
        pushPermissionProvider.overrideWith(() => _Permission(permission)),
        storageSnapshotProvider.overrideWith(() => _Storage(cacheBytes)),
        otaUpdateProvider.overrideWith(() => _Ota(ota)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(pushPermissionProvider.future);
    await container.read(storageSnapshotProvider.future);
    return container.read(settingsHealthProvider);
  }

  group('Settings health', () {
    test('a healthy app shows no cards', () async {
      expect(await issues(), isEmpty);
    });

    test('a system refusal is reported while notifications are on', () async {
      final List<SettingsHealthIssue> found = await issues(permission: false);
      expect(found.single.kind, SettingsHealthIssueKind.pushDenied);
    });

    test('a refusal is not a problem when the user turned push off', () async {
      expect(await issues(permission: false, notifications: false), isEmpty);
    });

    test('an unreadable permission is not reported as a refusal', () async {
      expect(await issues(permission: null), isEmpty);
    });

    test('a platform without push never gets the push card', () async {
      expect(
        await issues(permission: false, platform: TargetPlatform.windows),
        isEmpty,
      );
    });

    test('the cache card appears above 1 GB and carries the size', () async {
      expect(await issues(cacheBytes: _gb), isEmpty);
      final List<SettingsHealthIssue> found = await issues(
        cacheBytes: _gb + 1,
      );
      expect(found.single.kind, SettingsHealthIssueKind.cacheLarge);
      expect(found.single.bytes, _gb + 1);
    });

    test('a failed update is reported', () async {
      final List<SettingsHealthIssue> found = await issues(
        ota: OtaStatus.error,
      );
      expect(found.single.kind, SettingsHealthIssueKind.updateFailed);
    });

    test('a scheduled deletion comes first and carries its date', () async {
      final List<SettingsHealthIssue> found = await issues(
        pendingDeletion: true,
        permission: false,
        cacheBytes: _gb + 1,
      );
      // The hub shows two cards at most: this one must never be cut off.
      expect(found.first.kind, SettingsHealthIssueKind.deletionPending);
      expect(found.first.severity, SettingsHealthSeverity.critical);
      expect(found.first.scheduledAt, DateTime.utc(2026, 12, 23));
      expect(found.length, 3);
    });
  });
}
