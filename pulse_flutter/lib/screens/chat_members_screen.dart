import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_error_formatter.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/models/api/chat_member_model.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/search_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/app_error_banner.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/chat/moderation_bottom_sheet.dart';
import 'package:pulse_flutter/widgets/common/app_action_menu_item.dart';
import 'package:pulse_flutter/widgets/common/app_pill_field.dart';
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
        _error = AppErrorFormatter.format(e).toString();
        _loading = false;
      });
    }
  }

  Future<void> _inviteUser() async {
    final TextEditingController searchController = TextEditingController();
    final ApiSearchUser? picked = await AppBottomSheets.show<ApiSearchUser>(
      context: context,
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
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppPillField(
                      controller: searchController,
                      autofocus: true,
                      hintText: context.l10n.chatMembersSearchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      onChanged: (String q) {
                        ref.read(debouncedSearchProvider.notifier).search(q);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
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
                                                color: b.color,
                                                mode: BadgeResolver.isStatusBadge(b)
                                                    ? BadgeDisplayMode.statusIcon
                                                    : BadgeDisplayMode.infoLabel,
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
      AppToast.showSuccess(context, context.l10n.chatMembersInvited(picked.username));
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _openModeration(ApiChatMember member) async {
    final ApiChatMember? myMember = _members?.cast<ApiChatMember?>().firstWhere(
      (m) => m?.userId == _myUserId,
      orElse: () => null,
    );
    final String myRole = myMember?.role ?? 'member';
    await ModerationBottomSheet.show(
      context,
      chatId: widget.chatId,
      member: member,
      callerRole: myRole,
    );
    _loadMembers();
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
      AppToast.showError(context, e);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _kick(ApiChatMember member) async {
    final bool? confirm = await showAppConfirmDialog(
      context: context,
      title: 'Исключить участника?',
      subtitle: 'Участник @${member.username} будет исключен из группы.',
      confirmLabel: 'Исключить',
      cancelLabel: context.l10n.commonCancel,
      destructive: true,
      icon: Icons.person_remove_rounded,
    );
    if (confirm != true || !mounted) return;
    setState(() => _actionBusy = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .banUser(widget.chatId, member.userId, true);
      if (!mounted) return;
      AppToast.showSuccess(context, 'Участник исключен');
      await _loadMembers();
    } catch (e) {
      if (mounted) AppToast.showError(context, e);
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
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: isMe ? null : () => _openModeration(member),
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
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: scheme.primaryContainer.withValues(alpha: 0.7),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: <Widget>[
                                                          Icon(
                                                            Icons.star_rounded,
                                                            size: 11,
                                                            color: scheme.primary,
                                                          ),
                                                          const SizedBox(width: 3),
                                                          Text(
                                                            context.l10n.chatMembersRoleOwner,
                                                            style: textTheme.labelSmall?.copyWith(
                                                              color: scheme.primary,
                                                              fontWeight: FontWeight.w700,
                                                              fontSize: 10,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                  if (member.isAdmin && !member.isOwner) ...<Widget>[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: scheme.tertiaryContainer.withValues(alpha: 0.7),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: <Widget>[
                                                          Icon(
                                                            Icons.shield_rounded,
                                                            size: 11,
                                                            color: scheme.tertiary,
                                                          ),
                                                          const SizedBox(width: 3),
                                                          Text(
                                                            context.l10n.chatMembersRoleAdmin,
                                                            style: textTheme.labelSmall?.copyWith(
                                                              color: scheme.tertiary,
                                                              fontWeight: FontWeight.w700,
                                                              fontSize: 10,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
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
                                          MenuAnchor(
                                            builder: (BuildContext context, MenuController controller, Widget? child) {
                                              return IconButton(
                                                icon: const Icon(Icons.more_vert_rounded),
                                                onPressed: () {
                                                  if (controller.isOpen) {
                                                    controller.close();
                                                  } else {
                                                    controller.open();
                                                  }
                                                },
                                              );
                                            },
                                            menuChildren: AppActionMenuItem.buildItems(
                                              context,
                                              <AppActionMenuItem>[
                                                AppActionMenuItem(
                                                  label: 'Модерация (мут/бан)',
                                                  icon: Icons.gavel_rounded,
                                                  iconColor: scheme.primary,
                                                  onPressed: () => _openModeration(member),
                                                ),
                                                if (!member.isAdmin && !member.isOwner)
                                                  AppActionMenuItem(
                                                    label: context.l10n.chatMembersPromoteAdmin,
                                                    icon: Icons.shield_rounded,
                                                    iconColor: scheme.tertiary,
                                                    onPressed: () => _promote(member, 'admin'),
                                                  ),
                                                if (member.isAdmin && !member.isOwner)
                                                  AppActionMenuItem(
                                                    label: context.l10n.chatMembersDemoteMember,
                                                    icon: Icons.person_outline_rounded,
                                                    iconColor: scheme.onSurfaceVariant,
                                                    onPressed: () => _promote(member, 'member'),
                                                  ),
                                                if (!member.isOwner)
                                                  AppActionMenuItem(
                                                    label: 'Исключить из группы',
                                                    icon: Icons.person_remove_rounded,
                                                    isDestructive: true,
                                                    onPressed: () => _kick(member),
                                                  ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
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
