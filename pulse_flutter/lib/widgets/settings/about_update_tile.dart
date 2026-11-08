import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/constants/build_info.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/providers/ota_update_provider.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/update/app_update_dialog.dart';

/// Progress is isolated from the About page and its changelog/team content.
class AboutUpdateTile extends ConsumerWidget {
  const AboutUpdateTile({super.key});

  Future<void> _activate(BuildContext context, WidgetRef ref) async {
    final state = ref.read(otaUpdateProvider);
    final notifier = ref.read(otaUpdateProvider.notifier);
    if (state.status == OtaStatus.checking ||
        state.status == OtaStatus.installing) {
      return;
    }
    if (state.status == OtaStatus.readyToInstall) {
      await notifier.installApk(context: context);
      return;
    }
    if (state.updateInfo != null &&
        (state.status == OtaStatus.available ||
            state.status == OtaStatus.downloading)) {
      AppUpdateDialog.show(context, state.updateInfo!);
      return;
    }
    if (!(ref.read(connectivityProvider).value ?? true)) {
      AppToast.showError(context, context.l10n.aboutOfflineError);
      return;
    }
    await notifier.checkForUpdate();
    if (!context.mounted) return;
    final updated = ref.read(otaUpdateProvider);
    if (updated.status == OtaStatus.idle) {
      AppToast.showSuccess(context, context.l10n.aboutUpToDate);
    } else if (updated.status == OtaStatus.available &&
        updated.updateInfo != null) {
      AppUpdateDialog.show(context, updated.updateInfo!);
    } else if (updated.status == OtaStatus.error) {
      AppToast.showError(
        context,
        context.l10n.updateFailureMessage(updated.errorMessage ?? ''),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(otaUpdateProvider);
    final l = context.l10n;
    final busy =
        state.status == OtaStatus.checking ||
        state.status == OtaStatus.installing;
    final downloading = state.status == OtaStatus.downloading;
    final subtitle = switch (state.status) {
      OtaStatus.checking => l.aboutCheckingStatus,
      OtaStatus.available => l.aboutUpdateAvailable(
        state.updateInfo?.latestVersion ?? BuildInfo.version,
      ),
      OtaStatus.downloading => l.aboutDownloadingProgress(
        (state.progress * 100).round().clamp(0, 100),
      ),
      OtaStatus.readyToInstall => l.aboutReadyToInstall(
        state.updateInfo?.latestVersion ?? BuildInfo.version,
      ),
      OtaStatus.installing => l.commonContinue,
      OtaStatus.error => l.updateFailureMessage(state.errorMessage ?? ''),
      OtaStatus.idle => l.aboutOtaSubtitle,
    };
    return RepaintBoundary(
      child: SettingsListItem(
        icon: state.status == OtaStatus.error
            ? Icons.error_outline_rounded
            : Icons.system_update_rounded,
        title: l.aboutSystemUpdateTitle,
        subtitle: subtitle,
        pending: busy,
        trailing: downloading
            ? IconButton(
                tooltip: l.aboutCancelAction,
                onPressed: () =>
                    ref.read(otaUpdateProvider.notifier).cancelDownload(),
                icon: const Icon(Icons.close_rounded),
              )
            : busy
            ? const SizedBox.square(
                dimension: 48,
                child: Center(child: AppLoadingIndicator(size: 24)),
              )
            : const Icon(Icons.chevron_right_rounded),
        onTap: () => _activate(context, ref),
      ),
    );
  }
}
