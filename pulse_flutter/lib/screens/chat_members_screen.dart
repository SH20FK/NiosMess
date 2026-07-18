import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/models/api/chat_member_model.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/search_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/app_error_banner.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class ChatMembersScreen extends ConsumerStatefulWidget {
  const ChatMembersScreen({required this.chatId, super.key});

  final int chatId;

  @override
  ConsumerState<ChatMembersScreen> createState() => _ChatMembersScreenState();
}

class _ChatMembersScreenState extends ConsumerState<ChatMembersScreen> {
  List<ApiChatMember>? _members;
  bool _loading = true;
  String? _error;
  bool _actionBusy = false;

  String _query = '';

  int? get _myUserId => ref.read(authProvider).session?.userId;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<ApiChatMember> members = await ref
          .read(chatRepositoryProvider)
          .getMembers(widget.chatId);
      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : '$e';
        _loading = false;
      });
    }
  }

  Future<void> _inviteUser() async {
    final TextEditingController searchController = TextEditingController();
    final ApiSearchUser? picked = await showModalBottomSheet<ApiSearchUser>(
      context: context,
      isScrollControlled: true,
      
      builder: (BuildContext ctx) {
        return Consumer(
          builder: (BuildContext ctx, WidgetRef ref, _) {
            final AsyncValue<ApiSearchResult> searchAsync = ref.watch(
              debouncedSearchProvider,
            );
            final List<ApiSearchUser> users =
                searchAsync.value?.users ?? const <ApiSearchUser>[];

            return Padding(
              padding: EdgeInsets.fromLTRB(
                0,
                0,
                0,
                MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    context.l10n.chatMembersInviteUser,
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: context.l10n.chatMembersSearchHint,
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                      onChanged: (String q) {
                        ref.read(debouncedSearchProvider.notifier).search(q);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.4,
                    ),
                    child: users.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(context.l10n.chatMembersSearchPrompt),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: users.length,
                            itemBuilder: (BuildContext ctx, int index) {
                              final ApiSearchUser user = users[index];
                              return ListTile(
                                leading: PulseAvatar(
                                  radius: 18,
                                  name: user.displayName,
                                  avatarUrl: user.avatarUrl,
                                ),
                                title: Text(user.displayName),
                                subtitle: Text('@${user.username}'),
                                trailing: user.badges.isEmpty
                                    ? null
                                    : Wrap(
                                        spacing: 4,
                                        children: user.badges
                                            .map(
                                              (b) => BadgeChip(
                                                id: b.id,
                                                name: b.name,
                                                icon: b.icon,
                                                color: b.color, mode: BadgeResolver.isStatusBadge(b) ? BadgeDisplayMode.statusIcon : BadgeDisplayMode.infoLabel,
                                              ),
                                            )
                                            .toList(growable: false),
                                      ),
                                onTap: () => Navigator.of(ctx).pop(user),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    searchController.dispose();
    ref.read(debouncedSearchProvider.notifier).clear();

    if (picked == null || !mounted) return;

    setState(() => _actionBusy = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .inviteUser(widget.chatId, picked.id);
      await _loadMembers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.chatMembersInvited(picked.username)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : context.l10n.chatMembersActionFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _toggleBan(ApiChatMember member, bool ban) async {
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: ban ? context.l10n.chatMembersBanConfirmTitle : context.l10n.chatMembersUnbanConfirmTitle,
      subtitle: ban ? context.l10n.chatMembersBanConfirmBody : context.l10n.chatMembersUnbanConfirmBody,
      confirmLabel: ban ? context.l10n.chatMembersBan : context.l10n.chatMembersUnban,
      cancelLabel: context.l10n.commonCancel,
      destructive: ban,
      icon: ban ? Icons.gpp_bad_rounded : Icons.verified_user_rounded,
    );
    if (confirmed != true) return;
    setState(() => _actionBusy = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .banUser(widget.chatId, member.userId, ban);
      await _loadMembers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : '$e')),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _toggleMute(ApiChatMember member, bool mute) async {
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: mute ? context.l10n.chatMembersMuteConfirmTitle : context.l10n.chatMembersUnmuteConfirmTitle,
      subtitle: mute ? context.l10n.chatMembersMuteConfirmBody : context.l10n.chatMembersUnmuteConfirmBody,
      confirmLabel: mute ? context.l10n.chatMembersMute : context.l10n.chatMembersUnmute,
      cancelLabel: context.l10n.commonCancel,
      icon: mute ? Icons.volume_off_rounded : Icons.volume_up_rounded,
      destructive: false,
    );
    if (confirmed != true) return;
    setState(() => _actionBusy = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .muteUser(widget.chatId, member.userId, mute);
      await _loadMembers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : '$e')),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _promote(ApiChatMember member, String role) async {
    setState(() => _actionBusy = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .promoteUser(widget.chatId, member.userId, role);
      await _loadMembers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : '$e')),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final chat = ref.watch(chatByIdProvider(widget.chatId));
    final List<ApiChatMember> visibleMembers = (_members ?? const <ApiChatMember>[])
        .where((ApiChatMember member) {
          final String query = _query.trim().toLowerCase();
          if (query.isEmpty) return true;
          return member.displayName.toLowerCase().contains(query) ||
              member.username.toLowerCase().contains(query) ||
              member.role.toLowerCase().contains(query);
        })
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.chatMembersTitle(
            chat?.name ?? context.l10n.chatTitleFallback(widget.chatId),
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _actionBusy ? null : _inviteUser,
            icon: const Icon(Icons.person_add_rounded),
            tooltip: context.l10n.chatMembersInviteUser,
          ),
        ],
      ),
      body: PulseScaffoldBody(
        maxWidth: 980,
        child: _loading
            ? const Center(child: AppLoadingIndicator())
            : _error != null
            ? AppErrorBanner(
                message: _error!,
                variant: AppErrorBannerVariant.centered,
                onRetry: _loadMembers,
              )
            : Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.screenHorizontalPadding,
                      12,
                      AppConstants.screenHorizontalPadding,
                      8,
                    ),
                    child: TextField(
                      onChanged: (String value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: context.l10n.chatMembersSearchHint,
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  Expanded(
                    child: visibleMembers.isEmpty
                        ? Center(child: Text(context.l10n.chatMembersEmpty))
                        : RefreshIndicator(
                            onRefresh: _loadMembers,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.screenHorizontalPadding,
                                vertical: 12,
                              ),
                              itemCount: visibleMembers.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (BuildContext context, int index) {
                                final ApiChatMember member = visibleMembers[index];
                                final bool isMe = member.userId == _myUserId;

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainer,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      PulseAvatar(
                                        radius: 22,
                                        name: member.displayName,
                                        avatarUrl: member.avatarUrl,
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
                                                    member.displayName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: textTheme.titleMedium,
                                                  ),
                                                ),
                                                if (member.badges.isNotEmpty) ...<Widget>[
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Wrap(
                                                      spacing: 4,
                                                      runSpacing: 2,
                                                      children: member.badges
                                                          .map(
                                                            (badge) => BadgeChip(
                                                              id: badge.id,
                                                              name: badge.name,
                                                              icon: badge.icon,
                                                              color: badge.color,
                                                              mode: BadgeResolver.isStatusBadge(badge)
                                                                  ? BadgeDisplayMode.statusIcon
                                                                  : BadgeDisplayMode.infoLabel,
                                                            ),
                                                          )
                                                          .toList(growable: false),
                                                    ),
                                                  ),
                                                ],
                                                if (member.isOwner) ...<Widget>[
                                                  const SizedBox(width: 6),
                                                  Icon(
                                                    Icons.star_rounded,
                                                    size: 16,
                                                    color: scheme.primary,
                                                  ),
                                                ],
                                                if (member.isAdmin && !member.isOwner) ...<Widget>[
                                                  const SizedBox(width: 6),
                                                  Icon(
                                                    Icons.shield_rounded,
                                                    size: 14,
                                                    color: scheme.tertiary,
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _memberSubtitle(member),
                                              style: textTheme.bodySmall?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isMe && !_actionBusy)
                                        PopupMenuButton<String>(
                                          onSelected: (String action) {
                                            switch (action) {
                                              case 'ban':
                                                _toggleBan(member, !member.isBanned);
                                              case 'mute':
                                                _toggleMute(member, !member.isMuted);
                                              case 'admin':
                                                _promote(member, 'admin');
                                              case 'member':
                                                _promote(member, 'member');
                                            }
                                          },
                                          itemBuilder: (BuildContext ctx) =>
                                              <PopupMenuEntry<String>>[
                                                PopupMenuItem<String>(
                                                  value: 'ban',
                                                  child: Text(
                                                    member.isBanned
                                                        ? context.l10n.chatMembersUnban
                                                        : context.l10n.chatMembersBan,
                                                  ),
                                                ),
                                                PopupMenuItem<String>(
                                                  value: 'mute',
                                                  child: Text(
                                                    member.isMuted
                                                        ? context.l10n.chatMembersUnmute
                                                        : context.l10n.chatMembersMute,
                                                  ),
                                                ),
                                                if (!member.isAdmin && !member.isOwner)
                                                  PopupMenuItem<String>(
                                                    value: 'admin',
                                                    child: Text(
                                                      context.l10n.chatMembersPromoteAdmin,
                                                    ),
                                                  ),
                                                if (member.isAdmin && !member.isOwner)
                                                  PopupMenuItem<String>(
                                                    value: 'member',
                                                    child: Text(
                                                      context.l10n.chatMembersDemoteMember,
                                                    ),
                                                  ),
                                              ],
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  String _memberSubtitle(ApiChatMember member) {
    final List<String> parts = <String>[
      '@${member.username}',
      _roleLabel(member.role),
      if (member.isMuted) context.l10n.chatMembersMuted,
      if (member.isBanned) context.l10n.chatMembersBanned,
    ];
    return parts.join(' • ');
  }

  String _roleLabel(String role) {
    return switch (role) {
      'owner' => context.l10n.chatMembersRoleOwner,
      'admin' => context.l10n.chatMembersRoleAdmin,
      _ => context.l10n.chatMembersRoleMember,
    };
  }
}
