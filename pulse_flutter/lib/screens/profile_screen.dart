import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/theme/app_colors.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/storage/local_storage_service.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/image_compressor.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/working_hours_model.dart';
import 'package:pulse_flutter/models/settings/settings_node.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/widgets/common/app_pill_field.dart';
import 'package:pulse_flutter/widgets/nios_mark_badge.dart';
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
import 'package:pulse_flutter/services/settings/settings_registry.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/profile/ai_usage_card.dart';
import 'package:pulse_flutter/widgets/profile/badge_selector_dialog.dart';
import 'package:pulse_flutter/widgets/profile/my_qr_code_sheet.dart';
import 'package:pulse_flutter/widgets/profile/working_hours_planner_dialog.dart';
import 'package:pulse_flutter/widgets/profile/working_hours_widget.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({this.initialSection, super.key});

  final SettingsSectionId? initialSection;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final SearchController _searchController = SearchController();
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(desktopSelectedSettingsSectionProvider.notifier)
            .setSelectedSection(widget.initialSection!);
        if (MediaQuery.sizeOf(context).width < Breakpoints.medium) {
          final List<SettingsNavNode> sections =
              SettingsRegistry.getTopLevelSections();
          final SettingsNavNode? target = sections
              .where((s) => s.sectionId == widget.initialSection)
              .firstOrNull;
          if (target != null && mounted) {
            context.push(target.route);
          }
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(authProvider.notifier).refreshProfile();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
      final String ext =
          (file.extension ?? file.name.split('.').last).toLowerCase();
      final FileTypeInfo detected =
          FileTypeDetector.detectFromFileName(file.name);

      if (isVideo) {
        const Set<String> allowedVideoExts = <String>{'mp4', 'mov', 'webm'};
        if (!allowedVideoExts.contains(ext) || !detected.isVideo) {
          if (!mounted) return;
          AppToast.showError(
            context,
            'Поддерживаются только видеоформаты MP4, MOV, WebM',
          );
          return;
        }
      } else {
        const Set<String> allowedImageExts = <String>{
          'jpg',
          'jpeg',
          'png',
          'webp',
        };
        if (!allowedImageExts.contains(ext) || !detected.isImage) {
          if (!mounted) return;
          AppToast.showError(
            context,
            'Поддерживаются только изображения PNG, JPG, WebP',
          );
          return;
        }
      }

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

  Future<void> _shareProfile(String username) async {
    if (ref.read(uiSettingsProvider).haptics) {
      HapticService.tap();
    }
    final String url = 'https://ni-os.ru/u/$username';
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    AppToast.showSuccess(context, 'Ссылка на профиль скопирована');
  }

  Future<void> _copyNiosId(int? id) async {
    if (id == null) return;
    if (ref.read(uiSettingsProvider).haptics) {
      HapticService.tap();
    }
    await Clipboard.setData(ClipboardData(text: id.toString()));
    if (!mounted) return;
    AppToast.showSuccess(context, 'Nios ID скопирован');
  }

  Future<void> _openBadgeSelector(AuthState auth) async {
    final List<int>? updated = await BadgeSelectorDialog.show(
      context,
      initialSelectedBadgeIds: auth.profile?.visibleBadgeIds ?? const <int>[],
    );
    if (updated != null && mounted) {
      await ref.read(authProvider.notifier).refreshProfile();
    }
  }

  Future<void> _editWorkingHours(AuthState auth) async {
    final WorkingHours? updated = await WorkingHoursPlannerDialog.show(
      context,
      initialWorkingHours: auth.profile?.workingHours,
    );
    if (updated != null) {
      final AuthActionResult res = await ref
          .read(authProvider.notifier)
          .updateProfile(workingHours: updated);
      if (mounted) {
        if (res.success) {
          AppToast.showSuccess(context, 'График работы обновлен');
        } else {
          AppToast.showError(
            context,
            res.message ?? 'Ошибка сохранения графика',
          );
        }
      }
    }
  }

  String _getSectionBadgeValue(
    SettingsNavNode node,
    UiSettingsState settings,
    LocalStorageSnapshot? snapshot,
  ) {
    if (node.id == 'appearance') {
      final bool isRussian =
          Localizations.localeOf(context).languageCode == 'ru';
      return settings.themeMode == ThemeMode.dark
          ? (isRussian ? 'Тёмная' : 'Dark')
          : settings.themeMode == ThemeMode.light
              ? (isRussian ? 'Светлая' : 'Light')
              : (isRussian ? 'Системная' : 'System');
    } else if (node.id == 'storage') {
      return snapshot != null
          ? FileTypeDetector.formatFileSize(snapshot.totalBytes)
          : '0 Б';
    } else if (node.id == 'language') {
      final bool isRussian =
          Localizations.localeOf(context).languageCode == 'ru';
      return isRussian ? 'Русский' : 'English';
    } else if (node.id == 'about') {
      return AppConstants.appVersionWithPrefix;
    }
    return '';
  }

  Color _getSectionColor(SettingsGroup group, ColorScheme scheme) {
    switch (group) {
      case SettingsGroup.account:
      case SettingsGroup.appearance:
      case SettingsGroup.chats:
      case SettingsGroup.privacy:
      case SettingsGroup.language:
        return scheme.primary;
      case SettingsGroup.notifications:
      case SettingsGroup.motion:
        return scheme.secondary;
      case SettingsGroup.storage:
        return scheme.tertiary;
      case SettingsGroup.about:
        return scheme.onSurfaceVariant;
    }
  }

  Widget _buildSearchAnchor({required bool isWide}) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SearchAnchor(
      searchController: _searchController,
      viewElevation: 2.0,
      viewBackgroundColor: scheme.surface,
      builder: (BuildContext context, SearchController controller) {
        return SearchBar(
          controller: controller,
          hintText: 'Поиск настроек...',
          elevation: const WidgetStatePropertyAll<double>(0.0),
          backgroundColor: WidgetStatePropertyAll<Color>(
            scheme.surfaceContainerHigh.withValues(alpha: 0.6),
          ),
          padding: const WidgetStatePropertyAll<EdgeInsets>(
            EdgeInsets.symmetric(horizontal: 14.0),
          ),
          leading: Icon(
            Icons.search_rounded,
            color: scheme.onSurfaceVariant,
            size: 20,
          ),
          trailing: <Widget>[
            if (controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () => controller.clear(),
              ),
          ],
          onTap: () => controller.openView(),
          onChanged: (_) => controller.openView(),
        );
      },
      suggestionsBuilder:
          (BuildContext context, SearchController controller) {
        final List<SettingsSearchResult> results =
            SettingsRegistry.search(controller.text, context.l10n);

        if (results.isEmpty) {
          return <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Center(
                child: Text(
                  'Ничего не найдено',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          ];
        }

        return results.map((SettingsSearchResult result) {
          return ListTile(
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                result.node.icon,
                size: 20,
                color: scheme.primary,
              ),
            ),
            title: Text(
              result.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              result.breadcrumb,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
            onTap: () {
              controller.closeView(result.title);
              if (isWide && result.targetSectionId != null) {
                ref
                    .read(desktopSelectedSettingsSectionProvider.notifier)
                    .setSelectedSection(result.targetSectionId!);
              } else {
                context.push(result.targetRoute);
              }
            },
          );
        }).toList();
      },
    );
  }

  Widget _buildQuickProfileHeader(
    BuildContext context,
    AuthState auth,
    ColorScheme scheme,
    String displayName,
    String username, {
    bool isCompact = false,
  }) {
    return PressableSurface(
      onTap: () => _openEditProfile(
        context,
        displayName,
        auth,
        auth.profile?.bio ?? '',
      ),
      borderRadius: BorderRadius.circular(isCompact ? 16 : 20),
      color: scheme.surfaceContainerLow,
      border: Border.all(
        color: scheme.outlineVariant.withValues(alpha: 0.18),
        width: 1,
      ),
      padding: EdgeInsets.all(isCompact ? 12 : 14),
      child: Row(
        children: <Widget>[
          PulseAvatar(
            name: displayName,
            avatarUrl: auth.profile?.avatarUrl,
            radius: isCompact ? 22 : 26,
            fallbackColor: scheme.primaryContainer,
            textColor: scheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  username.isNotEmpty ? '@$username' : '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (auth.profile?.bio case final bio? when bio.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    bio,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          NiosMarkBadge(
            id: (auth.session?.userId ?? auth.profile?.id ?? 0).toString(),
            name: displayName,
            size: isCompact ? 36 : 42,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Изменить',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.edit_outlined,
                  size: 11,
                  color: scheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
    final int? niosId = auth.profile?.id ?? auth.session?.userId;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(18),
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
            // Row with Avatar + Identity info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Interactive Avatar with camera upload badge
                Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    PulseAvatar(
                      name: displayName,
                      avatarUrl: auth.profile?.avatarUrl,
                      radius: 36,
                      fallbackColor: scheme.primaryContainer,
                      textColor: scheme.onPrimaryContainer,
                      borderWidth: 2,
                      borderColor: scheme.surface,
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _uploadingAvatar ? null : _uploadAvatar,
                          customBorder: const CircleBorder(),
                          child: Container(
                            padding: const EdgeInsets.all(6),
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
                                    size: 13,
                                    color: scheme.onPrimary,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                // Identity texts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        displayName,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                          letterSpacing: -0.3,
                          color: scheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: <Widget>[
                          if (username.isNotEmpty) ...<Widget>[
                            Flexible(
                              child: Text(
                                '@$username',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Consumer(
                            builder: (BuildContext context, WidgetRef ref, _) {
                              final bool isOnline =
                                  ref.watch(connectivityProvider).value ?? true;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: isOnline
                                          ? AppColors.statusOnline
                                          : scheme.outline,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isOnline
                                        ? context.l10n.profileOnline
                                        : context.l10n.profileOffline,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                      if (bio.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          bio,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Metadata Chips (Nios ID, Phone, Birthday)
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (niosId != null)
                  InkWell(
                    onTap: () => _copyNiosId(niosId),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.badge_outlined, size: 13, color: scheme.primary),
                          const SizedBox(width: 5),
                          Text(
                            'ID: $niosId',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.copy_rounded,
                            size: 11,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (auth.profile?.phoneNumber?.isNotEmpty == true)
                  InkWell(
                    onTap: () async {
                      await Clipboard.setData(
                        ClipboardData(text: auth.profile!.phoneNumber!),
                      );
                      if (context.mounted) {
                        AppToast.showSuccess(context, 'Телефон скопирован');
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.phone_outlined, size: 13, color: scheme.primary),
                          const SizedBox(width: 5),
                          Text(
                            auth.profile!.phoneNumber!,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (auth.profile?.birthday?.isNotEmpty == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.cake_outlined, size: 13, color: scheme.primary),
                        const SizedBox(width: 5),
                        Text(
                          auth.profile!.birthday!,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Badges row with tap to manage
            if (auth.profile?.visibleBadges.isNotEmpty == true) ...<Widget>[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _openBadgeSelector(auth),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    ...auth.profile!.visibleBadges.map((ApiBadge b) {
                      return BadgeChip(
                        id: b.id,
                        name: b.name,
                        icon: b.icon,
                        color: b.color,
                        mode: BadgeDisplayMode.infoLabel,
                        showName: true,
                      );
                    }),
                  ],
                ),
              ),
            ],

            // Quick Action Buttons Row: Edit Profile & Share Profile
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: () =>
                          _openEditProfile(context, displayName, auth, bio),
                      icon: const Icon(Icons.edit_rounded, size: 15),
                      label: Text(
                        context.l10n.profileEdit,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 38,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: () => _shareProfile(username),
                    child: const Icon(Icons.share_outlined, size: 16),
                  ),
                ),
              ],
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
    UiSettingsState settings,
    LocalStorageSnapshot? storageSnapshot,
    String displayName,
    String username,
    String bio,
  ) {
    final List<SettingsNavNode> sections =
        SettingsRegistry.getTopLevelSections();

    final List<SettingsNavNode> generalSections = <SettingsNavNode>[];
    final List<SettingsNavNode> securitySections = <SettingsNavNode>[];
    final List<SettingsNavNode> systemSections = <SettingsNavNode>[];

    for (final SettingsNavNode s in sections) {
      if (s.group == SettingsGroup.account ||
          s.group == SettingsGroup.appearance ||
          s.group == SettingsGroup.chats) {
        generalSections.add(s);
      } else if (s.group == SettingsGroup.notifications ||
          s.group == SettingsGroup.privacy ||
          s.group == SettingsGroup.storage ||
          s.group == SettingsGroup.motion) {
        securitySections.add(s);
      } else {
        systemSections.add(s);
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          context.l10n.tabProfile,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: scheme.onSurface,
              ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'QR-код',
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.qr_code_rounded,
                size: 18,
                color: scheme.onSurface,
              ),
            ),
            onPressed: () => MyQrCodeSheet.show(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(authProvider.notifier).refreshProfile(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed(<Widget>[
                  // 1. Hero Profile Card
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

                  // 2. Working Hours (if configured)
                  if (auth.profile?.workingHours?.isNotEmpty == true) ...<Widget>[
                    const SizedBox(height: 12),
                    WorkingHoursWidget(
                      workingHours: auth.profile?.workingHours,
                      isEditable: true,
                      onEdit: () => _editWorkingHours(auth),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // 3. Search Bar for Settings
                  _buildSearchAnchor(isWide: false),
                  const SizedBox(height: 16),

                  // 4. Sections grouped into M3 Expressive Cards (exact from SettingsHub)
                  SettingsSection(
                    title: 'Основное',
                    children: generalSections.map((SettingsNavNode node) {
                      final String badgeVal =
                          _getSectionBadgeValue(node, settings, storageSnapshot);
                      return SettingsListItem.nav(
                        icon: node.icon,
                        title: node.title(context.l10n),
                        subtitle: node.subtitle?.call(context.l10n),
                        value: badgeVal.isNotEmpty ? badgeVal : null,
                        iconColor: _getSectionColor(node.group, scheme),
                        onTap: () => context.push(node.route),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  SettingsSection(
                    title: 'Безопасность и данные',
                    children: securitySections.map((SettingsNavNode node) {
                      final String badgeVal =
                          _getSectionBadgeValue(node, settings, storageSnapshot);
                      return SettingsListItem.nav(
                        icon: node.icon,
                        title: node.title(context.l10n),
                        subtitle: node.subtitle?.call(context.l10n),
                        value: badgeVal.isNotEmpty ? badgeVal : null,
                        iconColor: _getSectionColor(node.group, scheme),
                        onTap: () => context.push(node.route),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  SettingsSection(
                    title: 'Система и приложение',
                    children: systemSections.map((SettingsNavNode node) {
                      final String badgeVal =
                          _getSectionBadgeValue(node, settings, storageSnapshot);
                      return SettingsListItem.nav(
                        icon: node.icon,
                        title: node.title(context.l10n),
                        subtitle: node.subtitle?.call(context.l10n),
                        value: badgeVal.isNotEmpty ? badgeVal : null,
                        iconColor: _getSectionColor(node.group, scheme),
                        onTap: () => context.push(node.route),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // 5. Nios ID Section
                  SettingsSection(
                    title: 'Nios ID',
                    children: <Widget>[
                      SettingsListItem.nav(
                        icon: Icons.badge_outlined,
                        title: 'Управление аккаунтом Nios ID',
                        subtitle: 'Безопасность, 2FA и активные сессии',
                        iconColor: scheme.primary,
                        onTap: () => AppUrlLauncher.openUrl(
                          context,
                          'https://ni-os.ru/id/account',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 6. Logout action
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
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopMasterDetail(
    BuildContext context,
    AuthState auth,
    ColorScheme scheme,
    UiSettingsState settings,
    LocalStorageSnapshot? storageSnapshot,
    String displayName,
    String username,
  ) {
    final SettingsSectionId selectedSection =
        ref.watch(desktopSelectedSettingsSectionProvider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<SettingsNavNode> sections =
        SettingsRegistry.getTopLevelSections();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Left Master Pane
        Container(
          width: 360,
          decoration: BoxDecoration(
            color: isDark
                ? scheme.surfaceContainerLowest
                : scheme.surface.withValues(alpha: 0.65),
            border: Border(
              right: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
            children: <Widget>[
              // Search Anchor
              _buildSearchAnchor(isWide: true),
              const SizedBox(height: 12),

              // Compact Profile Header
              _buildQuickProfileHeader(
                context,
                auth,
                scheme,
                displayName,
                username,
                isCompact: true,
              ),
              const SizedBox(height: 14),

              // Top level sections from registry
              SettingsSection(
                isCard: false,
                title: 'Настройки',
                children: sections.map((SettingsNavNode node) {
                  final bool isSelected =
                      node.sectionId == selectedSection;
                  final String badgeVal =
                      _getSectionBadgeValue(node, settings, storageSnapshot);

                  return SettingsTile(
                    icon: node.icon,
                    title: node.title(context.l10n),
                    value: badgeVal.isNotEmpty ? badgeVal : null,
                    iconColor: _getSectionColor(node.group, scheme),
                    isSelected: isSelected,
                    onTap: () {
                      if (node.sectionId != null) {
                        ref
                            .read(
                              desktopSelectedSettingsSectionProvider.notifier,
                            )
                            .setSelectedSection(node.sectionId!);
                      }
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),
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

        const VerticalDivider(thickness: 1, width: 1),

        // Right Detail Pane
        Expanded(
          child: Container(
            color: scheme.surface,
            child: _buildDetailPane(selectedSection),
          ),
        ),
      ],
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

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final UiSettingsState settings = ref.watch(uiSettingsProvider);

    final String displayName = auth.profile?.displayName ??
        auth.session?.displayName ??
        context.l10n.profileGuestName;
    final String username =
        auth.session?.username ?? context.l10n.profileGuestUsername;
    final String bio = auth.profile?.bio.trim().isNotEmpty == true
        ? auth.profile!.bio.trim()
        : '';

    final LocalStorageSnapshot? storageSnapshot =
        ref.watch(storageSnapshotProvider).value;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final bool isWide =
            width >= Breakpoints.medium && MediaQuery.sizeOf(context).width >= Breakpoints.medium;

        if (isWide) {
          return _buildDesktopMasterDetail(
            context,
            auth,
            scheme,
            settings,
            storageSnapshot,
            displayName,
            username,
          );
        }

        return _buildMobileProfile(
          context,
          auth,
          scheme,
          settings,
          storageSnapshot,
          displayName,
          username,
          bio,
        );
      },
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
