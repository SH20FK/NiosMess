import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/chat_item.dart';
import '../../core/repositories/api_repository.dart';
import '../../core/session_provider.dart';

/// Global search modal (Ctrl+K) — searches contacts and messages across chats.
/// Shows as a centered dialog with auto-focus on the search field.
class GlobalSearchModal extends ConsumerStatefulWidget {
  final List<ChatItem> chats;
  final void Function(ChatItem chat) onChatSelected;

  const GlobalSearchModal({
    super.key,
    required this.chats,
    required this.onChatSelected,
  });

  @override
  ConsumerState<GlobalSearchModal> createState() => _GlobalSearchModalState();
}

class _GlobalSearchModalState extends ConsumerState<GlobalSearchModal> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _api = ApiRepository();

  Timer? _debounce;
  bool _loading = false;
  List<Map<String, dynamic>> _userResults = [];
  List<Map<String, dynamic>> _messageResults = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    final query = _controller.text.trim();
    if (query.length < 2) {
      setState(() {
        _userResults = [];
        _messageResults = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;

    final futures = <Future>[];

    // Search users
    futures.add(
      _api.searchUsers(query, session.username!, session.token!).then((res) {
        if (mounted) setState(() => _userResults = res);
      }).catchError((_) {}),
    );

    // Search messages in top-5 recent chats
    final topChats = widget.chats.take(5).toList();
    for (final chat in topChats) {
      futures.add(
        _api.searchMessages(
          chatId: chat.id,
          query: query,
          username: session.username!,
          token: session.token!,
          chatType: chat.type,
        ).then((res) {
          if (mounted) {
            setState(() {
              _messageResults.addAll(
                res.map((m) => <String, dynamic>{
                  ...m.toJson(),
                  '_chat_name': chat.name,
                  '_chat_id': chat.id,
                }),
              );
            });
          }
        }).catchError((_) {}),
      );
    }

    await Future.wait(futures);
    if (mounted) setState(() => _loading = false);
  }

  void _selectChat(ChatItem chat) {
    Navigator.of(context).pop();
    widget.onChatSelected(chat);
  }

  void _selectChatById(String chatId, String chatName) {
    final found = widget.chats.firstWhere(
      (c) => c.id == chatId,
      orElse: () => ChatItem(id: chatId, name: chatName, type: 'user', unread: 0),
    );
    _selectChat(found);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasResults = _userResults.isNotEmpty || _messageResults.isNotEmpty;
    final query = _controller.text.trim();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 100),
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search field
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Глобальный поиск...',
                    prefixIcon: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.search),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _controller.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) {
                    if (_userResults.isNotEmpty) {
                      final u = _userResults.first;
                      _selectChatById(u['username']?.toString() ?? '', u['name']?.toString() ?? '');
                    }
                  },
                ),
              ),
              // Hint when empty
              if (query.length < 2 && !hasResults)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Введите минимум 2 символа',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              // Results
              if (hasResults)
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    children: [
                      if (_userResults.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Text(
                            'КОНТАКТЫ',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                          ),
                        ),
                        ...(_userResults.take(5).map((u) {
                          final name = u['name']?.toString() ?? u['username']?.toString() ?? '?';
                          final uname = u['username']?.toString() ?? '';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: colorScheme.primaryContainer,
                              child: Text(name.characters.first.toUpperCase()),
                            ),
                            title: Text(name),
                            subtitle: uname.isNotEmpty ? Text('@$uname') : null,
                            onTap: () => _selectChatById(uname, name),
                          );
                        })),
                      ],
                      if (_messageResults.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            'СООБЩЕНИЯ',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                          ),
                        ),
                        ...(_messageResults.take(8).map((m) {
                          final text = m['text']?.toString() ?? '';
                          final chatName = m['_chat_name']?.toString() ?? '';
                          final chatId = m['_chat_id']?.toString() ?? '';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: colorScheme.secondaryContainer,
                              child: const Icon(Icons.chat_bubble_outline, size: 18),
                            ),
                            title: Text(chatName),
                            subtitle: Text(
                              text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _selectChatById(chatId, chatName),
                          );
                        })),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
