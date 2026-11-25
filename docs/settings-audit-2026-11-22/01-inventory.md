# 01 · Карта экранов и пунктов настроек

Аудит раздела «Настройки» NiosMess. Роль: картограф. Только чтение кода.
Дата: 2026-11-22. Все пути — от `pulse_flutter/`.

---

## 1. Главные выводы

1. **Хаб настроек — это `ProfileScreen`, а не `SettingsHubScreen`.** `SettingsHubScreen` (`lib/screens/settings/settings_hub_screen.dart:15`) — 17-строчная обёртка, которая нигде в `lib` не используется; её импортируют только тесты (`test/e2e/niosgram_and_settings_e2e_test.dart:283`, `test/widgets/settings_master_detail_test.dart:70`). Маршрут `/settings` редиректит на `/main/settings` (`lib/router/app_router.dart:529-536`), который рендерит `ProfileScreen` (`lib/screens/main_shell_screen.dart:605`). Файл, названный в задаче «хабом», в рантайме мёртв.
2. **В хабе 9 разделов, а не 11.** Реестр объявляет 11 верхнеуровневых узлов (`lib/services/settings/settings_registry.dart:40-319`), но `getTopLevelSections()` жёстко выкидывает `account` и `system_device` (`settings_registry.dart:700-709`). «Аккаунт» существует только как экран `/settings/account` + шапка профиля, «Система и устройство» — только из «О приложении» и по прямому deep-link.
3. **7 экранов недостижимы напрямую из хаба:** `/settings/account`, `/settings/system-device`, `/settings/e2ee`, `/settings/sessions`, `/settings/privacy/rule/:key`, `/settings/privacy/blocked-users`, `/settings/wallpaper`. Из них `wallpaper` **вообще не имеет входа из интерфейса** — только deep-links `/w`, `/wallpaper` и `AppUrlLauncher` (`app_router.dart:327-349`, `lib/core/services/app_url_launcher.dart:269-289`).
4. **20 переключателей на 17 экранах, и блок уведомлений держится на двух независимых хранилищах:** мастер-выключатель пишет `ui.notifications` в SharedPreferences, а 5 тумблеров по типам — JSON `notification_preferences_<userId>`; при этом отказ в системном разрешении не откатывает мастер-выключатель (`lib/services/settings/notification_preference_action.dart:12-32`, `lib/widgets/notifications/notification_settings_section.dart:144-146`).
5. **`UiSettingsState` содержит 16 полей, которые нельзя изменить из UI и которые никто не читает** (например `chatEffectsEnabled`, `streamMedia`, `saveToGallery*`, `videoSeekSeconds`, `energySavingThreshold`), плюс ещё 3 читаемых, но недоступных для правки. Это «настройки-призраки»: они сериализуются в prefs, попадают в `resetAll()`, но не влияют ни на один пиксель (`lib/providers/ui_settings_provider.dart:84-110`, `772-820`).
6. **Три поля читаются приложением, но не имеют UI** — фактически константы: `messageBubbleRadius` (читается в `lib/widgets/message_bubble.dart:245`), `camera2Api` (`lib/screens/circle_video_recorder_screen.dart:232`), `showPerformanceOverlay` (`lib/main.dart:345`). Сеттеры есть, вызовов из экранов нет.
7. **Реестр описывает далеко не весь раздел.** 22 дочерних узла против ~157 реальных пунктов; 4 узла имеют жёстко зашитый русский текст (`settings_registry.dart:512`, `528`, `546`, `567`), 3 группы-строки (`settingsV2Group*`) и 2 подсказки вообще не используются.
8. **Карточки «проблем настроек» ведут в пустоту.** Все 4 маршрута/анкора из `lib/features/settings/domain/settings_issue.dart:32-66` не существуют: `/settings/notifications` нет в роутере (есть `/settings/preferences`), анкоров `notifications-permission`, `account-security`, `storage-cache-clear`, `app-update` нет ни в одном виджете. Плюс фабрика `notificationsDenied()` никогда не вызывается.
9. **Строки живут в двух источниках.** `context.l10n` берёт `AppLocalizations` из `lib/l10n/app_localizations.dart` + расширение `SecretChatL10n` (`lib/core/localization/secret_chat_l10n.dart:5-6`), которое проксирует новый ARB `lib/l10n/secret/app_ru.arb` через `SecretChatLocalizations`. Часть ключей настроек есть только в старом `app_localizations_ru.dart`, часть — только в новом ARB. Любая правка текста при редизайне должна попадать в оба места.
10. **Верстка экрана «Фон чатов» нарушает правила проекта:** жёстко зашитые русские строки вместо готовых l10n-ключей и `PopupMenuButton` вместо `MenuAnchor` (`lib/features/wallpaper/presentation/wallpaper_studio_screen.dart:128-215`, `224-239`).

---

## 2. Дерево экранов

```
/main/settings  ·  хаб  ·  lib/screens/profile_screen.dart (через main_shell_screen.dart:605)
│   (маршрут /settings → redirect, app_router.dart:529-536; /main/profile → redirect, :249-252)
│   мобильный: вертикальный список (profile_screen.dart:528-569)
│   широкий/веб: master-detail (profile_screen.dart:603-674)
│
├─ шапка профиля (не маршрут): аватар → лист выбора фото/видео (:121-211),
│   «Изменить» → EditProfileSheet (:708-758), QR → MyQrCodeSheet (:519)
├─ поиск по настройкам → SettingsRegistry.search (:289-373)
├─ карточки проблем (0-2) → SettingsIssueCard (:438-447)
│
├─ 1. /settings/chats .............. Чаты и звонки .................. lib/screens/settings_chats_screen.dart
│     └─ диалог: выбор устройств звонка (showCallDevicesDialog)
├─ 2. /settings/preferences ........ Уведомления и звуки ............ settings_preferences_screen.dart
│     └─ встроенный блок NotificationSettingsSection (виджет, не экран)
├─ 3. /settings/appearance ......... Оформление ..................... settings_appearance_screen.dart
│     └─ лист: кастомный цвет (CustomColorPickerSheet)
├─ 4. /settings/language-region .... Язык и время ................... settings_language_region_screen.dart
│     └─ лист: выбор часового пояса (_TimeZonePicker)
├─ 5. /settings/energy-saving ...... Анимации и энергосбережение .... settings_energy_saving_screen.dart
│     └─ системный диалог Android: battery optimization
├─ 6. /settings/privacy ............ Приватность и безопасность .... settings_privacy_screen.dart
│     ├─ 6.1 /settings/privacy/rule/:key ... правило ............... lib/screens/privacy_rule_detail_screen.dart
│     │      └─ лист: выбор пользователя (showUserSearchPickerSheet)  ← глубина 4
│     ├─ 6.2 /settings/privacy/blocked-users ....................... lib/screens/blocked_users_screen.dart
│     │      └─ лист: выбор пользователя + строка → /u/:username
│     ├─ 6.3 /settings/e2ee ......... Секретные чаты ............... lib/screens/e2ee_settings_screen.dart
│     │      └─ OrdinaryE2eeSettings (виджет, ~15 пунктов)
│     └─ 6.4 /settings/sessions ..... Активные сессии .............. lib/screens/sessions_screen.dart
│            (обёртка) → lib/features/sessions/presentation/sessions_screen.dart
│            └─ лист: детали сессии
├─ 7. /settings/storage ............ Данные и память ................ settings_storage_screen.dart
├─ 8. /settings/plus ............... Nios+ · NiosAI ................. settings_plus_screen.dart
├─ 9. /settings/about .............. Помощь и о приложении .......... settings_about_screen.dart
│     ├─ /settings/system-device .... Система и устройство .......... settings_system_device_screen.dart
│     ├─ /help/faq .................. Справка и FAQ ................. lib/screens/help_faq_screen.dart
│     ├─ /legal/privacy ............. Политика ...................... LegalViewerScreen
│     ├─ /legal/tos + /legal/terms .. Условия (два маршрута-дубля) .. LegalViewerScreen
│     ├─ /legal/consent ............. Согласие ...................... LegalViewerScreen
│     └─ диалоги: баг-репорт, альфа-тест, лицензии, обновление
│
└─ (сирота) /settings/wallpaper .... Фон чатов ...................... features/wallpaper/presentation/wallpaper_studio_screen.dart
       вход только: /w/:code, /w, /wallpaper, AppUrlLauncher
```

### 2.1. Экраны без входа из хаба

| Экран | Маршрут | Как реально попасть |
|---|---|---|
| Аккаунт | `/settings/account` | поиск по настройкам (мобильный: `context.push`, `profile_screen.dart:363-367`), детальная панель на десктопе по умолчанию (`settings_navigation_provider.dart:31`), deep-link. В сайдбаре отсутствует |
| Система и устройство | `/settings/system-device` | «О приложении» → «Диагностика устройства» (`settings_about_screen.dart:231-245`), прямой deep-link; на вебе редирект на `/settings/about` (`app_router.dart:639-650`) |
| Секретные чаты (E2EE) | `/settings/e2ee` | «Приватность» → «Секретные чаты» (`settings_privacy_screen.dart:285-304`), уведомление в чате (`lib/widgets/chat/ordinary_e2ee_notice.dart:35`), поиск, deep-link |
| Активные сессии | `/settings/sessions` | «Приватность» → блок «Доступ к аккаунту» (`account_security_section.dart:104-121`), поиск, deep-link |
| Правило приватности | `/settings/privacy/rule/:key` | «Приватность» → 12 строк-правил (`settings_privacy_screen.dart:22-24`) |
| Заблокированные | `/settings/privacy/blocked-users` | «Приватность» → «Черный список» (`settings_privacy_screen.dart:272-284`) |
| Фон чатов | `/settings/wallpaper` | **только** deep-links `/w/:code`, `/w`, `/wallpaper` и `AppUrlLauncher` (`app_router.dart:327-349`); из UI ссылок нет |

### 2.2. Настройки, открываемые листом/диалогом, а не маршрутом

| Поверхность | Где открывается | Тип |
|---|---|---|
| Выбор источника аватара (фото/видео) | `profile_screen.dart:133-154` | sheet |
| EditProfileSheet (имя, @username, био, телефон, ДР, часы, бейджи) | `profile_screen.dart:714-754` | sheet |
| BadgeSelectorDialog | `profile_screen.dart:250-258` | dialog |
| MyQrCodeSheet | `profile_screen.dart:519`, `:552`, `:734` | sheet |
| Кастомный цвет палитры | `settings_appearance_screen.dart:237-248` | sheet |
| Выбор часового пояса | `settings_language_region_screen.dart:123-129` | sheet |
| Автоблокировка (таймаут) | `account_security_section.dart:36-62` | sheet |
| Устройства звонка (микрофон/камера/динамик) | `settings_chats_screen.dart:96` | dialog |
| Выбор пользователя (исключения приватности) | `privacy_rule_detail_screen.dart:150` | sheet |
| Выбор пользователя (блокировка) | `blocked_users_screen.dart:43` | sheet |
| Детали сессии | `features/sessions/presentation/sessions_screen.dart:52-59` | sheet |
| Баг-репорт | `settings_about_screen.dart:195-198` | dialog |
| Альфа-тест | `settings_about_screen.dart:208` | dialog |
| Лицензии | `settings_about_screen.dart:372-384` | page (showLicensePage) |
| Обновление приложения | `widgets/settings/about_update_tile.dart:30,44` | dialog |

---

## 3. Таблицы по экранам

Легенда контролов: **nav** — переход, **sw** — переключатель, **seg** — сегмент-кнопки, **sl** — ползунок, **act** — действие, **val** — статичное значение, **info** — только текст.

### 3.1. Хаб `/main/settings` — `lib/screens/profile_screen.dart`

| № | Пункт (l10n / RU) | Группа | Контрол | Где хранится | Платформа |
|---|---|---|---|---|---|
| 1 | аватар (`settingsProfileChangePhoto`) | шапка | act → sheet фото/видео | сервер: `authRepository.uploadAvatar` (`:196-198`) | все |
| 2 | `profileEdit` «Изменить» | шапка | act → EditProfileSheet | сервер (профиль) | все |
| 3 | `settingsV2Qr` «Мой QR-код» | шапка | act → sheet | — | все |
| 4 | `settingsV2Search` «Поиск настроек» | — | SearchAnchor | — | все (на широком — inline) |
| 5 | `settingsV2Chats` «Чаты и звонки» | Общение | nav `/settings/chats` | — | все |
| 6 | `settingsV2Notifications` «Уведомления и звуки» | Общение | nav `/settings/preferences` | — | все |
| 7 | `settingsV2Appearance` «Оформление» | Оформление | nav `/settings/appearance` | бейдж: `themeMode` (`:265-270`) | все |
| 8 | `settingsV2Language` «Язык и время» | Оформление | nav `/settings/language-region` | бейдж: `Locale` (`:276-281`) | все |
| 9 | `settingsV2Motion` «Анимации и энергосбережение» | Оформление | nav `/settings/energy-saving` | бейдж пустой (`:282-283`) | все (на вебе заголовок `webMotionTitle`) |
| 10 | `settingsV2Privacy` «Приватность и безопасность» | Аккаунт и защита | nav `/settings/privacy` | — | все |
| 11 | `settingsV2Storage` «Данные и память» | Приложение | nav `/settings/storage` | бейдж: `storageSnapshot.totalBytes` (`:271-275`) | бейдж скрыт на вебе |
| 12 | `Nios+ · NiosAI` (жёсткая строка, `settings_registry.dart:276`) | Приложение | nav `/settings/plus` | — | все |
| 13 | `settingsV2About` «Помощь и о приложении» | Приложение | nav `/settings/about` | бейдж: версия приложения (`:284-285`) | все |
| 14 | `profileLogout` «Выйти» | — | act (danger) + confirm | серверная сессия | все |
| 15-16 | карточки проблем (0-2) | — | info + act | `settingsHealthProvider` (`:438-447`) | все |

Группы хаба формируются в `profile_screen.dart:378-399` из `SettingsGroup` (`lib/models/settings/settings_node.dart:9-45`). Группа `SettingsGroup.account` в хабе не отображается никогда: единственный её видимый член — `about`, у которого группа `about`.

### 3.2. `/settings/account` — `lib/screens/settings_account_screen.dart`

| № | Пункт (l10n / RU) | Группа | Контрол | Где хранится | Платформа |
|---|---|---|---|---|---|
| 1 | `profileDisplayName` «Имя» | (без заголовка) | val + act «копировать» | сервер: `auth.profile.displayName` | все |
| 2 | `profileUsername` «@username» | — | val + копирование | сервер | все (скрыт если пусто) |
| 3 | `Nios ID` (жёсткая строка) | — | val + копирование | сервер: `auth.session.niosId` | все (скрыт если пусто) |
| 4 | `settingsV2SecurityLink` «Настройки безопасности» | — | nav → privacy | — | все; на вебе `go('/main/settings?section=privacy')` (`:69-77`) |

### 3.3. `/settings/appearance` — `lib/screens/settings_appearance_screen.dart`

| № | Пункт (l10n / RU) | Группа | Контрол | Где хранится | Платформа |
|---|---|---|---|---|---|
| 1 | `appearanceThemeMode` «Выбор темы» — Системная/Светлая/Тёмная | — | seg | `ui.themeMode` (prefs, `ui_settings_provider.dart:545`) | все |
| 2 | `appearanceSystemColors` «Системные цвета» | `appearancePaletteTitle` «Палитра» | sw | `ui.useSystemDynamic` (`:638`) | **только не-web** (`:283`) |
| 3-10 | 8 палитр: `appearanceLabelAmethyst/Lagoon/Meadow/Ember/Orchid/Slate/Sky/Rose` | Палитра | выбор кружка (PageView) | `ui.seedColor` (`:551`) | все |
| 11 | `appearanceCustomColor` «Пользовательский цвет» | Палитра | act → sheet | `ui.seedColor` | все |
| 12 | `appearancePaletteStyle` «Характер палитры» — 5 вариантов | Палитра | seg | `ui.paletteStyle` (`:678`) | все |
| 13 | `appearanceTextScale` «Масштаб текста» — 85/100/115/130 % | `settingsV2Density` «Плотность интерфейса» | seg | `ui.fontScale` (`:643`) | все |
| 14 | `appearanceCompactMode` «Компактный режим» | Плотность | sw | `ui.compact` (`:562`) | все |
| 15 | `appearanceUiRounding` «Скругление интерфейса» 8-28 dp | Плотность → `settingsV2Advanced` (раскрывашка) | sl | `ui.cornerRadius` (`:539`) | все |

### 3.4. `/settings/chats` — `lib/screens/settings_chats_screen.dart`

| № | Пункт (l10n / RU) | Группа | Контрол | Где хранится | Платформа |
|---|---|---|---|---|---|
| 1 | `inboxFolders` «Папки чатов» | (без заголовка) | nav → `openChatFolders` | сервер/локально (вне раздела) | все |
| 2 | `settingsChatsSendOnEnter` «Отправка по клавише Enter» | — | sw (`chats.sendOnEnter`) | `ui.sendOnEnter` (`:648`) | все (фактически desktop/веб) |
| 3 | `settingsChatsQuickReaction` «Быстрая реакция» — 8 эмодзи | — | набор ChoiceChip | `ui.doubleTapReactionEmoji` (`:652`) | все |
| 4 | `callDevicesTitle` «Звук и камера» | — | nav → диалог | вне prefs (устройства) | зависит от платформы (диалог сам сообщает) |

### 3.5. `/settings/preferences` — `lib/screens/settings_preferences_screen.dart`

| № | Пункт (l10n / RU) | Группа | Контрол | Где хранится | Платформа |
|---|---|---|---|---|---|
| 1 | `noticeTitle` «Уведомления»: статус разрешения | `NotificationSettingsSection` | info | `PushNotificationService.isPermissionGranted` | все |
| 2 | статус регистрации push | — | info | `PushNotificationService.deviceRegistered` | только если push поддержан и разрешён |
| 3 | `settingsPushNotifications` «Push-уведомления» | — | sw (`push_notifications`) | `ui.notifications` + повторная запись `ui.notifications` (`notification_preference_action.dart:21-25`) | все |
| 4 | `noticeMessages` «Сообщения» | — | sw | SharedPreferences `notification_preferences_<userId>` (`notification_preferences_provider.dart:57`) | все |
| 5 | `noticeCalls` «Входящие звонки» | — | sw | там же | все |
| 6 | `noticeActivity` «Активность NiosGram» | — | sw | там же | все |
| 7 | `noticePreview` «Показывать текст» | — | sw | там же | все |
| 8 | `noticeSound` «Звук уведомлений» | — | sw | там же | все |
| 9 | `appearanceSoundEffects` «Звуковые эффекты» | `settingsPreferencesSoundHaptics` «Звук и тактильный отклик» | sw | `ui.soundEffects` (`:577`) | все |
| 10 | `settingsVolume` «Громкость» 0-100 % | — | sl | `ui.soundVolume` (`:583`) | все (виден только при включённых эффектах) |
| 11 | `noticeSoundTest` «Проверить звук» | — | act | — | все |
| 12 | `settingsHapticFeedback` «Тактильный отклик» | — | sw | `ui.haptics` (`:567`) | только если `clientCapabilities.haptics` (Android/iOS, `client_capabilities.dart:12-14`) |

### 3.6. `/settings/privacy` — `lib/screens/settings_privacy_screen.dart` (самый длинный по числу пунктов)

| № | Пункт (l10n / RU) | Группа | Контрол | Где хранится | Платформа |
|---|---|---|---|---|---|
| 1 | `privacyRuleCalls` «Звонки» | `privacyCategoryCommunication` «Связь» | nav → правило `calls` | сервер: правило `calls` | все |
| 2 | `privacyRuleDirectMessages` «Личные сообщения» | Связь | nav → `messages` | сервер | все |
| 3 | `privacyRuleVoiceMessages` «Голосовые сообщения» | Связь | nav → `voice_messages` | сервер | все |
| 4 | `settingsV2ReadReceipts` «Отчёты о прочтении» | Связь | sw | сервер: `read_receipts` (`privacy_provider.dart:33-34`) | все |
| 5 | `settingsV2Typing` «Индикатор набора текста» | Связь | sw | сервер: `typing_indicators` | все |
| 6 | `privacyRulePhone` «Номер телефона» | `privacyCategoryPersonalData` «Личные данные» | nav → `phone` | сервер | все |
| 7 | `privacyRuleBirthDate` «Дата рождения» | Личные данные | nav → `birthday` | сервер | все |
| 8 | `privacyRuleAvatar` «Фотографии профиля» | Личные данные | nav → `profile_photos` | сервер | все |
| 9 | `privacyRuleBio` «О себе» | Личные данные | nav → `bio` | сервер | все |
| 10 | `privacyRuleGifts` «Подарки» | Личные данные | nav → `gifts` | сервер | все |
| 11 | `privacyRuleMusic` «Сохранённая музыка» | Личные данные | nav → `saved_music` | сервер | все |
| 12 | `privacyRuleLastSeen` «Время захода и статус в сети» | `privacyCategoryActivity` «Активность» | nav → `last_seen` | сервер + зеркало `ui.hideOnline` (`privacy_provider.dart:141,199,231`) | все |
| 13 | `privacyRuleForwards` «Пересылка сообщений» | Активность | nav → `forwards` | сервер | все |
| 14 | `privacyRuleInvites` «Приглашения в группы и каналы» | Активность | nav → `invites` | сервер | все |
| 15 | `settingsActiveSessions` «Активные сессии» | `settingsAccountAccessTitle` «Доступ к аккаунту» | nav → sessions | сервер | все |
| 16 | `biometricTitle` «Биометрия» (App Lock) | `settingsProtectionTitle` «Защита» | sw | `flutter_secure_storage` `app_lock.enabled` (`app_lock_controller.dart:8`) | не-web и `appLock.isSupported` |
| 17 | `settingsV2LockTimeout` «Автоблокировка» | Защита | nav → sheet | secure storage `app_lock.timeout` (`app_lock_controller.dart:9`) | только при включённом App Lock |
| 18 | `settingsAccountNiosIdSecurity` «Безопасность и 2FA в Nios ID» | Защита | nav → внешний URL `ni-os.ru/id/account` | вне приложения | все |
| 19 | `privacyBlacklist` «Черный список» | `privacyCategorySecurity` «Безопасность и блокировки» | nav → blocked-users | сервер: `blockedUsers` | все |
| 20 | `settingsSecretChatsTitle` «Секретные чаты» | Безопасность | nav → e2ee | — | все |
| 21 | `settingsSpamBlockTitle` «Ваш аккаунт на спам-блоке» → `settingsServerLimitsTitle` «Серверные ограничения» / `settingsProduction` «Продакшн» | — | info | серверный флаг `profile.spamBlock` | только при спам-блоке |

### 3.7. `/settings/privacy/rule/:key` — `lib/screens/privacy_rule_detail_screen.dart`

| № | Пункт | Группа | Контрол | Где хранится | Платформа |
|---|---|---|---|---|---|
| 1 | `privacyPolicyEveryone/Contacts/Nobody` (+ описания) | `privacyWhoCanInteract` | радио-список | сервер: `updateRule` (`:124-131`) | все |
| 2 | `privacyAlwaysAllow` → `privacyAddUserTooltip` «Добавить пользователя» | `privacyAlwaysAllow` | act → sheet | сервер: `alwaysAllow[]` | все |
| 3 | чипы `alwaysAllow` (с удалением) | — | чипы | сервер | все |
| 4 | `privacyNeverAllow` → «Добавить пользователя» | `privacyNeverAllow` | act → sheet | сервер: `neverAllow[]` | все |
| 5 | чипы `neverAllow` | — | чипы | сервер | все |

### 3.8. `/settings/privacy/blocked-users` — `lib/screens/blocked_users_screen.dart`

| № | Пункт | Группа | Контрол | Где хранится | Платформа |
|---|---|---|---|---|---|
| 1 | `searchBlockedHint` «Поиск по заблокированным...» | — | текстовое поле (локальная фильтрация, `:96-104`) | локально в состоянии | все |
| 2 | `blockUserAction` «Заблокировать пользователя» | — | act (в AppBar, `:110-116`) | сервер: `blockUser` | все |
| 3 | список заблокированных + `unblockAction` на строке; tap → `/u/:username` | — | nav/act | сервер: `blockedUsers` | все |

### 3.9. `/settings/storage` — `lib/screens/settings_storage_screen.dart`

Нативная ветка (`:142-384`):

| № | Пункт (l10n / RU) | Группа | Контрол | Где хранится | Платформа |
|---|---|---|---|---|---|
| 1 | карточка «занято» + `settingsStorageEstimate` | — | info + act «обновить» | `storageSnapshotProvider` | не-web |
| 2 | `settingsStorageCategoryAppData` «Данные» | `settingsStorageSafeCleanup` | val | локальный скан | не-web |
| 3 | `settingsStorageClearTemporary` «Очистить временный кэш» (`cache_cleaning`) | — | act (danger) + confirm | `LocalStorageService.clearTemporaryFiles` | не-web |
| 4 | `settingsStorageClearDrafts` «Очистить черновики» | — | act (danger) + confirm | `LocalStorageService.clearDrafts` | не-web |
| 5-13 | `settingsV2StorageImages/Videos/Audio/Files/Stickers/Avatars/Drafts/SecretCache/Other` | `settingsV2StorageDetails` «Использование памяти» | val | `snapshot.bytesFor(cat)` | не-web |
| 14 | `settingsV2Wifi` «Через Wi-Fi» (`auto_download_wifi`) | `settingsV2AutoDownload` «Автозагрузка медиа» | sw | `ui.autoDownloadWifi` (`:658`) | все |
| 15 | `settingsV2MobileData` «Через мобильную сеть» | Автозагрузка | sw | `ui.autoDownloadCellular` (`:663`) | не-web |

Веб-ветка (`:100-140`):

| № | Пункт | Группа | Контрол | Где хранится |
|---|---|---|---|---|
| 1 | `webStorageDescription` «Данные в браузере» | `webStorageTitle` | info | — |
| 2 | `webStorageDrafts` «Черновики обычных чатов» | — | val | `snapshot.draftCount` |
| 3 | `webAutoDownload` «Автоматически загружать медиа» | `webAutoDownload` | sw | `ui.autoDownloadWifi` (тот же ключ) |

### 3.10. `/settings/language-region` — `lib/screens/settings_language_region_screen.dart`

| № | Пункт (l10n / RU) | Группа | Контрол | Где хранится | Платформа |
|---|---|---|---|---|---|
| 1 | `languageRegionAppLanguage` «Язык приложения» — Авто/Русский/English | — | seg | `ui.localeCode` (`:588`) | все |
| 2 | `languageRegionTimeZone` «Часовой пояс» — Авто/Вручную | — | seg | `ui.timeZoneMode` (`:597`) | все |
| 3 | текущая зона (UTC±hh:mm / `Europe/Moscow`) | — | nav → sheet (только в ручном режиме) | `ui.timeZoneId` (`:600`) | все |
| 4 | `settingsLanguageLocalTime` «Локальное время» | `languageRegionCurrentTime` | info (таймер раз в минуту) | вычисляется | все |

### 3.11. `/settings/energy-saving` — `lib/screens/settings_energy_saving_screen.dart`

| № | Пункт (l10n / RU) | Группа | Контрол | Где хранится | Платформа |
|---|---|---|---|---|---|
| 1 | `settingsV2Stickers` «Анимация стикеров» (`motion.stickers`) | `settingsV2ChatAnimations` | sw | `ui.animateStickers` (`:716`) | все |
| 2 | `settingsV2Emoji` «Анимированные эмодзи» (`motion.emoji`) | Анимации в чатах | sw | `ui.animateEmoji` (`:721`) | все |
| 3 | `appearanceOptimizeWeakDevices` «Оптимизация для слабых устройств» (`motion.optimization`) | `settingsV2Graphics` «Производительность» | sw | `ui.optimizeWeak` (`:626`) | все |
| 4 | `settingsBackgroundTitle` «Работа в фоне» — Отключено/Экономный/Надёжный | Работа в фоне | seg | `ui.backgroundMode` (`:631`) | **только Android** (`:80`) |
| 5 | `privacyBatteryOptimization` «Работа без ограничений батареи» | Работа в фоне | act | системная настройка ОС | Android + режим «Надёжный» |
| 6 | `settingsBackgroundNotAvailable` «Режимы фона» / «Доступно только на Android» | Работа в фоне | info | — | не-Android (кроме web), `:172-183` |

### 3.12. `/settings/plus` — `lib/screens/settings_plus_screen.dart`

| № | Пункт (l10n / RU) | Группа | Контрол | Где хранится | Платформа |
|---|---|---|---|---|---|
| 1 | статус Nios+ (`settingsPlusActive/ActiveUntil/Grace/GraceUntil`) | — | val | сервер: `get_my_limits` (`:84-93`) | все (нужна авторизация) |
| 2 | `commonRetry` «Повторить» | — | act | — | при ошибке статуса |
| 3 | `AiUsageIndicatorCard` (остаток Ниосиков) | — | info | `auth.profile.aiUsage` | если есть |
| 4 | `PlusPurchaseOptions` (тарифы/покупка) | — | act | сервер | все |
| 5-10 | `settingsPlusAiBudget/Files/Communities/Emoji/GracePeriod` + «NiosAI Prime · SPrime» | `settingsPlusBenefits` «В подписке» | info | — | все |
| 11 | `settingsPlusTrial` «Попробовать бесплатно на 1 день» | — | act (FilledButton) | сервер: `claim_nios_plus_trial` (`:115-121`) | если триал не использован |

### 3.13. `/settings/about` — `lib/screens/settings_about_screen.dart`

| № | Пункт (l10n / RU) | Группа | Контрол | Где хранится | Платформа |
|---|---|---|---|---|---|
| 1 | бренд-марк + `appName` + `aboutTagline` | — | info (+easter egg) | — | все |
| 2 | чип версии (`AboutVersionChip`) | — | act «копировать» | `PackageInfo` | все |
| 3 | `aboutSystemUpdateTitle` «Обновление системы» | — | act | `otaUpdateProvider` | **только не-web** (`:152`) |
| 4 | табы `aboutTabWhatsNew/Legal/Team` | — | seg | локальный `_tab` | все |
| 5 | `aboutFaqAction` «Справка и FAQ» | `settingsAboutSupport` | nav `/help/faq` | — | все |
| 6 | `aboutReportBugAction` «Сообщить о баге» | Помощь | act → диалог | `supportRepository.createTicket` | все |
| 7 | `aboutShareAction` «Поделиться» | Помощь | act | — | все |
| 8 | `aboutAlphaTestAction` «Альфа-тест» | Помощь | act → диалог | — | все |
| 9 | `Telegram` `@niosmess` | `settingsAboutLinks` | nav → URL | — | все |
| 10 | `ni-os.ru` | Ссылки | nav → URL | — | все |
| 11 | `settingsV2Diagnostics` «Диагностика устройства» | `settingsV2Advanced` | nav → system-device | — | только не-web (`:231`) |
| 12 | `settingsV2Reset` «Сбросить локальные настройки» | Дополнительно | act (danger) + confirm | `uiSettingsProvider.resetAll()` (`:96`) | все |
| 13 | футер `aboutCopyrightFooter` + канал сборки | — | info | `BuildInfo` | все |
| 14-17 | таб «Документы»: `legalPrivacyTitle`, `legalToSTitle`, `legalConsentTitle`, `aboutThirdPartyLicensesTitle` | — | nav `/legal/*` / showLicensePage | — | все |
| 18 | таб «Что нового»: текст первого релиза из `assets/CHANGELOG.md` | — | info | ассет | все |
| 19 | таб «Команда»: `kTeamMembers` | — | nav → t.me | `core/constants/team.dart` | все |

### 3.14. `/settings/system-device` — `lib/screens/settings_system_device_screen.dart`

| № | Пункт (l10n / RU) | Группа | Контрол | Где хранится | Платформа |
|---|---|---|---|---|---|
| 1 | бренд + маркетинговое имя + ОС | — | info | `deviceHardwareProvider` | не-web (на вебе → About, `:22`) |
| 2 | `settingsDeviceRam` «Оперативная память» | `settingsDeviceMemory` | val (шкала) | провайдер | не-web |
| 3 | `settingsDeviceStorage` «Накопитель» | Память | val (шкала) | провайдер | не-web |
| 4 | `settingsDeviceProcessor` «Процессор» | `settingsDeviceSpecs` «Характеристики» | val + копирование | провайдер | не-web |
| 5 | `settingsDeviceDisplay` «Экран» | Характеристики | val + копирование | провайдер | не-web |
| 6 | `settingsDeviceCameras` «Камеры» | Характеристики | val + копирование | провайдер | не-web |
| 7 | `settingsDeviceOs` «Система» | Характеристики | val + копирование | провайдер | не-web |
| 8 | `settingsDeviceSecurityPatch` «Патч безопасности» | Характеристики | val + копирование | провайдер | если непусто |
| 9 | `settingsDeviceModel` «Модель» | Характеристики | val + копирование | провайдер | если непусто |
| 10 | `settingsDeviceBuild` «Сборка» | Характеристики | val + копирование | провайдер | если непусто |

### 3.15. `/settings/e2ee` — `lib/screens/e2ee_settings_screen.dart` + `lib/widgets/settings/ordinary_e2ee_settings.dart`

| № | Пункт (l10n / RU) | Группа | Контрол | Где хранится | Платформа |
|---|---|---|---|---|---|
| 1 | `settingsE2eeEncrypt` «Шифровать обычные чаты» | `settingsE2eeOrdinaryTitle` | sw | `OrdinaryE2eeService.enabled` (локально/сервер) | все |
| 2 | `settingsE2eeMeshTitle` «Bluetooth-мостик» | `settingsE2eeOfflineTitle` | sw | prefs `niosmess.bluetooth_fallback.v1` (`mesh_preferences.dart:12`) | Android/Windows (`mesh_preferences.dart:6-9`) |
| 3 | статус mesh + `settingsE2eeBluetoothPermission` | — | act | сервис | Android/Windows |
| 4 | `settingsE2eeShowRecovery` / `HideRecovery` | `settingsE2eeRecoveryTitle` | act (раскрытие) | сервис E2EE | при инициализированном и незаблокированном |
| 5 | `settingsE2eeBackupSaved` | — | act | `service.backupAcknowledged` | там же |
| 6 | `settingsE2eeOwnFingerprint` | — | act (раскрытие) | сервис | там же |
| 7 | поле кода восстановления + `settingsE2eeRestoreAction` | `settingsE2eeRestoreTitle` | act | сервис | только при `service.locked` |
| 8 | `settingsE2eeLostKeys` «Сбросить ключи» | Restore | act (danger) + confirm | сервис | там же |
| 9 | `settingsE2eePairCodeCreate` / `PairApproveAction` + поле/QR | `settingsE2eeLinkTitle` | act | сервис (pairing) | при инициализированном |
| 10 | `settingsE2eeDirectChat` (выбор чата) + `settingsE2eeAcceptFingerprint` | `settingsE2eeContactTitle` | dropdown + act | сервис | при инициализированном, не locked |
| 11 | `e2eeDeviceKey` «Ключ устройства»: `e2eeGenerateKeyPair` / `e2eeKeyPairReady` + отпечаток | `e2eeDeviceKey` | act / val | `secretChatCoordinatorProvider` (`e2ee_settings_screen.dart:64-88`) | все |
| 12 | `e2eeEraseTitle` «Удалить секретные чаты» | `profileDangerZone` | act (danger) + confirm | сервер: `eraseSecret` + локальный кэш | при наличии ключа |
| 13 | `e2eeHowItWorks` «Как это работает» | — | info | — | все |

### 3.16. `/settings/sessions` — `lib/features/sessions/presentation/sessions_screen.dart`

| № | Пункт (l10n / RU) | Группа | Контрол | Где хранится | Платформа |
|---|---|---|---|---|---|
| 1 | `settingsSessionsCurrentDevice` «Текущее устройство» | — | nav → лист деталей | сервер: `sessionsControllerProvider` | все |
| 2 | `settingsSessionsOthers` «Другие устройства», по строке на сессию | — | nav → лист деталей | сервер | все |
| 3 | `sessionsTerminateAll` «Завершить все остальные сессии» | — | act (danger) + confirm | сервер | если есть другие сессии |
| 4 | `settingsSessionsNoOtherDevices` «Нет других активных сессий» | — | val | — | если других нет |

### 3.17. `/settings/wallpaper` (сирота) — `lib/features/wallpaper/presentation/wallpaper_studio_screen.dart`

| № | Пункт (жёсткий RU, l10n не используется) | Контрол | Где хранится | Платформа |
|---|---|---|---|---|
| 1 | «Для всех чатов» / «Для «<чат>»» | ChoiceChip | `_applyToChatOnly` (локально) | все |
| 2 | табы «Готовые» / «Узор» / «Цвета» / «Эффекты» | TabBar | черновик `_draftConfig` | все |
| 3 | «Применить» | act | prefs `nios_global_wallpaper_v1` / `nios_chat_wallpapers_map_v1` (`chat_wallpaper_provider.dart:8-9`) | все |
| 4 | «Отмена» | act | — | все |
| 5 | меню «Сбросить по умолчанию» | act | черновик | все |
| 6 | меню «Скопировать код обоев» | act (копирование base64) | — | все |

### 3.18. Вспомогательные экраны

`/help/faq` (`lib/screens/help_faq_screen.dart:50-90`): поиск + 10 Q&A (`aboutFaqQ1..Q10`) + блок поддержки. Групп/настроек нет.

`/legal/privacy`, `/legal/tos`, `/legal/terms`, `/legal/consent` (`app_router.dart:675-706`): статичный `LegalViewerScreen`. `/legal/tos` и `/legal/terms` — один и тот же документ (`LegalDocType.tos`, `:684-697`).

---

## 4. Дубли

| # | Что дублируется | Где №1 | Где №2 | Комментарий |
|---|---|---|---|---|
| D1 | Имя, @username, аватар | шапка хаба (`profile_screen.dart:459-526`) | «Аккаунт» (`settings_account_screen.dart:37-59`) + EditProfileSheet | одно и то же читается/правится в трёх поверхностях |
| D2 | Язык и часовой пояс | `settings_language_region_screen.dart:29-104` | онбординг (`lib/screens/onboarding_screen.dart:53-63`, `565-680`) | две независимые UI на одни и те же `ui.localeCode`/`ui.timeZone*` |
| D3 | Nios ID / 2FA | «Аккаунт» → «Управление Nios ID» (`profile_screen.dart:747-752`) | «Приватность» → «Безопасность и 2FA в Nios ID» (`account_security_section.dart:167-174`) | один и тот же URL `ni-os.ru/id/account` |
| D4 | Вход в «Приватность» | хаб, группа «Аккаунт и защита» (`profile_screen.dart:391-394`) | «Аккаунт» → «Настройки безопасности» (`settings_account_screen.dart:64-79`) | два пути в один экран |
| D5 | Вход в «Сессии» | «Приватность» (`account_security_section.dart:104-121`) | поиск/реестр `sessions_management` (`settings_registry.dart:543-561`) | одинаковый target |
| D6 | Вход в «E2EE» | «Приватность» (`settings_privacy_screen.dart:285-304`) | уведомление в чате (`ordinary_e2ee_notice.dart:35`) + реестр | три входа |
| D7 | «Звук» | `noticeSound` «Звук уведомлений» (`notification_settings_section.dart:162-167`) | `appearanceSoundEffects` «Звуковые эффекты» + `settingsVolume` (`settings_preferences_screen.dart:84-142`) | разные хранилища, похожие названия — путаница на одном экране |
| D8 | Значение темы | сегменты в «Оформлении» | бейдж раздела в хабе (`profile_screen.dart:265-270`) | информационный дубль |
| D9 | Размер кэша | подпись строки «Очистить временный кэш» (`settings_storage_screen.dart:293`) | строка категории «Кеш» (`:314-332`) | одно число дважды на экране |
| D10 | Автозагрузка медиа | нативная ветка (`settings_storage_screen.dart:338-380`) | веб-ветка (`:121-137`) | параллельная реализация одного ключа `ui.autoDownloadWifi` |
| D11 | Пункт «Показывать текст» | реальная строка `noticePreview` | узел реестра `notifications.preview` (`settings_registry.dart:621-630`) | поиск ведёт к тому же, но подпись `settingsV2Preview` |
| D12 | «Сброс настроек» частично дублирует всё оформление/язык/звук | `resetAll()` (`ui_settings_provider.dart:772-820`) | экраны оформления/языка/уведомлений | но при этом не сбрасывает notification prefs, App Lock, обои, mesh |
| D13 | «Система и устройство» | скрытый раздел (`settings_registry.dart:223-246`) | «О приложении» → «Диагностика» (`settings_about_screen.dart:231-245`) | один экран, два входа, один из них скрыт |
| D14 | `/legal/tos` и `/legal/terms` | `app_router.dart:684` | `app_router.dart:692` | два маршрута, один документ |

---

## 5. Настройки без эффекта

### 5.1. Поля `UiSettingsState`, которые нельзя изменить из UI и которые никто не читает

Проверено поиском по имени поля во всём `lib` (кроме `ui_settings_provider.dart` совпадений нет). Значение сохраняется в SharedPreferences только если вызвать сеттер — а сеттер не вызывается ни из одного экрана (проверено поиском `setXxx` по `lib`).

| Поле | Ключ prefs | Сеттер | Читателей |
|---|---|---|---|
| `autoDownloadRoaming` | `ui.autoDownloadRoaming` | `setAutoDownloadRoaming` (`:666`) | 0 |
| `chatEffectsEnabled` | `ui.chatEffects` | `setChatEffectsEnabled` (`:724`) | 0 |
| `streamMedia` | `ui.streamMedia` | `setStreamMedia` (`:729`) | 0 |
| `saveToGalleryPrivate` | `ui.saveGalleryPrivate` | `:734` | 0 |
| `saveToGalleryGroups` | `ui.saveGalleryGroups` | `:739` | 0 |
| `saveToGalleryChannels` | `ui.saveGalleryChannels` | `:744` | 0 |
| `accountSelfDestructMonths` | `ui.accountSelfDestructMonths` | `:749` | 0 |
| `linkPreviewsInSecretChats` | `ui.linkPreviewsSecret` | `:754` | 0 |
| `secureScreenshotsInSecretChats` | `ui.secureScreenshotsSecret` | `:759` | 0 |
| `autoTerminateSessionsDays` | `ui.autoTerminateSessionsDays` | `:764` | 0 |
| `videoSeekSeconds` | `ui.videoSeekSeconds` | `:699` | 0 |
| `autoPauseVideoOnBackground` | `ui.autoPauseVideo` | `:704` | 0 |
| `energySavingThreshold` | `ui.energySavingThreshold` | `:709` | 0 |
| `hideBubbleTails` | `ui.hideBubbleTails` | `:689` | 0 |
| `replaceEditedWithIcon` | `ui.replaceEditedWithIcon` | `:694` | 0 |
| `debugRepaintRainbow` | — (не персистится, `:685-687`) | `:685` | 0 |

**16 полей.** При этом все они объявлены в конструкторе и `copyWith` (`ui_settings_provider.dart:84-110`, `208-311`), то есть выглядят как рабочие настройки, и попадают в «сброс».

### 5.2. Поля, которые читаются, но не имеют UI (фактически константы)

| Поле | Кто читает | Почему нельзя изменить |
|---|---|---|
| `messageBubbleRadius` | `lib/widgets/message_bubble.dart:245` | `setMessageBubbleRadius` (`:532`) не вызывается нигде → всегда 16.0 |
| `camera2Api` | `lib/screens/circle_video_recorder_screen.dart:232`, `lib/widgets/quick_camera_capture_screen.dart:101` (читает prefs напрямую) | `setCamera2Api` (`:671`) не вызывается |
| `showPerformanceOverlay` | `lib/main.dart:345` | `setShowPerformanceOverlay` (`:681`) не вызывается; дополнительно **не персистится** |

### 5.3. Формально «сохранено, но эффект частичный»

| Настройка | Проблема | Ссылка |
|---|---|---|
| `notifications` (push-мастер) | `updateNotificationPreference` возвращает `granted`, но вызывающий его игнорирует: при отказе в системном разрешении переключатель остаётся включённым | `notification_settings_section.dart:144-146`, `notification_preference_action.dart:12-32` |
| `ui.notifications` | пишется дважды за одно нажатие (внутри сеттера и вручную) | `notification_preference_action.dart:21-25` |
| `hideOnline` | не самостоятельная настройка, а зеркало серверного правила `last_seen`; в UI отдельного контрола нет | `privacy_provider.dart:141,199,231` |
| «Сбросить локальные настройки» | не сбрасывает `notification_preferences_<id>`, App Lock (secure storage), обои, mesh-флаг | `ui_settings_provider.dart:772-820` против `notification_preferences_provider.dart:38` |

### 5.4. Заглушки, «скоро» и пустые обработчики

| Место | Что | Ссылка |
|---|---|---|
| «Приватность» → блок спам-блока | строка «Серверные ограничения» с подписью **«Пака не сделано»** (опечатка + признак заглушки) и статичным значением «Продакшн» | `settings_privacy_screen.dart:314-319`; тексты — `app_localizations_ru.dart` (`settingsServerLimitsSubtitle`) |
| Карточка «Уведомления отключены» | фабрика `SettingsHealthIssue.notificationsDenied()` создана, но нигде не вызывается → карточка не появляется никогда | `settings_issue.dart:27-35` |
| 4 карточки проблем | ведут на несуществующий маршрут/анкоры (см. §6.4) | `settings_issue.dart:32-66` |
| «О приложении» → «Альфа-тест» | открывает `AlphaTestDialog` — вне «скоро», но это отдельный промо-диалог, не настройка | `settings_about_screen.dart:205-209` |
| «Фон чатов» | меню и подписи захардкожены по-русски, готовые l10n-ключи (`wallpaperApply`, `wallpaperDiscard`, `wallpaperResetTitle`, `wallpaperRandomUndo`, `wallpaperForThisChat`, `wallpaperCustomize`) не используются | `wallpaper_studio_screen.dart:128-241`; ключи — `app_localizations_ru.dart:4968-4990` |
| `SettingId.*` | 14 объявленных анкоров нигде не используются: `privacyDefaultExpiry`, `privacyHideOnline`, `privacyLinkPreviewsSecret`, `privacyScreenshotsSecret`, `privacyAccountSelfDestruct`, `securityAppLockHideInRecents`, `storageAutoDownloadWifi`, `storageAutoDownloadMobile`, `storageClearCache`, `notificationsEnabled`, `notificationsSound`, `notificationsVibration`, `appearanceThemeMode`, `appearanceDynamicColor` | `features/settings/domain/setting_id.dart:15-57` (поиск `SettingId.<имя>` даёт 0 совпадений) |

---

## 6. Расхождения с реестром

### 6.1. `settings_node.dart` — модель

* 10 групп (`settings_node.dart:9-19`), но хаб рисует только 9 разделов; группа `account` не отображается.
* `SettingsActionNode` (`:163-179`) объявлен, но в реестре не используется ни одного экземпляра — все действия реализованы вручную в экранах.
* `SettingsNavNode.badgeValue` (`:90`) объявлен, но нигде не задан; бейджи вычисляются вручную в `profile_screen.dart:260-288`.
* `SettingsGroup.plus.localizedTitle` возвращает жёсткое `'Nios Plus'` (`:40`).

### 6.2. Что есть в реестре, но не совпадает с экранами

| Узел реестра | Заявлено | Фактически |
|---|---|---|
| `notifications` (`:123-144`) | раздел «Уведомления и звуки», маршрут `/settings/preferences` | ок, но подпись хаба/реестра обещает «Push, превью, звук и вибрация» — вибрации на экране нет (только «Тактильный отклик» ОС-уровня) |
| `chats` (`:97-120`) | «Ввод, реакции, микрофон и камера» | на экране ещё «Папки чатов»; автозагрузка медиа, которая упомянута в keywords, живёт в `/settings/storage` |
| `auto_download_wifi` / `auto_download_cellular` (`:409-447`) | `parentNavId: 'storage'` | корректно, но keywords «медиа/трафик» уводят в «Чаты» |
| `blocked_users` (`:509-524`) | заголовок «Чёрный список» (жёсткий RU) | на экране `blockedUsersTitle` = «Заблокированные пользователи» |
| `e2ee_security` (`:525-542`) | «Сквозное шифрование E2EE» (жёсткий RU) | заголовок экрана `e2eeScreenTitle` = «Секретные чаты»; в «Приватности» строка `settingsSecretChatsTitle` |
| `sessions_management` (`:543-561`) | «Активные сессии» (жёсткий RU) | ок по смыслу |
| `cache_cleaning` (`:564-582`) | «Очистить кэш медиа» (жёсткий RU) | на экране `settingsStorageClearTemporary` = «Очистить временный кэш» |
| `notifications.preview` (`:621-630`) | `settingsV2Preview` «Показывать текст» | на экране `noticePreview` «Показывать текст» (совпадает по смыслу, разные ключи) |
| `motion.optimization` (`:611-620`) | «Оптимизация для слабых устройств» | ок |
| `system_device` (`:223-246`) | полноценный раздел, группа `about` | скрыт из хаба; на вебе редирект на `/settings/about` |
| `account` (`:42-65`) | раздел, группа `account` | скрыт из хаба, группа не рендерится |

### 6.3. Что есть в экранах, но отсутствует в реестре (не находится поиском)

* «Аккаунт»: копирование имени/@username/Nios ID, ссылка «Настройки безопасности».
* «Чаты»: «Папки чатов», 4 из 5 уведомленческих тумблеров (`messages`, `calls`, `activity`, `sound`) — в реестре только `preview`.
* «Приватность»: 12 правил (в реестре только `lastSeen`), App Lock-таймаут, Nios ID/2FA, «Секретные чаты», спам-блок.
* «Память»: 9 категорий, «Очистить черновики», веб-ветка целиком.
* «Язык»: таймзонный пикер и предпросмотр времени.
* «О приложении»: FAQ, баг-репорт, шаринг, альфа-тест, ссылки, диагностика, сброс, документы, команда, changelog.
* «Система и устройство»: все 10 пунктов.
* «Фон чатов»: весь экран.
* «Помощь и FAQ», 3 юридических документа.

Итого: 22 дочерних узла реестра против ~157 реальных пунктов — поиск покрывает около 20 % раздела.

### 6.4. Карточки проблем настроек

`lib/features/settings/domain/settings_issue.dart`:

| Карточка | route | anchor | Существует? |
|---|---|---|---|
| `notificationsDenied` | `/settings/notifications` | `notifications-permission` | маршрута нет (есть `/settings/preferences`); анкора нет; **фабрика не вызывается** |
| `reauthenticationRequired` | `/settings/account` | `account-security` | маршрут есть; анкора `account-security` нет ни в одном виджете |
| `storageLow` | `/settings/storage` | `storage-cache-clear` | маршрут есть; реальный анкор — `cache_cleaning` (`settings_storage_screen.dart:290`) |
| `updateIntegrityFailure` | `/settings/about` | `app-update` | маршрут есть; анкора нет (у `AboutUpdateTile` нет `SettingsAnchor`) |

Клик по карточке делает `context.push(issue.route)` и параллельно `settingsAnchorController.request(...)` (`settings_issue_card.dart:93-99`), поэтому подсветка не срабатывает, а `/settings/notifications` уводит на страницу ошибки роутера.

### 6.5. Реестр и веб

`web_settings_location.dart:3-17` знает все 13 маршрутов, кроме `/settings/privacy/rule/:key`, `/settings/privacy/blocked-users`, `/settings/wallpaper`, `/help/faq`, `/legal/*`. То есть на вебе эти пять маршрутов не переносятся в workspace (правила приватности и чёрный список открываются как отдельные страницы поверх шелла).

---

## 7. Итог цифрами

| Метрика | Значение |
|---|---|
| Экранов-маршрутов раздела «Настройки» | **17** (хаб + 16) |
| Вспомогательных маршрутов (FAQ + 3 юр. документа / 4 маршрута) | **4** |
| Экранов без прямого входа из хаба | **7** (из них 1 — вообще без UI-входа) |
| Настроек, открываемых листом/диалогом, а не маршрутом | **15** |
| Всего пунктов в таблицах §3 (без FAQ/legal) | **≈157** |
| Переключателей (sw) | **20** |
| Ползунков (sl) | **2** (`uiCornerRadius`, `soundVolume`) |
| Сегмент-контролов (seg) | **10** |
| Полей `UiSettingsState` | **42** (из них 16 «мёртвых», 3 «читаются, но без UI») |
| Ключей SharedPreferences у UI-настроек | **40** (`ui_settings_provider.dart:321-360`; без ключа живут `showPerformanceOverlay` и `debugRepaintRainbow`) |
| Узлов в реестре | **11** разделов + **22** дочерних = **33** |
| Максимальная глубина | **4**: хаб → Приватность → Правило → лист выбора пользователя (по маршрутам — **3**) |
| Самый длинный экран по пунктам | **Приватность** — 21 пункт (`settings_privacy_screen.dart`) |
| Самый длинный файл экрана | **Оформление** — 881 строка (`settings_appearance_screen.dart`) |
| Самый большой «составной» экран | **E2EE** — 261 + 717 строк (`e2ee_settings_screen.dart` + `ordinary_e2ee_settings.dart`) |

---

## 8. Не проверено

1. **Поведение на реальных платформах** (iOS/macOS/Linux) — только по чтению `clientCapabilities`; запуск запрещён условиями задачи.
2. **Фактические значения серверных правил приватности и лимитов `get_my_limits`** — контракт сервера вне репозитория (`server_core/` исключён из git).
3. **Полный список жестов/точек входа в «Фон чатов» из контекстного меню чата** — прямой поиск `'/settings/wallpaper'`, `'/w'`, `WallpaperStudioScreen` по `lib` дал только deep-links и `AppUrlLauncher`; если вход реализован через динамическую строку URL, он не найден.
4. **Какие именно ключи ARB и старого `app_localizations_ru.dart` дублируются по значению** — проверял выборочно (~90 ключей настроек), полного диффа двух источников не делал.
5. **Тесты как контракт редизайна** — читал только `test/unit/settings_registry_test.dart` (`:12-27` фиксирует «9 разделов, без account/system_device»); 19 остальных файлов `settings_*_test.dart` и e2e не разбирал.
6. **a11y-разметка всех строк** (Semantics) — проверял только там, где она есть в прочитанном коде; систематического аудита нет.
7. **Фактическое влияние `optimizeForWeakDevices` и `animateStickers/animateEmoji`** на рендер чата — поля читаются вне настроек, но конкретные места потребления не трассировал (это вне роли картографа).
