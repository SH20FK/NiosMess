import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/search_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/centered_note.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_skeleton.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

enum _ContactsTab { recent, search }

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  _ContactsTab _tab = _ContactsTab.recent;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _openingUsername;
  int? _callingChatId;

  bool _isInitialLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() => _isInitialLoaded = true);
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ApiChatSummary> _recentDirectChats(List<ApiChatSummary> chats) {
    return chats
        .where((ApiChatSummary c) => c.chatType == 'direct')
        .toList(growable: false);
  }

  Future<void> _openDirectChat(String username) async {
    final String normalized = username.trim();
    if (normalized.isEmpty) return;

    setState(() => _openingUsername = normalized);
    try {
      final result = await ref
          .read(chatRepositoryProvider)
          .openDirectChatByUsername(normalized);
      if (result == null || result.chatId <= 0) {
        throw ApiException(
          statusCode: 0,
          message: 'Could not open direct chat',
        );
      }
      await ref.read(chatsProvider.notifier).refresh();
      if (!mounted) return;
      context.push('/chat/${result.chatId}');
    } catch (error) {
      if (!mounted) return;
      final String message = error is ApiException
          ? error.message
          : context.l10n.contactsFailedToOpenChat('$error');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _openingUsername = null);
    }
  }

  String _previewText(String? raw) {
    final String text = (raw ?? '').trim();
    if (text.isEmpty) return context.l10n.contactsNoMessagesYet;
    final Match? match = RegExp(r'^_fwd from\s+(.+?):').firstMatch(text);
    if (match != null) {
      return context.l10n.contactsForwardedFrom(match.group(1) ?? 'Unknown');
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final bool compact = settings.compactMode;
    final bool optimize = settings.optimizeForWeakDevices;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AsyncValue<List<ApiChatSummary>> chatsAsync = ref.watch(
      chatsProvider,
    );

    return RefreshIndicator(
      onRefresh: () async {
        if (_tab == _ContactsTab.recent) {
          await ref.read(chatsProvider.notifier).refresh();
        } else if (_query.trim().isNotEmpty) {
          ref.read(debouncedSearchProvider.notifier).search(_query.trim());
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: optimize
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: scheme.surface.withValues(alpha: 0.95),
                    child: Text(context.l10n.tabContacts),
                  )
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: scheme.surface.withValues(alpha: 0.6),
                      child: Text(context.l10n.tabContacts),
                    ),
                  ),
          ),
          centerTitle: false,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          slivers: <Widget>[
            SliverPadding(
              padding: EdgeInsets.only(
                top: MediaQuery.viewPaddingOf(context).top + kToolbarHeight,
              ),
            ),
            _headerSliver(context, textTheme, scheme),
            if (_tab == _ContactsTab.recent)
              ..._buildRecentSlivers(auth, chatsAsync, compact, textTheme, scheme)
            else
              ..._buildSearchSlivers(auth, compact, textTheme, scheme),
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: 16 + MediaQuery.viewPaddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
    );
}

  Widget _headerSliver(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme scheme,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.screenHorizontalPadding,
          12,
          AppConstants.screenHorizontalPadding,
          12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _tabChip(
                    context,
                    value: _ContactsTab.recent,
                    label: context.l10n.contactsRecent,
                    icon: Icons.history_rounded,
                  ),
                  const SizedBox(width: 8),
                  _tabChip(
                    context,
                    value: _ContactsTab.search,
                    label: context.l10n.contactsSearch,
                    icon: Icons.search_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRecentSlivers(
    AuthState auth,
    AsyncValue<List<ApiChatSummary>> chatsAsync,
    bool compact,
    TextTheme textTheme,
    ColorScheme scheme,
  ) {
    if (!auth.isAuthenticated) {
      return <Widget>[
        SliverFillRemaining(
          child: CenteredNote(context.l10n.contactsNotAuth),
        ),
      ];
    }
    return chatsAsync.when(
      data: (List<ApiChatSummary> chats) {
        final List<ApiChatSummary> direct = _recentDirectChats(chats);
        if (direct.isEmpty) {
          return <Widget>[
            SliverFillRemaining(
              child: CenteredNote(
                context.l10n.contactsNoRecentFull,
              ),
            ),
          ];
        }
        return <Widget>[
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenHorizontalPadding,
            ),
            sliver: SliverList.separated(
              itemCount: direct.length,
              itemBuilder: (BuildContext context, int index) {
                final ApiChatSummary chat = direct[index];
                final bool busy = _callingChatId == chat.id;

                final List<ApiBadge> badges = chat.partnerBadges
                    .take(2)
                    .toList(growable: false);
                final int hiddenBadgeCount =
                    chat.partnerBadges.length - badges.length;

                final Widget item = InkWell(
                  onTap: chat.username == null || chat.username!.isEmpty
                      ? () => context.push('/chat/${chat.id}')
                      : () => context.push('/contact/${chat.username}'),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: compact ? 10 : 13,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Hero(
                          tag: 'user-avatar-${chat.username}',
                          child: PulseAvatar(
                            radius: 22,
                            name: chat.name,
                            avatarUrl: chat.avatarUrl,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      chat.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.titleMedium,
                                    ),
                                  ),
                                  if (badges.isNotEmpty) ...<Widget>[
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Wrap(
                                        spacing: 4,
                                        runSpacing: 2,
                                        children: <Widget>[
                                          ...badges.map(
                                            (badge) => BadgeChip(
                                              id: badge.id,
                                              name: badge.name,
                                              icon: badge.icon,
                                              color: badge.color,
                                              interactive: false,
                                              mode: BadgeResolver.isStatusBadge(badge) ? BadgeDisplayMode.statusIcon : BadgeDisplayMode.infoLabel,
                                            ),
                                          ),
                                          if (hiddenBadgeCount > 0)
                                            BadgeOverflowChip(
                                              count: hiddenBadgeCount,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _previewText(chat.lastMessage?.content),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (busy)
                          AppLoadingIndicator(size: 20)
                        else ...<Widget>[
                          IconButton(
                            onPressed: () {
                              if (ref.read(uiSettingsProvider).haptics) HapticService.reaction();
                              context.push('/chat/${chat.id}');
                            },
                            icon: const Icon(Icons.chat_rounded),
                            tooltip: context.l10n.contactsMessage,
                            iconSize: 20,
                          ),
                        ],
                      ],
                    ),
                  ),
                );

                if (_isInitialLoaded) {
                  return RepaintBoundary(child: item);
                }

                final int delayMs = (index < 6) ? index * 35 : 0;
                return RepaintBoundary(child: item)
                    .animate()
                    .fade(duration: 250.ms, delay: delayMs.ms, curve: Curves.easeOutCubic)
                    .slideY(
                      begin: 0.06,
                      end: 0,
                      duration: 250.ms,
                      delay: delayMs.ms,
                      curve: Curves.easeOutCubic,
                    );
              },
              separatorBuilder: (_, _) => SizedBox(height: compact ? 8 : 10),
            ),
          ),
        ];
      },
      loading: () => const <Widget>[
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: AppConstants.screenHorizontalPadding,
          ),
          sliver: SliverToBoxAdapter(child: ChatListSkeleton(count: 4)),
        ),
      ],
      error: (Object error, StackTrace _) => <Widget>[
        SliverFillRemaining(child: CenteredNote(context.l10n.contactsFailedToLoad('$error'))),
      ],
    );
  }

  List<Widget> _buildSearchSlivers(
    AuthState auth,
    bool compact,
    TextTheme textTheme,
    ColorScheme scheme,
  ) {
    if (!auth.isAuthenticated) {
      return <Widget>[
        SliverFillRemaining(
          child: CenteredNote(context.l10n.contactsNotAuth),
        ),
      ];
    }

    final String query = _query.trim();
    final AsyncValue<ApiSearchResult> resultsAsync = query.isNotEmpty
        ? ref.watch(debouncedSearchProvider)
        : AsyncValue<ApiSearchResult>.data(const ApiSearchResult.empty());

    return <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.screenHorizontalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _searchController,
                onChanged: (String value) {
                  setState(() => _query = value);
                  ref.read(debouncedSearchProvider.notifier).search(value);
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: context.l10n.contactsSearchHint,
                  prefixIcon: const Icon(Icons.person_search_rounded),
                  suffixIcon: query.isEmpty
                      ? null
                       : IconButton(
                           onPressed: () {
                             if (ref.read(uiSettingsProvider).haptics) HapticService.reaction();
                             _searchController.clear();
                             setState(() => _query = '');
                             ref.read(debouncedSearchProvider.notifier).clear();
                           },
                           icon: const Icon(Icons.close_rounded),
                         ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      if (query.isEmpty)
        SliverFillRemaining(
          child: CenteredNote(
            context.l10n.contactsSearchEmpty,
          ),
        )
      else
        ..._buildSearchResultsSlivers(resultsAsync, compact, textTheme, scheme),
    ];
  }

  List<Widget> _buildSearchResultsSlivers(
    AsyncValue<ApiSearchResult> resultsAsync,
    bool compact,
    TextTheme textTheme,
    ColorScheme scheme,
  ) {
    return resultsAsync.when(
      data: (ApiSearchResult results) {
        if (results.isEmpty) {
          return <Widget>[
            SliverFillRemaining(child: CenteredNote(context.l10n.contactsNoMatches)),
          ];
        }

        final List<Widget> children = <Widget>[];

        if (results.users.isNotEmpty) {
          children.add(_resultHeader(context, context.l10n.contactsUsers, results.users.length));
          children.add(const SizedBox(height: 8));
          for (final ApiSearchUser user in results.users) {
            final bool opening = _openingUsername == user.username;
            children.add(_userTile(user, opening, compact, textTheme, scheme));
            children.add(SizedBox(height: compact ? 8 : 10));
          }
        }

        if (results.chats.isNotEmpty) {
          children.add(_resultHeader(context, context.l10n.contactsChats, results.chats.length));
          children.add(const SizedBox(height: 8));
          for (final ApiSearchChat chat in results.chats) {
            children.add(_chatTile(chat, textTheme, scheme));
            children.add(const SizedBox(height: 8));
          }
        }

        if (results.messages.isNotEmpty) {
          children.add(
            _resultHeader(context, context.l10n.contactsMessages, results.messages.length),
          );
          children.add(const SizedBox(height: 8));
          for (final ApiSearchMessage message in results.messages) {
            children.add(_messageTile(message, textTheme, scheme));
            children.add(const SizedBox(height: 8));
          }
        }

        if (children.isNotEmpty && children.last is SizedBox) {
          children.removeLast();
        }
        return <Widget>[
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenHorizontalPadding,
            ),
            sliver: SliverList(delegate: SliverChildListDelegate(children)),
          ),
        ];
      },
      loading: () => const <Widget>[
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: AppConstants.screenHorizontalPadding,
          ),
          sliver: SliverToBoxAdapter(child: ChatListSkeleton(count: 4)),
        ),
      ],
      error: (Object error, StackTrace _) => <Widget>[
        SliverFillRemaining(
          child: CenteredNote(
            error is ApiException ? error.message : context.l10n.contactsFailedToSearch('$error'),
          ),
        ),
      ],
    );
  }

  Widget _userTile(
    ApiSearchUser user,
    bool opening,
    bool compact,
    TextTheme textTheme,
    ColorScheme scheme,
  ) {
    final List<ApiBadge> visibleBadges = user.badges
        .take(3)
        .toList(growable: false);
    final int hiddenBadgeCount = user.badges.length - visibleBadges.length;

    return InkWell(
      onTap: () => context.push('/contact/${user.username}'),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: compact ? 10 : 13,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: <Widget>[
            PulseAvatar(
              radius: 24,
              name: user.displayName.isEmpty ? user.username : user.displayName,
              avatarUrl: user.avatarUrl,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          user.displayName.isEmpty
                              ? '@${user.username}'
                              : user.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium,
                        ),
                      ),
                      if (visibleBadges.isNotEmpty) ...<Widget>[
                        const SizedBox(width: 6),
                        Wrap(
                          spacing: 3,
                          children: <Widget>[
                            ...visibleBadges.map(
                              (badge) => BadgeChip(
                                id: badge.id,
                                name: badge.name,
                                icon: badge.icon,
                                color: badge.color,
                                interactive: false,
                              ),
                            ),
                            if (hiddenBadgeCount > 0)
                              BadgeOverflowChip(count: hiddenBadgeCount),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${user.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (user.bio.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      user.bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            opening
                ? const AppLoadingIndicator(size: 22)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        onPressed: user.username.isEmpty
                            ? null
                            : () {
                                if (ref.read(uiSettingsProvider).haptics) HapticService.reaction();
                                _openDirectChat(user.username);
                              },
                        icon: const Icon(Icons.chat_rounded),
                        tooltip: context.l10n.contactsChat,
                        iconSize: 20,
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _chatTile(
    ApiSearchChat chat,
    TextTheme textTheme,
    ColorScheme scheme,
  ) {
    return InkWell(
      onTap: () {
        if (ref.read(uiSettingsProvider).haptics) HapticService.reaction();
        context.push('/chat/${chat.id}');
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: <Widget>[
            PulseAvatar(
              radius: 18,
              name: chat.name,
              avatarUrl: chat.avatarUrl,
              fallbackColor: scheme.secondaryContainer,
              textColor: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(chat.name, style: textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    '@${chat.username ?? '-'} • ${context.l10n.contactsMembersCount(chat.membersCount)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageTile(
    ApiSearchMessage message,
    TextTheme textTheme,
    ColorScheme scheme,
  ) {
    return InkWell(
      onTap: () =>
          context.push('/chat/${message.chatId}?highlight=${message.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              message.senderDisplayName,
              style: textTheme.labelLarge?.copyWith(color: scheme.primary),
            ),
            const SizedBox(height: 3),
            Text(
              message.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabChip(
    BuildContext context, {
    required _ContactsTab value,
    required String label,
    required IconData icon,
  }) {
    final bool selected = value == _tab;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.78)
          : scheme.surfaceContainerLow.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () => setState(() => _tab = value),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: selected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultHeader(BuildContext context, String title, int count) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Row(
      children: <Widget>[
        Text(title, style: textTheme.titleMedium),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
