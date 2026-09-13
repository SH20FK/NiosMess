import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
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
import 'package:pulse_flutter/widgets/alpha_test_dialog.dart';
import 'package:pulse_flutter/widgets/chat_creation_surfaces.dart';
import 'package:pulse_flutter/widgets/chat/m3_speed_dial_fab.dart';
import 'package:pulse_flutter/providers/chat_list_fab_provider.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';
import 'package:pulse_flutter/widgets/offline_banner.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/core/services/biometric_service.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({required this.tab, super.key});

  final String tab;

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen>
    with WidgetsBindingObserver {
  static const List<String> _tabs = <String>[
    'chats',
    'contacts',
    'niosgram',
    'profile',
  ];

  late final Set<int> _activatedTabs;

  bool _biometricLocked = false;
  double _desktopChatListWidth = 360.0;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activatedTabs = <int>{_tabIndex(widget.tab)};
    _checkBiometricLock();
    _showAlphaDialog();
    _checkWebPushPrompt();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(webSocketClientProvider).resumeFromBackground();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      ref.read(webSocketClientProvider).pauseForBackground();
    }

    // Re-lock when leaving the foreground; unlock (or exit) on return.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _biometricLocked = true;
    } else if (state == AppLifecycleState.resumed && _biometricLocked) {
      _biometricLocked = false;
      _checkBiometricLock();
    }
  }

  Future<void> _showAlphaDialog() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    await AlphaTestDialog.showIfFirstLaunch(context);
  }

  Future<void> _checkWebPushPrompt() async {
    if (!kIsWeb) return;
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool isGranted = await PushNotificationService.isPermissionGranted();
    if (isGranted) {
      await ref.read(authProvider.notifier).refreshFcmTokenRegistration();
      return;
    }

    final bool dismissed = prefs.getBool('web_push_prompt_dismissed') ?? false;
    if (dismissed) return;

    if (!mounted) return;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerHighest,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 12),
        content: Row(
          children: <Widget>[
            Icon(
              Icons.notifications_active_rounded,
              color: scheme.primary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Push-уведомления',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    'Включите уведомления о новых сообщениях и звонках',
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
        action: SnackBarAction(
          label: 'Включить',
          textColor: scheme.primary,
          onPressed: () async {
            await prefs.setBool('web_push_prompt_dismissed', true);
            final bool granted =
                await PushNotificationService.requestPermission();
            if (!mounted) return;
            if (granted) {
              await ref
                  .read(authProvider.notifier)
                  .refreshFcmTokenRegistration();
              if (mounted) {
                AppToast.showSuccess(context, 'Уведомления успешно включены!');
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> _checkBiometricLock() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final BiometricService biometric = ref.read(biometricServiceProvider);
    final bool authenticated = await biometric.authenticateIfEnabled();
    if (!authenticated && mounted) {
      await SystemUtils.minimizeApp();
      if (mounted) {
        await SystemNavigator.pop();
      }
    }
  }

  @override
  void didUpdateWidget(covariant MainShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab != widget.tab) {
      final int nextIndex = _tabIndex(widget.tab);
      if (!_activatedTabs.contains(nextIndex)) {
        setState(() {
          _activatedTabs.add(nextIndex);
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  int _tabIndex(String tab) => _tabs.contains(tab) ? _tabs.indexOf(tab) : 0;

  void _onTapTab(int nextIndex) {
    if (nextIndex < 0 || nextIndex >= _tabs.length) {
      return;
    }

    if (!_activatedTabs.contains(nextIndex)) {
      setState(() {
        _activatedTabs.add(nextIndex);
      });
    }

    final String targetTab = _tabs[nextIndex];
    if (targetTab == widget.tab) {
      return;
    }

    context.go('/main/$targetTab');
  }

  Widget _composeFab(BuildContext context) {
    final bool isWide = MediaQuery.sizeOf(context).width >= 720;
    final bool isVisible = ref.watch(chatListFabVisibleProvider);

    return M3SpeedDialFab(
      visible: isVisible,
      heroTag: 'compose_chat_fab',
      onSelectGroup: () {
        if (isWide) {
          showCreateChatDialog(context, initialType: 'group');
        } else {
          context.push('/chat/create?type=group');
        }
      },
      onSelectChannel: () {
        if (isWide) {
          showCreateChatDialog(context, initialType: 'channel');
        } else {
          context.push('/chat/create?type=channel');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final int? desktopChatId = ref.watch(desktopSelectedChatProvider);
    final int currentIndex = _tabIndex(widget.tab);
    final bool isOffline = !(ref.watch(connectivityProvider).value ?? true);

    ref.listen<AsyncValue<bool>>(connectivityProvider, (previous, next) {
      if (next.value == true && previous?.value == false) {
        ref.read(webSocketClientProvider).reconnectNow();
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        final int currentIndex = _tabIndex(widget.tab);
        if (currentIndex != 0) {
          // Secondary tab (Contacts, NiosGram, Profile) -> return to primary Chats tab
          context.go('/main/chats');
          return;
        }

        // Primary Chats tab -> require confirmation within 2 seconds before minimizing
        final DateTime now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          AppToast.showInfo(context, 'Нажмите ещё раз для выхода');
          return;
        }

        // Second press within 2 seconds -> minimize app cleanly without process kill
        SystemUtils.minimizeApp();
      },
      child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= 760;

        final double minChatListWidth = 260.0;
        final double maxChatListWidth =
            (constraints.maxWidth - 340.0).clamp(minChatListWidth, 640.0);
        final double effectiveChatListWidth =
            _desktopChatListWidth.clamp(minChatListWidth, maxChatListWidth);

        final List<Widget> pages = <Widget>[
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: effectiveChatListWidth,
                  child: const ChatListScreen(),
                ),
                _DraggableSidebarDivider(
                  onDragUpdate: (double delta) {
                    setState(() {
                      _desktopChatListWidth = (_desktopChatListWidth + delta)
                          .clamp(minChatListWidth, maxChatListWidth);
                    });
                  },
                  onReset: () {
                    setState(() {
                      _desktopChatListWidth = 360.0;
                    });
                  },
                ),
                Expanded(
                  child: desktopChatId != null
                      ? ChatDetailScreen(
                          key: ValueKey<int>(desktopChatId),
                          chatId: desktopChatId.toString(),
                          isDesktopSplit: true,
                        )
                      : _buildDesktopEmptyChatPlaceholder(context),
                ),
              ],
            )
          else
            const ChatListScreen(),
          isWide
              ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 780), child: const ContactsScreen()))
              : const ContactsScreen(),
          isWide
              ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: const NiosgramScreen()))
              : const NiosgramScreen(),
          const ProfileScreen(),
        ];
        final Widget body = IndexedStack(
          index: currentIndex,
          children: List<Widget>.generate(pages.length, (int index) {
            if (!_activatedTabs.contains(index)) {
              return const SizedBox.shrink();
            }
            return pages[index];
          }),
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
                          expand: true,
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
          extendBody: settings.navBarFloating,
          body: Column(
            children: [
              OfflineBanner(isOffline: isOffline),
              Expanded(
                child: PulseScaffoldBody(
                  expand: true,
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

  Widget _buildDesktopEmptyChatPlaceholder(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                'Выберите чат для начала общения',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Сообщения и звонки защищены сквозным шифрованием E2EE',
              style: TextStyle(
                fontSize: 12.5,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateMenu(BuildContext context) async {
    final String? action = await showCreateChatMenu(context);

    if (action == null || !context.mounted) return;
    final bool isWide = MediaQuery.sizeOf(context).width >= 720;

    switch (action) {
      case 'group':
      case 'channel':
        if (isWide) {
          await showCreateChatDialog(context, initialType: action);
        } else {
          context.push('/chat/create?type=$action');
        }
        return;
    }
  }
}

class _DraggableSidebarDivider extends StatefulWidget {
  const _DraggableSidebarDivider({
    required this.onDragUpdate,
    this.onReset,
  });

  final ValueChanged<double> onDragUpdate;
  final VoidCallback? onReset;

  @override
  State<_DraggableSidebarDivider> createState() =>
      _DraggableSidebarDividerState();
}

class _DraggableSidebarDividerState extends State<_DraggableSidebarDivider> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isHighlighted = _isHovered || _isDragging;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onReset,
        onHorizontalDragStart: (_) => setState(() => _isDragging = true),
        onHorizontalDragUpdate: (DragUpdateDetails details) {
          widget.onDragUpdate(details.delta.dx);
        },
        onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
        onHorizontalDragCancel: () => setState(() => _isDragging = false),
        child: Container(
          width: 8,
          color: Colors.transparent,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: isHighlighted ? 2.5 : 1.0,
            color: isHighlighted
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }
}

