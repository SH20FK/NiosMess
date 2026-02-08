import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../ui/nios_ui.dart';

class SwipeableMessage extends StatelessWidget {
  final Widget child;
  final VoidCallback onReply;
  final VoidCallback? onDelete;
  final VoidCallback? onForward;
  final bool isOutgoing;

  const SwipeableMessage({
    super.key,
    required this.child,
    required this.onReply,
    this.onDelete,
    this.onForward,
    this.isOutgoing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: key,
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.25,
        children: [
          CustomSlidableAction(
            onPressed: (_) => onReply(),
            backgroundColor: NiosPalette.accent.withValues(alpha: 0.2),
            foregroundColor: NiosPalette.accent,
            borderRadius: BorderRadius.circular(12),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.reply, size: 24),
                SizedBox(height: 4),
                Text('Ответить', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
      startActionPane: onDelete != null || onForward != null
          ? ActionPane(
              motion: const ScrollMotion(),
              extentRatio: 0.5,
              children: [
                if (onForward != null)
                  CustomSlidableAction(
                    onPressed: (_) => onForward!(),
                    backgroundColor: Colors.blue.withValues(alpha: 0.2),
                    foregroundColor: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forward, size: 24),
                        SizedBox(height: 4),
                        Text('Переслать', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                if (onDelete != null)
                  CustomSlidableAction(
                    onPressed: (_) => onDelete!(),
                    backgroundColor: Colors.red.withValues(alpha: 0.2),
                    foregroundColor: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete, size: 24),
                        SizedBox(height: 4),
                        Text('Удалить', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
              ],
            )
          : null,
      child: child,
    );
  }
}
