import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/modal/app_modal_content.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/widgets/app_logo_mark.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class AlphaTestDialog {
  static const String _key = 'alpha_test_acknowledged';

  static Future<void> markAcknowledged() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_key, true)) {
      throw StateError('alpha_ack_write_failed');
    }
  }

  static Future<void> showIfFirstLaunch(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getBool(_key) ?? false) || !context.mounted) return;
    await show(context, requireAcknowledgement: true);
  }

  static Future<void> show(
    BuildContext context, {
    bool requireAcknowledgement = false,
  }) => AppBottomSheets.show<void>(
    context: context,
    isDismissible: !requireAcknowledgement,
    enableDrag: !requireAcknowledgement,
    showDragHandle: !requireAcknowledgement,
    builder: (_) => const _AlphaTestContent(),
  );
}

class _AlphaTestContent extends StatefulWidget {
  const _AlphaTestContent();
  @override
  State<_AlphaTestContent> createState() => _AlphaTestContentState();
}

class _AlphaTestContentState extends State<_AlphaTestContent> {
  bool _saving = false;

  Future<void> _acknowledge() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await AlphaTestDialog.markAcknowledged();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.showError(context, context.l10n.commonError);
    }
  }

  @override
  Widget build(BuildContext context) => AppModalContent(
    title: context.l10n.alphaDialogTitle,
    subtitle: context.l10n.alphaDialogBody,
    actions: [
      AppDialogAction(
        label: context.l10n.alphaDialogUnderstood,
        isPrimary: true,
        isLoading: _saving,
        onPressed: _saving ? null : _acknowledge,
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Center(child: AppLogoMark(size: 64)),
        ),
        SettingsSection(
          title: context.l10n.alphaDialogReportTo,
          children: [
            SettingsListItem.nav(
              icon: Icons.send_outlined,
              title: '@hello_sanlsan',
              onTap: () =>
                  AppUrlLauncher.openUrl(context, 'https://t.me/hello_sanlsan'),
            ),
            SettingsListItem.nav(
              icon: Icons.send_outlined,
              title: '@sh20fk',
              onTap: () =>
                  AppUrlLauncher.openUrl(context, 'https://t.me/sh20fk'),
            ),
          ],
        ),
      ],
    ),
  );
}
