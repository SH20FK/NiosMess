import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/privacy_model.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _unblock(BlockedUser user) async {
    HapticService.confirm();
    final bool success =
        await ref.read(privacyProvider.notifier).unblockUser(user.id);
    if (!mounted) return;
    if (success) {
      AppToast.showSuccess(
        context,
        '${user.displayName} разблокирован(а)',
      );
    } else {
      AppToast.showError(context, 'Не удалось разблокировать пользователя');
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
        title: const Text('Заблокированные пользователи'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск заблокированных...',
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
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.block_rounded,
                              size: 56,
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _query.isEmpty
                                  ? 'Черный список пуст'
                                  : 'Пользователи не найдены',
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
                                  ? 'Заблокированные пользователи не смогут писать и звонить вам'
                                  : 'Попробуйте изменить поисковый запрос',
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
                      )
                    : ListView.builder(
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
                              child: const Text('Разблокировать'),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
