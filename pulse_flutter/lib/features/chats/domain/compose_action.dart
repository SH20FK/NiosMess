import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

enum ComposeActionId {
  message,
  group,
  channel,
  secret,
  joinLink,
}

@immutable
class ComposeActionDescriptor {
  const ComposeActionDescriptor({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.available = true,
  });

  final ComposeActionId id;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool available;
}

List<ComposeActionDescriptor> buildComposeActions(
  BuildContext context, {
  bool canCreateGroup = true,
  bool canCreateChannel = true,
  bool canCreateSecret = true,
}) {
  return <ComposeActionDescriptor>[
    ComposeActionDescriptor(
      id: ComposeActionId.message,
      icon: Icons.chat_bubble_outline_rounded,
      title: 'Новое сообщение',
      subtitle: 'Выбрать человека или найти по @username',
      available: true,
    ),
    ComposeActionDescriptor(
      id: ComposeActionId.group,
      icon: Icons.groups_rounded,
      title: context.l10n.groupNewGroup,
      subtitle: 'Создать чат и пригласить участников',
      available: canCreateGroup,
    ),
    ComposeActionDescriptor(
      id: ComposeActionId.channel,
      icon: Icons.campaign_rounded,
      title: context.l10n.groupNewChannel,
      subtitle: 'Канал для публикаций и новостей',
      available: canCreateChannel,
    ),
    ComposeActionDescriptor(
      id: ComposeActionId.secret,
      icon: Icons.lock_outline_rounded,
      title: 'Секретный чат',
      subtitle: 'Сквозное шифрование и самоуничтожение сообщений',
      available: canCreateSecret,
    ),
    const ComposeActionDescriptor(
      id: ComposeActionId.joinLink,
      icon: Icons.link_rounded,
      title: 'Вступить по ссылке',
      subtitle: 'Перейти по ссылке-приглашению или QR-коду',
      available: true,
    ),
  ];
}
