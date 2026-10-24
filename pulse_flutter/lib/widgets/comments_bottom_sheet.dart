import 'package:flutter/material.dart';
import 'package:pulse_flutter/screens/post_comments_screen.dart';

class CommentsBottomSheet extends StatelessWidget {
  const CommentsBottomSheet({required this.postId, super.key});
  final int postId;
  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .94,
    child: PostCommentsScreen(channelId: 0, postId: postId),
  );
}
