import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/privacy_model.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/widgets/common/user_search_picker_sheet.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(privacyProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _promptBlockUser() async {
    final PrivacyState state = ref.read(privacyProvider);
    final Set<int> alreadyBlocked = state.blockedUsers.map((u) => u.id).toSet();

    final ApiSearchUser? picked = await showUserSearchPickerSheet(
      context,
      title: context.l10n.blockUserAction,
      subtitle: context.l10n.searchByUsernameOrName,
      hintText: context.l10n.searchByUsernameOrNameHint,
      excludedUserIds: alreadyBlocked,
    );

    if (picked == null || !mounted) return;

    HapticService.confirm();
    final bool success = await ref.read(privacyProvider.notifier).blockUser(
          picked.id,
          user: BlockedUser(
            id: picked.id,
            username: picked.username,
            displayName: picked.displayName,
            avatarUrl: picked.avatarUrl,
          ),
        );
    if (!mounted) return;
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
    HapticService.confirm();
    final bool success =
        await ref.read(privacyProvider.notifier).unblockUser(user.id);
    if (!mounted) return;
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
    final PrivacyState state = ref.watch(privacyProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final List<BlockedUser> filtered = state.blockedUsers.where((BlockedUser u) {
      if (_query.isEmpty) return true;
      return u.displayName.toLowerCase().contains(_query.toLowerCase()) ||
          u.username.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.blockedUsersTitle),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.l10n.refreshAction,
            onPressed: () => ref.read(privacyProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: context.l10n.blockUserAction,
            onPressed: _promptBlockUser,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _promptBlockUser,
        icon: const Icon(Icons.block_rounded),
        label: Text(context.l10n.profileBlock),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(privacyProvider.notifier).refresh(),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: context.l10n.searchBlockedHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (String val) => setState(() => _query = val.trim()),
              ),
            ),
            Expanded(
              child: state.isLoading && state.blockedUsers.isEmpty
                  ? const Center(child: AppLoadingIndicator())
                  : filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: <Widget>[
                            const SizedBox(height: 80),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.block_rounded,
                                    size: 56,
                                    color: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _query.isEmpty
                                        ? context.l10n.noBlockedUsersDesc
                                        : context.l10n.noBlockedUsersFound,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _query.isEmpty
                                        ? context.l10n.privacyNoBlocked
                                        : context.l10n.noBlockedUsersFound,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant
                                              .withValues(alpha: 0.7),
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          itemBuilder: (BuildContext context, int index) {
                            final BlockedUser user = filtered[index];
                            return ListTile(
                              leading: PulseAvatar(
                                name: user.displayName,
                                avatarUrl: user.avatarUrl,
                                radius: 20,
                              ),
                              title: Text(
                                user.displayName,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text('@${user.username}'),
                              onTap: () {
                                if (user.username.isNotEmpty &&
                                    !user.username.startsWith('id')) {
                                  context.push('/u/${user.username}');
                                }
                              },
                              trailing: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => _unblock(user),
                                child: Text(context.l10n.unblockAction),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
