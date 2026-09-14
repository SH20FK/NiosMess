import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
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
import 'package:pulse_flutter/screens/settings_preferences_screen.dart';
import 'package:pulse_flutter/screens/settings_privacy_screen.dart';
import 'package:pulse_flutter/screens/settings_storage_screen.dart';
import 'package:pulse_flutter/screens/settings_system_device_screen.dart';
import 'package:pulse_flutter/services/settings/settings_registry.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

/// Central Material 3 Expressive hub for all application settings.
/// Fully decouples settings from the profile screen, supports responsive
/// Master-Detail on wide screens, and integrates instant full-text search.
class SettingsHubScreen extends ConsumerStatefulWidget {
  const SettingsHubScreen({this.initialSection, super.key});

  final SettingsSectionId? initialSection;

  @override
  ConsumerState<SettingsHubScreen> createState() => _SettingsHubScreenState();
}

class _SettingsHubScreenState extends ConsumerState<SettingsHubScreen> {
  final SearchController _searchController = SearchController();

  @override
  void initState() {
    super.initState();
    if (widget.initialSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(desktopSelectedSettingsSectionProvider.notifier)
            .setSelectedSection(widget.initialSection!);
      });
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

  String _getSectionBadgeValue(SettingsNavNode node, UiSettingsState settings) {
    if (node.id == 'appearance') {
      final bool isRussian =
          Localizations.localeOf(context).languageCode == 'ru';
      return settings.themeMode == ThemeMode.dark
          ? (isRussian ? 'Тёмная' : 'Dark')
          : settings.themeMode == ThemeMode.light
              ? (isRussian ? 'Светлая' : 'Light')
              : (isRussian ? 'Системная' : 'System');
    } else if (node.id == 'storage') {
      final LocalStorageSnapshot? snapshot =
          ref.watch(storageSnapshotProvider).value;
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
            settings,
            displayName,
            username,
          );
        }

        return _buildMobileHub(
          context,
          auth,
          scheme,
          settings,
          displayName,
          username,
        );
      },
    );
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
      onTap: () {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        } else {
          context.go('/main/profile');
        }
      },
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
                        color: scheme.onSurfaceVariant,
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
                  'Профиль',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: scheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHub(
    BuildContext context,
    AuthState auth,
    ColorScheme scheme,
    UiSettingsState settings,
    String displayName,
    String username,
  ) {
    final List<SettingsNavNode> sections =
        SettingsRegistry.getTopLevelSections();

    return SettingsShell(
      title: context.l10n.profileSettingsSection,
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.search_rounded),
          tooltip: 'Поиск настроек',
          onPressed: () => _searchController.openView(),
        ),
      ],
      children: <Widget>[
        // 1. Quick Profile Header
        _buildQuickProfileHeader(
          context,
          auth,
          scheme,
          displayName,
          username,
        ),
        const SizedBox(height: 12),

        // 2. Search Bar
        _buildSearchAnchor(isWide: false),
        const SizedBox(height: 16),

        // 3. Sections grouped into M3 Expressive Cards
        SettingsSection(
          title: 'Основное',
          children: sections
              .where((s) =>
                  s.group == SettingsGroup.account ||
                  s.group == SettingsGroup.appearance ||
                  s.group == SettingsGroup.chats)
              .map((SettingsNavNode node) {
            final String badgeVal = _getSectionBadgeValue(node, settings);
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
          children: sections
              .where((s) =>
                  s.group == SettingsGroup.notifications ||
                  s.group == SettingsGroup.privacy ||
                  s.group == SettingsGroup.storage)
              .map((SettingsNavNode node) {
            final String badgeVal = _getSectionBadgeValue(node, settings);
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
          children: sections
              .where((s) =>
                  s.group == SettingsGroup.language ||
                  s.group == SettingsGroup.about)
              .map((SettingsNavNode node) {
            final String badgeVal = _getSectionBadgeValue(node, settings);
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
        const SizedBox(height: 20),

        // Logout action
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withValues(alpha: 0.35)),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(
              context.l10n.profileLogout,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDesktopMasterDetail(
    BuildContext context,
    AuthState auth,
    ColorScheme scheme,
    UiSettingsState settings,
    String displayName,
    String username,
  ) {
    final SettingsSectionId selectedSection =
        ref.watch(desktopSelectedSettingsSectionProvider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<SettingsNavNode> sections =
        SettingsRegistry.getTopLevelSections();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Left Master Pane
          Container(
            width: 340,
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
                // Header Search
                _buildSearchAnchor(isWide: true),
                const SizedBox(height: 12),

                // Profile card
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
                        _getSectionBadgeValue(node, settings);

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
}
