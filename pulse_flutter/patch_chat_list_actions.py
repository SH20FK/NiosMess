import re

with open(r"E:\Niosmess V2\pulse_flutter\lib\screens\chat_list_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

old_long_press = "onLongPress: () => _showChatContextMenu(context, chat),"

new_actions = """actions: [
                            IconButton(
                              icon: Icon(chat.unreadCount > 0 ? Icons.mark_chat_read_rounded : Icons.mark_chat_unread_rounded),
                              tooltip: context.l10n.chatListMarkRead,
                              onPressed: () {
                                ref.read(chatMessagesProvider(chat.id).notifier).markRead();
                                ref.read(chatsProvider.notifier).refresh();
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                              tooltip: context.l10n.chatListLeave,
                              onPressed: () => _leaveChat(context, chat),
                            ),
                          ],"""

content = content.replace(old_long_press, new_actions)

with open(r"E:\Niosmess V2\pulse_flutter\lib\screens\chat_list_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
