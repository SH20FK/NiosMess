import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/desktop_chat_provider.dart';
import 'package:pulse_flutter/screens/chat_list_screen.dart';
import 'package:pulse_flutter/screens/chat_detail_screen.dart';
import 'package:pulse_flutter/screens/contacts_screen.dart';
import 'package:pulse_flutter/screens/profile_screen.dart';
import 'package:pulse_flutter/widgets/app_bottom_nav.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';
import 'package:pulse_flutter/widgets/offline_banner.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({required this.tab, super.key});

  final String tab;

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  static const List<String> _tabs = <String>[
    'chats',
    'contacts',
    'profile',
  ];

  late final PageController _pageController;
  bool _fabExtended = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _tabIndex(widget.tab));
  }

  @override
  void didUpdateWidget(covariant MainShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab != widget.tab) {
      final int nextIndex = _tabIndex(widget.tab);
      if (_pageController.hasClients && _pageController.page?.round() != nextIndex) {
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _tabIndex(String tab) => _tabs.contains(tab) ? _tabs.indexOf(tab) : 0;

  void _onTapTab(int nextIndex) {
    if (nextIndex < 0 || nextIndex >= _tabs.length) {
      return;
    }

    final String targetTab = _tabs[nextIndex];
    if (targetTab == widget.tab) {
      return;
    }

    context.go('/main/$targetTab');
  }

  void _setFabExtended(bool value) {
    if (_fabExtended == value || !mounted) {
      return;
    }
    setState(() => _fabExtended = value);
  }

  Widget _composeFab(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'compose_chat_fab',
      onPressed: () {
        if (ref.read(uiSettingsProvider).haptics) {
          HapticFeedback.lightImpact();
        }
        _showCreateMenu(context);
      },
      elevation: 3,
      child: const Icon(Icons.edit_rounded),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final int? desktopChatId = ref.watch(desktopSelectedChatProvider);
    final int currentIndex = _tabIndex(widget.tab);
    final bool isOffline = ref.watch(connectivityProvider).value ?? false;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= 760;

        final List<Widget> pages = <Widget>[
          if (isWide)
            Row(
              children: <Widget>[
                Container(
                  constraints: const BoxConstraints(minWidth: 320, maxWidth: 460),
                  width: constraints.maxWidth * 0.35,
                  child: ChatListScreen(onFabExtendedChanged: _setFabExtended),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: desktopChatId != null
                      ? ChatDetailScreen(
                          key: ValueKey<int>(desktopChatId),
                          chatId: desktopChatId.toString(),
                          isDesktopSplit: true,
                        )
                      : Center(
                          child: Text(
                            context.l10n.chatNoMessages,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                ),
              ],
            )
          else
            ChatListScreen(onFabExtendedChanged: _setFabExtended),
          const ContactsScreen(),
          const ProfileScreen(),
        ];
        final Widget body = PageView(
          controller: _pageController,
          onPageChanged: (int index) {
            final String targetTab = _tabs[index];
            if (targetTab != widget.tab) {
              context.go('/main/$targetTab');
            }
          },
          children: pages,
        );

        if (isWide) {
          return Scaffold(
            body: Column(
              children: [
                OfflineBanner(isOffline: isOffline),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      NavigationRail(
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                        selectedIndex: currentIndex,
                        onDestinationSelected: _onTapTab,
                        labelType: NavigationRailLabelType.all,
                        useIndicator: true,
                        indicatorColor: Theme.of(context).colorScheme.primaryContainer,
                        leading: Padding(
                          padding: const EdgeInsets.only(bottom: 20, top: 12),
                          child: FloatingActionButton(
                            elevation: 0,
                            onPressed: () {
                              if (ref.read(uiSettingsProvider).haptics) {
                                HapticFeedback.lightImpact();
                              }
                              _showCreateMenu(context);
                            },
                            child: const Icon(Icons.edit_rounded),
                          ),
                        ),
                        destinations: <NavigationRailDestination>[
                          NavigationRailDestination(
                            icon: const Icon(Icons.chat_bubble_outline_rounded),
                            selectedIcon: const Icon(Icons.chat_bubble_rounded),
                            label: Text(context.l10n.tabChats),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.people_outline_rounded),
                            selectedIcon: const Icon(Icons.people_rounded),
                            label: Text(context.l10n.tabContacts),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.person_outline_rounded),
                            selectedIcon: const Icon(Icons.person_rounded),
                            label: Text(context.l10n.tabProfile),
                          ),
                        ],
                      ),
                      const VerticalDivider(thickness: 1, width: 1),
                      Expanded(
                        child: PulseScaffoldBody(
                          maxWidth: 1440,
                          topSafe: false,
                          bottomSafe: true,
                          child: body,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: Column(
            children: [
              OfflineBanner(isOffline: isOffline),
              Expanded(
                child: PulseScaffoldBody(
                  maxWidth: 1440,
                  topSafe: false,
                  bottomSafe: false,
                  child: body,
                ),
              ),
            ],
          ),
          bottomNavigationBar: AppBottomNav(
            currentIndex: currentIndex,
            onTap: _onTapTab,
            hapticsEnabled: settings.haptics,
          ),
          floatingActionButton: currentIndex == 0 ? _composeFab(context) : null,
        );
      },
    );
  }

  void _showStartDirectChatDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        final TextEditingController usernameController = TextEditingController();
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            String? errorText;

            void submit() {
              String username = usernameController.text.trim();
              if (username.startsWith('@')) {
                username = username.substring(1);
              }
              if (username.isEmpty) {
                setState(() {
                  errorText = context.l10n.chatCreatePersonalErrorEmpty;
                });
                return;
              }
              Navigator.of(ctx).pop();
              context.push('/chat/dm/$username');
            }

            return AlertDialog(
              title: Text(context.l10n.chatCreatePersonalPrompt),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: usernameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: context.l10n.chatCreatePersonalUsernameLabel,
                      hintText: context.l10n.chatCreatePersonalUsernameHint,
                      errorText: errorText,
                      prefixText: '@',
                    ),
                    onSubmitted: (_) => submit(),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(context.l10n.commonCancel),
                ),
                TextButton(
                  onPressed: submit,
                  child: Text(context.l10n.chatCreatePersonalStart),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCreateMenu(BuildContext context) async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        final ColorScheme scheme = Theme.of(ctx).colorScheme;
        final TextTheme textTheme = Theme.of(ctx).textTheme;

        Widget actionTile({
          required String value,
          required IconData icon,
          required String title,
          required String subtitle,
        }) {
          return InkWell(
            onTap: () => Navigator.of(ctx).pop(value),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(title, style: textTheme.titleMedium),
                        Text(
                          subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.16),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  actionTile(
                    value: 'group',
                    icon: Icons.groups_rounded,
                    title: context.l10n.groupNewGroup,
                    subtitle: context.l10n.groupCreateSharedSubtitle,
                  ),
                  Divider(
                    height: 1,
                    indent: 68,
                    endIndent: 16,
                    color: scheme.outlineVariant.withValues(alpha: 0.16),
                  ),
                  actionTile(
                    value: 'channel',
                    icon: Icons.campaign_rounded,
                    title: context.l10n.groupNewChannel,
                    subtitle: context.l10n.groupCreateBroadcastSubtitle,
                  ),
                  Divider(
                    height: 1,
                    indent: 68,
                    endIndent: 16,
                    color: scheme.outlineVariant.withValues(alpha: 0.16),
                  ),
                  actionTile(
                    value: 'join',
                    icon: Icons.link_rounded,
                    title: context.l10n.groupJoinByInvite,
                    subtitle: context.l10n.groupJoinByInviteSubtitle,
                  ),
                  Divider(
                    height: 1,
                    indent: 68,
                    endIndent: 16,
                    color: scheme.outlineVariant.withValues(alpha: 0.16),
                  ),
                  actionTile(
                    value: 'direct',
                    icon: Icons.person_add_alt_1_rounded,
                    title: context.l10n.chatCreatePersonal,
                    subtitle: context.l10n.chatCreatePersonalSubtitle,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (action == null || !context.mounted) return;
    switch (action) {
      case 'group':
        context.push('/chat/create?type=group');
        return;
      case 'channel':
        context.push('/chat/create?type=channel');
        return;
      case 'join':
        context.push('/join');
        return;
      case 'direct':
        _showStartDirectChatDialog(context);
        return;
    }
  }
}
