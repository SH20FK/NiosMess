import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/modal/app_date_picker.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/models/api/working_hours_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/profile/working_hours_planner_dialog.dart';
import 'package:pulse_flutter/widgets/profile/profile_sheet_layout.dart';
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
    this.onEditBadges,
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
  final VoidCallback? onEditBadges;

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
    VoidCallback? onEditBadges,
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
      onEditBadges: onEditBadges,
    );
    return ProfileSheetLayout.show<bool>(context, builder: builder);
  }

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  final _form = GlobalKey<FormState>();
  final _details = ExpansibleController();
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
    _details.dispose();
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
    if (!mounted || _saving || _avatarBusy) return;
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
    if (!mounted || !_ownsSession) return;
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
    if (!mounted || !_ownsSession) return;
    final hours = await WorkingHoursPlannerDialog.show(
      context,
      initialWorkingHours: _hours,
    );
    if (hours != null && mounted && _ownsSession) {
      setState(() => _hours = hours);
    }
  }

  Future<void> _avatar() async {
    if (!mounted || _avatarBusy || _saving || !_ownsSession) return;
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
    if (!mounted || _saving || _avatarBusy || !_ownsSession) return;
    if (!_form.currentState!.validate()) {
      if (_phoneError(_phone.text) != null) _details.expand();
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
  }) {
    final scheme = Theme.of(context).colorScheme;
    const radius = BorderRadius.all(Radius.circular(16));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
          filled: true,
          fillColor: scheme.surfaceContainerHigh,
          border: const OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: scheme.primary),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          counterText: '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final l = context.l10n;
    if (!_ownsSession) {
      return ProfileSheetLayout(
        title: l.profileTitle,
        onClose: () => Navigator.of(context).pop(),
        child: Text(l.settingsProfileAccountChanged),
      );
    }
    final date = DateTime.tryParse(_birthday);
    final birthdayLabel = date == null
        ? l.settingsProfileNotSet
        : DateFormat.yMMMd(l.localeName).format(date);
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: ProfileSheetLayout(
        title: l.profileTitle,
        onClose: _saving || _avatarBusy ? null : _close,
        actionLabel: l.commonSave,
        onSubmit: _avatarBusy ? null : _save,
        busy: _saving,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _name,
                  builder: (context, value, _) => PulseAvatar(
                    name: value.text,
                    avatarUrl: auth.profile?.avatarUrl,
                    radius: 36,
                    fallbackColor: scheme.primaryContainer,
                    textColor: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              Center(
                child: TextButton.icon(
                  onPressed: _avatarBusy || _saving ? null : _avatar,
                  icon: _avatarBusy
                      ? const AppLoadingIndicator(size: 18)
                      : const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: Text(l.settingsProfileChangePhoto),
                ),
              ),
              const SizedBox(height: 12),
              _field(
                controller: _name,
                label: l.profileDisplayName,
                maxLength: 64,
                validator: (value) => value!.trim().isEmpty
                    ? l.registerNameRequired
                    : value.trim().length > 64
                    ? l.profileNameTooLong
                    : null,
              ),
              _field(
                controller: _username,
                label: l.profileUsernameLabel,
                prefix: '@',
                validator: (value) =>
                    (value!.trim().isEmpty && widget.initialUsername.isEmpty) ||
                        RegExp(r'^[a-zA-Z0-9_]{3,32}$').hasMatch(value.trim())
                    ? null
                    : l.profileUsernameInvalid,
              ),
              _field(
                controller: _bio,
                label: l.profileDescription,
                maxLength: 500,
                lines: 2,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 4),
              ProfileDetailsGroup(
                title: l.settingsProfileExtraDetails,
                controller: _details,
                enabled: !_saving,
                children: [
                  const SizedBox(height: 8),
                  _field(
                    controller: _phone,
                    label: l.settingsProfilePhone,
                    keyboardType: TextInputType.phone,
                    prefix: '+',
                    validator: _phoneError,
                  ),
                  SettingsListItem(
                    icon: Icons.cake_outlined,
                    title: l.settingsProfileBirthday,
                    subtitle: birthdayLabel,
                    enabled: !_saving,
                    onTap: _birthdayPicker,
                    trailing: _birthday.isEmpty
                        ? const Icon(Icons.chevron_right_rounded)
                        : IconButton(
                            tooltip: l.settingsProfileClearBirthday,
                            icon: const Icon(Icons.close_rounded),
                            onPressed: _saving
                                ? null
                                : () => setState(() => _birthday = ''),
                          ),
                  ),
                  SettingsListItem.nav(
                    icon: Icons.schedule_rounded,
                    title: l.settingsProfileWorkingHours,
                    value: _hours == null || _hours!.isEmpty
                        ? l.settingsProfileNotSet
                        : l.settingsProfileHoursConfigured,
                    enabled: !_saving,
                    onTap: _workingHours,
                  ),
                  if (widget.onEditBadges != null)
                    SettingsListItem.nav(
                      icon: Icons.verified_outlined,
                      title: l.settingsBadgesTitle,
                      enabled: !_saving,
                      onTap: () {
                        if (mounted && _ownsSession && !_saving) {
                          widget.onEditBadges!();
                        }
                      },
                    ),
                ],
              ),
              if (widget.actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                ProfileDetailsGroup(
                  title: l.settingsProfileLinksActions,
                  enabled: !_saving,
                  children: widget.actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
