import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/models/chat_item.dart';
import '../../core/session_provider.dart';
import '../../core/repositories/api_repository.dart';
import '../../core/settings_provider.dart';
import '../../core/window_state_persistence.dart';
import '../chats/chat_list_screen.dart';
import '../chat/chat_screen.dart';
import '../calls/calls_screen.dart';
import '../contacts/contacts_screen.dart';
import '../settings/settings_main_screen.dart';
import '../profile/profile_screen.dart';
import '../../ui/nios_ui.dart';
import '../../ui/widgets/resizable_panel_divider.dart';
import '../../ui/widgets/drop_zone_widget.dart';
import 'global_search_modal.dart';
import 'package:animations/animations.dart';
import '../../core/theme.dart';

/// Desktop layout with sidebar navigation — Telegram Desktop style.
/// Three panels: 80px nav | resizable chat list | expandable chat detail.
class DesktopLayout extends ConsumerStatefulWidget {
  const DesktopLayout({super.key});

  @override
  ConsumerState<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends ConsumerState<DesktopLayout>
    with WindowListener {
  int _selectedIndex = 0;
  ChatItem? _selectedChat;
  bool _showSettings = false;
  double _chatListWidth = 320.0;

  // Keys to allow programmatic search focus
  final GlobalKey<ChatListScreenState> _chatListKey = GlobalKey();

  // Debounce timer for window state saving
  Timer? _windowSaveDebounce;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
    }
    _loadPanelWidth();
  }

  @override
  void dispose() {
    _windowSaveDebounce?.cancel();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _loadPanelWidth() async {
    final saved = await WindowStatePersistence.loadChatListWidth();
    if (saved != null && mounted) {
      setState(() => _chatListWidth = saved.clamp(260.0, 500.0));
    }
  }

  // WindowListener callbacks — debounced save on resize/move
  @override
  void onWindowResized() => _scheduleSave();

  @override
  void onWindowMoved() => _scheduleSave();

  @override
  void onWindowClose() async {
    // Hide to tray instead of closing (minimize to tray behavior)
    await WindowStatePersistence.save();
    await windowManager.hide();
  }

  void _scheduleSave() {
    _windowSaveDebounce?.cancel();
    _windowSaveDebounce = Timer(
      const Duration(milliseconds: 500),
      WindowStatePersistence.save,
    );
  }

  void _onChatSelected(ChatItem chat) {
    setState(() {
      _selectedChat = chat;
      _selectedIndex = 0;
      _showSettings = false;
    });
  }

  void _onSelectChatById(String chatId) {
    // For calls/contacts: open chat panel with minimal info
    setState(() {
      _selectedChat = ChatItem(
        id: chatId,
        name: chatId,
        type: 'user',
        unread: 0,
        username: chatId,
      );
      _selectedIndex = 0;
      _showSettings = false;
    });
  }

  void _onResizePanel(double delta) {
    setState(() {
      _chatListWidth = (_chatListWidth + delta).clamp(260.0, 500.0);
    });
  }

  void _onResizePanelEnd() {
    WindowStatePersistence.saveChatListWidth(_chatListWidth);
  }

  void _openGlobalSearch() {
    final chats = _chatListKey.currentState?.chats ?? [];
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => GlobalSearchModal(
        chats: chats,
        onChatSelected: _onChatSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DesktopShortcuts(
      onNewChat: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const _CreateGroupPlaceholder()),
      ),
      onSearch: () {
        if (_selectedIndex == 0 && !_showSettings) {
          _chatListKey.currentState?.focusSearch();
        } else {
          _openGlobalSearch();
        }
      },
      onGlobalSearch: _openGlobalSearch,
      onSettings: () => setState(() => _showSettings = true),
      onClose: () => setState(() => _selectedChat = null),
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: Column(
          children: [
            // Custom Title Bar for desktop
            if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
              _buildCustomTitleBar(context),
            Expanded(
              child: Row(
                children: [
                  // ── Left sidebar ──────────────────────────────────────
                  RepaintBoundary(
                    child: Stack(
                      children: [
                        SizedBox(
                          width: 88,
                          child: NavigationRail(
                            selectedIndex: _showSettings ? 3 : _selectedIndex,
                            backgroundColor: colorScheme.surface,
                            labelType: NavigationRailLabelType.selected,
                            leading: Padding(
                              padding: const EdgeInsets.only(top: 16, bottom: 8),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: colorScheme.primaryContainer,
                                child: Icon(
                                  Icons.bubble_chart_rounded,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            trailing: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: IconButton(
                                icon: const Icon(Icons.search_rounded),
                                tooltip: 'Поиск',
                                onPressed: _openGlobalSearch,
                              ),
                            ),
                            destinations: const [
                              NavigationRailDestination(
                                icon: Icon(Icons.forum_outlined),
                                label: Text('Чаты'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.call_outlined),
                                label: Text('Звонки'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.people_outline_rounded),
                                label: Text('Контакты'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.settings_outlined),
                                label: Text('Настройки'),
                              ),
                            ],
                            onDestinationSelected: (index) {
                              setState(() {
                                if (index == 3) {
                                  _showSettings = true;
                                } else {
                                  _showSettings = false;
                                  _selectedIndex = index;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Content area (middle + right panels) ─────────────
                  Expanded(
                    child: Row(
                      children: [
                        // Middle panel with smooth transition
                        SizedBox(
                          width: _chatListWidth,
                          child: PageTransitionSwitcher(
                            duration: NiosAnimations.normal,
                            transitionBuilder: (child, animation, secondaryAnimation) {
                              return SharedAxisTransition(
                                animation: animation,
                                secondaryAnimation: secondaryAnimation,
                                transitionType: SharedAxisTransitionType.horizontal,
                                child: child,
                              );
                            },
                            child: _buildMiddlePanel(colorScheme),
                          ),
                        ),

                        // Resizable divider
                        ResizablePanelDivider(
                          onResize: _onResizePanel,
                          onResizeEnd: _onResizePanelEnd,
                        ),

                        // Right panel — selected chat or empty state
                        Expanded(
                          child: PageTransitionSwitcher(
                            duration: NiosAnimations.normal,
                            transitionBuilder: (child, animation, secondaryAnimation) {
                              return FadeThroughTransition(
                                animation: animation,
                                secondaryAnimation: secondaryAnimation,
                                child: child,
                              );
                            },
                            child: _selectedChat != null
                                ? _buildChatPanel()
                                : _buildEmptyState(context),
                          ),
                        ),
                      ],
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

  Widget _buildMiddlePanel(ColorScheme colorScheme) {
    Widget content;
    Key panelKey;

    if (_showSettings) {
      panelKey = const ValueKey('settings');
      content = const SettingsMainScreen();
    } else if (_selectedIndex == 0) {
      panelKey = const ValueKey('chats');
      content = ChatListScreen(
        key: _chatListKey,
        onChatSelected: _onChatSelected,
      );
    } else if (_selectedIndex == 1) {
      panelKey = const ValueKey('calls');
      content = CallsScreen(onSelectChat: _onSelectChatById);
    } else if (_selectedIndex == 2) {
      panelKey = const ValueKey('contacts');
      content = ContactsScreen(onSelectChat: _onSelectChatById);
    } else {
      panelKey = const ValueKey('empty_panel');
      content = const Center(child: Text('Раздел в разработке'));
    }

    return Container(
      key: panelKey,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          right: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: content,
    );
  }

  Widget _buildChatPanel() {
    final chat = _selectedChat!;
    final session = ref.read(sessionProvider);
    final api = ApiRepository();

    return DropZoneWidget(
      onFilesDropped: (paths) async {
        if (!session.isAuthed) return;
        for (final path in paths) {
          try {
            await api.uploadFile(
              sender: session.username!,
              receiver: chat.id,
              token: session.token!,
              filePath: path,
            );
          } catch (_) {}
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Отправлено файлов: ${paths.length}')),
          );
        }
      },
      child: ChatScreen(
        key: ValueKey(chat.id),
        chatId: chat.id,
        chatUsername: chat.username,
        chatType: chat.type,
        title: chat.name,
        status: chat.isOnline == true
            ? 'В сети'
            : chat.lastSeenText ?? 'Не в сети',
        badgeText: chat.badgeText ?? chat.badgeTitle,
        badgeIcon: chat.badgeIcon,
        onBack: () => setState(() => _selectedChat = null),
        onOpenProfile: (username) {
          showDialog(
            context: context,
            builder: (_) => Dialog(
              child: SizedBox(
                width: 420,
                child: ProfileScreen(
                  targetUsername: username,
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomTitleBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: WindowCaption(
        brightness: Theme.of(context).brightness,
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            const SizedBox(width: 8),
            Icon(Icons.bubble_chart_rounded,
                size: 20, color: colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              'NiosMess',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final reduceMotion =
        (ref.watch(settingsProvider)['reduce_motion'] as bool?) ?? false;
    return Container(
      key: const ValueKey('empty_state'),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: NiosNoiseLayer(opacity: 0.18),
          ),
          Center(
            child: NiosMotionWrap(
              enableMotion: !reduceMotion,
              blurSigma: 14,
              offset: const Offset(0, 24),
              duration: const Duration(milliseconds: 700),
              child: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _FloatingFox(
                      enable: !reduceMotion,
                      child: Image.asset(
                        'assets/images/fox.png',
                        width: 140,
                        height: 140,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Пока что тут ничего нет',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Выберите чат слева или создайте новый',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ctrl+K — глобальный поиск\nCtrl+N — новый чат\nEsc — закрыть',
                      textAlign: TextAlign.center,
                      style: textTheme.labelSmall?.copyWith(
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                        height: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Placeholder for creating new chats from shortcut
class _CreateGroupPlaceholder extends StatelessWidget {
  const _CreateGroupPlaceholder();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('Создать чат')),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class FadeInAnimation extends StatefulWidget {
  final Widget child;
  const FadeInAnimation({super.key, required this.child});

  @override
  State<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: NiosAnimations.slow,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: NiosAnimations.easeOutQuart,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: _animation.drive(
          Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero),
        ),
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FloatingFox extends StatefulWidget {
  const _FloatingFox({required this.child, required this.enable});

  final Widget child;
  final bool enable;

  @override
  State<_FloatingFox> createState() => _FloatingFoxState();
}

class _FloatingFoxState extends State<_FloatingFox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.enable) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _FloatingFox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enable != widget.enable) {
      if (widget.enable) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enable) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dy = -12 * _controller.value;
        return Transform.translate(
          offset: Offset(0, dy),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Keyboard shortcuts handler for desktop.
/// Wraps the entire desktop layout body.
class DesktopShortcuts extends StatelessWidget {
  final Widget child;
  final VoidCallback? onNewChat;
  final VoidCallback? onSearch;
  final VoidCallback? onGlobalSearch;
  final VoidCallback? onSettings;
  final VoidCallback? onClose;

  const DesktopShortcuts({
    super.key,
    required this.child,
    this.onNewChat,
    this.onSearch,
    this.onGlobalSearch,
    this.onSettings,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final ctrl = HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed;

        // Ctrl+N — new chat
        if (ctrl && event.logicalKey == LogicalKeyboardKey.keyN) {
          onNewChat?.call();
          return KeyEventResult.handled;
        }
        // Ctrl+F — focus search in panel
        if (ctrl && event.logicalKey == LogicalKeyboardKey.keyF) {
          onSearch?.call();
          return KeyEventResult.handled;
        }
        // Ctrl+K — global search modal
        if (ctrl && event.logicalKey == LogicalKeyboardKey.keyK) {
          onGlobalSearch?.call();
          return KeyEventResult.handled;
        }
        // Ctrl+, — settings
        if (ctrl && event.logicalKey == LogicalKeyboardKey.comma) {
          onSettings?.call();
          return KeyEventResult.handled;
        }
        // Escape — close current chat / close search
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          onClose?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
