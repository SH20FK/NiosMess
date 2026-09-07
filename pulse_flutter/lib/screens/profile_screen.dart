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
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/screens/e2ee_settings_screen.dart';
import 'package:pulse_flutter/screens/sessions_screen.dart';
import 'package:pulse_flutter/screens/settings_about_screen.dart';
import 'package:pulse_flutter/screens/settings_account_screen.dart';
import 'package:pulse_flutter/screens/settings_appearance_screen.dart';
import 'package:pulse_flutter/screens/settings_chats_screen.dart';
import 'package:pulse_flutter/screens/settings_language_region_screen.dart';
import 'package:pulse_flutter/screens/settings_preferences_screen.dart';
import 'package:pulse_flutter/screens/settings_privacy_screen.dart';
import 'package:pulse_flutter/screens/settings_storage_screen.dart';
import 'package:pulse_flutter/screens/settings_system_device_screen.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/working_hours_model.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/profile/working_hours_widget.dart';
import 'package:pulse_flutter/widgets/profile/working_hours_planner_dialog.dart';
import 'package:pulse_flutter/widgets/profile/badge_selector_dialog.dart';
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
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        final ColorScheme scheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.photo_library_outlined, color: scheme.primary),
                  title: const Text('Выбрать фото'),
                  subtitle: const Text('PNG, JPG, WebP до 8 МБ'),
                  onTap: () => Navigator.of(context).pop('photo'),
                ),
                ListTile(
                  leading: Icon(Icons.videocam_outlined, color: scheme.primary),
                  title: const Text('Выбрать видеоаватар'),
                  subtitle: const Text('Видео до 5 сек, 1:1, до 8 МБ'),
                  onTap: () => Navigator.of(context).pop('video'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null || !mounted) return;

    final bool isVideo = choice == 'video';
    final List<PlatformFile> result = await FilePicker.pickFiles(
      type: isVideo ? FileType.video : FileType.image,
    );
    if (result.isEmpty || !mounted) return;

    setState(() => _uploadingAvatar = true);

    try {
      final PlatformFile file = result.first;
      Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;

      if (bytes.length > 8 * 1024 * 1024) {
        if (!mounted) return;
        AppToast.showError(context, 'Размер файла превышает 8 МБ');
        return;
      }

      if (!isVideo) {
        final Uint8List? compressed = await ImageCompressor.compressImageBytes(
          bytes: bytes,
          fileName: file.name,
        );
        if (compressed != null) bytes = compressed;
      }

      await ref.read(authRepositoryProvider).uploadAvatar(
            bytes,
            filename: file.name,
            isVideo: isVideo,
          );
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      AppToast.showSuccess(context, context.l10n.profileAvatarUpdated);
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e);
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

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= 760;

        if (isWide) {
          return _buildDesktopMasterDetail(
            context,
            auth,
            scheme,
            displayName,
            username,
            bio,
            storageUsed,
          );
        }

        return _buildMobileProfile(
          context,
          auth,
          scheme,
          displayName,
          username,
          bio,
          storageUsed,
        );
      },
    );
  }

  Widget _buildDesktopMasterDetail(
    BuildContext context,
    AuthState auth,
    ColorScheme scheme,
    String displayName,
    String username,
    String bio,
    String storageUsed,
  ) {
    final SettingsSectionId selectedSection =
        ref.watch(desktopSelectedSettingsSectionProvider);

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 1. Left Master Pane (Sidebar docked to the left navigation rail)
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: isDark
                  ? scheme.surfaceContainerLowest
                  : scheme.surface.withValues(alpha: 0.65),
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
              children: <Widget>[
                _buildMasterProfileHeader(
                  context,
                  auth,
                  scheme,
                  displayName,
                  username,
                  bio,
                ),
                const SizedBox(height: 14),

                // 1. Account & Security
                SettingsSection(
                  isCard: false,
                  title: context.l10n.profileSectionAccount,
                  children: <Widget>[
                    SettingsTile(
                      icon: Icons.manage_accounts_rounded,
                      title: context.l10n.settingsAccountTitle,
                      iconColor: scheme.primary,
                      isSelected: selectedSection == SettingsSectionId.account,
                      onTap: () => ref
                          .read(desktopSelectedSettingsSectionProvider.notifier)
                          .setSelectedSection(SettingsSectionId.account),
                    ),
                    SettingsTile(
                      icon: Icons.devices_rounded,
                      title: context.l10n.settingsActiveSessions,
                      iconColor: scheme.primary,
                      isSelected: selectedSection == SettingsSectionId.sessions,
                      onTap: () => ref
                          .read(desktopSelectedSettingsSectionProvider.notifier)
                          .setSelectedSection(SettingsSectionId.sessions),
                    ),
                  ],
                ),

                // 2. Interface & Personalization
                SettingsSection(
                  isCard: false,
                  title: context.l10n.profileAppearance,
                  children: <Widget>[
                    SettingsTile(
                      icon: Icons.palette_rounded,
                      title: context.l10n.profileAppearance,
                      iconColor: scheme.primary,
                      isSelected:
                          selectedSection == SettingsSectionId.appearance,
                      onTap: () => ref
                          .read(desktopSelectedSettingsSectionProvider.notifier)
                          .setSelectedSection(SettingsSectionId.appearance),
                    ),
                    SettingsTile(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Чаты и медиа',
                      iconColor: scheme.primary,
                      isSelected:
                          selectedSection == SettingsSectionId.chats,
                      onTap: () => ref
                          .read(desktopSelectedSettingsSectionProvider.notifier)
                          .setSelectedSection(SettingsSectionId.chats),
                    ),
                    SettingsTile(
                      icon: Icons.notifications_active_rounded,
                      title: context.l10n.settingsPreferencesTitle,
                      iconColor: scheme.secondary,
                      isSelected:
                          selectedSection == SettingsSectionId.preferences,
                      onTap: () => ref
                          .read(desktopSelectedSettingsSectionProvider.notifier)
                          .setSelectedSection(SettingsSectionId.preferences),
                    ),
                    SettingsTile(
                      icon: Icons.language_rounded,
                      title: context.l10n.profileLanguage,
                      iconColor: scheme.secondary,
                      isSelected:
                          selectedSection == SettingsSectionId.languageRegion,
                      onTap: () => ref
                          .read(desktopSelectedSettingsSectionProvider.notifier)
                          .setSelectedSection(
                            SettingsSectionId.languageRegion,
                          ),
                    ),
                  ],
                ),

                // 3. Privacy & Security
                SettingsSection(
                  isCard: false,
                  title: context.l10n.profileSectionPrivacySecurity,
                  children: <Widget>[
                    SettingsTile(
                      icon: Icons.lock_rounded,
                      title: context.l10n.settingsPrivacyTitle,
                      iconColor: scheme.primary,
                      isSelected: selectedSection == SettingsSectionId.privacy,
                      onTap: () => ref
                          .read(desktopSelectedSettingsSectionProvider.notifier)
                          .setSelectedSection(SettingsSectionId.privacy),
                    ),
                    SettingsTile(
                      icon: Icons.enhanced_encryption_rounded,
                      title: context.l10n.settingsSecretChatsTitle,
                      iconColor: scheme.tertiary,
                      isSelected: selectedSection == SettingsSectionId.e2ee,
                      onTap: () => ref
                          .read(desktopSelectedSettingsSectionProvider.notifier)
                          .setSelectedSection(SettingsSectionId.e2ee),
                    ),
                  ],
                ),

                // 4. Notifications & Storage
                SettingsSection(
                  isCard: false,
                  title: context.l10n.settingsStorageTitle,
                  children: <Widget>[
                    SettingsTile(
                      icon: Icons.sd_storage_rounded,
                      title: context.l10n.settingsStorageTitle,
                      iconColor: scheme.tertiary,
                      isSelected: selectedSection == SettingsSectionId.storage,
                      onTap: () => ref
                          .read(desktopSelectedSettingsSectionProvider.notifier)
                          .setSelectedSection(SettingsSectionId.storage),
                    ),
                    SettingsTile(
                      icon: Icons.memory_rounded,
                      title: 'Система и устройство',
                      iconColor: scheme.primary,
                      isSelected:
                          selectedSection == SettingsSectionId.systemDevice,
                      onTap: () => ref
                          .read(desktopSelectedSettingsSectionProvider.notifier)
                          .setSelectedSection(SettingsSectionId.systemDevice),
                    ),
                    SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: context.l10n.settingsAboutTitle,
                      iconColor: scheme.onSurfaceVariant,
                      isSelected: selectedSection == SettingsSectionId.about,
                      onTap: () => ref
                          .read(desktopSelectedSettingsSectionProvider.notifier)
                          .setSelectedSection(SettingsSectionId.about),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(
                        color: scheme.error.withValues(alpha: 0.35),
                      ),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(
                      context.l10n.profileLogout,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Divider
          VerticalDivider(
            thickness: 1,
            width: 1,
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.3),
          ),

          // 3. Right Detail Pane
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 740),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey<SettingsSectionId>(selectedSection),
                    child: _buildDetailPane(selectedSection),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterProfileHeader(
    BuildContext context,
    AuthState auth,
    ColorScheme scheme,
    String displayName,
    String username,
    String bio,
  ) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerLow : scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.40),
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Stack(
                children: <Widget>[
                  PulseAvatar(
                    name: displayName,
                    avatarUrl: auth.profile?.avatarUrl,
                    radius: 26,
                    fallbackColor: scheme.primaryContainer,
                    textColor: scheme.onPrimaryContainer,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: scheme.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _uploadingAvatar ? null : _uploadAvatar,
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _uploadingAvatar
                              ? SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.onPrimary,
                                  ),
                                )
                              : Icon(
                                  Icons.photo_camera_rounded,
                                  size: 11,
                                  color: scheme.onPrimary,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      displayName,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (bio.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                bio,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (BuildContext ctx) => _EditProfileDialog(
                    initialName: displayName,
                    initialUsername: auth.session?.username ?? '',
                    initialBio: bio,
                    initialPhoneNumber: auth.profile?.phoneNumber,
                    initialBirthday: auth.profile?.birthday,
                    initialWorkingHours: auth.profile?.workingHours,
                    onUploadAvatar: _uploadAvatar,
                  ),
                );
              },
              icon: const Icon(Icons.edit_rounded, size: 15),
              label: Text(context.l10n.profileEdit, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPane(SettingsSectionId section) {
    switch (section) {
      case SettingsSectionId.account:
        return const SettingsAccountScreen(isEmbedded: true);
      case SettingsSectionId.appearance:
        return const SettingsAppearanceScreen(isEmbedded: true);
      case SettingsSectionId.chats:
        return const SettingsChatsScreen(isEmbedded: true);
      case SettingsSectionId.privacy:
        return const SettingsPrivacyScreen(isEmbedded: true);
      case SettingsSectionId.storage:
        return const SettingsStorageScreen(isEmbedded: true);
      case SettingsSectionId.languageRegion:
        return const SettingsLanguageRegionScreen(isEmbedded: true);
      case SettingsSectionId.preferences:
        return const SettingsPreferencesScreen(isEmbedded: true);
      case SettingsSectionId.systemDevice:
        return const SettingsSystemDeviceScreen(isEmbedded: true);
      case SettingsSectionId.about:
        return const SettingsAboutScreen(isEmbedded: true);
      case SettingsSectionId.e2ee:
        return const E2eeSettingsScreen(isEmbedded: true);
      case SettingsSectionId.sessions:
        return const SessionsScreen(isEmbedded: true);
    }
  }

  Widget _buildMobileProfile(
    BuildContext context,
    AuthState auth,
    ColorScheme scheme,
    String displayName,
    String username,
    String bio,
    String storageUsed,
  ) {
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
              bio: bio,
              badges: auth.profile?.visibleBadges ?? const <ApiBadge>[],
              onEdit: () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => _EditProfileDialog(
                    initialName: displayName,
                    initialUsername: auth.session?.username ?? '',
                    initialBio: bio,
                    initialPhoneNumber: auth.profile?.phoneNumber,
                    initialBirthday: auth.profile?.birthday,
                    initialWorkingHours: auth.profile?.workingHours,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  children: [
                    WorkingHoursWidget(
                      workingHours: auth.profile?.workingHours,
                      isEditable: true,
                      onEdit: () async {
                        final WorkingHours? updated =
                            await WorkingHoursPlannerDialog.show(
                          context,
                          initialWorkingHours: auth.profile?.workingHours,
                        );
                        if (updated != null) {
                          await ref
                              .read(authProvider.notifier)
                              .updateProfile(workingHours: updated);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    // 1. Account & Privacy
                    SettingsSection(
                      title: context.l10n.profileSectionAccount,
                      children: <Widget>[
                        SettingsTile(
                          icon: Icons.manage_accounts_rounded,
                          title: context.l10n.settingsAccountTitle,
                          subtitle: context.l10n.settingsAccountSubtitle,
                          iconColor: scheme.primary,
                          onTap: () => context.push('/settings/account'),
                        ),
                        SettingsTile(
                          icon: Icons.privacy_tip_rounded,
                          title: context.l10n.settingsPrivacyTitle,
                          subtitle: context.l10n.settingsPrivacySubtitle,
                          iconColor: scheme.secondary,
                          onTap: () => context.push('/settings/privacy'),
                        ),
                      ],
                    ),

                    // 2. Interface & Notifications
                    SettingsSection(
                      title: context.l10n.profileAppearance,
                      children: <Widget>[
                        SettingsTile(
                          icon: Icons.palette_rounded,
                          title: context.l10n.profileAppearance,
                          subtitle: context.l10n.profileAppearanceDesc,
                          iconColor: scheme.primary,
                          onTap: () => context.push('/settings/appearance'),
                        ),
                        SettingsTile(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'Чаты и медиа',
                          subtitle: 'Отправка по Enter, реакции, автозагрузка',
                          iconColor: scheme.primary,
                          onTap: () => context.push('/settings/chats'),
                        ),
                        SettingsTile(
                          icon: Icons.notifications_active_rounded,
                          title: context.l10n.settingsPreferencesTitle,
                          subtitle:
                              context.l10n.settingsPreferencesBannerSubtitle,
                          iconColor: scheme.secondary,
                          onTap: () => context.push('/settings/preferences'),
                        ),
                        SettingsTile(
                          icon: Icons.sd_storage_rounded,
                          title: context.l10n.settingsStorageTitle,
                          subtitle: storageUsed.isNotEmpty
                              ? storageUsed
                              : context.l10n.settingsStorageSubtitle,
                          iconColor: scheme.tertiary,
                          onTap: () => context.push('/settings/storage'),
                        ),
                        SettingsTile(
                          icon: Icons.language_rounded,
                          title: context.l10n.profileLanguage,
                          subtitle: context.l10n.profileLanguageDesc,
                          iconColor: scheme.onSurfaceVariant,
                          onTap: () => context.push('/settings/language-region'),
                        ),
                      ],
                    ),

                    // 3. About & System
                    SettingsSection(
                      title: context.l10n.profileSectionAbout,
                      children: <Widget>[
                        SettingsTile(
                          icon: Icons.memory_rounded,
                          title: 'Система и устройство',
                          subtitle: 'Характеристики смартфона, экран, процессор и память',
                          iconColor: scheme.primary,
                          onTap: () => context.push('/settings/system-device'),
                        ),
                        SettingsTile(
                          icon: Icons.info_outline_rounded,
                          title: context.l10n.settingsAboutTitle,
                          subtitle: context.l10n.settingsSupportAboutSubtitle,
                          iconColor: scheme.onSurfaceVariant,
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
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
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
    this.initialPhoneNumber,
    this.initialBirthday,
    this.initialWorkingHours,
    this.onUploadAvatar,
  });

  final String initialName;
  final String initialUsername;
  final String initialBio;
  final String? initialPhoneNumber;
  final String? initialBirthday;
  final WorkingHours? initialWorkingHours;
  final Future<void> Function()? onUploadAvatar;

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  static final RegExp _usernameRegExp = RegExp(r'^[a-zA-Z0-9_]{3,32}$');

  late final TextEditingController nameController;
  late final TextEditingController usernameController;
  late final TextEditingController bioController;
  late final TextEditingController phoneController;
  late final TextEditingController birthdayController;
  WorkingHours? _workingHours;
  bool _saving = false;
  String? _nameError;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.initialName);
    usernameController = TextEditingController(text: widget.initialUsername);
    bioController = TextEditingController(text: widget.initialBio);
    phoneController =
        TextEditingController(text: widget.initialPhoneNumber ?? '');
    birthdayController =
        TextEditingController(text: widget.initialBirthday ?? '');
    _workingHours = widget.initialWorkingHours;
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
    phoneController.dispose();
    birthdayController.dispose();
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

  Future<void> _selectBirthday() async {
    final DateTime initialDate = DateTime.tryParse(birthdayController.text) ??
        DateTime(2000, 1, 1);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final String formatted =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {
        birthdayController.text = formatted;
      });
    }
  }

  Future<void> _editWorkingHours() async {
    final WorkingHours? updated = await WorkingHoursPlannerDialog.show(
      context,
      initialWorkingHours: _workingHours,
    );
    if (updated != null) {
      setState(() {
        _workingHours = updated;
      });
    }
  }

  Future<void> _selectBadges() async {
    final AuthState auth = ref.read(authProvider);
    await BadgeSelectorDialog.show(
      context,
      initialSelectedBadgeIds: auth.profile?.visibleBadgeIds ?? const <int>[],
    );
  }

  Future<void> _save() async {
    if (_nameError != null || _usernameError != null) return;
    setState(() => _saving = true);

    final String username = usernameController.text.trim();
    final String? newUsername =
        username.isNotEmpty && username != widget.initialUsername
            ? username
            : null;
    final String phone = phoneController.text.trim();
    final String birthday = birthdayController.text.trim();

    final AuthActionResult result =
        await ref.read(authProvider.notifier).updateProfile(
              displayName: nameController.text.trim(),
              username: newUsername,
              bio: bioController.text.trim(),
              phoneNumber: phone.isNotEmpty ? phone : null,
              clearPhoneNumber: phone.isEmpty && widget.initialPhoneNumber != null,
              birthday: birthday.isNotEmpty ? birthday : null,
              clearBirthday: birthday.isEmpty && widget.initialBirthday != null,
              workingHours: _workingHours,
              clearWorkingHours:
                  _workingHours == null && widget.initialWorkingHours != null,
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
          onPressed: _saving || _nameError != null || _usernameError != null
              ? null
              : _save,
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.18),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.18),
                  ),
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
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.18),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.18),
                  ),
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
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Номер телефона',
                prefixIcon: const Icon(Icons.phone_rounded),
                filled: true,
                fillColor: scheme.surfaceContainerLow.withValues(alpha: 0.82),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.18),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.18),
                  ),
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
              controller: birthdayController,
              readOnly: true,
              onTap: _selectBirthday,
              decoration: InputDecoration(
                labelText: 'Дата рождения (ГГГГ-ММ-ДД)',
                prefixIcon: const Icon(Icons.cake_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today_rounded, size: 20),
                  onPressed: _selectBirthday,
                ),
                filled: true,
                fillColor: scheme.surfaceContainerLow.withValues(alpha: 0.82),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.18),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.18),
                  ),
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
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.18),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.18),
                  ),
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
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(
                      _workingHours == null || _workingHours!.isEmpty
                          ? 'График работы'
                          : 'График: ${_workingHours!.isOpenNow() ? "Открыто" : "Закрыто"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: _editWorkingHours,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.military_tech_rounded, size: 18),
                    label: Text(
                      'Бейджи (${auth.profile?.visibleBadgeIds.length ?? 0}/2)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: _selectBadges,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
