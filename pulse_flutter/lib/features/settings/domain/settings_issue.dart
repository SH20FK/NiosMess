import 'package:flutter/foundation.dart';

enum SettingsHealthSeverity { critical, warning, advisory }

@immutable
class SettingsHealthIssue {
  const SettingsHealthIssue({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.route,
    required this.anchor,
    required this.actionLabel,
    this.canDismiss = false,
  });

  final String id;
  final String title;
  final String description;
  final SettingsHealthSeverity severity;
  final String route;
  final String anchor;
  final String actionLabel;
  final bool canDismiss;

  factory SettingsHealthIssue.notificationsDenied() => const SettingsHealthIssue(
        id: 'notifications_denied',
        title: 'Уведомления отключены',
        description: 'Вы можете пропустить важные звонки и личные сообщения',
        severity: SettingsHealthSeverity.warning,
        route: '/settings/notifications',
        anchor: 'notifications-permission',
        actionLabel: 'Включить',
      );

  factory SettingsHealthIssue.reauthenticationRequired() => const SettingsHealthIssue(
        id: 'reauthentication_required',
        title: 'Требуется подтверждение входа',
        description: 'Срок действия сессии подходит к концу. Подтвердите вход для защиты чатов',
        severity: SettingsHealthSeverity.critical,
        route: '/settings/account',
        anchor: 'account-security',
        actionLabel: 'Подтвердить',
      );

  factory SettingsHealthIssue.storageLow(int freeBytes) {
    final int mb = (freeBytes / (1024 * 1024)).round();
    return SettingsHealthIssue(
      id: 'storage_low',
      title: 'Мало свободного места',
      description: 'На устройстве осталось $mb МБ. Очистите временные файлы и кэш',
      severity: SettingsHealthSeverity.warning,
      route: '/settings/storage',
      anchor: 'storage-cache-clear',
      actionLabel: 'Очистить кэш',
    );
  }

  factory SettingsHealthIssue.updateIntegrityFailure() => const SettingsHealthIssue(
        id: 'update_integrity_failure',
        title: 'Ошибка проверки обновления',
        description: 'Контрольная сумма пакета обновления не совпала с серверной',
        severity: SettingsHealthSeverity.critical,
        route: '/settings/about',
        anchor: 'app-update',
        actionLabel: 'Повторить',
      );
}
