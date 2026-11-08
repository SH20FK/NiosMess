import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/modal/app_date_picker.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/models/api/working_hours_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/profile/working_hours_planner_dialog.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

/// Profile editing owns its draft until saving succeeds or discard is confirmed.
class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({
    required this.initialName,
    required this.initialUsername,
    required this.initialBio,
    required this.onUploadAvatar,
    required this.actions,
    this.initialPhoneNumber,
    this.initialBirthday,
    this.initialWorkingHours,
    super.key,
  });

  final String initialName;
  final String initialUsername;
  final String initialBio;
  final String? initialPhoneNumber;
  final String? initialBirthday;
  final WorkingHours? initialWorkingHours;
  final Future<void> Function() onUploadAvatar;
  final List<Widget> actions;

  static Future<bool?> show(
    BuildContext context, {
    required String initialName,
    required String initialUsername,
    required String initialBio,
    required Future<void> Function() onUploadAvatar,
    required List<Widget> actions,
    String? initialPhoneNumber,
    String? initialBirthday,
    WorkingHours? initialWorkingHours,
  }) {
    Widget builder(BuildContext _) => EditProfileSheet(
      initialName: initialName,
      initialUsername: initialUsername,
      initialBio: initialBio,
      initialPhoneNumber: initialPhoneNumber,
      initialBirthday: initialBirthday,
      initialWorkingHours: initialWorkingHours,
      onUploadAvatar: onUploadAvatar,
      actions: actions,
    );
    if (MediaQuery.sizeOf(context).width >= 600) {
      return AppModal.showDialog<bool>(
        context: context,
        builder: builder,
        isDismissible: false,
        isScrollable: true,
      );
    }
    return AppModal.showSheet<bool>(
      context: context,
      builder: builder,
      isDismissible: false,
      enableDrag: false,
      isScrollable: true,
    );
  }

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _bio;
  late final TextEditingController _phone;
  late String _birthday;
  WorkingHours? _hours;
  bool _saving = false;
  bool _avatarBusy = false;
  bool _allowPop = false;
  late final ({int? id, String? token}) _owner;

  bool get _ownsSession {
    final session = ref.read(authProvider).session;
    return _owner.id != null &&
        session?.userId == _owner.id &&
        session?.accessToken == _owner.token &&
        !ref.read(authProvider.notifier).isLoggingOut;
  }

  @override
  void initState() {
    super.initState();
    final session = ref.read(authProvider).session;
    _owner = (id: session?.userId, token: session?.accessToken);
    _name = TextEditingController(text: widget.initialName);
    _username = TextEditingController(text: widget.initialUsername);
    _bio = TextEditingController(text: widget.initialBio);
    _phone = TextEditingController(
      text: widget.initialPhoneNumber?.replaceAll(RegExp(r'\D'), '') ?? '',
    );
    _birthday = widget.initialBirthday ?? '';
    _hours = widget.initialWorkingHours;
  }

  @override
  void dispose() {
    for (final controller in [_name, _username, _bio, _phone]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _dirty =>
      _name.text != widget.initialName ||
      _username.text != widget.initialUsername ||
      _bio.text != widget.initialBio ||
      _phone.text !=
          (widget.initialPhoneNumber?.replaceAll(RegExp(r'\D'), '') ?? '') ||
      _birthday != (widget.initialBirthday ?? '') ||
      _hours != widget.initialWorkingHours;

  Future<void> _close() async {
    if (_saving || _avatarBusy) return;
    if (_dirty) {
      final discard = await showAppConfirmDialog(
        context: context,
        title: context.l10n.commonDiscardChanges,
        subtitle: context.l10n.commonDiscardChangesDesc,
        confirmLabel: context.l10n.commonDiscardChangesConfirm,
        cancelLabel: context.l10n.commonCancel,
        icon: Icons.edit_off_outlined,
        destructive: true,
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  Future<void> _birthdayPicker() async {
    if (!_ownsSession) return;
    final now = DateTime.now();
    final parsed = DateTime.tryParse(_birthday) ?? DateTime(2000);
    final initial = parsed.isBefore(DateTime(1900))
        ? DateTime(1900)
        : parsed.isAfter(now)
        ? now
        : parsed;
    final picked = await AppDatePicker.show(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null || !mounted || !_ownsSession) return;
    setState(
      () => _birthday =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
    );
  }

  Future<void> _workingHours() async {
    if (!_ownsSession) return;
    final hours = await WorkingHoursPlannerDialog.show(
      context,
      initialWorkingHours: _hours,
    );
    if (hours != null && mounted && _ownsSession) {
      setState(() => _hours = hours);
    }
  }

  Future<void> _avatar() async {
    if (_avatarBusy || _saving || !_ownsSession) return;
    setState(() => _avatarBusy = true);
    try {
      await widget.onUploadAvatar();
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  String? _phoneError(String? value) {
    final digits = value?.trim() ?? '';
    if (digits.isEmpty) return null;
    return RegExp(r'^[1-9]\d{6,14}$').hasMatch(digits)
        ? null
        : context.l10n.settingsProfilePhoneInvalid;
  }

  Future<void> _save() async {
    if (_saving ||
        _avatarBusy ||
        !_ownsSession ||
        !_form.currentState!.validate()) {
      return;
    }
    final session = ref.read(authProvider).session;
    if (session == null || ref.read(authProvider.notifier).isLoggingOut) return;
    final name = _name.text.trim();
    final username = _username.text.trim();
    final phone = _phone.text.trim();
    final digits = phone.startsWith('8') && phone.length == 11
        ? '7${phone.substring(1)}'
        : phone;
    setState(() => _saving = true);
    try {
      final result = await ref
          .read(authProvider.notifier)
          .updateProfile(
            displayName: name,
            username: username.isNotEmpty && username != widget.initialUsername
                ? username
                : null,
            bio: _bio.text.trim(),
            phoneNumber: digits.isNotEmpty ? '+$digits' : null,
            clearPhoneNumber:
                digits.isEmpty && widget.initialPhoneNumber != null,
            birthday: _birthday.isEmpty ? null : _birthday,
            clearBirthday: _birthday.isEmpty && widget.initialBirthday != null,
            workingHours: _hours,
            clearWorkingHours:
                (_hours == null || _hours!.isEmpty) &&
                widget.initialWorkingHours != null,
          );
      if (!mounted) return;
      final current = ref.read(authProvider);
      if (ref.read(authProvider.notifier).isLoggingOut ||
          current.session?.userId != session.userId ||
          current.session?.accessToken != session.accessToken) {
        return;
      }
      if (result.success) {
        setState(() => _allowPop = true);
        Navigator.of(context).pop(true);
      } else {
        AppToast.showError(
          context,
          result.message ?? context.l10n.settingsProfileSaveFailed,
        );
      }
    } catch (_) {
      if (mounted && _ownsSession) {
        AppToast.showError(context, context.l10n.settingsProfileSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    int? maxLength,
    int lines = 1,
    TextInputType? keyboardType,
    String? prefix,
  }) => Padding(
    padding: const EdgeInsets.all(16),
    child: TextFormField(
      controller: controller,
      enabled: !_saving,
      validator: validator,
      maxLength: maxLength,
      minLines: lines,
      maxLines: lines == 1 ? 1 : 5,
      keyboardType: keyboardType,
      textInputAction: lines == 1
          ? TextInputAction.next
          : TextInputAction.newline,
      inputFormatters: keyboardType == TextInputType.phone
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        counterText: '',
        filled: false,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    if (!_ownsSession) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.settingsProfileAccountChanged,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.commonDismiss),
            ),
          ],
        ),
      );
    }
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final stackActions =
                      bounds.maxWidth < 400 &&
                      MediaQuery.textScalerOf(context).scale(14) > 18;
                  final save = FilledButton(
                    onPressed: _saving || _avatarBusy ? null : _save,
                    child: _saving
                        ? const AppLoadingIndicator(size: 22)
                        : Text(context.l10n.commonSave),
                  );
                  final heading = Row(
                    children: [
                      IconButton(
                        onPressed: _saving ? null : _close,
                        tooltip: context.l10n.commonCancel,
                        icon: const Icon(Icons.close_rounded),
                      ),
                      Expanded(
                        child: Text(
                          context.l10n.profileTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (!stackActions) save,
                    ],
                  );
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      heading,
                      if (stackActions)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(width: double.infinity, child: save),
                        ),
                    ],
                  );
                },
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Form(
                  key: _form,
                  child: Column(
                    children: [
                      PulseAvatar(
                        name: _name.text,
                        avatarUrl: auth.profile?.avatarUrl,
                        radius: 42,
                        fallbackColor: scheme.primaryContainer,
                        textColor: scheme.onPrimaryContainer,
                      ),
                      TextButton.icon(
                        onPressed: _avatarBusy || _saving ? null : _avatar,
                        icon: _avatarBusy
                            ? const AppLoadingIndicator(size: 18)
                            : const Icon(Icons.add_a_photo_outlined, size: 18),
                        label: Text(context.l10n.settingsProfileChangePhoto),
                      ),
                      SettingsSection(
                        children: [
                          _field(
                            controller: _name,
                            label: context.l10n.profileDisplayName,
                            maxLength: 64,
                            validator: (value) => value!.trim().isEmpty
                                ? context.l10n.registerNameRequired
                                : value.trim().length > 64
                                ? context.l10n.profileNameTooLong
                                : null,
                          ),
                          _field(
                            controller: _bio,
                            label: context.l10n.profileDescription,
                            maxLength: 500,
                            lines: 3,
                            keyboardType: TextInputType.multiline,
                          ),
                        ],
                      ),
                      SettingsSection(
                        children: [
                          _field(
                            controller: _username,
                            label: context.l10n.profileUsernameLabel,
                            prefix: '@',
                            validator: (value) =>
                                (value!.trim().isEmpty &&
                                        widget.initialUsername.isEmpty) ||
                                    RegExp(
                                      r'^[a-zA-Z0-9_]{3,32}$',
                                    ).hasMatch(value.trim())
                                ? null
                                : context.l10n.profileUsernameInvalid,
                          ),
                          _field(
                            controller: _phone,
                            label: context.l10n.settingsProfilePhone,
                            keyboardType: TextInputType.phone,
                            prefix: '+',
                            validator: _phoneError,
                          ),
                          SettingsListItem.value(
                            icon: Icons.cake_outlined,
                            title: context.l10n.settingsProfileBirthday,
                            value: _birthday.isEmpty
                                ? context.l10n.settingsProfileNotSet
                                : _birthday,
                            onTap: _saving ? null : _birthdayPicker,
                            onLongPress: _saving
                                ? null
                                : () => setState(() => _birthday = ''),
                          ),
                          if (_birthday.isNotEmpty)
                            SettingsListItem(
                              icon: Icons.event_busy_outlined,
                              title: context.l10n.settingsProfileClearBirthday,
                              onTap: _saving
                                  ? null
                                  : () => setState(() => _birthday = ''),
                            ),
                        ],
                      ),
                      SettingsSection(
                        children: [
                          SettingsListItem.nav(
                            icon: Icons.schedule_rounded,
                            title: context.l10n.settingsProfileWorkingHours,
                            value: _hours == null || _hours!.isEmpty
                                ? context.l10n.settingsProfileNotSet
                                : context.l10n.settingsProfileHoursConfigured,
                            enabled: !_saving,
                            onTap: _workingHours,
                          ),
                        ],
                      ),
                      if (widget.actions.isNotEmpty)
                        SettingsSection(children: widget.actions),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
