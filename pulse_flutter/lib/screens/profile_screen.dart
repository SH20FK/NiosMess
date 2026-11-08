import 'package:pulse_flutter/core/platform/client_capabilities.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/widgets/settings/settings_profile_header.dart';
import 'package:pulse_flutter/widgets/profile/edit_profile_sheet.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/storage/local_storage_service.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/image_compressor.dart';
import 'package:pulse_flutter/models/settings/settings_node.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
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
import 'package:pulse_flutter/screens/settings_energy_saving_screen.dart';
import 'package:pulse_flutter/screens/settings_plus_screen.dart';
import 'package:pulse_flutter/screens/settings_system_device_screen.dart';
import 'package:pulse_flutter/services/settings/settings_registry.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/profile/badge_selector_dialog.dart';
import 'package:pulse_flutter/widgets/profile/my_qr_code_sheet.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';
import 'package:pulse_flutter/features/settings/application/settings_anchor_controller.dart';
import 'package:pulse_flutter/features/settings/application/settings_health_controller.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_issue_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({this.initialSection, super.key});

  final SettingsSectionId? initialSection;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final SearchController _searchController = SearchController();
  bool _uploadingAvatar = false;

  bool get _browser => ref.read(clientCapabilitiesProvider).browserWorkspace;
  SettingsSectionId get _webSection =>
      widget.initialSection == SettingsSectionId.systemDevice
      ? SettingsSectionId.about
      : widget.initialSection ?? SettingsSectionId.account;
  void _selectSection(SettingsSectionId section) {
    if (_browser) {
      context.go('/main/settings?section=${section.name}');
    } else {
      ref
          .read(desktopSelectedSettingsSectionProvider.notifier)
          .setSelectedSection(section);
    }
  }

  void _openSection(SettingsNavNode node) {
    if (_browser && node.sectionId != null) {
      _selectSection(node.sectionId!);
    } else {
      context.push(node.route);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialSection != null &&
        !ref.read(clientCapabilitiesProvider).browserWorkspace) {
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
    if (_uploadingAvatar) return;
    final owner = ref.read(authProvider).session;
    bool ownsSession() =>
        mounted &&
        owner != null &&
        ref.read(authProvider).session?.userId == owner.userId &&
        ref.read(authProvider).session?.accessToken == owner.accessToken &&
        !ref.read(authProvider.notifier).isLoggingOut;
    if (!mounted || !ownsSession()) return;
    setState(() => _uploadingAvatar = true);
    try {
      final choice = await AppBottomSheets.show<String>(
        context: context,
        builder: (sheetContext) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SettingsSection(
            children: [
              SettingsListItem.nav(
                icon: Icons.photo_library_outlined,
                title: context.l10n.settingsProfileChoosePhoto,
                subtitle: context.l10n.settingsProfilePhotoHint,
                onTap: () => Navigator.of(sheetContext).pop('photo'),
              ),
              SettingsListItem.nav(
                icon: Icons.videocam_outlined,
                title: context.l10n.settingsProfileChooseVideo,
                subtitle: context.l10n.settingsProfileVideoHint,
                onTap: () => Navigator.of(sheetContext).pop('video'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || choice == null || !ownsSession()) return;
      final isVideo = choice == 'video';
      final result = await FilePicker.pickFiles(
        type: isVideo ? FileType.video : FileType.image,
      );
      if (!mounted || result.isEmpty || !ownsSession()) return;
      final file = result.first;
      final knownLength = file.lengthSync();
      if (knownLength != null && knownLength > 8 * 1024 * 1024) {
        AppToast.showError(context, context.l10n.settingsProfileFileTooLarge);
        return;
      }
      final ext = (file.extension ?? file.name.split('.').last).toLowerCase();
      final detected = FileTypeDetector.detectFromFileName(file.name);
      if (isVideo
          ? !{'mp4', 'mov', 'webm'}.contains(ext) || !detected.isVideo
          : !{'jpg', 'jpeg', 'png', 'webp'}.contains(ext) ||
                !detected.isImage) {
        AppToast.showError(
          context,
          isVideo
              ? context.l10n.settingsProfileVideoFormats
              : context.l10n.settingsProfilePhotoFormats,
        );
        return;
      }
      Uint8List bytes = await file.readAsBytes();
      if (!mounted || bytes.isEmpty || !ownsSession()) return;
      if (bytes.length > 8 * 1024 * 1024) {
        AppToast.showError(context, context.l10n.settingsProfileFileTooLarge);
        return;
      }
      if (!isVideo) {
        bytes =
            await ImageCompressor.compressImageBytes(
              bytes: bytes,
              fileName: file.name,
            ) ??
            bytes;
        if (!mounted || !ownsSession()) return;
      }
      await ref
          .read(authRepositoryProvider)
          .uploadAvatar(bytes, filename: file.name, isVideo: isVideo);
      if (!mounted || !ownsSession()) return;
      await ref.read(authProvider.notifier).refreshProfile();
      if (mounted && ownsSession()) {
        AppToast.showSuccess(context, context.l10n.profileAvatarUpdated);
      }
    } catch (_) {
      if (mounted && ownsSession()) {
        AppToast.showError(context, context.l10n.settingsProfileAvatarFailed);
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _logout() async {
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: context.l10n.profileLogoutConfirmTitle,
      subtitle: context.l10n.secretLogoutWarning,
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
    AppToast.showSuccess(context, context.l10n.settingsV2ProfileCopied);
  }

  Future<void> _copyNiosId(int? id) async {
    if (id == null) return;
    if (ref.read(uiSettingsProvider).haptics) {
      HapticService.tap();
    }
    await Clipboard.setData(ClipboardData(text: id.toString()));
    if (!mounted) return;
    AppToast.showSuccess(context, context.l10n.settingsV2IdCopied);
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

  String _getSectionBadgeValue(
    SettingsNavNode node,
    UiSettingsState settings,
    LocalStorageSnapshot? snapshot,
  ) {
    if (node.id == 'appearance') {
      return settings.themeMode == ThemeMode.dark
          ? context.l10n.commonDark
          : settings.themeMode == ThemeMode.light
          ? context.l10n.commonLight
          : context.l10n.commonSystem;
    } else if (node.id == 'storage') {
      if (_browser) return '';
      return snapshot != null
          ? FileTypeDetector.formatFileSize(snapshot.totalBytes)
          : '—';
    } else if (node.id == 'language') {
      final bool isRussian =
          Localizations.localeOf(context).languageCode == 'ru';
      return isRussian
          ? context.l10n.languageRussian
          : context.l10n.languageEnglish;
    } else if (node.id == 'energy_saving') {
      return '';
    } else if (node.id == 'about') {
      return AppConstants.appVersionWithPrefix;
    }
    return '';
  }

  Widget _buildSearchAnchor({required bool isWide}) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SearchAnchor(
      searchController: _searchController,
      isFullScreen: !isWide,
      viewElevation: 0,
      viewBackgroundColor: scheme.surface,
      builder: (BuildContext context, SearchController controller) {
        return SearchBar(
          controller: controller,
          hintText: context.l10n.settingsV2Search,
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
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () => controller.clear(),
              ),
          ],
          onTap: () => controller.openView(),
          onChanged: (_) => controller.openView(),
        );
      },
      suggestionsBuilder: (BuildContext context, SearchController controller) {
        final List<SettingsSearchResult> results = SettingsRegistry.search(
          controller.text,
          context.l10n,
        );

        if (results.isEmpty) {
          return <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Center(
                child: Text(
                  controller.text.trim().isEmpty
                      ? context.l10n.settingsV2SearchEmpty
                      : context.l10n.settingsV2SearchNone,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ];
        }

        return results.map((SettingsSearchResult result) {
          return SettingsListItem.nav(
            icon: result.node.icon,
            title: result.title,
            subtitle: result.breadcrumb,
            isSection: true,
            onTap: () {
              controller.closeView(result.title);
              if (result.anchor != null && result.anchor!.isNotEmpty) {
                ref
                    .read(settingsAnchorControllerProvider.notifier)
                    .request(route: result.targetRoute, anchor: result.anchor!);
              }
              if ((_browser || isWide) && result.targetSectionId != null) {
                _selectSection(result.targetSectionId!);
              } else {
                context.push(result.targetRoute);
              }
            },
          );
        }).toList();
      },
    );
  }

  String usernameForProfile(AuthState auth) =>
      auth.profile?.username ?? auth.session?.username ?? '';

  List<({String title, Set<SettingsGroup> groups})> _groups() => [
    (
      title: context.l10n.settingsGroupCommunication,
      groups: {SettingsGroup.chats, SettingsGroup.notifications},
    ),
    (
      title: context.l10n.settingsGroupPersonalization,
      groups: {
        SettingsGroup.appearance,
        SettingsGroup.language,
        SettingsGroup.motion,
      },
    ),
    (
      title: context.l10n.settingsGroupSecurity,
      groups: {SettingsGroup.account, SettingsGroup.privacy},
    ),
    (
      title: context.l10n.settingsGroupApplication,
      groups: {SettingsGroup.storage, SettingsGroup.plus, SettingsGroup.about},
    ),
  ];

  List<Widget> _sectionGroups(
    UiSettingsState settings,
    LocalStorageSnapshot? snapshot, {
    SettingsSectionId? selected,
  }) {
    final sections = SettingsRegistry.getTopLevelSections();
    return [
      for (final group in _groups())
        Semantics(
          container: true,
          label: group.title,
          child: SettingsSection(
            children: [
              for (final node in sections.where(
                (n) => group.groups.contains(n.group),
              ))
                SettingsListItem.nav(
                  key: ValueKey('settings-destination-${node.id}'),
                  icon: node.icon,
                  title: node.title(context.l10n),
                  value: _getSectionBadgeValue(node, settings, snapshot),
                  isSection: true,
                  isSelected: selected != null && node.sectionId == selected,
                  onTap: () {
                    if (selected != null && node.sectionId != null) {
                      _selectSection(node.sectionId!);
                    } else {
                      _openSection(node);
                    }
                  },
                ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _healthIssues() => ref
      .watch(settingsHealthProvider)
      .take(2)
      .map(
        (issue) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SettingsIssueCard(issue: issue),
        ),
      )
      .toList();

  Widget _logoutAction() => SettingsSection(
    children: [
      SettingsListItem.danger(
        icon: Icons.logout_rounded,
        title: context.l10n.profileLogout,
        onTap: _logout,
      ),
    ],
  );

  Widget _buildQuickProfileHeader(
    BuildContext context,
    AuthState auth,
    ColorScheme scheme,
    String displayName,
    String username,
  ) => Padding(
    key: const ValueKey('settings-profile-header'),
    padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
    child: Column(
      children: [
        Semantics(
          button: true,
          label: context.l10n.settingsProfileChangePhoto,
          child: InkWell(
            onTap: _uploadingAvatar ? null : _uploadAvatar,
            customBorder: const CircleBorder(),
            child: PulseAvatar(
              name: displayName,
              avatarUrl: auth.profile?.avatarUrl,
              radius: 42,
              fallbackColor: scheme.primaryContainer,
              textColor: scheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          displayName,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (username.isNotEmpty)
          Text(
            '@$username',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () => _openEditProfile(
                context,
                displayName,
                auth,
                auth.profile?.bio ?? '',
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(context.l10n.profileEdit),
            ),
            IconButton(
              tooltip: context.l10n.settingsV2Qr,
              onPressed: () => MyQrCodeSheet.show(context),
              icon: const Icon(Icons.qr_code_rounded),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildMobileProfile(
    BuildContext context,
    AuthState auth,
    ColorScheme scheme,
    UiSettingsState settings,
    LocalStorageSnapshot? storageSnapshot,
    String displayName,
    String username,
    String bio,
  ) => Scaffold(
    backgroundColor: scheme.surface,
    body: RefreshIndicator(
      onRefresh: () => ref.read(authProvider.notifier).refreshProfile(),
      child: CustomScrollView(
        key: const PageStorageKey('settings-overview-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SettingsProfileHeader(
            displayName: displayName,
            username: username,
            avatarUrl: auth.profile?.avatarUrl,
            busy: _uploadingAvatar,
            onAvatar: _uploadAvatar,
            onEdit: () => _openEditProfile(context, displayName, auth, bio),
            onQr: () => MyQrCodeSheet.show(context),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                _buildSearchAnchor(isWide: false),
                const SizedBox(height: 20),
                ..._healthIssues(),
                ..._sectionGroups(settings, storageSnapshot),
                _logoutAction(),
              ]),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _animatedDetail(SettingsSectionId section) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : M3Durations.medium1,
      reverseDuration: reduced ? Duration.zero : M3Durations.short3,
      switchInCurve: M3SpringCurves.expressiveDecel,
      switchOutCurve: M3SpringCurves.expressiveAccel,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, .015),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [
          for (final old in previous)
            ExcludeFocus(child: IgnorePointer(child: old)),
          ?current,
        ],
      ),
      child: KeyedSubtree(
        key: ValueKey(section),
        child: _buildDetailPane(section),
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
    final selected = _browser
        ? _webSection
        : ref.watch(desktopSelectedSettingsSectionProvider);
    return Material(
      color: scheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const ValueKey('settings-master-pane'),
            width: _browser
                ? (MediaQuery.sizeOf(context).width * .27).clamp(300.0, 360.0)
                : 340,
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(
                right: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: .35),
                ),
              ),
            ),
            child: ListView(
              key: const PageStorageKey('settings-navigation-scroll'),
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    context.l10n.tabSettings,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildQuickProfileHeader(
                  context,
                  auth,
                  scheme,
                  displayName,
                  username,
                ),
                _buildSearchAnchor(isWide: true),
                const SizedBox(height: 20),
                ..._healthIssues(),
                ..._sectionGroups(
                  settings,
                  storageSnapshot,
                  selected: selected,
                ),
                _logoutAction(),
              ],
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: scheme.surface,
              child: _animatedDetail(selected),
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
      case SettingsSectionId.energySaving:
        return const SettingsEnergySavingScreen(isEmbedded: true);
      case SettingsSectionId.plus:
        return const SettingsPlusScreen(isEmbedded: true);
    }
  }

  Future<void> _openEditProfile(
    BuildContext context,
    String displayName,
    AuthState auth,
    String bio,
  ) async {
    final bool? updated = await EditProfileSheet.show(
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
      onEditBadges: () => _openBadgeSelector(auth),
      actions: [
        SettingsListItem.nav(
          icon: Icons.qr_code_rounded,
          title: context.l10n.settingsV2Qr,
          onTap: () => MyQrCodeSheet.show(context),
        ),
        SettingsListItem.nav(
          icon: Icons.share_outlined,
          title: context.l10n.settingsV2Share,
          onTap: () => _shareProfile(usernameForProfile(auth)),
        ),
        SettingsListItem.value(
          icon: Icons.fingerprint_rounded,
          title: 'Nios ID',
          value: auth.session?.userId.toString(),
          onTap: () => _copyNiosId(auth.session?.userId),
        ),
        SettingsListItem.nav(
          icon: Icons.manage_accounts_outlined,
          title: context.l10n.settingsV2NiosId,
          onTap: () =>
              AppUrlLauncher.openUrl(context, 'https://ni-os.ru/id/account'),
        ),
      ],
    );
    if (updated == true && context.mounted) {
      AppToast.showSuccess(context, context.l10n.settingsProfileSaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final UiSettingsState settings = ref.watch(uiSettingsProvider);

    final String displayName =
        auth.profile?.displayName ??
        auth.session?.displayName ??
        context.l10n.profileGuestName;
    final String username = usernameForProfile(auth);
    final String bio = auth.profile?.bio.trim().isNotEmpty == true
        ? auth.profile!.bio.trim()
        : '';

    final LocalStorageSnapshot? storageSnapshot = ref
        .watch(storageSnapshotProvider)
        .value;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final browser = ref.watch(clientCapabilitiesProvider).browserWorkspace;
        final bool isWide =
            width >= (browser ? 720 : Breakpoints.medium) &&
            MediaQuery.sizeOf(context).width >= Breakpoints.medium;
        if (browser && !isWide && widget.initialSection != null) {
          final section = _webSection;
          final node = SettingsRegistry.getAllNodes()
              .whereType<SettingsNavNode>()
              .where((n) => n.sectionId == section)
              .firstOrNull;
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: context.l10n.commonBack,
                onPressed: () => context.go('/main/settings'),
              ),
              title: Text(
                node?.title(context.l10n) ?? context.l10n.tabSettings,
              ),
            ),
            body: KeyedSubtree(
              key: ValueKey(section),
              child: SettingsHeadingScope(
                showEmbeddedHeading: false,
                child: _buildDetailPane(section),
              ),
            ),
          );
        }

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
