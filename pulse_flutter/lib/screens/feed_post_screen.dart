import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/screens/post_comments_screen.dart';
import 'package:pulse_flutter/widgets/post_card.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class FeedPostScreen extends ConsumerWidget {
  const FeedPostScreen({required this.postId, super.key});
  final int postId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('NiosGram')),
    body: ref
        .watch(feedPostByIdProvider(postId))
        .when(
          loading: () => const Center(child: AppLoadingIndicator()),
          error: (error, stack) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(feedPostByIdProvider(postId)),
              child: const Text('Повторить загрузку публикации'),
            ),
          ),
          data: (post) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(feedPostByIdProvider(postId));
              await ref.read(feedPostByIdProvider(postId).future);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: PostCard(
                    post: post,
                    onChanged: () =>
                        ref.invalidate(feedPostByIdProvider(postId)),
                    onDeleted: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/main/niosgram');
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
  );
}
