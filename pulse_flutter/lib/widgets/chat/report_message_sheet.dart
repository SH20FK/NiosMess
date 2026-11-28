import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';

/// Opens the report-reason picker and resolves with the chosen reason code
/// (`spam`, `scam`, …), or `null` when the sheet is dismissed.
Future<String?> showReportMessageSheet(BuildContext context) =>
    AppModal.showSheet<String>(
      context: context,
      builder: (BuildContext ctx) => const ReportMessageSheet(),
    );

class ReportMessageSheet extends StatelessWidget {
  const ReportMessageSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              context.l10n.reportSelectReason,
              style: textTheme.titleMedium,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Выбранное сообщение и его текст будут переданы модераторам вместе с жалобой.',
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.report_gmailerrorred_rounded,
              color: scheme.error,
            ),
            title: Text(context.l10n.reportReasonSpam),
            onTap: () => Navigator.of(context).pop('spam'),
          ),
          ListTile(
            leading: Icon(Icons.report_problem_rounded, color: scheme.error),
            title: Text(context.l10n.reportReasonScam),
            onTap: () => Navigator.of(context).pop('scam'),
          ),
          ListTile(
            leading: Icon(Icons.gavel_rounded, color: scheme.error),
            title: Text(context.l10n.reportReasonIllegal),
            onTap: () => Navigator.of(context).pop('illegal'),
          ),
          ListTile(
            leading: Icon(Icons.copyright_rounded, color: scheme.error),
            title: const Text('Нарушение авторских прав (copyright)'),
            onTap: () => Navigator.of(context).pop('copyright'),
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip_rounded, color: scheme.error),
            title: const Text('Доксинг (личные данные)'),
            onTap: () => Navigator.of(context).pop('doxing'),
          ),
          ListTile(
            leading: Icon(Icons.warning_amber_rounded, color: scheme.error),
            title: const Text('Сваттинг / угрозы безопасности'),
            onTap: () => Navigator.of(context).pop('swatting'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
