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
import '../../core/utils/error_handler.dart';
import '../../ui/nios_ui.dart';
import '../../ui/widgets/swipeable_chat_item.dart';
import '../../ui/widgets/staggered_list.dart';
import '../../ui/widgets/glass_container.dart';
import '../chat/chat_screen.dart';
import '../groups/create_group_screen.dart';
import '../profile/profile_screen.dart';
import '../stories/widgets/stories_row.dart';

/// Улучшенный экран списка чатов с Material 3 дизайном
class EnhancedChatListScreen extends ConsumerStatefulWidget {
  const EnhancedChatListScreen({super.key});

  @override
  ConsumerState<EnhancedChatListScreen> createState() => _EnhancedChatListScreenState();
}

class _EnhancedChatListScreenState extends ConsumerState<EnhancedChatListScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final api = ApiRepository();
  final SearchController _searchController = SearchController();
  final ScrollController _scrollController = ScrollController();

  List<ChatItem> chats = [];
  String _selectedFilter = 'all';
  final Map<String, Uint8List?> _avatarCache = {};
  final Map<String, MessageItem> _lastMessages = {};
  bool loading = true;
  String? error;
  String query = '';
  bool _showScrollButton = false;

  late AnimationController _fabController;
  late AnimationController _headerController;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );

    _load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _fabController.dispose();
    _headerController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => query = _searchController.text);
  }

  void _onScroll() {
    // Скрытие/показ FAB при скролле
    if (_scrollController.offset > 100 && !_showScrollButton) {
      setState(() => _showScrollButton = true);
      _fabController.forward();
    } else if (_scrollController.offset <= 100 && _showScrollButton) {
      setState(() => _showScrollButton = false);
      _fabController.reverse();
    }

    // Анимация заголовка при скролле
    final progress = (_scrollController.offset / 100).clamp(0.0, 1.0);
    _headerController.value = 1.0 - progress;
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    final session = ref.read(sessionProvider);
    try {
      final data = await api.getChats(session.username!, session.token!);
      if (!mounted) return;

      setState(() {
        chats = data;
        loading = false;
      });

      _loadLastMessages();
    } catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'LoadChats');

      // Fallback к кэшу
      final cached = await api.getCachedChats();
      if (!mounted) return;

      setState(() {
        chats = cached;
        loading = false;
        error = cached.isEmpty ? ErrorHandler.getUserMessage(e) : null;
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
      } catch (e, stack) {
        ErrorHandler.handle(e, stackTrace: stack, context: 'LoadLastMessage');
      }
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

    try {
      final bytes = await api.getAvatarBytes(username);
      if (!mounted) return;
      setState(() => _avatarCache[username] = bytes);
    } catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'LoadAvatar');
    }
  }

  List<ChatItem> get _filteredChats {
    var items = chats;

    // Фильтр по типу
    if (_selectedFilter != 'all') {
      items = items.where((c) => c.type == _selectedFilter).toList();
    }

    // Фильтр Focus Mode
    final focusMode = ref.watch(focusModeProvider);
    if (focusMode.mode == FocusModeType.work) {
      items = items.where((c) => focusMode.workChatIds.contains(c.id)).toList();
    } else if (focusMode.mode == FocusModeType.personal) {
      items = items.where((c) => focusMode.personalChatIds.contains(c.id)).toList();
    }

    // Поиск
    if (query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      items = items.where((c) {
        final name = (c.name ?? c.username ?? '').toLowerCase();
        final lastMsg = _lastMessages[c.id]?.text.toLowerCase() ?? '';
        return name.contains(lowerQuery) || lastMsg.contains(lowerQuery);
      }).toList();
    }

    return items;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final filteredChats = _filteredChats;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        edgeOffset: 80,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // Animated AppBar
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              stretch: true,
              elevation: 0,
              backgroundColor: theme.colorScheme.surface,
              surfaceTintColor: theme.colorScheme.surfaceTint,
              systemOverlayStyle: theme.brightness == Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                title: AnimatedBuilder(
                  animation: _headerController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _headerController.value,
                      child: Text(
                        'Чаты',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    );
                  },
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                        theme.colorScheme.surface,
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchController.openView(),
                  tooltip: 'Поиск',
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: _showMenu,
                  tooltip: 'Меню',
                ),
              ],
            ),

            // Stories Row
            SliverToBoxAdapter(
              child: AnimatedOnScroll(
                child: const StoriesRow(),
              ),
            ),

            // Фильтры
            SliverToBoxAdapter(
              child: AnimatedOnScroll(
                child: _buildFilters(theme),
              ),
            ),

            // Список чатов или состояние ошибки/пустой список
            if (loading)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Загрузка чатов...',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        error!,
                        style: theme.textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              )
            else if (filteredChats.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        query.isEmpty ? 'Нет чатов' : 'Ничего не найдено',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        query.isEmpty
                            ? 'Начните новый чат'
                            : 'Попробуйте другой запрос',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final chat = filteredChats[index];
                    _ensureAvatar(chat);

                    return AnimatedListItem(
                      index: index,
                      delay: const Duration(milliseconds: 30),
                      child: SwipeableChatItem(
                        onTap: () => _openChat(chat),
                        onPin: () => _pinChat(chat),
                        onDelete: () => _deleteChat(chat),
                        isPinned: chat.isPinned ?? false,
                        isRead: chat.unread == 0,
                        child: _buildChatTile(chat),
                      ),
                    );
                  },
                  childCount: filteredChats.length,
                ),
              ),
          ],
        ),
      ),

      // FAB с анимацией
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scroll to top button
          if (_showScrollButton)
            ScaleTransition(
              scale: _fabController,
              child: FloatingActionButton.small(
                heroTag: 'scroll-top',
                onPressed: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutQuart,
                  );
                },
                child: const Icon(Icons.arrow_upward),
              ),
            ),
          const SizedBox(height: 12),
          // Новый чат
          FloatingActionButton(
            heroTag: 'new-chat',
            onPressed: _createNewChat,
            child: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(ThemeData theme) {
    final filters = [
      ('all', 'Все', Icons.chat_bubble_outline),
      ('user', 'Личные', Icons.person_outline),
      ('group', 'Группы', Icons.groups_outlined),
      ('channel', 'Каналы', Icons.campaign_outlined),
    ];

    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (key, label, icon) = filters[index];
          final isSelected = _selectedFilter == key;

          return FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 6),
                Text(label),
              ],
            ),
            selected: isSelected,
            onSelected: (selected) {
              setState(() => _selectedFilter = key);
            },
            showCheckmark: false,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            selectedColor: theme.colorScheme.primaryContainer,
            labelStyle: theme.textTheme.labelLarge?.copyWith(
              color: isSelected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          );
        },
      ),
    );
  }

  Widget _buildChatTile(ChatItem chat) {
    final lastMessage = _lastMessages[chat.id];
    final avatarBytes = _avatarCache[chat.username ?? chat.id];
    final hasUnread = (chat.unread ?? 0) > 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: avatarBytes != null ? MemoryImage(avatarBytes) : null,
        child: avatarBytes == null ? Text(chat.name.isEmpty ? '?' : chat.name.characters.first.toUpperCase()) : null,
      ),
      title: Text(
        chat.name,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: lastMessage != null
          ? Text(
              lastMessage.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (chat.isPinned ?? false)
            const Icon(Icons.push_pin, size: 16),
          if (hasUnread)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${chat.unread}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openChat(ChatItem chat) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chat.id,
          chatUsername: chat.username,
          chatType: chat.type,
          onBack: () => Navigator.of(context).pop(),
          onOpenProfile: (String username) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileScreen(
                  targetUsername: chat.username ?? '',
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _createNewChat() {
    // TODO: Открыть экран создания чата
    showModalBottomSheet(
      context: context,
      builder: (context) => GlassBottomSheet(
        height: 200,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Новый чат'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Открыть выбор контакта
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('Новая группа'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateGroupScreen(
                      onBack: () => Navigator.of(context).pop(),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _archiveChat(ChatItem chat) {
    // TODO: Архивация чата
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${chat.name} архивирован')),
    );
  }

  void _deleteChat(ChatItem chat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить чат?'),
        content: Text('Вы уверены, что хотите удалить чат с ${chat.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: Удалить чат через API
      setState(() {
        chats.removeWhere((c) => c.id == chat.id);
      });
    }
  }

  void _pinChat(ChatItem chat) {
    // TODO: Закрепить чат
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${chat.name} закреплён')),
    );
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => GlassBottomSheet(
        height: 300,
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Профиль'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      onBack: () => Navigator.of(context).pop(),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Настройки'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Открыть настройки
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive),
              title: const Text('Архив'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Открыть архив
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Папки'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Открыть папки
              },
            ),
          ],
        ),
      ),
    );
  }
}
