import 'package:universal_io/io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/storage/local_storage_service.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  LocalStorageSnapshot? _storageSnapshot;
  bool _uploadingAvatar = false;

  Future<void> _uploadAvatar() async {
    if (_uploadingAvatar) return;
    final FilePickerResult? picked = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.image,
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;

    final String? filePath = picked.files.first.path;
    if (filePath == null || filePath.isEmpty) return;

    final File file = File(filePath);
    if (!await file.exists()) return;

    final String filename = picked.files.first.name.isNotEmpty
        ? picked.files.first.name
        : 'avatar.jpg';
    final List<int> bytes = await file.readAsBytes();

    setState(() => _uploadingAvatar = true);
    try {
      await ref.read(authRepositoryProvider).uploadAvatar(bytes, filename);
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.settingsAvatarUpdated)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : '$e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadStorageUsage();
  }

  Future<void> _loadStorageUsage() async {
    try {
      final LocalStorageSnapshot snapshot =
          await ref.read(localStorageServiceProvider).snapshot();
      if (mounted) setState(() => _storageSnapshot = snapshot);
    } catch (_) {
      if (mounted) setState(() => _storageSnapshot = null);
    }
  }

  Future<void> _showEditProfileSheet(
    BuildContext context,
    WidgetRef ref,
    AuthState auth,
  ) async {
    final TextEditingController nameController = TextEditingController(
      text: auth.profile?.displayName ?? auth.session?.displayName ?? '',
    );
    final TextEditingController bioController = TextEditingController(
      text: auth.profile?.bio ?? '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                context.l10n.profileEdit,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: context.l10n.profileDisplayName,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bioController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: context.l10n.profileDescription,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await ref.read(authProvider.notifier).updateProfile(
                        displayName: nameController.text.trim(),
                        bio: bioController.text.trim(),
                      );
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.save_rounded),
                label: Text(context.l10n.commonSave),
              ),
            ],
          ),
        );
      },
    );

    nameController.dispose();
    bioController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final UiSettingsState uiSettings = ref.watch(uiSettingsProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(context.l10n.tabProfile),
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 920,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              0,
              0,
              0,
              28 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: <Widget>[
              // Обложка профиля + Карточка пользователя
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  // Баннер-обложка
                  Container(
                    height: 190,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          scheme.primary.withValues(alpha: 0.8),
                          scheme.tertiary.withValues(alpha: 0.6),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(28),
                      ),
                    ),
                  ),
                  // Карточка с аватаром
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.screenHorizontalPadding,
                      110,
                      AppConstants.screenHorizontalPadding,
                      0,
                    ),
                    child: Material(
                      color: scheme.surfaceContainerLow.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(24),
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.16),
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: <Widget>[
                            GestureDetector(
                              onTap: _uploadingAvatar ? null : _uploadAvatar,
                              child: Stack(
                                children: <Widget>[
                                  Hero(
                                    tag: 'user-avatar-$username',
                                    child: PulseAvatar(
                                      name: displayName,
                                      avatarUrl: auth.profile?.avatarUrl,
                                      radius: 44,
                                      fallbackColor: scheme.primaryContainer,
                                      textColor: scheme.onPrimaryContainer,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: scheme.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: scheme.surfaceContainerLow,
                                          width: 2,
                                        ),
                                      ),
                                      child: _uploadingAvatar
                                          ? SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                
                                                strokeWidth: 2,
                                                color: scheme.onPrimary,
                                              ),
                                            )
                                          : Icon(
                                              Icons.camera_alt_rounded,
                                              size: 14,
                                              color: scheme.onPrimary,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              displayName,
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              username.isEmpty ? '' : '@$username',
                              style: textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (bio.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 10),
                              Text(
                                bio,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 16),
                            FilledButton.tonal(
                              onPressed: () => _showEditProfileSheet(context, ref, auth),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(double.infinity, 40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(context.l10n.profileEdit),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fade(duration: 260.ms).slideY(begin: 0.04, end: 0, duration: 260.ms),
                ],
              ),

              const SizedBox(height: 16),

              // Список настроек
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenHorizontalPadding,
                ),
                child: SettingsSection(
                  children: <Widget>[
                    SettingsTile(
                      icon: Icons.admin_panel_settings_rounded,
                      title: context.l10n.settingsAccountSecurityTitle,
                      subtitle: context.l10n.settingsAccountSecuritySubtitle,
                      iconColor: Colors.blue,
                      onTap: () => context.push('/settings/account'),
                    ),
                    SettingsTile(
                      icon: Icons.palette_rounded,
                      title: context.l10n.settingsPersonalizationTitle,
                      subtitle: context.l10n.settingsPersonalizationSubtitle,
                      iconColor: Colors.purple,
                      onTap: () => context.push('/settings/appearance'),
                    ),
                    SettingsTile(
                      icon: Icons.language_rounded,
                      title: context.l10n.languageRegionTitle,
                      subtitle: context.l10n.languageRegionSubtitle,
                      iconColor: Colors.teal,
                      onTap: () => context.push('/settings/language-region'),
                    ),
                    SettingsTile(
                      icon: Icons.privacy_tip_rounded,
                      title: context.l10n.settingsPrivacyTitle,
                      subtitle: context.l10n.settingsPrivacyNotificationsSubtitle,
                      iconColor: Colors.orange,
                      onTap: () => context.push('/settings/privacy'),
                    ),
                    SettingsTile(
                      icon: Icons.storage_rounded,
                      title: context.l10n.settingsStorageTitle,
                      subtitle: storageUsed.isNotEmpty
                          ? '${context.l10n.settingsStorageSubtitle} ($storageUsed)'
                          : context.l10n.settingsStorageSubtitle,
                      iconColor: Colors.green,
                      onTap: () async {
                        await context.push('/settings/storage');
                        _loadStorageUsage();
                      },
                    ),
                    SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: context.l10n.settingsAboutTitle,
                      subtitle: context.l10n.settingsSupportAboutSubtitle,
                      iconColor: Colors.indigo,
                      onTap: () => context.push('/settings/about'),
                    ),
                  ],
                ),
              ).animate(delay: 60.ms).fade(duration: 260.ms).slideY(begin: 0.04, end: 0, duration: 260.ms),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenHorizontalPadding,
                ),
                child: SettingsSection(
                  children: <Widget>[
                    SettingsTile(
                      icon: Icons.admin_panel_settings_rounded,
                      title: context.l10n.settingsAdminTitle,
                      subtitle: context.l10n.settingsAdminSubtitle,
                      iconColor: Colors.red,
                      onTap: () => context.push('/settings/admin'),
                    ),
                    SettingsTile(
                      icon: Icons.verified_rounded,
                      title: context.l10n.settingsBadgesTitle,
                      subtitle: context.l10n.settingsBadgesSubtitle,
                      iconColor: Colors.amber,
                      onTap: () => context.push('/settings/badges'),
                    ),
                    SettingsTile(
                      icon: Icons.smart_toy_rounded,
                      title: context.l10n.settingsBotsTitle,
                      subtitle: context.l10n.settingsBotsSubtitle,
                      iconColor: Colors.cyan,
                      onTap: () => context.push('/settings/bots'),
                    ),
                    SettingsTile(
                      icon: Icons.lock_rounded,
                      title: context.l10n.settingsSecretChatsTitle,
                      subtitle: context.l10n.settingsSecretChatsSubtitle,
                      iconColor: Colors.green,
                      onTap: () => context.push('/settings/e2ee'),
                    ),
                  ],
                ),
              ).animate(delay: 80.ms).fade(duration: 260.ms).slideY(begin: 0.04, end: 0, duration: 260.ms),

              const SizedBox(height: 16),

              // Выход
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenHorizontalPadding,
                ),
                child: SettingsSection(
                  children: <Widget>[
                    SettingsDangerTile(
                      icon: Icons.logout_rounded,
                      title: context.l10n.profileLogout,
                      onTap: () async {
                        if (uiSettings.haptics) HapticFeedback.selectionClick();
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) context.go('/login');
                      },
                    ),
                  ],
                ),
              ).animate(delay: 90.ms).fade(duration: 260.ms).slideY(begin: 0.04, end: 0, duration: 260.ms),
            ],
          ),
        ),
      ),
    );
  }
}
