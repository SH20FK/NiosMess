import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/widgets/app_logo_mark.dart';

class AlphaTestDialog {
  static const String _key = 'alpha_test_acknowledged';

  static Future<void> markAcknowledged() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  static Future<void> showIfFirstLaunch(BuildContext context) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool acknowledged = prefs.getBool(_key) ?? false;
    if (acknowledged) return;

    if (!context.mounted) return;
    await show(context);
  }

  static Future<void> show(BuildContext context) async {
    await AppBottomSheets.show<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (BuildContext ctx) => const _AlphaTestBottomSheetWidget(),
    );
  }
}

class _AlphaTestBottomSheetWidget extends StatelessWidget {
  const _AlphaTestBottomSheetWidget();

  Future<void> _launchTelegram(BuildContext context, String handle) async {
    HapticService.tap();
    final Uri uri = Uri.parse('https://t.me/$handle');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Hero Brand Squircle with Lab/Alpha badge
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      scheme.primaryContainer,
                      scheme.surfaceContainerHigh,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const AppLogoMark(size: 44),
              ),
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.surfaceContainerLow,
                      width: 2.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.science_rounded,
                    size: 15,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Version Badge Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: scheme.primary.withValues(alpha: isDark ? 0.35 : 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E676),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ALPHA PRE-RELEASE',
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            context.l10n.alphaDialogTitle,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: scheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),

          // Body text
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              context.l10n.alphaDialogBody,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
                fontSize: 13.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),

          // Feedback & Telegram contact card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? scheme.surfaceContainer
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.35),
              ),
            ),
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.bug_report_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.alphaDialogReportTo,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _TelegramButton(
                        handle: 'hello_sanlsan',
                        onTap: () => _launchTelegram(context, 'hello_sanlsan'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TelegramButton(
                        handle: 'sh20fk',
                        onTap: () => _launchTelegram(context, 'sh20fk'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Primary Action Button (56dp pill)
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: () {
                HapticService.confirm();
                AlphaTestDialog.markAcknowledged();
                Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: Text(
                context.l10n.alphaDialogUnderstood,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TelegramButton extends StatelessWidget {
  const _TelegramButton({
    required this.handle,
    required this.onTap,
  });

  final String handle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark
          ? scheme.surfaceContainerHighest
          : scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF2AABEE).withValues(alpha: isDark ? 0.35 : 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SvgPicture.asset(
                'assets/svg/telegram_logo.svg',
                width: 18,
                height: 18,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF2AABEE),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '@$handle',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF2AABEE),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
