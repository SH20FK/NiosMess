import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/api_repository.dart';
import '../../core/session_provider.dart';
import '../../ui/nios_ui.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final api = ApiRepository();
  final nameController = TextEditingController();
  final descController = TextEditingController();
  final searchController = TextEditingController();
  bool isChannel = false;
  bool loading = false;
  String? error;

  // Selected members
  final List<_UserEntry> _selectedMembers = [];

  // Search results
  List<_UserEntry> _searchResults = [];
  bool _searching = false;
  Timer? _searchTimer;

  // Recent chats as suggestions
  List<_UserEntry> _suggestions = [];
  bool _loadingSuggestions = true;

  // Invite link
  String? _inviteLink;
  bool _createdGroupId = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    try {
      final chats = await api.getChats(session.username!, session.token!);
      final users = chats
          .where((c) => c.type == 'user' || c.type.isEmpty)
          .map((c) => _UserEntry(
                username: c.username ?? c.id,
                name: c.name,
                isOnline: c.isOnline ?? false,
              ))
          .toList();
      if (mounted) {
        setState(() {
          _suggestions = users;
          _loadingSuggestions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchTimer = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    try {
      final results = await api.searchUsers(query, session.username!, session.token!);
      if (mounted) {
        setState(() {
          _searchResults = results
              .map((e) => _UserEntry(
                    username: e['username']?.toString() ?? '',
                    name: e['name']?.toString(),
                    isOnline: e['isonline'] == true,
                  ))
              .where((e) => e.username.isNotEmpty)
              .toList();
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _toggleMember(_UserEntry user) {
    setState(() {
      final idx = _selectedMembers.indexWhere((m) => m.username == user.username);
      if (idx >= 0) {
        _selectedMembers.removeAt(idx);
      } else {
        _selectedMembers.add(user);
      }
    });
  }

  bool _isSelected(String username) {
    return _selectedMembers.any((m) => m.username == username);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayList = searchController.text.trim().isNotEmpty
        ? _searchResults
        : _suggestions;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(isChannel ? 'Новый канал' : 'Новая группа'),
        actions: [
          if (loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _submit,
              child: const Text('Создать', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Type selector + name section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type toggle
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Группа'),
                      icon: Icon(Icons.group_outlined),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Канал'),
                      icon: Icon(Icons.campaign_outlined),
                    ),
                  ],
                  selected: {isChannel},
                  onSelectionChanged: (value) =>
                      setState(() => isChannel = value.first),
                  style: SegmentedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Name field
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Название',
                    prefixIcon: Icon(
                      isChannel ? Icons.campaign_outlined : Icons.group_outlined,
                      color: scheme.primary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Description (collapsed)
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Описание (необязательно)',
                    prefixIcon: Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                if (error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      error!,
                      style: TextStyle(color: scheme.onErrorContainer, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Selected members chips
          if (_selectedMembers.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _selectedMembers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final member = _selectedMembers[i];
                  return InputChip(
                    avatar: CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      child: Text(
                        (member.name ?? member.username).substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    label: Text(member.name ?? member.username),
                    onDeleted: () => _toggleMember(member),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                },
              ),
            ),

          if (_selectedMembers.isNotEmpty) const SizedBox(height: 8),

          // Divider + member count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.people_outline, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Добавить участников',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (_selectedMembers.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_selectedMembers.length}',
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Поиск пользователей...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _searching = false;
                          });
                        },
                        icon: const Icon(Icons.close),
                      )
                    : null,
                filled: true,
                fillColor: scheme.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // User list
          Expanded(
            child: Column(
              children: [
                if (_searching || _loadingSuggestions)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: displayList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_search_outlined,
                                size: 48,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                searchController.text.isNotEmpty
                                    ? 'Пользователи не найдены'
                                    : 'Нет контактов',
                                style: TextStyle(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: displayList.length,
                          itemBuilder: (_, i) {
                            final user = displayList[i];
                            final selected = _isSelected(user.username);
                            return ListTile(
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: selected
                                        ? scheme.primary
                                        : scheme.surfaceVariant,
                                    child: selected
                                        ? Icon(Icons.check,
                                            color: scheme.onPrimary, size: 20)
                                        : Text(
                                            (user.name ?? user.username)
                                                .substring(0, 1)
                                                .toUpperCase(),
                                            style: TextStyle(
                                              color: scheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                  if (user.isOnline)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: scheme.tertiary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: scheme.surface,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(
                                user.name ?? user.username,
                                style: TextStyle(
                                  fontWeight:
                                      selected ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                              subtitle: Text(
                                '@${user.username}',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              trailing: selected
                                  ? Icon(Icons.check_circle, color: scheme.primary)
                                  : Icon(Icons.circle_outlined,
                                      color: scheme.outlineVariant),
                              onTap: () => _toggleMember(user),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    final name = nameController.text.trim();
    if (name.isEmpty) {
      setState(() => error = 'Введите название');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await api.createCollective(
        name: name,
        owner: session.username!,
        token: session.token!,
        isChannel: isChannel,
      );
      final chatId = result['chat_id']?.toString();
      final members = _selectedMembers.map((m) => m.username).toList();
      if (chatId != null && chatId.isNotEmpty && members.isNotEmpty) {
        await api.updateMembers(
          chatId: chatId,
          operator: session.username!,
          token: session.token!,
          members: members,
          isChannel: isChannel,
        );
      }

      // Generate invite link
      final inviteLink = chatId != null
          ? 'niosmess://join/$chatId'
          : null;

      if (!mounted) return;

      // Show success with invite link
      if (inviteLink != null) {
        await showModalBottomSheet(
          context: context,
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _InviteLinkSheet(
            link: inviteLink,
            isChannel: isChannel,
          ),
        );
      }

      if (!mounted) return;
      widget.onBack();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isChannel ? 'Канал создан' : 'Группа создана'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      setState(() => error = 'Не удалось создать чат');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class _UserEntry {
  final String username;
  final String? name;
  final bool isOnline;

  const _UserEntry({
    required this.username,
    this.name,
    this.isOnline = false,
  });
}

class _InviteLinkSheet extends StatelessWidget {
  final String link;
  final bool isChannel;

  const _InviteLinkSheet({required this.link, required this.isChannel});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Success icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              size: 32,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            isChannel ? 'Канал создан!' : 'Группа создана!',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Поделитесь ссылкой-приглашением',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // Link row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.link, color: scheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    link,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: link));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ссылка скопирована'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: Icon(Icons.copy, color: scheme.primary, size: 20),
                  tooltip: 'Копировать',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Share button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: link));
                Navigator.pop(context);
              },
              icon: const Icon(Icons.share),
              label: const Text('Поделиться ссылкой'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }
}
