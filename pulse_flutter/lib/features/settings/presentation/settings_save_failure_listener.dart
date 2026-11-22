import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

/// Says so when a setting did not reach the disk and offers to ask again.
/// Mounted once above the routes: a setting can be changed from onboarding or
/// a chat as well as from the settings screens.
class SettingsSaveFailureListener extends ConsumerWidget {
  const SettingsSaveFailureListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<SettingsSaveFailure?>(settingsSaveFailureProvider, (
      SettingsSaveFailure? _,
      SettingsSaveFailure? next,
    ) {
      if (next == null) return;
      AppToast.showError(
        context,
        context.l10n.settingsSaveFailed,
        onRetry: next.retry,
      );
    });
    return child;
  }
}
