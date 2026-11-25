# 09. Тексты интерфейса и локализация настроек

Дата: 2026-11-22. Роль: редактор интерфейсных текстов и локализации. Только анализ, код и arb не менялись.

## Метод и важная оговорка об источниках

Прочитаны: хаб (`lib/screens/profile_screen.dart`, `lib/screens/settings/settings_hub_screen.dart`), 13 экранов `lib/screens/settings_*.dart` + `e2ee_settings_screen.dart`, каркас (`lib/widgets/settings_ui.dart`, `lib/widgets/settings/*.dart`, `lib/features/settings/**`, `lib/widgets/notifications/notification_settings_section.dart`), реестр (`lib/services/settings/settings_registry.dart`, `lib/models/settings/settings_node.dart`), маршруты (`lib/router/app_router.dart`), обвязка (`lib/core/localization/l10n.dart`, `secret_chat_l10n.dart`, `l10n.yaml`).

**Главная оговорка.** Файлов `lib/l10n/app_ru.arb` и `lib/l10n/app_en.arb`, на которые ссылается `AGENTS.md:16`, в репозитории **нет**. Единственная пара arb — `lib/l10n/secret/app_ru.arb` (772 ключа) и `app_en.arb`; из неё `l10n.yaml:1-5` генерирует только `SecretChatLocalizations`. Основной класс `AppLocalizations` (1716 ключей: 1601 геттер и 115 методов, `lib/l10n/app_localizations.dart`) существует только как закоммиченный сгенерированный код `app_localizations_ru.dart` / `app_localizations_en.dart`. Поэтому:

- все цитаты русских строк ниже даны по `lib/l10n/app_localizations_ru.dart:<строка>`, английских — по `lib/l10n/app_localizations_en.dart:<строка>`, если не сказано иное;
- строки, живущие в secret-каталоге, цитируются по `lib/l10n/secret/generated/secret_chat_localizations_ru.dart:<строка>`;
- «ключ» — имя геттера, по нему строка ищется в любом из двух каталогов.

Инвентарь: во всех файлах настроек используется ≈450 ключей (452 совпадения, из них 2 — не ключи: `dart` из импортов и `localeName` — свойство класса); 0 ключей без пары RU/EN; 0 расхождений в наборах плейсхолдеров; 0 ключей «только в одном каталоге» (проверено разбором обоих каталогов скриптом).

Понятийный аппарат отчёта: **P0** — видит каждый пользователь и выглядит как поломка; **P1** — видит большинство, текст неверен или нелокализован; **P2** — системная несогласованность, мешает ориентироваться; **P3** — полировка.

Сокращения ссылок в главах 1 и 3: `secret/..._ru.dart` = `lib/l10n/secret/generated/secret_chat_localizations_ru.dart`, `en.dart` = `lib/l10n/app_localizations_en.dart`; одиночная ссылка вида `:1147` относится к `app_localizations_ru.dart`, если рядом не указан другой файл.

---

## 1. Десять главных выводов

1. **Источника текстов нет.** 1716 строк основного каталога нельзя изменить штатно: `flutter gen-l10n` по `l10n.yaml:1-5` перегенерирует только secret-каталог. Любая правка настроечного текста сегодня = ручная правка сгенерированного файла `app_localizations_ru.dart`. Это блокирует и редизайн, и перевод (P0).
2. **Часть настроек не локализована вообще.** Карточки проблем на самом верху хаба, таймауты автоблокировки и сообщение о неудачном сохранении — русские литералы в коде: `settings_issue.dart:29-67`, `app_lock_policy.dart:25-53`, `setting_mutation_controller.dart:38`. Англоязычный пользователь на первом экране настроек читает по-русски (P0).
3. **В пользовательском тексте осталась записка разработчика.** Блок спам-блока рисует строку «Серверные ограничения» → «Пака не сделано» → «Продакшн» (`app_localizations_ru.dart:859-862`, `:774`; вызов `settings_privacy_screen.dart:309-321`). В английском каталоге на этом месте осмысленный текст про серверные лимиты (`app_localizations_en.dart:861`) — то есть перевод ушёл вперёд оригинала (P0).
4. **Одно и то же названо по-разному в трёх-четырёх местах.** «Чёрный список» (литерал `settings_registry.dart:512`) / «Черный список» (`:4406`) / «Заблокированные пользователи» (`:4194`); «Очистить кэш» (`settings_issue.dart:56`) / «Очистить кэш медиа» (`settings_registry.dart:567`) / «Очистить временный кэш» (`:1942`) / «Хранилище очищено» (`:1971`). Пользователь не понимает, что это одна и та же кнопка (P1).
5. **Названия разделов не описывают содержимое.** «Данные и память» содержит автозагрузку медиа и кэш, а не память устройства (`settings_storage_screen.dart:338-381`); «Анимации и энергосбережение» содержит режимы фоновой работы и «Оптимизацию для слабых устройств» (`settings_energy_saving_screen.dart:58-185`); «Чаты и звонки» содержит папки, реакции и устройства звонка (`settings_chats_screen.dart:35-100`); «Приватность и безопасность» содержит сессии, биометрию и E2EE (`settings_privacy_screen.dart:266`).
6. **Раздел «Уведомления» называется четырьмя именами:** в интерфейсе «Уведомления и звуки» (`secret/..._ru.dart:1147`), в реестре id `notifications` (`settings_registry.dart:124`), в enum — `preferences` (`settings_navigation_provider.dart:11`), на маршруте — `/settings/preferences` (`app_router.dart:659`). При редизайне это надо назвать один раз.
7. **Заголовки групп хаба не видны, но придуманы.** «Общение», «Оформление», «Аккаунт и защита», «Приложение» уходят только в скринридер (`profile_screen.dart:408-435`). При этом «Оформление» — ещё и название раздела (`secret/..._ru.dart:1134`), то есть два уровня с одинаковым именем. Скринридер слышит структуру, которой нет на экране (P2).
8. **Английский текст живёт по трём разным правилам капитализации:** «Send with Enter Key» (`app_localizations_en.dart:4686`), «Quick Reaction» (`:4690`), «Secret Chats» (`:2370`), «Erase Secret Chats» (`:3195`), «Device Key» (`:3139`) рядом с «Push notifications» (`:831`) и «Interface density» (`secret/..._en.dart:1211`). Для одного экрана это выглядит как разные приложения (P2).
9. **Подписи-объяснения inconsistent: 54 из 83 длинных подсказок без точки, 29 с точкой.** Плюс 12 подсказок длиннее 120 знаков, максимум 295 (`settingsE2eeDeviceDescription`, `secret/..._ru.dart:2052`) — это 6-7 строк мелким текстом в карточке. При этом у четырёх из пяти категорий уведомлений подписи нет вовсе (`notification_settings_section.dart:149-167`), а причина недоступности строк не показывается никогда (`settings_row.dart:175`) (P2).
10. **Каталог забит мёртвыми поколениями текста.** В основном каталоге **320 неиспользуемых ключей** строго настроечных семейств (`settings*` 192, `appearance*` 82, `e2ee*` 27, `sessions*` 12, `privacy*` 7) и ещё ~95 в смежных (`profile*` 44, `about*` 36, `common*` 10, `language*` 4) — проверено текстовым поиском по `lib`; выборочная проверка подтвердила: `appearanceDarkTheme`, `appearanceFloatingNav`, `settingsCenterTitle`, `e2eeMitmWarning` не встречаются в коде. Среди мёртвых — целый старый E2EE-экран (`e2eeRotateKey`, `e2eeMitmWarning`, `e2eeCompareWordsHint`…) и старая палитра/плотность. Это прямой риск: при редизайне легко «взять готовую строку» из мёртвого поколения (P2).

---

## 2. Литералы в коде: полный список

Искал кириллицу `[А-Яа-яЁё]` и английские литералы в перечисленных файлах (`Text('…')`, `title:`, `subtitle:`, `label:`, `tooltip:`, `Semantics(label:)`, `keywords:`). Русских комментариев в коде настроек мало и они безвредны (`settings_privacy_screen.dart:62,154,229,268,308`, `settings_storage_screen.dart:309,337`).

### 2.1. Видно пользователю — править обязательно

| № | Место | Текст | Примечание |
|---|---|---|---|
| Л1 | `lib/services/settings/settings_registry.dart:276` | `'Nios+ · NiosAI'` | заголовок раздела в хабе; два продукта в одном названии |
| Л2 | `lib/services/settings/settings_registry.dart:512` | `'Чёрный список'` | в экране тот же пункт — «Черный список» (`:4406`) |
| Л3 | `settings_registry.dart:513` | `'Заблокированные пользователи'` | подпись поиска; это заголовок целевого экрана (`:4194`) |
| Л4 | `settings_registry.dart:528` | `'Сквозное шифрование E2EE'` | в экране — «Секретные чаты» + «Сквозное шифрование (E2EE)» (`:2395-2398`) |
| Л5 | `settings_registry.dart:529` | `'Ключи безопасности и секретные чаты'` | третье название того же |
| Л6 | `settings_registry.dart:546` | `'Активные сессии'` | совпадает с ключом `settingsActiveSessions` (`:902`) — дубль |
| Л7 | `settings_registry.dart:548` | `'Устройства и браузеры с доступом к аккаунту'` | в экране другая подпись: `settingsActiveSessionsSubtitle` |
| Л8 | `settings_registry.dart:567` | `'Очистить кэш медиа'` | третье название действия очистки |
| Л9 | `settings_registry.dart:569` | `'Очистка загруженных фото, аудио и превью'` | «превью» — англицизм |
| Л10 | `lib/models/settings/settings_node.dart:40` | `'Nios Plus'` | третье написание бренда (ещё «Nios+», «Nios+ · NiosAI») |
| Л11 | `lib/features/settings/domain/settings_issue.dart:29` | `'Уведомления отключены'` | карточка на хабе |
| Л12 | `settings_issue.dart:30` | `'Вы можете пропустить важные звонки и личные сообщения'` | |
| Л13 | `settings_issue.dart:34` | `'Включить'` | кнопка |
| Л14 | `settings_issue.dart:39` | `'Требуется подтверждение входа'` | |
| Л15 | `settings_issue.dart:40` | `'Срок действия сессии подходит к концу. Подтвердите вход для защиты чатов'` | |
| Л16 | `settings_issue.dart:44` | `'Подтвердить'` | |
| Л17 | `settings_issue.dart:51` | `'Мало свободного места'` | подставляется размер *кэша*, а не свободного места |
| Л18 | `settings_issue.dart:52` | `'На устройстве осталось $mb МБ. Очистите временные файлы и кэш'` | |
| Л19 | `settings_issue.dart:56` | `'Очистить кэш'` | |
| Л20 | `settings_issue.dart:62` | `'Ошибка проверки обновления'` | |
| Л21 | `settings_issue.dart:63` | `'Контрольная сумма пакета обновления не совпала с серверной'` | «контрольная сумма» — жаргон |
| Л22 | `settings_issue.dart:67` | `'Повторить'` | |
| Л23 | `lib/features/settings/presentation/settings_issue_card.dart:85` | `'Скрыть'` | tooltip крестика |
| Л24 | `lib/features/settings/application/setting_mutation_controller.dart:38` | `'Не удалось сохранить изменение'` | код мёртвый (нет потребителей), но строка есть |
| Л25 | `lib/features/security/domain/app_lock_policy.dart:28,30,32,34,36` | `'Сразу'`, `'Через 30 секунд'`, `'Через 1 минуту'`, `'Через 5 минут'`, `'Через 30 минут'` | таймаут автоблокировки — единственный переключатель с полным русским набором в домене |
| Л26 | `app_lock_policy.dart:43,45,47,49,51` | `'Immediately'`, `'After 30 seconds'`… | английский набор там же; выбор по `localeName.startsWith('ru')` (`account_security_section.dart:51,160`) |
| Л27 | `lib/screens/settings_account_screen.dart:57` | `'Nios ID'` | поле без ключа |
| Л28 | `lib/screens/profile_screen.dart:743` | `'Nios ID'` | то же поле в шите профиля |
| Л29 | `lib/screens/settings_plus_screen.dart:180`, `:196` | `'Nios+'` | заголовок экрана и название подписки |
| Л30 | `lib/screens/settings_plus_screen.dart:237` | `'NiosAI Prime · SPrime'` | технические имена моделей в списке преимуществ |
| Л31 | `lib/screens/settings_about_screen.dart:217` | `'Telegram'` | название мессенджера (ок, но value `@niosmess` тоже литерал) |
| Л32 | `lib/screens/settings_about_screen.dart:223` | `'ni-os.ru'` | адрес как название пункта |
| Л33 | `lib/screens/settings_about_screen.dart:306` | `'v${release.version}'` | префикс «v» без l10n (P3) |
| Л34 | `lib/screens/settings_about_screen.dart:257` | `'${l.aboutCopyrightFooter(2026)} · ${BuildInfo.buildChannel}'` | год зашит; `buildChannel` показывается как есть («release»/«debug») |
| Л35 | `lib/screens/settings_appearance_screen.dart:773`, `:784` | `'${…} dp'` | «dp» — техническая единица без объяснения (см. Л36) |

### 2.2. Полувидимые строки (семантика, буфер обмена, склейки)

| № | Место | Что |
|---|---|---|
| Л36 | `settings_registry.dart:334` | `unit: 'dp'` — единица в узле поиска; в UI даёт «20 dp» |
| Л37 | `profile_screen.dart:275` | `'—'` — заглушка значения раздела «Данные и память» |
| Л38 | `settings_system_device_screen.dart:98,148,158` | `' · '` — склейка трёх подписей в одну строку без локализации разделителя |
| Л39 | `settings_system_device_screen.dart:227` | `'$title: $value'` — формат копирования в буфер («Название: значение»); в EN останется русское название |
| Л40 | `settings_language_region_screen.dart:134` | `'${option.label} (${option.currentOffsetLabel()})'` — скобки/порядок не локализуются |
| Л41 | `settings_language_region_screen.dart:142-143` | `'UTC+hh:mm'` — формат собирается вручную |
| Л42 | `settings_language_region_screen.dart:283` | `'${option.id} · ${offset}'` — пользователю показывается технический id `Europe/Moscow` |
| Л43 | `settings_storage_screen.dart:249-251` | склейка Semantics через `', '` — порядок и запятая не локализуются |
| Л44 | `settings_storage_screen.dart:115` | `'${count}'` — число без подписи «черновиков» |
| Л45 | `settings_registry.dart:797` | `'$parentTitle › $title'` — разделитель хлебных крошек; в результате заголовок пункта дублируется (заголовок + «Раздел › Пункт») |
| Л46 | `settings_registry.dart` — все блоки `keywords:` (строки 50-696) | **138 русских строк, из них ≈130 поисковых слов** вне l10n |
| Л47 | `lib/screens/e2ee_settings_screen.dart:102`, `:145` | `'Secret account unavailable'` — `StateError`, в UI не попадает (проверено: перехватывается `catch`) |
| Л48 | `lib/features/settings/presentation/settings_responsive_shell.dart:26` | assert-сообщение на английском (только debug) |

Про Л46 отдельно: это не нарушение «нет литералов в UI» (слова не видны), но это **вторая, нелокализуемая база текста** — 138 русских строк в реестре. У неё есть практический дефект: слова записаны только в одной форме. Поиск сравнивает `lowerKw.contains(query)` (`settings_registry.dart:841-845`), поэтому запрос «сессия» не находит пункт с ключевым словом «сессии» (`:161`), «уведомление» — «уведомления» (`:132`), «чат» находит «чаты», но «переписка» не находит ничего.

---

## 3. Названия: хаб, группы, экраны, пункты

### 3.1. Разделы хаба (9 видимых; «Аккаунт» и «Система и устройство» исключены фильтром `settings_registry.dart:700-709`)

| Ключ | RU | EN | Оценка |
|---|---|---|---|
| `settingsV2Appearance` | Оформление | Appearance | ✅ понятно, коротко. ⚠ совпадает с названием группы «Оформление» (`settingsGroupPersonalization`) |
| `settingsV2Chats` | Чаты и звонки | Chats and calls | ⚠ внутри ещё папки, быстрые реакции и устройства звонка; «и звонки» обещает отдельный раздел звонков |
| `settingsV2Notifications` | Уведомления и звуки | Notifications and sounds | ✅ но раздел в коде и на маршруте называется `preferences` |
| `settingsV2Privacy` | Приватность и безопасность | Privacy and security | ⚠ «безопасность» дублирует группу «Аккаунт и защита»; фактически внутри сессии, биометрия, E2EE |
| `settingsV2Storage` | Данные и память | Data and storage | ✖ RU говорит «память» (RAM), EN — «storage»; смыслы расходятся. Внутри — кэш и автозагрузка |
| `settingsV2Language` | Язык и время | Language and time | ✅ но маршрут `language-region`, а «региона» в названии нет |
| `settingsV2Motion` | Анимации и энергосбережение | Motion and battery | ✖ EN теряет «энергосбережение». На вебе раздел называется иначе: «Анимации и производительность» (`webMotionTitle`) |
| литерал Л1 | Nios+ · NiosAI | (то же) | ✖ два продукта в одном пункте; на самом экране только «Nios+» (`settings_plus_screen.dart:180`) |
| `settingsV2About` | Помощь и о приложении | Help and about | ✖ RU несогласовано («помощь» + «о приложении» + союз «и о»); EN неграмотно. Внутри — документы, команда, диагностика, сброс |

### 3.2. Названия экранов и их совпадение с хабом

| Экран | Заголовок RU / EN | Ключ | Замечание |
|---|---|---|---|
| Аккаунт | Аккаунт / Account | `settingsAccountTitle` (`:630`) | в хабе пункта нет, но на широком экране раздел открыт по умолчанию |
| Приватность | Приватность и безопасность / Privacy and security | `settingsV2Privacy` | внутри 4 секции, включая «Защита» (`settingsProtectionTitle`) |
| Оформление | Оформление / Appearance | `settingsV2Appearance` | |
| Чаты | Чаты и звонки / Chats and calls | `settingsV2Chats` | |
| Уведомления | Уведомления и звуки / Notifications and sounds | `settingsV2Notifications` | заголовок секции внутри — «Уведомления» (`noticeTitle`, `:974`), т. е. имя повторяется |
| Язык | Язык и время / Language and time | `settingsV2Language` | |
| Данные | Данные и память / Data and storage | `settingsV2Storage` | на вебе — «Данные в браузере» (`webStorageTitle`) |
| Анимации | Анимации и энергосбережение / Motion and battery | `settingsV2Motion` | на вебе — «Анимации и производительность» (`webMotionTitle`) |
| Nios+ | Nios+ / Nios+ | литерал Л29 | |
| О приложении | Помощь и о приложении / Help and about | `settingsV2About` | |
| Система | Система и устройство / System and device | `settingsDeviceTitle` (`secret/..._ru.dart:1957`) | вход — из «О приложении» пунктом «Диагностика устройства» (`settingsV2Diagnostics`) |
| Секретные чаты | Секретные чаты / Secret Chats | `e2eeScreenTitle` (`:3154`) | вход из «Приватности» пунктом «Секретные чаты» (`:2395`) |
| Сессии | Активные сессии / Active sessions | `sessionsTitle` (`:2153`) | вход из «Приватности», блок «Доступ к аккаунту» |
| Обои | Фон чатов / Chat Wallpaper | `wallpaperScreenTitle` | из интерфейса настроек недостижим: маршрут открывают только deep-link (`app_url_launcher.dart:277-288`) |

### 3.3. Группы (только для скринридера)

| Ключ | RU | EN | Оценка |
|---|---|---|---|
| `settingsGroupCommunication` | Общение | Communication | ⚠ в группе «Чаты» и «Уведомления» |
| `settingsGroupPersonalization` | Оформление | Personalization | ✖ одно имя с разделом «Оформление»; EN «Personalization» |
| `settingsGroupSecurity` | Аккаунт и защита | Account and security | ⚠ «защита» vs «безопасность» в разделе |
| `settingsGroupApplication` | Приложение | Application | ⚠ «Приложение» — про что? (данные, Nios+, о приложении) |

Плюс мёртвый третий набор: `settingsV2GroupCommunication` = «Общение и оформление», `settingsV2GroupPrivacy` = «Приватность и данные», `settingsV2GroupApplication` = «Приложение» (не используются, `secret/app_ru.arb`). И четвёртый — `SettingsGroup.localizedTitle` (`settings_node.dart:21-44`) на ключах `settingsV2*`, где `plus` = литерал «Nios Plus». **Четыре системы названий одной и той же группировки.**

### 3.4. Ключевые пункты и подписи (выборка проблемных)

Ссылки в скобках: файл не указан — значит `lib/l10n/app_localizations_ru.dart` (EN — тот же ключ в `app_localizations_en.dart`); «реестр» — `lib/services/settings/settings_registry.dart`.

| Ключ | RU | EN | Оценка |
|---|---|---|---|
| `settingsChatsSendOnEnter` | Отправка по клавише Enter | Send with Enter Key | ⚠ EN Title Case; RU «по клавише» — канцелярит |
| `settingsChatsQuickReaction` | Быстрая реакция | Quick Reaction | ⚠ EN Title Case |
| `settingsV2Wifi` / `settingsChatsAutoDownloadWifi` | Через Wi-Fi / Через сеть Wi-Fi | On Wi-Fi / When connected to Wi-Fi | ✖ один переключатель, два названия (`settings_storage_screen.dart:347` vs реестр `:413`) |
| `settingsV2MobileData` / `settingsChatsAutoDownloadCellular` | Через мобильную сеть / Через мобильную сеть | On mobile data / When using Cellular data | ⚠ EN: «mobile data» vs «Cellular data» |
| `settingsV2Preview` / `noticePreview` | Показывать текст / Показывать текст | Show message text / Show message preview | ✖ в EN два разных названия одной настройки; в поиске даёт два одинаковых результата |
| `privacyBlacklist` / `blockedUsersTitle` | Черный список / Заблокированные пользователи | Blocked list / Blocked Users | ✖ три названия + «Blocked list» vs «Blocked Users»; «Черный» без ё |
| `privacyRuleLastSeen` | Время захода и статус в сети | Last seen & online status | ⚠ в реестре то же понятие — «последняя активность», в сессиях — «Последняя активность» (`:2165`) |
| `settingsV2Off` / `settingsV2Economy` / `settingsV2Reliable` | Отключено / Экономный / Надёжный | Off / Economy / Reliable | ✖ RU: причастие среди прилагательных |
| `settingsBackgroundReliableDesc` | С милым уведомлением для поддержания связи | With a cute notification to keep app alive | ✖ шутка в технической подписи; непонятно, что произойдёт |
| `settingsBackgroundEconomyDesc` | Без уведомлений, но система может редко закрывать приложение | No notification, but system may close app rarely | ✖ «экономный» описан как «без уведомлений» — противоречит смыслу |
| `settingsV2BackgroundOff` | Фоновое соединение отключено. Push продолжает работать через FCM. | The background connection is off. Push notifications still use FCM. | ✖ «FCM» — внутренняя технология |
| `appearanceOptimizeWeakDevices` | Оптимизация для слабых устройств | Optimize for weak devices | ✖ «слабые устройства» — оценка, которую пользователь не может проверить |
| `settingsDeviceRam` / `settingsDeviceMemory` | Оперативная память / Память и накопитель | Memory / Memory and storage | ✖ EN: «Memory» и «Memory and storage» — тавтология |
| `settingsDeviceUnknown` | Недоступно | Unavailable | ✖ подставляется там, где значение *неизвестно* («Неизвестно» ≠ «Недоступно») |
| `settingsDeviceFrontCamera` | фронтальная | front | ⚠ строчная в склейке «12 МП фронтальная» (`settings_system_device_screen.dart:168`) |
| `settingsDeviceCameras` | Оптика и камеры | Cameras | ⚠ «оптика» — жаргон |
| `profileDangerZone` | Тут лучше аккуратно трогать | Danger zone | ✖ RU — реплика в блоге, EN — стандарт; заголовок опасного блока |
| `privacyBatteryOptimization` | Работа без ограничений батареи | Unrestricted battery mode | ✖ подпись кнопки не говорит, что откроются настройки Android |
| `settingsE2eeMeshTitle` | Если нет интернета использовать блютуз | Use Bluetooth when offline | ✖ безграмотно («если… то»), «блютуз» вместо «Bluetooth» |
| `settingsE2eeOrdinaryTitle` | Личные чаты · тестирование E2E | Personal chats · E2E preview | ⚠ «тестирование» в рабочем UI |
| `noticeActivity` | Активность NiosGram | NiosGram activity | ⚠ бренд-жаргон в переключателе уведомлений |
| `settingsProduction` | Продакшн | Production | ✖ см. вывод 3 |
| `aboutOtaSubtitle` / `aboutSystemUpdateTitle` | OTA-обновления NiosMess / Обновление системы | NiosMess OTA Updates / System Update | ✖ два названия одного пункта, «OTA» не объяснено |
| `aboutTabLegal` | Документы | Legal | ⚠ RU — объект, EN — категория |
| `aboutCurrentVersionBadge` | Текущая | Current | ⚠ прилагательное без существительного рядом с «v3.141.0» |
| `settingsPlusAiBudget` | 300 Ниосиков за 3 дня | 300 Niosiki every 3 days | ⚠ «Ниосики» без объяснения, что это |
| `settingsPlusBenefits` | В подписке | Included | ⚠ заголовок секции непонятен без контекста («Что входит») |
| `settingsV2Density` | Плотность интерфейса | Interface density | ⚠ внутри ещё «Размер шрифта» и «Скругление» — «плотность» их не покрывает |
| `appearancePaletteStyle` + варианты | Характер палитры: Выразительный / Насыщенный / **Контент** / Спокойный / Моно | Palette Style: Expressive / Vibrant / **Content** / Calm / Mono | ✖ существительное «Контент» в ряду прилагательных; EN Title Case; «Моно» — обрубок |
| `languageRegionCurrentTime` | Текущее время в приложении | Current time in app | ⚠ показывается время устройства, а не «в приложении» |
| `settingsStorageCategoryAppData` | Данные | App Data | ✖ рядом легенда «Данные приложения» (`:1892`) — два имени; EN Title Case |

---

## 4. Находки

| P | Место | Что не так | Предложение |
|---|---|---|---|
| **P0** | `l10n.yaml:1-5`, отсутствующие `lib/l10n/app_ru.arb`/`app_en.arb` | Нет исходников 1716 строк основного каталога; `flutter gen-l10n` их не восстановит (генерируется только secret-каталог) | Вернуть arb-пару, `l10n.yaml` на два каталога, генерацию в CI; до этого — запрет правок сгенерированных файлов «на глаз» |
| **P0** | `app_localizations_ru.dart:862`, `:774`, `settings_privacy_screen.dart:309-321` | «Пака не сделано» + «Продакшн» в UI; EN-версия при этом осмысленная (`app_localizations_en.dart:861`) | Заменить на текст EN: «Индикатор набора и отчёты о прочтении сейчас задаются на сервере и станут настраиваемыми позже»; значение «Продакшн» убрать |
| **P0** | `settings_issue.dart:29-67`, `settings_issue_card.dart:85`, `settings_health_controller.dart:7-27` | Карточки в шапке хаба — русские литералы; при EN-интерфейсе это первый русский текст, который видит пользователь | Перевести на ключи (`settingsIssue*`) в оба каталога |
| **P0** | `app_lock_policy.dart:25-53`, `account_security_section.dart:51,160` | Таймаут автоблокировки хранится как пара RU/EN в домене, выбор — по `localeName.startsWith('ru')` | Ключи `autoLockImmediately/After30s/…` в каталог; выбор через `l10n` |
| **P1** | `app_localizations_ru.dart:314` (`profileUsername`) | В русском интерфейсе поле профиля подписано «Username» | «Имя пользователя» (или «Логин»), EN оставить «Username» |
| **P1** | `secret/..._ru.dart:2076` (`settingsE2eeMeshTitle`) | «Если нет интернета использовать блютуз» — безграмотно и разговорно | «Передача через Bluetooth без интернета» |
| **P1** | `app_localizations_ru.dart:362` (`profileDangerZone`) | «Тут лучше аккуратно трогать» вместо предупреждения | «Опасная зона» / «Необратимые действия» |
| **P1** | `app_localizations_ru.dart:3537` (`settingsBackgroundReliableDesc`) | «С милым уведомлением для поддержания связи» — шутка, нет описания последствий | «Показывает постоянное уведомление, чтобы система не закрывала приложение» |
| **P1** | `app_localizations_ru.dart:3272-3273` (`e2eeEraseDone`) | «Удалено $chats чатов и $files файлов» — нет русской плюрализации: «Удалено 1 чатов» | ICU plural: `{chats, plural, one{# чат} few{# чата} many{# чатов}}`; в проекте плюрализация уже применяется (`secret/app_ru.arb:66,75,133,950`) |
| **P1** | `settings_issue.dart:47-57`, `settings_health_controller.dart:16-19` | Текст «На устройстве осталось N МБ» подставляет размер кэша (`storage.temporaryBytes`), а не свободное место | «Кэш занимает N МБ. Очистите его, чтобы освободить место» |
| **P1** | `settings_issue.dart:32,42,54,65` + `app_router.dart:529-669` | CTA карточек ведут на `/settings/notifications` (маршрута нет) и в якоря `account-security`, `storage-cache-clear`, `app-update`, `notifications-permission` (ни одного нет в UI) | Починить маршрут и якоря либо переписать кнопки на честные («Открыть приватность») |
| **P1** | `settings_registry.dart:512-529,546-569`, `app_localizations_ru.dart:4406,4194,1942` | Один пункт/действие назван 3-4 способами (кэш, чёрный список, E2EE, сессии) | Свести к одному ключу на понятие (см. §8) |
| **P1** | `profile_screen.dart:213-228` (`_logout`) | Подтверждение выхода: заголовок «Выйти из аккаунта?», а тело — только про секретные чаты (`secretLogoutWarning`) | Тело: «Вы выйдете на этом устройстве. Обычные чаты останутся на сервере; секретная история будет удалена» |
| **P1** | `settings_storage_screen.dart:80-90` | Кнопка подтверждения очистки кэша подписана `commonDelete` = «Удалить», хотя удаляются временные файлы, а не данные | «Очистить» / «Очистить кэш» |
| **P2** | `profile_screen.dart:408-435` | Заголовки групп только в `Semantics`, на экране их нет; «Оформление» — и группа, и раздел | Либо показать заголовки, либо убрать группировку и её тексты |
| **P2** | `settingsV2Notifications` vs `settings_registry.dart:124-130` vs `settings_navigation_provider.dart:11` vs `app_router.dart:659` | Раздел называется «Уведомления и звуки», в коде `preferences`, на маршруте `preferences` | Переименовать enum и маршрут в `notifications` при редизайне |
| **P2** | `settings_storage_screen.dart:338-381` | «Данные и память» содержит автозагрузку медиа; «память» в RU не равна «storage» в EN | Раздел «Хранилище»; автозагрузку вынести в «Чаты» или отдельный блок «Медиа» |
| **P2** | `settings_energy_saving_screen.dart:58-74`, `app_localizations_ru.dart:2333` | «Оптимизация для слабых устройств» — оценочная формулировка | «Экономить ресурсы на старых устройствах» + объяснение, что отключается |
| **P2** | `settings_privacy_screen.dart:272-284` (`privacyNoBlocked`) и `blocked_users_screen.dart:167` | Экран «Заблокированные пользователи» при ошибке показывает «Не удалось обновить настройки приватности» | Отдельный ключ «Не удалось загрузить список» |
| **P2** | `settings_row.dart:143,154,175` | `disabledReason` есть в API, но **ни один экран его не передаёт**; недоступные строки (приватность при загрузке, кэш = 0, категории уведомлений при выключенном главном) не объясняют причину | Подключить `disabledReason`: «Сначала включите уведомления», «Кэш пуст», «Загружаем настройки…» |
| **P2** | `notification_settings_section.dart:64-79` | Подписи отсутствуют у 4 из 5 категорий; «Сообщения», «Входящие звонки», «Активность NiosGram» без объяснений, что именно придёт | Добавить подписи или переименовать: «Личные сообщения», «Звонки», «Упоминания и реакции» |
| **P2** | `settings_preferences_screen.dart:82`, `noticeUiSoundsHint` (`:1127`) | Секция «Звук и тактильный отклик» смешивает звуки интерфейса и громкость уведомлений; подпись «Звуки нажатий и действий. Уведомления настраиваются отдельно» противоречит соседнему ползунку «Громкость» | Развести: «Звуки интерфейса» и «Звук уведомлений» |
| **P2** | `app_localizations_ru.dart:852-855` | «Ваш аккаунт на спам-блоке» + «ЛС» (аббревиатура) | «Аккаунт ограничен из-за спама» + «личные сообщения» без ЛС |
| **P2** | `secret/..._ru.dart:2162,2191,2197` + `lib/features/sessions/presentation/sessions_screen.dart:121-150` | Сессии: заголовок «Активные сессии», внутри «Другие устройства», «Завершить эту сессию», «Нет других активных сессий» — сессия/устройство вперемешку; EN ещё и «End»/«Terminate» | Выбрать «сеанс» для сущности и «устройство» только как описание; глагол один |
| **P2** | `app_localizations_en.dart:4686,4690,2370,3195,3139` и др. | EN Title Case вперемешку с sentence case (см. вывод 8) | Правило: EN — sentence case везде, кроме имён продуктов |
| **P2** | `secret/..._ru.dart:2052` (`settingsE2eeDeviceDescription`), `webStorageDescription`, `settingsE2eeResetDescription`, `settingsE2eePairNewDescription`, `settingsV2ResetBody` (147 знаков), `settingsStorageSafeCleanup` (136) | Тексты 135-295 знаков в подписях строк/секций — 4-7 строк мелким шрифтом | Разбить на 2-3 предложения-пункта, главное — в первую строку |
| **P2** | `about_report_dialog` (`about_bug_report_dialog.dart:116-135`) | Форма баг-репорта: «Опишите ошибку или проблему» без подсказки, что писать; не сказано, куда уйдёт отчёт и когда ответят | Добавить helper-текст: «Что делали, что ожидали, что произошло. Версия и устройство приложатся автоматически» |
| **P2** | `app_localizations_ru.dart:2797` (`settingsStorageLegendCache` = «Кеш») | В каталоге «кеш» (4) и «кэш» (7) одновременно | Оставить «кэш» |
| **P2** | `app_localizations_ru.dart:4204` (`noBlockedUsersDesc`) | «Вы еще никого не заблокировали» — без ё; рядом «Чёрный»/«Черный» | «Вы ещё никого не заблокировали»; единое «Чёрный список» |
| **P3** | `app_localizations_ru.dart:671` (`settingsAccountSubtitle`) | Единственный подзаголовок хаба с точкой; остальные (`settingsV2AppearanceHint` и др.) без | Убрать точку |
| **P3** | `settings_preferences_screen.dart:112-113` | «Громкость · 70 %» — середина строки, точка-разделитель не локализуется | «Громкость: 70 %» |
| **P3** | `settings_appearance_screen.dart:773,784` | «20 dp» — непонятная единица | «20» без единицы или «20 пт» |
| **P3** | `settings_language_region_screen.dart:283` | В списке часовых поясов видно `Europe/Moscow · UTC+03:00` | Оставить только смещение и город |
| **P3** | `settings_about_screen.dart:306` | «v3.141.0» рядом с бейджем «Текущая» — два разных стиля версии (`BuildInfo.versionWithPrefix` тоже с «v») | Один формат версии |
| **P3** | `settings_about_screen.dart:257` | Год 2026 в копирайте зашит в вызов | Брать текущий год |
| **P3** | `settings_plus_screen.dart:237` | «NiosAI Prime · SPrime» — внутренние имена моделей без объяснения | «Доступ к продвинутым моделям NiosAI» + расшифровка в подписи |
| **P3** | `settings_registry.dart:841-845` | Поиск не находит единственное число («сессия», «уведомление») | Хранить основы слов или добавить формы |
| **P3** | `settings_registry.dart:797` | В результатах поиска заголовок пункта дублируется: заголовок + «Раздел › Пункт» | Подзаголовок = только раздел |

---

## 5. Подписи-объяснения

### 5.1. Переключатели: где объяснение есть, где его нет

| Переключатель | Где | Вердикт |
|---|---|---|
| `settingsV2Stickers` («Анимация стикеров») | `settings_energy_saving_screen.dart:34-43` | ✅ подпись «Воспроизводить стикеры в сообщениях» |
| 4 из 5 категорий уведомлений | `notification_settings_section.dart:149-167` | ✖ `noticeMessages`/`noticeCalls`/`noticeActivity` без подписи; непонятно, что попадёт под «Активность NiosGram» |
| `appearanceSystemColors` («Системные цвета») | `settings_appearance_screen.dart:286-296` | ⚠ подпись есть («Цвета из обоев устройства»), но не сказано, что выбор палитры ниже выключит системные цвета |
| `settingsBackgroundMode` (3 сегмента) | `settings_energy_saving_screen.dart:86-120` | ✖ подписи есть, но «Экономный» описан как «Без уведомлений», а «Надёжный» — шуткой |
| `settingsHapticFeedback` | `settings_preferences_screen.dart:147-154` | ✅ подпись «Вибрировать при взаимодействиях» |
| Кнопка «Работа без ограничений батареи» | `settings_energy_saving_screen.dart:163-165` | ✖ не сказано, что откроется системный экран Android |
| `appearanceOptimizeWeakDevices` | `settings_energy_saving_screen.dart:61-72` | ⚠ подпись говорит *что* делает, но не *как понять, что мне это нужно* |
| Очистка кэша/черновиков | `settings_storage_screen.dart:289-305` | ⚠ размер показан как подпись, но не сказано, что удаление необратимо (частично сказано в подтверждении) |
| Автозагрузка по мобильной сети | `settings_storage_screen.dart:360-379` | ✅ «Может расходовать мобильный трафик» |
| Переключатели приватности (5 правил) | `settings_privacy_screen.dart:63-152` | ✅ текущее значение видно справа; но при `pending` строки гаснут без причины (см. `settings_row.dart:175`) |

### 5.2. Подписи, повторяющие название

- «Очистить временный кэш» → подпись = размер (`settings_storage_screen.dart:292-293`); «Очистить черновики» → размер (`:300-301`).
- «Показывать текст» / «Показывать текст» (два разных ключа, одна строка).
- «Настройки безопасности» → «Сессии, блокировка приложения и защита аккаунта» (`settingsV2SecurityLink`+`Hint`) — по сути перечисление содержимого, а не объяснение пользы.
- `settingsV2Density` «Плотность интерфейса» + `appearanceCompactModeSubtitle` «Более плотные отступы…» — «плотность» повторяется трижды в одном блоке.
- `biometricEnabled`/`biometricDisabled`: подпись повторяет состояние переключателя («Включена — …» / «Отключена») — это работа самого свитча; полезнее объяснить, что биометрия защищает приложение, а не вход.

### 5.3. Слишком длинные (не влезают в 2 строки)

Лимиты вёрстки: подпись рисуется `bodySmall`, значение — до 18 знаков в одну строку иначе уходит вниз, ширина значения ≤88 (`settings_list_item.dart:169-174,213`). Подписи длиннее ~120 знаков (12 штук) гарантированно занимают 3+ строки:

| Ключ | Знаков |
|---|---|
| `settingsE2eeDeviceDescription` | 295 |
| `webStorageDescription` | 221 |
| `settingsPlusGracePeriodHint` | 171 |
| `settingsE2eeResetDescription` | 164 |
| `settingsE2eePairNewDescription` | 162 |
| `settingsV2ResetBody` | 147 |
| `settingsE2eeContactDescription` | 147 |
| `settingsStorageSafeCleanup` | 136 |
| `settingsE2eeActionFailed` | 135 |
| `settingsPlusAiBudgetHint` | 131 |
| `settingsE2eeRecoveryDescription` | 125 |
| `secretLogoutWarning` | 121 |

Ограничение на значения-бейджи хаба: `_getSectionBadgeValue` (`profile_screen.dart:260-288`) отдаёт «Системная»/«Тёмная»/«Светлая», «Русский»/«English» и «v3.141.0» — сегодня все укладываются в 18 знаков, но правило `settings_list_item.dart:169-174` переносит значение вниз, как только появится более длинная подпись. Это нужно держать в голове при переименовании разделов.

---

## 6. Опасные действия, подтверждения, ошибки, пустые состояния

### 6.1. Опасные действия

| Действие | Заголовок / тело / кнопка | Оценка |
|---|---|---|
| Выход из аккаунта (`profile_screen.dart:213-228`) | «Выйти из аккаунта?» / «При выходе секретная история и неотправленные сообщения на этом устройстве будут удалены. История собеседника сохранится.» / «Выйти» | ✖ не сказано, что будет с обычными чатами и что сеанс на других устройствах останется; тело только про секретные чаты |
| Очистка кэша (`settings_storage_screen.dart:35-47,80-90`) | «Очистить временный кэш?» / «Кэш будет создан заново при необходимости. Аккаунт и настройки не будут затронуты.» / **«Удалить»** | ⚠ тело хорошее, кнопка не та («Удалить» вместо «Очистить») |
| Очистка черновиков (`:49-58`) | «Очистить черновики?» / «Неотправленный текст черновиков на этом устройстве будет удалён.» / «Удалить» | ✅ кроме универсальной кнопки |
| Сброс настроек (`settings_about_screen.dart:85-105`) | «Сбросить локальные настройки?» / «Сбросятся оформление, язык, звуки, уведомления и другие настройки этого приложения. Чаты, файлы, ключи и серверные настройки приватности останутся.» / «Сбросить локальные настройки» | ✅ лучшее подтверждение в разделе; минус — кнопка дублирует заголовок и длинная |
| Удаление секретных чатов (`e2ee_settings_screen.dart:122-134`) | «Удалить все секретные чаты?» / «Вся история секретных чатов и связанные файлы будут безвозвратно удалены с сервера. Это действие нельзя отменить.» / «Удалить» | ✅ (EN: «Erase»/«Erase Secret Chats» — другой глагол) |
| Завершение остальных сеансов (`lib/features/sessions/presentation/sessions_screen.dart:19-44`) | «Завершить все остальные сессии?» / «Все устройства, кроме этого, будут отключены от вашего аккаунта.» / «Завершить все» | ✅ |
| Завершение одного сеанса (`lib/features/sessions/presentation/session_details_sheet.dart:44-49`) | «Завершить сессию?» / «Устройство «X» будет отключено от вашего аккаунта.» / «Завершить» | ✅ |
| Блокировка пользователя (`blocked_users_screen.dart:35-74`, `:76-90`) | — | ✖ подтверждения нет вовсе: выбор пользователя сразу блокирует, разблокировка мгновенная (см. отчёт 10) |

### 6.2. Ошибки

| Ключ | RU | Оценка |
|---|---|---|
| `settingsV2StorageError` (`secret/..._ru.dart:1385`) | «Не удалось загрузить данные хранилища» | ⚠ нет второй части «что делать», хотя рядом есть кнопка «Повторить» — приемлемо |
| `settingsDeviceError` + `Hint` | «Не удалось получить параметры устройства» / «Попробуйте обновить сведения. Данные приложения не изменятся.» | ✅ образец: что + что делать + успокоение |
| `settingsSessionsLoadFailed` | «Не удалось загрузить устройства. Проверьте подключение и попробуйте ещё раз.» | ✅ |
| `noticeSyncFailed` | «Не удалось обновить push на сервере. Настройка сохранена; повторим при подключении.» | ✅ |
| `settingsV2BiometricFailure` | «Не удалось подтвердить личность» | ⚠ нет «что делать» |
| `commonError` (`:108`) | «Произошла ошибка» | ✖ в настройках используется как единственный текст ошибки таймаута (`account_security_section.dart:67`) |
| `settingsPrivacyLoadFailed` в `blocked_users_screen.dart:167` | «Не удалось обновить настройки приватности» | ✖ не тот контекст |
| `settingsPlusStatusFailed` | «Не удалось проверить подписку. Обновите статус перед активацией пробного периода.» | ✅ |
| `secretCreateFailed` (`settings_privacy`→E2EE) | «Не удалось открыть секретный чат. Попробуйте ещё раз.» | ✖ на экране «Секретные чаты» речь про ключ, а не про открытие чата |
| `aboutReportError` | «Не удалось отправить отчёт. Попробуйте позже.» | ⚠ нет запасного канала (Telegram/почта) |

### 6.3. Пустые состояния

| Место | Текст | Оценка |
|---|---|---|
| Поиск настроек, пустой запрос (`profile_screen.dart:337-340`) | «Найдите параметр по названию или действию» | ⚠ это инструкция, а не состояние; показывается, пока поле пустое |
| Поиск, нет результатов | «Ничего не найдено. Попробуйте другое слово.» | ✅ |
| Часовые пояса, нет результатов (`settings_language_region_screen.dart:271-272`) | переиспользуется `settingsV2SearchNone` = «Ничего не найдено. Попробуйте другое слово.» | ⚠ в контексте часовых поясов «другое слово» звучит странно; лучше «Такого часового пояса нет» |
| Сессии, других нет | «Нет других активных сессий» + «Вы вошли в аккаунт только с этого устройства.» | ✅ |
| Заблокированные, пусто | «Вы еще никого не заблокировали» (+ «По запросу ничего не найдено») | ⚠ нет ё; нет подсказки, как заблокировать |
| Хранилище, ошибка | текст + кнопка | ✅ |
| Уведомления, нет разрешения | «Для push нужно разрешение системы» + «Включите уведомления для NiosMess в настройках браузера или устройства.» | ⚠ нет кнопки «Открыть настройки» — текст отправляет вручную искать |
| Устройство, ошибка | см. 6.2 | ✅ |

---

## 7. Русский и английский: расхождения

**Проверено:** у всех ≈450 использованных ключей есть оба перевода, наборы плейсхолдеров совпадают, незаполненных `{}` нет, у методов совпадают сигнатуры. Пустых переводов нет. Это хорошая новость.

Проблемы другого рода:

1. **Смысл разошёлся.**
   - `settingsSecretChatsSubtitle`: RU «Сквозное шифрование (E2EE)» (`app_localizations_ru.dart:2398`) vs EN «End-to-end encrypted messaging» (`app_localizations_en.dart:2373`) — RU называет технологию, EN описывает функцию.
   - `settingsV2Storage`: «Данные и память» vs «Data and storage».
   - `settingsV2Motion`: «Анимации и энергосбережение» vs «Motion and battery».
   - `aboutTabLegal`: «Документы» vs «Legal».
   - `settingsDeviceUnknown`: «Недоступно» vs «Unavailable» — оба неверны для *неизвестного* значения.
   - `modalSessionBody`: RU — «Устройство «{device}» будет отключено…» (`secret/..._ru.dart:129`), EN — с типографскими кавычками “{device}” (`secret/..._en.dart:129`). В одном окне две разные кавычки — нормально, но в RU «ёлочки» внутри строки ломают поиск по подстроке.
2. **Английский ушёл вперёд.** `settingsServerLimitsSubtitle` (RU-заглушка, EN — готовый текст). Плюс `settingsV2NotificationsHint`: RU «Push, превью сообщений…» — англицизмы, которых в EN нет.
3. **Плюрализация.** В проекте есть ICU-плюрализация (7 вызовов `pluralLogic` в каждом каталоге, `secret/app_ru.arb:66,75,133,950`), но у настроек она не применена: `e2eeEraseDone` (`app_localizations_ru.dart:3272`), `privacyBlockedCount` (`:4410` — «Заблокировано: 1», тут безопасно), `settingsPlusCommunities` («220 публичных каналов» — зашито числом, при смене лимита сломается), `settingsPlusAiBudget` («300 Ниосиков»).
4. **Числа и единицы.** В RU «МБ», «ГБ», «Гц», «МП» (`secret/..._ru.dart:2007-2013`), в EN «MB/GB/Hz/MP»; «МП» для мегапикселей — нестандартно (обычно «Мп»). Форматирование размеров отдано `FileTypeDetector.formatFileSize` — не проверял, локализует ли он десятичный разделитель.
5. **Порядок и склейки.** Три места собирают фразу конкатенацией (см. Л38-Л45), поэтому перевод не может изменить порядок слов.
6. **Формы обращения.** Везде «вы» со строчной — единообразно (`settingsSpamBlockSubtitle`, `aboutUpToDate`, `settingsV2ResetBody`). Исключений не нашёл. Это можно фиксировать как правило.
7. **Регистр.** EN Title Case: «Send with Enter Key», «Quick Reaction», «Secret Chats», «Secret Chats (E2EE)», «Erase Secret Chats», «Device Key», «Palette Style», «App Data», «Alpha Test», «Report a Bug», «System Update», «NiosMess OTA Updates», «Third-Party Licenses & Libraries», «Chat Wallpaper», «Pure Black (OLED)», «About Developer», «Contact Support», «Theme Mode», «Secret Mode Activated!». При этом рядом «Push notifications», «Notification sound», «Interface density», «Auto-lock», «Two-factor authentication». RU заголовки — с одной заглавной, стабильно.

---

## 8. Словарь терминов для настроек

| Понятие | Канон RU | Канон EN | Запрещено / убрать |
|---|---|---|---|
| Учётная запись | **аккаунт** | account | «профиль» в значении аккаунта; «учётка» |
| Человек | **профиль** (имя, фото, описание) | profile | «страница», «анкета» |
| Идентификатор | **Nios ID** (с пробелом, всегда) | Nios ID | «NiosID», «Nios Id», «ID аккаунта» |
| Вход в аккаунт на устройстве | **сеанс** (род. «сеанса», мн. «сеансы») | session | «сессия», «сеанс связи», смешение «сессия/устройство» в одном экране |
| Физическое устройство | **устройство** | device | «девайс», «гаджет» |
| Уведомления | **уведомления** | notifications | «оповещения», «пуши», «push-уведомления» (кроме технического контекста) |
| Настройки уведомлений по типам | **категории уведомлений** | notification categories | «каналы» (в UI), «топики» |
| Звук/вибро | **звук**, **вибрация**, **тактильный отклик** | sound, vibration, haptics | «хаптик», «haptic» в RU |
| Временные файлы | **кэш** | cache | «кеш» |
| Место на диске | **хранилище** | storage | «память» (только про RAM: «оперативная память») |
| Данные приложения | **данные приложения** | app data | «App Data», «Данные» (без уточнения) |
| Оформление | **оформление** (тема, палитра, шрифт, плотность) | appearance | «внешний вид», «персонализация», «стиль» |
| Палитра | **палитра**, **акцентный цвет** | palette, accent color | «характер палитры», «тон», «Color seed» |
| Приватность | **приватность** (кто что видит) | privacy | «приватка»; смешение с «безопасностью» |
| Безопасность | **безопасность** (вход, ключи, блокировка) | security | «защита» как синоним в заголовках |
| E2EE | **сквозное шифрование (E2EE)** — один раз расшифровать, дальше «E2EE» | end-to-end encryption (E2EE) | «сквозное шифрование E2EE» (дубль), «шифровка» |
| Секретный чат | **секретный чат** | secret chat | «защищённый чат», «приватный чат» |
| Ключ | **ключ**, **пара ключей**, **отпечаток** | key, key pair, fingerprint | «fingerprint» в RU, «слепок» |
| Блокировка приложения | **блокировка приложения**, **автоблокировка** | app lock, auto-lock | «app lock» в RU, «лок» |
| Биометрия | **биометрия**, **отпечаток или лицо** | biometrics, fingerprint or face | «Face ID», «Touch ID» (только как пример) |
| Чёрный список | **заблокированные** (пункт «Заблокированные», экран «Заблокированные пользователи») | blocked, blocked users | «Чёрный список», «blacklist», «Blocked list» |
| Жалоба | **спам-блок**, **ограничение аккаунта** | spam block, account restriction | «забанен», «продакшн» |
| Nios-подписка | **Nios+** | Nios+ | «Nios Plus», «Nios +», «премиум» |
| ИИ | **NiosAI** | NiosAI | «ИИ-ассистент» вперемешку с «NiosAI», «бот» |
| Единицы | **%**, **МБ/ГБ**, **Гц**, **Мп** | %, MB/GB, Hz, MP | «dp», «DIP», «МП» |
| Плюрализация | ICU `plural` для любого счётчика | ICU `plural` | ручные «чатов/файлов» |

Правило одного понятия: **одно понятие — один ключ — одно название на всех экранах.** Дубли вроде `settingsV2Preview`/`noticePreview` и `settingsChatsAutoDownloadWifi`/`settingsV2Wifi` должны схлопнуться.

---

## 9. Правила стиля (12)

1. **Один термин — один ключ — одно название.** Перед новой строкой проверь §8; если понятия нет — добавь в словарь, а не придумывай синоним. Ни одной строки в коде: даже «Nios ID», «dp», «Скрыть» — ключи в оба каталога; служебные строки (assert, `StateError`) живут только в debug-путях.
2. **Заголовок раздела — существительное, 1-2 слова, без «и»-склеек.** «Оформление», «Уведомления», «Хранилище», «Приватность», «Безопасность», «Язык и время», «О приложении». Не «Данные и память», не «Помощь и о приложении».
3. **Название пункта — объект, действие — глагол в кнопке.** «Отчёты о прочтении», «Автоблокировка», «Очистка кэша»; кнопка — инфинитив: «Завершить», «Очистить», «Удалить навсегда». Один глагол на действие: не «Удалить» для очистки кэша, не «End»/«Terminate» для одного и того же.
4. **Подпись объясняет следствие, а не повторяет название.** Формула: «что произойдёт» + «чего не случится». Пример-эталон: «Попробуйте обновить сведения. Данные приложения не изменятся.»
5. **Длина подписи — до 90 знаков (2 строки).** Больше — вынести в отдельный блок-описание или разбить на пункты. 120+ знаков в строке не допускается.
6. **Точка в конце — только у полного предложения.** Короткая подпись-перечисление без точки. Сейчас 29 с точкой и 54 без — привести к одному.
7. **Обращение — «вы» со строчной или безличная форма.** «Вы получите…», «Можно выбрать…». Не «Вы», не «ты».
8. **Без англицизмов там, где есть русское слово.** «предпросмотр» вместо «превью», «имя пользователя» вместо «юзернейм», «обновление» вместо «апдейт». Технологии (E2EE, FCM, OTA, HEX, Bluetooth) — только с расшифровкой при первом упоминании в разделе.
9. **Никаких шуток, оценок и внутренних имён в системных текстах.** «Тут лучше аккуратно трогать», «с милым уведомлением», «слабые устройства», «Продакшн», «Пака не сделано» — вне UI.
10. **Опасное действие: что исчезнет + необратимо ли + кнопка глаголом.** «Удалить все секретные чаты?» — эталон. Выход из аккаунта обязан сказать и про обычные чаты, и про другие устройства.
11. **Регистр: EN — sentence case, RU — только первое слово с заглавной.** Исключения: имена продуктов (NiosMess, Nios+, NiosAI, NiosGram, Nios ID) и аббревиатуры.
12. **Счётчики — только через ICU `plural`, числа и даты — через один формат** (`formatFileSize`, `formatFullDateTime`), единицы — из словаря §8.

---

## 10. Варианты названий для новой структуры

Ниже — карта переименований: 11 пунктов первого уровня (сейчас видно 9, «Аккаунт» скрыт) плюс подчинённые экраны. Главный принцип: **название отвечает на вопрос «что я тут настрою», а не «какая это технология»**.

| № | Сейчас | Предлагаю RU | EN | Что внутри | Почему |
|---|---|---|---|---|---|
| 1 | Аккаунт (скрыт из хаба) | **Аккаунт** | Account | профиль, имя, Nios ID, QR, вход и 2FA | вернуть в хаб: сейчас раздел открыт по умолчанию, но пункта нет |
| 2 | Приватность и безопасность | **Приватность** | Privacy | кто видит телефон/фото/био/активность, кто может писать и звонить, блокировки | «безопасность» переезжает в №3 |
| 3 | (внутри приватности) | **Безопасность** | Security | сеансы, блокировка приложения, биометрия, сквозное шифрование | сеансы и E2EE — это безопасность, а не «кто что видит» |
| 4 | Оформление | **Оформление** | Appearance | тема, палитра, шрифт, плотность, скругления | оставить: слово работает |
| 5 | Чаты и звонки | **Чаты** | Chats | Enter, реакции, папки, автозагрузка медиа, устройства звонка | автозагрузка — про медиа в чатах, ей тут место |
| 6 | Уведомления и звуки | **Уведомления** | Notifications | push, категории, звук, вибрация, проверка звука | «и звуки» — лишнее: звук уведомлений внутри |
| 7 | Анимации и энергосбережение | **Производительность** | Performance | анимации стикеров и эмодзи, экономия ресурсов, работа в фоне | «энергосбережение» — только один из трёх блоков |
| 8 | Данные и память | **Хранилище** | Storage | занято, кэш, черновики, категории, кэш секретных чатов | «память» — про RAM, здесь диск |
| 9 | Язык и время | **Язык и регион** | Language & region | язык, часовой пояс, формат даты | в разделе есть формат и часовой пояс, не только «время» |
| 10 | Nios+ · NiosAI | **Nios+** | Nios+ | подписка, лимиты, пробный период, NiosAI внутри | один бренд в заголовке; NiosAI — в подписи |
| 11 | Помощь и о приложении | **О приложении** | About | версия, обновления, документы, команда, диагностика, сброс | «Помощь» уходит в отдельный пункт поддержки внутри |
| 12 | Система и устройство (внутри «О приложении») | **Диагностика** | Diagnostics | характеристики устройства | сейчас раздел называется «Система и устройство», а вход — «Диагностика устройства»; назвать одинаково |

Подчинённые экраны, которые стоит назвать иначе:

| Сейчас | Предлагаю | Почему |
|---|---|---|
| Секретные чаты (E2EE) | **Сквозное шифрование** (внутри «Безопасность») | «секретный чат» — тип чата, а экран про ключи |
| Активные сессии | **Сеансы** | одна сущность — одно слово |
| Чёрный список / Заблокированные пользователи | **Заблокированные** | короче, нейтральнее, без ё-вариаций |
| Настройки безопасности (пункт в «Аккаунте») | убрать | ведёт в «Приватность» — обманка |
| Фон чатов / Обои | **Оформление → Фон чатов** | сейчас недостижим; если возвращать — только как подпункт оформления |

Если не разводить «Приватность» и «Безопасность», первый уровень — 10 пунктов («Аккаунт» возвращается в список). Минимальный набор правок без перестройки: «Данные и память» → «Хранилище», «Анимации и энергосбережение» → «Производительность», «Помощь и о приложении» → «О приложении», литерал «Nios+ · NiosAI» → «Nios+», «Система и устройство» → «Диагностика» в обоих местах.

---

## Не проверено

- **История git.** Как и когда исчезли `lib/l10n/app_ru.arb` / `app_en.arb`, не смотрел (git-команды запрещены условиями задачи). Возможно, они лежат в другой ветке или генерируются внешним скриптом — в текущем рабочем дереве их нет, `l10n.yaml` указывает только на `lib/l10n/secret`.
- **Реальный рендер.** Длину строк оценивал по лимитам кода (`settings_list_item.dart:169-174,213`, `bodySmall`), а не по скриншотам. «2 строки» — оценка.
- **Визуальная проверка «Пака не сделано»** в приложении не выполнялась (запуск запрещён); вывод сделан по коду: `settings_privacy_screen.dart:309-321` рендерит секцию при `spamBlock == true` (`settings_privacy_screen.dart:34`).
- **Системные подписи** (tooltip «Назад», «Закрыть», «Удалить») приходят из `MaterialLocalizations` (`settings_shell.dart:107-109`, `profile_screen.dart:317`, `settings_language_region_screen.dart:238-240,256-258`) — их перевод не мой слой, не проверял.
- **Экран обоев** (`lib/features/wallpaper/**`) прочитан только по заголовку и паре ключей; полный аудит текстов обоев не делал (он недостижим из настроек).
- **`ordinary_e2ee_settings.dart`** (26 КБ) прочитан выборочно по строкам каталога; возможны непроверенные длинные тексты внутри диалогов.
- **Серверные тексты** (ошибки API, лимиты) не проверял: `server_core/` в этом репозитории отсутствует.
- **Ключи, используемые динамически** (по строковому имени), теоретически могли попасть в «мёртвые». Проверял текстовым поиском по `lib`; выборочная проверка 5 ключей подтвердила отсутствие, полную гарантию не даю.
- **Другие языки** не проверял: поддерживаются только `ru` и `en` (`AppLocalizations.supportedLocales`, `lib/main.dart:395`).
- **`FileTypeDetector.formatFileSize`** — локализует ли он разделитель и единицы, не смотрел.
