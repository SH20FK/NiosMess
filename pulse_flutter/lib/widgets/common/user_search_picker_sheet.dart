import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/search_provider.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// Shows an expressive Material 3 bottom sheet for finding and picking a user
/// by @username or display name with live search suggestions.
Future<ApiSearchUser?> showUserSearchPickerSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? hintText,
  Set<int>? excludedUserIds,
  bool allowCustomUsername = false,
}) {
  return AppBottomSheets.show<ApiSearchUser>(
    context: context,
    builder: (BuildContext ctx) {
      return UserSearchPickerSheet(
        title: title,
        subtitle: subtitle,
        hintText: hintText,
        excludedUserIds: excludedUserIds,
        allowCustomUsername: allowCustomUsername,
      );
    },
  );
}

class UserSearchPickerSheet extends ConsumerStatefulWidget {
  const UserSearchPickerSheet({
    required this.title,
    this.subtitle,
    this.hintText,
    this.excludedUserIds,
    this.allowCustomUsername = false,
    super.key,
  });

  static Future<ApiSearchUser?> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? hintText,
    Set<int>? excludedUserIds,
    bool allowCustomUsername = false,
    void Function(ApiSearchUser user)? onUserSelected,
  }) async {
    final ApiSearchUser? picked = await showUserSearchPickerSheet(
      context,
      title: title,
      subtitle: subtitle,
      hintText: hintText,
      excludedUserIds: excludedUserIds,
      allowCustomUsername: allowCustomUsername,
    );
    if (picked != null && onUserSelected != null) {
      onUserSelected(picked);
    }
    return picked;
  }

  final String title;
  final String? subtitle;
  final String? hintText;
  final Set<int>? excludedUserIds;
  final bool allowCustomUsername;

  @override
  ConsumerState<UserSearchPickerSheet> createState() =>
      _UserSearchPickerSheetState();
}

class _UserSearchPickerSheetState extends ConsumerState<UserSearchPickerSheet> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onSearchChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final String clean = _controller.text.trim();
    if (clean != _query) {
      setState(() => _query = clean);
      final String searchQuery =
          clean.startsWith('@') ? clean.substring(1) : clean;
      ref.read(debouncedSearchProvider.notifier).search(searchQuery);
    }
  }

  void _selectUser(ApiSearchUser user) {
    HapticService.tap();
    Navigator.of(context).pop(user);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final chatsAsync = ref.watch(chatsProvider);
    final List<ApiChatSummary> directChats = (chatsAsync.value ?? const [])
        .where((c) => c.chatType == 'direct' && c.username != null)
        .toList(growable: false);

    final AsyncValue<ApiSearchResult> searchAsync =
        ref.watch(debouncedSearchProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Field
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: widget.hintText ??
                  context.l10n.chatMembersSearchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _controller.clear();
                        ref.read(debouncedSearchProvider.notifier).clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Results or Contacts
          Flexible(
            child: _query.isEmpty
                ? _buildRecentContacts(directChats, scheme, textTheme)
                : _buildSearchResults(searchAsync, scheme, textTheme),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildRecentContacts(
    List<ApiChatSummary> directChats,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final List<ApiChatSummary> filtered = directChats.where((c) {
      if (widget.excludedUserIds != null &&
          widget.excludedUserIds!.contains(c.id)) {
        return false;
      }
      return true;
    }).toList(growable: false);

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.person_search_rounded,
              size: 48,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Введите @username для поиска',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Недавние контакты',
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
            itemBuilder: (BuildContext context, int index) {
              final ApiChatSummary chat = filtered[index];
              final ApiSearchUser user = ApiSearchUser(
                id: chat.id,
                username: chat.username ?? '',
                displayName: chat.name,
                avatarUrl: chat.avatarUrl,
                bio: chat.description,
                badges: chat.partnerBadges,
              );
              return _buildUserTile(user, scheme, textTheme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(
    AsyncValue<ApiSearchResult> searchAsync,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return searchAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: AppLoadingIndicator(),
      ),
      error: (Object e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Center(
          child: Text(
            'Ошибка поиска: $e',
            style: textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ),
      ),
      data: (ApiSearchResult result) {
        final List<ApiSearchUser> users = result.users.where((u) {
          if (widget.excludedUserIds != null &&
              widget.excludedUserIds!.contains(u.id)) {
            return false;
          }
          return true;
        }).toList(growable: false);

        final String cleanQuery =
            _query.startsWith('@') ? _query.substring(1) : _query;
        final bool showDirect =
            widget.allowCustomUsername && cleanQuery.isNotEmpty;

        if (users.isEmpty && !showDirect) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.search_off_rounded,
                  size: 44,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 10),
                Text(
                  'Пользователи по запросу «$_query» не найдены',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final int directOffset = showDirect ? 1 : 0;
        final int totalCount = users.length + directOffset;

        return ListView.separated(
          shrinkWrap: true,
          itemCount: totalCount,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
          itemBuilder: (BuildContext context, int index) {
            if (showDirect && index == 0) {
              return _buildDirectUsernameTile(cleanQuery, scheme, textTheme);
            }
            final ApiSearchUser user = users[index - directOffset];
            return _buildUserTile(user, scheme, textTheme);
          },
        );
      },
    );
  }

  Widget _buildDirectUsernameTile(
    String clean,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: scheme.primaryContainer,
        child: Icon(
          Icons.alternate_email_rounded,
          color: scheme.onPrimaryContainer,
          size: 20,
        ),
      ),
      title: Text(
        '@$clean',
        style: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        'Открыть диалог с пользователем',
        style: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.arrow_forward_rounded,
          size: 16,
          color: scheme.primary,
        ),
      ),
      onTap: () => _selectUser(
        ApiSearchUser(
          id: 0,
          username: clean,
          displayName: '@$clean',
          avatarUrl: null,
          bio: '',
          badges: const [],
        ),
      ),
    );
  }

  Widget _buildUserTile(
    ApiSearchUser user,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: PulseAvatar(
        radius: 20,
        name: user.displayName,
        avatarUrl: user.avatarUrl,
      ),
      title: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              user.displayName,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (user.badges.isNotEmpty) ...<Widget>[
            const SizedBox(width: 4),
            ...user.badges.take(2).map((b) => Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: BadgeChip(
                    id: b.id,
                    name: b.name,
                    icon: b.icon,
                    color: b.color,
                    mode: BadgeDisplayMode.statusIcon,
                  ),
                )),
          ],
        ],
      ),
      subtitle: Text(
        '@${user.username}',
        style: textTheme.bodySmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.arrow_forward_rounded,
          size: 16,
          color: scheme.primary,
        ),
      ),
      onTap: () => _selectUser(user),
    );
  }
}
