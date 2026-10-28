import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/providers/niosgram_saved_provider.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// Local snapshots provide an offline index; opening fetches the current post.
class NiosgramSavedScreen extends ConsumerWidget {
  const NiosgramSavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(niosgramSavedProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.niosgramSavedTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: saved.when(
            loading: () => const Center(child: AppLoadingIndicator()),
            error: (_, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.niosgramSaveFailed),
                  TextButton(
                    onPressed: () => ref.invalidate(niosgramSavedProvider),
                    child: Text(context.l10n.commonRetry),
                  ),
                ],
              ),
            ),
            data: (posts) => ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: posts.isEmpty ? 2 : posts.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
                    child: Text(
                      context.l10n.niosgramSavedLocalNotice,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                if (posts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: Text(context.l10n.niosgramSavedEmpty)),
                  );
                }
                final NgPost post = posts[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      leading: PulseAvatar(
                        name: post.author.displayName,
                        avatarUrl: post.author.avatarUrl,
                        radius: 20,
                      ),
                      title: Text(
                        post.author.displayName.isNotEmpty
                            ? post.author.displayName
                            : post.author.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        post.content.isEmpty
                            ? context.l10n.auditPostMedia
                            : post.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => context.push('/niosgram/post/${post.id}'),
                      trailing: IconButton(
                        tooltip: context.l10n.niosgramRemoveSaved,
                        icon: const Icon(Icons.bookmark_remove_outlined),
                        onPressed: () async {
                          try {
                            await ref
                                .read(niosgramSavedProvider.notifier)
                                .toggle(post);
                          } catch (_) {
                            if (context.mounted) {
                              AppToast.showError(
                                context,
                                context.l10n.niosgramSaveFailed,
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
