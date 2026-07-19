import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

class AlphaTestDialog {
  static const String _key = 'alpha_test_acknowledged';

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

    return Dialog.fullscreen(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.errorContainer.withValues(alpha: 0.3),
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Icon with pulsing glow
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.error.withValues(alpha: 0.2),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.bug_report_rounded,
                    color: scheme.onErrorContainer,
                    size: 48,
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  context.l10n.alphaDialogTitle,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: scheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Body
                Text(
                  context.l10n.alphaDialogBody,
                  style: textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 28),

                // Report section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        context.l10n.alphaDialogReportTo,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _TelegramButton(
                            handle: 'Door0S',
                            onTap: () => _launchTelegram(context, 'Door0S'),
                          ),
                          const SizedBox(width: 12),
                          _TelegramButton(
                            handle: 'sanlsan',
                            onTap: () => _launchTelegram(context, 'sanlsan'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Got it button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: () {
                      AlphaTestDialog.markAcknowledged();
                      Navigator.of(context).pop();
                    },
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
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
        ),
      ),
    );
  }
}

class _TelegramButton extends StatelessWidget {
  const _TelegramButton({required this.handle, required this.onTap});

  final String handle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(Icons.send_rounded, size: 18, color: scheme.primary),
      label: Text('@$handle'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
