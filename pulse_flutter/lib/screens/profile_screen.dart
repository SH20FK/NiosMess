import 'package:pulse_flutter/widgets/app_refresh_indicator.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/platform/client_capabilities.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:pulse_flutter/features/account_deletion/presentation/account_deletion_screen.dart';
import 'package:pulse_flutter/screens/blocked_users_screen.dart';
import 'package:pulse_flutter/screens/privacy_rule_detail_screen.dart';
import 'package:pulse_flutter/screens/settings_wallpaper_screen.dart';
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
  const ProfileScreen({this.initialSection, this.initialAnchor, super.key});

  final SettingsSectionId? initialSection;

  /// A row of [initialSection] to scroll to and highlight: a link to one
  /// setting opened in a browser.
  final String? initialAnchor;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final SearchController _searchController = SearchController();

  // Whether the last layout showed two panes. Set while building, read by
  // callbacks that run after it.
  bool _wide = false;

  // The section row the keyboard focus is on, if it is in the list.
  SettingsSectionId? _focusedSection;

  // A screen opened under a section while two panes are shown: it takes the
  // place of that section beside the list instead of covering the window.
  ({SettingsSectionId section, String route})? _subpage;

  bool get _browser => ref.read(clientCapabilitiesProvider).browserWorkspace;
  SettingsSectionId get _webSection =>
      widget.initialSection == SettingsSectionId.systemDevice
      ? SettingsSectionId.about
      : widget.initialSection ?? SettingsSectionId.account;
  void _selectSection(SettingsSectionId section) {
    // Choosing a section, even the open one, shows the section itself.
    _closeSubpage();
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

  // Escape on the settings tab goes one level up: from a screen opened under
  // a section to the section, from a section reached through another one to
  // that one, from anything else to the chats.
  void _keyBack() {
    if (_wide && _subpage != null) {
      _closeSubpage();
      return;
    }
    if (_browser && !_wide && widget.initialSection != null) {
      context.go('/main/settings');
      return;
    }
    final SettingsSectionId? current = !_wide
        ? null
        : _browser
        ? _webSection
        : ref.read(desktopSelectedSettingsSectionProvider);
    final SettingsSectionId? parent = switch (current) {
      SettingsSectionId.e2ee => SettingsSectionId.privacy,
      SettingsSectionId.systemDevice => SettingsSectionId.about,
      _ => null,
    };
    if (parent != null) {
      _selectSection(parent);
    } else {
      context.go('/main/chats');
    }
  }

  // Arrow keys in the list of sections: the neighbour of the focused row
  // opens beside the list and the focus moves onto it.
  void _stepSection(int delta) {
    final List<SettingsNavNode> sections =
        SettingsRegistry.getTopLevelSections();
    final SettingsSectionId current =
        _focusedSection ??
        (_browser
            ? _webSection
            : ref.read(desktopSelectedSettingsSectionProvider));
    final int index = sections.indexWhere((n) => n.sectionId == current);
    final int next = index + delta;
    if (index >= 0 && next >= 0 && next < sections.length) {
      final SettingsSectionId? id = sections[next].sectionId;
      if (id != null) _selectSection(id);
    }
    // Past either end the focus still leaves the list: to the search above
    // or to the row below.
    primaryFocus?.focusInDirection(
      delta > 0 ? TraversalDirection.down : TraversalDirection.up,
    );
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
        if (!_wide) {
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
    _requestInitialAnchor();
  }

  // A link to one setting: the address names the section and the row. The
  // row is highlighted once the section is on screen.
  void _requestInitialAnchor() {
    final String? anchor = widget.initialAnchor;
    if (anchor == null || anchor.isEmpty || widget.initialSection == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final SettingsSectionId section = _webSection;
      final String route =
          SettingsRegistry.getAllNodes()
              .whereType<SettingsNavNode>()
              .where((SettingsNavNode node) => node.sectionId == section)
              .firstOrNull
              ?.route ??
          '/main/settings';
      ref
          .read(settingsAnchorControllerProvider.notifier)
          .request(route: route, anchor: anchor);
    });
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // In a browser the section comes from the address: back and forward
    // change it without asking the hub.
    if (oldWidget.initialSection != widget.initialSection) _subpage = null;
    if (oldWidget.initialAnchor != widget.initialAnchor ||
        oldWidget.initialSection != widget.initialSection) {
      _requestInitialAnchor();
    }
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
    // Beside an open section the list is navigation: low rows, and a problem
    // is a dot on the row of its section instead of a card above the list.
    final bool dense = selected != null;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Map<SettingsSectionId, SettingsHealthIssue> marks =
        <SettingsSectionId, SettingsHealthIssue>{
          if (dense)
            // Reversed, so the first problem of a section is the one kept.
            for (final SettingsHealthIssue issue
                in ref.watch(settingsHealthProvider).reversed)
              issue.sectionId: issue,
        };
    final Widget list = SettingsSection(
      stagger: true,
      // The open section rounds off on every side, not only recolours.
      selectedIndex: selectedIndex < 0 ? null : selectedIndex,
      children: [
        for (final node in sections)
          // Notes which row the keyboard is on, so the arrows step from it
          // and not from the open section.
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            includeSemantics: false,
            onFocusChange: (bool focused) {
              if (focused) {
                _focusedSection = node.sectionId;
              } else if (_focusedSection == node.sectionId) {
                _focusedSection = null;
              }
            },
            child: SettingsListItem.nav(
              key: ValueKey('settings-destination-${node.id}'),
              icon: node.icon,
              title: node.title(context.l10n),
              value: _getSectionBadgeValue(node, themeMode, snapshot),
              isSection: true,
              isSelected: selected != null && node.sectionId == selected,
              dense: dense,
              attention: switch (marks[node.sectionId]) {
                final SettingsHealthIssue issue => settingsIssueTitle(
                  context.l10n,
                  issue,
                ),
                null => null,
              },
              attentionColor: switch (marks[node.sectionId]?.severity) {
                SettingsHealthSeverity.critical => scheme.error,
                SettingsHealthSeverity.warning => scheme.tertiary,
                SettingsHealthSeverity.advisory => scheme.primary,
                null => null,
              },
              onTap: () {
                if (selected != null && node.sectionId != null) {
                  // A marked row leads to the control that fixes the problem.
                  final SettingsHealthIssue? issue = marks[node.sectionId];
                  if (issue != null) {
                    ref
                        .read(settingsAnchorControllerProvider.notifier)
                        .request(route: issue.route, anchor: issue.anchor);
                  }
                  _selectSection(node.sectionId!);
                } else {
                  _openSection(node);
                }
              },
            ),
          ),
      ],
    );
    // On a phone the rows push screens, so the arrows keep their usual job.
    if (selected == null) return [list];
    return [
      CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              _stepSection(1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              _stepSection(-1),
        },
        child: list,
      ),
    ];
  }

  // Cards exist only in the single-column hub: a browser keeps the section
  // in the address, a phone pushes the screen.
  void _openIssue(SettingsHealthIssue issue) {
    ref
        .read(settingsAnchorControllerProvider.notifier)
        .request(route: issue.route, anchor: issue.anchor);
    if (_browser) {
      _selectSection(issue.sectionId);
    } else {
      context.push(issue.route);
    }
  }

  List<Widget> _healthIssues() => ref
      .watch(settingsHealthProvider)
      .take(2)
      .map(
        (SettingsHealthIssue issue) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SettingsIssueCard(
            issue: issue,
            onOpen: () => _openIssue(issue),
          ),
        ),
      )
      .toList();

  Widget _logoutAction({bool dense = false}) => SettingsSection(
    children: [
      SettingsListItem(
        icon: Icons.logout_rounded,
        title: context.l10n.profileLogout,
        type: SettingsListItemType.danger,
        dense: dense,
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
      dense: wide,
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
                  ..._healthIssues(),
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

  Widget _animatedDetail(SettingsSectionId section, {bool pane = false}) {
    final reduced = context.reduceMotion;
    // A screen opened under this section takes its place in the pane.
    final String? route = pane && _subpage?.section == section
        ? _subpage!.route
        : null;
    final Widget switcher = AnimatedSwitcher(
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
        key: route == null
            ? ValueKey(section)
            : ValueKey<String>('${section.name}:$route'),
        child: route == null
            ? _buildDetailPane(section)
            : _buildSubpage(section, route),
      ),
    );
    if (!pane) return switcher;
    return SettingsPaneScope(
      onOpen: (String target) => _openSubpage(section, target),
      onClose: _closeSubpage,
      child: switcher,
    );
  }

  bool _openSubpage(SettingsSectionId section, String route) {
    if (_subpageFor(route) == null) return false;
    setState(() => _subpage = (section: section, route: route));
    return true;
  }

  void _closeSubpage() {
    if (_subpage != null) setState(() => _subpage = null);
  }

  // Screens that open under a section. Anything else is pushed as a page.
  ({Widget page, bool fullWidth})? _subpageFor(String route) {
    final Uri uri = Uri.parse(route);
    const String rule = '/settings/privacy/rule/';
    if (uri.path.startsWith(rule) && uri.path.length > rule.length) {
      return (
        page: PrivacyRuleDetailScreen(
          ruleKey: uri.path.substring(rule.length),
          isEmbedded: true,
        ),
        fullWidth: false,
      );
    }
    return switch (uri.path) {
      '/settings/privacy/blocked-users' => (
        page: const BlockedUsersScreen(isEmbedded: true),
        fullWidth: false,
      ),
      '/settings/account/delete' => (
        page: const AccountDeletionScreen(isEmbedded: true),
        fullWidth: false,
      ),
      // The studio lays itself out across the whole pane.
      '/settings/wallpaper' => (
        page: SettingsWallpaperScreen(
          chatId: uri.queryParameters['chatId'],
          chatTitle: uri.queryParameters['chatTitle'],
          initialCode: uri.queryParameters['code'],
          isEmbedded: true,
        ),
        fullWidth: true,
      ),
      _ => null,
    };
  }

  // The path stays in sight: the section is a link above the screen that was
  // opened under it, and the screen keeps its own heading.
  Widget _buildSubpage(SettingsSectionId section, String route) {
    final ({Widget page, bool fullWidth}) sub = _subpageFor(route)!;
    final String parent =
        SettingsRegistry.getAllNodes()
            .whereType<SettingsNavNode>()
            .where((SettingsNavNode node) => node.sectionId == section)
            .firstOrNull
            ?.title(context.l10n) ??
        context.l10n.tabSettings;
    final Widget back = Align(
      alignment: AlignmentDirectional.centerStart,
      child: Tooltip(
        message: context.l10n.commonBack,
        child: TextButton.icon(
          key: const ValueKey<String>('settings-subpage-back'),
          onPressed: _closeSubpage,
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: Text(parent),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          child: sub.fullWidth
              ? back
              // Over the same centred column the screen below lays out in.
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: back,
                  ),
                ),
        ),
        Expanded(child: sub.page),
      ],
    );
  }

  Widget _buildDesktopMasterDetail(
    BuildContext context,
    AuthState auth,
    ColorScheme scheme,
    ThemeMode themeMode,
    LocalStorageSnapshot? storageSnapshot,
    String displayName,
    String username, {
    required double width,
  }) {
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
            // The same share on Windows and the web, and never so wide that
            // the section beside it drops under its own minimum.
            width: (width * .27).clamp(Breakpoints.settingsNavMinWidth, 340.0),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(
                right: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: .35),
                ),
              ),
            ),
            // Navigation that stays on screen: the search on top, the
            // sections under it, who is signed in at the foot. The section
            // beside it carries the heading, so the list has none.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    14,
                    AppSpacing.lg,
                    14,
                    AppSpacing.md,
                  ),
                  child: _buildSearchAnchor(isWide: true),
                ),
                Expanded(
                  child: SettingsPaneScrollbar(
                    builder: (context, controller) => ListView(
                      key: const PageStorageKey('settings-navigation-scroll'),
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      children: [
                        ..._sectionGroups(
                          themeMode,
                          storageSnapshot,
                          selected: selected,
                        ),
                        _logoutAction(dense: true),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    14,
                    AppSpacing.sm,
                    14,
                    AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: _profileCard(
                    auth,
                    displayName,
                    username,
                    wide: true,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: scheme.surface,
              child: _animatedDetail(selected, pane: true),
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
    ref.listen(settingsKeyCommandProvider, (_, next) {
      if (next == null) return;
      switch (next.command) {
        case SettingsKeyCommand.search:
          // A compact page of one section has no search field.
          if (_searchController.isAttached) _searchController.openView();
        case SettingsKeyCommand.back:
          _keyBack();
      }
    });
    // Another screen may switch the section itself; whatever was open under
    // the old one goes with it.
    ref.listen(
      desktopSelectedSettingsSectionProvider,
      (_, _) => _closeSubpage(),
    );
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
        // One rule for Windows and the web, counted from the room the open
        // section needs and not from the window: the app rail is already
        // taken out of these constraints.
        final bool isWide = Breakpoints.settingsTwoPane(
          Size(
            width,
            constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height,
          ),
        );
        _wide = isWide;
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
            // The same cross-fade between sections as beside the list.
            body: SettingsHeadingScope(
              showEmbeddedHeading: false,
              child: _animatedDetail(section),
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
            width: width,
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
