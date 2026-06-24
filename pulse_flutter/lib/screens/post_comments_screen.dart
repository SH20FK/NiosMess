import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/widgets/message_bubble.dart';

class PostCommentsScreen extends ConsumerStatefulWidget {
  const PostCommentsScreen({
    required this.channelId,
    required this.postId,
    super.key,
  });

  final int channelId;
  final int postId;

  @override
  ConsumerState<PostCommentsScreen> createState() => _PostCommentsScreenState();
}

class _PostCommentsScreenState extends ConsumerState<PostCommentsScreen> {
  final TextEditingController _inputController = TextEditingController();
  int? _replyToMessageId;
  String? _replyPreview;
  bool _busy = false;

  PostCommentsArgs get _args =>
      PostCommentsArgs(channelId: widget.channelId, postId: widget.postId);

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String text = _inputController.text.trim();
    if (text.isEmpty || _busy) {
      return;
    }

    setState(() => _busy = true);

    try {
      await ref
          .read(postCommentsProvider(_args).notifier)
          .send(text, replyToId: _replyToMessageId);
      _inputController.clear();
      if (!mounted) return;
      setState(() {
        _replyToMessageId = null;
        _replyPreview = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String message = error is ApiException
          ? error.message
          : context.l10n.commentsFailedSend('$error');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _displayText(ApiMessage message) {
    if (message.isDeleted) {
      return context.l10n.commentsDeleted;
    }
    if (message.content.trim().isNotEmpty) {
      return message.content.trim();
    }
    return '[${message.msgType}]';
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final AsyncValue<List<ApiMessage>> commentsAsync = ref.watch(
      postCommentsProvider(_args),
    );

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: !_busy,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Отменить?'),
            content: const Text('Идёт отправка комментария. Отменить?'),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Нет')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Да')),
            ],
          ),
        );
        if (confirm == true && mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.commentsTitle)),
        body: Column(
          children: <Widget>[
            Expanded(
              child: commentsAsync.when(
                data: (List<ApiMessage> comments) {
                  if (comments.isEmpty) {
                    return Center(child: Text(context.l10n.commentsEmpty));
                  }

                  final Map<int, ApiMessage> byId = <int, ApiMessage>{
                    for (final ApiMessage message in comments)
                      message.id: message,
                  };

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    itemCount: comments.length,
                    itemBuilder: (BuildContext context, int index) {
                      final ApiMessage message = comments[index];
                      final bool isMine =
                          message.senderId == (auth.session?.userId ?? -1);

                      String? replyPreview;
                      final int? replyToId = message.replyToId;
                      if (replyToId != null && byId[replyToId] != null) {
                        final ApiMessage target = byId[replyToId]!;
                        replyPreview =
                            '${target.senderDisplayName}: ${_displayText(target)}';
                      }

                      return MessageBubble(
                        text: _displayText(message),
                        formattedTime: formatMessageTime(message.sentAt),
                        isMine: isMine,
                        isEdited: message.isEdited,
                        isDeleted: message.isDeleted,
                        reactions: message.reactions,
                        replyPreview: replyPreview,
                        onLongPress: () {
                          setState(() {
                            _replyToMessageId = message.id;
                            _replyPreview =
                                '${message.senderDisplayName}: ${_displayText(message)}';
                          });
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(year2023: false)),
                error: (Object error, StackTrace trace) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(context.l10n.commentsFailedLoad('$error')),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.screenHorizontalPadding,
                  8,
                  AppConstants.screenHorizontalPadding,
                  12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (_replyToMessageId != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                _replyPreview ?? context.l10n.chatReply,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _replyToMessageId = null;
                                  _replyPreview = null;
                                });
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: context.l10n.commentsHint,
                              prefixIcon: const Icon(Icons.mode_comment_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(56, 56),
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: _busy ? null : _send,
                          child: _busy
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    year2023: false,
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
