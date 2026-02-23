import 'package:flutter/material.dart';
import '../../core/models/message_item.dart';

class ChatInputWidget extends StatelessWidget {
  final TextEditingController controller;
  final bool isRecording;
  final Duration recordDuration;
  final MessageItem? replyTo;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onEmoji;
  final VoidCallback onAttach;
  final VoidCallback onRecord;
  final VoidCallback onCancelRecord;
  final VoidCallback onClearReply;
  final bool enterToSend;

  const ChatInputWidget({
    super.key,
    required this.controller,
    this.isRecording = false,
    this.recordDuration = Duration.zero,
    this.replyTo,
    this.sending = false,
    required this.onSend,
    required this.onEmoji,
    required this.onAttach,
    required this.onRecord,
    required this.onCancelRecord,
    required this.onClearReply,
    this.enterToSend = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isRecording) _buildVoiceRecordingUI(context),
              if (replyTo != null) _buildReplyPreview(context),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _CircleButton(
                    icon: Icons.attach_file,
                    onPressed: onAttach,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: enterToSend
                          ? TextInputAction.send
                          : TextInputAction.newline,
                      onSubmitted: enterToSend ? (_) => onSend() : null,
                      style: textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Сообщение',
                        filled: true,
                        fillColor: scheme.surfaceVariant,
                        prefixIcon: IconButton(
                          onPressed: onEmoji,
                          icon: const Icon(Icons.emoji_emotions_outlined),
                        ),
                        hintStyle: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: scheme.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: scheme.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: scheme.primary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Use ValueListenableBuilder to reactively switch
                  // between mic / send button based on text content
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final hasText = value.text.isNotEmpty;
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: RotationTransition(
                              turns: Tween<double>(begin: 0.5, end: 0)
                                  .animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: !hasText && !isRecording
                            ? _CircleButton(
                                key: const ValueKey('mic'),
                                icon: Icons.mic,
                                onPressed: onRecord,
                              )
                            : isRecording
                                ? _CircleButton(
                                    key: const ValueKey('stop'),
                                    icon: Icons.stop,
                                    onPressed: onRecord,
                                    color: scheme.error,
                                  )
                                : _CircleButton(
                                    key: const ValueKey('send'),
                                    icon: Icons.send,
                                    onPressed: sending ? null : onSend,
                                    color: scheme.primary,
                                  ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: scheme.primary, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ответ',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyTo!.text,
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClearReply,
            icon: const Icon(Icons.close),
            tooltip: 'Убрать ответ',
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildVoiceRecordingUI(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration:
                BoxDecoration(color: scheme.error, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Text(
            _formatDuration(recordDuration),
            style: TextStyle(
              color: scheme.error,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 3,
                  height: 10 + (index % 3) * 8.0,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 16),
          IconButton.filledTonal(
            onPressed: onCancelRecord,
            icon: const Icon(Icons.close),
            tooltip: 'Отменить',
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: onRecord,
            icon: const Icon(Icons.send),
            tooltip: 'Отправить',
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;

  const _CircleButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = color ?? scheme.surfaceVariant;
    final foreground = onPressed == null
        ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
        : (color != null ? scheme.onPrimary : scheme.onSurfaceVariant);

    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
