import 'package:flutter/material.dart';
import '../../core/models/message_item.dart';
import 'voice_recorder_widget.dart';

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

    // Show voice recorder when recording
    if (isRecording) {
      return VoiceRecorderWidget(
        isRecording: isRecording,
        duration: recordDuration,
        onCancel: onCancelRecord,
        onSend: onRecord,
      );
    }

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
                        fillColor: scheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.emoji_emotions_outlined),
                              onPressed: onEmoji,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (controller.text.isEmpty)
                    _CircleButton(
                      icon: Icons.mic,
                      onPressed: onRecord,
                      color: scheme.primary,
                    )
                  else
                    _CircleButton(
                      icon: Icons.send,
                      onPressed: sending ? null : onSend,
                      color: scheme.primary,
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
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
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
                  replyTo!.sender,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyTo!.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClearReply,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
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
    required this.icon,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = color ?? scheme.surfaceContainerHighest;
    final foreground = onPressed == null
        ? scheme.onSurfaceVariant.withOpacity(0.5)
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
