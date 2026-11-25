# 12. Визуальная согласованность настроек

Аудитор: визуальная согласованность. Дата: 22.11.2026.
Код: `pulse_flutter/lib`. Снимки: `docs/design-audit-2026-11-21/shots/` (40–44, 48 — настройки).
Только чтение кода; flutter/dart/git не запускались.

> **Важно про снимки.** Снимки настроек есть: `40_settings_hub_top.png`, `41_settings_hub_mid.png`, `42_settings_appearance.png`, `43_appearance_light.png`, `44_light_settings_hub.png`, `48_settings_language.png`. Они сделаны 21.11 в 14:14–14:18, а `settings_shell.dart`, `settings_appearance_screen.dart`, `settings_chats_screen.dart` правились 22.11 (mtime 10:36 / 11:41 / 11:56). Часть геометрии на снимках может быть старее кода; где это влияет на вывод — помечено.

---

## 1. Главные выводы

1. **Язык «одна карточка-группа с тихими внутренними углами» существует только в коде и почти не читается на экране.** `SettingsSection` даёт внешний радиус `clamp(24,32)` и внутренние 4, но фон группы — `surfaceContainerLow`: в светлой теме это `#EFEFEF` на `#F2F2F2` (контраст ≈1.03), в тёмной — `#212121` на `#1A1A1A` (≈1.08). На снимке `43_appearance_light.png` карточки групп практически не видны: читаются только розовые плитки иконок (`settings_ui.dart:224-226`, `app_surfaces.dart:32,40-42`).
2. **Хаб и внутренние экраны стоят на разных сетках: 16 против 20.** Хаб — `EdgeInsets.fromLTRB(16, 0, 16, 32)` (`profile_screen.dart:555`), внутренние экраны — `AppConstants.screenHorizontalPadding = 20` (`settings_shell.dart:61-63`, `app_constants.dart:6`). На снимках видно: карточки хаба начинаются на ~4–5 dp левее карточек «Оформления»/«Языка» (снимки 40 против 42/48). При переходе контент прыгает вправо.
3. **Заголовки секций исчезли там, где они нужнее всего.** В хабе 4 смысловые группы («Общение», «Персонализация», «Безопасность», «Приложение») существуют только в `Semantics(label:)` — визуальных заголовков нет (`profile_screen.dart:407-435`), а на экране «Аккаунт» обе группы без заголовков вообще (`settings_account_screen.dart:35,62`). При этом в остальных 11 экранах заголовки есть. Группировка в хабе невидима, отступ между группами равен отступу между секциями (20 dp).
4. **Название строки набрано «читальным» шрифтом, а не UI-шрифтом.** Строка настроек — `bodyLarge` (GolosText 16) с весом 500 (`settings_list_item.dart:260`), а строка чатов — `titleMedium` (Onest 16, w600) (`chat_tile.dart:646`). По конвенции проекта Onest — UI/labels/titles, GolosText — body/reading (`app_typography.dart:7-13`). Один и тот же по смыслу элемент в двух соседних экранах набран разными семействами.
5. **Токены почти не используются.** На ~20 файлов настроек приходится ровно **два** обращения к токенам: `AppRadii.of(context).lg` (`settings_ui.dart:179`) и `AppRadii.mdRadius` (`settings_list_item.dart:310`). `AppShape`, `AppHeights`, `AppSpacing` не встречаются ни разу. `expressive_tokens.dart` импортирован в 4 файлах из ~20 (`settings_ui.dart`, `settings_list_item.dart`, `pressable_surface.dart`, `settings_responsive_shell.dart`).
6. **Ползунок «Скругление интерфейса» врёт в настройках.** Пользователь двигает 8…28 dp (`settings_appearance_screen.dart:209-211`), но радиус группы — `AppRadii.of(context).lg.clamp(24.0, 32.0)` (`settings_ui.dart:179`). При любом значении ниже 24 группа остаётся 24: эффект виден только в верхних 4 шагах ползунка, остальные 16 шагов ничего не делают в настройках.
7. **Две реализации строки живут в одной группе.** `SettingsListItem` (16/12, minHeight 64, иконка 22 в слоте 40, подпись bodySmall 12) и `SwitchListTile`/`ListTile` (padding 16/6 из темы + свой 16/8, иконка 24 без слота, подпись bodyMedium 14) — в «Оформлении» они соседствуют внутри одной карточки (`settings_appearance_screen.dart:286-297` рядом с `330-334`, `856-861`). На снимке 42 видно расхождение отступа текста и размера подписи.
8. **Плитка иконки раздела есть только в хабе.** `isSection: true` используется лишь в хабе, поиске, сессиях и выборе бейджей (`profile_screen.dart:422,355`), внутренние экраны рисуют голый глиф. Переход «хаб → раздел» меняет обработку иконки с цветной плитки 40×40 r14 на серый контур 22 px — самый заметный визуальный разрыв между снимками 40 и 48.
9. **Хвост строки не имеет одной шкалы.** Шеврон 22 (`settings_list_item.dart:196-202`), копирование 20 (`settings_account_screen.dart:99`), копирование 18 (`settings_system_device_screen.dart:221-223`), «открыть» 24 (`about_identity_widgets.dart:58-61`), шеврон 24 (`about_update_tile.dart:96`). Плюс значение уезжает: при коротком значении без подписи оно встаёт справа (`settings_list_item.dart:169-174,209-229`), при длинном или при наличии подписи — третьей строкой слева (`278-291`). Одно и то же «значение» живёт в двух местах в зависимости от длины строки.
10. **Три масштаба заголовка страницы на трёх соседних экранах.** Хаб — `titleLarge` 22 w700 (`settings_profile_header.dart:181-186`), экран раздела — `headlineMedium` 28 w700 (`settings_shell.dart:90-96`), список чатов — `headlineSmall` 24 w600 (`chat_list_header.dart:120`). Это читается как три разных приложения, а не как одна семья.

---

## 2. Большая таблица параметров (экран в строке)

Сокращения: `SCL` = `surfaceContainerLow`, `SCH` = `surfaceContainerHigh`, `oSV` = `onSurfaceVariant`, `SC` = `secondaryContainer`.

| Экран | Шапка | Боковые поля | Фон | Группа: контейнер / цвет / радиус | Заголовок секции | Высота строки | Отступы в строке | Иконка: размер / подложка | Название / подпись | Разделители | Хвост |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Хаб** (`profile_screen.dart`) | кастомный `SliverPersistentHeader`: аватар 104→36, имя, «Редактировать», QR; expanded 178+details+20, collapsed clamp(64,104) | 16 (`:555`); desktop-мастер 14 (`:635`) | `scheme.surface` (`:538`) | да / SCL / 24 (из `settings_ui.dart:179,224`) | **нет** (`:407-435`, только Semantics) | 67 (1 строка) … 86 (подпись+значение) | 16 / 12; слот иконки 40; зазор 12 | 22 в плитке 40×40 r14 `primaryContainer` (`settings_list_item.dart:237-250`) | bodyLarge w500 / bodySmall 12 | зазор 2 dp, линий нет (`settings_ui.dart:215`) | значение + шеврон 22; поиск `SearchBar` SCH α0.6 (`:303-305`) |
| **Аккаунт** (`settings_account_screen.dart`) | `SliverAppBar.large`, 140 / clamp(64,104), headlineMedium 28 w700 | 20 | surface | да / SCL / 24 | **нет** для обеих групп (`:35,62`) | 67 | 16 / 12 | 22, без подложки | bodyLarge w500 / bodySmall | 2 dp | копировать 20 (`:99`) |
| **Приватность** (`settings_privacy_screen.dart`) | тот же shell | 20 | surface | да / SCL / 24 | labelLarge w600 oSV (`settings_ui.dart:191-200`) — 5 секций | 67 | 16 / 12 | 22; цвет по категории: primary / secondary / tertiary / error (`:69,161,236,275`) | bodyLarge w500 / bodySmall | 2 dp | шеврон 22 / значение inline / Switch |
| **Оформление** (`settings_appearance_screen.dart`) | shell + локальный `AnimatedTheme` (`:99-106`) | 20 | surface (подменяется темой-превью) | да / SCL / 24; внутри 3 блока | labelLarge + bodySmall подзаголовок | 72 (`SwitchListTile`, `:286-297`) / 67 / блоки | 16 / 8 у switch; 16 / 12 у строк; чипы `all(16)` (`:692`) | 24 без подложки (ListTile, `:291); 22 (строки); круг d48–72 (`:389`); бейдж-галочка r12 (`:626`) | titleMedium (ListTile) / bodyMedium 14 подпись; кружки — labelMedium 12 | 2 dp | Switch; чипы-pill; точки-пагинатор 8→20×8 (`:443-449`); Slider `trackHeight: 16` (`:778`) |
| **Чаты и звонки** (`settings_chats_screen.dart`) | shell | 20 | surface | да / SCL / 24; 3 секции | labelLarge + bodySmall | 67 / блок чипов | 16 / 12; чипы `all(16)` (`:59`) | 22; чипы без иконок | bodyLarge / bodySmall; эмодзи `fontSize: 24` (`:72` — магическое число) | 2 dp | Switch; шеврон |
| **Уведомления** (`settings_preferences_screen.dart` + `notification_settings_section.dart`) | shell | 20 | surface | да / SCL / 24 | labelLarge; **внутри карточки свой «хедер»**: Row icon 24 + titleSmall + bodySmall, padding 20/16/20/8 (`:83-117`) | 67; хедер ~72; слайдер-блок | 16 / 12; хедер 20; слайдер 16/16/16/8 (`preferences:107`) | 22; у хедера 24 без слота (`:88-93`) | bodyLarge / bodySmall; хедер titleSmall | 2 dp | Switch; Slider; строка «тест звука» с `AppLoadingIndicator` |
| **Язык и время** (`settings_language_region_screen.dart`) | shell | 20 | surface | да / SCL / 24; 3 секции | labelLarge + bodySmall | 67 / блоки чипов | 16 / 12; чипы `all(16)` (`:34,64`) | 22 (часы, глобус); чипы 18 | bodyLarge / bodySmall | 2 dp | чипы-pill; значение (UTC+05:00); шеврон |
| **Данные и память** (`settings_storage_screen.dart`) | shell + `onRefresh` | 20 | surface | да / SCL / 24 + **hero вне групп** | labelLarge; **одна секция без title, только subtitle** (`:281-282`) | 67 | 16 / 12; hero padding `all(18)` (`:201`) | 22; часть иконок `scheme.primary` (`:329,344`) | bodyLarge w500 / bodySmall; hero — headlineMedium w800 ls-0.6 (`:212-217`) | 2 dp | значение; кнопка-обновление `IconButton.filledTonal` SC (`:228-236`); прогресс 10 dp r6 (`:419-433`) |
| **Анимации и энергосбережение** (`settings_energy_saving_screen.dart`) | shell | 20 | surface | да / SCL / 24; 3 секции | labelLarge + bodySmall | 67 / блок | 16 / 12; блок `fromLTRB(16,12,16,14)` (**14 — не кратно 4**, `:82`) | 22; чипы-иконки 18 (`:93-105`) | bodyLarge / bodySmall; пояснение bodyMedium h1.35 (`:135-139`) | 2 dp | Switch; чипы; `TextButton` padding 10/6 min 48 (`:148-155`) |
| **Система и устройство** (`settings_system_device_screen.dart`) | shell; **hero-блок**: `secondaryContainer` r24 + padding 20 + headlineSmall + bodyMedium (`:71-104`) | 20 (hero — 12, `:72`) | surface | да / SCL / 24; 2 секции | labelLarge + bodySmall | 67 / `SystemResourceMeter` ~130 | 16 / 12; meter padding 16 + зазоры 10/12/8 (`system_resource_meter.dart:44,55,60,94`) | 22; icon 36 в hero (`:262`) | bodyLarge / bodySmall; meter — titleSmall + bodyMedium w600 + bodySmall | 2 dp | копировать 18 (`:221-223`) |
| **Nios+** (`settings_plus_screen.dart`) | shell + свой `leading` back (`:183-189`) | 20 | surface | 1 секция **без заголовка** (`:191`), карточка покупок `all(16)` (`:217-218`), секция «Преимущества» | labelLarge (только у преимуществ) | 67 / блоки | 16 / 12 | 22 | bodyLarge / bodySmall | 2 dp | значение «Nios+»; `FilledButton` **вне карточки** (`:272-283`) |
| **О приложении** (`settings_about_screen.dart`) | shell | 20 | surface | hero без группы (`16,8,16,24`, `:117-118`); 3 секции; changelog `all(20)` (`:294`) | labelLarge + bodySmall | 67 / блоки | 16 / 12 | 22; бренд 72 (`:121-127`); версия-чип 18 (`about_identity_widgets.dart:27`) | bodyLarge / bodySmall; hero headlineSmall w700; changelog titleMedium w700 + labelMedium primary | 2 dp | чипы-табы **вне карточки** (`:153-165`); шеврон; `open_in_new` 24 |
| **E2EE** (`e2ee_settings_screen.dart` + `ordinary_e2ee_settings.dart`) | shell | 20 | surface | да / SCL / 24; много секций | labelLarge + bodySmall; часть текста блоками | 67 / блоки | 16 / 12; блоки `fromLTRB(16,12,16,12)` (`:247`), `fromLTRB(16,4,16,12)` (ordinary `:316`) | 22 | bodyLarge / bodySmall; **ошибка — `TextStyle(fontSize: 13)`** (`:224`); `SelectableText` без стиля (`:216`) | 2 dp | действие / danger |
| **Обои** (`settings_wallpaper_screen.dart` → `wallpaper_studio_screen.dart`) | **свой `AppBar`** (не large), свои табы и превью | 16 / 24 | surface | нет групп настроек | нет | — | превью-панель 16/4/16/8 (`:295`) | — | — | — | `PopupMenuButton` с **русскими строками в коде** (`:232,236`) |

**Сколько разных значений живёт в разделе**

| Параметр | Разных значений | Значения |
|---|---|---|
| Радиус поверхности | **11 + pill** | 4 (внутр. угол строки), 6 (прогресс), 8 (meter, точки), 12 (fallback строки, кнопка карточки, бейдж), 14 (плитка иконки, аватар команды), 16 (баннер, подсветка, пикер), 20 (карточка проблемы, пикер), 24 (группа, hero устройства, тап-зона точки), 26 (hero хранилища), 28 (пикер, превью обоев), pill (чипы, поиск). Из них 6/14/20/24/26 **отсутствуют в шкале `AppRadii`** (4/8/12/16/28/999, `expressive_tokens.dart:6-26`) |
| Высота строки | 5 | 64 (min) / 67 (с подписью) / 72 (`ListTile`) / 86 (подпись + значение) / ~130 (`SystemResourceMeter`); для сравнения чат — 76 (`chat_tile.dart:85`) |
| Боковое поле экрана | 5 | 14 (desktop-мастер), 16 (хаб, embedded-narrow, обои), 20 (телефон, shell), 24 (обои desktop), 28 (wide shell) |
| Стиль заголовка секции | 6 | labelLarge+bodySmall (SettingsSection); «хедер» в карточке уведомлений (titleSmall, padding 20); hero хранилища (headlineMedium w800); hero устройства (headlineSmall); hero «О приложении» (headlineSmall); чипы-табы «О приложении» (без заголовка) |
| Заголовок страницы | 3 | 22 (хаб) / 24 (чаты) / 28 (shell) |
| Размер хвостового глифа | 4 | 18 / 20 / 22 / 24 |
| Подложка иконки | 5 | нет (22); плитка 40 r14 SCL→`primaryContainer`; баннер 48 r16 `primary @14%` (мёртвый код); круг с бордюром (палитра); hero r24 `secondaryContainer` |
| Шрифтовая роль названия строки | 4 | bodyLarge w500 (строка), bodyLarge w400 (`ListTile`), titleMedium w600 (чаты), titleSmall (хедер/meter) |
| Паддинг внутри карточки | 7 | 16/12; 16/8; 16/0/16/8; 16/12/16/14; 12/16/12/0; 18; 20 |

Высоты 67 и 86 — расчёт по метрикам: 12 + 24 (title bodyLarge) + 3 + 16 (bodySmall) + 12; для варианта с подписью и значением добавляются ещё 3 + 16. Сама строка задаёт только `minHeight: 64` (`settings_list_item.dart:230-233`), поэтому фактическая высота зависит от текста. «~130» у `SystemResourceMeter` — оценка по зазорам 16 + 22 + 10 + 20 + 12 + 8 + 16.

---

## 3. Находки

P0 нет: ни одна проблема не ломает отрисовку, всё — качество языка.

| # | P | Место | Что не так | Предложение |
|---|---|---|---|---|
| 1 | **P1** | `app_surfaces.dart:32,40-42` + `settings_ui.dart:224-226` | Контраст группы к фону 1.03 (светлая) и 1.08 (тёмная): карточки не видны, разделение держится только на иконках. Нарушает собственное правило файла «шаги по ≥3 L\*» (`app_surfaces.dart:5-19`) | Группа = `scheme.surfaceContainer` (1.12 / 1.21) или поднять `surfaceContainerLow`; вложенные блоки — на шаг выше. Проверить на реальном устройстве |
| 2 | **P1** | `profile_screen.dart:555` vs `settings_shell.dart:61-63` + `app_constants.dart:6` | Поле хаба 16, поле раздела 20 → контент сдвигается при каждом переходе (видно на 40 vs 42/48) | Одно поле: 16 на компакте (как в хабе и в чатах), 28 на wide; вынести в `AppSpacing.lg` |
| 3 | **P1** | `settings_list_item.dart:258-266` | Название строки — `bodyLarge` (GolosText) вместо `titleMedium` (Onest): нарушает роли шрифтов и расходится с переделанным списком чатов (`chat_tile.dart:646`) | `titleMedium` + `fontWeight w600` (как в чатах); для выбранной строки w700 |
| 4 | **P1** | `settings_ui.dart:179` | `clamp(24,32)` игнорирует пользовательский радиус 8…24 — ползунок «Скругление интерфейса» ложно обещает эффект | Ввести токен `AppRadii.group = 24` и показывать ползунок честно, либо не клампить снизу (радиус группы = `AppRadii.lg` + 4) |
| 5 | **P1** | `profile_screen.dart:407-435`, `settings_account_screen.dart:35,62` | 4 группы хаба и 2 группы аккаунта не имеют видимых заголовков — группировка не читается, отступы между группами равны отступам между секциями | Добавить видимые заголовки секций (labelLarge, oSV) во все группы; убрать `Semantics`-костыль |
| 6 | **P1** | `settings_appearance_screen.dart:286-297,330-334,854-861` | `SwitchListTile` и `ListTile` внутри `SettingsSection`: иконка 24 без слота, подпись bodyMedium 14, высота 72 — рядом со строками 22/bodySmall/67 | Перевести на `SettingsListItem`: переключатель — `toggle`-строка, «Характер палитры» — строка с заголовком секции вместо `ListTile` |
| 7 | **P1** | `settings_list_item.dart:169-174,209-229,278-291` | Значение уезжает вправо при длине ≤18 и без подписи, иначе — третьей строкой слева; ломается вертикальное выравнивание значений в столбце | Всегда одно место: значение справа (`bodySmall`/`bodyMedium`, maxWidth 96, ellipsis); длинный текст — `subtitle`, не `value` |
| 8 | **P2** | `settings_list_item.dart:196-202`, `settings_account_screen.dart:99`, `settings_system_device_screen.dart:221-223`, `about_identity_widgets.dart:58-61`, `about_update_tile.dart:96` | Хвостовые глифы 18/20/22/24 | Шеврон 22, служебные иконки 20, всё из одного `AppHeights`/`iconSize` токена |
| 9 | **P2** | `settings_privacy_screen.dart:69,161,236,275` vs `settings_storage_screen.dart:329,344` vs `settings_list_item.dart:163-164` vs `settings_list_item.dart:239-248` | Четыре конвенции цвета иконки: 4 роли по категориям (privacy), всё `primary` (storage), `onSurfaceVariant` по умолчанию, плитка `primaryContainer` (хаб) | Одна база — `onSurfaceVariant`; акцент раздела — только плиткой в хабе. Цветовое кодирование категорий privacy либо задокументировать, либо снять (при динамическом цвете 4 роли схлопываются в похожие оттенки) |
| 10 | **P2** | `settings_storage_screen.dart:281-282` | Секция с `subtitle` без `title` → над группой висит одинокая серая строка 12 px | Заголовок обязателен, если есть subtitle (или subtitle уходит внутрь первой строки) |
| 11 | **P2** | `settings_storage_screen.dart:196-201` | Hero: `BorderRadius.circular(26)`, `EdgeInsets.all(18)` — оба числа вне шкал | r24 (радиус группы) + `AppSpacing.lg` (16) или 20; в hero допустим `AppRadii.xl` = 28, но не 26 |
| 12 | **P2** | `settings_issue_card.dart:43,46,51,100-103` | Карточка проблемы лежит внутри `SliverPadding(16)` и добавляет свой `margin: horizontal 16` → двойной отступ 32; r20 вне шкалы; кнопка `Size(100,36)` r12 | Убрать margin (родитель уже даёт поле), r24 как у групп, кнопка minHeight `AppHeights.control` 40 |
| 13 | **P2** | `settings_shell.dart:90-96` | В `SliverAppBar.large` передан явный `headlineMedium w700 ls-0.5`, который перекрывает авто-масштаб M3 → свёрнутый заголовок рисуется тем же 28 px (риск, визуально не проверено, см. §5) | Задать `expandedTitleTextStyle`/`collapsedTitleTextStyle` явно: 28 → 22 |
| 14 | **P2** | `settings_profile_header.dart:181-186` vs `settings_shell.dart:92` vs `chat_list_header.dart:120` | Три масштаба заголовка страницы: 22 / 28 / 24 | Один: 28 для страниц-настроек и хаба (хаб поднять с 22), чаты поднять с 24 в том же проходе — иначе семья читается как два приложения |
| 15 | **P2** | `settings_ui.dart:16-72,74-156`, `features/settings/presentation/settings_responsive_shell.dart:14-104` | Мёртвые оболочки: `SettingsScaffold` (адаптивные колонки 840/20) и `SettingsResponsiveShell` нигде не используются, но тянут свои стили: w800/w700, padding 28/16, дефолтный `titleLarge`; `SettingsNavBanner` не используется вовсе | Удалить или свести к `SettingsShell`; иначе следующий разработчик возьмёт «третью правду» |
| 16 | **P2** | `settings_ui.dart:177`, `settings_list_item.dart:142-143` | `SettingsSection` молча выбрасывает `Divider` из детей, `dividerIndent = 68` не используется нигде → разделителей в разделе нет вообще, а API обещает | Либо вернуть реальные `Divider` (1 dp, `outlineVariant α0.22`, inset 68), либо убрать и параметр, и константу |
| 17 | **P2** | `settings_ui.dart:214-223` | Гибрид «2 dp зазора + внутренние углы 4 + внешние 24» — не связанная карточка (нет линий) и не отдельные карточки (углы глушатся). В списке чатов язык другой: отдельные карточки r20 с зазором 2 (`chat_tile.dart:235,377-380`) | Выбрать одно: (а) строки встык + hairline `Divider` inset 68; (б) отдельные строки r20 с зазором 2 — как в чатах. Сейчас — ни то ни другое |
| 18 | **P2** | `settings_storage_screen.dart:419-433` vs `system_resource_meter.dart:69-87` | Два стиля полосы прогресса: 10 dp r6 и 8 dp r8 | Один компонент (высота 8, r8, трек `surfaceContainerHighest`) |
| 19 | **P2** | `settings_appearance_screen.dart:776-778` | `trackHeight: 16` у `Slider` — в 2–4 раза толще M3-нормы и толще любого другого индикатора в разделе | Токен высоты трека (8 dp) или обосновать expressive-стиль и применить ко всем слайдерам |
| 20 | **P2** | `settings_about_screen.dart:153-165` | Чипы-табы лежат прямо на фоне, без карточки и без паддинга, тогда как все остальные чипы в разделе — внутри карточки с `all(16)` | Обернуть в группу или задать тот же боковой паддинг 16 |
| 21 | **P2** | `settings_preferences_screen.dart:106-133` | Слайдер громкости — блок внутри карточки: `labelLarge`-метка + Slider без обёртки `SettingsListItem`; вертикальный ритм отличается от строк | Оформить как строку со значением + слайдер-слот под ней (как `_FontScaleSliderTile`, `appearance:806-833`) |
| 22 | **P3** | `e2ee_settings_screen.dart:219-226` | Ошибка: `TextStyle(color: scheme.error, fontSize: 13)` — не из `textTheme`, 13 вне шкалы | `textTheme.bodySmall.copyWith(color: scheme.error)` |
| 23 | **P3** | `settings_chats_screen.dart:72`, `settings_energy_saving_screen.dart:93-105,148-155` | `fontSize: 24` в эмодзи-чипе, иконки чипов 18, `TextButton` padding 10/6 | Через `textTheme`/`AppHeights`: иконка чипа 18 — норм, но вынести в токен; эмодзи — 20 или 24 осознанно |
| 24 | **P3** | `profile_screen.dart:303-307` | `SearchBar` переопределяет тему: `SCH α0.6` и padding 14, хотя `searchBarTheme` уже задаёт `SCH` и 14 (`app_theme.dart:142-152`) | Убрать inline-переопределение, оставить тему |
| 25 | **P3** | `settings_issue_card.dart:85` | `tooltip: 'Скрыть'` — жёсткая русская строка | Через l10n (заодно снимется рассинхрон с EN) |
| 26 | **P3** | `wallpaper_studio_screen.dart:232,236,245-307` | Экран обоев живёт отдельным языком: обычный `AppBar`, превью r28/r20, `PopupMenuButton` (запрещён AGENTS) с русскими строками | Наследовать `SettingsShell` и радиусы группы, либо явно задокументировать как «студия», а строки — в l10n |
| 27 | **P3** | `settings_system_device_screen.dart:72-81` | Hero-блок с полем 12 против 20 у остального контента экрана → блок шире строк | Поле 20, как у контента |
| 28 | **P3** | `settings_row.dart:120-131` | Подсветка «якоря» поиска — r16 поверх строки с внутренним r4 | Радиус подсветки = радиус строки (4 внутри / 24 по краю группы) |

---

## 4. Единая визуальная спецификация

### 4.1 Экран

| Параметр | Значение | Токен |
|---|---|---|
| Фон | `colorScheme.surface` | — |
| Поле по бокам | 16 (компакт) / 28 (≥840 dp) | `AppSpacing.lg` / новое `AppSpacing.screenWide` |
| Верх контента | 4 под app bar, 12 в embedded | `AppSpacing.xs/md` |
| Низ контента | 32 | `AppSpacing.xxl` |
| Max width | 860 | — |
| Заголовок страницы | `headlineMedium` 28, w700, ls −0.5, Bricolage; свёрнутый — `titleLarge` 22 | `textTheme.headlineMedium` |
| App bar | `SliverAppBar.large`, expanded 140 + масштаб текста, toolbar clamp(64…104), `scrolledUnderElevation: 0`, фон `surface` | `AppHeights.appBar` |
| Группы между собой | 24 (сейчас 20) | `AppSpacing.xl` |

### 4.2 Группа (секция)

| Параметр | Значение |
|---|---|
| Фон | `scheme.surfaceContainer` (поднять контраст до ≥1.10 в обеих темах) |
| Радиус | **24**, `BorderRadius.vertical` с внутренними **0** (строки встык) либо отдельные карточки r20 — выбрать один вариант; текущий гибрид 24/4 не использовать |
| Заголовок | `labelLarge` 14 w600, `onSurfaceVariant`; паддинг `16, 0, 12, 8` |
| Подзаголовок секции | `bodySmall` 12, `onSurfaceVariant`, gap 4 под заголовком; **без заголовка не показывать** |
| Паддинг группы | 0 (строки дают свой) |
| Разделитель | если строки встык — `Divider` 1 dp, `outlineVariant α0.22`, inset 68 (`AppSpacing.lg` + слот 40 + gap 12); если отдельные карточки — зазор 2 |
| Низ до следующей группы | 20, между заголовком и группой — 0 |

### 4.3 Строка (все варианты)

| Параметр | Значение |
|---|---|
| Мин. высота | 64 (`AppHeights.xl`), при подписи — авто (≈68–72) |
| Паддинг | 16 по горизонтали, 12 по вертикали |
| Слот иконки | 40×40; глиф **22**; подложка — только в хабе: 40×40, r14, `primaryContainer` / `onPrimaryContainer` |
| Зазор иконка → текст | 12 |
| Название | `titleMedium` 16 **Onest** w600, `onSurface`; выбранная — w700 + `secondaryContainer` |
| Подпись | `bodyMedium` 14, `onSurfaceVariant`, maxLines 2, gap 4 |
| Значение | всегда справа, `bodyMedium` w500, `onSurfaceVariant`, maxWidth 96, 1 строка + ellipsis |
| Зазор текст → хвост | 12 |
| Хвост: навигация | шеврон 22, `onSurfaceVariant` |
| Хвост: переключатель | стандартный M3 `Switch` из `switchTheme` |
| Хвост: значение | см. «Значение» (без шеврона, если тап не ведёт дальше) |
| Хвост: действие | иконка 20 (`onSurfaceVariant`), либо `IconButton` для отдельного тапа |
| Хвост: опасное | текст `scheme.error`, иконка `scheme.error`, фон не меняется |
| Хвост: загрузка | `AppLoadingIndicator(size: 24)` в квадрате 48 |
| Нажатие | `PressableSurface`: scale 0.98, `M3SpringCurves.expressiveStandard`, `M3Durations.short4` (как сейчас, `pressable_surface.dart:87-91,139`) |
| Фокус | кольцо `primary` 2 dp по радиусу строки |
| Выключенная | `onSurface` α0.38 (как сейчас, `settings_list_item.dart:158`) |

### 4.4 Прочее

| Элемент | Значение |
|---|---|
| Чипы (выбор) | pill, фон `surfaceContainerLow`, выбранный `secondaryContainer`, подпись `onSecondaryContainer` (сейчас `onSurface` — риск контраста, `app_theme.dart:123-133`), паддинг блока 16, зазор 8 |
| Слайдер | трек 8 (`surfaceContainerHighest`), активный `primary`, отступ блока 16/0/16/16 |
| Индикатор объёма | высота 8, r8, трек `surfaceContainerHighest`, сегменты `primary` / `tertiary` / `secondary` |
| Hero-блоки (хранилище, устройство, о приложении) | допустимы, но: радиус 24 или 28 (`AppRadii.xl`), паддинг 20, фон `surfaceContainer` / `secondaryContainer`, заголовок `headlineSmall` w700 |
| Иконки в строках | база `onSurfaceVariant`; акцент — только плиткой хаба |
| Заголовки внутри карточки | не изобретать: либо строка, либо заголовок секции |
| Мёртвые оболочки | удалить `SettingsScaffold`, `SettingsResponsiveShell`, `SettingsNavBanner`, `dividerIndent`, параметр `isCard` |

---

## 5. Не проверено

- **Рендеринг не запускался** (flutter/dart запрещены): все выводы — по коду и статичным снимкам.
- **Снимки старше правок.** 40–44, 48 сделаны 21.11 14:14–14:18; `settings_shell.dart` (22.11 10:36), `settings_appearance_screen.dart` (11:41), `settings_chats_screen.dart` (11:56) изменены позже. Точное соответствие текущего кода и снимков по отступам/заголовкам — **не проверено**; расхождение 16 vs 20 подтверждается кодом, но конкретные пиксели снимков могут быть от прежней версии.
- **Тёмная тема и плитки иконок.** На снимке 40 плитки насыщенно-маджентовые, в текущем коде — `primaryContainer` (`settings_list_item.dart:239-248`), который в тёмной M3-теме тёмный. Как это выглядит сегодня — **не проверено** (снимок, вероятно, от другой реализации).
- **Динамический цвет** (обои устройства) визуально не проверялся; по коду он влияет только на акценты (`AppSurfaces.neutralize` глушит только лестницу поверхностей, `app_surfaces.dart:29-61`). Схлопывание 4 ролей privacy в похожие оттенки — предположение.
- **Контрасты** посчитаны вручную по значениям `AppSurfaces` (1.03 / 1.08 / 1.12 / 1.21), инструментом не измерялись.
- **Свёрнутый заголовок `SliverAppBar.large`** с явным `style` (`settings_shell.dart:90-96`): поведение авто-масштаба M3 не проверено на устройстве.
- **Масштаб текста 1.0–2.0, RTL, планшет/desktop 2-панельный режим, web** — только по коду (`profile_screen.dart:603-674`), визуально не проверялись.
- **Нет снимков** для: приватности, хранилища, Nios+, «О приложении», анимаций, «Системы», E2EE, уведомлений, аккаунта, обоев. Их таблица собрана только по коду.
- **Не покрыты аудитом:** `sessions_screen.dart` (раздел настроек, вне списка роли), `badge_picker_sheet.dart`, `ordinary_e2ee_settings.dart` (просмотрен точечно — только визуальные параметры), `custom_color_picker_sheet.dart` (только список радиусов), `ai_usage_card.dart`, `plus_purchase_options.dart`.
- **Порядок и содержание снимков** 41 (середина хаба) не сверялся с текущим порядком секций реестра.
