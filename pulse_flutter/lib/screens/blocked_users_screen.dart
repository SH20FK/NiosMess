import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/privacy_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/widgets/common/user_search_picker_sheet.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/settings/settings_group_scope.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});
  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _picking = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _promptBlockUser() async {
    if (_picking) return;
    final owner = ref.read(authProvider).session;
    final privacy = ref.read(privacyProvider);
    if (privacy.pendingRules.isNotEmpty || privacy.pendingUsers.isNotEmpty) {
      return;
    }
    setState(() => _picking = true);
    final picked = await showUserSearchPickerSheet(
      context,
      title: context.l10n.blockUserAction,
      subtitle: context.l10n.searchByUsernameOrName,
      hintText: context.l10n.searchByUsernameOrNameHint,
      excludedUserIds: privacy.blockedUsers.map((u) => u.id).toSet(),
    );
    if (!mounted) return;
    setState(() => _picking = false);
    if (picked == null || owner != ref.read(authProvider).session) return;
    HapticService.confirm();
    final success = await ref
        .read(privacyProvider.notifier)
        .blockUser(
          picked.id,
          user: BlockedUser(
            id: picked.id,
            username: picked.username,
            displayName: picked.displayName,
            avatarUrl: picked.avatarUrl,
          ),
        );
    if (!mounted || owner != ref.read(authProvider).session) return;
    if (success) {
      AppToast.showSuccess(
        context,
        context.l10n.userBlockedToast(picked.displayName),
      );
    } else {
      AppToast.showError(context, context.l10n.userBlockFailed);
    }
  }

  Future<void> _unblock(BlockedUser user) async {
    final owner = ref.read(authProvider).session;
    HapticService.confirm();
    final success = await ref
        .read(privacyProvider.notifier)
        .unblockUser(user.id);
    if (!mounted || owner != ref.read(authProvider).session) return;
    if (success) {
      AppToast.showSuccess(
        context,
        context.l10n.userUnblockedToast(user.displayName),
      );
    } else {
      AppToast.showError(context, context.l10n.userUnblockFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(privacyProvider);
    final query = _query.toLowerCase();
    final filtered = state.blockedUsers
        .where(
          (user) =>
              query.isEmpty ||
              user.displayName.toLowerCase().contains(query) ||
              user.username.toLowerCase().contains(query),
        )
        .toList();
    final pending =
        state.pendingUsers.isNotEmpty || state.pendingRules.isNotEmpty;
    return SettingsShell(
      title: context.l10n.blockedUsersTitle,
      onRefresh: () => ref.read(privacyProvider.notifier).refresh(),
      actions: [
        IconButton(
          icon: const Icon(Icons.person_add_rounded),
          tooltip: context.l10n.blockUserAction,
          onPressed: pending || _picking ? null : _promptBlockUser,
        ),
      ],
      sliversAfter: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) =>
                _blockedRow(filtered[index], index, filtered.length, pending),
          ),
        ),
      ],
      children: [
        RepaintBoundary(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.l10n.searchBlockedHint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : M3Durations.short3,
                child: _query.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        key: const ValueKey('clear-blocked-search'),
                        icon: const Icon(Icons.clear_rounded),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).deleteButtonTooltip,
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
        ),
        const SizedBox(height: 16),
        if (state.isLoading && state.blockedUsers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: AppLoadingIndicator()),
          )
        else if (state.error != null)
          SettingsSection(
            children: [
              SettingsListItem(
                icon: Icons.cloud_off_rounded,
                title: context.l10n.settingsPrivacyLoadFailed,
                value: context.l10n.commonRetry,
                type: SettingsListItemType.action,
                onTap: () => ref.read(privacyProvider.notifier).refresh(),
              ),
            ],
          )
        else if (filtered.isEmpty)
          SettingsSection(
            children: [
              SettingsListItem(
                icon: Icons.block_rounded,
                title: _query.isEmpty
                    ? context.l10n.privacyNoBlocked
                    : context.l10n.noBlockedUsersFound,
                subtitle: _query.isEmpty
                    ? context.l10n.noBlockedUsersDesc
                    : null,
                type: SettingsListItemType.value,
              ),
            ],
          ),
      ],
    );
  }

  Widget _blockedRow(BlockedUser user, int index, int count, bool pending) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.vertical(
      top: Radius.circular(index == 0 ? 26 : 4),
      bottom: Radius.circular(index == count - 1 ? 26 : 4),
    );
    return Padding(
      key: ValueKey(user.id),
      padding: EdgeInsets.only(top: index == 0 ? 0 : 2),
      child: SettingsGroupScope(
        borderRadius: radius,
        color: scheme.surfaceContainerLow,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: radius,
          ),
          child: SettingsListItem(
            icon: Icons.person_outline_rounded,
            leading: PulseAvatar(
              name: user.displayName,
              avatarUrl: user.avatarUrl,
              radius: 20,
            ),
            title: user.displayName,
            subtitle:
                user.username.isNotEmpty && !user.username.startsWith('id')
                ? '@${user.username}'
                : null,
            type: SettingsListItemType.action,
            trailing: IconButton(
              icon: const Icon(Icons.lock_open_rounded),
              tooltip: context.l10n.unblockAction,
              onPressed: pending ? null : () => _unblock(user),
            ),
            onTap: user.username.isNotEmpty && !user.username.startsWith('id')
                ? () => context.push('/u/${user.username}')
                : null,
          ),
        ),
      ),
    );
  }
}
