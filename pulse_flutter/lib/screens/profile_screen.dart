import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/storage/local_storage_service.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/core/utils/image_compressor.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/profile_header_delegate.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploadingAvatar = false;
  LocalStorageSnapshot? _storageSnapshot;

  @override
  void initState() {
    super.initState();
    _loadStorageSize();
  }

  Future<void> _loadStorageSize() async {
    try {
      final LocalStorageSnapshot snapshot =
          await ref.read(localStorageServiceProvider).snapshot();
      if (!mounted) return;
      setState(() => _storageSnapshot = snapshot);
    } catch (e, st) {
      debugPrint('Failed to load storage snapshot: $e\n$st');
    }
  }

  Future<void> _uploadAvatar() async {
    final List<PlatformFile> result = await FilePicker.pickFiles(
      type: FileType.image,
    );
    if (result.isEmpty) return;

    if (!mounted) return;
    setState(() => _uploadingAvatar = true);

    try {
      final PlatformFile file = result.first;
      Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;
      final Uint8List? compressed = await ImageCompressor.compressImageBytes(
        bytes: bytes,
        fileName: file.name,
      );
      if (compressed != null) bytes = compressed;
      await ref.read(authRepositoryProvider).uploadAvatar(bytes, file.name);
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      AppToast.showSuccess(context, context.l10n.profileAvatarUpdated);
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, context.l10n.profileError(e));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _logout() async {
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: context.l10n.profileLogoutConfirmTitle,
      subtitle: context.l10n.profileLogoutConfirmBody,
      confirmLabel: context.l10n.profileLogout,
      cancelLabel: context.l10n.commonCancel,
      icon: Icons.logout_rounded,
      destructive: true,
    );
    if (confirmed != true) return;

    final AuthNotifier notifier = ref.read(authProvider.notifier);
    await notifier.logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final String displayName =
        auth.profile?.displayName ??
        auth.session?.displayName ??
        context.l10n.profileGuestName;
    final String username =
        auth.session?.username ?? context.l10n.profileGuestUsername;
    final String bio = auth.profile?.bio.trim().isNotEmpty == true
        ? auth.profile!.bio.trim()
        : '';

    final LocalStorageSnapshot? snapshot = _storageSnapshot;
    final String storageUsed = snapshot != null
        ? FileTypeDetector.formatFileSize(snapshot.totalBytes)
        : '';

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: ProfileHeaderDelegate(
              name: displayName,
              username: username,
              avatarUrl: auth.profile?.avatarUrl,
              onEdit: () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => _EditProfileDialog(
                    initialName: displayName,
                    initialUsername: auth.session?.username ?? '',
                    initialBio: bio,
                    onUploadAvatar: _uploadAvatar,
                  ),
                );
              },
              onUploadAvatar: _uploadAvatar,
              isUploadingAvatar: _uploadingAvatar,
            ),
          ),
          SliverSafeArea(
            top: false,
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                children: [
                  // Appearance
                  SettingsSection(
                    title: context.l10n.profileAppearance,
                    children: <Widget>[
                      SettingsTile(
                        icon: Icons.color_lens_rounded,
                        title: context.l10n.profileAppearance,
                        subtitle: context.l10n.profileAppearanceDesc,
                        onTap: () => context.push('/settings/appearance'),
                      ),
                      SettingsTile(
                        icon: Icons.language_rounded,
                        title: context.l10n.profileLanguage,
                        subtitle: context.l10n.profileLanguageDesc,
                        onTap: () => context.push('/settings/language-region'),
                      ),
                    ],
                  ),
                  // Privacy & Security
                  SettingsSection(
                    title: context.l10n.profileSectionPrivacySecurity,
                    children: <Widget>[
                      SettingsTile(
                        icon: Icons.lock_outline_rounded,
                        title: context.l10n.settingsPrivacyTitle,
                        subtitle: context.l10n.settingsPrivacySubtitle,
                        onTap: () => context.push('/settings/privacy'),
                      ),
                      SettingsTile(
                        icon: Icons.enhanced_encryption_rounded,
                        title: context.l10n.settingsSecretChatsTitle,
                        subtitle: context.l10n.settingsSecretChatsSubtitle,
                        iconColor: scheme.tertiary,
                        onTap: () => context.push('/settings/e2ee'),
                      ),
                      SettingsTile(
                        icon: Icons.devices_rounded,
                        title: context.l10n.settingsActiveSessions,
                        subtitle: context.l10n.settingsActiveSessionsSubtitle,
                        onTap: () => context.push('/settings/sessions'),
                      ),
                    ],
                  ),
                  // Account
                  SettingsSection(
                    title: context.l10n.profileSectionAccount,
                    children: <Widget>[
                      SettingsTile(
                        icon: Icons.manage_accounts_rounded,
                        title: context.l10n.settingsAccountTitle,
                        subtitle: context.l10n.settingsAccountSubtitle,
                        onTap: () => context.push('/settings/account'),
                      ),
                      SettingsTile(
                        icon: Icons.sd_storage_rounded,
                        title: context.l10n.settingsStorageTitle,
                        subtitle: storageUsed.isNotEmpty
                            ? storageUsed
                            : context.l10n.settingsStorageSubtitle,
                        onTap: () => context.push('/settings/storage'),
                      ),
                    ],
                  ),
                  // System
                  SettingsSection(
                    title: context.l10n.commonSystem,
                    children: <Widget>[
                      SettingsTile(
                        icon: Icons.tune_rounded,
                        title: context.l10n.profilePreferences,
                        subtitle: context.l10n.settingsPreferencesBannerSubtitle,
                        onTap: () => context.push('/settings/preferences'),
                      ),
                    ],
                  ),
                  // About
                  SettingsSection(
                    title: context.l10n.profileSectionAbout,
                    children: <Widget>[
                      SettingsTile(
                        icon: Icons.info_outline_rounded,
                        title: context.l10n.settingsAboutTitle,
                        subtitle: context.l10n.settingsSupportAboutSubtitle,
                        onTap: () => context.push('/settings/about'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.errorContainer,
                        foregroundColor: scheme.onErrorContainer,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(
                        context.l10n.profileLogout,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }
}

class _EditProfileDialog extends ConsumerStatefulWidget {
  const _EditProfileDialog({
    required this.initialName,
    required this.initialUsername,
    required this.initialBio,
    this.onUploadAvatar,
  });

  final String initialName;
  final String initialUsername;
  final String initialBio;
  final Future<void> Function()? onUploadAvatar;

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  static final RegExp _usernameRegExp = RegExp(r'^[a-zA-Z0-9_]{3,32}$');

  late final TextEditingController nameController;
  late final TextEditingController usernameController;
  late final TextEditingController bioController;
  bool _saving = false;
  String? _nameError;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.initialName);
    usernameController = TextEditingController(text: widget.initialUsername);
    bioController = TextEditingController(text: widget.initialBio);
    nameController.addListener(_validateName);
    usernameController.addListener(_validateUsername);
    _validateName();
    _validateUsername();
  }

  @override
  void dispose() {
    nameController.removeListener(_validateName);
    usernameController.removeListener(_validateUsername);
    nameController.dispose();
    usernameController.dispose();
    bioController.dispose();
    super.dispose();
  }

  void _validateName() {
    final String text = nameController.text.trim();
    final String? error;
    if (text.isEmpty) {
      error = context.l10n.registerNameRequired;
    } else if (text.length > 64) {
      error = context.l10n.profileNameTooLong;
    } else {
      error = null;
    }
    if (error != _nameError) {
      setState(() => _nameError = error);
    }
  }

  void _validateUsername() {
    final String text = usernameController.text.trim();
    final String? error;
    if (text.isEmpty || _usernameRegExp.hasMatch(text)) {
      error = null;
    } else {
      error = context.l10n.profileUsernameInvalid;
    }
    if (error != _usernameError) {
      setState(() => _usernameError = error);
    }
  }

  Future<void> _save() async {
    if (_nameError != null || _usernameError != null) return;
    setState(() => _saving = true);

    final String username = usernameController.text.trim();
    final String? newUsername =
        username.isNotEmpty && username != widget.initialUsername
            ? username
            : null;

    final AuthActionResult result =
        await ref.read(authProvider.notifier).updateProfile(
              displayName: nameController.text.trim(),
              username: newUsername,
              bio: bioController.text.trim(),
            );

    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).pop();
    } else {
      AppToast.showError(
        context,
        context.l10n.profileError(result.message ?? 'Failed'),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AuthState auth = ref.watch(authProvider);

    return AppDialog(
      title: context.l10n.profileEdit,
      subtitle: context.l10n.settingsEditProfileSubtitle,
      icon: Icons.edit_note_rounded,
      actions: <AppDialogAction>[
        AppDialogAction(
          label: context.l10n.commonCancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppDialogAction(
          label: context.l10n.commonSave,
          icon: Icons.check_rounded,
          isPrimary: true,
          isLoading: _saving,
          onPressed:
              _saving || _nameError != null || _usernameError != null ? null : _save,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Center(
            child: Stack(
              children: <Widget>[
                PulseAvatar(
                  name: widget.initialName,
                  avatarUrl: auth.profile?.avatarUrl,
                  radius: 36,
                  fallbackColor: scheme.primaryContainer,
                  textColor: scheme.onPrimaryContainer,
                ),
                if (widget.onUploadAvatar != null)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: scheme.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () => widget.onUploadAvatar!(),
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.photo_camera_rounded,
                            size: 16,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: nameController,
            maxLength: 64,
            decoration: InputDecoration(
              labelText: context.l10n.profileDisplayName,
              prefixIcon: const Icon(Icons.person_rounded),
              errorText: _nameError,
              filled: true,
              fillColor: scheme.surfaceContainerLow.withValues(alpha: 0.82),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.18)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.18)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: scheme.primary, width: 1.4),
              ),
              counterStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: usernameController,
            decoration: InputDecoration(
              labelText: context.l10n.profileUsernameLabel,
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              prefixText: '@',
              errorText: _usernameError,
              filled: true,
              fillColor: scheme.surfaceContainerLow.withValues(alpha: 0.82),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.18)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.18)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: scheme.primary, width: 1.4),
              ),
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bioController,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: context.l10n.profileDescription,
              prefixIcon: const Icon(Icons.notes_rounded),
              filled: true,
              fillColor: scheme.surfaceContainerLow.withValues(alpha: 0.82),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.18)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.18)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: scheme.primary, width: 1.4),
              ),
              counterStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
