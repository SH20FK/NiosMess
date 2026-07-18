import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/system_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/desktop_chat_provider.dart';
import 'package:pulse_flutter/screens/chat_list_screen.dart';
import 'package:pulse_flutter/screens/chat_detail_screen.dart';
import 'package:pulse_flutter/screens/contacts_screen.dart';
import 'package:pulse_flutter/screens/niosgram_screen.dart';
import 'package:pulse_flutter/screens/profile_screen.dart';
import 'package:pulse_flutter/widgets/app_bottom_nav.dart';
import 'package:pulse_flutter/widgets/chat_creation_surfaces.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';
import 'package:pulse_flutter/widgets/offline_banner.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/core/services/biometric_service.dart';

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
    'niosgram',
    'profile',
  ];

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _tabIndex(widget.tab));
    _checkBiometricLock();
  }

  Future<void> _checkBiometricLock() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final BiometricService biometric = ref.read(biometricServiceProvider);
    final bool authenticated = await biometric.authenticateIfEnabled();
    if (!authenticated && mounted) {
      Navigator.of(context).pop();
    }
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

  Widget _composeFab(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return FloatingActionButton.extended(
      heroTag: 'compose_chat_fab',
      onPressed: () {
        if (ref.read(uiSettingsProvider).haptics) {
          HapticService.tap();
        }
        _showCreateMenu(context);
      },
      elevation: 3,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      icon: const Icon(Icons.edit_rounded),
      label: Text(context.l10n.commonCreate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final int? desktopChatId = ref.watch(desktopSelectedChatProvider);
    final int currentIndex = _tabIndex(widget.tab);
    final bool isOffline = !(ref.watch(connectivityProvider).value ?? true);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          SystemUtils.minimizeApp();
        }
      },
      child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= 760;

        final List<Widget> pages = <Widget>[
          if (isWide)
            Row(
              children: <Widget>[
                Container(
                  constraints: const BoxConstraints(minWidth: 320, maxWidth: 460),
                  width: constraints.maxWidth * 0.35,
                  child: ChatListScreen(),
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
            ChatListScreen(),
          const ContactsScreen(),
          const NiosgramScreen(),
          const ProfileScreen(),
        ];
        final Widget body = PageTransitionSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (
            Widget child,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.scaled,
              fillColor: Colors.transparent,
              child: child,
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(currentIndex),
            child: pages[currentIndex],
          ),
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
                                HapticService.tap();
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
                            icon: const Icon(Icons.grid_view_rounded),
                            selectedIcon: const Icon(Icons.grid_view_rounded),
                            label: Text(context.l10n.tabNiosgram),
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
          extendBody: true,
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
          bottomNavigationBar: RepaintBoundary(
            child: AppBottomNav(
              currentIndex: currentIndex,
              onTap: _onTapTab,
              hapticsEnabled: settings.haptics,
            ),
          ),
          floatingActionButton: currentIndex == 0 ? _composeFab(context) : null,
        );
      },
    ),
    );
  }

  Future<void> _showStartDirectChatDialog(BuildContext context) {
    return showStartDirectChatDialog(context);
  }

  Future<void> _showCreateMenu(BuildContext context) async {
    final String? action = await showCreateChatMenu(context);

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
