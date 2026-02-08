import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/chat_item.dart';
import '../../core/models/message_item.dart';
import '../../core/repositories/api_repository.dart';
import '../../core/session_provider.dart';
import '../../core/storage/offline_cache.dart';
import '../../core/obfuscate.dart';
import '../../core/settings_provider.dart';
import '../../ui/nios_ui.dart';

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

  Widget _avatar(ChatItem chat) {
    final fallback = Text(
      chat.name.isEmpty ? '?' : chat.name.characters.first.toUpperCase(),
      style: const TextStyle(fontWeight: FontWeight.w600),
    );
    if (chat.type != 'user') return fallback;
    final username = (chat.username ?? chat.id).trim();
    final bytes = _avatarCache[username];
    if (bytes != null && bytes.isNotEmpty) {
      return ClipOval(child: Image.memory(bytes, fit: BoxFit.cover));
    }
    _ensureAvatar(chat);
    return ClipOval(child: Center(child: fallback));
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
    final filtered = query.isEmpty
        ? chats
        : chats
            .where((c) =>
                c.name.toLowerCase().contains(query.toLowerCase()) ||
                c.id.toLowerCase().contains(query.toLowerCase()))
            .toList();

    return NiosScaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Чаты',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: NiosPalette.text,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => widget.onOpenProfile(null),
                  icon: Icon(Icons.person_outline, color: NiosPalette.textSecondary),
                ),
                IconButton(
                  onPressed: widget.onCreateGroup,
                  icon: Icon(Icons.add_circle_outline, color: NiosPalette.textSecondary),
                ),
                IconButton(
                  onPressed: widget.onOpenSettings,
                  icon: Icon(Icons.settings_outlined, color: NiosPalette.textSecondary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              decoration: niosInputDecoration('Поиск чатов', icon: Icons.search),
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: reduceMotion ? 0 : 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: loading
                  ? const Center(
                      key: ValueKey('loading'),
                      child: CircularProgressIndicator(),
                    )
                  : ListView.separated(
                      key: const ValueKey('list'),
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final c = filtered[i];
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
                        return InkWell(
                          onTap: () => widget.onOpenChat(c),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: EdgeInsets.all(compact ? 9 : 12),
                            decoration: BoxDecoration(
                              color: NiosPalette.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: NiosPalette.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: compact ? 40 : 46,
                                  height: compact ? 40 : 46,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: NiosPalette.surfaceHover,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: NiosPalette.borderLight),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: _avatar(c),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              c.name,
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          if ((c.badgeText ?? c.badgeTitle ?? c.badgeIcon ?? '').isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 6),
                                              child: NiosBadge(
                                                tooltip: c.badgeText ??
                                                    c.badgeTitle ??
                                                    'Этот человек связан с разработкой напрямую или является спонсором NiosMess',
                                                icon: c.badgeIcon ?? '🦊',
                                                reduceMotion: reduceMotion,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      if (preview.isNotEmpty)
                                        Text(
                                          preview,
                                          style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                if (timeText.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      timeText,
                                      style: TextStyle(color: NiosPalette.textSecondary, fontSize: 11),
                                    ),
                                  ),
                                if (c.unread > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: NiosPalette.accent,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      c.unread > 99 ? '99+' : c.unread.toString(),
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
