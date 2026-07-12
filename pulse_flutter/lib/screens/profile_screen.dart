import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/storage/local_storage_service.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/core/utils/image_compressor.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/profile_header_delegate.dart';
import 'package:pulse_flutter/widgets/liquid_logout_tile.dart';

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
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    if (!mounted) return;
    setState(() => _uploadingAvatar = true);

    try {
      final PlatformFile file = result.files.first;
      Uint8List bytes = file.bytes!;
      final Uint8List? compressed = await ImageCompressor.compressImageBytes(
        bytes: bytes,
        fileName: file.name,
      );
      if (compressed != null) bytes = compressed;
      await ref.read(authRepositoryProvider).uploadAvatar(bytes, file.name);
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.profileAvatarUpdated)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.profileError(e))),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _logout() async {
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
                    initialBio: bio,
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
                  SettingsSection(
                    title: context.l10n.profileSectionQuickSettings,
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
                  SettingsSection(
                    title: context.l10n.profileSectionPrivacy,
                    children: <Widget>[
                      SettingsTile(
                        icon: Icons.lock_outline_rounded,
                        title: context.l10n.settingsPrivacyTitle,
                        subtitle: context.l10n.settingsPrivacySubtitle,
                        onTap: () => context.push('/settings/privacy'),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: context.l10n.profileSectionAccount,
                    children: <Widget>[
                      SettingsTile(
                        icon: Icons.manage_accounts_rounded,
                        title: context.l10n.settingsAccountTitle,
                        subtitle: context.l10n.settingsAccountSubtitle,
                        onTap: () => context.push('/settings/account'),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: context.l10n.profileSectionData,
                    children: <Widget>[
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
                  SettingsSection(
                    title: context.l10n.profileTeamTools,
                    subtitle: context.l10n.profileTeamToolsDesc,
                    children: <Widget>[
                      SettingsTile(
                        icon: Icons.enhanced_encryption_rounded,
                        title: context.l10n.settingsSecretChatsTitle,
                        subtitle: context.l10n.settingsSecretChatsSubtitle,
                        iconColor: scheme.tertiary,
                        onTap: () => context.push('/settings/e2ee'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  LiquidLogoutTile(
                    label: context.l10n.profileLogout,
                    onLogout: _logout,
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
  const _EditProfileDialog({required this.initialName, required this.initialBio});
  final String initialName;
  final String initialBio;

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  late final TextEditingController nameController;
  late final TextEditingController bioController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.initialName);
    bioController = TextEditingController(text: widget.initialBio);
  }

  @override
  void dispose() {
    nameController.dispose();
    bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile(
            displayName: nameController.text.trim(),
            bio: bioController.text.trim(),
          );
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.profileError('$e'))),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          onPressed: _saving ? null : _save,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppTextFieldDialogContent(
            controller: nameController,
            label: context.l10n.profileDisplayName,
            prefixIcon: Icons.person_rounded,
          ),
          const SizedBox(height: 12),
          AppTextFieldDialogContent(
            controller: bioController,
            label: context.l10n.profileDescription,
            prefixIcon: Icons.notes_rounded,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}
