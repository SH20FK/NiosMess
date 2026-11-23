import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/services/password_reset_service.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

const int _codeLength = 6;
const int _minPasswordLength = 10;

/// The Nios ID rule the new password must satisfy: at least 10 characters,
/// one uppercase Latin letter, one digit. Kept in sync with the server so the
/// button only unlocks on a password the server will accept.
bool _passwordAcceptable(String password) =>
    password.length >= _minPasswordLength &&
    RegExp('[A-Z]').hasMatch(password) &&
    RegExp(r'\d').hasMatch(password);

/// Resets the password of the Nios ID behind the account with an emailed
/// code, straight from the app. The email comes from the own profile.
class SettingsPasswordScreen extends ConsumerStatefulWidget {
  const SettingsPasswordScreen({this.isEmbedded = false, super.key});

  /// Shown inside the settings pane, under Account, instead of as a page of
  /// its own.
  final bool isEmbedded;

  @override
  ConsumerState<SettingsPasswordScreen> createState() =>
      _SettingsPasswordScreenState();
}

class _SettingsPasswordScreenState
    extends ConsumerState<SettingsPasswordScreen> {
  final TextEditingController _code = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _repeat = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  bool _done = false;
  bool _obscure = true;
  PasswordResetFailureKind? _error;

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  /// Runs one Nios ID request; a second tap while it runs is ignored.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on PasswordResetException catch (error) {
      if (mounted) setState(() => _error = error.kind);
    } catch (_) {
      if (mounted) {
        setState(() => _error = PasswordResetFailureKind.unknown);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The address the code goes to. Null when the profile has none or has
  /// gone: the screen is built on it, but the account can end between the
  /// frame and the tap.
  String? get _email {
    final String? email = ref.read(authProvider).profile?.email?.trim();
    return email == null || email.isEmpty ? null : email;
  }

  Future<void> _sendCode() => _run(() async {
    final String? email = _email;
    if (email == null) return;
    await ref.read(passwordResetServiceProvider).requestCode(email);
    if (!mounted) return;
    setState(() => _codeSent = true);
  });

  Future<void> _reset() => _run(() async {
    final String? email = _email;
    if (email == null) return;
    await ref
        .read(passwordResetServiceProvider)
        .reset(
          email: email,
          code: _code.text.trim(),
          newPassword: _password.text,
        );
    if (!mounted) return;
    HapticService.confirm();
    AppToast.showSuccess(context, context.l10n.settingsPasswordDoneTitle);
    setState(() => _done = true);
  });

  void _toggleObscure() {
    setState(() => _obscure = !_obscure);
  }

  @override
  Widget build(BuildContext context) {
    // The email arrives with the own profile only; other profiles never
    // carry it.
    final String? email = ref
        .watch(authProvider.select((AuthState a) => a.profile?.email))
        ?.trim();
    // Only whether the profile exists: watching the whole state would rebuild
    // the form on every useless change of the account.
    final bool hasProfile = ref.watch(
      authProvider.select((AuthState a) => a.profile != null),
    );
    final String? stage;
    final Widget body;
    if (email == null && hasProfile) {
      stage = 'no-email';
      body = _noEmail();
    } else if (email == null) {
      // The profile is still on its way: claiming "no email" before it lands
      // would be wrong.
      stage = 'loading';
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: AppLoadingIndicator()),
      );
    } else if (_done) {
      stage = 'done';
      body = _doneCard();
    } else {
      stage = _codeSent ? 'form' : 'request';
      body = _codeSent ? _form() : _request(email);
    }
    return SettingsShell(
      title: context.l10n.settingsPasswordTitle,
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

  /// No email on the account: the code has nowhere to go, so there is no
  /// send button. The address is set on the Nios ID portal.
  Widget _noEmail() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppLocalizations l10n = context.l10n;
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
                  Icons.mark_email_unread_outlined,
                  color: scheme.onSurfaceVariant,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.settingsPasswordNoEmailTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.settingsPasswordNoEmailBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                key: const ValueKey('settings-password-open-nios-id'),
                onPressed: () =>
                    AppUrlLauncher.openUrl(context, 'https://ni-os.ru/id/account'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(l10n.settingsPasswordOpenNiosId),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _request(String email) {
    final AppLocalizations l10n = context.l10n;
    return SettingsSection(
      children: [
        _text(l10n.settingsPasswordCodeIntro(email)),
        SettingsListItem(
          key: const ValueKey('settings-password-send-code'),
          type: SettingsListItemType.action,
          icon: Icons.mark_email_unread_outlined,
          title: l10n.settingsPasswordRequest,
          enabled: !_busy,
          pending: _busy,
          onTap: _sendCode,
        ),
        // A 400 here is not about a code: there is no code yet.
        if (_error != null) _errorText(_error!, forRequest: true),
      ],
    );
  }

  Widget _form() {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool enabled = !_busy;
    return SettingsSection(
      children: [
        // The request always answers 202, so the letter itself is never a
        // fact: the note says what is true.
        _text(l10n.settingsPasswordRequested),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('settings-password-code'),
                controller: _code,
                enabled: enabled,
                keyboardType: TextInputType.number,
                maxLength: _codeLength,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.oneTimeCode],
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: l10n.settingsPasswordCodeLabel,
                  prefixIcon: const Icon(Icons.pin_outlined),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              _passwordField(
                key: const ValueKey('settings-password-new'),
                controller: _password,
                label: l10n.settingsPasswordNewPasswordLabel,
                enabled: enabled,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.settingsPasswordRuleHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _passwordField(
                key: const ValueKey('settings-password-repeat'),
                controller: _repeat,
                label: l10n.settingsPasswordRepeatLabel,
                enabled: enabled,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _errorText(_error!),
              ],
              const SizedBox(height: 16),
              ListenableBuilder(
                listenable: Listenable.merge(
                  <Listenable>[_code, _password, _repeat],
                ),
                builder: (BuildContext context, _) {
                  final bool canSubmit =
                      !_busy &&
                      _code.text.trim().length == _codeLength &&
                      _passwordAcceptable(_password.text) &&
                      _password.text == _repeat.text;
                  return FilledButton(
                    key: const ValueKey('settings-password-submit'),
                    onPressed: canSubmit ? _reset : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: _busy
                        ? const AppLoadingIndicator(size: 24)
                        : Text(l10n.settingsPasswordSubmit),
                  );
                },
              ),
              // The letter can be late or the code can expire; the intro and
              // the error both say a new request replaces the old one.
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const ValueKey('settings-password-resend'),
                    onPressed: enabled ? _sendCode : null,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(l10n.settingsPasswordResend),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _passwordField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required bool enabled,
  }) => TextField(
    key: key,
    controller: controller,
    enabled: enabled,
    obscureText: _obscure,
    autocorrect: false,
    enableSuggestions: false,
    textInputAction: TextInputAction.done,
    autofillHints: const <String>[AutofillHints.newPassword],
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.password_outlined),
      suffixIcon: IconButton(
        onPressed: _toggleObscure,
        tooltip: _obscure
            ? context.l10n.settingsPasswordShow
            : context.l10n.settingsPasswordHide,
        icon: Icon(
          _obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );

  /// [forRequest] is the stage where no code has been typed yet: a rejected
  /// request cannot be about a wrong code or a weak password.
  Widget _errorText(PasswordResetFailureKind kind, {bool forRequest = false}) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppLocalizations l10n = context.l10n;
    final PasswordResetFailureKind shown = forRequest &&
            (kind == PasswordResetFailureKind.invalidCode ||
                kind == PasswordResetFailureKind.weakPassword)
        ? PasswordResetFailureKind.unknown
        : kind;
    final String text = switch (shown) {
      PasswordResetFailureKind.weakPassword => l10n.settingsPasswordErrorWeak,
      PasswordResetFailureKind.invalidCode => l10n.settingsPasswordErrorCode,
      PasswordResetFailureKind.tooManyRequests =>
        l10n.settingsPasswordErrorRate,
      PasswordResetFailureKind.network => l10n.settingsPasswordErrorNetwork,
      PasswordResetFailureKind.unknown => l10n.settingsPasswordErrorUnknown,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      // Said out loud when it appears: a colour alone tells nobody.
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: 18, color: scheme.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _doneCard() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppLocalizations l10n = context.l10n;
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
                  Icons.task_alt_rounded,
                  color: scheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.settingsPasswordDoneTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.settingsPasswordDoneBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('settings-password-done'),
                onPressed: () => closeSettingsPage(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(l10n.settingsPasswordDoneAction),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
