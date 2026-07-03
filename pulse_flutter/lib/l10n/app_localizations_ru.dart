// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'NiosMess';

  @override
  String get tabChats => 'Чаты';

  @override
  String get tabCalls => 'Звонки';

  @override
  String get tabContacts => 'Контакты';

  @override
  String get tabProfile => 'Профиль';

  @override
  String get commonContinue => 'Продолжить';

  @override
  String get commonSkip => 'Пропустить';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonOk => 'ОК';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonPreview => 'Открыть';

  @override
  String get commonSearch => 'Поиск';

  @override
  String get commonSystem => 'Системная';

  @override
  String get commonLight => 'Светлая';

  @override
  String get commonDark => 'Тёмная';

  @override
  String get commonDismiss => 'Закрыть';

  @override
  String get commonAutomatic => 'Автоматически';

  @override
  String get commonManual => 'Вручную';

  @override
  String get commonLoading => 'Загрузка...';

  @override
  String get commonNoDescription => 'Публичное описание пока не добавлено.';

  @override
  String commonFailed(Object error) {
    return 'Ошибка: $error';
  }

  @override
  String get commonPasteFromClipboard => 'Вставить из буфера';

  @override
  String get commonDiscardChanges => 'Отменить изменения?';

  @override
  String get commonDiscardChangesDesc =>
      'У вас есть несохранённые изменения, которые будут потеряны.';

  @override
  String get commonDiscardChangesConfirm => 'Отменить';

  @override
  String get splashTagline => 'НАШ мессенджер';

  @override
  String get splashGraphicsOptimization => 'Оптимизация графики...';

  @override
  String get loginTitle => 'С возвращением';

  @override
  String get loginSubtitle => 'Войдите по email или username.';

  @override
  String get loginIdentifierLabel => 'Email или username';

  @override
  String get loginIdentifierError => 'Введите email или username';

  @override
  String get loginPasswordLabel => 'Пароль';

  @override
  String get loginPasswordError => 'Минимум 4 символа';

  @override
  String get loginForgotPassword => 'Забыли пароль?';

  @override
  String get loginSubmit => 'Войти';

  @override
  String get loginSubmitting => 'Входим...';

  @override
  String get loginCreateAccount => 'Создать аккаунт';

  @override
  String get loginFailed => 'Не удалось войти';

  @override
  String get twoFaTitle => 'Проверка безопасности';

  @override
  String get twoFaHeroTitle => 'Введите код 2FA';

  @override
  String get twoFaHeroSubtitle => 'Мы отправили 6-значный код на вашу почту.';

  @override
  String get twoFaCodeLabel => 'Код подтверждения';

  @override
  String get twoFaCodeError => 'Введите 6 цифр';

  @override
  String get twoFaVerify => 'Подтвердить код';

  @override
  String get twoFaVerifying => 'Проверяем...';

  @override
  String get twoFaProtected => 'Защищённый вход';

  @override
  String get twoFaExpires => 'Код действует недолго';

  @override
  String get twoFaHint =>
      'Совет: вставьте код целиком, пробелы будут проигнорированы.';

  @override
  String get twoFaFailed => 'Не удалось подтвердить 2FA';

  @override
  String get registerTitle => 'Создать аккаунт';

  @override
  String get registerEmailLabel => 'Email';

  @override
  String get registerEmailError => 'Введите корректный email';

  @override
  String get registerUsernameLabel => 'Username';

  @override
  String get registerUsernameError => 'Минимум 3 символа';

  @override
  String get registerDisplayNameLabel => 'Отображаемое имя';

  @override
  String get registerDisplayNameError => 'Минимум 2 символа';

  @override
  String get registerPasswordLabel => 'Пароль';

  @override
  String get registerPasswordError => 'Минимум 8 символов';

  @override
  String get registerSubmit => 'Создать аккаунт';

  @override
  String get registerSubmitting => 'Создаём...';

  @override
  String get registerFailed => 'Не удалось создать аккаунт(';

  @override
  String get verifyEmailTitle => 'Подтвердите почту';

  @override
  String get verifyEmailCodeLabel => '6-значный код';

  @override
  String get verifyEmailCodeError => 'Введите 6 цифр';

  @override
  String get verifyEmailSubmit => 'Подтвердить';

  @override
  String get verifyEmailSubmitting => 'Подтверждаем...';

  @override
  String get verifyEmailDone => 'Готово';

  @override
  String get setupWelcomeTitle => 'Приятно познакомиться)!';

  @override
  String get setupWelcomeBody =>
      'Давайте быстро настроим NiosMess для вас.\nЭто займёт пару секунд.';

  @override
  String get setupLanguageTitle => 'Выберите ваш язык';

  @override
  String get setupTimezoneTitle => 'Ваш часовой пояс';

  @override
  String get setupTimezoneUseDevice =>
      'Используется текущий часовой пояс устройства';

  @override
  String get setupTimezoneChooseManual => 'Можешь сам выбрать';

  @override
  String get setupStartMessaging => 'Напиши кому то';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageRussianNative => 'Русский';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profilePublicView => 'Это ваш профиль';

  @override
  String get profilePublicProfile => 'Профиль';

  @override
  String get profileMessage => 'Написать';

  @override
  String get profileCall => 'Звонок';

  @override
  String get profileVideo => 'Видео';

  @override
  String get profileAbout => 'О профиле';

  @override
  String get profileDisplayName => 'Имя';

  @override
  String get profileUsername => 'Username';

  @override
  String get profileDescription => 'Описание';

  @override
  String get profilePreferences => 'Предпочтения';

  @override
  String get profileMyProfile => 'Мой профиль';

  @override
  String get profileQuickSettings => 'Быстрые настройки';

  @override
  String get profileDoNotDisturb => 'Не беспокоить';

  @override
  String get profileDoNotDisturbSubtitle =>
      'Выключить push-уведомления на этом устройстве';

  @override
  String get profileHideOnline => 'Спрятать онлайн';

  @override
  String get profileHideOnlineSubtitle => 'Сделать онлайн менее заметным';

  @override
  String get profileStorage => 'Хранилище';

  @override
  String profileStorageUsed(Object used, Object total) {
    return 'Занято $used из $total';
  }

  @override
  String get profileAccountSection => 'Аккаунт';

  @override
  String get profileDangerZone => 'Тут лучше аккуратно трогать';

  @override
  String get profileAppearance => 'Внешний вид';

  @override
  String get profileAppearanceSubtitle => 'Тема, цвета, плотность';

  @override
  String get profileHaptics => 'Вибрация';

  @override
  String get profileHapticsSubtitle =>
      'Отклик на нажатия и элементы управления';

  @override
  String get profileAccount => 'Аккаунт';

  @override
  String get profileAccountSubtitle => 'Профиль, пароль, сессии';

  @override
  String get profilePrivacy => 'Приватность';

  @override
  String get profilePrivacySubtitle => 'Видимость и разрешения';

  @override
  String get profileHelp => 'Помощь';

  @override
  String get profileHelpSubtitle => 'FAQ, поддержка, контакты';

  @override
  String get profileSession => 'Сессия';

  @override
  String get profileLogoutSubtitle => 'Выйти только на этом устройстве.';

  @override
  String get profileLogout => 'Выйти';

  @override
  String get profileEdit => 'Редактировать профиль';

  @override
  String get profileThemeStudio => 'Редактор тем';

  @override
  String get profileGuestName => 'Гость';

  @override
  String get profileGuestUsername => 'guest';

  @override
  String get profileDefaultBio => 'Пользователь NiosMess';

  @override
  String get appearanceTitle => 'Внешний вид';

  @override
  String get appearanceStudioTitle => 'Редактор тем';

  @override
  String get appearanceStudioSubtitle =>
      'Настройте палитру, тему, плотность и посмотрите как оно выглядит.';

  @override
  String get appearancePreviewTitle => 'От так щас выглядит';

  @override
  String get appearancePreviewSubtitle =>
      'Компактный взгляд на текущий интерфейс.';

  @override
  String get appearancePreviewChat => 'Превью чата';

  @override
  String get appearanceIncomingPreview => 'Пример входящего сообщения';

  @override
  String get appearanceAccentPreview => 'Превью акцентного цвета';

  @override
  String get appearanceThemeMode => 'Выбор темы';

  @override
  String get appearanceModeSystemSubtitle => 'Оставить системным';

  @override
  String get appearanceModeLightSubtitle => 'Светлый режимчек';

  @override
  String get appearanceModeDarkSubtitle => 'Тёмный режимчек';

  @override
  String get appearanceAccentPalette => 'Акцентная палитра';

  @override
  String get appearanceAccentPaletteSubtitle =>
      'Material 3 строит всю цветовую систему из этого цвета.';

  @override
  String get appearanceMaterialVariant => 'Material-вариант';

  @override
  String get appearanceInteraction => 'Взаимодействие';

  @override
  String get appearanceInteractionSubtitle =>
      'Поведение, регион и предпочтения по отклику.';

  @override
  String get appearanceCompactMode => 'Компактный режим';

  @override
  String get appearanceCompactModeSubtitle =>
      'Более плотные отступы в чатах и списках';

  @override
  String get appearanceDarkCallBackdrop => 'Тёмный фон звонка';

  @override
  String get appearanceDarkCallBackdropSubtitle =>
      'Более тёмный стиль на экране активного звонка';

  @override
  String get appearanceHapticsSubtitle => 'Отклик на чипы, кнопки и строки';

  @override
  String get appearanceSoundEffects => 'Звуковые эффекты';

  @override
  String get appearanceSoundEffectsSubtitle =>
      'Звуки сообщений, звонков и навигации';

  @override
  String get appearanceSoundVolume => 'Громкость звуков';

  @override
  String get appearanceSoundVolumeSubtitle =>
      'Громкость кликов интерфейса, сообщений и звонков';

  @override
  String appearanceSoundVolumeValue(int percent) {
    return '$percent%';
  }

  @override
  String get appearanceLanguageRegion => 'Язык и регион';

  @override
  String get appearanceLanguageRegionSubtitle =>
      'Язык приложения, часовой пояс и региональный формат';

  @override
  String get appearancePersonalizationTitle => 'Оформление и темы';

  @override
  String get appearancePersonalizationSubtitle =>
      'Material 3-палитры, мягкая дымка акцентных цветов и ручная настройка визуального ритма.';

  @override
  String get appearancePaletteTitle => 'Палитра';

  @override
  String get appearancePaletteSubtitle =>
      'Выберите акцентные цвета для интерфейса, текста и кнопок';

  @override
  String get appearanceDensityTitle => 'Плотность интерфейса';

  @override
  String get appearanceDensitySubtitle =>
      'Влияет на размер превью, палитр и визуальный ритм экрана';

  @override
  String get appearanceDensitySoft => 'Мягкая';

  @override
  String get appearanceDensityRich => 'Насыщенная';

  @override
  String get appearanceDensityExpressive => 'Выразительная';

  @override
  String get appearanceThemeParamsTitle => 'Параметры темы';

  @override
  String get appearanceThemeParamsSubtitle =>
      'Системные переключатели Material 3';

  @override
  String get appearanceDynamicColors => 'Динамические цвета';

  @override
  String get appearanceDynamicColorsSubtitle =>
      'Использовать более выразительную тональную схему';

  @override
  String get appearanceDarkTheme => 'Тёмная тема';

  @override
  String get appearanceDarkThemeSubtitle =>
      'Переключать светлую и тёмную Material 3 тему вручную';

  @override
  String get appearanceLabelLight => 'Светлая';

  @override
  String get appearanceLabelDark => 'Тёмная';

  @override
  String get appearanceLabelAmethyst => 'Аметист';

  @override
  String get appearanceLabelLagoon => 'Лагуна';

  @override
  String get appearanceLabelMeadow => 'Луг';

  @override
  String get appearanceLabelEmber => 'Янтарь';

  @override
  String get appearanceLabelOrchid => 'Орхидея';

  @override
  String get appearanceLabelSlate => 'Сланец';

  @override
  String get appearanceLabelSky => 'Небо';

  @override
  String get appearanceLabelRose => 'Роза';

  @override
  String get languageRegionTitle => 'Язык и регион';

  @override
  String get languageRegionSubtitle =>
      'Выберите язык приложения и способ отображения времени.';

  @override
  String get languageRegionAppLanguage => 'Язык приложения';

  @override
  String get languageRegionUseSystemLanguage => 'Использовать системный язык';

  @override
  String get languageRegionTimeZone => 'Часовой пояс';

  @override
  String get languageRegionTimeZoneMode => 'Режим часового пояса';

  @override
  String get languageRegionCurrentTime => 'Текущее время в приложении';

  @override
  String get languageRegionSelectTimeZone => 'Выбрать часовой пояс';

  @override
  String get languageRegionSearchTimeZones => 'Поиск часовых поясов';

  @override
  String get settingsAccountTitle => 'Аккаунт';

  @override
  String get settingsCenterTitle => 'Центр настроек';

  @override
  String get settingsCenterSubtitle =>
      'Аккаунт, внешний вид, приватность и поддержка в одном месте.';

  @override
  String get settingsQuickControls => 'Быстрые переключатели';

  @override
  String get settingsPersonalizationTitle => 'Персонализация';

  @override
  String get settingsPersonalizationSubtitle =>
      'Тема, язык, плотность и стиль взаимодействия';

  @override
  String get settingsAccountSecurityTitle => 'Аккаунт и безопасность';

  @override
  String get settingsAccountSecuritySubtitle =>
      'Профиль, восстановление, сессии и 2FA';

  @override
  String get settingsPrivacyNotificationsTitle => 'Приватность и уведомления';

  @override
  String get settingsPrivacyNotificationsSubtitle =>
      'Видимость, уведомления, отчёты и серверные ограничения';

  @override
  String get settingsSupportAboutTitle => 'Помощь и информация';

  @override
  String get settingsSupportAboutSubtitle =>
      'Поддержка, версия приложения, документы и ссылки проекта';

  @override
  String get settingsAccountSubtitle =>
      'Профиль, безопасность, сессии и восстановление доступа.';

  @override
  String get settingsAccountAccessTitle => 'Доступ к аккаунту';

  @override
  String get settingsAccountAccessSubtitle =>
      'Инструменты подтверждения и восстановления доступа.';

  @override
  String get settingsProtectionTitle => 'Защита';

  @override
  String get settingsProtectionSubtitle => 'Контролируйте доступ к аккаунту.';

  @override
  String get settingsSecurityTitle => 'Безопасность';

  @override
  String get settingsSecuritySubtitle =>
      'Управление доступом, устройствами, предупреждениями и уровнем защиты.';

  @override
  String get settingsSecurityCheckupTitle => 'Проверка безопасности';

  @override
  String get settingsSecurityCheckupEnabled =>
      'У вашего аккаунта уже есть усиленная защита входа.';

  @override
  String get settingsSecurityCheckupDisabled =>
      'Включите дополнительную защиту для входа и восстановления.';

  @override
  String get settingsPrivacyTitle => 'Приватность';

  @override
  String get settingsPrivacySubtitle =>
      'Уведомления, видимость сообщений и ограничения аккаунта.';

  @override
  String get settingsPrivacyVisibilityTitle => 'Видимость';

  @override
  String get settingsPrivacyVisibilitySubtitle =>
      'Что приложение показывает на этом устройстве и другим людям.';

  @override
  String get settingsHelpTitle => 'Помощь';

  @override
  String get settingsHelpSubtitle =>
      'Поддержка, частые вопросы и быстрое сообщение об ошибке.';

  @override
  String get settingsHelpSupportTitle => 'Поддержка';

  @override
  String get settingsHelpSupportSubtitle =>
      'Получите ответы, свяжитесь с поддержкой или отправьте баг-репорт.';

  @override
  String get settingsAboutTitle => 'О NiosMess';

  @override
  String get settingsAboutSubtitle => 'Информация для разработчиков';

  @override
  String get settingsBuildSnapshotTitle => 'Версия приложения';

  @override
  String get settingsBuildSnapshotSubtitle =>
      'Структурное общение с чистым интерфейсом Material 3.';

  @override
  String get settingsRuntimeTitle => 'Тех данные';

  @override
  String get settingsRuntimeSubtitle => 'Технические данные';

  @override
  String get settingsLinksCreditsTitle => 'Ссылки проекта';

  @override
  String get settingsLinksCreditsSubtitle => 'Публичные страницы NiosMess.';

  @override
  String get settingsVersion => 'Версия';

  @override
  String get settingsApi => 'API';

  @override
  String get settingsApiEnvironment => 'Среда API';

  @override
  String get settingsReleaseChannel => 'Канал релиза';

  @override
  String get settingsLocalStorage => 'Локальное хранилище';

  @override
  String get settingsProduction => 'Продакшн';

  @override
  String get settingsClientCache => 'Клиентский кэш';

  @override
  String get settingsReleaseLiveHint =>
      'Эта сборка подключается к актуальному API NiosMess.';

  @override
  String get settingsLocalStorageHint =>
      'Сообщения, черновики и данные сессии хранятся локально прямо на вашем телефоне.';

  @override
  String get settingsDevelopers => 'Разработчики';

  @override
  String get settingsDevelopersSubtitle =>
      'Люди, которые делают NiosMess таким приятным';

  @override
  String get settingsOpenWebsite => 'Открыть сайт';

  @override
  String settingsOpenWebsiteSubtitle(Object url) {
    return 'Открыть $url в браузере';
  }

  @override
  String get settingsCopyApiUrl => 'Скопировать URL API';

  @override
  String get settingsApiUrlCopied => 'URL API скопирован';

  @override
  String get settingsLicenses => 'Open source лицензии';

  @override
  String get settingsLicensesSubtitle =>
      'Посмотреть опенсурс лицензии используемые в приложении';

  @override
  String get settingsPrivacyPolicy => 'Политика конфиденциальности';

  @override
  String get settingsTermsOfService => 'Условия использования';

  @override
  String get settingsLegalTitle => 'Юридическая информация';

  @override
  String get settingsLegalSubtitle => 'Документы и лицензии';

  @override
  String get settingsCouldNotOpenLink => 'Не удалось открыть ссылку в браузере';

  @override
  String get settingsPushNotifications => 'Push-уведомления';

  @override
  String get settingsPushNotificationsSubtitle =>
      'Сообщения и звонки на этом устройстве';

  @override
  String get settingsReadReceipts => 'Отчёты о прочтении';

  @override
  String get settingsReadReceiptsSubtitle =>
      'Показывать другим, что вы прочитали сообщение';

  @override
  String get settingsTypingIndicator => 'Индикатор набора';

  @override
  String get settingsTypingIndicatorSubtitle =>
      'Показывать, когда вы печатаете сообщение';

  @override
  String get settingsSpamBlockTitle => 'Ваш аккаунт на спам-блоке';

  @override
  String get settingsSpamBlockSubtitle =>
      'Вы не можете начинать новые ЛС, вступать в группы или получать приглашения. Если это ошибка — обратитесь в поддержку.';

  @override
  String get settingsServerLimitsTitle => 'Серверные ограничения';

  @override
  String get settingsServerLimitsSubtitle => 'Пака не сделано';

  @override
  String get settingsTwoFactorStatus => 'Статус двухфакторной защиты';

  @override
  String get settingsTwoFactor => 'Двухфакторная аутентификация';

  @override
  String get settingsTwoFactorEnabledShort => 'Включена для вашего аккаунта';

  @override
  String get settingsTwoFactorDisabledShort => 'Выключена для вашего аккаунта';

  @override
  String get settingsTwoFactorOpenAccount =>
      'Открыть настройки аккаунта для включения или отключения 2FA';

  @override
  String get settingsTrustedDevices => 'Доверенные устройства';

  @override
  String get settingsTrustedDevicesSubtitle =>
      'Проверьте текущие сессии и отключите старые устройства';

  @override
  String get settingsResetPassword => 'Сброс пароля';

  @override
  String get settingsResetPasswordSubtitle =>
      'Запросить код сброса пароля по email';

  @override
  String get settingsVerifyEmail => 'Подтверждение email';

  @override
  String get settingsVerifyEmailSubtitle =>
      'Подтвердите почту для восстановления и более безопасного входа';

  @override
  String get settingsActiveSessions => 'Активные сессии';

  @override
  String get settingsActiveSessionsSubtitle =>
      'Управление устройствами с входом в аккаунт';

  @override
  String get settingsNoUsername => 'Нет username';

  @override
  String get settingsUserFallback => 'Пользователь';

  @override
  String get settingsAvatarUpdated => 'Аватар обновлён';

  @override
  String get settingsDisable2faTitle => 'Отключить 2FA?';

  @override
  String get settingsDisable2faBody => 'Ваш аккаунт станет менее защищённым.';

  @override
  String get settingsDisable => 'Отключить';

  @override
  String get settingsConfirm => 'Подтвердить';

  @override
  String get settingsConfirmPassword => 'Подтвердите пароль';

  @override
  String get settingsDisable2fa => 'Отключить 2FA';

  @override
  String get settingsEnable2fa => 'Включить 2FA';

  @override
  String get settings2faEnabled => '2FA включена';

  @override
  String get settings2faDisabled => '2FA отключена';

  @override
  String get settingsContactSupport => 'Связаться с поддержкой';

  @override
  String get settingsReportIssue => 'Сообщить о проблеме';

  @override
  String get settingsReportIssueSubtitle =>
      'Опишите проблему, с которой столкнулись';

  @override
  String get settingsReportIssueHint => 'Опишите проблему...';

  @override
  String get settingsSubmit => 'Отправить';

  @override
  String get settingsSupportCopied =>
      'Email поддержки скопирован в буфер обмена';

  @override
  String get settingsSupportRequestSubject => 'Запрос в поддержку NiosMess';

  @override
  String get settingsSupportRequestBody => 'Опишите вашу проблему здесь.';

  @override
  String get settingsBugReportSubject => 'Баг-репорт NiosMess';

  @override
  String get settingsBugReportEmpty => 'Описание проблемы не было указано.';

  @override
  String get settingsFaq => 'FAQ';

  @override
  String get settingsFaqResetQ => 'Как сбросить пароль?';

  @override
  String get settingsFaqResetA =>
      'Перейдите в Аккаунт > Сброс пароля. Введите email и следуйте по ссылке.';

  @override
  String get settingsFaq2faQ => 'Как включить 2FA?';

  @override
  String get settingsFaq2faA =>
      'Перейдите в Аккаунт > Двухфакторная аутентификация и подтвердите действие паролем.';

  @override
  String get settingsFaqJoinQ => 'Как вступить в группу?';

  @override
  String get settingsFaqJoinA =>
      'Используйте инвайт-ссылку или нажмите на иконку ссылки на экране чатов, чтобы войти по slug.';

  @override
  String get settingsFaqSpamQ => 'Почему я не могу начинать новые чаты?';

  @override
  String get settingsFaqSpamA =>
      'Возможно, на ваш аккаунт наложен спам-блок. Свяжитесь с поддержкой.';

  @override
  String get developersTeamTitle => 'Команда NiosMess';

  @override
  String get developersHeroSubtitle =>
      'Основатель, Разработчик мобильного приложения и саунд дизайнер в одной команде';

  @override
  String get developersSanlsanRole => 'Основатель';

  @override
  String get developersSanlsanDescription =>
      'Создал ядро Niosmess и придумал саму идею приложения';

  @override
  String get developersSh20fkRole =>
      'Руководитель разработки приложения на все платформы';

  @override
  String get developersSh20fkDescription =>
      'Создал приятный интерфейс которым вы сможете пользоваться ежедневно';

  @override
  String get developersKarlovPrimeRole => 'Саунд-дизайнер';

  @override
  String get developersKarlovPrimeDescription =>
      'Создал звуки и мелодии в приложении';

  @override
  String get developersTagBackend => 'Бэкенд';

  @override
  String get developersTagApi => 'API';

  @override
  String get developersTagAuth => 'Авторизация';

  @override
  String get developersTagFlutter => 'Flutter';

  @override
  String get developersTagUx => 'UX';

  @override
  String get developersTagClient => 'Клиент';

  @override
  String get developersTagSound => 'Звук';

  @override
  String get developersTagCalls => 'Звонки';

  @override
  String get developersTagIdentity => 'Стиль';

  @override
  String get chatListFilterAll => 'Все';

  @override
  String get chatListFilterUnread => 'Непрочитанные';

  @override
  String get chatListFilterGroups => 'Группы';

  @override
  String get chatListFilterChannels => 'Каналы';

  @override
  String get chatListFilterDirect => 'Личные';

  @override
  String get chatListFilterBots => 'Боты';

  @override
  String get chatListSearch => 'Поиск чатов';

  @override
  String get chatListSearchMessagesHint => 'Поиск чатов и сообщений';

  @override
  String get chatListMessageMatches => 'Совпадения в сообщениях';

  @override
  String get chatListNoChats => 'Чаты не найдены.';

  @override
  String get chatListNotAuthenticated => 'Вы ещё не авторизованы.';

  @override
  String get chatListMarkRead => 'Отметить прочитанным';

  @override
  String get chatListMarkReadSubtitle =>
      'Убрать статус непрочитанного для этого чата';

  @override
  String get chatListMute => 'Выключить звук';

  @override
  String get chatListPin => 'Закрепить';

  @override
  String get chatListArchive => 'Архивировать';

  @override
  String get chatListMuteSubtitle => 'Пока не отключение звука не реализовано';

  @override
  String get chatListLeave => 'Покинуть чат';

  @override
  String get chatListLeaveSubtitle => 'Удалить этот диалог из вашего аккаунта';

  @override
  String chatListFailedLoad(Object error) {
    return 'Не удалось загрузить чаты: $error';
  }

  @override
  String get chatListMuteUnsupported => 'Отключение звука пока не реализовано';

  @override
  String get chatListPinUnsupported => 'Закрепление пока не реализовано';

  @override
  String get chatListArchiveUnsupported => 'Архив пока не реализовано';

  @override
  String get chatListLeft => 'Вы покинули этот чат';

  @override
  String chatListChannelPreview(Object preview) {
    return 'Канал • $preview';
  }

  @override
  String chatListGroupPreview(Object preview) {
    return 'Группа • $preview';
  }

  @override
  String chatListUnreadCount(int count) {
    return '$count непрочит.';
  }

  @override
  String chatPreviewForwardedFrom(Object name) {
    return 'Переслано от $name';
  }

  @override
  String get chatPreviewPhoto => 'Фото';

  @override
  String get chatPreviewVideo => 'Видео';

  @override
  String get chatPreviewAudio => 'Аудио';

  @override
  String get chatPreviewFile => 'Файл';

  @override
  String chatTitleFallback(int id) {
    return 'Чат #$id';
  }

  @override
  String get chatInvalidId => 'Некорректный ID чата';

  @override
  String get chatToday => 'Сегодня';

  @override
  String get chatYesterday => 'Вчера';

  @override
  String chatMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника',
      many: '$count участников',
      few: '$count участника',
      one: '1 участник',
      zero: 'Нет участников',
    );
    return '$_temp0';
  }

  @override
  String get chatNoMessages => 'Сообщений пока нет';

  @override
  String get chatSendFirst => 'Начните общение!';

  @override
  String get chatLoadEarlier => 'Показать старые сообщения';

  @override
  String get chatNoMoreMessages => 'Больше сообщений нет';

  @override
  String get chatVoiceCall => 'Голосовой звонок';

  @override
  String get chatVideoCall => 'Видеозвонок';

  @override
  String get chatMembers => 'Участники';

  @override
  String get chatManage => 'Управление чатом';

  @override
  String get chatReply => 'Ответить';

  @override
  String get chatCopyText => 'Копировать текст';

  @override
  String get chatResendTo => 'Переслать в...';

  @override
  String get chatResendSubtitle => 'Копирует текст сообщения в другой чат';

  @override
  String get chatComments => 'Комментарии';

  @override
  String chatCommentsCount(int count) {
    return '$count комментариев';
  }

  @override
  String get chatEdit => 'Изменить';

  @override
  String get chatDelete => 'Удалить';

  @override
  String get chatEditMessageTitle => 'Изменить сообщение';

  @override
  String get chatEditMessageHint => 'Текст сообщения';

  @override
  String get chatDeleteMessageTitle => 'Удалить сообщение?';

  @override
  String get chatDeleteMessageBody => 'Это действие нельзя отменить.';

  @override
  String get chatMessageDeleted => 'Сообщение удалено';

  @override
  String get chatMessageForwarded => 'Сообщение переслано';

  @override
  String get chatMessageTextCopied => 'Текст скопирован';

  @override
  String get chatMediaSent => 'Медиа отправлено';

  @override
  String get chatForwardTo => 'Переслать в...';

  @override
  String get chatAttachment => 'Вложение';

  @override
  String get chatOpenAttachment => 'Открыть вложение';

  @override
  String get chatTapToPreview => 'Нажмите для просмотра';

  @override
  String chatReplyToId(int id) {
    return 'Ответ на #$id';
  }

  @override
  String get chatForwardedTitle => 'Пересланное сообщение';

  @override
  String chatForwardedFrom(Object name) {
    return 'От $name';
  }

  @override
  String get chatEdited => 'изменено';

  @override
  String chatFailedLoadMessages(Object error) {
    return 'Не удалось загрузить сообщения: $error';
  }

  @override
  String get chatCancelReply => 'Отменить ответ';

  @override
  String get chatAttachMedia => 'Прикрепить медиа';

  @override
  String get chatMessageHint => 'Введите сообщение';

  @override
  String get chatOnlyAdminsCanPost =>
      'Писать в этот канал могут только администраторы';

  @override
  String chatMembersTitle(Object name) {
    return 'Участники: $name';
  }

  @override
  String get chatMembersInviteUser => 'Пригласить пользователя';

  @override
  String get chatMembersSearchHint => 'Поиск по username или имени';

  @override
  String get chatMembersSearchPrompt => 'Введите имя для поиска';

  @override
  String chatMembersInvited(Object username) {
    return 'Приглашён @$username';
  }

  @override
  String get chatMembersEmpty => 'Участников нет';

  @override
  String get chatMembersRoleOwner => 'владелец';

  @override
  String get chatMembersRoleAdmin => 'админ';

  @override
  String get chatMembersRoleMember => 'участник';

  @override
  String get chatMembersMuted => 'заглушен';

  @override
  String get chatMembersBanned => 'забанен';

  @override
  String get chatMembersBan => 'Забанить';

  @override
  String get chatMembersUnban => 'Разбанить';

  @override
  String get chatMembersMute => 'Заглушить';

  @override
  String get chatMembersUnmute => 'Снять мут';

  @override
  String get chatMembersPromoteAdmin => 'Назначить админом';

  @override
  String get chatMembersDemoteMember => 'Понизить до участника';

  @override
  String get commentsTitle => 'Комментарии к посту';

  @override
  String get commentsEmpty => 'Комментариев пока нет';

  @override
  String get commentsDeleted => 'Комментарий удалён';

  @override
  String get commentsHint => 'Напишите комментарий';

  @override
  String commentsFailedLoad(Object error) {
    return 'Не удалось загрузить комментарии: $error';
  }

  @override
  String commentsFailedSend(Object error) {
    return 'Не удалось отправить комментарий: $error';
  }

  @override
  String get callsSubtitle => 'История звонков.';

  @override
  String get callsNoHistory =>
      'Истории звонков пока нет. Начните звонок из любого чата.';

  @override
  String callsFailedToStart(Object error) {
    return 'Не удалось начать звонок: $error';
  }

  @override
  String callsFailedLoadChats(Object error) {
    return 'Не удалось загрузить чаты: $error';
  }

  @override
  String callsMissed(Object time) {
    return 'Пропущенный • $time';
  }

  @override
  String callsDeclined(Object time) {
    return 'Отклонённый • $time';
  }

  @override
  String get callsDeclinedShort => 'Отклонённый';

  @override
  String callsOutgoing(Object time) {
    return 'Исходящий • $time';
  }

  @override
  String get callsOutgoingShort => 'Исходящий';

  @override
  String callsIncoming(Object time) {
    return 'Входящий • $time';
  }

  @override
  String get callsIncomingShort => 'Входящий';

  @override
  String get callsInProgress => 'Идёт звонок';

  @override
  String callsTotalCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count звонка',
      many: '$count звонков',
      few: '$count звонка',
      one: '1 звонок',
      zero: 'Нет звонков',
    );
    return '$_temp0';
  }

  @override
  String callsMissedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count пропущенного',
      many: '$count пропущенных',
      few: '$count пропущенных',
      one: '1 пропущенный',
      zero: 'Нет пропущенных',
    );
    return '$_temp0';
  }

  @override
  String callsVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count видео',
      one: '1 видео',
      zero: 'Нет видео',
    );
    return '$_temp0';
  }

  @override
  String get callsSearchHint => 'Поиск звонков';

  @override
  String get callsFilterAll => 'Все';

  @override
  String get callsFilterMissed => 'Пропущенные';

  @override
  String get callsFilterVideo => 'Видео';

  @override
  String get callsQuickTitle => 'Центр звонков';

  @override
  String callsLatestCall(Object name) {
    return 'Последний звонок: $name';
  }

  @override
  String get callsQuickPeople => 'Быстрый звонок';

  @override
  String get callsQuickAdd => 'Добавить';

  @override
  String callsResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count подходящего звонка',
      many: '$count подходящих звонков',
      few: '$count подходящих звонка',
      one: '1 подходящий звонок',
      zero: 'Подходящих звонков нет',
    );
    return '$_temp0';
  }

  @override
  String get activeCallTitle => 'Звонок';

  @override
  String get activeCallInvalidChat => 'Некорректный ID чата';

  @override
  String get activeCallRefresh => 'Обновить статус звонка';

  @override
  String activeCallResponseFailed(Object error) {
    return 'Не удалось ответить на звонок: $error';
  }

  @override
  String activeCallEndFailed(Object error) {
    return 'Не удалось завершить звонок: $error';
  }

  @override
  String get activeCallVoice => 'Голосовой';

  @override
  String get activeCallVideo => 'Видео';

  @override
  String get activeCallRinging => 'Вызов';

  @override
  String get activeCallActive => 'Активен';

  @override
  String get activeCallEnded => 'Завершён';

  @override
  String get activeCallMissed => 'Пропущен';

  @override
  String get activeCallDeclined => 'Отклонён';

  @override
  String get activeCallVideoPreview => 'Видео-превью готово';

  @override
  String get activeCallCameraOn => 'Камера включена';

  @override
  String get activeCallCameraOff => 'Камера выключена';

  @override
  String get activeCallAnswer => 'Ответить';

  @override
  String get activeCallDecline => 'Отклонить';

  @override
  String get activeCallEnd => 'Завершить звонок';

  @override
  String get activeCallMute => 'Выключить микрофон';

  @override
  String get activeCallUnmute => 'Включить микрофон';

  @override
  String get activeCallSpeaker => 'Динамик';

  @override
  String get groupTypeGroup => 'Группа';

  @override
  String get groupTypeChannel => 'Канал';

  @override
  String get groupTypeStep => 'Тип';

  @override
  String get groupDetailsStep => 'Детали';

  @override
  String get groupPrivacyStep => 'Приватность';

  @override
  String get groupReviewStep => 'Проверка';

  @override
  String get groupWizardTypeSubtitle => 'Выберите, что вы хотите создать.';

  @override
  String get groupWizardDetailsSubtitle =>
      'Укажите название и короткое описание.';

  @override
  String get groupWizardPrivacySubtitle => 'Это публичный или приватный чат?';

  @override
  String get groupWizardReviewSubtitle =>
      'Проверьте настройки перед созданием.';

  @override
  String get groupNewGroup => 'Новая группа';

  @override
  String get groupNewChannel => 'Новый канал';

  @override
  String get groupCreateOrJoin => 'Создать или войти';

  @override
  String get groupCreateSharedSubtitle => 'Создайте общий чат для участников';

  @override
  String get groupCreateBroadcastSubtitle =>
      'Создайте канал для постов и объявлений';

  @override
  String get groupJoinByInvite => 'Войти по приглашению';

  @override
  String get groupJoinByInviteSubtitle =>
      'Вставьте ссылку-приглашение для входа в чат';

  @override
  String get groupTypeGroupSubtitle =>
      'Участники могут общаться вместе. Подходит для друзей и команд.';

  @override
  String get groupTypeChannelSubtitle =>
      'Публикуйте обновления, посты и объявления для подписчиков.';

  @override
  String get groupYourNewChannel => 'Ваш новый канал';

  @override
  String get groupYourNewGroup => 'Ваша новая группа';

  @override
  String get groupEditLater =>
      'Аватар, участников и ссылки можно изменить позже.';

  @override
  String get groupNameLabel => 'Название';

  @override
  String get groupNameHint => 'Мой рабочий чат';

  @override
  String get groupDescriptionChannelLabel => 'Описание канала (необязательно)';

  @override
  String get groupDescriptionGroupLabel => 'Описание группы (необязательно)';

  @override
  String get groupDescriptionChannelHint => 'О чём этот канал';

  @override
  String get groupDescriptionGroupHint => 'Для чего эта группа';

  @override
  String get groupPrivate => 'Приватный';

  @override
  String get groupPrivateSubtitle =>
      'Люди смогут войти только по ссылке-приглашению.';

  @override
  String get groupPublic => 'Публичный';

  @override
  String get groupPublicSubtitle =>
      'Люди смогут найти его по названию или вступить по ссылке.';

  @override
  String get groupPublicUsername => 'Имя группы';

  @override
  String get groupEnableComments => 'Включить комментарии';

  @override
  String get groupEnableCommentsSubtitle =>
      'Участники смогут комментировать посты канала в ветке обсуждений.';

  @override
  String get groupBack => 'Назад';

  @override
  String get groupContinue => 'Продолжить';

  @override
  String get groupCreate => 'Создать';

  @override
  String get groupCreating => 'Создаём...';

  @override
  String get groupAlreadyHaveInvite => 'Уже есть инвайт? Войти по ссылке';

  @override
  String get groupVisibility => 'Видимость';

  @override
  String get groupUsernameLabel => 'Username';

  @override
  String get groupCreatedChannel => 'Канал успешно создан';

  @override
  String get groupCreatedGroup => 'Группа успешно создана';

  @override
  String groupCreateFailed(Object error) {
    return 'Не удалось создать чат: $error';
  }

  @override
  String get groupNameTooShort => 'Название должно быть минимум 3 символа';

  @override
  String get groupUsernameRules =>
      'Используйте 3-32 символа: буквы, цифры, точку и подчёркивание';

  @override
  String get groupJoinTitle => 'Вход по инвайту';

  @override
  String get groupJoinHeadline => 'Войти по ссылке';

  @override
  String get groupJoinSubtitle =>
      'Вставьте приватную ссылку-приглашение чтобы сначала посмотреть превью чата.';

  @override
  String get groupInviteLinkOrSlug => 'Ссылка-приглашение';

  @override
  String get groupPreviewInvite => 'Показать превью';

  @override
  String get groupInvitePreviewNotFound => 'Превью инвайта не найдено.';

  @override
  String get groupJoinChat => 'Войти в чат';

  @override
  String get groupJoining => 'Входим...';

  @override
  String groupInviteFailedLoad(Object error) {
    return 'Не удалось загрузить инвайт: $error';
  }

  @override
  String groupJoinFailed(Object error) {
    return 'Не удалось войти в чат: $error';
  }

  @override
  String get groupSignInToJoin =>
      'Войдите в аккаунт, чтобы заходить в чаты по инвайту.';

  @override
  String get groupChannelPreview => 'Превью канала';

  @override
  String get groupGroupPreview => 'Превью группы';

  @override
  String get groupNoPostsYet => 'Постов пока нет';

  @override
  String groupManageTitle(Object name) {
    return 'Управление: $name';
  }

  @override
  String get groupManageChangeAvatar => 'Изменить аватар';

  @override
  String get groupManageUploading => 'Загрузка...';

  @override
  String get groupManageAvatarUpdated => 'Аватар обновлён';

  @override
  String get groupManageChatUpdated => 'Чат обновлён';

  @override
  String get groupManageSaveChanges => 'Сохранить изменения';

  @override
  String get groupManageIdentity => 'Основное';

  @override
  String get groupManageLinks => 'Ссылки и метаданные';

  @override
  String get groupManageLeaveTitle => 'Покинуть чат?';

  @override
  String get groupManageLeaveBody => 'Вы больше не будете видеть этот чат.';

  @override
  String get groupManageLeave => 'Покинуть чат';

  @override
  String get commonEnabled => 'Включено';

  @override
  String get commonDisabled => 'Выключено';

  @override
  String get timeNow => 'сейчас';

  @override
  String get timeYesterday => 'вчера';

  @override
  String get settingsProfileSetupSubtitle => 'Настройте профиль';

  @override
  String get settingsSectionsTitle => 'Разделы настроек';

  @override
  String get settingsSectionsSubtitle =>
      'Здесь показаны только рабочие разделы.';

  @override
  String get settingsStorageTitle => 'Хранилище';

  @override
  String get settingsStorageSubtitle =>
      'Данные приложения, черновики и кэш, который можно очистить.';

  @override
  String get settingsStorageBreakdown => 'Состав хранилища';

  @override
  String get settingsStorageBreakdownSubtitle =>
      'Посчитано на этом устройстве.';

  @override
  String get settingsStorageAppData => 'Данные приложения';

  @override
  String get settingsStorageAppDataSubtitle =>
      'Локальные файлы, нужные приложению.';

  @override
  String get settingsStorageTemporaryCache => 'Временный кэш';

  @override
  String get settingsStorageTemporaryCacheSubtitle =>
      'Файлы, которые приложение может создать заново.';

  @override
  String get settingsStorageDrafts => 'Черновики';

  @override
  String settingsStorageDraftsSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сохранённых черновиков',
      one: '1 сохранённый черновик',
      zero: 'Нет сохранённых черновиков',
    );
    return '$_temp0';
  }

  @override
  String get settingsStorageActions => 'Действия';

  @override
  String get settingsStorageActionsSubtitle =>
      'Очищаются только данные, которые безопасно восстановить.';

  @override
  String get settingsStorageRefresh => 'Обновить';

  @override
  String get settingsStorageRefreshSubtitle =>
      'Заново посчитать локальное хранилище';

  @override
  String get settingsStorageCheckIntegrity => 'Проверить хранилище';

  @override
  String get settingsStorageCheckIntegritySubtitle =>
      'Проверить схему, папки и черновики';

  @override
  String get settingsStorageClearTemporary => 'Очистить временный кэш';

  @override
  String get settingsStorageClearTemporarySubtitle =>
      'Удалить файлы из папки кэша приложения';

  @override
  String get settingsStorageClearDrafts => 'Очистить черновики';

  @override
  String get settingsStorageClearDraftsSubtitle =>
      'Удалить неотправленный локальный текст';

  @override
  String get settingsStorageClearTemporaryConfirmTitle =>
      'Очистить временный кэш?';

  @override
  String get settingsStorageClearTemporaryConfirmBody =>
      'Кэш будет создан заново при необходимости. Аккаунт и настройки не будут затронуты.';

  @override
  String get settingsStorageClearDraftsConfirmTitle => 'Очистить черновики?';

  @override
  String get settingsStorageClearDraftsConfirmBody =>
      'Неотправленный текст черновиков на этом устройстве будет удалён.';

  @override
  String get settingsStorageCleared => 'Хранилище очищено';

  @override
  String get settingsStorageHealthOkTitle => 'Хранилище в порядке';

  @override
  String settingsStorageHealthOkBody(int schemaVersion) {
    return 'Локальная схема версии $schemaVersion готова, проблем целостности нет.';
  }

  @override
  String get settingsStorageHealthIssueTitle => 'Хранилище требует внимания';

  @override
  String get settingsStorageUsedByApp => 'Занято NiosMess на этом устройстве';

  @override
  String settingsStorageCleanable(Object size) {
    return '$size можно очистить без выхода из аккаунта.';
  }

  @override
  String get settingsLegalPoliciesSubtitle =>
      'Документы. Лицензии перенесены в скрытое меню.';

  @override
  String get settingsHiddenMenuTitle => 'Скрытые инструменты';

  @override
  String get settingsHiddenMenuSubtitle =>
      'Открываются долгим нажатием на версию приложения.';

  @override
  String get settingsDiagnosticsTitle => 'Диагностика';

  @override
  String get settingsDiagnosticsSubtitle => 'Информация для разработчиков';

  @override
  String settingsDiagnosticsStorageSummary(int schemaVersion, Object size) {
    return 'Схема v$schemaVersion, локально занято $size';
  }

  @override
  String get settingsDiagnosticsLogsTitle => 'Локальные логи';

  @override
  String get settingsDiagnosticsLogsSubtitle =>
      'Последние ошибки и события на этом устройстве.';

  @override
  String get settingsDiagnosticsNoLogs => 'Локальных ошибок нет';

  @override
  String get settingsDiagnosticsActions => 'Действия диагностики';

  @override
  String get settingsDiagnosticsRefresh => 'Обновить диагностику';

  @override
  String get settingsDiagnosticsRefreshSubtitle =>
      'Заново прочитать версию, звук, хранилище и логи';

  @override
  String get settingsDiagnosticsTestSound => 'Проверить звук интерфейса';

  @override
  String get settingsDiagnosticsTestSoundSubtitle =>
      'Проиграть текущий звук перехода';

  @override
  String get settingsDiagnosticsCopyLogs => 'Скопировать локальные логи';

  @override
  String get settingsDiagnosticsCopyLogsSubtitle =>
      'Скопировать последние ошибки и события';

  @override
  String get settingsDiagnosticsLogsCopied => 'Локальные логи скопированы';

  @override
  String get settingsEditProfileSubtitle => 'Изменить имя, аватар и описание';

  @override
  String get appearanceVariantTonalSpot => 'Мягкая';

  @override
  String get appearanceVariantVibrant => 'Насыщенная';

  @override
  String get appearanceVariantExpressive => 'Выразительная';

  @override
  String get appearanceVariantNeutral => 'Нейтральная';

  @override
  String get appearanceVariantMonochrome => 'Монохромная';

  @override
  String get appearanceVariantFidelity => 'Резкая';

  @override
  String get appearancePaletteNiosMess => 'Фирменная тема NiosMess';

  @override
  String get appearancePaletteOcean => 'Океан';

  @override
  String get appearancePaletteForest => 'Лес';

  @override
  String get appearancePaletteSunset => 'Закат';

  @override
  String get appearancePaletteRose => 'Роза';

  @override
  String get appearancePaletteSignal => 'Сигнал';

  @override
  String get resetPasswordRequestTitle => 'Сброс пароля';

  @override
  String get resetPasswordRequestHeroTitle => 'Сброс пароля';

  @override
  String get resetPasswordRequestHeroSubtitle =>
      'Мы отправим код для сброса на ваш email.';

  @override
  String get resetPasswordRequestEmailLabel => 'Электронная почта';

  @override
  String get resetPasswordRequestEmailError => 'Введите корректный email';

  @override
  String get resetPasswordRequestSubmit => 'Отправить код';

  @override
  String get resetPasswordRequestSubmitting => 'Отправка...';

  @override
  String get resetPasswordRequestSent => 'Запрос отправлен';

  @override
  String get resetPasswordConfirmTitle => 'Подтверждение сброса';

  @override
  String get resetPasswordConfirmHeroTitle => 'Введите код';

  @override
  String get resetPasswordConfirmHeroSubtitle =>
      'Введите код, отправленный на ваш email.';

  @override
  String get resetPasswordConfirmEmailLabel => 'Электронная почта';

  @override
  String get resetPasswordConfirmEmailError => 'Введите корректный email';

  @override
  String get resetPasswordConfirmCodeLabel => 'Код';

  @override
  String get resetPasswordConfirmCodeError => 'Введите 6 цифр';

  @override
  String get resetPasswordConfirmPasswordLabel => 'Новый пароль';

  @override
  String get resetPasswordConfirmPasswordError => 'Минимум 8 символов';

  @override
  String get resetPasswordConfirmSubmit => 'Сбросить пароль';

  @override
  String get resetPasswordConfirmSubmitting => 'Применение...';

  @override
  String get resetPasswordConfirmDone => 'Пароль успешно изменён';

  @override
  String get sessionsTitle => 'Активные сессии';

  @override
  String get sessionsRevokeTitle => 'Отозвать сессию?';

  @override
  String get sessionsRevokeConfirm => 'Отозвать';

  @override
  String get sessionsCancel => 'Отмена';

  @override
  String get sessionsRevokeTooltip => 'Отозвать сессию';

  @override
  String get sessionsRevokedSuccess => 'Сессия отозвана';

  @override
  String get sessionsEmpty => 'Нет активных сессий';

  @override
  String get sessionsRetry => 'Повторить';

  @override
  String get sessionsRevokeAll => 'Отозвать все другие сессии';

  @override
  String get contactsTitle => 'Контакты';

  @override
  String get contactsRecent => 'Недавние';

  @override
  String get contactsRecentPeople => 'Недавние контакты...';

  @override
  String get contactsSearch => 'Поиск';

  @override
  String get contactsNoRecent => 'Пока нет недавних контактов...';

  @override
  String get contactsTypeUsername => 'Введите имя пользователя...';

  @override
  String get contactsNoMatches => 'Совпадений не найдено.';

  @override
  String get contactsMessage => 'Сообщение';

  @override
  String get contactsChat => 'Чат';

  @override
  String get contactDetailTitle => 'Контакт';

  @override
  String get contactDetailOverview => 'Обзор контакта';

  @override
  String get contactDetailSharedContext => 'Общий контекст';

  @override
  String get contactDetailUsername => 'Имя пользователя';

  @override
  String get contactDetailBio => 'О себе';

  @override
  String get contactDetailSharedContextDesc =>
      'Общие группы и медиа появятся здесь, как только эти данные станут доступны из API.';

  @override
  String get contactDetailNoBio => 'Нет публичной информации';

  @override
  String get contactsSubtitle =>
      'Недавние контакты, быстрые сообщения и поиск.';

  @override
  String get contactsNotAuth => 'Вы еще не авторизованы.';

  @override
  String get contactsNoRecentFull =>
      'Пока нет недавних контактов.\nНачните общение через вкладку Поиск.';

  @override
  String get contactsSearchHint => 'Поиск по имени, username или тексту';

  @override
  String get contactsSearchEmpty =>
      'Введите username или имя для поиска пользователей, чатов и сообщений.';

  @override
  String get contactsUsers => 'Пользователи';

  @override
  String get contactsChats => 'Чаты';

  @override
  String get contactsMessages => 'Сообщения';

  @override
  String get contactsNoMessagesYet => 'Сообщений пока нет';

  @override
  String contactsForwardedFrom(Object name) {
    return 'Переслано от $name';
  }

  @override
  String get mediaActionSave => 'Сохранить';

  @override
  String get mediaActionCopy => 'Скопировать ссылку';

  @override
  String get mediaActionOpenIn => 'Открыть в...';

  @override
  String get mediaViewerTitle => 'Вложение';

  @override
  String get mediaViewerCannotPreview => 'Предпросмотр этого файла недоступен';

  @override
  String get mediaViewerOpenExternal => 'Открыть во внешнем приложении';

  @override
  String get chatUploadCancelTitle => 'Отменить загрузку?';

  @override
  String get chatUploadCancelBody => 'Идёт загрузка медиа. Прервать?';

  @override
  String get commonYes => 'Да';

  @override
  String get commonNo => 'Нет';

  @override
  String get chatScrollToBottom => 'К последним сообщениям';

  @override
  String chatTypingOne(Object name) {
    return '$name печатает...';
  }

  @override
  String get chatTypingMultiple => 'Несколько человек печатают...';

  @override
  String chatUnreadMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count непрочитанных',
      many: '$count непрочитанных',
      few: '$count непрочитанных',
      one: '1 непрочитанное',
    );
    return '$_temp0';
  }

  @override
  String get chatEditingMessage => 'Редактирование';

  @override
  String get chatEditCancel => 'Отменить редактирование';

  @override
  String get chatScrollLoadingEarlier => 'Загрузка сообщений...';

  @override
  String get appearanceOptimizeWeakDevices =>
      'Оптимизация для слабых устройств';

  @override
  String get appearanceOptimizeWeakDevicesSubtitle =>
      'Отключает размытие фона и тяжелые BackdropFilter эффекты для повышения FPS';

  @override
  String get searchSemantic => 'Семантический поиск';

  @override
  String get searchSemanticHint => 'Искать по смыслу с помощью ИИ';

  @override
  String get searchSemanticFallback =>
      'Семантический поиск временно недоступен. Выполнен обычный поиск.';

  @override
  String get chatCreatePersonal => 'Создать личный чат';

  @override
  String get chatCreatePersonalSubtitle =>
      'Начать прямой диалог по имени пользователя';

  @override
  String get chatCreatePersonalPrompt => 'Начать личный чат';

  @override
  String get chatCreatePersonalUsernameLabel => 'Имя пользователя (username)';

  @override
  String get chatCreatePersonalUsernameHint => 'username';

  @override
  String get chatCreatePersonalStart => 'Начать';

  @override
  String get chatCreatePersonalErrorEmpty =>
      'Имя пользователя не может быть пустым';

  @override
  String get settingsAdminTitle => 'Панель админа';

  @override
  String get settingsAdminSubtitle => 'Управление пользователями и чатами';

  @override
  String get settingsBadgesTitle => 'Бейджи';

  @override
  String get settingsBadgesSubtitle => 'Просмотр и управление бейджами';

  @override
  String get settingsBotsTitle => 'Боты';

  @override
  String get settingsBotsSubtitle => 'Создание и управление ботами';

  @override
  String get settingsSecretChatsTitle => 'Секретные чаты';

  @override
  String get settingsSecretChatsSubtitle => 'Сквозное шифрование (E2EE)';

  @override
  String get settingsSecretChatsButton => 'Секретный чат';

  @override
  String adminUserBanned(int id) {
    return 'Пользователь $id забанен';
  }

  @override
  String adminUserUnbanned(int id) {
    return 'Пользователь $id разбанен';
  }

  @override
  String adminUserFrozen(int id) {
    return 'Пользователь $id заморожен';
  }

  @override
  String adminUserUnfrozen(int id) {
    return 'Пользователь $id разморожен';
  }

  @override
  String adminSpamBlockEnabled(int id) {
    return 'Спам-блок включен для $id';
  }

  @override
  String adminSpamBlockDisabled(int id) {
    return 'Спам-блок отключен для $id';
  }

  @override
  String adminChatBanned(int id) {
    return 'Чат $id забанен';
  }

  @override
  String adminChatUnbanned(int id) {
    return 'Чат $id разбанен';
  }

  @override
  String adminTabUsers(int count) {
    return 'Пользователи ($count)';
  }

  @override
  String adminTabChats(int count) {
    return 'Чаты ($count)';
  }

  @override
  String get adminActionBan => 'Забанить';

  @override
  String get adminActionUnban => 'Разбанить';

  @override
  String get adminActionFreeze => 'Заморозить';

  @override
  String get adminActionUnfreeze => 'Разморозить';

  @override
  String get adminActionSpamBlock => 'Спам-блок';

  @override
  String get adminActionUnspamBlock => 'Снять спам-блок';

  @override
  String get badgeCreateTitle => 'Создать бейдж';

  @override
  String get badgeAwardTitle => 'Выдать бейдж';

  @override
  String get badgeActionCreate => 'Создать';

  @override
  String get badgeActionAward => 'Выдать';

  @override
  String get badgeCreated => 'Бейдж создан';

  @override
  String badgeDeleted(int id) {
    return 'Бейдж $id удалён';
  }

  @override
  String badgeAwarded(int badgeId, int userId) {
    return 'Бейдж $badgeId выдан пользователю $userId';
  }

  @override
  String get badgeNoBadges => 'Нет доступных бейджей';

  @override
  String get badgeListRefresh => 'Обновить';

  @override
  String get botCreateTitle => 'Создать бота';

  @override
  String get botBotToken => 'Токен бота';

  @override
  String get botActionUse => 'Использовать';

  @override
  String get botTokenCopied => 'Токен скопирован';

  @override
  String get botNoUpdates => 'Нет обновлений';

  @override
  String get e2eeKeyGenerated => 'E2EE ключ сгенерирован и загружен';

  @override
  String get mediaDownloadAndOpen => 'Скачать и открыть';

  @override
  String mediaSavedTo(Object path) {
    return 'Сохранено в $path';
  }

  @override
  String get mediaDownloadFailedExt =>
      'Не удалось скачать. Попробуйте открыть во внешнем приложении.';

  @override
  String mediaDownloadFailed(Object error) {
    return 'Ошибка скачивания: $error';
  }

  @override
  String get dialogCancelChatCreationTitle => 'Отменить?';

  @override
  String get dialogCancelChatCreationBody => 'Идёт создание чата. Отменить?';

  @override
  String get dialogCancelCommentTitle => 'Отменить?';

  @override
  String get dialogCancelCommentBody => 'Идёт отправка комментария. Отменить?';

  @override
  String get emptyStateNoItems => 'Ничего не найдено';

  @override
  String get emptyStateNoItemsDesc => 'Здесь пока ничего нет.';

  @override
  String get offlineWaiting => 'Ожидание сети...';

  @override
  String get filePreviewSave => 'Сохранить';

  @override
  String get filePreviewLink => 'Ссылка';

  @override
  String get filePreviewOpen => 'Открыть';

  @override
  String get filePreviewForward => 'Переслать';

  @override
  String get filePreviewFileName => 'Имя файла';

  @override
  String get filePreviewClose => 'Закрыть';

  @override
  String get filePreviewLinkCopied => 'Ссылка скопирована';

  @override
  String get filePreviewPathCopied => 'Путь скопирован';

  @override
  String get filePreviewSaved => 'Файл сохранён';

  @override
  String filePreviewSaveError(Object error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get filePreviewPause => 'Пауза';

  @override
  String get filePreviewPlay => 'Воспроизвести';

  @override
  String get filePickerGallery => 'Галерея';

  @override
  String get filePickerDocument => 'Документ';

  @override
  String get filePickerAudio => 'Аудио';

  @override
  String get filePickerFile => 'Файл';

  @override
  String get filePickerReadError => 'Не удалось прочитать файл';

  @override
  String get badgeFieldName => 'Название';

  @override
  String get badgeFieldDescription => 'Описание';

  @override
  String get badgeFieldIcon => 'Иконка (эмодзи)';

  @override
  String get badgeFieldColor => 'Цвет (hex)';

  @override
  String get badgeFieldUserId => 'ID пользователя';

  @override
  String get badgeFieldBadgeId => 'ID бейджа';

  @override
  String get badgeAdminPassword => 'Пароль админа';

  @override
  String get badgeAdminMode => 'Режим админа';

  @override
  String get badgeAdminSubtitle => 'Показать управление бейджами';

  @override
  String get botFieldName => 'Имя бота';

  @override
  String get botFieldUsername => 'Username';

  @override
  String get botFieldDescription => 'Описание (необязательно)';

  @override
  String get botFieldToken => 'Введите токен бота';

  @override
  String get botSectionTitle => 'Боты';

  @override
  String get botSectionSubtitle => 'Создавайте и управляйте ботами.';

  @override
  String get botCreateSubtitle => 'Создать нового бота';

  @override
  String get botCreateDescription => 'Зарегистрировать бота';

  @override
  String get botUpdatesTitle => 'Обновления бота';

  @override
  String get botGetUpdates => 'Получить обновления';

  @override
  String get botPollSubtitle => 'Опросить новые сообщения и колбэки';

  @override
  String get botCreated => 'Бот создан!';

  @override
  String get botCopied => 'Скопировано';

  @override
  String get fluidPreviewM3Title => 'Оформление M3 Expressive';

  @override
  String get fluidPreviewM3Subtitle =>
      'Новые индикаторы и плавные переходы уже доступны!';

  @override
  String get profileAvatarUpdated => 'Аватар обновлён';

  @override
  String profileError(Object error) {
    return 'Ошибка: $error';
  }

  @override
  String get chatImageUnavailable => 'Изображение недоступно';

  @override
  String get settingsRevokeSession => 'Завершить сессию';

  @override
  String get tabNiosgram => 'Лента';

  @override
  String get niosgramTitle => 'NiosGram';

  @override
  String get niosgramCreatePost => 'Новый пост';

  @override
  String get niosgramPublish => 'Опубликовать';

  @override
  String get niosgramWhatMind => 'О чём думаешь?';

  @override
  String get niosgramAttachMedia => 'Прикрепить медиа';

  @override
  String get niosgramRemove => 'Убрать';

  @override
  String get niosgramEmptyFeed => 'Постов пока нет';

  @override
  String get niosgramEmptyFeedDesc => 'Будь первым, кто поделится чем-то!';

  @override
  String get niosgramLoadMore => 'Загрузить ещё';

  @override
  String get niosgramComments => 'Комментарии';

  @override
  String get niosgramWriteComment => 'Напишите комментарий...';

  @override
  String get niosgramLike => 'Нравится';

  @override
  String get niosgramDislike => 'Не нравится';

  @override
  String get niosgramDeletePost => 'Удалить пост?';

  @override
  String get niosgramDeletePostConfirm => 'Это действие нельзя отменить.';

  @override
  String get niosgramCopied => 'Скопировано в буфер обмена';

  @override
  String get niosgramEdit => 'Изменить';

  @override
  String get niosgramDelete => 'Удалить';

  @override
  String get niosgramCopyText => 'Скопировать текст';

  @override
  String get niosgramEditPost => 'Отредактируйте пост...';

  @override
  String get niosgramFileTooLarge => 'Файл превышает 10 МБ';

  @override
  String get niosgramEmptyContent => 'Напишите что-нибудь или прикрепите файл';

  @override
  String get niosgramFailedLoad => 'Не удалось загрузить ленту';

  @override
  String get settingsPrivacyBannerSubtitle =>
      'Уведомления, видимость и системные ограничения аккаунта.';

  @override
  String get settingsPrivacyNotificationsManage =>
      'Управление push-уведомлениями приложения';

  @override
  String get settingsPrivacyVisibilityDesc =>
      'Контроль статуса присутствия в приложении';

  @override
  String get settingsPrivacyHideOnline => 'Скрывать онлайн-статус';

  @override
  String get settingsPrivacyHideOnlineDesc =>
      'Не показывать другим пользователям ваш статус присутствия';

  @override
  String get settingsStorageBannerSubtitle =>
      'Использование памяти, кеша и черновиков приложения.';

  @override
  String get settingsStorageLegendCache => 'Кеш';

  @override
  String get settingsStorageLegendDrafts => 'Черновики';

  @override
  String get settingsStorageCategoryAppData => 'Данные';

  @override
  String get settingsStorageCategoryCache => 'Кеш';

  @override
  String get settingsStorageCategoryDrafts => 'Черновики';

  @override
  String get settingsAboutBannerSubtitle =>
      'Поддержка, правовая информация и сведения о приложении.';

  @override
  String get settingsAboutHelpDesc => 'Частые вопросы и способы связи';

  @override
  String get settingsAboutVersionTitle => 'NiosMess';

  @override
  String get settingsAboutVersionDesc => 'Версия приложения и служебные пункты';

  @override
  String get settingsAboutLegalDesc => 'Политики и внешние ресурсы';

  @override
  String get settingsAccountBannerSubtitle =>
      'Безопасность входа, подтверждение почты и активные сессии.';

  @override
  String get settingsAccountAccessDesc =>
      'Основные действия для доступа и восстановления аккаунта';

  @override
  String get settingsLanguageBannerDesc =>
      'Язык интерфейса и локализация элементов приложения';

  @override
  String get settingsLanguageCurrentLang => 'Текущий язык';

  @override
  String get settingsLanguageTzDesc =>
      'Автоматическое определение или ручной выбор часового пояса';

  @override
  String get settingsLanguageTimePreview =>
      'Предпросмотр текущих даты и времени';

  @override
  String get settingsLanguageLocalTime => 'Локальное время';

  @override
  String get sessionsBannerSubtitle =>
      'Управление активными устройствами и сессиями.';

  @override
  String get sessionsRevokeBody =>
      'Это устройство будет отключено, если это текущая сессия.';

  @override
  String sessionsActive(Object time) {
    return 'Активна: $time';
  }

  @override
  String sessionsCreated(Object time) {
    return 'Создана: $time';
  }

  @override
  String get sessionsCurrent => 'Текущая';

  @override
  String get onboardingSlide1Title => 'Быстрые звонки без лишнего';

  @override
  String get onboardingSlide1Desc =>
      'Звоните коллегам в одно касание и переключайтесь между голосом и видео не покидая разговор.';

  @override
  String get onboardingSlide2Title => 'Упорядоченные беседы';

  @override
  String get onboardingSlide2Desc =>
      'Держите чаты, звонки и контакты в одном удобном пространстве.';

  @override
  String get onboardingSlide3Title => 'Для повседневного ритма';

  @override
  String get onboardingSlide3Desc =>
      'Плавные переходы и чёткая иерархия сохраняют спокойствие общения даже в напряжённый день.';

  @override
  String get onboardingGetStarted => 'Начать';

  @override
  String get onboardingNext => 'Далее';

  @override
  String get mediaViewerDownload => 'Скачать';

  @override
  String mediaViewerImageLoadFailed(Object error) {
    return 'Не удалось загрузить изображение: $error';
  }

  @override
  String get mediaViewerDownloadWeb => 'Скачивание недоступно в веб-версии';

  @override
  String get mediaViewerDownloadFailedExt =>
      'Не удалось скачать. Попробуйте открыть во внешнем приложении.';

  @override
  String directResolverResolving(Object username) {
    return 'Распознаём @$username';
  }

  @override
  String get directResolverSecretEstablishing =>
      'Устанавливаем сквозное шифрование...';

  @override
  String get directResolverPreparing =>
      'Подготавливаем защищённый диалог в NiosMess.';

  @override
  String get directResolverUserNotFound => 'Пользователь не найден';

  @override
  String get directResolverUserNotFoundDesc =>
      'Не удалось найти этого пользователя.';

  @override
  String get directResolverSecretTitle => 'Секретный чат';

  @override
  String get postNewPost => 'Новый пост';

  @override
  String get postPublish => 'Опубликовать';

  @override
  String get postHint => 'О чём думаешь?';

  @override
  String get postRemove => 'Убрать';

  @override
  String get postAttachMedia => 'Прикрепить медиа';

  @override
  String get postFileTooLarge => 'Файл превышает 10 МБ';

  @override
  String get postEmptyContent => 'Напишите что-нибудь или прикрепите файл';

  @override
  String get chatCreateFailed => 'Не удалось создать чат';

  @override
  String get chatChannelCreated => 'Канал создан';

  @override
  String get chatGroupCreated => 'Группа создана';

  @override
  String get chatChooseNextStep => 'Выберите, что сделать дальше.';

  @override
  String get chatOpenChat => 'Открыть чат';

  @override
  String get chatCopyInvite => 'Скопировать инвайт';

  @override
  String get chatInviteLinkCopied => 'Ссылка-приглашение скопирована';

  @override
  String get chatCommentsEnabled => 'Включены';

  @override
  String get chatCommentsDisabled => 'Выключены';

  @override
  String get profileSettingsSection => 'Настройки';

  @override
  String get profileSettingsSectionDesc =>
      'Основные параметры аккаунта и приложения';

  @override
  String get profileSectionQuickSettings => 'Быстрые настройки';

  @override
  String get profileSectionPrivacy => 'Конфиденциальность';

  @override
  String get profileSectionAccount => 'Аккаунт';

  @override
  String get profileSectionData => 'Данные';

  @override
  String get profileSectionAbout => 'О приложении';

  @override
  String get profileAppearanceDesc => 'Тема, цвета';

  @override
  String get profileLanguage => 'Язык';

  @override
  String get profileLanguageDesc => 'Язык приложения';

  @override
  String get profileTeamTools => 'Команда и инструменты';

  @override
  String get profileTeamToolsDesc => 'Команда проекта и дополнительные разделы';

  @override
  String get chatManageInviteLink => 'Ссылка-приглашение';

  @override
  String get chatManageCopyInvite => 'Скопировать инвайт';

  @override
  String get chatManageShareInvite => 'Поделиться инвайтом';

  @override
  String get chatManageShareLink => 'Поделиться ссылкой';

  @override
  String get chatManageCommentsChatId => 'ID чата комментариев';

  @override
  String chatManageCopied(Object title) {
    return '$title скопировано';
  }

  @override
  String get chatManageCopy => 'Копировать';

  @override
  String get chatManageName => 'Название';

  @override
  String get chatManageDescription => 'Описание';

  @override
  String get chatManageSaveChanges => 'Сохранить изменения';

  @override
  String get chatManageChannel => 'Канал';

  @override
  String get chatManageGroup => 'Группа';

  @override
  String get adminPanelTitle => 'Панель админа';

  @override
  String get adminPanelSubtitle =>
      'Управление пользователями и чатами с паролем админа.';

  @override
  String get adminAuthentication => 'Авторизация';

  @override
  String get adminPasswordLabel => 'Пароль админа';

  @override
  String get adminConnecting => 'Подключение...';

  @override
  String get adminConnect => 'Подключиться';

  @override
  String get adminStatusBanned => 'Забанен';

  @override
  String get adminStatusActive => 'Активен';

  @override
  String get adminStatusFrozen => 'Заморожен';

  @override
  String get adminStatusSpamBlock => 'Спам-блок';

  @override
  String get adminActionUnblockSpam => 'Снять спам-блок';

  @override
  String get adminChatUnban => 'Разбанить';

  @override
  String get adminChatBan => 'Забанить';

  @override
  String get badgeScreenTitle => 'Бейджи';

  @override
  String get badgeAvailableBadges => 'Доступные бейджи';

  @override
  String get badgeAdminActions => 'Действия админа';

  @override
  String get badgeCopied => 'Бейдж создан';

  @override
  String get e2eeScreenTitle => 'Секретные чаты';

  @override
  String get e2eeBannerTitle => 'Секретные чаты (E2EE)';

  @override
  String get e2eeBannerSubtitle =>
      'Сквозное шифрование привязано к устройству. Сгенерируйте ключ для использования секретных чатов.';

  @override
  String get e2eeDeviceKey => 'Ключ устройства';

  @override
  String get e2eeKeyPairReady => 'Пара ключей готова';

  @override
  String get e2eeNoKeyPair => 'Нет пары ключей';

  @override
  String get e2eeTapToRegenerate => 'Нажмите для регенерации';

  @override
  String get e2eeGenerateKeyPair => 'Сгенерировать RSA-2048 ключ для E2EE';

  @override
  String get e2eeRotateKey => 'Ротация ключа';

  @override
  String get e2eeRotateKeySubtitle =>
      'Создать новую пару ключей (старые секретные чаты сломаются)';

  @override
  String get e2eeHowItWorks => 'Как это работает';

  @override
  String get e2eeHowItWorksDesc =>
      '• Каждое устройство генерирует свою RSA-2048 пару ключей\n• Публичный ключ передаётся на сервер\n• Приватный ключ остаётся только на этом устройстве\n• Секретные чаты видны только на этом устройстве\n• Сообщения шифруются AES-256-GCM\n• AES-ключ шифруется публичным RSA-ключом получателя';

  @override
  String get e2eeCreateSecretChat => 'Создать секретный чат';

  @override
  String get e2eeCreateSecretChatDesc =>
      'Для начала секретного чата откройте личный диалог из контактов.\nОпция секретного чата станет доступна после генерации ключей.';

  @override
  String get e2eeRotateConfirmTitle => 'Ротировать ключ?';

  @override
  String get e2eeRotateConfirmBody =>
      'Старые секретные чаты станут недоступны после ротации. Новые сообщения будут использовать новый ключ.';

  @override
  String get e2eeRotateConfirm => 'Ротировать';

  @override
  String get e2eeGeneratingKeys => 'Генерация ключей шифрования';

  @override
  String get e2eeGeneratingKeysDesc =>
      'Создаётся RSA-2048 пара ключей.\nЭто может занять несколько секунд...';

  @override
  String get e2eeKeyRotated => 'Ключ ротирован и загружен';

  @override
  String get chatMembersBanConfirmTitle => 'Забанить участника?';

  @override
  String get chatMembersUnbanConfirmTitle => 'Разбанить участника?';

  @override
  String get chatMembersBanConfirmBody =>
      'Участник потеряет доступ до тех пор, пока вы не восстановите его.';

  @override
  String get chatMembersUnbanConfirmBody =>
      'Восстановите участника и позвольте ему вернуться в беседу.';

  @override
  String get chatMembersMuteConfirmTitle => 'Заглушить участника?';

  @override
  String get chatMembersUnmuteConfirmTitle => 'Снять мут?';

  @override
  String get chatMembersMuteConfirmBody =>
      'Заглушенные участники остаются в чате, но не могут нормально участвовать.';

  @override
  String get chatMembersUnmuteConfirmBody =>
      'Разрешите участнику снова участвовать в беседе.';

  @override
  String chatMembersFailed(Object error) {
    return 'Ошибка: $error';
  }

  @override
  String contactsFailedToLoad(Object error) {
    return 'Не удалось загрузить: $error';
  }

  @override
  String contactsFailedToSearch(Object error) {
    return 'Не удалось найти: $error';
  }

  @override
  String get contactsCouldNotOpenChat => 'Не удалось открыть личный чат';

  @override
  String contactsFailedToOpenChat(Object error) {
    return 'Не удалось открыть личный чат: $error';
  }

  @override
  String contactsMembersCount(int count) {
    return '$count участников';
  }

  @override
  String get settingsSupportEmail => 'support@ni-os.ru';

  @override
  String get settingsPrivacyPolicyUrl => 'ni-os.ru/privacy';

  @override
  String get settingsTermsOfServiceUrl => 'ni-os.ru/terms';

  @override
  String get settingsWebsiteUrl => 'ni-os.ru';

  @override
  String get settingsAboutNiosMess => 'NiosMess';

  @override
  String get biometricTitle => 'Биометрия';

  @override
  String get biometricEnabled => 'Включена — вход по отпечатку/лицу';

  @override
  String get biometricDisabled => 'Отключена';

  @override
  String get biometricAuthReason =>
      'Подтвердите личность для включения биометрии';

  @override
  String chatManageCopiedLabel(Object title) {
    return '$title скопировано';
  }

  @override
  String get chatAiAssistant => 'ИИ помощник';

  @override
  String get chatAiProcessed => 'Текст успешно изменен ИИ';

  @override
  String get chatAiUndo => 'Отменить';

  @override
  String chatAiError(Object error) {
    return 'Ошибка обработки ИИ: $error';
  }

  @override
  String get chatAiFixErrors => 'Исправить';

  @override
  String get chatAiFormal => 'Деловой';

  @override
  String get chatAiTranslate => 'Перевести';

  @override
  String get chatAiLangEn => 'Англ.';

  @override
  String get chatAiLangRu => 'Рус.';

  @override
  String get chatAiLangDe => 'Нем.';

  @override
  String get chatAiLangFr => 'Фран.';

  @override
  String get chatAiLangEs => 'Исп.';

  @override
  String get chatAiLangZh => 'Кит.';

  @override
  String get chatDraftRestored => 'Черновик восстановлен на этом устройстве';

  @override
  String get fileOpenerInvalidUrl => 'Неверный URL файла';

  @override
  String get fileOpenerFailedOpenRemote => 'Не удалось открыть удалённый файл';

  @override
  String get fileOpenerCannotOpenType => 'Не удалось открыть файл этого типа';

  @override
  String get fileOpenerApkAndroidOnly =>
      'APK-файлы можно установить только на Android-устройствах';

  @override
  String fileOpenerFailedApk(Object error) {
    return 'Не удалось открыть APK: $error';
  }

  @override
  String get fileOpenerExeNotOnMobile =>
      'EXE-файлы нельзя открыть на мобильных устройствах';

  @override
  String fileOpenerFailedExe(Object error) {
    return 'Не удалось открыть EXE: $error';
  }

  @override
  String fileOpenerNoAppFound(Object type) {
    return 'Не найдено приложение для открытия файлов типа $type';
  }

  @override
  String get chatEmojiToggle => 'Эмодзи';

  @override
  String get chatVoiceMessage => 'Голосовое сообщение';

  @override
  String get chatSearchInChat => 'Поиск в чате';

  @override
  String get chatTyping => 'печатает...';

  @override
  String chatReactedWith(Object emoji) {
    return 'Отреагировал(а) $emoji';
  }

  @override
  String get chatReadBy => 'Прочитали';

  @override
  String get chatForwardedCard => 'Пересланное сообщение';

  @override
  String get messageSentByMe => 'Отправлено мной';

  @override
  String get messageSemantics => 'Сообщение';

  @override
  String get chatE2eeBanner =>
      'Сообщения защищены сквозным шифрованием. Никто вне этого чата не может их прочитать.';

  @override
  String get chatForwardRestricted => 'Пересылка запрещена в секретных чатах';

  @override
  String get chatDisappearingMessages => 'Исчезающие сообщения';

  @override
  String get chatDisappearingOff => 'Выкл';

  @override
  String get chatDisappearing5s => '5 секунд';

  @override
  String get chatDisappearing1m => '1 минута';

  @override
  String get chatDisappearing1h => '1 час';

  @override
  String get chatDisappearing1d => '1 день';
}
