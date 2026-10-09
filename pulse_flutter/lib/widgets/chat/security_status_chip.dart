import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/widgets/chat/e2ee_status_card.dart';

class SecurityStatusChip extends ConsumerWidget {
  const SecurityStatusChip({
    required this.chatId,
    required this.onTap,
    this.compact = false,
    super.key,
  });
  final int chatId;
  final bool compact;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(secretChatRevisionProvider);
    final data = ref.watch(secretProtectionStateProvider(chatId));
    final warning =
        data['status'] == 'keyChanged' || data['status'] == 'invalidSignature';
    final colors = Theme.of(context).colorScheme;
    if (compact) {
      return IconButton(
        onPressed: onTap,
        tooltip: context.l10n.secretTitle,
        icon: Icon(
          warning ? Icons.shield_outlined : Icons.lock_rounded,
          color: warning ? colors.error : colors.primary,
          size: 20,
        ),
      );
    }
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: warning ? colors.error : colors.primary,
        shape: const StadiumBorder(),
      ),
      icon: Icon(
        warning ? Icons.shield_outlined : Icons.lock_rounded,
        size: 16,
      ),
      label: Text(
        context.l10n.secretTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}
