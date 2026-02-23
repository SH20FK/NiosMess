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
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen>
    with AutomaticKeepAliveClientMixin {
  final api = ApiRepository();
  final SearchController _searchController = SearchController();
  List<ChatItem> chats = [];
  String _selectedFilter = 'all';
  final Map<String, Uint8List?> _avatarCache = {};
  final Map<String, MessageItem> _lastMessages = {};
  bool loading = true;
  String query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => query = _searchController.text);
  }

  Future<void> _load() async {
    final session = ref.read(sessionProvider);
    try {
      final data = await api.getChats(session.username!, session.token!);
      setState(() {
        chats = data;
        loading = false;
      });
      _loadLastMessages();
    } catch (_) {
      final cached = await api.getCachedChats();
      setState(() {
        chats = cached;
        loading = false;
      });
      _loadLastMessages();
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
        title: const Text('Чаты'),
        actions: [
          SearchAnchor(
            searchController: _searchController,
            builder: (context, controller) => IconButton(
              onPressed: () => controller.openView(),
              icon: const Icon(Icons.search),
              tooltip: 'Поиск',
            ),
            suggestionsBuilder: (context, controller) {
              final q = controller.text.trim().toLowerCase();
              final items = q.isEmpty
                  ? chats.take(6).toList()
                  : chats
                      .where((c) =>
                          c.name.toLowerCase().contains(q) ||
                          c.id.toLowerCase().contains(q))
                      .take(8)
                      .toList();
              return items.map((c) {
                return ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: Text(c.name),
                  subtitle:
                      Text(c.type == 'user' ? c.id : c.type.toUpperCase()),
                  onTap: () {
                    controller.closeView('');
                    _searchController.clear();
                    _openChat(c);
                  },
                );
              }).toList();
            },
          ),
          IconButton(
            onPressed: _openCreateGroup,
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Создать группу',
          ),
          PopupMenuButton<FocusModeType>(
            tooltip: 'Фокус',
            icon: const Icon(Icons.tune),
            onSelected: (mode) =>
                ref.read(focusModeProvider.notifier).setMode(mode),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: FocusModeType.all,
                checked: focusMode.mode == FocusModeType.all,
                child: const Text('Фокус: все'),
              ),
              CheckedPopupMenuItem(
                value: FocusModeType.work,
                checked: focusMode.mode == FocusModeType.work,
                child: const Text('Фокус: учёба'),
              ),
              CheckedPopupMenuItem(
                value: FocusModeType.personal,
                checked: focusMode.mode == FocusModeType.personal,
                child: const Text('Фокус: личное'),
              ),
            ],
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
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

                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, (1 - value) * 8),
                                    child: child,
                                  ),
                                );
                              },
                              child: RepaintBoundary(
                                child: SwipeableChatItem(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    _openChat(c);
                                  },
                                  onLongPress: () => _openFocusCategorySheet(c),
                                  onDelete: () => _deleteChat(c),
                                  onPin: () => _archiveChat(c),
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
        child: fallback,
      );
    } else {
      final username = (chat.username ?? chat.id).trim();
      final bytes = _avatarCache[username];

      if (bytes != null && bytes.isNotEmpty) {
        avatarContent = CircleAvatar(
          radius: 28,
          backgroundImage: MemoryImage(bytes),
        );
      } else {
        _ensureAvatar(chat);
        avatarContent = CircleAvatar(
          radius: 28,
          backgroundColor: colorScheme.surfaceContainerHighest,
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
                color: NiosColors.greenOnline,
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
      return Hero(tag: 'chat_avatar_${chat.id}', child: avatar);
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
}
