import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

class AlphaTestDialog {
  static const String _key = 'alpha_test_acknowledged';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !prefs.getBool(_key)!;
  }

  static Future<void> markAcknowledged() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  static Future<void> showIfFirstLaunch(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final acknowledged = prefs.getBool(_key) ?? false;
    if (acknowledged) return;

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _AlphaTestDialogWidget(),
    );
  }
}

class _AlphaTestDialogWidget extends StatelessWidget {
  const _AlphaTestDialogWidget();

  Future<void> _launchTelegram(BuildContext context, String handle) async {
    final uri = Uri.parse('https://t.me/$handle');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bug_report_rounded,
                color: scheme.onErrorContainer,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.l10n.alphaDialogTitle,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.alphaDialogBody,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  context.l10n.alphaDialogReportTo,
                  style: textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _TelegramChip(
                  handle: 'Door0S',
                  onTap: () => _launchTelegram(context, 'Door0S'),
                ),
                const SizedBox(width: 10),
                _TelegramChip(
                  handle: 'sanlsan',
                  onTap: () => _launchTelegram(context, 'sanlsan'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  AlphaTestDialog.markAcknowledged();
                  Navigator.of(context).pop();
                },
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  context.l10n.alphaDialogUnderstood,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelegramChip extends StatelessWidget {
  const _TelegramChip({required this.handle, required this.onTap});

  final String handle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ActionChip(
      label: Text('@$handle'),
      avatar: Icon(Icons.send_rounded, size: 16, color: scheme.primary),
      onPressed: onTap,
    );
  }
}
