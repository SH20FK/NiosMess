import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:flutter/services.dart';
import 'package:pulse_flutter/core/platform/client_capabilities.dart';
import 'package:pulse_flutter/features/chats/application/inbox_selection_controller.dart';
import 'package:pulse_flutter/widgets/nav/app_nav_destination.dart';
import 'package:pulse_flutter/widgets/nav/app_nav_item.dart';
import 'package:pulse_flutter/widgets/nav/app_nav_rail.dart';
import 'package:pulse_flutter/widgets/nav/shell_window_title.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/chat_list_fab_provider.dart';
import 'package:pulse_flutter/providers/chat_list_scroll_provider.dart';
import 'package:pulse_flutter/features/chats/application/inbox_search_controller.dart';
import 'package:pulse_flutter/core/theme/app_surfaces.dart';
import 'package:pulse_flutter/core/utils/system_utils.dart';
import 'package:pulse_flutter/services/settings/notification_preference_action.dart';
import 'package:universal_io/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/desktop_chat_provider.dart';
import 'package:pulse_flutter/screens/chat_list_screen.dart';
import 'package:pulse_flutter/screens/chat_detail_screen.dart';
import 'package:pulse_flutter/screens/niosgram_screen.dart';
import 'package:pulse_flutter/screens/profile_screen.dart';
import 'package:pulse_flutter/widgets/app_bottom_nav.dart';
import 'package:pulse_flutter/widgets/alpha_test_dialog.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/features/account_deletion/data/account_deletion_repository.dart';
import 'package:pulse_flutter/features/account_deletion/domain/account_deletion_status.dart';
import 'package:pulse_flutter/features/account_deletion/presentation/account_deletion_texts.dart';
import 'package:pulse_flutter/widgets/chat/inbox_compose_button.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';
import 'package:pulse_flutter/widgets/offline_banner.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/providers/ota_update_provider.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/services/update/app_update_service.dart';
import 'package:pulse_flutter/widgets/nav/m3_route_tab_switcher.dart';
import 'package:pulse_flutter/widgets/update/app_update_dialog.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/core/services/background_service.dart';
import 'package:pulse_flutter/core/services/account_background_policy.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';

export 'package:pulse_flutter/widgets/chat/inbox_compose_button.dart'
    show kInboxComposerClearance, kInboxComposerMargin;

/// Max readable width of the inbox pane. On tablets/desktop the list is
/// centred inside this budget instead of stretching edge to edge
/// (INBOX_VISUAL_AUDIT_2026-11-16, P0 #3).
const double kInboxContentMaxWidth = 640.0;

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({
    required this.tab,
    this.selectedChatId,
    this.highlightMessageId,
    this.settingsSection,
    this.settingsAnchor,
    super.key,
  });

  final String tab;
  final int? selectedChatId, highlightMessageId;
  final String? settingsSection;

  /// A setting to highlight in the open section, from a link in a browser.
  final String? settingsAnchor;

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen>
    with WidgetsBindingObserver {
  static const List<AppNavDestination> _tabs = AppNavDestination.values;

  late final Set<int> _activatedTabs;
  final TabTransitionController _tabTransition = TabTransitionController();

  /// A notifier, not state: dragging the divider resizes the inbox pane alone
  /// instead of rebuilding the whole shell on every pointer move.
  final ValueNotifier<double> _desktopChatListWidth = ValueNotifier<double>(
    360.0,
  );
  DateTime? _lastBackPressTime;
  Timer? _startupTimer;
  Timer? _tabWarmupTimer;
  bool _mainScrolling = false;
  ProviderSubscription<BackgroundMode>? _backgroundModeSubscription;
  ProviderSubscription<bool>? _callSubscription;
  ProviderSubscription<bool>? _authSubscription;
  ProviderSubscription<({int? account, bool pending})>? _deletionSubscription;
  int? _deletionWarnedAccount;
  AdaptivePerformanceNotifier? _performance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activatedTabs = <int>{_tabIndex(widget.tab)};
    _performance = ref.read(adaptivePerformanceProvider.notifier);
    unawaited(
      BackgroundService.setAuthenticated(
        ref.read(authProvider).isAuthenticated &&
            !ref.read(authProvider.notifier).isLoggingOut,
      ),
    );
    BackgroundService.workCount.addListener(_syncBackgroundPolicy);
    _authSubscription = ref.listenManual(
      authProvider.select((s) => s.isAuthenticated),
      (_, authenticated) {
        unawaited(
          BackgroundService.setAuthenticated(
            authenticated && !ref.read(authProvider.notifier).isLoggingOut,
          ),
        );
        _syncBackgroundPolicy();
      },
    );
    _backgroundModeSubscription = ref.listenManual(
      uiSettingsProvider.select((s) => s.backgroundMode),
      (_, _) => _syncBackgroundPolicy(),
    );
    _callSubscription = ref.listenManual(
      callSessionProvider.select((session) => session?.isActive ?? false),
      (_, _) => _syncBackgroundPolicy(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _runStartupSequence();
      _syncBackgroundPolicy();
      _scheduleTabWarmup();
    });
  }

  void _syncInteraction() {
    _performance?.setInteractionActive(
      this,
      _mainScrolling || _tabTransition.isTransitioning,
    );
  }

  void _syncBackgroundPolicy() {
    if (!mounted) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final policy = AccountBackgroundPolicy(
      authenticated:
          ref.read(authProvider).isAuthenticated &&
          BackgroundService.accountAuthenticated,
      background:
          lifecycle == AppLifecycleState.paused ||
          lifecycle == AppLifecycleState.hidden,
      reliable:
          ref.read(uiSettingsProvider).backgroundMode ==
          BackgroundMode.reliable,
      activeWork:
          (ref.read(callSessionProvider)?.isActive ?? false) ||
          BackgroundService.workCount.value > 0,
    );
    final socket = ref.read(webSocketClientProvider);
    if (policy.keepSocket) {
      socket.resumeFromBackground();
    } else {
      socket.pauseForBackground();
    }
    if (ref.exists(secretChatCoordinatorProvider)) {
      ref
          .read(secretChatCoordinatorProvider)
          .value
          ?.setTransportAllowed(policy.keepSocket);
    }
    unawaited(BackgroundService.applyPolicy(policy));
  }

  void _scheduleTabWarmup() {
    _tabWarmupTimer?.cancel();
    _tabWarmupTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (_tabTransition.isTransitioning || _mainScrolling) {
        _scheduleTabWarmup();
        return;
      }
      final pending = List.generate(
        _tabs.length,
        (i) => i,
      ).where((i) => !_activatedTabs.contains(i)).firstOrNull;
      if (pending == null) return;
      setState(() => _activatedTabs.add(pending));
      _scheduleTabWarmup();
    });
  }

  Future<void> _runStartupSequence() async {
    // Sequence dialogs and background checks with lifecycle cancellation (АРХ-10)
    _startupTimer?.cancel();
    _startupTimer = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      await _showAlphaDialog();
      if (!mounted) return;
      _checkDailyOtaUpdate();
      _checkPushPermissionPrompt();
      _watchPendingDeletion();
    });
  }

  // Starts after the first-launch dialog so the two never stack.
  void _watchPendingDeletion() {
    _deletionSubscription ??= ref.listenManual(
      authProvider.select(
        (s) => (
          account: s.session?.userId,
          pending: s.profile?.isPendingDeletion ?? false,
        ),
      ),
      (_, next) {
        if (next.pending) unawaited(_warnPendingDeletion());
      },
      fireImmediately: true,
    );
  }

  /// Signing in does not cancel a scheduled deletion and the account keeps
  /// working, so say it once per launch instead of letting it lapse silently.
  Future<void> _warnPendingDeletion() async {
    final auth = ref.read(authProvider);
    final account = auth.session?.userId;
    if (!mounted ||
        account == null ||
        !(auth.profile?.isPendingDeletion ?? false) ||
        _deletionWarnedAccount == account) {
      return;
    }
    _deletionWarnedAccount = account;
    final l10n = context.l10n;
    final cancel = await showAppConfirmDialog(
      context: context,
      title: accountDeletionPendingTitle(
        l10n,
        auth.profile?.deletionScheduledAt,
      ),
      subtitle: l10n.accountDeletePendingBody,
      confirmLabel: l10n.accountDeleteCancel,
      cancelLabel: l10n.accountDeleteKeep,
      icon: Icons.auto_delete_outlined,
    );
    if (cancel != true ||
        !mounted ||
        ref.read(authProvider).session?.userId != account) {
      return;
    }
    try {
      await ref.read(accountDeletionRepositoryProvider).cancel();
    } catch (error) {
      // Already cancelled from another device: the goal is reached.
      if (AccountDeletionFailure.of(error) !=
          AccountDeletionFailure.notScheduled) {
        if (mounted) AppToast.showError(context, l10n.accountDeleteFailed);
        return;
      }
    }
    await ref.read(authProvider.notifier).refreshProfile();
    if (mounted) AppToast.showSuccess(context, l10n.accountDeleteCancelled);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncBackgroundPolicy();
    if (state == AppLifecycleState.resumed) {
      if (_activatedTabs.length < _tabs.length) _scheduleTabWarmup();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _tabWarmupTimer?.cancel();
    }
  }

  Future<void> _showAlphaDialog() async {
    if (!mounted) return;
    await AlphaTestDialog.showIfFirstLaunch(context);
  }

  Future<void> _checkPushPermissionPrompt() async {
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) return;
    final session = ref.read(authProvider).session;
    bool canPrompt() =>
        mounted &&
        identical(ref.read(authProvider).session, session) &&
        ref.read(uiSettingsProvider).notifications;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!canPrompt()) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!canPrompt()) return;
    final bool isGranted = await PushNotificationService.isPermissionGranted();
    if (!canPrompt()) return;
    if (isGranted) {
      await ref.read(authProvider.notifier).refreshFcmTokenRegistration();
      return;
    }

    final promptKey = kIsWeb
        ? 'web_push_prompt_dismissed'
        : 'native_push_prompt_dismissed';
    final bool dismissed = prefs.getBool(promptKey) ?? false;
    if (dismissed) return;

    if (!mounted || !canPrompt()) return;
    AppToast.showAction(
      context,
      message: context.l10n.shellPushNotificationsDesc,
      actionLabel: context.l10n.shellPushNotificationsEnable,
      duration: const Duration(seconds: 12),
      onAction: () async {
        await prefs.setBool(promptKey, true);
        if (!canPrompt()) return;
        try {
          final granted = await updateNotificationPreference(ref, true);
          if (mounted && granted) {
            AppToast.showSuccess(
              context,
              context.l10n.shellPushNotificationsSuccess,
            );
          }
        } catch (_) {
          if (mounted) {
            AppToast.showError(context, context.l10n.noticeSyncFailed);
          }
        }
      },
    );
  }

  Future<void> _checkDailyOtaUpdate() async {
    if (kIsWeb) return;
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int lastCheckMs =
          prefs.getInt('last_daily_ota_check_timestamp') ?? 0;
      final DateTime now = DateTime.now();
      final DateTime lastCheck = DateTime.fromMillisecondsSinceEpoch(
        lastCheckMs,
      );

      // Only check automatically once every 24 hours
      if (now.difference(lastCheck).inHours < 24) {
        return;
      }

      final AppUpdateService service = ref.read(appUpdateServiceProvider);
      final AppUpdateInfo updateInfo = await service.checkForUpdate();
      await prefs.setInt(
        'last_daily_ota_check_timestamp',
        now.millisecondsSinceEpoch,
      );

      if (updateInfo.hasUpdate && mounted) {
        ref.read(otaUpdateProvider.notifier).setUpdateInfo(updateInfo);
        await AppUpdateDialog.show(context, updateInfo);
      }
    } catch (e) {
      debugPrint('[MainShellScreen] Daily update check warning: $e');
    }
  }

  @override
  void didUpdateWidget(covariant MainShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab != widget.tab) {
      _mainScrolling = false;
      _lastBackPressTime = null;
      _revealComposer();
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
    _authSubscription?.close();
    _deletionSubscription?.close();
    _backgroundModeSubscription?.close();
    _callSubscription?.close();
    BackgroundService.workCount.removeListener(_syncBackgroundPolicy);
    _performance?.setInteractionActive(this, false);
    _startupTimer?.cancel();
    _tabWarmupTimer?.cancel();
    _desktopChatListWidth.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  int _tabIndex(String tab) => AppNavDestination.fromRoute(tab).index;

  /// The inbox hides the composer while the user scrolls down (owned by
  /// `ChatListScreen`). Without this reset a hidden FAB would stay hidden
  /// forever after switching tabs, so the primary action would silently
  /// disappear from the inbox.
  void _revealComposer() {
    if (ref.read(chatListFabVisibleProvider)) return;
    // Post-frame: `didUpdateWidget` runs while the tree is building and
    // Riverpod forbids provider writes during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(chatListFabVisibleProvider.notifier).show();
    });
  }

  /// The active destination was tapped again. Returns whether anything
  /// happened, so the bar stays silent when there is nothing to do.
  bool _onReselectTab(int index) {
    if (index != 0) return false;
    _revealComposer();
    ref.read(chatListScrollToTopProvider.notifier).request();
    return true;
  }

  void _onTapTab(int nextIndex) {
    if (nextIndex < 0 || nextIndex >= _tabs.length) {
      return;
    }

    final String targetTab = _tabs[nextIndex].route;
    if (nextIndex == _tabIndex(widget.tab)) {
      _onReselectTab(nextIndex);
      return;
    }

    _lastBackPressTime = null;

    if (targetTab == 'chats') {
      _revealComposer();
    }

    if (!_activatedTabs.contains(nextIndex)) {
      setState(() {
        _activatedTabs.add(nextIndex);
      });
    }

    context.go('/main/$targetTab');
  }

  @override
  Widget build(BuildContext context) {
    final bool haptics = ref.watch(uiSettingsProvider.select((s) => s.haptics));
    final capabilities = ref.watch(clientCapabilitiesProvider);
    // Tab shortcuts work wherever there is a hardware keyboard by default.
    final bool keyboardNav =
        capabilities.browserWorkspace || capabilities.desktopFiles;
    final int? desktopChatId = capabilities.browserWorkspace
        ? widget.selectedChatId
        : ref.watch(desktopSelectedChatProvider);
    final int currentIndex = _tabIndex(widget.tab);
    final bool isOffline = !(ref.watch(connectivityProvider).value ?? true);

    ref.listen<AsyncValue<bool>>(connectivityProvider, (previous, next) {
      if (next.value == true && previous?.value == false) {
        ref.read(webSocketClientProvider).reconnectNow();
      }
    });

    return PopScope(
      canPop: capabilities.browserWorkspace,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop || capabilities.browserWorkspace) return;
        final int currentIndex = _tabIndex(widget.tab);
        if (currentIndex != 0) {
          // Secondary tab (Contacts, NiosGram, Profile) -> return to primary Chats tab
          _lastBackPressTime = null;
          context.go('/main/chats');
          return;
        }

        // Picking chats is a mode of the inbox: back leaves it first.
        if (ref.read(inboxSelectionProvider).isNotEmpty) {
          _lastBackPressTime = null;
          ref.read(inboxSelectionProvider.notifier).clear();
          return;
        }

        // Two-pane layout: back closes the open chat instead of arming the
        // exit prompt. The shell owns this; the chat pane's own PopScope on
        // the same route stays out of it on native.
        if (Breakpoints.twoPane(MediaQuery.sizeOf(context)) &&
            ref.read(desktopSelectedChatProvider) != null) {
          _lastBackPressTime = null;
          ref.read(desktopSelectedChatProvider.notifier).setSelectedChat(null);
          return;
        }

        // An open inbox search closes first.
        if (ref.read(inboxSearchProvider).active) {
          _lastBackPressTime = null;
          ref.read(inboxSearchProvider.notifier).close();
          return;
        }

        // Primary Chats tab -> require confirmation within 2 seconds before minimizing
        final DateTime now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          AppToast.showInfo(context, context.l10n.shellPressAgainToExit);
          return;
        }

        // Second press within 2 seconds -> minimize app cleanly without process kill
        SystemUtils.minimizeApp();
      },
      child: CallbackShortcuts(
        bindings: keyboardNav
            ? {
                const SingleActivator(
                  LogicalKeyboardKey.digit1,
                  control: true,
                  alt: true,
                ): () =>
                    _onTapTab(0),
                const SingleActivator(
                  LogicalKeyboardKey.digit2,
                  control: true,
                  alt: true,
                ): () =>
                    _onTapTab(1),
                const SingleActivator(
                  LogicalKeyboardKey.digit3,
                  control: true,
                  alt: true,
                ): () =>
                    _onTapTab(2),
                const SingleActivator(
                  LogicalKeyboardKey.keyN,
                  control: true,
                  alt: true,
                ): () =>
                    context.push('/new-message'),
                // The usual desktop key for settings.
                const SingleActivator(LogicalKeyboardKey.comma, control: true):
                    () => _onTapTab(AppNavDestination.settings.index),
                const SingleActivator(LogicalKeyboardKey.comma, meta: true):
                    () => _onTapTab(AppNavDestination.settings.index),
                // Bound only on the settings tab, so Escape is not swallowed
                // elsewhere. The hub acts on them.
                if (currentIndex == AppNavDestination.settings.index) ...{
                  const SingleActivator(LogicalKeyboardKey.escape): () => ref
                      .read(settingsKeyCommandProvider.notifier)
                      .send(SettingsKeyCommand.back),
                  const SingleActivator(
                    LogicalKeyboardKey.keyF,
                    control: true,
                  ): () => ref
                      .read(settingsKeyCommandProvider.notifier)
                      .send(SettingsKeyCommand.search),
                  const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
                      () => ref
                          .read(settingsKeyCommandProvider.notifier)
                          .send(SettingsKeyCommand.search),
                },
              }
            : const {},
        child: Focus(
          autofocus: keyboardNav,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              // From 840 dp the bottom bar gives way to the side rail on
              // every platform. The list–detail split also needs height: a
              // phone on its side gets the rail and a single pane.
              final bool rail = constraints.maxWidth >= Breakpoints.medium;
              final bool isWide = Breakpoints.twoPane(constraints.biggest);
              final workspaceWidth =
                  constraints.maxWidth -
                  (rail ? AppNavMetrics.railWidth + 1 : 0);

              final double minChatListWidth = 260.0;
              final double maxChatListWidth = (workspaceWidth - 340.0).clamp(
                minChatListWidth,
                640.0,
              );

              final bool desktopChatOpen =
                  capabilities.browserWorkspace && desktopChatId != null;
              // The body already ends above the navigation bar
              // (`extendBody: false`); the system gesture inset only needs to
              // be added when no bar is painted at all (side rail).
              final double composerBottomInset = rail
                  ? MediaQuery.viewPaddingOf(context).bottom
                  : 0;

              final List<Widget> pages = <Widget>[
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      ValueListenableBuilder<double>(
                        valueListenable: _desktopChatListWidth,
                        builder:
                            (BuildContext context, double width, Widget? pane) {
                              return SizedBox(
                                // Clamped here as well: the window can shrink
                                // below a width chosen earlier.
                                width: width.clamp(
                                  minChatListWidth,
                                  maxChatListWidth,
                                ),
                                child: pane,
                              );
                            },
                        child: _InboxPane(
                          overlayComposer: true,
                          bottomInset: composerBottomInset,
                        ),
                      ),
                      _DraggableSidebarDivider(
                        onDragUpdate: (double delta) {
                          _desktopChatListWidth.value =
                              (_desktopChatListWidth.value + delta).clamp(
                                minChatListWidth,
                                maxChatListWidth,
                              );
                        },
                        onReset: () => _desktopChatListWidth.value = 360.0,
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: context.reduceMotion
                              ? Duration.zero
                              : M3Durations.medium1,
                          switchInCurve: M3SpringCurves.expressiveDecel,
                          switchOutCurve: M3SpringCurves.expressiveAccel,
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(
                                        0.015,
                                        0.0,
                                      ), // ~12dp subtle slide
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                          child: desktopChatId != null
                              ? ChatDetailScreen(
                                  key: ValueKey<int>(desktopChatId),
                                  chatId: desktopChatId.toString(),
                                  highlightMessageId: widget.highlightMessageId,
                                  isDesktopSplit: true,
                                )
                              : KeyedSubtree(
                                  key: const ValueKey<String>(
                                    'desktop_empty_chat',
                                  ),
                                  child: _buildDesktopEmptyChatPlaceholder(
                                    context,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  )
                else
                  desktopChatOpen
                      ? ChatDetailScreen(
                          key: ValueKey(desktopChatId),
                          chatId: desktopChatId.toString(),
                          highlightMessageId: widget.highlightMessageId,
                        )
                      : const _InboxPane(overlayComposer: false),
                rail
                    ? Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 820),
                          child: const NiosgramScreen(),
                        ),
                      )
                    : const NiosgramScreen(),
                ProfileScreen(
                  initialSection:
                      capabilities.browserWorkspace &&
                          widget.settingsSection != null
                      ? SettingsSectionId.fromString(widget.settingsSection)
                      : null,
                  initialAnchor: capabilities.browserWorkspace
                      ? widget.settingsAnchor
                      : null,
                ),
              ];
              final PerformanceTier tier = ref.watch(
                adaptivePerformanceProvider.select((s) => s.tier),
              );
              final bool tabMotion = !context.reduceMotion;

              final Widget body = NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification) {
                    _mainScrolling = true;
                  }
                  if (notification is ScrollEndNotification) {
                    _mainScrolling = false;
                    if (currentIndex == 0 &&
                        notification.depth == 0 &&
                        notification.metrics.axis == Axis.vertical &&
                        notification.metrics.extentAfter <= 0) {
                      // The list is parked at its end, where the composer would
                      // sit right on top of the last row and its badge: keep it
                      // hidden until the user scrolls back up.
                      ref.read(chatListFabVisibleProvider.notifier).hide();
                    }
                  }
                  _syncInteraction();
                  return false;
                },
                child: M3RouteTabSwitcher(
                  onTransitionStateChanged: (_) => _syncInteraction(),
                  index: currentIndex,
                  controller: _tabTransition,
                  animate: tabMotion,
                  // Same duration as the navigation bar indicator.
                  duration: tier.isTierC
                      ? M3Durations.short4
                      : M3Durations.medium2,
                  children: List<Widget>.generate(pages.length, (int index) {
                    if (!_activatedTabs.contains(index)) {
                      return const SizedBox.shrink();
                    }
                    final bool isActive = index == currentIndex;
                    return TickerMode(
                      enabled: isActive,
                      // Chat tiles of a hidden tab must not start Hero flights.
                      child: HeroMode(
                        enabled: isActive,
                        child: RepaintBoundary(child: pages[index]),
                      ),
                    );
                  }),
                ),
              );

              return ShellWindowTitle(
                settingsOpen: currentIndex == AppNavDestination.settings.index,
                // The same rule the hub applies to the room it is given.
                sectionVisible:
                    Breakpoints.settingsTwoPane(
                      Size(workspaceWidth, constraints.maxHeight),
                    ) ||
                    (capabilities.browserWorkspace &&
                        widget.settingsSection != null),
                webSection: capabilities.browserWorkspace
                    ? SettingsSectionId.fromString(widget.settingsSection)
                    : null,
                child: Scaffold(
                extendBody: false,
                body: Column(
                  children: [
                    OfflineBanner(isOffline: isOffline),
                    Expanded(
                      child: Row(
                        children: [
                          if (rail) ...[
                            RepaintBoundary(
                              child: AppNavRail(
                                currentIndex: currentIndex,
                                onTap: _onTapTab,
                                onReselect: _onReselectTab,
                                hapticsEnabled: haptics,
                              ),
                            ),
                            const VerticalDivider(width: 1),
                          ],
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
                    ),
                  ],
                ),
                bottomNavigationBar: rail
                    ? null
                    : RepaintBoundary(
                        child: AppBottomNav(
                          currentIndex: currentIndex,
                          onTap: _onTapTab,
                          onReselect: _onReselectTab,
                          hapticsEnabled: haptics,
                        ),
                      ),
                floatingActionButton:
                    !isWide &&
                        currentIndex == 0 &&
                        !(capabilities.browserWorkspace &&
                            desktopChatId != null)
                    ? const InboxComposeButton()
                    : null,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopEmptyChatPlaceholder(BuildContext context) {
    if (ref.read(clientCapabilitiesProvider).browserWorkspace) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.forum_outlined, size: 56, color: scheme.primary),
                const SizedBox(height: 20),
                Text(
                  'NiosMess Web',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.webWorkspaceHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final radii = AppRadii.of(context);
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
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(radii.card),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.25),
                  width: 1.2,
                ),
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
                borderRadius: BorderRadius.circular(radii.button),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                context.l10n.shellSelectChatToStart,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.shellE2eeNotice,
              style: TextStyle(
                fontSize: 12,
                // Full tone: 12 px text at 70% alpha fell under 4.5:1.
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inbox pane chrome shared by the compact and the list–detail layouts.
///
/// * The list is centred inside [kInboxContentMaxWidth] so tablet/desktop
///   windows never stretch it edge to edge (audit P0 #3).
/// * A tonal scrim covers the [kInboxComposerClearance] strip the list keeps
///   free for the composer, so rows and unread badges never show through
///   around the button (audit P0 #1).
/// * In list–detail mode the composer is positioned here, inset-aware, with
///   the exact clearance the list reserves at its end.
class _InboxPane extends ConsumerWidget {
  const _InboxPane({required this.overlayComposer, this.bottomInset = 0});

  /// `true` in list–detail mode, where the shell owns the FAB position.
  /// `false` on phones: the enclosing [Scaffold] docks the FAB.
  final bool overlayComposer;

  /// Extra bottom inset (system gesture area) for hosts without a nav bar.
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kInboxContentMaxWidth),
            child: const ChatListScreen(),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: kInboxComposerClearance,
          child: _InboxComposerScrim(),
        ),
        if (overlayComposer)
          Positioned(
            right: kInboxComposerMargin,
            bottom: kInboxComposerMargin + bottomInset,
            child: const InboxComposeButton(),
          ),
      ],
    );
  }
}

/// Tonal fade under the composer. No blur, no shadow: the pane backdrop is
/// blended over the last rows so text and badges do not peek around the FAB.
/// It follows the composer's own visibility, so scrolling down (which hides
/// the FAB) leaves the list untouched.
class _InboxComposerScrim extends ConsumerWidget {
  const _InboxComposerScrim();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool visible = ref.watch(inboxComposerVisibleProvider);
    final Color backdrop = AppSurfaces.of(context);

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: context.reduceMotion
            ? Duration.zero
            : M3Durations.short4,
        curve: M3SpringCurves.expressiveDecel,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                backdrop.withValues(alpha: 0),
                backdrop.withValues(alpha: 0.72),
                backdrop.withValues(alpha: 0.97),
              ],
              stops: const <double>[0, 0.55, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class _DraggableSidebarDivider extends StatefulWidget {
  const _DraggableSidebarDivider({required this.onDragUpdate, this.onReset});

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
            duration: M3Durations.short3,
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
