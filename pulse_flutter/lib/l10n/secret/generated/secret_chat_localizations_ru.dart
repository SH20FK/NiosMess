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

  @override
  String get inboxDraftLabel => 'Черновик:';

  @override
  String get inboxDeleted => 'Переписка удалена';

  @override
  String inboxDeleteNamed(String name) {
    return 'Удалить чат «$name»?';
  }

  @override
  String inboxLeaveNamed(String name) {
    return 'Покинуть «$name»?';
  }

  @override
  String get inboxRefreshFailed =>
      'Не удалось обновить список. Попробуйте ещё раз.';

  @override
  String get interactiveTitle => 'Создать';

  @override
  String get interactivePoll => 'Опрос';

  @override
  String get interactiveQuiz => 'Викторина';

  @override
  String get interactiveList => 'Общий список';

  @override
  String get interactiveTitleField => 'Название';

  @override
  String get interactiveQuestion => 'Вопрос';

  @override
  String get interactiveTitleRequired => 'Введите название';

  @override
  String get interactiveQuestionRequired => 'Введите вопрос';

  @override
  String get interactiveOptions => 'Варианты ответа';

  @override
  String get interactiveQuizOptions => 'Варианты ответа. Отметьте правильный';

  @override
  String get interactiveFieldRequired => 'Заполните поле';

  @override
  String get interactiveDuplicateOptions => 'Варианты не должны повторяться';

  @override
  String interactiveItemNumber(int number) {
    return 'Пункт $number';
  }

  @override
  String interactiveOptionNumber(int number) {
    return 'Вариант $number';
  }

  @override
  String get interactiveRemoveItem => 'Удалить пункт';

  @override
  String get interactiveRemoveOption => 'Удалить вариант';

  @override
  String get interactiveAddItem => 'Добавить пункт';

  @override
  String get interactiveAddOption => 'Добавить вариант';

  @override
  String get interactiveCorrectAnswer => 'Правильный ответ';

  @override
  String get interactiveMultiple => 'Несколько ответов';

  @override
  String get interactiveExplanation => 'Пояснение (необязательно)';

  @override
  String get interactiveExplanationHint => 'Появится после ответа';

  @override
  String get interactiveVotesVisible =>
      'Участники видят, кто за что проголосовал.';

  @override
  String get interactiveSend => 'Отправить';

  @override
  String get interactiveSendFailed =>
      'Не удалось отправить. Повторите отправку в чате.';

  @override
  String get interactiveSaveFailed =>
      'Не удалось сохранить. Повторите отправку.';

  @override
  String get interactiveVoters => 'Голоса';

  @override
  String get interactiveParticipant => 'Участник';

  @override
  String get interactiveClosed => 'Завершён';

  @override
  String get interactiveOpenPoll => 'Открытый опрос';

  @override
  String get interactiveQuizClosed => 'Викторина завершена';

  @override
  String get interactivePollClosed => 'Опрос завершён';

  @override
  String get interactiveQuizSingle => 'Викторина, один ответ';

  @override
  String get interactivePollMultiple => 'Открытый опрос, несколько ответов';

  @override
  String get interactivePollSingle => 'Открытый опрос, один ответ';

  @override
  String get interactiveCorrectAnswerLabel => 'Правильный ответ';

  @override
  String get interactiveItemReopened => 'Пункт снова открыт';

  @override
  String get interactiveItemCompleted => 'Пункт выполнен';

  @override
  String get interactiveQuizAnswer => 'Ответ на викторину';

  @override
  String get interactiveCorrect => 'Верно';

  @override
  String get interactiveIncorrect => 'Неверно';

  @override
  String get interactiveVoteEvent => 'Голос в опросе';

  @override
  String get interactiveVote => 'Голосовать';

  @override
  String get interactiveChangeVote => 'Изменить голос';

  @override
  String get interactiveVoteRevoked => 'Голос отозван';

  @override
  String get interactiveRevoke => 'Отозвать';

  @override
  String get interactiveLoadRetry => 'Не удалось загрузить. Повторить';

  @override
  String get interactiveLoading => 'Загружаю изменения…';

  @override
  String get interactiveAfterSend => 'Доступно после отправки';

  @override
  String get interactiveFinishList => 'Завершить список?';

  @override
  String get interactiveFinishPoll => 'Завершить голосование?';

  @override
  String get interactiveFinishBody =>
      'После этого участники не смогут менять ответы.';

  @override
  String get interactiveFinish => 'Завершить';

  @override
  String get interactiveFinishedEvent => 'Завершено';

  @override
  String get interactiveYourWrongAnswer => 'Ваш ответ, неверно';

  @override
  String get interactiveYourAnswer => 'Ваш ответ';

  @override
  String get interactiveSaving => 'Сохраняю…';

  @override
  String interactiveParticipantNumber(int id) {
    return 'Участник $id';
  }

  @override
  String interactiveCompletedCount(int count, int total) {
    return 'Выполнено $count из $total';
  }

  @override
  String interactiveVoterCount(int count) {
    return 'Проголосовали: $count';
  }

  @override
  String get attachmentPhotoVideo => 'Фото или видео';

  @override
  String get attachmentDocument => 'Файл или документ';

  @override
  String get attachmentAudio => 'Аудиозапись';

  @override
  String get attachmentRecordCircle => 'Записать видеокружок';

  @override
  String get recordCircleDesktopHint =>
      'Видеокружок: нажмите для записи, правая кнопка — микрофон';

  @override
  String get recordVoiceDesktopHint =>
      'Голосовое: нажмите для записи, правая кнопка — видео';

  @override
  String get recordSwitchVoice => 'Переключить на микрофон';

  @override
  String get recordSwitchCircle => 'Переключить на видеокружок';

  @override
  String get deliverySent => 'Отправлено';

  @override
  String get deliveryRead => 'Прочитано';

  @override
  String get webWorkspaceHint =>
      'Выберите чат слева. Ctrl + Alt + N — новая переписка.';

  @override
  String get videoPreview => 'Воспроизвести видео';

  @override
  String get webAutoDownload => 'Автоматически загружать медиа';

  @override
  String get webMotionTitle => 'Анимации и производительность';

  @override
  String get webDownloadStarted => 'Загрузка файла началась';

  @override
  String get pasteImageTitle => 'Отправить изображение?';

  @override
  String get pasteImageCaption => 'Подпись';

  @override
  String get pasteImageFailed => 'Не удалось прочитать изображение из буфера';

  @override
  String get pasteImageLimit =>
      'Можно вставить до 8 изображений общим размером до 40 МБ';

  @override
  String get pasteImageSendFailed =>
      'Не удалось сохранить вложение. Изображение осталось здесь — повторите отправку.';

  @override
  String pasteImageCount(int count) {
    return 'Осталось изображений: $count';
  }

  @override
  String get webStorageTitle => 'Данные в браузере';

  @override
  String get webStorageDescription =>
      'Браузер управляет местом для данных сайта. Объём диска и системные временные файлы здесь недоступны. Данные приложения можно удалить в настройках сайта в браузере; это также удалит локальные секретные переписки и очередь.';

  @override
  String get webStorageDrafts => 'Черновики обычных чатов';

  @override
  String get webStorageDraftsDescription =>
      'Сохранены в этом браузере. Секретные черновики хранятся отдельно.';

  @override
  String get callDevicesTitle => 'Звук и камера';

  @override
  String get callDevicesLocalHint =>
      'Проверка работает только на этом устройстве: звук и видео никуда не отправляются.';

  @override
  String get callDevicesUnavailable => 'Не удалось получить список устройств';

  @override
  String get callDevicesPermission =>
      'Не удалось открыть микрофон или камеру. Проверьте разрешения или выберите другое устройство.';

  @override
  String get callDevicesApplyFailed =>
      'Не удалось переключить устройства. Выберите доступное устройство и повторите.';

  @override
  String get callDeviceDefault => 'По умолчанию';

  @override
  String get callDeviceMicrophone => 'Микрофон';

  @override
  String get callDeviceCamera => 'Камера';

  @override
  String get callDeviceOutput => 'Наушники и динамики';

  @override
  String get callDeviceSpeak =>
      'Скажите что-нибудь: индикатор показывает уровень микрофона';

  @override
  String get callDeviceLevelUnavailable =>
      'Микрофон открыт. Это устройство не сообщает уровень сигнала.';

  @override
  String get callDeviceTest => 'Проверить микрофон и камеру';

  @override
  String get callDeviceTestSound => 'Проверить звук';

  @override
  String get callDeviceTestSystemSound => 'Проверить системный звук';

  @override
  String get callDeviceOutputUnavailable =>
      'Выбор этого выхода недоступен. Проверьте устройства и настройки звука браузера или системы.';

  @override
  String get callDeviceStart => 'Позвонить';

  @override
  String get callQualityReconnecting => 'Восстанавливаем связь…';

  @override
  String get callQualityMeasuring => 'Проверяем связь…';

  @override
  String get callQualityGood => 'Связь хорошая';

  @override
  String get callQualityFair => 'Связь нестабильна';

  @override
  String get callQualityPoor => 'Слабая связь';

  @override
  String get callQualityLatency => 'высокая задержка';

  @override
  String get callQualityLoss => 'теряются пакеты';

  @override
  String get callQualityJitter => 'данные приходят неравномерно';

  @override
  String get callQualityBandwidth => 'не хватает скорости сети';

  @override
  String get callQualityCpu => 'устройство не успевает обрабатывать видео';

  @override
  String get stickerHubSearch => 'Поиск по эмодзи и названиям наборов';

  @override
  String get stickerHubRecent => 'Недавние';

  @override
  String get stickerHubEmpty => 'Здесь пока нет стикеров';

  @override
  String get stickerHubEmptyHint =>
      'Выберите набор или создайте свой. Отправленные стикеры появятся в недавних.';

  @override
  String get stickerHubLoadError => 'Не удалось загрузить стикеры';

  @override
  String get stickerHubCreate => 'Создать набор';

  @override
  String get stickerHubAdd => 'Добавить стикеры';

  @override
  String get stickerHubDetails => 'О наборе';

  @override
  String get stickerHubEmoji => 'Эмодзи';

  @override
  String get stickerHubStickers => 'Стикеры';

  @override
  String get stickerHubNoResults => 'Ничего не найдено';

  @override
  String get chatDropFiles => 'Отпустите файлы, чтобы открыть предпросмотр';

  @override
  String get chatDropError =>
      'Не удалось прочитать файлы. Попробуйте добавить их через скрепку.';

  @override
  String get chatBatchTitle => 'Отправить вложения?';

  @override
  String get chatBatchAlbum => 'Собрать фотографии в альбом';

  @override
  String get chatBatchSeparate => 'Отправить отдельными файлами';

  @override
  String get chatBatchRemove => 'Убрать вложение';

  @override
  String get chatBatchLimit => 'Добавьте до 10 файлов общим размером до 100 МБ';

  @override
  String get chatAlbumOpen => 'Открыть альбом';

  @override
  String get chatAlbumPrevious => 'Предыдущее фото';

  @override
  String get chatAlbumNext => 'Следующее фото';

  @override
  String get callDeviceMissing => 'устройство недоступно';
}
