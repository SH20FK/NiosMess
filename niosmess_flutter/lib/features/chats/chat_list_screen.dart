import 'dart:typed_data';

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
import '../../core/theme.dart';
import '../../core/focus_mode_provider.dart';
import '../../core/ghost_mode_provider.dart';
import '../../ui/nios_ui.dart';
import '../../ui/widgets/animated_list_item.dart';
import '../../ui/widgets/telegram_animations.dart';
import '../../ui/widgets/swipeable_chat_item.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({
    super.key,
    required this.onOpenChat,
    required this.onOpenSettings,
    required this.onOpenProfile,
    required this.onCreateGroup,
  });

  final void Function(ChatItem chat) onOpenChat;
  final VoidCallback onOpenSettings;
  final void Function(String? username) onOpenProfile;
  final VoidCallback onCreateGroup;

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final api = ApiRepository();
  List<ChatItem> chats = [];
  final Map<String, Uint8List?> _avatarCache = {};
  final Map<String, MessageItem> _lastMessages = {};
  bool loading = true;
  String query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
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

  Widget _avatar(ChatItem chat, {bool useHero = false}) {
    final fallback = Text(
      chat.name.isEmpty ? '?' : chat.name.characters.first.toUpperCase(),
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
    );
    if (chat.type != 'user') {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: NiosPalette.accent.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Center(child: fallback),
      );
    }
    final username = (chat.username ?? chat.id).trim();
    final bytes = _avatarCache[username];
    
    Widget avatar;
    if (bytes != null && bytes.isNotEmpty) {
      avatar = Image.memory(bytes, fit: BoxFit.cover);
    } else {
      _ensureAvatar(chat);
      avatar = Container(
        color: NiosPalette.surfaceHover,
        child: Center(child: fallback),
      );
    }
    
    if (useHero && username.isNotEmpty) {
      return TelegramHeroAvatar(
        heroTag: 'avatar_$username',
        size: 48,
        child: avatar,
        onTap: () => widget.onOpenProfile(username),
      );
    }
    return ClipOval(child: SizedBox(width: 48, height: 48, child: avatar));
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

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final compact = (settings['compact_messages'] as bool?) ?? false;
    final reduceMotion = (settings['reduce_motion'] as bool?) ?? false;
    final showStatus = (settings['show_status'] as bool?) ?? true;
    final showLastSeen = (settings['show_last_seen'] as bool?) ?? true;
    final focusMode = ref.watch(focusModeProvider);
    final ghostMode = ref.watch(ghostModeProvider);
    
    // Filter chats based on Focus Mode
    var filteredChats = query.isEmpty
        ? chats
        : chats
            .where((c) =>
                c.name.toLowerCase().contains(query.toLowerCase()) ||
                c.id.toLowerCase().contains(query.toLowerCase()))
            .toList();
    
    // Apply Focus Mode filter
    if (focusMode.mode != FocusModeType.all) {
      filteredChats = filteredChats.where((c) {
        final category = ref.read(focusModeProvider.notifier).getChatCategory(c.id);
        return focusMode.mode == FocusModeType.work 
            ? category == ChatCategory.work 
            : category == ChatCategory.fun;
      }).toList();
    }

    return NiosScaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Telegram-style AppBar with Focus Mode
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                decoration: BoxDecoration(
                  color: NiosPalette.surface,
                  border: Border(bottom: BorderSide(color: NiosPalette.border)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Чаты',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: NiosPalette.text,
                              ),
                            ),
                            if (focusMode.mode != FocusModeType.all)
                              Text(
                                focusMode.mode == FocusModeType.work 
                                    ? 'Рабочий режим' 
                                    : 'Личный режим',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: NiosPalette.accent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Focus Mode Toggle
                      FocusModeToggle(
                        mode: focusMode.mode,
                        onToggle: () {
                          ref.read(focusModeProvider.notifier).toggleMode();
                        },
                      ),
                      const SizedBox(width: 8),
                      TelegramIconButton(
                        icon: Icons.person_outline,
                        onPressed: () => widget.onOpenProfile(null),
                        size: 40,
                        tooltip: 'Профиль',
                      ),
                      const SizedBox(width: 4),
                      TelegramIconButton(
                        icon: Icons.add_circle_outline,
                        onPressed: widget.onCreateGroup,
                        size: 40,
                        tooltip: 'Создать группу',
                      ),
                      const SizedBox(width: 4),
                      TelegramIconButton(
                        icon: Icons.settings_outlined,
                        onPressed: widget.onOpenSettings,
                        size: 40,
                        tooltip: 'Настройки',
                      ),
                    ],
                  ),
                ),
              ),

              // Search bar
              Container(
                color: NiosPalette.surface,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Поиск',
                    filled: true,
                    fillColor: NiosPalette.surfaceAlt,
                    prefixIcon: Icon(Icons.search, color: NiosPalette.textSecondary, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    hintStyle: TextStyle(
                      color: NiosPalette.textTertiary,
                      fontSize: 16,
                    ),
                  ),
                  onChanged: (value) => setState(() => query = value),
                ),
              ),
              // Chat list with swipeable items
              Expanded(
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: reduceMotion ? 0 : 250),
                  switchInCurve: NiosAnimations.easeOutExpo,
                  switchOutCurve: NiosAnimations.easeInExpo,
                  child: loading
                      ? const Center(
                          key: ValueKey('loading'),
                          child: CircularProgressIndicator(),
                        )
                      : filteredChats.isEmpty
                          ? Center(
                              key: const ValueKey('empty'),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    focusMode.mode != FocusModeType.all
                                        ? Icons.work_off
                                        : Icons.chat_bubble_outline,
                                    size: 64,
                                    color: NiosPalette.textTertiary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    focusMode.mode != FocusModeType.all
                                        ? 'Нет чатов в этом режиме'
                                        : 'Нет чатов',
                                    style: TextStyle(
                                      color: NiosPalette.textSecondary,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              key: const ValueKey('list'),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: filteredChats.length,
                              itemBuilder: (_, i) {
                                final c = filteredChats[i];
                                final last = _lastMessages[c.id];
                                final subtitle = c.type == 'user'
                                    ? (c.isOnline == true
                                        ? 'в сети'
                                        : c.lastSeenText ?? 'не в сети')
                                    : c.type == 'group'
                                        ? 'Группа'
                                        : 'Канал';
                                final preview = last != null ? _previewText(last.text) : ((showStatus && showLastSeen) ? subtitle : '');
                                final timeText = last != null ? _formatMessageTime(last.time) : '';
                                final isOnline = c.isOnline == true && c.type == 'user';
                                final isRead = last?.isRead ?? true;
                                
                                return StaggeredListAnimation(
                                  index: i,
                                  delayMultiplier: reduceMotion ? 0 : 1,
                                  child: SwipeableChatItem(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      widget.onOpenChat(c);
                                    },
                                    onLongPress: () {
                                      // Ghost peek on long press
                                      ref.read(ghostModeProvider.notifier).activate();
                                      widget.onOpenChat(c);
                                    },
                                    onPin: () {
                                      HapticFeedback.mediumImpact();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('${c.name} закреплен'),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    onRead: () {
                                      HapticFeedback.lightImpact();
                                      // Mark as read logic
                                    },
                                    onMute: () {
                                      HapticFeedback.mediumImpact();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Уведомления от ${c.name} отключены'),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    onDelete: () {
                                      HapticFeedback.heavyImpact();
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Удалить чат?'),
                                          content: Text('Чат с ${c.name} будет удален из списка'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Отмена'),
                                            ),
                                            FilledButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                setState(() {
                                                  chats.removeWhere((chat) => chat.id == c.id);
                                                });
                                              },
                                              style: FilledButton.styleFrom(
                                                backgroundColor: Colors.red,
                                              ),
                                              child: const Text('Удалить'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    isPinned: c.isPinned,
                                    isRead: c.unread == 0,
                                    isMuted: false,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: compact ? 8 : 10,
                                      ),
                                      child: Row(
                                        children: [
                                          // Avatar with online indicator
                                          Stack(
                                            children: [
                                              _avatar(c, useHero: true),
                                              if (isOnline)
                                                const Positioned(
                                                  bottom: 0,
                                                  right: 0,
                                                  child: OnlineStatusIndicator(
                                                    isOnline: true,
                                                    size: 14,
                                                    borderWidth: 2,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(width: 12),
                                          // Chat info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        c.name,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 16,
                                                          color: NiosPalette.text,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (timeText.isNotEmpty) ...[
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        timeText,
                                                        style: TextStyle(
                                                          color: c.unread > 0 
                                                              ? NiosPalette.accent 
                                                              : NiosPalette.textTertiary,
                                                          fontSize: 12,
                                                          fontWeight: c.unread > 0 
                                                              ? FontWeight.w500 
                                                              : FontWeight.w400,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    // Read checks for outgoing messages
                                                    if (last != null && !isRead && last.isOutgoing)
                                                      Padding(
                                                        padding: const EdgeInsets.only(right: 4),
                                                        child: ReadChecks(
                                                          isRead: isRead,
                                                          size: 16,
                                                        ),
                                                      ),
                                                    Expanded(
                                                      child: Text(
                                                        preview,
                                                        style: TextStyle(
                                                          color: c.unread > 0 
                                                              ? NiosPalette.text 
                                                              : NiosPalette.textSecondary,
                                                          fontSize: 14,
                                                          fontWeight: c.unread > 0 
                                                              ? FontWeight.w500 
                                                              : FontWeight.w400,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (c.unread > 0) ...[
                                                      const SizedBox(width: 8),
                                                      MutedUnreadBadge(count: c.unread),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Badge
                                          if ((c.badgeText ?? c.badgeTitle ?? c.badgeIcon ?? '').isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 8),
                                              child: NiosBadge(
                                                tooltip: c.badgeText ??
                                                    c.badgeTitle ??
                                                    'Этот человек связан с разработкой напрямую или является спонсором NiosMess',
                                                icon: c.badgeIcon ?? '🦊',
                                                reduceMotion: reduceMotion,
                                                size: 18,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ),
              
              // Bottom Tab Bar (iOS style)
              Container(
                decoration: BoxDecoration(
                  color: NiosPalette.surface,
                  border: Border(
                    top: BorderSide(color: NiosPalette.border),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildTabItem(
                          icon: Icons.chat_bubble,
                          label: 'Чаты',
                          active: true,
                          onPressed: () {},
                        ),
                        _buildTabItem(
                          icon: Icons.contacts,
                          label: 'Контакты',
                          active: false,
                          onPressed: () => widget.onOpenProfile(null),
                        ),
                        _buildTabItem(
                          icon: Icons.call,
                          label: 'Звонки',
                          active: false,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Звонки скоро будут доступны')),
                            );
                          },
                        ),
                        _buildTabItem(
                          icon: Icons.settings,
                          label: 'Настройки',
                          active: false,
                          onPressed: widget.onOpenSettings,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Ghost Mode Indicator
          if (ghostMode.isActive)
            Positioned(
              top: 100,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.visibility_off,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Призрачный режим',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        ref.read(ghostModeProvider.notifier).deactivate();
                      },
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildTabItem({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: active ? NiosPalette.accent : NiosPalette.textSecondary,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? NiosPalette.accent : NiosPalette.textSecondary,
              fontSize: 11,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
