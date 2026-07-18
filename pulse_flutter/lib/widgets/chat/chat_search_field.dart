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
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
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

  void _openMessage(ApiSearchMessage msg) {
    _searchController.closeView('');
    ref.read(desktopSelectedChatProvider.notifier).setSelectedChat(msg.chatId);
    final router = GoRouter.of(context);
    final currentPath = router.routeInformationProvider.value.uri.path;
    if (!currentPath.startsWith('/chat/${msg.chatId}')) {
      context.push('/chat/${msg.chatId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SearchAnchor.bar(
      searchController: _searchController,
      barHintText: context.l10n.chatListSearchMessagesHint,
      barElevation: const WidgetStatePropertyAll<double>(0.0),
      barBackgroundColor: WidgetStatePropertyAll<Color>(scheme.surfaceContainerHigh),
      barShape: WidgetStatePropertyAll<OutlinedBorder>(RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
      barPadding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.symmetric(horizontal: 16)),
      suggestionsBuilder: (BuildContext context, SearchController controller) async {
        _onSearchChanged(controller.text);
        
        final query = controller.text.trim();
        if (query.isEmpty) {
          return const [
            Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Icon(Icons.search_rounded, size: 64, color: Colors.grey),
              ),
            )
          ];
        }

        await Future.delayed(const Duration(milliseconds: 350));
        final searchAsync = ref.read(chatListSearchProvider);
        
        return searchAsync.when(
          data: (ApiSearchResult result) {
            if (result.messages.isEmpty) {
              return [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      context.l10n.emptyStateNoItems,
                      style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              ];
            }
            
            return result.messages.map<Widget>((msg) => ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.message_rounded, color: scheme.onPrimaryContainer, size: 20),
              ),
              title: Text(
                msg.senderDisplayName,
                style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                msg.content,
                style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _openMessage(msg),
            )).toList();
          },
          loading: () => [
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: AppLoadingIndicator(size: 32)),
            )
          ],
          error: (e, _) => [
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text('Error: $e', style: TextStyle(color: scheme.error)),
              ),
            )
          ],
        );
      },
    );
  }
}
