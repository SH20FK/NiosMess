import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/navigation/direct_chat_navigator.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/repositories/search_repository.dart';
import 'package:pulse_flutter/widgets/empty_state_widget.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

enum InboxSearchScope {
  all,
  chats,
  messages,
  people,
}

class InboxSearchScreen extends ConsumerStatefulWidget {
  const InboxSearchScreen({super.key});

  @override
  ConsumerState<InboxSearchScreen> createState() => _InboxSearchScreenState();
}

class _InboxSearchScreenState extends ConsumerState<InboxSearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _queryFocus = FocusNode();

  InboxSearchScope _scope = InboxSearchScope.all;
  Timer? _debounce;
  int _generation = 0;

  bool _isLoading = false;
  ApiSearchResult? _searchResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final query = _queryController.text.trim();
    _debounce?.cancel();
    final int generation = ++_generation;

    if (query.isEmpty) {
      setState(() {
        _isLoading = false;
        _searchResult = null;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _debounce = Timer(const Duration(milliseconds: 220), () {
      _performSearch(query, generation);
    });
  }

  Future<void> _performSearch(String query, int generation) async {
    try {
      final repo = ref.read(searchRepositoryProvider);
      final result = await repo.search(query);
      if (generation != _generation || !mounted) return;

      setState(() {
        _searchResult = result;
        _isLoading = false;
      });
    } catch (e) {
      if (generation != _generation || !mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка при поиске: $e';
      });
    }
  }

  void _openMessage(ApiSearchMessage msg) {
    HapticService.tap();
    context.push('/chat/${msg.chatId}?highlight=${msg.id}&source=search');
  }

  void _openChat(int chatId) {
    HapticService.tap();
    context.push('/chat/$chatId');
  }

  void _openUser(ApiSearchUser user) {
    HapticService.tap();
    navigateToDirectChat(
      context,
      ref,
      username: user.username,
      userId: user.id > 0 ? user.id : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final query = _queryController.text.trim();
    final allChats = ref.watch(chatsProvider).value ?? <ApiChatSummary>[];

    // Local chat filtering for instant response
    final localMatchingChats = query.isEmpty
        ? <ApiChatSummary>[]
        : allChats.where((c) {
            final q = query.toLowerCase();
            return c.name.toLowerCase().contains(q) ||
                (c.username != null && c.username!.toLowerCase().contains(q)) ||
                c.description.toLowerCase().contains(q);
          }).toList(growable: false);

    final bool isWide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;

    Widget body = Column(
      children: <Widget>[
        // Scope Bar
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              _buildScopeChip(InboxSearchScope.all, 'Все', scheme),
              const SizedBox(width: 8),
              _buildScopeChip(InboxSearchScope.chats, 'Чаты', scheme),
              const SizedBox(width: 8),
              _buildScopeChip(InboxSearchScope.messages, 'Сообщения', scheme),
              const SizedBox(width: 8),
              _buildScopeChip(InboxSearchScope.people, 'Люди', scheme),
            ],
          ),
        ),
        const Divider(height: 1),

        // Main content
        Expanded(
          child: _isLoading
              ? const Center(child: AppLoadingIndicator(size: 32))
              : _errorMessage != null
                  ? Center(
                      child: EmptyStateWidget(
                        icon: Icons.error_outline_rounded,
                        title: 'Ошибка поиска',
                        subtitle: _errorMessage!,
                      ),
                    )
                  : query.isEmpty
                      ? _buildEmptyQuerySuggestions(scheme, textTheme)
                      : _buildSearchResults(
                          localMatchingChats,
                          _searchResult,
                          allChats,
                          scheme,
                          textTheme,
                        ),
        ),
      ],
    );

    if (isWide) {
      body = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            elevation: 0,
            color: scheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              side: BorderSide(
                color: scheme.outlineVariant,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              child: body,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _queryController,
          focusNode: _queryFocus,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Поиск по чатам, сообщениям и людям...',
            border: InputBorder.none,
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    onPressed: () {
                      _queryController.clear();
                    },
                  )
                : null,
          ),
        ),
      ),
      body: body,
    );
  }

  Widget _buildScopeChip(
    InboxSearchScope scope,
    String label,
    ColorScheme scheme,
  ) {
    final isSelected = _scope == scope;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (val) {
        if (val) {
          HapticService.selection();
          setState(() => _scope = scope);
        }
      },
      selectedColor: scheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.full),
        side: BorderSide(
          color: isSelected ? Colors.transparent : scheme.outlineVariant,
        ),
      ),
    );
  }

  Widget _buildEmptyQuerySuggestions(ColorScheme scheme, TextTheme textTheme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: <Widget>[
        Text(
          'Быстрый поиск',
          style: textTheme.titleSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            ActionChip(
              avatar: const Icon(Icons.mark_chat_unread_outlined, size: 16),
              label: const Text('Непрочитанные'),
              onPressed: () {
                _queryController.text = 'непрочитан';
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.groups_outlined, size: 16),
              label: const Text('Группы'),
              onPressed: () {
                setState(() => _scope = InboxSearchScope.chats);
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.campaign_outlined, size: 16),
              label: const Text('Каналы'),
              onPressed: () {
                setState(() => _scope = InboxSearchScope.chats);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchResults(
    List<ApiChatSummary> localChats,
    ApiSearchResult? serverResult,
    List<ApiChatSummary> allChats,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final matchingUsers = serverResult?.users ?? <ApiSearchUser>[];
    final matchingMessages = serverResult?.messages ?? <ApiSearchMessage>[];
    final serverChats = serverResult?.chats ?? <ApiSearchChat>[];

    // Combine local chats and server chats without duplicates
    final Set<int> seenChatIds = localChats.map((c) => c.id).toSet();
    final combinedChats = List<dynamic>.from(localChats);
    for (final sc in serverChats) {
      if (!seenChatIds.contains(sc.id)) {
        combinedChats.add(sc);
        seenChatIds.add(sc.id);
      }
    }

    final bool showChats = _scope == InboxSearchScope.all ||
        _scope == InboxSearchScope.chats;
    final bool showMessages = _scope == InboxSearchScope.all ||
        _scope == InboxSearchScope.messages;
    final bool showUsers = _scope == InboxSearchScope.all ||
        _scope == InboxSearchScope.people;

    final bool hasAny = (showChats && combinedChats.isNotEmpty) ||
        (showMessages && matchingMessages.isNotEmpty) ||
        (showUsers && matchingUsers.isNotEmpty);

    if (!hasAny) {
      return const Center(
        child: EmptyStateWidget(
          icon: Icons.search_off_rounded,
          title: 'Ничего не найдено',
          subtitle: 'Попробуйте изменить запрос или фильтр',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: <Widget>[
        // Users Section
        if (showUsers && matchingUsers.isNotEmpty) ...[
          _buildSectionHeader('Люди', scheme, textTheme),
          ...matchingUsers.map((user) => ListTile(
                leading: PulseAvatar(
                  avatarUrl: user.avatarUrl,
                  name: user.displayName,
                  radius: 20,
                ),
                title: Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '@${user.username}',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                onTap: () => _openUser(user),
              )),
          const SizedBox(height: 8),
        ],

        // Chats Section
        if (showChats && combinedChats.isNotEmpty) ...[
          _buildSectionHeader('Чаты', scheme, textTheme),
          ...combinedChats.map((c) {
            final String name = c is ApiChatSummary ? c.name : (c as ApiSearchChat).name;
            final String? avatar = c is ApiChatSummary ? c.avatarUrl : (c as ApiSearchChat).avatarUrl;
            final int id = c is ApiChatSummary ? c.id : (c as ApiSearchChat).id;
            final String type = c is ApiChatSummary ? c.chatType : (c as ApiSearchChat).chatType;

            return ListTile(
              leading: PulseAvatar(
                avatarUrl: avatar,
                name: name,
                radius: 20,
              ),
              title: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                type == 'channel'
                    ? 'Канал'
                    : type == 'group'
                        ? 'Группа'
                        : 'Личный чат',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              onTap: () => _openChat(id),
            );
          }),
          const SizedBox(height: 8),
        ],

        // Messages Section
        if (showMessages && matchingMessages.isNotEmpty) ...[
          _buildSectionHeader('Сообщения', scheme, textTheme),
          ...matchingMessages.map((msg) {
            final chat =
                allChats.where((c) => c.id == msg.chatId).firstOrNull;
            final chatTitle = chat?.name ??
                (msg.senderDisplayName.isNotEmpty
                    ? msg.senderDisplayName
                    : 'Сообщение');
            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              title: Text(
                chatTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                msg.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              onTap: () => _openMessage(msg),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 4),
      child: Text(
        title,
        style: textTheme.labelLarge?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
