import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/storage/local_storage_service.dart';
import 'package:pulse_flutter/features/settings/domain/settings_issue.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/ota_update_provider.dart';

final Provider<List<SettingsHealthIssue>> settingsHealthProvider =
    Provider<List<SettingsHealthIssue>>((Ref ref) {
  final List<SettingsHealthIssue> issues = <SettingsHealthIssue>[];

  final AuthState auth = ref.watch(authProvider);
  if (auth.error != null && !auth.isAuthenticated) {
    issues.add(SettingsHealthIssue.reauthenticationRequired());
  }

  final LocalStorageSnapshot? storage = ref.watch(storageSnapshotProvider).asData?.value;
  if (storage != null && storage.temporaryBytes > 1024 * 1024 * 1024) {
    issues.add(SettingsHealthIssue.storageLow(storage.temporaryBytes));
  }

  final OtaUpdateState ota = ref.watch(otaUpdateProvider);
  if (ota.status == OtaStatus.error) {
    issues.add(SettingsHealthIssue.updateIntegrityFailure());
  }

  return issues;
});
