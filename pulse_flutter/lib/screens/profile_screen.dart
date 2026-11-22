import 'package:pulse_flutter/widgets/app_refresh_indicator.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/platform/client_capabilities.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/widgets/settings/settings_profile_card.dart';
import 'package:pulse_flutter/widgets/motion/m3_entrance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/storage/local_storage_service.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/models/settings/settings_node.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/screens/e2ee_settings_screen.dart';
import 'package:pulse_flutter/screens/sessions_screen.dart';
import 'package:pulse_flutter/screens/settings_about_screen.dart';
import 'package:pulse_flutter/screens/settings_account_screen.dart';
import 'package:pulse_flutter/screens/settings_appearance_screen.dart';
import 'package:pulse_flutter/screens/settings_chats_screen.dart';
import 'package:pulse_flutter/screens/settings_language_region_screen.dart';
import 'package:pulse_flutter/screens/settings_notifications_screen.dart';
import 'package:pulse_flutter/screens/settings_privacy_screen.dart';
import 'package:pulse_flutter/screens/settings_storage_screen.dart';
import 'package:pulse_flutter/screens/settings_plus_screen.dart';
import 'package:pulse_flutter/screens/settings_system_device_screen.dart';
import 'package:pulse_flutter/services/settings/settings_registry.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/features/settings/application/settings_anchor_controller.dart';
import 'package:pulse_flutter/features/settings/application/settings_health_controller.dart';
import 'package:pulse_flutter/features/settings/domain/settings_issue.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_issue_card.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/features/sessions/application/sessions_controller.dart';
import 'package:pulse_flutter/providers/push_permission_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({this.initialSection, super.key});

  final SettingsSectionId? initialSection;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final SearchController _searchController = SearchController();

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

  String _getSectionBadgeValue(
    SettingsNavNode node,
    ThemeMode themeMode,
    LocalStorageSnapshot? snapshot,
  ) {
    if (node.id == 'appearance') {
      return themeMode == ThemeMode.dark
          ? context.l10n.commonDark
          : themeMode == ThemeMode.light
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
    } else if (node.id == 'about') {
      return AppConstants.appVersionWithPrefix;
    } else if (node.id == 'devices') {
      // Nothing until the list has arrived: a dash would read as "none".
      final SessionsState sessions = ref.watch(sessionsControllerProvider);
      return sessions is SessionsReady && sessions.sessions.isNotEmpty
          ? '${sessions.sessions.length}'
          : '';
    } else if (node.id == 'notifications') {
      final bool enabled = ref.watch(
        uiSettingsProvider.select((UiSettingsState s) => s.notifications),
      );
      // A switch that is on while the system refuses is still "off" for the
      // user: nothing arrives.
      final bool refused =
          PushNotificationService.supportsPush &&
          ref.watch(pushPermissionProvider).value == false;
      return enabled && !refused
          ? context.l10n.commonEnabled
          : context.l10n.commonDisabled;
    } else if (node.id == 'plus') {
      return ref.watch(
            authProvider.select(
              (AuthState a) => a.profile?.isNiosPlus ?? false,
            ),
          )
          ? context.l10n.settingsPlusActive
          : '';
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

  // One flat list: the registry owns which rows there are and their order.
  List<Widget> _sectionGroups(
    ThemeMode themeMode,
    LocalStorageSnapshot? snapshot, {
    SettingsSectionId? selected,
  }) {
    final sections = SettingsRegistry.getTopLevelSections();
    final selectedIndex = selected == null
        ? -1
        : sections.indexWhere((node) => node.sectionId == selected);
    return [
      SettingsSection(
        stagger: true,
        // The open section rounds off on every side, not only recolours.
        selectedIndex: selectedIndex < 0 ? null : selectedIndex,
        children: [
          for (final node in sections)
            SettingsListItem.nav(
              key: ValueKey('settings-destination-${node.id}'),
              icon: node.icon,
              title: node.title(context.l10n),
              value: _getSectionBadgeValue(node, themeMode, snapshot),
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
    ];
  }

  // Same rule as a search result: two panes select the section in place,
  // a phone pushes the screen.
  void _openIssue(SettingsHealthIssue issue, {required bool wide}) {
    ref
        .read(settingsAnchorControllerProvider.notifier)
        .request(route: issue.route, anchor: issue.anchor);
    if (_browser || wide) {
      _selectSection(issue.sectionId);
    } else {
      context.push(issue.route);
    }
  }

  List<Widget> _healthIssues({required bool wide}) => ref
      .watch(settingsHealthProvider)
      .take(2)
      .map(
        (SettingsHealthIssue issue) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SettingsIssueCard(
            issue: issue,
            onOpen: () => _openIssue(issue, wide: wide),
          ),
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

  // Same rule as the rows below: two panes select Account in place, a phone
  // pushes the screen.
  void _openAccount({required bool wide}) {
    if (_browser || wide) {
      _selectSection(SettingsSectionId.account);
    } else {
      context.push('/settings/account');
    }
  }

  Widget _profileCard(
    AuthState auth,
    String displayName,
    String username, {
    required bool wide,
  }) => M3Entrance(
    offsetY: 12,
    child: SettingsProfileCard(
      displayName: displayName,
      username: username,
      avatarUrl: auth.profile?.avatarUrl,
      onTap: () => _openAccount(wide: wide),
    ),
  );

  Widget _buildMobileHub(
    AuthState auth,
    ColorScheme scheme,
    ThemeMode themeMode,
    LocalStorageSnapshot? storageSnapshot,
    String displayName,
    String username,
  ) => Scaffold(
    backgroundColor: scheme.surface,
    body: AppRefreshIndicator(
      onRefresh: () => ref.read(authProvider.notifier).refreshProfile(),
      child: CustomScrollView(
        key: const PageStorageKey('settings-overview-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.sm,
                      bottom: AppSpacing.lg,
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(
                        context.l10n.tabSettings,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  _profileCard(auth, displayName, username, wide: false),
                  const SizedBox(height: AppSpacing.lg),
                  _buildSearchAnchor(isWide: false),
                  const SizedBox(height: 20),
                  ..._healthIssues(wide: false),
                  ..._sectionGroups(themeMode, storageSnapshot),
                  _logoutAction(),
                ]),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _animatedDetail(SettingsSectionId section) {
    final reduced = context.reduceMotion;
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
    ThemeMode themeMode,
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
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: _profileCard(auth, displayName, username, wide: true),
                ),
                _buildSearchAnchor(isWide: true),
                const SizedBox(height: 20),
                ..._healthIssues(wide: true),
                ..._sectionGroups(
                  themeMode,
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
      case SettingsSectionId.notifications:
        return const SettingsNotificationsScreen(isEmbedded: true);
      case SettingsSectionId.systemDevice:
        if (kIsWeb) return const SettingsAboutScreen(isEmbedded: true);
        return const SettingsSystemDeviceScreen(isEmbedded: true);
      case SettingsSectionId.about:
        return const SettingsAboutScreen(isEmbedded: true);
      case SettingsSectionId.e2ee:
        return const E2eeSettingsScreen(isEmbedded: true);
      case SettingsSectionId.sessions:
        return const SessionsScreen(isEmbedded: true);
      case SettingsSectionId.plus:
        return const SettingsPlusScreen(isEmbedded: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ThemeMode themeMode = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.themeMode),
    );

    final String displayName =
        auth.profile?.displayName ??
        auth.session?.displayName ??
        context.l10n.profileGuestName;
    final String username = usernameForProfile(auth);

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
            themeMode,
            storageSnapshot,
            displayName,
            username,
          );
        }

        return _buildMobileHub(
          auth,
          scheme,
          themeMode,
          storageSnapshot,
          displayName,
          username,
        );
      },
    );
  }
}
