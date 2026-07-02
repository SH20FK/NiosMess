// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'NiosMess Admin';

  @override
  String get unlockTitle => 'Админ-доступ';

  @override
  String get unlockSubtitle =>
      'Введите admin-пароль для управления пользователями, чатами и бейджами.';

  @override
  String get unlockPassword => 'Пароль администратора';

  @override
  String get unlockAction => 'Открыть';

  @override
  String get unlockChecking => 'Проверяем...';

  @override
  String get unlockFailed => 'Доступ запрещён';

  @override
  String get logout => 'Выйти';

  @override
  String get dashboard => 'Обзор';

  @override
  String get users => 'Пользователи';

  @override
  String get chats => 'Чаты';

  @override
  String get badges => 'Бейджи';

  @override
  String get refresh => 'Обновить';

  @override
  String get search => 'Поиск';

  @override
  String get retry => 'Повторить';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get delete => 'Удалить';

  @override
  String get close => 'Закрыть';

  @override
  String get dashboardTitle => 'Админ-панель';

  @override
  String get dashboardSubtitle =>
      'Инструменты модерации пользователей, чатов и бейджей.';

  @override
  String get dashboardUsersTitle => 'Модерация пользователей';

  @override
  String get dashboardUsersBody =>
      'Открывайте профили, баньте и замораживайте аккаунты, управляйте спам-блоком.';

  @override
  String get dashboardChatsTitle => 'Модерация чатов';

  @override
  String get dashboardChatsBody =>
      'Баньте группы и каналы, проверяйте размер и состояние.';

  @override
  String get dashboardBadgesTitle => 'Система бейджей';

  @override
  String get dashboardBadgesBody =>
      'Создавайте бейджи, удаляйте их и выдавайте пользователям.';

  @override
  String get usersTitle => 'Пользователи';

  @override
  String get usersSubtitle => 'Поиск и модерация аккаунтов по страницам.';

  @override
  String get usersSearchHint => 'Поиск по username, email или имени';

  @override
  String usersPage(int page) {
    return 'Страница $page';
  }

  @override
  String get usersNoResults => 'На этой странице пользователей нет.';

  @override
  String get usersOpen => 'Открыть';

  @override
  String get usersBan => 'Забанить';

  @override
  String get usersUnban => 'Разбанить';

  @override
  String get usersFreeze => 'Заморозить';

  @override
  String get usersUnfreeze => 'Разморозить';

  @override
  String get usersSpamblock => 'Спам-блок';

  @override
  String get usersUnspamblock => 'Снять спам-блок';

  @override
  String get usersReason => 'Причина';

  @override
  String get userDetailTitle => 'Профиль пользователя';

  @override
  String get userDetailActions => 'Действия модерации';

  @override
  String get userDetailBadges => 'Бейджи';

  @override
  String get userDetailAwardBadge => 'Выдать бейдж';

  @override
  String get userDetailRevokeBadge => 'Забрать бейдж';

  @override
  String get userStatusActive => 'Активен';

  @override
  String get userStatusBanned => 'Забанен';

  @override
  String get userStatusFrozen => 'Заморожен';

  @override
  String get userStatusSpamBlocked => 'Спам-блок';

  @override
  String get userStatus2fa => '2FA';

  @override
  String get chatsTitle => 'Чаты';

  @override
  String get chatsSubtitle => 'Модерация групп и каналов.';

  @override
  String get chatsSearchHint => 'Поиск по имени или username';

  @override
  String get chatsNoResults => 'На этой странице чатов нет.';

  @override
  String get chatsBan => 'Забанить чат';

  @override
  String get chatsUnban => 'Разбанить чат';

  @override
  String get badgesTitle => 'Бейджи';

  @override
  String get badgesSubtitle =>
      'Создание, удаление и выдача визуальных токенов аккаунтов.';

  @override
  String get badgesCreate => 'Создать бейдж';

  @override
  String get badgesNoResults => 'Бейджей пока нет.';

  @override
  String get badgeName => 'Название бейджа';

  @override
  String get badgeDescription => 'Описание';

  @override
  String get badgeIcon => 'Иконка или текст';

  @override
  String get badgeColor => 'HEX цвет';

  @override
  String get badgeAward => 'Выдать';

  @override
  String get badgeRevoke => 'Забрать';

  @override
  String get badgeDeleteConfirm => 'Удалить этот бейдж?';

  @override
  String get badgeUserId => 'ID пользователя';

  @override
  String get badgePreview => 'Превью';

  @override
  String get systemError => 'Что-то пошло не так';

  @override
  String get createdAt => 'Создан';

  @override
  String get membersCount => 'Участников';

  @override
  String get username => 'Username';

  @override
  String get displayName => 'Имя';

  @override
  String get email => 'Email';

  @override
  String get chatType => 'Тип';

  @override
  String get emptyDescription => 'Без описания';

  @override
  String get moderationSuccess => 'Действие выполнено';
}
