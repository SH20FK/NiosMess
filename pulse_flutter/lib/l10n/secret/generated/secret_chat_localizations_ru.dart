// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'secret_chat_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class SecretChatLocalizationsRu extends SecretChatLocalizations {
  SecretChatLocalizationsRu([String locale = 'ru']) : super(locale);

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
}
