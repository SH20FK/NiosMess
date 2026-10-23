// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'secret_chat_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class SecretChatLocalizationsRu extends SecretChatLocalizations {
  SecretChatLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get updateIntegrityFailed =>
      'Файл обновления повреждён или загружен не полностью. Скачайте его ещё раз.';

  @override
  String get callMediaUnavailable =>
      'Не удалось включить микрофон или камеру. Проверьте разрешения приложения и попробуйте снова.';

  @override
  String get callConnectionFailed =>
      'Не удалось соединить звонок. Попробуйте ещё раз.';

  @override
  String get callConnectionLost => 'Соединение прервалось. Позвоните ещё раз.';

  @override
  String get callSignalingFailed =>
      'Не удалось установить защищённое соединение звонка. Попробуйте ещё раз.';

  @override
  String get callSoloTimeout => 'Звонок завершён: никто не присоединился.';

  @override
  String get callDurationLimit => 'Достигнут лимит длительности звонка.';

  @override
  String get secretTitle => 'Секретный чат';

  @override
  String get secretProtected => 'Переписка защищена';

  @override
  String get secretDescription =>
      'Сообщения доступны только на этих двух устройствах. Всё сохраняется на вашем устройстве автоматически.';

  @override
  String get secretQueued => 'Сообщения сохранены и отправятся автоматически';

  @override
  String get secretPreparing => 'Готовим защищённое соединение';

  @override
  String get secretUpdateRequired =>
      'Собеседнику нужно обновить приложение. Сообщения сохранены.';

  @override
  String get secretKeyChanged => 'Изменился ключ собеседника';

  @override
  String get secretKeyChangedBody =>
      'Сообщения сохранены на устройстве. Подтвердите новый ключ, чтобы продолжить доставку.';

  @override
  String get secretAcceptKey => 'Продолжить с новым ключом';

  @override
  String get secretOtherDevice => 'Этот чат открыт на другом устройстве';

  @override
  String get secretSignatureInvalid =>
      'Не удалось проверить подпись. Доставка приостановлена.';

  @override
  String get secretAdvanced => 'Проверить защиту';

  @override
  String get secretCompare =>
      'Для ручной проверки код и отпечаток должны совпасть на обоих устройствах. Это дополнительная проверка — для обычной переписки она не нужна.';

  @override
  String get secretCodesMatch => 'Коды совпадают';

  @override
  String get secretVerified => 'Код проверен';

  @override
  String get secretUnavailable =>
      'Сообщение пока недоступно на этом устройстве';

  @override
  String get secretSaveFailed =>
      'Не удалось сохранить сообщение. Текст остался в поле ввода.';

  @override
  String get secretCreateFailed =>
      'Не удалось открыть секретный чат. Попробуйте ещё раз.';

  @override
  String get secretAttachmentSaveFailed =>
      'Не удалось сохранить вложение. Повторите отправку.';

  @override
  String get secretLocalOnly =>
      'Содержимое секретного чата не отправляется внешнему ИИ.';

  @override
  String get secretLogoutWarning =>
      'При выходе секретная история и неотправленные сообщения на этом устройстве будут удалены. История собеседника сохранится.';

  @override
  String get secretRetry => 'Повторить отправку';

  @override
  String get secretDeleteWarning =>
      'История, вложения и неотправленные сообщения на этом устройстве будут удалены. История собеседника сохранится.';

  @override
  String get secretVerificationFailed =>
      'Не удалось сохранить проверку ключа. Сообщения не удалены.';

  @override
  String get modalDeleteChatBody =>
      'Удалить эту переписку из вашего списка чатов?';

  @override
  String get modalSessionTitle => 'Завершить сессию?';

  @override
  String modalSessionBody(String device) {
    return 'Устройство «$device» будет отключено от вашего аккаунта.';
  }

  @override
  String get modalSessionConfirm => 'Завершить';

  @override
  String get modalSessionsTitle => 'Завершить все остальные сессии?';

  @override
  String get modalSessionsBody =>
      'Все устройства, кроме этого, будут отключены от вашего аккаунта.';

  @override
  String get modalSessionsConfirm => 'Завершить все';

  @override
  String get inboxActions => 'Действия';

  @override
  String get backgroundsPaused => 'Фоны временно отключены';

  @override
  String get inboxChatType => 'Тип чата';

  @override
  String get inboxCreateMenu => 'Создать…';

  @override
  String get inboxComposeTitle => 'Начать общение';

  @override
  String get inboxComposePersonHint =>
      'Выберите собеседника или найдите по @username';

  @override
  String get inboxComposeGroupHint => 'Общий чат с несколькими участниками';

  @override
  String get inboxComposeChannelHint => 'Публикации для ваших подписчиков';

  @override
  String get inboxComposeSecretHint =>
      'Личная переписка со сквозным шифрованием';

  @override
  String get inboxJoinLink => 'Вступить по ссылке';

  @override
  String get inboxJoinLinkHint => 'Откройте приглашение в группу или канал';

  @override
  String get inboxEncryptedPreview => 'Зашифрованное сообщение';

  @override
  String get inboxNoUnread => 'Всё прочитано';

  @override
  String get inboxCategoryEmpty => 'В этой категории пока нет чатов';

  @override
  String get inboxFilterResetHint =>
      'Выберите «Все», чтобы вернуться ко всем чатам';

  @override
  String get inboxSearchEmpty => 'Ничего не найдено';

  @override
  String get inboxSearchEmptyHint => 'Попробуйте изменить поисковый запрос';

  @override
  String get inboxWaitingToSend => 'Ожидает отправки';

  @override
  String get inboxSendFailed => 'Не отправлено — повторите в чате';

  @override
  String get inboxDraftSemantics => 'Черновик';
}
