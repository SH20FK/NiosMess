import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/desktop_chat_provider.dart';
import 'package:pulse_flutter/providers/search_provider.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

enum SearchCategory { all, users, chats, messages, posts }

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
  SearchCategory _selectedCategory = SearchCategory.all;

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

  String? _extractInviteSlug(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final RegExp uPlusRegex = RegExp(r'(?:/u/\+|ni-os\.ru/u/\+|^u/\+)(\+?[A-Za-z0-9_-]+)');
    final RegExpMatch? match = uPlusRegex.firstMatch(trimmed);
    if (match != null) {
      final String slug = match.group(1)!;
      return slug.startsWith('+') ? slug : '+$slug';
    }

    if (RegExp(r'^\+[A-Za-z0-9_-]{4,}$').hasMatch(trimmed)) {
      return trimmed;
    }

    final int joinIdx = trimmed.indexOf('/join/');
    if (joinIdx != -1) {
      final String part =
          trimmed.substring(joinIdx + 6).split('?').first.split('/').first.trim();
      if (part.isNotEmpty) return part;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final String displayName = ref.watch(
      authProvider.select(
        (a) => a.profile?.displayName ?? a.session?.displayName ?? 'Me',
      ),
    );
    final String? avatarUrl = ref.watch(
      authProvider.select((a) => a.profile?.avatarUrl),
    );

    return SearchAnchor.bar(
      isFullScreen: false,
      viewConstraints: const BoxConstraints(
        minHeight: 120,
        maxHeight: 480,
      ),
      viewShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      viewBackgroundColor: scheme.surfaceContainerHigh,
      viewElevation: 4.0,
      dividerColor: scheme.outlineVariant.withValues(alpha: 0.25),
      searchController: _searchController,
      barHintText: widget.hintText ?? context.l10n.chatListSearchMessagesHint,
      viewHintText: widget.hintText ?? context.l10n.chatListSearchMessagesHint,
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
      viewTrailing: <Widget>[
        IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Закрыть',
          onPressed: () {
            _searchController.closeView('');
          },
        ),
      ],
      suggestionsBuilder:
          (BuildContext context, SearchController controller) {
        _onSearchChanged(controller.text);

        final String query = controller.text.trim();
        if (query.isEmpty) {
          return <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.search_rounded,
                      size: 48,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.hintText ?? context.l10n.chatListSearchMessagesHint,
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
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setChipState) {
              Widget buildChip(SearchCategory cat, String label) {
                final bool isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(label),
                    onSelected: (_) {
                      setChipState(() {
                        _selectedCategory = cat;
                      });
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                  ),
                );
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: <Widget>[
                    buildChip(SearchCategory.all, 'Все'),
                    buildChip(SearchCategory.users, 'Люди'),
                    buildChip(SearchCategory.chats, 'Чаты'),
                    buildChip(SearchCategory.messages, 'Сообщения'),
                    buildChip(SearchCategory.posts, 'Посты'),
                  ],
                ),
              );
            },
          ),
          Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              final AsyncValue<ApiSearchResult> searchAsync =
                  ref.watch(chatListSearchProvider);

              return searchAsync.when(
                data: (ApiSearchResult result) {
                  final List<Widget> resultsList = <Widget>[];

                  final bool showChats =
                      (_selectedCategory == SearchCategory.all ||
                              _selectedCategory == SearchCategory.chats) &&
                          result.chats.isNotEmpty;
                  final bool showUsers =
                      (_selectedCategory == SearchCategory.all ||
                              _selectedCategory == SearchCategory.users) &&
                          result.users.isNotEmpty;
                  final bool showMessages =
                      (_selectedCategory == SearchCategory.all ||
                              _selectedCategory == SearchCategory.messages) &&
                          result.messages.isNotEmpty;
                  final bool showPosts =
                      (_selectedCategory == SearchCategory.all ||
                              _selectedCategory == SearchCategory.posts) &&
                          result.posts.isNotEmpty;

                  final String? inviteSlug = _extractInviteSlug(query);
                  final String trimmedQuery = query.trim();
                  final bool isExplicitUsername = trimmedQuery.startsWith('@');
                  final String cleanUsername =
                      isExplicitUsername ? trimmedQuery.substring(1) : trimmedQuery;
                  final bool isValidUsername = cleanUsername.length >= 3 &&
                      cleanUsername.length <= 32 &&
                      RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(cleanUsername);

                  Widget? inviteTile;
                  if (inviteSlug != null && inviteSlug.isNotEmpty) {
                    inviteTile = Container(
                      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.link_rounded,
                            color: scheme.onPrimary,
                            size: 22,
                          ),
                        ),
                        title: const Text(
                          'Вступить по ссылке-приглашению',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Код: $inviteSlug',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_rounded,
                          color: scheme.primary,
                          size: 20,
                        ),
                        onTap: () {
                          HapticService.tap();
                          controller.closeView('');
                          context.push(
                            '/join?slug=${Uri.encodeComponent(inviteSlug)}',
                          );
                        },
                      ),
                    );
                  }

                  Widget? directUserTile;
                  if (isValidUsername &&
                      (isExplicitUsername ||
                          result.users.every((u) =>
                              u.username.toLowerCase() !=
                              cleanUsername.toLowerCase()))) {
                    directUserTile = Container(
                      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.20),
                        ),
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.person_add_alt_1_rounded,
                            color: scheme.onSecondaryContainer,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Написать @$cleanUsername',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: const Text(
                          'Открыть личный диалог',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                          size: 20,
                        ),
                        onTap: () {
                          HapticService.tap();
                          controller.closeView('');
                          context.push(
                            '/chat/dm/${Uri.encodeComponent(cleanUsername)}',
                          );
                        },
                      ),
                    );
                  }

                  if (inviteTile != null) resultsList.add(inviteTile);
                  if (directUserTile != null) resultsList.add(directUserTile);

                  if (!showChats &&
                      !showUsers &&
                      !showMessages &&
                      !showPosts &&
                      resultsList.isEmpty) {
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

                  if (showChats) {
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

                  if (showUsers) {
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
                            HapticService.tap();
                            final String uname = user.username.trim();
                            if (uname.isNotEmpty) {
                              context.push(
                                '/chat/dm/${Uri.encodeComponent(uname)}',
                              );
                            } else {
                              context.push(
                                '/chat/dm/${user.id}?userId=${user.id}',
                              );
                            }
                          },
                        ),
                      );
                    }
                  }

                  if (showMessages) {
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

                  if (showPosts) {
                    resultsList.add(
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          'Посты',
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );

                    for (final NgPost post in result.posts) {
                      resultsList.add(
                        ListTile(
                          leading: PulseAvatar(
                            radius: 20,
                            name: post.author.displayName.isNotEmpty
                                ? post.author.displayName
                                : post.author.username,
                            avatarUrl: post.author.avatarUrl,
                            fallbackColor: scheme.secondary,
                            textColor: scheme.onSecondary,
                          ),
                          title: Text(
                            post.author.displayName.isNotEmpty
                                ? post.author.displayName
                                : '@${post.author.username}',
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            post.content,
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: (post.mediaUrls.isNotEmpty ||
                                  post.mediaUrl != null)
                              ? Icon(
                                  post.isVideo
                                      ? Icons.videocam_rounded
                                      : Icons.image_rounded,
                                  size: 20,
                                  color: scheme.onSurfaceVariant,
                                )
                              : null,
                          onTap: () {
                            controller.closeView('');
                            context.push(
                              '/niosgram/post/${post.id}/comments',
                            );
                          },
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
