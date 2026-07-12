import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/providers/desktop_chat_provider.dart';
import 'package:pulse_flutter/providers/search_provider.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class ChatSearchField extends ConsumerStatefulWidget {
  const ChatSearchField({super.key});

  @override
  ConsumerState<ChatSearchField> createState() => _ChatSearchFieldState();
}

class _ChatSearchFieldState extends ConsumerState<ChatSearchField> {
  final SearchController _searchController = SearchController();
  String _query = '';
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      ref.read(chatListSearchProvider.notifier).clear();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(chatListSearchProvider.notifier).search(value);
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
    ref.read(chatListSearchProvider.notifier).clear();
  }

  void _openFirstMessageMatch(AsyncValue<ApiSearchResult> searchAsync) {
    final ApiSearchResult? result = searchAsync.asData?.value;
    if (result == null || result.messages.isEmpty) {
      return;
    }
    final ApiSearchMessage message = result.messages.first;
    if (MediaQuery.sizeOf(context).width >= 760) {
      ref.read(desktopSelectedChatProvider.notifier).setSelectedChat(message.chatId);
    } else {
      context.push('/chat/${message.chatId}?highlight=${message.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final query = _query.trim();
    final searchAsync = query.isEmpty
        ? const AsyncValue<ApiSearchResult>.data(ApiSearchResult.empty())
        : ref.watch(chatListSearchProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SearchBar(
          controller: _searchController,
          onChanged: _onSearchChanged,
          onSubmitted: (_) => _openFirstMessageMatch(searchAsync),
          hintText: context.l10n.chatListSearchMessagesHint,
          leading: const Icon(Icons.search_rounded),
          trailing: <Widget>[
            if (_query.isNotEmpty)
              IconButton(
                onPressed: _clearSearch,
                icon: const Icon(Icons.close_rounded),
                tooltip: context.l10n.commonCancel,
              )
            else
              const SizedBox.shrink(),
          ],
        ),
        _messageSearchPreview(searchAsync, scheme, textTheme),
      ],
    );
  }

  Widget _messageSearchPreview(
    AsyncValue<ApiSearchResult> searchAsync,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    if (_query.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: searchAsync.when(
        data: (ApiSearchResult result) {
          if (result.messages.isEmpty) {
            return const SizedBox.shrink();
          }
          final List<ApiSearchMessage> messages = result.messages
              .take(3)
              .toList(growable: false);
          return Padding(
            key: ValueKey<int>(messages.length),
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.manage_search_rounded,
                          size: 20,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.chatListMessageMatches,
                          style: textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${result.messages.length}',
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final ApiSearchMessage message in messages)
                    _messageResultTile(message, scheme, textTheme),
                ],
              ),
            ),
          );
        },
        loading: () => Padding(
          key: const ValueKey<String>('loading'),
          padding: const EdgeInsets.only(top: 10),
          child: const AppLoadingIndicator(size: 24),
        ),
        error: (_, _) => const SizedBox.shrink(key: ValueKey<String>('error')),
      ),
    );
  }

  Widget _messageResultTile(
    ApiSearchMessage message,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return InkWell(
      onTap: () {
        if (MediaQuery.sizeOf(context).width >= 760) {
          ref.read(desktopSelectedChatProvider.notifier).setSelectedChat(message.chatId);
        } else {
          context.push('/chat/${message.chatId}?highlight=${message.id}');
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 18,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    message.senderDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
