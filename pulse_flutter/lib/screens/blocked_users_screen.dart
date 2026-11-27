import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/privacy_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/common/user_search_picker_sheet.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({this.isEmbedded = false, super.key});

  /// Shown inside the settings pane, under Privacy, instead of as a page of
  /// its own.
  final bool isEmbedded;

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  /// Wide-window gutter of [SettingsShell]. The shell pads its own slivers
  /// with it; a list appended after them has to use the same one, otherwise
  /// the rows sit 12 dp left of the search field above on a desktop window.
  static const double _wideGutter = 28.0;

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
    if (picked == null || owner != ref.read(authProvider).session) {
      setState(() => _picking = false);
      return;
    }
    // Blocking cuts off messages and calls: ask the same question as the
    // profile does. Unblocking stays instant because it is reversible.
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: context.l10n.profileBlock,
      subtitle: context.l10n.blockUserConfirmDesc(picked.username),
      confirmLabel: context.l10n.profileBlock,
      cancelLabel: context.l10n.commonCancel,
      destructive: true,
      icon: Icons.block_rounded,
    );
    if (!mounted) return;
    setState(() => _picking = false);
    if (confirmed != true || owner != ref.read(authProvider).session) return;
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // The same breakpoint and gutter the shell picks for its own content.
        // Reading them here keeps the appended list in that column instead of
        // inventing a second one.
        final double gutter = constraints.maxWidth >= Breakpoints.medium
            ? _wideGutter
            : AppSpacing.lg;
        final EdgeInsets safe = MediaQuery.paddingOf(context);
        return SettingsShell(
          title: context.l10n.blockedUsersTitle,
          isEmbedded: widget.isEmbedded,
          onRefresh: () => ref.read(privacyProvider.notifier).refresh(),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add_rounded),
              tooltip: context.l10n.blockUserAction,
              onPressed: pending || _picking ? null : _promptBlockUser,
            ),
          ],
          sliversAfter: [
            if (filtered.isNotEmpty)
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  gutter + safe.left,
                  0,
                  gutter + safe.right,
                  AppSpacing.xxl + safe.bottom,
                ),
                sliver: SliverToBoxAdapter(
                  child: SettingsSection(
                    children: [
                      for (final user in filtered)
                        _blockedRow(user, pending),
                    ],
                  ),
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
                    duration: context.reduceMotion
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
            const SizedBox(height: AppSpacing.lg),
            if (state.isLoading && state.blockedUsers.isEmpty)
              const SettingsSection(children: [SettingsSkeleton(rows: 4)])
            else if (state.error != null)
              SettingsErrorSection(
                title: context.l10n.commonError,
                message: context.l10n.settingsPrivacyLoadFailed,
                onRetry: () => ref.read(privacyProvider.notifier).refresh(),
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
      },
    );
  }

  /// One row of the group. The radii of the connected list belong to
  /// [SettingsSection]; a row only says who it is and offers to release them.
  Widget _blockedRow(BlockedUser user, bool pending) {
    final bool openable =
        user.username.isNotEmpty && !user.username.startsWith('id');
    return SettingsListItem(
      key: ValueKey<int>(user.id),
      icon: Icons.person_outline_rounded,
      leading: PulseAvatar(
        name: user.displayName,
        avatarUrl: user.avatarUrl,
        radius: 20,
      ),
      title: user.displayName,
      subtitle: openable ? '@${user.username}' : null,
      type: SettingsListItemType.action,
      trailing: IconButton(
        icon: const Icon(Icons.lock_open_rounded),
        tooltip: context.l10n.unblockAction,
        onPressed: pending ? null : () => _unblock(user),
      ),
      onTap: openable ? () => context.push('/u/${user.username}') : null,
    );
  }
}
