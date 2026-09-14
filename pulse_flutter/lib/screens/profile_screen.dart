import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
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
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/common/app_pill_field.dart';
import 'package:pulse_flutter/widgets/profile/ai_usage_card.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploadingAvatar = false;

  Future<void> _uploadAvatar() async {
    final String? choice = await AppBottomSheets.show<String>(
      context: context,
      builder: (BuildContext context) {
        final ColorScheme scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
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

    final LocalStorageSnapshot? snapshot =
        ref.watch(storageSnapshotProvider).value;
    final String storageUsed = snapshot != null
        ? FileTypeDetector.formatFileSize(snapshot.totalBytes)
        : '';

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final bool isWide =
            width >= 760 && MediaQuery.sizeOf(context).width >= 760;

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
    final ThemeMode themeMode =
        ref.watch(uiSettingsProvider.select((UiSettingsState s) => s.themeMode));
    final bool isRussian =
        Localizations.localeOf(context).languageCode == 'ru';
    final String themeLabel = themeMode == ThemeMode.dark
        ? (isRussian ? 'Тёмная' : 'Dark')
        : themeMode == ThemeMode.light
            ? (isRussian ? 'Светлая' : 'Light')
            : (isRussian ? 'Системная' : 'System');
    final String languageLabel = isRussian ? 'Русский' : 'English';

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
                if (auth.profile?.aiUsage != null) ...<Widget>[
                  const SizedBox(height: 10),
                  AiUsageIndicatorCard(usage: auth.profile!.aiUsage!),
                ],
                const SizedBox(height: 14),

                // 1. Account
                SettingsSection(
                  isCard: false,
                  title: context.l10n.settingsAccountTitle,
                  children: <Widget>[
                    SettingsTile(
                      icon: Icons.manage_accounts_rounded,
                      title: context.l10n.settingsAccountTitle,
                      value: username.isNotEmpty ? '@$username' : null,
                      iconColor: scheme.primary,
                      isSelected: selectedSection == SettingsSectionId.account,
                      onTap: () => ref
                          .read(desktopSelectedSettingsSectionProvider.notifier)
                          .setSelectedSection(SettingsSectionId.account),
                    ),
                  ],
                ),

                // 2. Appearance & Chats
                SettingsSection(
                  isCard: false,
                  title: 'Внешний вид и чаты',
                  children: <Widget>[
                    SettingsTile(
                      icon: Icons.palette_rounded,
                      title: context.l10n.profileAppearance,
                      value: themeLabel,
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
                  ],
                ),

                // 3. Notifications & Sounds
                SettingsSection(
                  isCard: false,
                  title: 'Уведомления и звуки',
                  children: <Widget>[
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
                  ],
                ),

                // 4. Privacy & Security
                SettingsSection(
                  isCard: false,
                  title: context.l10n.settingsPrivacyTitle,
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
                  ],
                ),

                // 5. Storage & Data
                SettingsSection(
                  isCard: false,
                  title: 'Память и данные',
                  children: <Widget>[
                    SettingsTile(
                      icon: Icons.sd_storage_rounded,
                      title: context.l10n.settingsStorageTitle,
                      value: storageUsed.isNotEmpty ? storageUsed : '0 Б',
                      iconColor: scheme.tertiary,
                      isSelected: selectedSection == SettingsSectionId.storage,
                      onTap: () => ref
                          .read(desktopSelectedSettingsSectionProvider.notifier)
                          .setSelectedSection(SettingsSectionId.storage),
                    ),
                  ],
                ),

                // 6. Language & Region
                SettingsSection(
                  isCard: false,
                  title: context.l10n.profileLanguage,
                  children: <Widget>[
                    SettingsTile(
                      icon: Icons.language_rounded,
                      title: context.l10n.profileLanguage,
                      value: languageLabel,
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

                // 7. About App
                SettingsSection(
                  isCard: false,
                  title: 'О приложении',
                  children: <Widget>[
                    SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: context.l10n.settingsAboutTitle,
                      value: AppConstants.appVersionWithPrefix,
                      iconColor: scheme.onSurfaceVariant,
                      isSelected: selectedSection == SettingsSectionId.about,
                      onTap: () => ref
                          .read(desktopSelectedSettingsSectionProvider.notifier)
                          .setSelectedSection(SettingsSectionId.about),
                    ),
                    if (!kIsWeb)
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
            child: RepaintBoundary(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final Animation<double> curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  );
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
                    ),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.02, 0),
                        end: Offset.zero,
                      ).animate(curved),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<SettingsSectionId>(selectedSection),
                  child: _buildDetailPane(selectedSection),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditProfile(
    BuildContext context,
    String displayName,
    AuthState auth,
    String bio,
  ) async {
    final bool? updated = await _EditProfileSheet.show(
      context,
      initialName: auth.profile?.displayName.isNotEmpty == true
          ? auth.profile!.displayName
          : displayName,
      initialUsername: auth.profile?.username.isNotEmpty == true
          ? auth.profile!.username
          : (auth.session?.username ?? ''),
      initialBio: auth.profile?.bio.isNotEmpty == true
          ? auth.profile!.bio
          : bio,
      initialPhoneNumber: auth.profile?.phoneNumber,
      initialBirthday: auth.profile?.birthday,
      initialWorkingHours: auth.profile?.workingHours,
      onUploadAvatar: _uploadAvatar,
    );
    if (updated == true && context.mounted) {
      AppToast.showSuccess(context, 'Профиль успешно сохранён');
    }
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
        color: isDark
            ? scheme.surfaceContainerLow
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
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
                              ? AppLoadingIndicator(
                                  size: 10,
                                  color: scheme.onPrimary,
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
          if (auth.profile?.phoneNumber?.isNotEmpty == true ||
              auth.profile?.birthday?.isNotEmpty == true) ...<Widget>[
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: <Widget>[
                if (auth.profile?.phoneNumber?.isNotEmpty == true)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.phone_outlined, size: 12, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        auth.profile!.phoneNumber!,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                if (auth.profile?.birthday?.isNotEmpty == true)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.cake_outlined, size: 12, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        auth.profile!.birthday!,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => _openEditProfile(context, displayName, auth, bio),
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
        if (kIsWeb) return const SettingsAboutScreen(isEmbedded: true);
        return const SettingsSystemDeviceScreen(isEmbedded: true);
      case SettingsSectionId.about:
        return const SettingsAboutScreen(isEmbedded: true);
      case SettingsSectionId.e2ee:
        return const E2eeSettingsScreen(isEmbedded: true);
      case SettingsSectionId.sessions:
        return const SessionsScreen(isEmbedded: true);
    }
  }

  Widget _buildMobileHeroProfileCard(
    BuildContext context,
    AuthState auth,
    ColorScheme scheme,
    String displayName,
    String username,
    String bio,
  ) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? scheme.surfaceContainerLow
              : scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.22),
            width: 1,
          ),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Avatar with camera badge
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  PulseAvatar(
                    name: displayName,
                    avatarUrl: auth.profile?.avatarUrl,
                    radius: 34,
                    fallbackColor: scheme.primaryContainer,
                    textColor: scheme.onPrimaryContainer,
                    borderWidth: 2,
                    borderColor: scheme.surface,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: GestureDetector(
                      onTap: _uploadingAvatar ? null : _uploadAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.surface, width: 2),
                        ),
                        child: _uploadingAvatar
                            ? AppLoadingIndicator(
                                size: 10,
                                color: scheme.onPrimary,
                              )
                            : Icon(
                                Icons.photo_camera_rounded,
                                size: 12,
                                color: scheme.onPrimary,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            displayName,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              letterSpacing: -0.2,
                              color: scheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (username.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        '@$username',
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (bio.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        bio,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12.5,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (auth.profile?.phoneNumber?.isNotEmpty == true) ...<Widget>[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.phone_outlined,
                            size: 13,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            auth.profile!.phoneNumber!,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (auth.profile?.birthday?.isNotEmpty == true) ...<Widget>[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.cake_outlined,
                            size: 13,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            auth.profile!.birthday!,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Badges if present
          if (auth.profile?.visibleBadges.isNotEmpty == true) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: auth.profile!.visibleBadges.take(3).map((ApiBadge b) {
                return BadgeChip(
                  id: b.id,
                  name: b.name,
                  icon: b.icon,
                  color: b.color,
                  mode: BadgeDisplayMode.infoLabel,
                  showName: true,
                );
              }).toList(),
            ),
          ],

          // Edit profile action button
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              width: double.infinity,
              height: 38,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: () => _openEditProfile(context, displayName, auth, bio),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: Text(
                  context.l10n.profileEdit,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
    final ThemeMode themeMode =
        ref.watch(uiSettingsProvider.select((UiSettingsState s) => s.themeMode));
    final bool isRussian =
        Localizations.localeOf(context).languageCode == 'ru';
    final String themeLabel = themeMode == ThemeMode.dark
        ? (isRussian ? 'Тёмная' : 'Dark')
        : themeMode == ThemeMode.light
            ? (isRussian ? 'Светлая' : 'Light')
            : (isRussian ? 'Системная' : 'System');
    final String languageLabel = isRussian ? 'Русский' : 'English';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          context.l10n.profileSettingsSection,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: scheme.onSurface,
              ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: context.l10n.profileEdit,
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.edit_outlined, size: 18, color: scheme.onSurface),
            ),
            onPressed: () => _openEditProfile(context, displayName, auth, bio),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed(<Widget>[
          // Hero Profile Card
          _buildMobileHeroProfileCard(
            context,
            auth,
            scheme,
            displayName,
            username,
            bio,
          ),
          if (auth.profile?.aiUsage != null) ...<Widget>[
            const SizedBox(height: 12),
            AiUsageIndicatorCard(usage: auth.profile!.aiUsage!),
          ],
          const SizedBox(height: 12),

          // Working Hours
          if (auth.profile?.workingHours?.isNotEmpty == true) ...<Widget>[
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
                  final AuthActionResult res = await ref
                      .read(authProvider.notifier)
                      .updateProfile(workingHours: updated);
                  if (context.mounted) {
                    if (res.success) {
                      AppToast.showSuccess(context, 'График работы обновлен');
                    } else {
                      AppToast.showError(context, res.message ?? 'Ошибка сохранения графика');
                    }
                  }
                }
              },
            ),
            const SizedBox(height: 12),
          ],

          // 1. Account
          SettingsSection(
            title: context.l10n.settingsAccountTitle,
            children: <Widget>[
              SettingsTile(
                icon: Icons.person_rounded,
                title: context.l10n.settingsAccountTitle,
                value: username.isNotEmpty ? '@$username' : null,
                iconColor: scheme.primary,
                onTap: () => context.push('/settings/account'),
              ),
            ],
          ),

          // 2. Appearance & Chats
          SettingsSection(
            title: 'Внешний вид и чаты',
            children: <Widget>[
              SettingsTile(
                icon: Icons.palette_rounded,
                title: context.l10n.profileAppearance,
                value: themeLabel,
                iconColor: scheme.tertiary,
                onTap: () => context.push('/settings/appearance'),
              ),
              SettingsTile(
                icon: Icons.chat_bubble_rounded,
                title: 'Чаты и медиа',
                iconColor: scheme.primary,
                onTap: () => context.push('/settings/chats'),
              ),
            ],
          ),

          // 3. Notifications & Sounds
          SettingsSection(
            title: 'Уведомления и звуки',
            children: <Widget>[
              SettingsTile(
                icon: Icons.notifications_active_rounded,
                title: context.l10n.settingsPreferencesTitle,
                iconColor: scheme.secondary,
                onTap: () => context.push('/settings/preferences'),
              ),
            ],
          ),

          // 4. Security & Privacy
          SettingsSection(
            title: context.l10n.settingsPrivacyTitle,
            children: <Widget>[
              SettingsTile(
                icon: Icons.security_rounded,
                title: context.l10n.settingsPrivacyTitle,
                iconColor: scheme.primary,
                onTap: () => context.push('/settings/privacy'),
              ),
            ],
          ),

          // 5. Storage & Data
          SettingsSection(
            title: 'Память и данные',
            children: <Widget>[
              SettingsTile(
                icon: Icons.pie_chart_rounded,
                title: context.l10n.settingsStorageTitle,
                value: storageUsed.isNotEmpty ? storageUsed : '0 Б',
                iconColor: scheme.secondary,
                onTap: () => context.push('/settings/storage'),
              ),
            ],
          ),

          // 6. Language & Region
          SettingsSection(
            title: context.l10n.profileLanguage,
            children: <Widget>[
              SettingsTile(
                icon: Icons.language_rounded,
                title: context.l10n.profileLanguage,
                value: languageLabel,
                iconColor: scheme.primary,
                onTap: () => context.push('/settings/language-region'),
              ),
            ],
          ),

          // 7. About & System
          SettingsSection(
            title: context.l10n.profileSectionAbout,
            children: <Widget>[
              SettingsTile(
                icon: Icons.info_rounded,
                title: context.l10n.settingsAboutTitle,
                value: AppConstants.appVersionWithPrefix,
                iconColor: scheme.tertiary,
                onTap: () => context.push('/settings/about'),
              ),
              if (!kIsWeb)
                SettingsTile(
                  icon: Icons.memory_rounded,
                  title: 'Система и устройство',
                  iconColor: scheme.onSurfaceVariant,
                  onTap: () => context.push('/settings/system-device'),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Logout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(
                  color: scheme.error.withValues(alpha: 0.35),
                ),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded, size: 19),
              label: Text(
                context.l10n.profileLogout,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),

          const SizedBox(height: 110),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({
    required this.initialName,
    required this.initialUsername,
    required this.initialBio,
    this.initialPhoneNumber,
    this.initialBirthday,
    this.initialWorkingHours,
    this.onUploadAvatar,
    this.isDialog = false,
  });

  final String initialName;
  final String initialUsername;
  final String initialBio;
  final String? initialPhoneNumber;
  final String? initialBirthday;
  final WorkingHours? initialWorkingHours;
  final Future<void> Function()? onUploadAvatar;
  final bool isDialog;

  static Future<bool?> show(
    BuildContext context, {
    required String initialName,
    required String initialUsername,
    required String initialBio,
    String? initialPhoneNumber,
    String? initialBirthday,
    WorkingHours? initialWorkingHours,
    Future<void> Function()? onUploadAvatar,
  }) {
    final bool isWide = MediaQuery.sizeOf(context).width >= 600;
    if (isWide) {
      return showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 780),
            child: _EditProfileSheet(
              initialName: initialName,
              initialUsername: initialUsername,
              initialBio: initialBio,
              initialPhoneNumber: initialPhoneNumber,
              initialBirthday: initialBirthday,
              initialWorkingHours: initialWorkingHours,
              onUploadAvatar: onUploadAvatar,
              isDialog: true,
            ),
          ),
        ),
      );
    }

    return AppBottomSheets.show<bool>(
      context: context,
      builder: (BuildContext ctx) => _EditProfileSheet(
        initialName: initialName,
        initialUsername: initialUsername,
        initialBio: initialBio,
        initialPhoneNumber: initialPhoneNumber,
        initialBirthday: initialBirthday,
        initialWorkingHours: initialWorkingHours,
        onUploadAvatar: onUploadAvatar,
        isDialog: false,
      ),
    );
  }

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  static final RegExp _usernameRegExp = RegExp(r'^[a-zA-Z0-9_]{3,32}$');

  late final TextEditingController nameController;
  late final TextEditingController usernameController;
  late final TextEditingController bioController;
  late final TextEditingController phoneController;
  late final TextEditingController birthdayController;
  WorkingHours? _workingHours;
  String? _nameError;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.initialName);
    usernameController = TextEditingController(text: widget.initialUsername);
    bioController = TextEditingController(text: widget.initialBio);
    phoneController = TextEditingController(
      text: widget.initialPhoneNumber?.replaceAll(RegExp(r'\D'), '') ?? '',
    );
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

  Widget _buildInputField({
    required ColorScheme scheme,
    required TextTheme textTheme,
    required IconData icon,
    required String label,
    required TextEditingController controller,
    String? hintText,
    String? errorText,
    String? prefixText,
    int? maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final bool hasError = errorText != null;
    final bool isMultiline = maxLines != null && maxLines > 1;

    if (isMultiline) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: hasError
                      ? scheme.error
                      : scheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: hasError ? scheme.error : scheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: controller,
              maxLines: maxLines,
              maxLength: maxLength,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              style: textTheme.bodyLarge?.copyWith(
                color: scheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: hintText,
                errorText: errorText,
                counterText: '',
                fillColor: scheme.surfaceContainerHigh,
                filled: true,
                border: const OutlineInputBorder(
                  borderRadius: AppRadii.mdRadius,
                  borderSide: BorderSide.none,
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: AppRadii.mdRadius,
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadii.mdRadius,
                  borderSide: BorderSide(
                    color: scheme.primary.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 16,
                  color: hasError
                      ? scheme.error
                      : scheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: hasError ? scheme.error : scheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          AppPillField(
            controller: controller,
            hintText: hintText,
            prefixText: prefixText,
            errorText: errorText,
            maxLength: maxLength,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            fillColor: scheme.surfaceContainerHigh,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_nameError != null || _usernameError != null) return;

    final String username = usernameController.text.trim();
    final String? newUsername =
        username.isNotEmpty && username != widget.initialUsername
            ? username
            : null;
    final String rawDigits =
        phoneController.text.replaceAll(RegExp(r'\D'), '').trim();
    String? formattedPhone;
    if (rawDigits.isNotEmpty) {
      String digits = rawDigits;
      if (digits.startsWith('8') && digits.length == 11) {
        digits = '7${digits.substring(1)}';
      }
      formattedPhone = '+$digits';
      if (!RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(formattedPhone)) {
        AppToast.showError(
          context,
          'Номер телефона должен содержать от 7 до 15 цифр',
        );
        return;
      }
    }
    final String birthday = birthdayController.text.trim();
    final String displayName = nameController.text.trim();
    final String bio = bioController.text.trim();
    final WorkingHours? workingHours = _workingHours;
    final bool clearPhoneNumber =
        rawDigits.isEmpty && widget.initialPhoneNumber != null;
    final bool clearBirthday =
        birthday.isEmpty && widget.initialBirthday != null;
    final bool clearWorkingHours =
        (workingHours == null || workingHours.isEmpty) &&
            widget.initialWorkingHours != null;

    try {
      final AuthActionResult result =
          await ref.read(authProvider.notifier).updateProfile(
                displayName: displayName,
                username: newUsername,
                bio: bio,
                phoneNumber: formattedPhone,
                clearPhoneNumber: clearPhoneNumber,
                birthday: birthday.isNotEmpty ? birthday : null,
                clearBirthday: clearBirthday,
                workingHours: workingHours,
                clearWorkingHours: clearWorkingHours,
              );

      if (!mounted) return;
      if (result.success) {
        Navigator.of(context).pop(true);
      } else {
        AppToast.showError(
          context,
          result.message ?? 'Ошибка сохранения профиля',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e);
      }
    }
  }

  Widget _buildCard({
    required ColorScheme scheme,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadii.mdRadius,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.12 : 0.18),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: AppRadii.mdRadius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AuthState auth = ref.watch(authProvider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerLow : scheme.surface,
        borderRadius: widget.isDialog
            ? BorderRadius.circular(28)
            : const BorderRadius.vertical(top: Radius.circular(28)),
        border: widget.isDialog
            ? Border.all(
                color: scheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.3),
                width: 1,
              )
            : null,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Drag handle on mobile
            if (!widget.isDialog) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],

            // Top Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: Text(
                      context.l10n.commonCancel,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      context.l10n.profileEdit,
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      minimumSize: const Size(60, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _nameError != null || _usernameError != null ? null : _save,
                    child: Text(
                      context.l10n.commonSave,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.15),
            ),

            // Scrollable Form
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 20 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Avatar center
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Stack(
                            clipBehavior: Clip.none,
                            children: <Widget>[
                              PulseAvatar(
                                name: widget.initialName,
                                avatarUrl: auth.profile?.avatarUrl,
                                radius: 44,
                                fallbackColor: scheme.primaryContainer,
                                textColor: scheme.onPrimaryContainer,
                                borderWidth: 3,
                                borderColor: scheme.surface,
                              ),
                              if (widget.onUploadAvatar != null)
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Material(
                                    color: scheme.primary,
                                    shape: const CircleBorder(),
                                    elevation: 2,
                                    child: InkWell(
                                      onTap: widget.onUploadAvatar,
                                      customBorder: const CircleBorder(),
                                      child: Padding(
                                        padding: const EdgeInsets.all(7),
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
                          if (widget.onUploadAvatar != null) ...<Widget>[
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: widget.onUploadAvatar,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Text(
                                'Изменить фотографию',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 1: Личные данные
                    _buildCard(
                      scheme: scheme,
                      isDark: isDark,
                      children: <Widget>[
                        _buildInputField(
                          scheme: scheme,
                          textTheme: textTheme,
                          icon: Icons.person_outline_rounded,
                          label: context.l10n.profileDisplayName,
                          controller: nameController,
                          hintText: 'Ваше имя',
                          errorText: _nameError,
                          maxLength: 64,
                        ),
                        Divider(
                          height: 1,
                          indent: 50,
                          color: scheme.outlineVariant.withValues(alpha: 0.12),
                        ),
                        _buildInputField(
                          scheme: scheme,
                          textTheme: textTheme,
                          icon: Icons.notes_rounded,
                          label: context.l10n.profileDescription,
                          controller: bioController,
                          hintText: 'Расскажите о себе...',
                          maxLines: 2,
                          maxLength: 500,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Section 2: Контакты и аккаунт
                    _buildCard(
                      scheme: scheme,
                      isDark: isDark,
                      children: <Widget>[
                        _buildInputField(
                          scheme: scheme,
                          textTheme: textTheme,
                          icon: Icons.alternate_email_rounded,
                          label: context.l10n.profileUsernameLabel,
                          controller: usernameController,
                          prefixText: '@',
                          errorText: _usernameError,
                        ),
                        Divider(
                          height: 1,
                          indent: 50,
                          color: scheme.outlineVariant.withValues(alpha: 0.12),
                        ),
                        _buildInputField(
                          scheme: scheme,
                          textTheme: textTheme,
                          icon: Icons.phone_outlined,
                          label: 'Номер телефона',
                          controller: phoneController,
                          hintText: '79990000000',
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 16,
                        ),
                        Divider(
                          height: 1,
                          indent: 50,
                          color: scheme.outlineVariant.withValues(alpha: 0.12),
                        ),
                        InkWell(
                          onTap: _selectBirthday,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  Icons.cake_outlined,
                                  size: 20,
                                  color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                        'Дата рождения',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        birthdayController.text.isNotEmpty
                                            ? birthdayController.text
                                            : 'Не указана',
                                        style: textTheme.bodyLarge?.copyWith(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: birthdayController.text.isNotEmpty
                                              ? scheme.onSurface
                                              : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Section 3: График работы
                    _buildCard(
                      scheme: scheme,
                      isDark: isDark,
                      children: <Widget>[
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          leading: Icon(
                            Icons.schedule_rounded,
                            color: scheme.primary,
                            size: 22,
                          ),
                          title: const Text(
                            'График работы',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          subtitle: Text(
                            _workingHours == null || _workingHours!.isEmpty
                                ? 'Не настроен'
                                : (_workingHours!.isOpenNow() ? 'Открыто сейчас' : 'Закрыто'),
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                          onTap: _editWorkingHours,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
