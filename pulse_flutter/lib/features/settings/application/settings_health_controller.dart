import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/core/storage/local_storage_service.dart';
import 'package:pulse_flutter/features/settings/domain/settings_issue.dart';
import 'package:pulse_flutter/providers/ota_update_provider.dart';
import 'package:pulse_flutter/providers/push_permission_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

const int _largeCacheBytes = 1024 * 1024 * 1024;

final Provider<List<SettingsHealthIssue>> settingsHealthProvider =
    Provider<List<SettingsHealthIssue>>((Ref ref) {
      final List<SettingsHealthIssue> issues = <SettingsHealthIssue>[];

      // An unknown permission is not a problem yet: only a definite "no" is.
      if (PushNotificationService.supportsPush &&
          ref.watch(
            uiSettingsProvider.select((UiSettingsState s) => s.notifications),
          ) &&
          ref.watch(pushPermissionProvider).value == false) {
        issues.add(const SettingsHealthIssue.pushDenied());
      }

      final int cacheBytes = ref.watch(
        storageSnapshotProvider.select(
          (AsyncValue<LocalStorageSnapshot> s) => s.value?.temporaryBytes ?? 0,
        ),
      );
      if (cacheBytes > _largeCacheBytes) {
        issues.add(SettingsHealthIssue.cacheLarge(cacheBytes));
      }

      // The update row does not exist on the web, so there is nothing to open.
      if (!kIsWeb &&
          ref.watch(otaUpdateProvider.select((OtaUpdateState s) => s.status)) ==
              OtaStatus.error) {
        issues.add(const SettingsHealthIssue.updateFailed());
      }

      return issues;
    });
