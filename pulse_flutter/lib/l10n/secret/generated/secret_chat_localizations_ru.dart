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

  @override
  String get noticeOpenChat => 'Открыть чат';

  @override
  String get noticeOpen => 'Открыть';

  @override
  String get noticeReadChat => 'Прочитать весь чат';

  @override
  String get noticeMarkAllRead => 'Прочитать всё';

  @override
  String get noticeTitle => 'Уведомления';

  @override
  String get noticeEmpty => 'Пока тихо';

  @override
  String get noticeEmptyHint =>
      'Здесь сохраняются сообщения и события этого аккаунта.';

  @override
  String get noticeClose => 'Закрыть';

  @override
  String get noticeClear => 'Очистить историю';

  @override
  String get noticePermissionGranted => 'Системные уведомления разрешены';

  @override
  String get noticePermissionMissing => 'Для push нужно разрешение системы';

  @override
  String get noticePermissionHint =>
      'Включите уведомления для NiosMess в настройках браузера или устройства.';

  @override
  String get noticeDeviceHint =>
      'Настройки действуют на этом устройстве. Уведомления в открытом чате не дублируются.';

  @override
  String get noticeMessages => 'Сообщения';

  @override
  String get noticeCalls => 'Входящие звонки';

  @override
  String get noticeActivity => 'Активность NiosGram';

  @override
  String get noticePreview => 'Показывать текст';

  @override
  String get noticePreviewHint =>
      'Секретные сообщения всегда скрыты в системных push.';

  @override
  String get noticeSound => 'Звук уведомлений';

  @override
  String get noticeSoundHint =>
      'Звук системных каналов также настраивается в ОС.';

  @override
  String get noticeMessagesChannel => 'Сообщения NiosMess';

  @override
  String get noticeCallsChannel => 'Звонки NiosMess';

  @override
  String get noticeUpdatesChannel => 'Обновления NiosMess';

  @override
  String get noticeIncomingCall => 'Входящий звонок';

  @override
  String get noticeIncomingVideo => 'Входящий видеозвонок';

  @override
  String get noticeAccept => 'Принять';

  @override
  String get noticeDecline => 'Отклонить';

  @override
  String get noticeNewMessage => 'Новое сообщение';

  @override
  String get noticeEncrypted => 'Зашифрованное сообщение';

  @override
  String get noticeBackground => 'Фоновая работа включена';

  @override
  String get noticeEconomy => 'Экономить заряд';

  @override
  String get noticeSoundTest => 'Проверить звук';

  @override
  String get noticeSoundTestHint => 'Тап, сообщение, успех и ошибка';

  @override
  String get noticeSyncFailed =>
      'Не удалось обновить push на сервере. Настройка сохранена; повторим при подключении.';

  @override
  String get noticeCopied => 'Скопировано';

  @override
  String get noticeUpdateDownloading => 'Загрузка обновления NiosMess';

  @override
  String get noticeUpdateReady => 'Обновление NiosMess готово';

  @override
  String get noticeUpdateTap => 'Нажмите для установки';

  @override
  String get noticeVersion => 'Версия';

  @override
  String get noticeInAppOnly =>
      'На этом устройстве доступны уведомления внутри приложения';

  @override
  String get noticePostLike => 'Реакция на вашу публикацию';

  @override
  String get noticePostComment => 'Комментарий к вашей публикации';

  @override
  String get noticeAttachment => 'Вложение';

  @override
  String get noticeReply => 'Ответить';

  @override
  String get noticeMarkRead => 'Отметить прочитанным';

  @override
  String get noticeReplyHint => 'Сообщение';

  @override
  String get noticeSend => 'Отправить';

  @override
  String get noticeSending => 'Отправка…';

  @override
  String get noticeReplyFailed =>
      'Не удалось отправить. Текст остался в поле — можно повторить.';

  @override
  String get noticeReplySaveFailed =>
      'Не удалось сохранить черновик. Текст остался в поле.';

  @override
  String get noticeDeviceRegistered => 'Устройство зарегистрировано для push';

  @override
  String get noticeDevicePending => 'Регистрация push ожидает подключения';

  @override
  String get noticeUiSoundsHint =>
      'Звуки нажатий и действий. Уведомления настраиваются отдельно.';

  @override
  String get noticeSilentMessages => 'Сообщения без звука';

  @override
  String get settingsV2Appearance => 'Оформление';

  @override
  String get settingsV2AppearanceHint =>
      'Тема, палитра, текст и плотность интерфейса';

  @override
  String get settingsV2Chats => 'Чаты и звонки';

  @override
  String get settingsV2ChatsHint => 'Ввод, реакции, микрофон и камера';

  @override
  String get settingsV2Notifications => 'Уведомления и звуки';

  @override
  String get settingsV2NotificationsHint =>
      'Push, превью сообщений, звук и вибрация';

  @override
  String get settingsV2Privacy => 'Приватность и безопасность';

  @override
  String get settingsV2PrivacyHint => 'Видимость данных, доступ и шифрование';

  @override
  String get settingsV2Storage => 'Данные и память';

  @override
  String get settingsV2StorageHint => 'Кэш, загрузка медиа и данные устройства';

  @override
  String get settingsV2Motion => 'Анимации и энергосбережение';

  @override
  String get settingsV2MotionHint => 'Стикеры, эмодзи и производительность';

  @override
  String get settingsV2Language => 'Язык и время';

  @override
  String get settingsV2LanguageHint => 'Язык интерфейса и часовой пояс';

  @override
  String get settingsV2About => 'Помощь и о приложении';

  @override
  String get settingsV2AboutHint => 'Версия, обновления, справка и документы';

  @override
  String get settingsV2GroupCommunication => 'Общение и оформление';

  @override
  String get settingsV2GroupPrivacy => 'Приватность и данные';

  @override
  String get settingsV2GroupApplication => 'Приложение';

  @override
  String get settingsV2Search => 'Поиск настроек';

  @override
  String get settingsV2SearchEmpty =>
      'Найдите параметр по названию или действию';

  @override
  String get settingsV2SearchNone =>
      'Ничего не найдено. Попробуйте другое слово.';

  @override
  String get settingsV2AccountHint => 'Профиль и управление аккаунтом';

  @override
  String get settingsV2NiosId => 'Управление Nios ID';

  @override
  String get settingsV2Qr => 'Мой QR-код';

  @override
  String get settingsV2Share => 'Поделиться профилем';

  @override
  String get settingsV2More => 'Действия профиля';

  @override
  String get settingsV2Advanced => 'Дополнительно';

  @override
  String get settingsV2GeometryHint =>
      'Скругления карточек и системных панелей';

  @override
  String get settingsV2Density => 'Плотность интерфейса';

  @override
  String get settingsV2Graphics => 'Производительность';

  @override
  String get settingsV2OptimizeHint =>
      'Упрощает визуальные эффекты для более плавной работы';

  @override
  String get settingsV2ChatAnimations => 'Анимации в чатах';

  @override
  String get settingsV2ChatAnimationsHint =>
      'Выберите, какие эффекты воспроизводить автоматически';

  @override
  String get settingsV2Stickers => 'Анимация стикеров';

  @override
  String get settingsV2StickersHint => 'Воспроизводить стикеры в сообщениях';

  @override
  String get settingsV2Emoji => 'Анимированные эмодзи';

  @override
  String get settingsV2EmojiHint => 'Воспроизводить эмодзи в сообщениях';

  @override
  String get settingsV2Off => 'Отключено';

  @override
  String get settingsV2Reset => 'Сбросить локальные настройки';

  @override
  String get settingsV2ResetHint =>
      'Вернуть оформление и поведение по умолчанию. История сообщений сохранится.';

  @override
  String get settingsV2LockTimeout => 'Автоблокировка';

  @override
  String get settingsV2LockTimeoutHint =>
      'Когда блокировать приложение после сворачивания';

  @override
  String get settingsV2BiometricFailure => 'Не удалось подтвердить личность';

  @override
  String get settingsV2ReadReceipts => 'Отчёты о прочтении';

  @override
  String get settingsV2ReadReceiptsHint =>
      'Показывать, когда вы прочитали сообщение';

  @override
  String get settingsV2Typing => 'Индикатор набора текста';

  @override
  String get settingsV2TypingHint => 'Показывать собеседнику, что вы печатаете';

  @override
  String get settingsV2ReadSaveFailed =>
      'Не удалось сохранить настройки прочтения';

  @override
  String get settingsV2TypingSaveFailed =>
      'Не удалось сохранить настройки набора';

  @override
  String get settingsV2StorageDetails => 'Использование памяти';

  @override
  String get settingsV2StorageDetailsHint =>
      'Загруженные медиа и временные файлы';

  @override
  String get settingsV2AutoDownload => 'Автозагрузка медиа';

  @override
  String get settingsV2AutoDownloadHint =>
      'Выберите, когда загружать фото, видео и голосовые';

  @override
  String get settingsV2Wifi => 'Через Wi-Fi';

  @override
  String get settingsV2MobileData => 'Через мобильную сеть';

  @override
  String get settingsV2MobileDataHint => 'Может расходовать мобильный трафик';

  @override
  String get settingsV2SecretCache => 'Кэш секретных чатов';

  @override
  String get settingsV2SecretCacheHint =>
      'Расшифрованные сообщения на этом устройстве';

  @override
  String get settingsV2ClearSecretCache => 'Очистить кэш секретных чатов';

  @override
  String get settingsV2Diagnostics => 'Диагностика устройства';

  @override
  String get settingsV2DiagnosticsHint => 'Сведения о системе и оборудовании';

  @override
  String get settingsV2StorageImages => 'Фото';

  @override
  String get settingsV2StorageVideos => 'Видео';

  @override
  String get settingsV2StorageAudio => 'Аудио';

  @override
  String get settingsV2StorageFiles => 'Файлы';

  @override
  String get settingsV2StorageStickers => 'Стикеры';

  @override
  String get settingsV2StorageAvatars => 'Аватары';

  @override
  String get settingsV2StorageDrafts => 'Черновики';

  @override
  String get settingsV2StorageOther => 'Прочее';

  @override
  String get settingsV2SecurityLink => 'Настройки безопасности';

  @override
  String get settingsV2SecurityLinkHint =>
      'Сессии, блокировка приложения и защита аккаунта';

  @override
  String get settingsV2ProfileCopied => 'Ссылка на профиль скопирована';

  @override
  String get settingsV2IdCopied => 'Nios ID скопирован';

  @override
  String get settingsV2Economy => 'Экономный';

  @override
  String get settingsV2Reliable => 'Надёжный';

  @override
  String get settingsV2BackgroundOff =>
      'Фоновое соединение отключено. Push продолжает работать через FCM.';

  @override
  String get settingsV2Preview => 'Показывать текст';

  @override
  String get settingsV2StorageError => 'Не удалось загрузить данные хранилища';

  @override
  String get settingsV2ClearCategory => 'Очистить файлы этой категории?';

  @override
  String get settingsV2ClearCategoryHint =>
      'Файлы выбранной категории будут удалены из локального кэша.';

  @override
  String get settingsV2SecretCacheConfirm =>
      'Все расшифрованные сообщения секретных чатов на этом устройстве будут удалены. Это действие необратимо.';

  @override
  String get settingsV2ResetConfirm => 'Сбросить локальные настройки?';

  @override
  String get settingsV2ResetBody =>
      'Сбросятся оформление, язык, звуки, уведомления и другие настройки этого приложения. Чаты, файлы, ключи и серверные настройки приватности останутся.';

  @override
  String get settingsV2ResetDone => 'Локальные настройки сброшены';

  @override
  String get settingsV2ResetFailed => 'Не удалось сбросить настройки';

  @override
  String get pickerClearSearch => 'Очистить поиск';

  @override
  String get pickerFaces => 'Смайлы';

  @override
  String get pickerAnimals => 'Природа';

  @override
  String get pickerFood => 'Еда';

  @override
  String get pickerActivities => 'Занятия';

  @override
  String get pickerTravel => 'Путешествия';

  @override
  String get pickerObjects => 'Предметы';

  @override
  String get pickerSymbols => 'Символы';

  @override
  String get pickerFlags => 'Флаги';

  @override
  String get pickerSearchEmoji => 'Поиск эмодзи';

  @override
  String get pickerNoRecents => 'Здесь появятся недавние эмодзи';

  @override
  String get pickerCustom => 'Свои';

  @override
  String get pickerCompact => 'Свернуть';

  @override
  String get pickerLibrary => 'Библиотека';

  @override
  String get pickerSearchPacks => 'Поиск наборов';

  @override
  String get pickerManage => 'Управление наборами';

  @override
  String get customEmojiTitle => 'Кастомные эмодзи';

  @override
  String get customContinue => 'Продолжить';

  @override
  String get customCreateSet => 'Создать набор эмодзи';

  @override
  String get customSetTitle => 'Название';

  @override
  String get customSetName => 'Имя набора латиницей';

  @override
  String get customAddSet => 'Добавить набор эмодзи';

  @override
  String get customAddEmoji => 'Добавить эмодзи';

  @override
  String get customRemoveSet => 'Убрать из моих наборов';

  @override
  String get customShortcode => 'Короткое имя: латиница, цифры, _';

  @override
  String get customFileTooLarge => 'Выберите изображение размером до 512 КБ';

  @override
  String get customTooManyFrames => 'Слишком много кадров в эмодзи';

  @override
  String get customEmptySet => 'В этом наборе пока нет эмодзи';

  @override
  String get auditSystemLanguage => 'Системный';

  @override
  String get auditPostPublished => 'Публикация добавлена';

  @override
  String get auditCommentSend => 'Отправить комментарий';

  @override
  String get auditCommentDeleteTitle => 'Удалить комментарий?';

  @override
  String get auditCommentDeleteBody => 'Ответы останутся в обсуждении.';

  @override
  String get auditCommentLoadMore => 'Загрузить ещё комментарии';

  @override
  String get auditCommentHint => 'Комментарий или вопрос @ai';

  @override
  String get auditCommentEditing => 'Редактирование комментария';

  @override
  String auditCommentReply(String name) {
    return 'Ответ $name';
  }

  @override
  String get auditCommentReported => 'Жалоба на качество отправлена';

  @override
  String get auditCommentAuthor => 'Автор';

  @override
  String get auditCommentChannel => 'Канал';

  @override
  String get auditPostMedia => 'Медиафайл';

  @override
  String get auditPostQuiz => 'Викторина';

  @override
  String get auditPostPoll => 'Опрос';

  @override
  String get auditPlusSignIn => 'Войдите через NiosID';

  @override
  String get auditPlusCatalogUnavailable => 'Тарифы недоступны';

  @override
  String get auditPlusCatalogLoadFailed =>
      'Не удалось загрузить тарифы. Активация купленной ссылки доступна ниже.';

  @override
  String get auditPlusActivationLinkInvalid =>
      'Вставьте полную ссылку активации из заказа';

  @override
  String get auditPlusAccountChanged =>
      'Аккаунт изменился. Обновите тарифы перед покупкой.';

  @override
  String get auditPlusProductUnavailable =>
      'Адрес товара недоступен. Попробуйте обновить тарифы.';

  @override
  String get auditPlusOpenFailed => 'Не удалось открыть FunPay';

  @override
  String get auditPlusNativeOnly =>
      'Покупка и активация доступны в мобильном и десктопном NiosMess.';

  @override
  String get auditPlusSupportedPlatforms =>
      'Покупка и активация пока доступны в приложениях для Android, Windows и Linux.';

  @override
  String get auditPlusPurchaseTitle => 'Покупка и продление';

  @override
  String get auditPlusPromoLimit => 'Один раз на аккаунт, IP и устройство';

  @override
  String get auditPlusBuy => 'Купить';

  @override
  String get auditPlusSalesPending =>
      'Продажи ещё не открыты. Купленную ссылку можно активировать ниже.';

  @override
  String get auditPlusRefreshPlans => 'Обновить тарифы';

  @override
  String get auditPlusAlreadyPurchased => 'Уже купили NiosPlus?';

  @override
  String get auditPlusActivationLink => 'Ссылка активации';

  @override
  String get auditPlusCheckSubscription => 'Проверить подписку';

  @override
  String get auditPlusContinuePurchase => 'Перейти к покупке';

  @override
  String get auditPlusPurchaseInstructions =>
      'На FunPay вы получите одноразовую ссылку. Откройте её в NiosMess для активации.';

  @override
  String get auditPlusFeeNotice =>
      'К цене добавляется комиссия платёжного шлюза. Итоговая сумма будет показана на FunPay перед оплатой.';

  @override
  String get auditPlusDeviceHashConsent =>
      'Согласен на передачу SHA-256 хеша устройства при активации';

  @override
  String get auditPlusDeviceHashPurpose =>
      'Нужен для защиты покупки. Для промотарифа учитываются также аккаунт и IP.';

  @override
  String get auditPlusOpenFunPay => 'Перейти на FunPay';

  @override
  String get auditAppLockCheckFailed =>
      'Не удалось проверить блокировку приложения. Попробуйте ещё раз.';

  @override
  String get auditAppLockTitle => 'NiosMess заблокирован';

  @override
  String get auditAppLockDescription =>
      'Подтвердите личность для доступа к сообщениям и данным';

  @override
  String get auditAppLockAuthenticating => 'Проверка…';

  @override
  String get auditAppLockUnlock => 'Разблокировать';

  @override
  String get auditAppLockMinimize => 'Свернуть';

  @override
  String get savedMessagesTitle => 'Избранное';

  @override
  String get savedMessagesSubtitle => 'Заметки и сохранённые сообщения';

  @override
  String get niosgramPageLoadFailed =>
      'Не удалось загрузить следующие публикации';

  @override
  String get niosgramVideoTitle => 'Видео';

  @override
  String get niosgramVideoUnavailable => 'Не удалось открыть это видео';

  @override
  String get niosgramPlayVideo => 'Открыть видео';

  @override
  String get niosgramSavedTitle => 'Сохранённые публикации';

  @override
  String get niosgramSavedLocalNotice =>
      'Сохранено на этом устройстве для вашего аккаунта. Копии могут устареть и удалятся при выходе из аккаунта.';

  @override
  String get niosgramSavedEmpty => 'Пока нет сохранённых публикаций';

  @override
  String get niosgramRemoveSaved => 'Убрать из сохранённого';

  @override
  String get niosgramSaveFailed =>
      'Не удалось изменить сохранённые публикации. Попробуйте ещё раз.';

  @override
  String get niosgramDraftSaveFailed =>
      'Не удалось сохранить черновик. Изменения остались здесь — попробуйте ещё раз перед выходом.';

  @override
  String get niosgramDraftRestoreFailed =>
      'Не удалось восстановить черновик. Он не удалён.';

  @override
  String get niosgramScrollTop => 'В начало ленты';

  @override
  String get niosgramLikeAction => 'Нравится';

  @override
  String get niosgramDislikeAction => 'Показывать меньше такого';

  @override
  String get niosgramCommentAction => 'Комментарии';

  @override
  String get niosgramShareAction => 'Поделиться публикацией';

  @override
  String get niosgramSaveAction => 'Сохранить публикацию';

  @override
  String get niosgramPublishToFeed => 'Публикация в NiosGram';

  @override
  String get niosgramAnonymousPoll => 'Анонимный опрос';

  @override
  String get niosgramAnonymousQuiz => 'Анонимная викторина';

  @override
  String get niosgramRemovePoll => 'Убрать опрос';

  @override
  String get niosgramSendToChat => 'Отправить в чат';

  @override
  String get niosgramCopyLink => 'Скопировать ссылку';

  @override
  String get niosgramShareExternal => 'Поделиться в другом приложении';

  @override
  String get niosgramNoChats => 'Нет доступных чатов';

  @override
  String get niosgramLinkAddedToChat =>
      'Добавлено в чат. Статус отправки можно посмотреть там.';

  @override
  String get niosgramSendLinkFailed =>
      'Не удалось добавить ссылку в чат. Попробуйте ещё раз.';

  @override
  String get niosgramUnsupportedMedia =>
      'Выберите фото JPG, PNG, WebP или GIF либо видео MP4, MOV или WebM.';

  @override
  String get niosgramMediaTooLarge => 'Размер файла не должен превышать 25 МБ.';

  @override
  String get niosgramPhotoTooLarge =>
      'Размер фото после сжатия не должен превышать 5 МБ.';

  @override
  String get niosgramVideoAlone =>
      'Видео публикуется отдельно, без других вложений.';

  @override
  String get niosgramVideoDurationLimit =>
      'Выберите видео длительностью до 10 секунд.';

  @override
  String get niosgramVideoDurationFailed =>
      'Не удалось проверить длительность видео. Попробуйте другой файл или устройство.';

  @override
  String get niosgramOpenVideoExternal => 'Открыть видео в другом приложении';

  @override
  String get niosgramTextTooShort =>
      'В текстовой публикации должно быть не меньше 10 символов.';

  @override
  String get niosgramReadMore => 'Читать дальше';

  @override
  String get niosgramReadLess => 'Свернуть';

  @override
  String get niosgramPostStatusUnknown =>
      'Сервер не подтвердил публикацию. Проверьте ленту перед повтором; черновик сохранён.';

  @override
  String get niosgramPublishedCleanupFailed =>
      'Публикация отправлена, но очистить её черновик не удалось.';
}
