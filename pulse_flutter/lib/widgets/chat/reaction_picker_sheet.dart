import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/models/api/message_model.dart';

const List<String> allReactionEmojis = <String>[
  '👍',
  '👎',
  '❤️',
  '🔥',
  '😂',
  '🎉',
  '😮',
  '😢',
  '😍',
  '🤔',
  '😎',
  '🫡',
  '🙏',
  '👏',
  '💪',
  '🤝',
  '💯',
  '✨',
  '⭐',
  '⚡',
  '☕',
  '🍕',
  '🎮',
  '❌',
  '✅',
];

/// Opens the full reaction picker and resolves with the chosen emoji, or
/// `null` when the sheet is dismissed.
Future<String?> showReactionPickerSheet(
  BuildContext context, {
  required ApiMessage message,
}) => AppModal.showSheet<String>(
  context: context,
  builder: (BuildContext ctx) => ReactionPickerSheet(message: message),
);

class ReactionPickerSheet extends StatelessWidget {
  const ReactionPickerSheet({required this.message, super.key});

  final ApiMessage message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                context.l10n.chatReactionsPickerTitle,
                style: tt.titleMedium,
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: allReactionEmojis.map((String emoji) {
                return InkWell(
                  onTap: () => Navigator.of(context).pop(emoji),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (message.reactions[emoji] ?? 0) > 0
                          ? scheme.primaryContainer.withValues(alpha: 0.6)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
