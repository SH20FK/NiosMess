import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/features/account_deletion/application/account_deletion_controller.dart';
import 'package:pulse_flutter/features/account_deletion/domain/account_deletion_status.dart';
import 'package:pulse_flutter/features/account_deletion/presentation/account_deletion_texts.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/motion/m3_reveal.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

const int _codeLength = 6;

/// Schedules the account for deletion with an emailed code, or cancels a
/// deletion that is already scheduled.
class AccountDeletionScreen extends ConsumerStatefulWidget {
  const AccountDeletionScreen({this.isEmbedded = false, super.key});

  /// Shown inside the settings pane, under Account, instead of as a page of
  /// its own.
  final bool isEmbedded;

  @override
  ConsumerState<AccountDeletionScreen> createState() =>
      _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends ConsumerState<AccountDeletionScreen> {
  final TextEditingController _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// Runs one server action; a second tap while it runs is ignored.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      switch (AccountDeletionFailure.of(error)) {
        // The screen is out of date: another device scheduled or cancelled
        // the deletion. Show what is true now instead of an error.
        case AccountDeletionFailure.alreadyScheduled:
        case AccountDeletionFailure.notScheduled:
          ref.invalidate(accountDeletionControllerProvider);
        case AccountDeletionFailure.plusActive:
          AppToast.showError(context, context.l10n.accountDeletePlusActive);
        case AccountDeletionFailure.invalidCode:
          AppToast.showError(context, context.l10n.accountDeleteInvalidCode);
        case AccountDeletionFailure.unknown:
          AppToast.showError(context, context.l10n.accountDeleteFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
    await ref.read(accountDeletionControllerProvider.notifier).requestCode();
    if (!mounted) return;
    setState(() => _codeSent = true);
    AppToast.showInfo(context, context.l10n.accountDeleteCodeSent);
  });

  Future<void> _confirm(AccountDeletionStatus status) async {
    final String code = _code.text.trim();
    if (_busy || code.length != _codeLength) return;
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: l10n.accountDeleteConfirmTitle,
      subtitle: l10n.accountDeleteConfirmBody(
        l10n.accountDeleteDays(status.graceDays),
      ),
      confirmLabel: l10n.accountDeleteEntry,
      cancelLabel: l10n.commonCancel,
      icon: Icons.delete_forever_rounded,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      final int? owner = ref.read(authProvider).session?.userId;
      final AccountDeletionStatus scheduled = await ref
          .read(accountDeletionControllerProvider.notifier)
          .confirm(code);
      if (!mounted || owner != ref.read(authProvider).session?.userId) return;
      HapticService.confirm();
      final DateTime? date = scheduled.scheduledAt;
      if (date != null) {
        AppToast.showInfo(
          context,
          l10n.accountDeleteScheduledToast(accountDeletionDate(l10n, date)),
        );
      }
      // The server has already ended this session; finish it locally too.
      try {
        await ref.read(authProvider.notifier).logout();
      } catch (_) {
        // Cleanup may be incomplete, but the session is gone either way.
      }
      if (mounted) context.go('/login');
    });
  }

  Future<void> _cancel() => _run(() async {
    await ref.read(accountDeletionControllerProvider.notifier).cancel();
    if (!mounted) return;
    setState(() {
      _codeSent = false;
      _code.clear();
    });
    AppToast.showSuccess(context, context.l10n.accountDeleteCancelled);
  });

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AccountDeletionStatus> status = ref.watch(
      accountDeletionControllerProvider,
    );
    final AccountDeletionStatus? value = status.value;
    final (String stage, Widget body) = value != null
        ? value.isPending
              ? ('pending', _pending(value))
              : ('form', _form(value))
        : status.hasError
        ? ('error', _loadFailed())
        : (
            'loading',
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: AppLoadingIndicator()),
            ),
          );
    return SettingsShell(
      title: context.l10n.accountDeleteTitle,
      isEmbedded: widget.isEmbedded,
      children: [
        if (context.reduceMotion)
          body
        else
          AnimatedSize(
            duration: M3Durations.medium2,
            curve: M3SpringCurves.expressiveDecel,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: M3Durations.medium2,
              switchInCurve: M3SpringCurves.expressiveDecel,
              switchOutCurve: M3SpringCurves.expressiveAccel,
              child: KeyedSubtree(key: ValueKey<String>(stage), child: body),
            ),
          ),
      ],
    );
  }

  Widget _text(String text) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: 1.4,
      ),
    ),
  );

  Widget _loadFailed() => SettingsSection(
    children: [
      SettingsListItem(
        icon: Icons.cloud_off_rounded,
        title: context.l10n.accountDeleteLoadFailed,
        value: context.l10n.commonRetry,
        type: SettingsListItemType.action,
        onTap: () => ref.invalidate(accountDeletionControllerProvider),
      ),
    ],
  );

  Widget _pending(AccountDeletionStatus status) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return SettingsSection(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Icon(
                  Icons.auto_delete_outlined,
                  color: scheme.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                accountDeletionPendingTitle(context.l10n, status.scheduledAt),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.accountDeletePendingBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const ValueKey('account-deletion-cancel'),
                onPressed: _busy ? null : _cancel,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.undo_rounded),
                label: Text(context.l10n.accountDeleteCancel),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _form(AccountDeletionStatus status) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          title: l10n.accountDeleteWhatTitle,
          children: [_text(l10n.accountDeleteWhatBody)],
        ),
        SettingsSection(
          title: l10n.accountDeleteHowTitle,
          children: [
            _text(
              l10n.accountDeleteHowBody(
                l10n.accountDeleteDays(status.graceDays),
              ),
            ),
          ],
        ),
        SettingsSection(
          children: [
            // One group item: a hidden reveal must not leave an empty tile.
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsListItem(
                  key: const ValueKey('account-deletion-send-code'),
                  type: SettingsListItemType.action,
                  icon: Icons.mark_email_unread_outlined,
                  title: l10n.accountDeleteSendCode,
                  subtitle: _codeSent ? l10n.accountDeleteCodeSent : null,
                  pending: _busy && !_codeSent,
                  enabled: !_busy,
                  onTap: _sendCode,
                ),
                M3Reveal(
                  revealed: _codeSent,
                  child: IgnorePointer(
                    ignoring: !_codeSent,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            key: const ValueKey('account-deletion-code'),
                            controller: _code,
                            enabled: !_busy,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            autofillHints: const <String>[
                              AutofillHints.oneTimeCode,
                            ],
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(_codeLength),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.accountDeleteCodeLabel,
                              prefixIcon: const Icon(Icons.pin_outlined),
                            ),
                            onSubmitted: (_) => _confirm(status),
                          ),
                          const SizedBox(height: 16),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _code,
                            builder: (context, value, _) => FilledButton(
                              key: const ValueKey('account-deletion-confirm'),
                              onPressed:
                                  _busy || value.text.length != _codeLength
                                  ? null
                                  : () => _confirm(status),
                              style: FilledButton.styleFrom(
                                backgroundColor: scheme.error,
                                foregroundColor: scheme.onError,
                                minimumSize: const Size.fromHeight(48),
                              ),
                              child: Text(l10n.accountDeleteEntry),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
