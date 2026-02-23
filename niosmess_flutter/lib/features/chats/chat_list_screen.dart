import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/chat_item.dart';
import '../../core/models/message_item.dart';
import '../../core/repositories/api_repository.dart';
import '../../core/session_provider.dart';
import '../../core/storage/offline_cache.dart';
import '../../core/obfuscate.dart';
import '../../core/settings_provider.dart';
import '../../core/focus_mode_provider.dart';
import '../../ui/nios_ui.dart';
import '../../ui/widgets/swipeable_chat_item.dart';
import '../chat/chat_screen.dart';
import '../groups/create_group_screen.dart';
import '../profile/profile_screen.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  final void Function(ChatItem chat)? onChatSelected;
  final FocusNode? searchFocusNode;

  const ChatListScreen({super.key, this.onChatSelected, this.searchFocusNode});

  @override
  ConsumerState<ChatListScreen> createState() => ChatListScreenState();
}

// Public state class so desktop GlobalKey<ChatListScreenState> can access chats/focusSearch
class ChatListScreenState extends ConsumerState<ChatListScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final api = ApiRepository();
  final SearchController _searchController = SearchController();
  final FocusNode _searchFocusNode = FocusNode();
  late AnimationController _searchAnimationController;
  late Animation<double> _searchAnimation;
  List<ChatItem> chats = [];
  String _selectedFilter = 'all';
  final Map<String, Uint8List?> _avatarCache = {};
  final Map<String, MessageItem> _lastMessages = {};
  bool loading = true;
  bool _isSyncing = false;
  String query = '';
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    
    // Search focus animation
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeOutCubic,
    );
    
    _load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _searchAnimationController.dispose();
    super.dispose();
  }

  void _onSearchFocusChanged() {
    setState(() {
      _isSearchFocused = _searchFocusNode.hasFocus;
    });
    if (_searchFocusNode.hasFocus) {
      _searchAnimationController.forward();
    } else {
      _searchAnimationController.reverse();
    }
  }

  void _onSearchChanged() {
    setState(() => query = _searchController.text);
  }

  Future<void> _load() async {
    final session = ref.read(sessionProvider);
    // 1) Cache-first
    List<ChatItem> cached = [];
    try {
      cached = await api.getCachedChats();
    } catch (e) {
      debugPrint('[ChatList] cache read error: $e');
    }
    if (!mounted) return;
    setState(() {
      chats = cached;
      loading = false;
    });
    _loadLastMessages();

    // 2) Background sync if session is valid
    if (session.username == null || session.token == null) return;
    setState(() => _isSyncing = true);
    try {
      final data = await api.getChats(session.username!, session.token!);
      if (!mounted) return;
      setState(() {
        chats = data;
      });
      _loadLastMessages();
    } catch (e) {
      debugPrint('[ChatList] _load sync error: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _loadLastMessages() async {
    final map = <String, MessageItem>{};
    for (final chat in chats) {
      try {
        final rawList = await OfflineCache.loadMessages(chat.id);
        if (rawList.isEmpty) continue;
        final last = Map<String, dynamic>.from(rawList.last);
        final rawText = last['text']?.toString() ?? '';
        last['text'] = Obfuscator.deobfuscate(rawText);
        map[chat.id] = MessageItem.fromJson(last);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _lastMessages
        ..clear()
        ..addAll(map);
    });
  }

  Future<void> _ensureAvatar(ChatItem chat) async {
    if (chat.type != 'user') return;
    final username = (chat.username ?? chat.id).trim();
    if (username.isEmpty) return;
    if (_avatarCache.containsKey(username)) return;
    final bytes = await api.getAvatarBytes(username);
    if (!mounted) return;
    setState(() => _avatarCache[username] = bytes);
  }

  String _previewText(String text) {
    if (text.startsWith('POLL:')) return 'Опрос';
    if (text.startsWith('LOCATION:')) return 'Геолокация';
    if (text.startsWith('CONTACT:')) return 'Контакт';
    if (text.startsWith('MEDIA:')) return 'Медиа';
    if (text.startsWith('FILE:')) return 'Файл';
    return text;
  }

  String _formatMessageTime(String raw) {
    if (raw.isEmpty) return '';
    final value = double.tryParse(raw);
    if (value == null) return raw;
    final dt = DateTime.fromMillisecondsSinceEpoch((value * 1000).toInt());
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _openChat(ChatItem chat) {
    // Desktop panel mode: use callback instead of Navigator.push
    if (widget.onChatSelected != null) {
      widget.onChatSelected!(chat);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chat.id,
          chatUsername: chat.username,
          chatType: chat.type,
          title: chat.name,
          status: chat.isOnline == true
              ? 'В сети'
              : chat.lastSeenText ?? 'Не в сети',
          badgeText: chat.badgeText ?? chat.badgeTitle,
          badgeIcon: chat.badgeIcon,
          onBack: () => Navigator.of(context).pop(),
          onOpenProfile: (username) => _openProfile(username),
        ),
      ),
    );
  }

  /// Allows external callers (e.g. desktop keyboard shortcut) to focus the search field.
  void focusSearch() {
    _searchFocusNode.requestFocus();
  }

  void _openProfile(String? username) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          targetUsername: username,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _openCreateGroup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateGroupScreen(
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final settings = ref.watch(settingsProvider);
    final focusMode = ref.watch(focusModeProvider);
    final reduceMotion = (settings['reduce_motion'] as bool?) ?? false;
    final compact = (settings['compact_messages'] as bool?) ?? false;
    final byType = chats.where((c) {
      if (_selectedFilter == 'all') return true;
      if (_selectedFilter == 'chats') return c.type == 'user';
      if (_selectedFilter == 'groups') return c.type == 'group';
      if (_selectedFilter == 'channels') return c.type == 'channel';
      return true;
    });
    final focusFiltered = byType.where((c) => focusMode.shouldShowChat(c.id));
    final filteredChats = query.isEmpty
        ? focusFiltered.toList()
        : focusFiltered
            .where((c) =>
                c.name.toLowerCase().contains(query.toLowerCase()) ||
                c.id.toLowerCase().contains(query.toLowerCase()))
            .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'new_chat_fab',
        onPressed: _openCreateGroup,
        tooltip: 'Новый чат',
        child: const Icon(Icons.edit_outlined),
      ),
      appBar: AppBar(
        title: AnimatedOpacity(
          opacity: _isSearchFocused ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: const Text('Чаты'),
        ),
        bottom: _isSyncing
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
        actions: [
          // Animated search bar
          AnimatedBuilder(
            animation: _searchAnimation,
            builder: (context, child) {
              return Container(
                width: 200 + (100 * _searchAnimation.value),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: SearchBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  hintText: 'Поиск чатов...',
                  leading: const Icon(Icons.search),
                  trailing: _searchController.text.isNotEmpty
                      ? [
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => query = '');
                            },
                          ),
                        ]
                      : null,
                  backgroundColor: WidgetStatePropertyAll(
                    Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withOpacity(0.5 + (0.5 * _searchAnimation.value)),
                  ),
                  elevation: const WidgetStatePropertyAll(0),
                  onChanged: (value) => setState(() => query = value),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _openCreateGroup,
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Создать группу',
          ),
        ],
      ),
      body: Column(
        children: [
          if (loading) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 12, 16, NiosSpacing.sm),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('Все'),
                          selected: _selectedFilter == 'all',
                          onSelected: (_) =>
                              setState(() => _selectedFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Чаты'),
                          selected: _selectedFilter == 'chats',
                          onSelected: (_) =>
                              setState(() => _selectedFilter = 'chats'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Группы'),
                          selected: _selectedFilter == 'groups',
                          onSelected: (_) =>
                              setState(() => _selectedFilter = 'groups'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Каналы'),
                          selected: _selectedFilter == 'channels',
                          onSelected: (_) =>
                              setState(() => _selectedFilter = 'channels'),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: filteredChats.isEmpty
                      ? Center(
                          child: NiosMotionWrap(
                            enableMotion: !reduceMotion,
                            blurSigma: 10,
                            offset: const Offset(0, 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Нет чатов',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(
                            top: NiosSpacing.xs,
                            bottom: NiosSpacing.md,
                          ),
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: true,
                          addSemanticIndexes: false,
                          cacheExtent: 1200,
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredChats.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            indent: 76,
                            endIndent: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withValues(alpha: 0.4),
                          ),
                          itemBuilder: (_, i) {
                            final c = filteredChats[i];
                            final last = _lastMessages[c.id];
                            final preview = last != null
                                ? _previewText(last.text)
                                : (c.type == 'user'
                                    ? (c.isOnline == true
                                        ? 'В сети'
                                        : c.lastSeenText ?? 'Не в сети')
                                    : c.type == 'group'
                                        ? 'Группа'
                                        : 'Канал');
                            final timeText =
                                last != null ? _formatMessageTime(last.time) : '';
                            final isOnline = c.isOnline == true && c.type == 'user';

                            return NiosMotionWrap(
                              enableMotion: !reduceMotion,
                              delay: Duration(milliseconds: 25 * i),
                              blurSigma: 10,
                              offset: const Offset(0, 14),
                              child: GestureDetector(

                                onSecondaryTapUp: (details) =>
                                    _showChatContextMenu(details, c),
                                child: RepaintBoundary(
                                  child: SwipeableChatItem(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      _openChat(c);
                                    },
                                    onLongPress: () => _openFocusCategorySheet(c),
                                    onDelete: () => _deleteChat(c),
                                    onPin: () => _pinChat(c),
                                    isPinned: c.isPinned,
                                    child: _buildChatTile(
                                      chat: c,
                                      preview: preview,
                                      timeText: timeText,
                                      isOnline: isOnline,
                                      unread: c.unread,
                                      compact: compact,
                                    ),
                                  ),
                                ),
                                                            ),
                            );
                          },
                        ),
                ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  Widget _buildChatTile({
    required ChatItem chat,
    required String preview,
    required String timeText,
    required bool isOnline,
    required int unread,
    required bool compact,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final timeStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color:
              unread > 0 ? colorScheme.primary : colorScheme.onSurfaceVariant,
        );

    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: NiosSpacing.md,
        vertical: compact ? NiosSpacing.xs : NiosSpacing.sm,
      ),
      leading: _buildAvatar(chat, isOnline),
      title: Text(
        chat.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.titleMedium,
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (timeText.isNotEmpty) Text(timeText, style: timeStyle),
          if (unread > 0) ...[
            const SizedBox(height: NiosSpacing.sm - 2),
            _buildUnreadBadge(unread),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(ChatItem chat, bool isOnline) {
    final colorScheme = Theme.of(context).colorScheme;
    final fallback = Text(
      chat.name.isEmpty ? '?' : chat.name.characters.first.toUpperCase(),
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 20,
        color: colorScheme.onSurface,
      ),
    );

    Widget avatarContent;
    if (chat.type != 'user') {
      avatarContent = CircleAvatar(
        radius: 28,
        backgroundColor: colorScheme.surfaceContainerHighest,
        foregroundColor: colorScheme.onSurface,
        child: fallback,
      );
    } else {
      final username = (chat.username ?? chat.id).trim();
      final bytes = _avatarCache[username];

      if (bytes != null && bytes.isNotEmpty) {
        avatarContent = CircleAvatar(
          radius: 28,
          backgroundColor: colorScheme.surfaceContainerHighest,
          backgroundImage: MemoryImage(bytes),
        );
      } else {
        _ensureAvatar(chat);
        avatarContent = CircleAvatar(
          radius: 28,
          backgroundColor: colorScheme.surfaceContainerHighest,
          foregroundColor: colorScheme.onSurface,
          child: fallback,
        );
      }
    }

    final avatar = Stack(
      children: [
        avatarContent,
        if (isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colorScheme.tertiary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
    if (chat.type == 'user') {
      return Hero(
        tag: 'chat_avatar_${chat.id}',
        child: avatar,
        flightShuttleBuilder: (
          BuildContext flightContext,
          Animation<double> animation,
          HeroFlightDirection flightDirection,
          BuildContext fromHeroContext,
          BuildContext toHeroContext,
        ) {
          return AnimatedBuilder(
            animation: animation,
            builder: (BuildContext context, Widget? child) {
              return Transform.scale(
                scale: animation.value,
                child: avatar,
              );
            },
          );
        },
      );
    }
    return avatar;
  }

  Widget _buildUnreadBadge(int count) {
    final displayCount = count > 99 ? '99+' : count.toString();
    final isSingleDigit = displayCount.length == 1;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: isSingleDigit ? 24 : 32,
      height: 24,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        displayCount,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> _deleteChat(ChatItem chat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить чат?'),
        content: Text(
          'Чат "${chat.name}" будет удален. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      setState(() {
        chats.removeWhere((c) => c.id == chat.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Чат "${chat.name}" удален')),
      );
    }
  }

  Future<void> _archiveChat(ChatItem chat) async {
    setState(() {
      chats.removeWhere((c) => c.id == chat.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Чат "${chat.name}" архивирован')),
    );
  }

  Future<void> _pinChat(ChatItem chat) async {
    final isPinned = chat.isPinned;
    try {
      // Call API to pin/unpin
      final session = ref.read(sessionProvider);
      await api.pinChat(
        token: session.token!,
        username: session.username!,
        chatId: chat.id,
        pinned: !isPinned,
      );
      
      setState(() {
        final index = chats.indexWhere((c) => c.id == chat.id);
        if (index != -1) {
          chats[index] = chat.copyWith(isPinned: !isPinned);
          // Sort: pinned first
          chats.sort((a, b) {
            final aPinned = a.isPinned;
            final bPinned = b.isPinned;
            if (aPinned && !bPinned) return -1;
            if (!aPinned && bPinned) return 1;
            return 0;
          });
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPinned 
                ? 'Чат "${chat.name}" откреплен' 
                : 'Чат "${chat.name}" закреплен'
          ),
          action: SnackBarAction(
            label: 'Отмена',
            onPressed: () => _pinChat(chat), // Toggle back
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  void _openFocusCategorySheet(ChatItem chat) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        final notifier = ref.read(focusModeProvider.notifier);
        final current = notifier.getChatCategory(chat.id);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Работа'),
                trailing: current == ChatCategory.work
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  notifier.setChatCategory(chat.id, ChatCategory.work);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Личное'),
                trailing: current == ChatCategory.fun
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  notifier.setChatCategory(chat.id, ChatCategory.fun);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Сбросить'),
                trailing: current == ChatCategory.uncategorized
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  notifier.setChatCategory(chat.id, ChatCategory.uncategorized);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Показывает контекстное меню для чата (правый клик на ПК)
  void _showChatContextMenu(TapUpDetails details, ChatItem chat) {
    // Контекстное меню только для десктопных платформ
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return;
    }

    final isPinned = chat.isPinned;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'pin',
          child: Row(
            children: [
              Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin),
              const SizedBox(width: 12),
              Text(isPinned ? 'Открепить' : 'Закрепить'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'read',
          child: Row(
            children: [
              const Icon(Icons.mark_email_read_outlined),
              const SizedBox(width: 12),
              const Text('Прочитано'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline, color: Colors.red),
              const SizedBox(width: 12),
              const Text('Удалить чат', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'pin':
          _pinChat(chat);
          break;
        case 'read':
          _markAsRead(chat);
          break;
        case 'delete':
          _deleteChat(chat);
          break;
      }
    });
  }

  /// Отмечает чат как прочитанный
  Future<void> _markAsRead(ChatItem chat) async {
    if (chat.unread <= 0) return;
    try {
      final session = ref.read(sessionProvider);
      await api.markAsRead(
        token: session.token!,
        username: session.username!,
        chatId: chat.id,
        chatType: chat.type,
      );
      setState(() {
        final index = chats.indexWhere((c) => c.id == chat.id);
        if (index != -1) {
          chats[index] = chat.copyWith(unread: 0);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }
}
