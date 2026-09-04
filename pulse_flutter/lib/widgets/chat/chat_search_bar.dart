import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/desktop_chat_provider.dart';
import 'package:pulse_flutter/providers/search_provider.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// Android 15 / Google Messages floating search bar with 28dp pill radius,
/// tonal elevation, and embedded profile avatar shortcut.
class ChatSearchBar extends ConsumerStatefulWidget {
  const ChatSearchBar({
    super.key,
    this.onAvatarTap,
    this.hintText,
    this.controller,
    this.onQueryChanged,
    this.onMessageSelected,
  });

  final VoidCallback? onAvatarTap;
  final String? hintText;
  final SearchController? controller;
  final ValueChanged<String>? onQueryChanged;
  final ValueChanged<ApiSearchMessage>? onMessageSelected;

  @override
  ConsumerState<ChatSearchBar> createState() => _ChatSearchBarState();
}

class _ChatSearchBarState extends ConsumerState<ChatSearchBar> {
  late final SearchController _searchController;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController = widget.controller ?? SearchController();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    if (widget.controller == null) {
      _searchController.dispose();
    }
    super.dispose();
  }

  void _onSearchChanged(String value) {
    widget.onQueryChanged?.call(value);
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      ref.read(chatListSearchProvider.notifier).clear();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        ref.read(chatListSearchProvider.notifier).search(value);
      }
    });
  }

  void _openMessage(ApiSearchMessage msg) {
    if (widget.onMessageSelected != null) {
      widget.onMessageSelected!(msg);
      _searchController.closeView('');
      return;
    }
    _searchController.closeView('');
    ref.read(desktopSelectedChatProvider.notifier).setSelectedChat(msg.chatId);
    final router = GoRouter.of(context);
    final currentPath = router.routeInformationProvider.value.uri.path;
    if (!currentPath.startsWith('/chat/${msg.chatId}')) {
      context.push('/chat/${msg.chatId}');
    }
  }

  void _handleAvatarTap() {
    HapticService.tap();
    if (widget.onAvatarTap != null) {
      widget.onAvatarTap!();
    } else {
      context.push('/main/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final authState = ref.watch(authProvider);
    final profile = authState.profile;
    final session = authState.session;
    final String displayName =
        profile?.displayName ?? session?.displayName ?? 'Me';
    final String? avatarUrl = profile?.avatarUrl;

    return SearchAnchor.bar(
      searchController: _searchController,
      barHintText: widget.hintText ?? context.l10n.chatListSearchMessagesHint,
      barElevation: const WidgetStatePropertyAll<double>(0.0),
      barBackgroundColor:
          WidgetStatePropertyAll<Color>(scheme.surfaceContainerHigh),
      barShape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      barPadding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      ),
      barLeading: Icon(
        Icons.search_rounded,
        color: scheme.onSurfaceVariant,
        size: 24,
      ),
      barTrailing: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleAvatarTap,
          child: Padding(
            padding: const EdgeInsets.only(left: 4, right: 2),
            child: Tooltip(
              message: context.l10n.tabProfile,
              child: PulseAvatar(
                radius: 15,
                name: displayName,
                avatarUrl: avatarUrl,
                fallbackColor: scheme.primary,
                textColor: scheme.onPrimary,
              ),
            ),
          ),
        ),
      ],
      suggestionsBuilder:
          (BuildContext context, SearchController controller) {
        _onSearchChanged(controller.text);

        final String query = controller.text.trim();
        if (query.isEmpty) {
          return <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.search_rounded,
                      size: 56,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.chatListSearchMessagesHint,
                      style: textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ];
        }

        return <Widget>[
          Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              final AsyncValue<ApiSearchResult> searchAsync =
                  ref.watch(chatListSearchProvider);

              return searchAsync.when(
                data: (ApiSearchResult result) {
                  if (result.messages.isEmpty &&
                      result.chats.isEmpty &&
                      result.users.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          context.l10n.emptyStateNoItems,
                          style: textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }

                  final List<Widget> resultsList = <Widget>[];

                  if (result.chats.isNotEmpty) {
                    resultsList.add(
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          context.l10n.tabChats,
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );

                    for (final ApiSearchChat chat in result.chats) {
                      resultsList.add(
                        ListTile(
                          leading: PulseAvatar(
                            radius: 20,
                            name: chat.name,
                            avatarUrl: chat.avatarUrl,
                            fallbackColor: scheme.secondary,
                            textColor: scheme.onSecondary,
                          ),
                          title: Text(
                            chat.name,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: chat.username != null
                              ? Text(
                                  '@${chat.username}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          onTap: () {
                            controller.closeView('');
                            ref
                                .read(desktopSelectedChatProvider.notifier)
                                .setSelectedChat(chat.id);
                            final GoRouter router = GoRouter.of(context);
                            final String currentPath =
                                router.routeInformationProvider.value.uri.path;
                            if (!currentPath.startsWith('/chat/${chat.id}')) {
                              context.push('/chat/${chat.id}');
                            }
                          },
                        ),
                      );
                    }
                  }

                  if (result.users.isNotEmpty) {
                    resultsList.add(
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          context.l10n.tabContacts,
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );

                    for (final ApiSearchUser user in result.users) {
                      resultsList.add(
                        ListTile(
                          leading: PulseAvatar(
                            radius: 20,
                            name: user.displayName.isNotEmpty
                                ? user.displayName
                                : user.username,
                            avatarUrl: user.avatarUrl,
                            fallbackColor: scheme.tertiary,
                            textColor: scheme.onTertiary,
                          ),
                          title: Text(
                            user.displayName.isNotEmpty
                                ? user.displayName
                                : user.username,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: user.username.isNotEmpty
                              ? Text(
                                  '@${user.username}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          onTap: () {
                            controller.closeView('');
                            ref
                                .read(desktopSelectedChatProvider.notifier)
                                .setSelectedChat(user.id);
                            final GoRouter router = GoRouter.of(context);
                            final String currentPath =
                                router.routeInformationProvider.value.uri.path;
                            if (!currentPath.startsWith('/chat/${user.id}')) {
                              context.push('/chat/${user.id}');
                            }
                          },
                        ),
                      );
                    }
                  }

                  if (result.messages.isNotEmpty) {
                    resultsList.add(
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          context.l10n.chatListMessageMatches,
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );

                    for (final ApiSearchMessage msg in result.messages) {
                      resultsList.add(
                        ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.message_rounded,
                              color: scheme.onPrimaryContainer,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            msg.senderDisplayName,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            msg.content,
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _openMessage(msg),
                        ),
                      );
                    }
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: resultsList,
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: AppLoadingIndicator(size: 32)),
                ),
                error: (Object e, _) => Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      context.l10n.commonFailed(e),
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                ),
              );
            },
          ),
        ];
      },
    );
  }
}
