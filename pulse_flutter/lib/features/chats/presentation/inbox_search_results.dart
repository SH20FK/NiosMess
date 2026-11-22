import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/navigation/direct_chat_navigator.dart';
import 'package:pulse_flutter/core/platform/client_capabilities.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/features/chats/application/inbox_search_controller.dart';
import 'package:pulse_flutter/features/chats/presentation/saved_messages_search.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/desktop_chat_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/chat_productivity.dart'
    show openSavedMessages;
import 'package:pulse_flutter/widgets/common/touch_container.dart';
import 'package:pulse_flutter/widgets/empty_state_widget.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// Results of the in-inbox search, as one sliver for the chat list viewport.
///
/// Chats already on the device match instantly; people, other chats and
/// messages arrive with the server response.
class InboxSearchResults extends ConsumerWidget {
  const InboxSearchResults({super.key});

  void _openChat(BuildContext context, WidgetRef ref, int chatId) {
    // Same routing as a tap on an inbox row.
    if (ref.read(clientCapabilitiesProvider).browserWorkspace) {
      context.go('/main/chats?chat=$chatId');
    } else if (MediaQuery.sizeOf(context).width >= Breakpoints.medium) {
      ref.read(desktopSelectedChatProvider.notifier).setSelectedChat(chatId);
    } else {
      context.push('/chat/$chatId');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final InboxSearchState search = ref.watch(inboxSearchProvider);
    final String query = search.query;
    final String needle = query.toLowerCase();
    final List<ApiChatSummary> allChats =
        ref.watch(chatsProvider).value ?? const <ApiChatSummary>[];
    final identity = ref.watch(
      authProvider.select((AuthState s) => (s.session, s.profile)),
    );
    final session = identity.$1;
    final String ownUsername = (session?.username ?? '').toLowerCase();
    final bool matchesSaved =
        session != null &&
        matchesSavedMessagesQuery(
          query: query,
          username: session.username,
          displayName: identity.$2?.displayName ?? session.displayName,
          savedTitle: l10n.savedMessagesTitle,
        );
    final bool hasSavedChat = allChats.any((ApiChatSummary c) => c.isSaved);
    final bool haptics = ref.watch(
      uiSettingsProvider.select((UiSettingsState s) => s.haptics),
    );

    final InboxSearchScope scope = search.scope;
    final bool showChats =
        scope == InboxSearchScope.all || scope == InboxSearchScope.chats;
    final bool showPeople =
        scope == InboxSearchScope.all || scope == InboxSearchScope.people;
    final bool showMessages =
        scope == InboxSearchScope.all || scope == InboxSearchScope.messages;

    final Map<int, ApiChatSummary> known = <int, ApiChatSummary>{
      for (final ApiChatSummary c in allChats) c.id: c,
    };
    final List<_ChatHit> chatHits = <_ChatHit>[];
    if (showChats) {
      final Set<int> seen = <int>{};
      for (final ApiChatSummary c in allChats) {
        final bool hit =
            (c.isSaved && matchesSaved) ||
            c.name.toLowerCase().contains(needle) ||
            (c.username?.toLowerCase().contains(needle) ?? false) ||
            c.description.toLowerCase().contains(needle);
        if (hit && seen.add(c.id)) chatHits.add(_ChatHit.local(c));
      }
      for (final ApiSearchChat c
          in search.result?.chats ?? const <ApiSearchChat>[]) {
        // The self-chat is offered as "Saved Messages", never under the
        // account's own username.
        if (!hasSavedChat &&
            matchesSaved &&
            c.chatType == 'direct' &&
            ownUsername.isNotEmpty &&
            c.username?.toLowerCase() == ownUsername) {
          continue;
        }
        if (!seen.add(c.id)) continue;
        final ApiChatSummary? local = known[c.id];
        chatHits.add(
          local != null && local.isSaved
              ? _ChatHit.local(local)
              : _ChatHit.remote(c),
        );
      }
    }
    final bool savedShortcut = showChats && matchesSaved && !hasSavedChat;

    final List<ApiSearchUser> users = !showPeople
        ? const <ApiSearchUser>[]
        : <ApiSearchUser>[
            for (final ApiSearchUser u
                in search.result?.users ?? const <ApiSearchUser>[])
              if (u.id != session?.userId &&
                  (ownUsername.isEmpty ||
                      u.username.toLowerCase() != ownUsername))
                u,
          ];
    final List<ApiSearchMessage> messages = showMessages
        ? search.result?.messages ?? const <ApiSearchMessage>[]
        : const <ApiSearchMessage>[];

    if (chatHits.isEmpty && !savedShortcut && users.isEmpty && messages.isEmpty) {
      return SliverFillRemaining(
        child: search.loading
            ? const Center(child: AppLoadingIndicator(size: 32))
            : search.failed
            ? EmptyStateWidget(
                icon: Icons.cloud_off_rounded,
                iconColor: scheme.error,
                title: l10n.inboxSearchFailed,
                actionLabel: l10n.commonRetry,
                onAction: () => ref.read(inboxSearchProvider.notifier).retry(),
              )
            : EmptyStateWidget(
                icon: Icons.search_off_rounded,
                title: l10n.inboxSearchEmpty,
                subtitle: l10n.inboxSearchEmptyHint,
              ),
      );
    }

    String typeLabel(_ChatHit hit) => hit.isSaved
        ? l10n.savedMessagesSubtitle
        : switch (hit.type) {
            'channel' => l10n.groupTypeChannel,
            'group' => l10n.groupTypeGroup,
            _ => l10n.inboxSearchDirectChat,
          };

    final List<Widget> rows = <Widget>[
      if (chatHits.isNotEmpty || savedShortcut) ...<Widget>[
        _SectionHeader(l10n.tabChats),
        if (savedShortcut)
          _ResultRow(
            key: const ValueKey<String>('inbox-search-saved'),
            leading: const _IconAvatar(
              icon: Icons.bookmark_rounded,
              accent: true,
            ),
            title: l10n.savedMessagesTitle,
            subtitle: l10n.savedMessagesSubtitle,
            query: query,
            haptics: haptics,
            onTap: () => openSavedMessages(context, ref),
          ),
        for (final _ChatHit hit in chatHits)
          _ResultRow(
            key: ValueKey<String>('inbox-search-chat-${hit.id}'),
            leading: hit.isSaved
                ? const _IconAvatar(icon: Icons.bookmark_rounded, accent: true)
                : PulseAvatar(
                    name: hit.name,
                    id: hit.id.toString(),
                    avatarUrl: hit.avatarUrl,
                    radius: 22,
                  ),
            title: hit.isSaved ? l10n.savedMessagesTitle : hit.name,
            subtitle: typeLabel(hit),
            query: query,
            haptics: haptics,
            onTap: () => _openChat(context, ref, hit.id),
          ),
      ],
      if (users.isNotEmpty) ...<Widget>[
        _SectionHeader(l10n.inboxSearchPeople),
        for (final ApiSearchUser user in users)
          _ResultRow(
            key: ValueKey<String>('inbox-search-user-${user.id}'),
            leading: PulseAvatar(
              name: user.displayName.isNotEmpty
                  ? user.displayName
                  : user.username,
              avatarUrl: user.avatarUrl,
              radius: 22,
            ),
            title: user.displayName.isNotEmpty
                ? user.displayName
                : user.username,
            subtitle: '@${user.username}',
            query: query,
            haptics: haptics,
            onTap: () => navigateToDirectChat(
              context,
              ref,
              username: user.username,
              userId: user.id > 0 ? user.id : null,
            ),
          ),
      ],
      if (messages.isNotEmpty) ...<Widget>[
        _SectionHeader(l10n.noticeMessages),
        for (final ApiSearchMessage message in messages)
          _messageRow(context, message, known[message.chatId], query, haptics),
      ],
      if (search.loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: AppLoadingIndicator(size: 24),
        ),
    ];

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      sliver: SliverList.list(children: rows),
    );
  }

  Widget _messageRow(
    BuildContext context,
    ApiSearchMessage message,
    ApiChatSummary? chat,
    String query,
    bool haptics,
  ) {
    final l10n = context.l10n;
    final String title = chat == null
        ? (message.senderDisplayName.isNotEmpty
              ? message.senderDisplayName
              : l10n.inboxSearchMessage)
        : chat.isSaved
        ? l10n.savedMessagesTitle
        : chat.name;
    return _ResultRow(
      key: ValueKey<String>(
        'inbox-search-message-${message.chatId}-${message.id}',
      ),
      leading: chat == null
          ? const _IconAvatar(icon: Icons.chat_bubble_outline_rounded)
          : chat.isSaved
          ? const _IconAvatar(icon: Icons.bookmark_rounded, accent: true)
          : PulseAvatar(
              name: chat.name,
              id: chat.id.toString(),
              avatarUrl: chat.avatarUrl,
              radius: 22,
            ),
      title: title,
      subtitle: message.content,
      subtitleLines: 2,
      query: query,
      haptics: haptics,
      onTap: () => context.push(
        '/chat/${message.chatId}?highlight=${message.id}&source=search',
      ),
    );
  }
}

/// A chat match from the local inbox or from the server response.
class _ChatHit {
  _ChatHit.local(ApiChatSummary chat)
    : id = chat.id,
      name = chat.name,
      avatarUrl = chat.avatarUrl,
      type = chat.chatType,
      isSaved = chat.isSaved;

  _ChatHit.remote(ApiSearchChat chat)
    : id = chat.id,
      name = chat.name,
      avatarUrl = chat.avatarUrl,
      type = chat.chatType,
      isSaved = false;

  final int id;
  final String name;
  final String? avatarUrl;
  final String type;
  final bool isSaved;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      // 12 dp: the same text column as the avatars of the rows below.
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Semantics(
        header: true,
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// 44 dp tonal circle for rows without a photo.
class _IconAvatar extends StatelessWidget {
  const _IconAvatar({required this.icon, this.accent = false});

  final IconData icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 22,
          color: accent ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.query,
    required this.haptics,
    required this.onTap,
    this.subtitleLines = 1,
    super.key,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String query;
  final bool haptics;
  final VoidCallback onTap;
  final int subtitleLines;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextStyle titleStyle =
        (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        );
    final TextStyle subtitleStyle =
        (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
          color: scheme.onSurfaceVariant,
        );
    final TextStyle matchStyle = TextStyle(
      color: scheme.primary,
      fontWeight: FontWeight.w700,
    );

    return Semantics(
      button: true,
      label: subtitle.isEmpty ? title : '$title, $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: TouchContainer(
          onTap: onTap,
          enableHaptics: haptics,
          borderRadius: AppRadii.of(context).lgRadius,
          scaleDown: 0.98,
          releaseCurve: M3SpringCurves.spatialFast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text.rich(
                      TextSpan(children: _highlight(title, query, matchStyle)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                    if (subtitle.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: _highlight(subtitle, query, matchStyle),
                        ),
                        maxLines: subtitleLines,
                        overflow: TextOverflow.ellipsis,
                        style: subtitleStyle,
                      ),
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

/// Splits [text] into spans with every case-insensitive match of [query]
/// painted in [matchStyle].
List<TextSpan> _highlight(String text, String query, TextStyle matchStyle) {
  final String needle = (query.startsWith('@') ? query.substring(1) : query)
      .toLowerCase();
  final String haystack = text.toLowerCase();
  // Lower-casing can change the length of some scripts; offsets would drift.
  if (needle.isEmpty || haystack.length != text.length) {
    return <TextSpan>[TextSpan(text: text)];
  }
  final List<TextSpan> spans = <TextSpan>[];
  int start = 0;
  while (true) {
    final int index = haystack.indexOf(needle, start);
    if (index < 0) break;
    if (index > start) spans.add(TextSpan(text: text.substring(start, index)));
    spans.add(
      TextSpan(
        text: text.substring(index, index + needle.length),
        style: matchStyle,
      ),
    );
    start = index + needle.length;
  }
  if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
  return spans;
}
