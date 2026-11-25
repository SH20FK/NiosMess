# Аудит «Настройки» — 02. Архитектура кода

Дата: 2026-11-22. Роль: архитектор кода. Только чтение кода: `flutter`/`dart`/`git` не запускались (12 параллельных агентов).
Все утверждения ниже получены чтением файлов и подсчётом вхождений поиском по `F:/Niosmess V2/pulse_flutter`
(числа вхождений — результат `Select-String`/ripgrep по `lib` и `test`, а не прогон анализатора).

---

## 1. Главные выводы

1. **В коде живут три параллельные системы «строка настройки»**: `SettingsListItem` (`lib/widgets/settings/settings_list_item.dart:14`),
   легаси-обёртки `SettingsTile/SettingsSwitchTile/SettingsInfoTile` (`lib/widgets/settings_ui.dart:246,291,325`) и
   `SettingsRow` + sealed `SettingsControl` (`lib/features/settings/presentation/settings_row.dart:135`,
   `lib/features/settings/domain/settings_control.dart:3`). Экраны поделены между ними: `privacy` — 17 `SettingsRow`,
   `storage` — 8 `SettingsRow`, но `energy-saving` — 3 `SettingsSwitchTile` + 1 `SettingsRow`, `about` — 12 `SettingsListItem`.
   Возможности у трёх API разные (`pending`/`disabledReason` есть только в двух, `danger`-вариант — только в `SettingsListItem`).
2. **Каркас экрана продублирован трижды**: рабочий `SettingsShell` (`lib/widgets/settings/settings_shell.dart:29`),
   `SettingsScaffold` (`lib/widgets/settings_ui.dart:16`, в проде не используется — только тесты) и
   `SettingsResponsiveShell` (`lib/features/settings/presentation/settings_responsive_shell.dart:14`, не импортирует никто).
   Плюс третий режим заголовка — `SettingsHeadingScope` (`settings_shell.dart:9`).
3. **Хаба настроек как отдельного экрана нет**: маршрут `/settings` редиректит на `/main/settings`
   (`lib/router/app_router.dart:529-536`), а рисует всё `ProfileScreen` — 840 строк, 2 класса
   (`lib/screens/profile_screen.dart:51`): профиль-хедер, загрузка аватара, бейджи, логаут, поиск, health-карточки и
   `switch` по 13 разделам (`profile_screen.dart:676-706`). `SettingsHubScreen` (`lib/screens/settings/settings_hub_screen.dart:8`)
   — 17-строчная обёртка, которую импортируют только тесты.
4. **Два источника правды для одной и той же настройки**: каталог `SettingsRegistry` (866 строк,
   `lib/services/settings/settings_registry.dart:36`) и ручная вёрстка экранов. Поиск отдаёт якоря через хардкод-switch
   (`settings_registry.dart:800-807`), а экраны задают якоря четырьмя разными соглашениями: `SettingId.*.value`
   (`settings_privacy_screen.dart:68`), «сырые» snake-id (`settings_appearance_screen.dart:200`, `settings_storage_screen.dart:125`),
   dot-path (`settings_chats_screen.dart:43`), а health-issues ссылаются на якоря, которых не существует вовсе
   (`lib/features/settings/domain/settings_issue.dart:33,43,55,66`). Подсветка/скролл к найденному элементу работает только
   там, где строки случайно совпали.
5. **Состояние — одна «божественная» модель**: `UiSettingsState` — 42 поля и 42 параметра `copyWith`
   (`lib/providers/ui_settings_provider.dart:165-311`), 40 ключей SharedPreferences (`:321-360`), 42 сеттера (`:532-767`),
   файл 826 строк. Шесть мест читают стейт целиком (`profile_screen.dart:764`, `settings_chats_screen.dart:30`,
   `settings_energy_saving_screen.dart:21`, `settings_language_region_screen.dart:20`, `settings_preferences_screen.dart:72`,
   `connectivity_provider.dart:74`) — любой тумблер ребилдит весь экран.
6. **`lib/features/settings/**` — слой, который почти не используется**: из 11 файлов 4 мёртвые по импортам
   (`setting_mutation_controller` — 0, `settings_responsive_shell` — 0, `domain/settings_section.dart` — 0,
   `domain/settings_destination.dart` — 0); из живых `settings_health_controller` имеет 1 импорт, `settings_anchor_controller` — 3.
7. **Мёртвого кода примерно на 390 строк** (+ тестовые зависимости): файлы на 105 и 48 строк, 41 строка домена,
   `SettingsScaffold` 57 и `SettingsNavBanner` 83, неиспользуемые `SettingsActionNode` и `badgeValue`.
8. **Монолиты >600 строк**: `settings_appearance_screen.dart` 881 (14 классов внутри файла), `settings_registry.dart` 866,
   `profile_screen.dart` 840, `ui_settings_provider.dart` 826, `ordinary_e2ee_settings.dart` 717 — порог пройден у пяти
   файлов, и все пять относятся к настройкам; следующий по размеру `settings_storage_screen.dart` — 490.
9. **Нарушений явных запретов AGENTS.md (StateProvider, `dart:io`, `withOpacity`, `Colors.white/black`, `PopupMenuButton`,
   прямой `CircularProgressIndicator`) в коде настроек не найдено.** Зато есть нарушения другого правила — L10n:
   захардкоженные русские строки в `settings_issue.dart:29-67`, `settings_issue_card.dart:85`, `settings_registry.dart:276,512`.
10. **Тесты закрепляют легаси-API**: `SettingsScaffold` и `SettingsTile/SwitchTile/InfoTile` проверяются в
    `test/widgets/settings_screens_m3_test.dart:158,201`, `settings_performance_phase4_test.dart:95`,
    `settings_scroll_smoothness_test.dart:33`, `settings_desktop_restructure_test.dart:41`; состав разделов хаба
    закреплён ожиданием `ids.length == 9` (`test/unit/settings_registry_test.dart:19`). Любая чистка должна идти вместе с тестами,
    иначе шаг «проект собирается» превращается в шаг «тесты падают».

---

## 2. Таблица находок

| # | Сев. | Место | Что не так | Что предлагаю |
|---|---|---|---|---|
| 1 | P1 | `settings_list_item.dart:14`; `settings_ui.dart:246,291,325`; `settings_row.dart:135`; `settings_control.dart:3` | Три API строки + 5 типов в enum (`settings_list_item.dart:9`). Одинаковые по смыслу контролы имеют разный набор возможностей: `pending` есть в `SettingsListItem:140,188` и `SettingsRow:188`, но `SettingsSwitchTile` (`settings_ui.dart:291-323`) его теряет; `disabledReason` есть только в `SettingsRow:143,175`; `danger` — только `SettingsListItem.danger:109` | Один `SettingsRow` с union-контролом (toggle/choice/slider/value/nav/action) и едиными `pending`/`disabledReason`/`destructive`; `SettingsListItem` оставить внутренним примитивом |
| 2 | P1 | `settings_shell.dart:29`; `settings_ui.dart:16`; `settings_responsive_shell.dart:14` | Три оболочки экрана, две из них мертвы; разные модели скролла (`CustomScrollView`+`SliverAppBar.large` vs `NestedScrollView`, `responsive_shell.dart:80-90`) и разные заголовки (`SettingsHeadingScope`) | Один `SettingsPage` (Scaffold + SliverAppBar + `isEmbedded` + `onRefresh`), мёртвые удалить |
| 3 | P1 | `profile_screen.dart:51` (840 строк) | Хаб настроек = экран профиля: аватар `:121`, логаут `:213`, бейджи `:250`, поиск `:290`, health `:438`, master-detail `:603`, `switch` по 13 разделам `:676-706`. Импортирует 13 экранов (`:27-39`) | Вынести `SettingsHubPage` + `SettingsProfileCard`; профиль-логику — в `features/profile`; хаб не должен знать про 13 конкретных экранов, только про каталог |
| 4 | P1 | `settings_registry.dart:36-866`; якоря `:800-807` | Каталог дублирует содержимое экранов: 11 top-level (`:40-319`) и ~40 детей (`:322-697`) описаны отдельно от UI. Четыре несовместимых соглашения об id (см. вывод 4) | Один каталог `settings_catalog.dart` как источник и для UI, и для поиска; id = `SettingId`; тест-инвариант «каждый anchor из каталога существует в дереве» |
| 5 | P1 | `ui_settings_provider.dart:67-826` | 42 поля / 42 сеттера / 40 prefs-ключей / 826 строк в одном Notifier; 6 мест читают стейт целиком | Разбить на доменные notifier'ы (`appearance`, `chats`, `privacy`, `notifications`, `storage`, `motion`, `language`); в UI — производные провайдеры/`select` |
| 6 | P2 | `settings_responsive_shell.dart` (105), `setting_mutation_controller.dart` (48), `domain/settings_section.dart` (17), `domain/settings_destination.dart` (24), `settings_hub_screen.dart` (17, только тесты), `SettingsScaffold` (`settings_ui.dart:16-72`), `SettingsNavBanner` (`settings_ui.dart:74-156`) | Мёртвый код (доказательства — §4) | Удалить в 1-2 коммита, предварительно переписав 4 теста на `SettingsShell` |
| 7 | P2 | `settings_issue.dart:29-67`; `settings_issue_card.dart:85`; `settings_registry.dart:276,512,513,528,529,546,547,567,568` | Захардкоженные RU-строки в коде (нарушение «L10n: all user-facing strings via `context.l10n`») | Перенести в `.arb`, каталог хранит `String Function(AppLocalizations)` |
| 8 | P2 | `settings_health_controller.dart:16-19` + `settings_issue.dart:47-57` | `storageLow(int freeBytes)` получает `storage.temporaryBytes` (размер кэша) и печатает «осталось N МБ» — семантика перевёрнута; порог `> 1 ГБ` означает «много кэша», а не «мало места» | Переименовать в `storageCacheLarge(cacheBytes)`; либо передавать реально свободное место |
| 9 | P2 | `settings_issue.dart:32,42,54,65` | Маршрут `notificationsDenied()` — `/settings/notifications`, такого роута нет (`app_router.dart:659` — `/settings/preferences`); якоря issues не существуют | Починить route/anchor в рамках единого `SettingId` |
| 10 | P2 | `settings_registry.dart:700-709` + `test/unit/settings_registry_test.dart:17-19` | `getTopLevelSections()` жёстко выкидывает `account` и `system_device`, поведение закреплено тестом; при этом `_buildDetailPane` содержит их кейсы (`profile_screen.dart:678,692`) и роут `/settings/system-device` жив (`app_router.dart:640-650`) — раздел недостижим из списка | Решить, чем является Account (хедер профиля vs раздел), и убрать «мёртвые» кейсы/роут либо вернуть раздел в каталог |
| 11 | P2 | `widgets/settings_ui.dart:160` vs `features/settings/domain/settings_section.dart:5` | Коллизия имени `SettingsSection` (виджет-группа и домен-модель раздела хаба) | Виджет переименовать в `SettingsGroupCard`, домен-модель удалить |
| 12 | P2 | `settings_appearance_screen.dart` (881, 14 классов), `ordinary_e2ee_settings.dart:19-717`, `settings_storage_screen.dart:25-490`, `profile_screen.dart` (840) | Экраны-монолиты: бизнес-логика (загрузка changelog, очистка кэша, E2EE-пейринг, аватар) живёт в `State` экрана вместе с вёрсткой и приватными виджетами | Логику — в application-контроллеры (`features/settings/application`), вёрстку — в отдельные виджеты/файлы |
| 13 | P3 | `e2ee_settings_screen.dart:233-240` | Destructive-строка сделана через легаси `SettingsTile` + `iconColor: scheme.error` вместо `SettingsListItem.danger` (`settings_list_item.dart:109`) | Унифицировать при переезде на единый `SettingsRow` |
| 14 | P3 | `settings_list_item.dart:169-174` | `inlineValue` переключает вёрстку по длине строки (`<= 18`) и текущему `textScaler` — layout зависит от данных, а не от макета | Явный параметр `valuePlacement` |
| 15 | P3 | `settings_anchor_controller.dart:25-31` | Подсветка гаснет по таймеру 1000 мс: при медленном переходе/долгом кадре она исчезнет до скролла | Сбрасывать по факту `ensureVisible`, а не по времени |
| 16 | P3 | `settings_ui.dart:36-68` | `adaptiveColumns` делит `children` пополам (`(length+1)~/2`) — колоночная вёрстка зависит от числа переданных детей; в проде не используется | Не переносить в новую структуру либо задавать раскладку секциями явно |
| 17 | P3 | `settings_shell.dart:104-118` | Фолбэк «назад» ведёт на `/main/profile`, который редиректит на `/main/settings` (`app_router.dart:250-252`) — лишний хоп, который легко потерять при редизайне | Явный `context.go('/main/settings')` |

P0 не выставлен: приложение работоспособно, проблемы — структурные и точечно-функциональные (поиск/подсветка).

---

## 3. Карта систем

### 3.1. Файлы, строки, публичные классы, импортёры (только `lib`)

Счётчик импортёров — число файлов в `lib`, содержащих `import 'package:pulse_flutter/<путь>'`.
Важно: почти все экраны импортируют **barrel** `widgets/settings_ui.dart` (28 файлов), поэтому прямых импортов
`settings_list_item.dart` всего 2 (`settings_row.dart:6`, сам barrel `settings_ui.dart:5`), а `settings_shell.dart` — 2
(`settings_ui.dart:7` и мёртвый `settings_responsive_shell.dart:3`). Реальные зависимости скрыты за barrel'ом.

| Система | Файл | Строк | Публичные классы / API | Импортёров в lib | Статус |
|---|---|---|---|---|---|
| A. Barrel + легаси | `lib/widgets/settings_ui.dart` | 357 | `SettingsScaffold:16`, `SettingsNavBanner:74`, `SettingsSection:160`, `SettingsTile:246`, `SettingsSwitchTile:291`, `SettingsInfoTile:325`; 5 re-export (`:9-13`) | 28 | частично легаси (2 класса мертвы) |
| B. Атомы | `lib/widgets/settings/settings_list_item.dart` | 319 | `SettingsListItemType:9`, `SettingsListItem:14` (+`.nav/.toggle/.value/.danger`), `dividerIndent:143` | 2 (+barrel) | ядро, живо |
| B | `lib/widgets/settings/settings_shell.dart` | 189 | `SettingsHeadingScope:9`, `SettingsShell:29` | 2 (+barrel) | ядро, живо |
| B | `lib/widgets/settings/pressable_surface.dart` | 143 | `PressableSurface:14` | 2 (+barrel export) | живо |
| B | `lib/widgets/settings/settings_group_scope.dart` | 21 | `SettingsGroupScope:4` | 3 (+barrel) | живо |
| B | `lib/widgets/settings/settings_choice_buttons.dart` | 40 | `SettingsChoiceButtons<T>:4` | 1 (+barrel export) | живо |
| B | `lib/widgets/settings/settings_profile_header.dart` | 329 | `SettingsProfileHeader:12`, `_ProfileHeaderDelegate` | 1 (`profile_screen.dart:8`) | живо |
| B | `lib/widgets/settings/ordinary_e2ee_settings.dart` | 717 | `OrdinaryE2eeSettings:19` (+`State`) | 1 (`e2ee_settings_screen.dart:2`) | монолит |
| B | `lib/widgets/settings/account_security_section.dart` | 180 | `AccountSecuritySection:18` | 1 (`settings_privacy_screen.dart:1`) | живо, использует `SettingsRow` |
| B | `lib/widgets/settings/custom_color_picker_sheet.dart` | 435 | `CustomColorPickerSheet:28` | 1 (`settings_appearance_screen.dart:15`) | живо |
| B | `lib/widgets/settings/about_bug_report_dialog.dart` | 140 | — | 1 (`settings_about_screen.dart:25`) | живо |
| B | `lib/widgets/settings/about_identity_widgets.dart` | 70 | — | 1 | живо |
| B | `lib/widgets/settings/about_update_tile.dart` | 101 | — | 1 | живо |
| B | `lib/widgets/settings/system_resource_meter.dart` | 104 | `SystemResourceMeter:6` | 1 | живо |
| C. Feature-слой | `lib/features/settings/presentation/settings_row.dart` | 196 | `SettingsAnchor:9`, `SettingsSearchDisclosure:21`, `SettingsRow:135` | 10 | живо, вторая система строк |
| C | `lib/features/settings/presentation/settings_responsive_shell.dart` | 105 | `SettingsResponsiveShell:14`, `settingsScrollPhysics:5` | **0** | мёртв |
| C | `lib/features/settings/presentation/settings_issue_card.dart` | 114 | `SettingsIssueCard:7` | 1 (`profile_screen.dart:49`) | живо |
| C | `lib/features/settings/application/settings_anchor_controller.dart` | 43 | `SettingsAnchorState:6`, `SettingsAnchorController:16` | 3 | живо |
| C | `lib/features/settings/application/settings_health_controller.dart` | 27 | `settingsHealthProvider:7` | 1 | живо |
| C | `lib/features/settings/application/setting_mutation_controller.dart` | 48 | `SettingMutationState:4`, `AsyncSettingController:22` | **0** | мёртв |
| C | `lib/features/settings/domain/settings_control.dart` | 32 | `SettingsControl:3`, `Navigation/Toggle/Value/ActionControl` | 6 | живо (только через `SettingsRow`) |
| C | `lib/features/settings/domain/setting_id.dart` | 68 | `SettingId:4` + ~45 констант | 5 | живо |
| C | `lib/features/settings/domain/settings_issue.dart` | 69 | `SettingsHealthSeverity:3`, `SettingsHealthIssue:6` + 4 factory | 2 | живо |
| C | `lib/features/settings/domain/settings_section.dart` | 17 | `SettingsSection:5` (домен) | **0** | мёртв |
| C | `lib/features/settings/domain/settings_destination.dart` | 24 | `SettingsDestination:6` | 1 (только `settings_section.dart`) | мёртв |
| D. Модель+каталог | `lib/models/settings/settings_node.dart` | 179 | `SettingsGroup:9`, `SettingsNode:48`, `SettingsNavNode:73`, `SettingsToggleNode:94`, `SettingsChoiceNode:113`, `SettingsSliderNode:136`, `SettingsActionNode:163` | 2 (`settings_registry`, `profile_screen`) | живо, `SettingsActionNode`/`badgeValue:90` не используются |
| D | `lib/services/settings/settings_registry.dart` | 866 | `SettingsSearchResult:12`, `SettingsRegistry:36` | 1 (`profile_screen.dart:40`) | живо, монолит |
| D | `lib/services/settings/notification_preference_action.dart` | 33 | `updateNotificationPreference` | 3 | живо |
| E. Состояние | `lib/providers/ui_settings_provider.dart` | 826 | `UiSettingsState:67`, `UiSettingsNotifier:320`, enum'ы `:7-30`, `uiSettingsProvider:823` | 53 | живо, «божественный» стейт |
| E | `lib/providers/settings_navigation_provider.dart` | 46 | `SettingsSectionId:5`, `DesktopSettingsSectionNotifier:29`, провайдер `:42` | 9 | живо; enum раздела лежит в файле провайдера |
| F. Роутинг | `lib/router/web_settings_location.dart` | 24 | `webSettingsRedirect:2` | 1 (`app_router.dart:3`) | живо (web-only) |
| F | `lib/router/app_router.dart` | 847 | 17 путей `/settings*` | — | `:529` редирект, `:538-680` экраны |

### 3.2. Схема связей (текстом)

```
/settings ──redirect──► /main/settings ──► MainShellScreen(:605) ──► ProfileScreen (840)
                                                                      ├─ SettingsProfileHeader
                                                                      ├─ SettingsRegistry (каталог + поиск)
                                                                      ├─ settingsHealthProvider ──► SettingsIssueCard
                                                                      └─ switch(SettingsSectionId) → 13 экранов (isEmbedded: true)

13 экранов настроек (standalone routes /settings/*; отдельно /settings/sessions → features/sessions):
   SettingsShell ◄─ barrel settings_ui.dart ◄─ 28 импортёров
     ├─ SettingsSection ─ SettingsListItem ◄── SettingsRow ◄── SettingsControl
     │                        ▲                    ▲
     │                        └ SettingsTile/SwitchTile/InfoTile (легаси-обёртки)
     └─ SettingsAnchor/SettingsSearchDisclosure ◄── settingsAnchorControllerProvider

Состояние: uiSettingsProvider (826 строк, 42 поля) ◄── 53 файла, из них 6 читают целиком
```

### 3.3. Две точки правды для одной настройки (пример)

| Настройка | Каталог (для поиска) | Экран (для UI) |
|---|---|---|
| Send on Enter | `settings_registry.dart:391-408` (`send_on_enter` → anchor `chats.sendOnEnter` через switch `:801`) | `settings_chats_screen.dart:42-51` (`SettingsAnchor(id: 'chats.sendOnEnter')`) ✔ совпало |
| Скругление UI | `settings_registry.dart:324-347` (`ui_corner_radius`) | `settings_appearance_screen.dart:199-217` (`SettingsSearchDisclosure(anchor: 'ui_corner_radius')`) ✔ совпало |
| Быстрые реакции / превью / звук уведомлений | `settings_registry.dart:622-630,656-665` (`notifications.preview`, `motion.emoji`) | якорей с такими id в UI нет; `settings_preferences_screen.dart:80` использует `sound_volume`, `notification_settings_section.dart:134` — `push_notifications` |
| Health: «Мало места» | `settings_issue.dart:55` (`storage-cache-clear`) | в `settings_storage_screen.dart` таких якорей нет (`:125,290,343,362` — `auto_download_wifi` и др.) ✘ |

---

## 4. Мёртвый код (доказано поиском)

| Файл/класс | Строк | Доказательство |
|---|---|---|
| `lib/features/settings/presentation/settings_responsive_shell.dart` | 105 | никто не импортирует: 0 вхождений `settings_responsive_shell` в `lib` и `test`; `SettingsResponsiveShell` встречается только в собственном файле (`:14,15`) |
| `lib/features/settings/application/setting_mutation_controller.dart` | 48 | `asyncSettingControllerProvider` — 1 вхождение, в самом файле (`:45`); `MutationSaving/MutationFailed` — только `:12-38` |
| `lib/features/settings/domain/settings_section.dart` | 17 | 0 импортёров; `SettingsSection` (домен) объявлен `:5` и нигде не инстанцируется (`profile_screen.dart` использует виджет из barrel) |
| `lib/features/settings/domain/settings_destination.dart` | 24 | единственный импорт — `settings_section.dart:2` (сам мёртв) |
| `SettingsScaffold` (`lib/widgets/settings_ui.dart:16-72`) | 57 | в `lib` — только объявление и внутренний вызов `SettingsShell` (`:42`); в проде не используется; используется только тестами (`test/widgets/settings_performance_phase4_test.dart:95`, `settings_scroll_smoothness_test.dart:33,83,117,153`, `settings_screens_m3_test.dart:158,178`, `settings_desktop_restructure_test.dart:41,110`) |
| `SettingsNavBanner` (`lib/widgets/settings_ui.dart:74-156`) | 83 | в `lib` 0 использований; единственный потребитель — `test/widgets/vector_illustrations_test.dart:199` |
| `SettingsActionNode` (`lib/models/settings/settings_node.dart:163-179`) | 17 | 0 использований (`settings_registry.dart` не создаёт ни одного) |
| `SettingsNavNode.badgeValue` (`settings_node.dart:85,90`) | 2 | не читается: `profile_screen.dart:421` использует собственный `_getSectionBadgeValue` |
| `lib/screens/settings/settings_hub_screen.dart` | 17 | в `lib` 0 импортов; маршрут `/settings` редиректит (`app_router.dart:529-536`); импортируется только `test/e2e/niosgram_and_settings_e2ee_test.dart:24`, `test/widgets/settings_master_detail_test.dart:21` |
| `SettingsHealthIssue.notificationsDenied` (`settings_issue.dart:27-35`) | 9 | 0 вызовов; вдобавок ведёт на несуществующий `/settings/notifications` |

Итого чисто мёртвого: 105 + 48 + 17 + 24 + 57 + 83 + 17 ≈ **351 строка**, плюс `settings_hub_screen.dart` (17)
и неиспользуемая factory `notificationsDenied` (9) — вместе **≈ 377 строк**, а с двумя неиспользуемыми полями —
около 390 (§1.7). `SettingsTile/SettingsSwitchTile/SettingsInfoTile` **не мёртвые** — используются
(`e2ee_settings_screen.dart:200,233`, `notification_settings_section.dart:67,135`, `settings_appearance_screen.dart:190,769,809`,
`settings_energy_saving_screen.dart:36,47,63`, `settings_chats_screen.dart:44`, `settings_preferences_screen.dart:84,148`,
`settings_language_region_screen.dart:190`, `settings_plus_screen.dart:261`).

---

## 5. Дубли: кто чем пользуется

### 5.1. Роли компонентов

| Роль | Кандидаты | Комментарий |
|---|---|---|
| Строка | `SettingsListItem` (`:14`), `SettingsRow` (`:135`), `SettingsTile` (`:246`), `SettingsSwitchTile` (`:291`), `SettingsInfoTile` (`:325`) | 3 публичных пути + 4 фабрики; `SettingsRow` — единственный с `anchor`/`disabledReason`/`pending`-для-toggle |
| Группа | `SettingsSection` (`settings_ui.dart:160`) + `SettingsGroupScope` (`:4`) | дублей нет, но имя конфликтует с домен-моделью |
| Заголовок секции | внутри `SettingsSection:185-213` | отдельного компонента нет — заголовки секций задаются props |
| Оболочка экрана | `SettingsShell:29`, `SettingsScaffold:16`, `SettingsResponsiveShell:14` | 1 рабочая, 2 мёртвых |
| Оболочка части экрана | `SettingsAnchor:9`, `SettingsSearchDisclosure:21` | живые, но завязаны на строковые id |

### 5.2. Экран × компонент

| Экран (строк) | Оболочка | Группы | Строки | Особое |
|---|---|---|---|---|
| `settings_account_screen.dart` (108) | SettingsShell | ×2 | SettingsListItem ×2 + `SettingsAnchor` | `_copyableField` (`:86`) собирает строку вручную |
| `settings_privacy_screen.dart` (325) | SettingsShell | ×6 | **SettingsRow ×17**, SettingsListItem ×1 | `AccountSecuritySection` (`:266`) — свой файл с 4 `SettingsRow` |
| `settings_appearance_screen.dart` (881) | SettingsShell | ×3 (+свои) | SettingsSwitchTile ×1, SettingsInfoTile ×2 | 14 классов в файле, `_SliderSettingTile`, `_FontScaleSliderTile`, `_PalettePager`, `NiosColorField`; `SettingsSearchDisclosure` (`:199`) |
| `settings_chats_screen.dart` (104) | SettingsShell | ×3 | SettingsListItem ×2, SettingsSwitchTile ×1 | реакции — `ChoiceChip` вручную (`:60-85`) |
| `settings_preferences_screen.dart` (161) | SettingsShell | ×1 | SettingsSwitchTile ×2, SettingsListItem ×1 | `NotificationSettingsSection` (свой `SettingsSection` + 2 `SettingsSwitchTile` + `SettingsAnchor`) |
| `settings_language_region_screen.dart` (299) | SettingsShell | ×3 | SettingsRow ×1, SettingsInfoTile ×1, SettingsListItem ×1 | `SettingsChoiceButtons` ×2, список таймзон в диалоге (`:273`) |
| `settings_storage_screen.dart` (490) | SettingsShell ×2 (web/native) | ×6 | **SettingsRow ×8** | вся логика очистки в State (`:35-90`); `_SegmentedProgressBar`, `_LegendItem` |
| `settings_energy_saving_screen.dart` (188) | SettingsShell | ×3 | SettingsSwitchTile ×3, SettingsRow ×1 | `SettingsChoiceButtons<BackgroundMode>` (`:86`) |
| `settings_system_device_screen.dart` (270) | SettingsShell | ×3 | SettingsListItem ×2 | `SystemResourceMeter` ×2, `_DeviceDetails/_CopyableSpec/_DeviceBrand` |
| `settings_plus_screen.dart` (287) | SettingsShell | ×3 | SettingsListItem ×2, SettingsInfoTile ×1 | состояние подписки в State |
| `settings_about_screen.dart` (389) | SettingsShell | ×7 | SettingsListItem ×12 | changelog из asset (`:52-64`), `resetAll` (`:96`), `SettingsChoiceButtons<int>` |
| `e2ee_settings_screen.dart` (261) | SettingsShell | ×3 | SettingsTile ×2 (легаси), SettingsListItem ×1 | `OrdinaryE2eeSettings` (717) внутри |
| `settings_wallpaper_screen.dart` (27) | — | — | — | прокси к `WallpaperStudioScreen`, к настройкам относится номинально |
| хаб `profile_screen.dart` (840) | свой LayoutBuilder | ×3 | SettingsListItem ×9 | поиск, health, master-detail |
| вне настроек | SettingsShell: `sessions_screen`, `help_faq_screen`, `privacy_rule_detail_screen`, `blocked_users_screen`; SettingsSection: `alpha_test_dialog`, `edit_profile_sheet`, `badge_picker_sheet`, `working_hours_planner_dialog`, `ai_usage_card`, `session_details_sheet` | | | компоненты настроек протекли в 6+ несвязанных фич |

Итог: **ни один экран не использует один и тот же набор компонентов**. `SettingsRow` — 4 экрана (`privacy`, `storage`,
`energy-saving`, `language-region`; плюс `account_security_section` внутри `privacy`), причём два из них одновременно
пользуются легаси-обёртками. Легаси `SettingsTile/SwitchTile/InfoTile` — 7 файлов (`appearance`, `chats`, `preferences`,
`energy-saving`, `language-region`, `plus`, `e2ee`). «Сырой» `SettingsListItem` — `account`, `chats`, `plus`, `about`,
`system_device`, `privacy`, `preferences` и хаб. Причина — не дизайн-решение, а история правок.

---

## 6. Экраны-монолиты

| Файл | Строк | Классов в файле | Что смешано |
|---|---|---|---|
| `settings_appearance_screen.dart` | 881 | 14 | тема (AnimatedTheme, `DynamicColorBuilder`, `_appearanceThemeProvider:45`), палитры, слайдеры, пикер цвета; `_ThemeModeSelectorCard:683`, `_PalettePager`, `_PalettePagePhysics` — физика страниц внутри экрана |
| `profile_screen.dart` | 840 | 2 | профиль + хаб + поиск + health + master-detail + 13 импортов экранов |
| `ordinary_e2ee_settings.dart` | 717 | 2 | E2EE-сервис: `_run:105`, `_reset:135`, `_createPairCode:159`, `_checkPairing:171`, загрузка контактов `:617`, `_restore`-контроллер, 6 `SettingsSection` внутри одного State |
| `settings_storage_screen.dart` | 490 | 4 | подтверждения (`:80`), очистка (`:35-58`), тосты, две ветки web/native, сегментный прогресс-бар, легенда |
| `settings_language_region_screen.dart` | 299 | 5 | локал + таймзона + превью времени (`_LocalTimePreview`), пикер (`_TimeZonePicker`), `ListView.builder` в диалоге |
| `settings_about_screen.dart` | 389 | 2 | PackageInfo, changelog из `rootBundle`, сброс настроек, ссылки, bug-report |
| `settings_system_device_screen.dart` | 270 | 4 | сбор системных данных + 3 приватных вьюхи |

Общая картина: **логика в `State` экрана**, а `features/settings/application` (куда её и просили класть архитектурой) пустует.
Единственный «правильный» контроллер — `settings_anchor_controller` (43 строки), и тот про скролл, а не про данные.

---

## 7. Состояние

### 7.1. `ui_settings_provider.dart` (826 строк)

- 1 публичный класс состояния `UiSettingsState` (`:67`), **42 поля** (`:165-206`), `copyWith` c 42 параметрами и 2 флагами
  очистки (`:208-311`), `defaults()` дублирует все 42 значения (`:121-163`).
- **40 ключей** SharedPreferences (`:321-360`); не персистятся только `showPerformanceOverlay` и `debugRepaintRainbow`
  (сеттеры `:681-687` меняют только state).
- **42 сеттера** (`:532-767`) + `resetAll()` (`:772-820`), где вручную перечислены 40 `prefs.remove`.
- Персист: одиночные `_persistKey` + debounce 250 мс с картой ожидающих записей (`:507-530`), `flushPersist()` (`:530`).
- Загрузка: `build()` (`:461`) отдаёт `defaults()`, если кэш prefs пуст, иначе читает; `_load()` (`:471`) — фоном.
  Значит первый кадр **всегда** с дефолтной темой/локалью — источник мигания при холодном старте (не проверял визуально).
- Чтение целиком (`ref.watch(uiSettingsProvider)`): `profile_screen.dart:764`, `settings_chats_screen.dart:30`,
  `settings_energy_saving_screen.dart:21`, `settings_language_region_screen.dart:20`, `settings_preferences_screen.dart:72`,
  `connectivity_provider.dart:74`. Точечных `select` в `lib` — 40 вхождений.
- Гранулярность: поля принадлежат 7+ разным доменам (тема, звук, чаты, приватность, хранилище, движение, язык) — все в одном объекте,
  поэтому `select` спасает только от ребилда, но не от того, что любое изменение темы инвалидирует стейт для всех слушателей.

### 7.2. `settings_navigation_provider.dart` (46 строк)

`SettingsSectionId` (`:5`) — enum 13 разделов, `fromString` с фолбэком в `account` (`:20-26`); `DesktopSettingsSectionNotifier`
(`:29`) с web-хаком `systemDevice → about` (`:34-37`). Используется в 9 файлах, в том числе экранами
(`settings_account_screen.dart:73`) — то есть навигация хаба управляется из листового экрана.

### 7.3. Контроллеры `features/settings/application`

| Контроллер | Кто использует | Что делает |
|---|---|---|
| `settingsAnchorControllerProvider` (`:39`) | `settings_row.dart:4,45,83`, `settings_issue_card.dart:95`, `profile_screen.dart:359` | «прокрути к якорю и подсвети 1 с»; `request(route, anchor)` (`:25`), таймер сброса (`:28`) |
| `settingsHealthProvider` (`:7`) | `profile_screen.dart:439` (+ override в 2 тестах) | собирает `List<SettingsHealthIssue>` из `authProvider`, `storageSnapshotProvider`, `otaUpdateProvider` |
| `asyncSettingControllerProvider` (`:45`) | **никто** | обёртка «сохраняю/ошибка» поверх async-операции — не подключена ни к одному экрану |
| `SettingsResponsiveShell` | **никто** | альтернативная оболочка |

Т.е. заявленный «application-слой» существует на 1/3: контроллер мутаций не используется, а сами экраны зовут
`ref.read(uiSettingsProvider.notifier).setX()` напрямую (`settings_privacy_screen.dart:103` и десятки других).
Ошибок сохранения пользователь не видит нигде — механизм (`MutationFailed`) есть, но не подключён.

---

## 8. Нарушения правил AGENTS.md в коде настроек

Поиск по `lib/widgets/settings_ui.dart`, `lib/widgets/settings/**`, `lib/features/settings/**`, `lib/models/settings/**`,
`lib/services/settings/**`, `lib/screens/settings_*.dart`, `lib/screens/e2ee_settings_screen.dart`,
`lib/widgets/notifications/notification_settings_section.dart`, `lib/screens/profile_screen.dart`:

| Правило | Результат |
|---|---|
| `StateProvider` | 0 совпадений в коде настроек (единственные `*StateProvider` в `lib` — `secretProtectionStateProvider`, `widgets/chat/*`, это `Provider.family`) |
| `dart:io` | 0 |
| `withOpacity` | 0 (используется `withValues(alpha:)`, например `settings_list_item.dart:158`) |
| `Colors.white` / `Colors.black` | 0 (`Colors.transparent` в `settings_row.dart:127`, `pressable_surface.dart:95` — допустимо) |
| `PopupMenuButton` | 0 |
| прямой `CircularProgressIndicator`/`LinearProgressIndicator` | 0 (используется `AppLoadingIndicator`: `settings_list_item.dart:192`, `settings_storage_screen.dart:151`, `e2ee_settings_screen.dart:197`) |
| **L10n (`context.l10n`)** | **нарушено**: `settings_issue.dart:29-34,39-44,51-56,62-67`; `settings_issue_card.dart:85` (`'Скрыть'`); `settings_registry.dart:276` (`'Nios+ · NiosAI'`), `:512-513`, `:528-529`, `:546-548`, `:567-569` |
| Riverpod 3 / `NotifierProvider` | соблюдено (`ui_settings_provider.dart:823`, `settings_navigation_provider.dart:42`, `settings_anchor_controller.dart:39`) |

Отдельно: `settings_registry.dart:3` импортирует `flutter/material.dart` внутри сервиса (иконки + `kIsWeb`), а
`models/settings/settings_node.dart:108,132,158,178` хранит `valueSelector`/`onChanged`, принимающие `WidgetRef` —
презентационная зависимость внутри модели/сервиса. Формально не в списке запретов, но это то, что мешает вынести
каталог в чистый домен.

---

## 9. Целевая структура

### 9.1. Каталоги

```
lib/features/settings/
  domain/
    setting_id.dart            // единственный неймспейс id (anchor == id)
    setting_definition.dart    // sealed: Navigation | Toggle | Choice | Slider | Value | Action
    settings_catalog.dart      // секции → элементы; источник И для UI, И для поиска
    settings_issue.dart        // без хардкода строк: l10n-функции
  application/
    settings_state.dart        // 3-4 узких notifier'а по доменам, не 42 поля
    settings_search.dart       // читает catalog, не дублирует данные
    settings_health.dart
    settings_anchor.dart       // (переиспользуем существующий, сброс по факту скролла)
  presentation/
    widgets/
      settings_page.dart       // Scaffold + SliverAppBar + isEmbedded + onRefresh (замена SettingsShell)
      settings_group.dart      // SettingsGroupCard (бывший SettingsSection)
      settings_row.dart        // ОДИН ряд: control: SettingControl, anchor, pending, disabledReason, destructive
      settings_row_preview.dart// мини-превью значения (inline/stacked — явный параметр)
      settings_issue_card.dart
      settings_search_field.dart
    hub/
      settings_hub_page.dart   // хаб: каталог + профиль-карточка
      settings_profile_card.dart
    pages/
      account/, appearance/, privacy/, chats/, preferences/, language_region/,
      storage/, energy_saving/, device/, plus/, about/, e2ee/, sessions/
      <feature>_page.dart      // по одному файлу на раздел, ≤ 300 строк
  settings_routes.dart         // список роутов рядом с фичей, не в общем app_router
```

Правила новой структуры:
- `SettingsPage` — единственная оболочка; `isEmbedded` — единственный переключатель режима; никаких `SettingsScaffold`.
- `SettingsRow` — единственная строка; контрол задаётся union-типом, а не выбором между 3 классами.
- `SettingsGroupCard` — единственная группа; имя не конфликтует с «секцией хаба».
- Ни один `presentation/*` не импортирует `providers/ui_settings_provider.dart` напрямую — только свой application-контроллер.
- Каталог не содержит литералов строк и маршрутов, только `SettingId`, l10n-функции и `control`.

### 9.2. Порядок миграции (каждый шаг собирается и проходит тесты)

**Шаг 0. Заморозить поведение.** Ничего не менять; добавить (отдельным коммитом) тест-инвариант:
«для каждого `SettingsSearchResult.anchor` существует `SettingsAnchor` с таким id на целевом экране» — он сразу краснеет
на 4 фантомных якорях (§1.4) и держит следующие шаги.

**Шаг 1. Удалить чисто мёртвое** (0 импортёров, доказано §4): `settings_responsive_shell.dart`,
`setting_mutation_controller.dart`, `domain/settings_section.dart`, `domain/settings_destination.dart`.
Риск: нулевой, ни один файл не импортирует. Проверка: `flutter analyze`, `dart test`.

**Шаг 2. Убрать barrel `widgets/settings_ui.dart`.** Механически заменить 28 импортов на прямые
(`widgets/settings/settings_list_item.dart`, `settings_shell.dart`, `settings_choice_buttons.dart`, `pressable_surface.dart`,
`vector_illustrations.dart`) и перенести `SettingsSection` в `widgets/settings/settings_section.dart`.
`SettingsScaffold`/`SettingsNavBanner` удалить, переписав 4 теста (`settings_screens_m3_test.dart`, `settings_performance_phase4_test.dart`,
`settings_scroll_smoothness_test.dart`, `settings_desktop_restructure_test.dart`) на `SettingsShell`.
Шаг безопасен, потому что `SettingsScaffold` в проде не вызывается (0 вхождений вне тестов).

**Шаг 3. Свести легаси-обёртки к `SettingsListItem`.** `SettingsTile` → `SettingsListItem.nav`, `SettingsSwitchTile` → `.toggle`,
`SettingsInfoTile` → `.value` (это уже 1:1, см. `settings_ui.dart:276,313,348`). Затронуто 6 файлов, 13 вызовов — правки чисто механические.

**Шаг 4. Свести `SettingsRow` и `SettingsListItem` к одному API.** Выбрать `SettingsRow` (у него есть `pending`, `disabledReason`,
`anchor`, destructive) и сделать его единственным публичным; `SettingsListItem` — внутренний примитив. Переписать
`privacy` (17), `storage` (8), `account_security_section` (4), `energy` (1), `language` (1). Тесты хаба (`settings_refresh_test.dart:240`) идут вместе.

**Шаг 5. Вынести хаб из `ProfileScreen`.** Новый `SettingsHubPage` + `SettingsProfileCard`; `ProfileScreen` становится
тонкой страницей таба, которая рендерит хаб. `settings_hub_screen.dart` удалить, поправив 2 теста
(`niosgram_and_settings_e2ee_test.dart`, `settings_master_detail_test.dart`). На этом шаге 13 экранов всё ещё
подключаются switch'ем — переносим switch в `settings_routes.dart`/`settings_catalog`, не меняя экраны.

**Шаг 6. Один каталог.** Перенести содержимое `SettingsRegistry` (11 секций + 40 элементов) в `settings_catalog.dart`
на `SettingId`; поиск читает каталог; экраны берут `title/subtitle/icon/anchor` из каталога, а не из литералов.
Здесь же чинятся фантомные якоря и дубли id (3 соглашения → одно). Инвариант шага 0 становится зелёным.

**Шаг 7. Разбить `ui_settings_provider`.** Ввести `appearanceSettingsProvider`, `chatSettingsProvider`,
`privacySettingsProvider`, `notificationSettingsProvider`, `storageSettingsProvider`, `motionSettingsProvider`,
`languageSettingsProvider`; `uiSettingsProvider` оставить как `Provider`-агрегатор на время перехода (совместимость),
затем удалить. Заменить 6 «watch целиком» на точечные провайдеры.

**Шаг 8. Разбить монолиты.** `settings_appearance_screen.dart` 881 → 4-5 файлов (тема, палитра, геометрия, шрифт);
`ordinary_e2ee_settings.dart` 717 → контроллер + 3 секции-виджета; `settings_storage_screen.dart` → контроллер очистки + вью.
Логика уезжает в `application/`, где уже есть место (и где сейчас пусто).

**Шаг 9. Почистить домен и тесты.** Удалить `SettingsActionNode`/`badgeValue`, решить судьбу `account`/`system_device`
в каталоге (и обновить `test/unit/settings_registry_test.dart:17-19`), переименовать `SettingsSection` → `SettingsGroupCard`.

Порядок выбран так, что шаги 1-3 не меняют поведение вообще, шаг 4 меняет только реализацию строки (одинаковый UI),
шаги 5-6 меняют навигацию/поиск, шаги 7-8 — внутренности без изменения экранов, шаг 9 — уборка.

---

## 10. Не проверено

- **Не запускались** `flutter analyze`, `dart test`, `flutter test` — утверждения о «собирается/проходит» это план, а не факт.
  Не проверено, нет ли уже сейчас красных тестов.
- **Не проверено визуально**: мигание темы на холодном старте из-за `defaults()` в `build()` (`ui_settings_provider.dart:461-469`);
  реальный FPS-эффект от 6 «whole-state watch».
- **Не проверял** `test/features/settings/` — каталог существует, но пуст (чтение `test/features` показало 0 файлов);
  read/Get-Content по нему вернул `PermissionDenied`, содержимое не подтверждено.
- **Не проверял** содержимое `settings_plus_screen.dart`, `settings_about_screen.dart`, `settings_system_device_screen.dart`
  построчно (только классы, размеры и ключевые вызовы) — выводы о «монолитах» по этим файлам основаны на размере и списке методов.
- **Не проверял** `pressable_surface`/`m3_*` на соответствие motion-протоколу AGENTS.md (вне роли).
- **Не проверял** мёртвость `SettingsActionNode`/`badgeValue` в `test/` — поиск вёлся по `lib`; в тестах прямых обращений не искал.
- **Не проверял** остальные потребители `SettingsListItem` вне настроек (сессии, blocked users, диалоги профиля) на предмет
  последствий унификации строки — их 6+ файлов, оценка влияния не делалась.
- **Не проверял** `app_router.dart` целиком (~700 строк) — смотрел только блок `/settings*` и редиректы `/main/profile`.
