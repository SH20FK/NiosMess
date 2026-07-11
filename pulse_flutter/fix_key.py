with open('lib/widgets/chat/chat_message_list.dart', 'r') as f:
    content = f.read()

content = content.replace("key: ValueKey<int>(message.id),", "key: ValueKey<String>('msg_${message.id}_${message.isRead}'),")

with open('lib/widgets/chat/chat_message_list.dart', 'w') as f:
    f.write(content)
