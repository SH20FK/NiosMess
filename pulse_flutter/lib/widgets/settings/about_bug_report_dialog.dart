import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/repositories/support_repository.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';

/// Uses the shared scrollable dialog, including its keyboard/large-text layout.
class AboutBugReportDialog extends ConsumerStatefulWidget {
  const AboutBugReportDialog({super.key});
  @override
  ConsumerState<AboutBugReportDialog> createState() =>
      _AboutBugReportDialogState();
}

class _AboutBugReportDialogState extends ConsumerState<AboutBugReportDialog> {
  final _subject = TextEditingController();
  final _description = TextEditingController();
  bool _sending = false;
  bool _allowPop = false;
  bool _confirmingClose = false;

  @override
  void initState() {
    super.initState();
    _subject.addListener(_textChanged);
    _description.addListener(_textChanged);
  }

  void _textChanged() => setState(() {});

  Future<void> _close() async {
    if (_sending || _confirmingClose) return;
    if (_subject.text.isNotEmpty || _description.text.isNotEmpty) {
      _confirmingClose = true;
      final discard = await showAppConfirmDialog(
        context: context,
        title: context.l10n.commonDiscardChanges,
        subtitle: context.l10n.commonDiscardChangesDesc,
        confirmLabel: context.l10n.commonDiscardChangesConfirm,
        cancelLabel: context.l10n.commonCancel,
        destructive: true,
      );
      _confirmingClose = false;
      if (discard != true || !mounted) return;
    }
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending ||
        _subject.text.trim().isEmpty ||
        _description.text.trim().isEmpty) {
      return;
    }
    setState(() => _sending = true);
    try {
      final ticket = await ref
          .read(supportRepositoryProvider)
          .createTicket(
            ticketType: 'bug',
            subject: _subject.text.trim(),
            body: _description.text.trim(),
          );
      if (ticket == null || ticket.id <= 0) {
        throw const FormatException('support_ack_missing');
      }
      if (!mounted) return;
      AppToast.showSuccess(context, context.l10n.aboutReportSuccess);
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppToast.showError(context, context.l10n.aboutReportError);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (popped, _) {
      if (!popped) _close();
    },
    child: AppDialog(
      title: context.l10n.aboutReportBugAction,
      icon: Icons.bug_report_outlined,
      actions: [
        AppDialogAction(
          label: context.l10n.commonCancel,
          onPressed: _sending ? null : _close,
        ),
        AppDialogAction(
          label: context.l10n.settingsSubmit,
          isPrimary: true,
          isLoading: _sending,
          onPressed:
              _sending ||
                  _subject.text.trim().isEmpty ||
                  _description.text.trim().isEmpty
              ? null
              : _submit,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _subject,
            enabled: !_sending,
            textInputAction: TextInputAction.next,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: context.l10n.aboutReportSubject,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            enabled: !_sending,
            minLines: 3,
            maxLines: 6,
            maxLength: 10000,
            decoration: InputDecoration(
              labelText: context.l10n.aboutReportDescription,
            ),
          ),
        ],
      ),
    ),
  );
}
