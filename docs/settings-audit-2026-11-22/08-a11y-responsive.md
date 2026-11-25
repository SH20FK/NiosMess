# 08. Доступность и адаптивность «Настроек»

Аудит только по чтению кода. `flutter`, `dart`, `git` не запускались. Всё, что требует устройства/скринридера, помечено «не проверено».
Все утверждения — со ссылками `путь:строка`. Код, тесты и arb не изменялись.

Охвачено: `lib/screens/settings/*.dart`, `lib/screens/settings_*.dart`, `lib/screens/e2ee_settings_screen.dart`, `lib/widgets/settings_ui.dart`, `lib/widgets/settings/*.dart`, `lib/features/settings/presentation/*.dart`, `lib/widgets/notifications/notification_settings_section.dart`, плюс точки входа — хаб `lib/screens/profile_screen.dart` и `lib/main.dart` (глобальный `AppTextScaler`).

---

## 1. Главные выводы

1. **Базовый каркас хороший, единая строка — нет.** Каркас (`SettingsShell`) масштабирует заголовок под крупный шрифт (`settings_shell.dart:84-89`), рисует фокусную рамку 2 dp (`pressable_surface.dart:99-107`), поддерживает Enter/Space (`pressable_surface.dart:120-123`) и уважает «уменьшение движения» (`pressable_surface.dart:87-91`). Но сама строка `SettingsListItem` **не объявляет себя одним элементом**: `Semantics(button, enabled, selected)` без `label`, без `excludeSemantics` и **без `onTap`** (`settings_list_item.dart:300-314`). `MergeSemantics` применяется только к переключателям (`:317`). Эталон в проекте уже есть — `chat_tile.dart:290-304` (единая метка + `excludeSemantics` + `onTap`/`onLongPress`).
2. **Активация строки скринридером висит на вложенном `GestureDetector`.** Действие приходит только из `PressableSurface` (`pressable_surface.dart:132-140`), у которого `excludeFromSemantics` не выставлен. Правильный паттерн — действия в `Semantics` строки (как `chat_tile.dart:299-300`). Это главный риск: «двойное касание не срабатывает» / «кнопка объявляется пустой». Требует проверки на устройстве.
3. **Нижний системный inset не учитывается.** `SettingsShell` — `Scaffold` без `SafeArea`, содержимое имеет фиксированный `bottom: 32` (`settings_shell.dart:65-71`, `:176-185`). На iOS домашний индикатор = 34 dp, в альбомной ориентации на телефоне с вырезом не учитываются боковые `padding.left/right`.
4. **Касания ≥ 48 dp почти везде выдержаны.** Проверено: строка `minHeight 64` (`settings_list_item.dart:231`), точки пагинации 48×48 (`settings_appearance_screen.dart:434-436`), образцы цвета 48–72 (`:389`), кнопка «версия» `Size(48,48)` (`about_identity_widgets.dart:29`), энергосбережение `Size(48,48)` (`settings_energy_saving_screen.dart:153`), аватар `hitSize.clamp(48,104)` (`settings_profile_header.dart:150`). Исключение — кнопка в карточке проблемы: `Size(100, 36)` (`settings_issue_card.dart:100-103`).
5. **Крупный шрифт обрабатывается осознанно, но точечно.** Есть условное скрытие значения в строке при масштабе > ~128 % (`settings_list_item.dart:169-174`), расчёт высоты полосы палитры от `textScaler` (`settings_appearance_screen.dart:384-394`), рост `expandedHeight` у `SliverAppBar` (`settings_shell.dart:86-89`), перенос чипов в `Wrap` (`settings_choice_buttons.dart:19-36`). Остаются жёсткие ширины/высоты: `maxWidth: 88` у значения (`settings_list_item.dart:213-224`), `math.min(600, …)` у шторки часовых поясов (`settings_language_region_screen.dart:223-224`), строка легенды хранилища без `Flexible` (`settings_storage_screen.dart:471-488`).
6. **Контраст в основном тональный, но есть «серое на сером» и сырые цвета.** Отключённый текст — `onSurface` с alpha 0.38 (`settings_list_item.dart:158`), подложки карточек проблем — `errorContainer`/`tertiaryContainer` с alpha 0.35 (`settings_issue_card.dart:29-35`), палитра — 8 констант `Color(0xFF…)` (`settings_appearance_screen.dart:34-43`). Сырые `Colors.white` в настройках не найдены; `Colors.transparent` — только как отсутствие фона (`pressable_surface.dart:95`).
7. **Правая-на-лево письменность не поддерживается по факту, но код не направленный.** Приложение объявляет только `en`/`ru` (`l10n/app_localizations.dart:96-99`), поэтому RTL сегодня не ломает UI. При этом в компонентах зашито физическое направление: `Positioned(left:/right:)`, `Alignment.centerLeft` (`settings_profile_header.dart:165,180,192,201,238,250`), `Alignment.centerLeft/Right` (`settings_energy_saving_screen.dart:146`, `settings_issue_card.dart:91`). Иконки-стрелки не зеркалируются: шеврон `chevron_right_rounded` (`settings_list_item.dart:196-202`).
8. **Клавиатура: строки доступны, переключатели — только через сам `Switch`.** `keyboardFocusable: !toggle` (`settings_list_item.dart:309`) означает, что вся площадь строки-переключателя для Tab недоступна, фокус попадает на маленький `Switch` без рамки строки. Фокус-рамка, Enter/Space есть (`pressable_surface.dart:99-131`), Escape обрабатывается только Material-модалками (`m3_modal_route.dart:20-32`).
9. **Результаты действий скринридеру почти не сообщаются.** Единственный `liveRegion` в настройках — текст ошибки в E2EE (`ordinary_e2ee_settings.dart:262-270`). Всё остальное — тосты (`AppToast.showSuccess/Error`), и `SemanticsService.announce` в проекте не используется нигде (grep по `lib`: 0 совпадений). Индикаторы загрузки `AppLoadingIndicator` не имеют семантики вообще (`pulse_loading_indicator.dart:30-63`) — «идёт загрузка» не озвучивается.
10. **Лучшие практики уже есть и их надо переиспользовать, а не изобретать.** Образец палитры (`settings_appearance_screen.dart:543-548`), диаграмма хранилища (`settings_storage_screen.dart:247-257`), QR-код (`ordinary_e2ee_settings.dart:507-523`), профиль-заголовок (`settings_profile_header.dart:170-190, 243-263`), `chat_tile.dart`. Проблема не в отсутствии знаний, а в том, что доступность живёт на каждом экране отдельно.

---

## 2. Таблица находок

Severity: **P0** — блокирует использование, **P1** — серьёзно мешает, **P2** — заметно, **P3** — полировка.

| ID | P | Место | Что не так | Что предлагаю |
|---|---|---|---|---|
| A-01 | P1 | `widgets/settings/settings_list_item.dart:300-317` | Outer `Semantics` без `label`, `excludeSemantics` и `onTap`/`onLongPress`; объединение только для `toggle`. Название/подзаголовок/значение идут отдельными узлами, действие — из вложенного `GestureDetector` | Собрать одну метку (title · subtitle · value · состояние) и положить `onTap`/`onLongPress` в `Semantics`, как `chat_tile.dart:290-304`. Если подтвердится на устройстве — P0 |
| A-02 | P1 | `widgets/settings/settings_shell.dart:65-71,176-185` | Нет `SafeArea`; `bottom: 32` фиксирован; боковые inset в альбомной ориентации не учитываются | `SafeArea(top: false)` вокруг скролла + `bottom: max(32, MediaQuery.paddingOf(context).bottom + 16)` |
| A-03 | P1 | `widgets/settings/custom_color_picker_sheet.dart:208-292` | Плоскость насыщенности/яркости: `GestureDetector` без `onIncrease`/`onDecrease`, не фокусируется, недоступна с клавиатуры. SR только читает значение | Добавить `Semantics(increase/decrease, value)` + `FocusableActionDetector` со стрелками; либо убрать плоскость из обязательного пути выбора (пресеты + hue-слайдер) |
| A-04 | P2 | `screens/settings_language_region_screen.dart:90-102` | Значение («UTC+03:00») стоит в `title`, а «Автоматически» — в `subtitle`; SR читает значение как имя настройки | `title` = «Часовой пояс», `value` = текущая зона |
| A-05 | P2 | `features/settings/presentation/settings_issue_card.dart:85` | `tooltip: 'Скрыть'` — жёсткая русская строка в EN-интерфейсе | Ключ l10n, как у остальных подписей |
| A-06 | P2 | `account_security_section.dart:44-58`, `screens/privacy_rule_detail_screen.dart:203-224` | Радиогруппа собрана как `Semantics(checked, inMutuallyExclusiveGroup)` вокруг строки-кнопки с иконкой-радио: `checked` на кнопке, нет имени группы, нет навигации стрелками | `RadioGroup`/`RadioListTile` либо `SettingsListItem.radio(groupLabel:, checked:)` с `onTap`+`checked` на одном узле |
| A-07 | P2 | `widgets/settings/settings_profile_header.dart:206-236`, `screens/profile_screen.dart:470-484` | `Semantics(button, label:'Сменить фото')` без `excludeSemantics`, внутри `PulseAvatar`, который сам даёт `Semantics(image, label:'Аватар …')` (`pulse_avatar.dart:127-131`) и текст инициалов → тройное чтение | `excludeSemantics: true` на кнопке-аватаре |
| A-08 | P2 | `settings_list_item.dart:196-202` (+ `settings_row.dart:67-74`) | Шеврон/стрелка раскрытия не зеркалируются в RTL; `Icons.chevron_right_rounded` без учёта `Directionality` | `IconData(..., matchTextDirection: true)` или `Directionality.of(context) == rtl ? chevron_left : chevron_right` |
| A-09 | P2 | `screens/settings_preferences_screen.dart:117-130` | Громкость: `Slider` без `semanticFormatterCallback` и без привязки к подписи; читается «40 %» без контекста | `MergeSemantics` вокруг подписи+слайдера или `semanticFormatterCallback: (v) => 'Громкость: …'` |
| A-10 | P2 | `widgets/pulse_loading_indicator.dart:30-63` | Загрузка не озвучивается: у всех состояний настройки (`settings_storage_screen.dart:149-152`, `settings_privacy_screen.dart:45-49`, `settings_system_device_screen.dart:34-37`, `settings_plus_screen.dart:193-201`, `settings_about_screen.dart:282-287`) нет ни метки, ни `liveRegion` | В компонент — необязательный `semanticLabel` (по умолчанию «Загрузка»), в экранах — `Semantics(liveRegion: true)` |
| A-11 | P2 | `app_toast.dart` (весь), `SemanticsService.announce` — 0 совпадений в `lib` | «Сохранено / ошибка» объявляется только снекбаром; нет единого канала объявления результата | Хелпер `Announcer.announce(context, text)`; для переключателей — объявление нового состояния после ответа сервера |
| A-12 | P2 | `screens/settings_chats_screen.dart:64-83` | Быстрые реакции: чипы только из эмодзи, без названия; SR читает «красное сердце, выбрано», без контекста «быстрая реакция» | `Semantics(label: l10n.reactionLike, selected:)` + `tooltip`; заголовок `Wrap` как `header` |
| A-13 | P2 | `custom_color_picker_sheet.dart:347-377` | Пресеты подписаны только hex-кодом («6750A4») | Имена цветов (как в `_palettes`, `settings_appearance_screen.dart:34-43`) + hex в `value` |
| A-14 | P2 | `screens/settings_appearance_screen.dart:298-329, 340-462` | Палитра из 9 вариантов разложена по страницам `PageView`; часть образцов не построена и недоступна свайпом без знания о пагинации | Вертикальный список названных вариантов (сетка 2 колонки) на узких экранах; пагинацию оставить только как визуальный вариант |
| A-15 | P2 | `screens/settings_account_screen.dart:92-106`, `settings_system_device_screen.dart:215-232`, `about_identity_widgets.dart:44-69` | Копирование по тапу: строка объявляется «кнопка», но не говорит, что делает | `Semantics(onTapHint: l10n.copy)` (или `customSemanticsActions`) |
| A-16 | P2 | `screens/profile_screen.dart:409-411` | Заголовки групп существуют **только** в семантике (`Semantics(container, label:)`), визуально их нет; SR получает узел-«пустышку» либо ничего | Видимый заголовок секции (`SettingsSection(title:)` уже даёт `Semantics(header)` — `settings_ui.dart:192-201`) |
| A-17 | P2 | `widgets/settings/settings_list_item.dart:309` | Строка-переключатель не фокусируется: `keyboardFocusable: !toggle`; Tab попадает только на сам `Switch` | Фокусировать строку целиком (`ActivateIntent` → переключение), `Switch` оставить `excludeFromSemantics` |
| A-18 | P2 | `notification_settings_section.dart:72` | Пока идёт любой запрос, отключаются **все** переключатели (`enabled: ... && !_busy`) | Отключать только изменяемый, остальные оставить доступными |
| A-19 | P3 | `settings_issue_card.dart:90-103` | `Alignment.centerRight` (не directional) и `minimumSize: Size(100,36)` | `AlignmentDirectional.centerEnd`, `Size(100,48)` |
| A-20 | P3 | `settings_energy_saving_screen.dart:145-148` | `Alignment.centerLeft` | `AlignmentDirectional.centerStart` |
| A-21 | P3 | `settings_storage_screen.dart:471-488` | Легенда: `Row(mainAxisSize.min)` с `Text` без `Flexible` внутри `Wrap` — при 200 % длинная подпись переполнит строку | `Flexible`/`softWrap` или `Wrap` без внутреннего `Row` |
| A-22 | P3 | `e2ee_settings_screen.dart:219-226` | `fontSize: 13` числом вместо токена темы | `textTheme.bodySmall` + `colorScheme.error` |
| A-23 | P3 | `e2ee_settings_screen.dart:213-217`, `ordinary_e2ee_settings.dart:675-676` | Отпечаток ключа — `SelectableText` одной длинной hex-строкой, без метки | `Semantics(label: l10n.fingerprint, value: разбитый по 4 символа)` |
| A-24 | P3 | `settings_appearance_screen.dart:773,784` | «dp» жёстко в тексте (`'${_localValue.toInt()} dp'`) | Ключ l10n |
| A-25 | P3 | `features/settings/presentation/settings_row.dart:120-131` | Подсветка найденного якоря анимируется без проверки `reduceMotion` | `context.reduceMotion ? Duration.zero : M3Durations.medium1` |
| A-26 | P3 | `settings_appearance_screen.dart:549-570` | `Tooltip`→`GestureDetector(onTap)` и вложенный `InkWell(onTap)` — двойная привязка одного действия | Оставить один обработчик |
| A-27 | P3 | `settings_plus_screen.dart:179-180` | Заголовок `'Nios+'` — не через l10n (в отличие от остальных) | Ключ l10n |
| A-28 | P3 | `account_security_section.dart:51-53,160-162` | Язык метки выбирается через `l10n.localeName.startsWith('ru')` вместо локализованного ключа | Две строки в arb |
| A-29 | P3 | `settings_list_item.dart:158` | Отключённое состояние = alpha 0.38 (≈2:1). По WCAG для неактивных элементов допустимо, но на `surfaceContainerLow` в тёмной теме почти невидимо | Оставить 0.38 для текста, но добавить непрозрачную иконку-замок/пояснение причины |
| A-30 | P3 | `widgets/settings_ui.dart:246-357`, `features/settings/presentation/settings_responsive_shell.dart`, `widgets/settings_ui.dart:16-156` | Три параллельных API строк (`SettingsTile`/`SettingsSwitchTile`/`SettingsInfoTile` → `SettingsListItem`, плюс `SettingsRow`), плюс мёртвые `SettingsScaffold`/`SettingsResponsiveShell`/`SettingsNavBanner` (по 1 определению, использований нет) | Оставить одну строку и один каркас; доступность чинить в них, а не в 13 экранах |
| A-31 | P3 | `core/theme/app_text_scaler.dart:16-17,28-34` | Итоговый масштаб жёстко ограничен 200 % (система 250 % + приложение 130 % → 200 %). Осознанно, но это потолок ниже системного запроса | Задокументировать в UI выбора размера (подпись «максимум 200 %») |

**P0 не выявлено.** A-01 может оказаться P0 после проверки на устройстве.

---

## 3. Оценки по экранам

Шкала 1–5, где 5 — «доступность в компоненте, экран ничего не ломает».

| Экран | Оценка | Короткий итог |
|---|---|---|
| Хаб `settings/settings_hub_screen.dart` → `profile_screen.dart` | **3.5** | Поиск с `SearchAnchor` и подсказкой (`:299-324`), заголовок профиля с `ExcludeSemantics` и hit-area ≥48 (`settings_profile_header.dart:150,170-190`) — хорошо. Минусы: невидимые заголовки групп (A-16), тройное чтение аватара (A-07), мастер-панель фиксированной ширины 340 (`profile_screen.dart:620-624`) на узком десктопе. |
| `settings_account_screen.dart` | **4.0** | Строки-значения с копированием, тост подтверждения (`:100-105`). Нет подсказки «копировать» (A-15), нет объединения семантики (A-01). |
| `settings_privacy_screen.dart` | **3.5** | Много однотипных `SettingsRow` (32 использования) — доступность целиком зависит от компонента. Загрузка без метки (`:45-49`), ошибка-строка без `liveRegion` (`:53-59`). Вложенный `AccountSecuritySection` — радиогруппа-суррогат (A-06). |
| `settings_appearance_screen.dart` | **4.0** | Лучший экран: `Semantics(button, selected, label, onTap, excludeSemantics)` у палитры (`:543-548`), точки 48×48 с `MaterialLocalizations.tabLabel` (`:424-455`), `AnimatedTheme` с нулевой длительностью при `reduceMotion` (`:103-105`), `jumpToPage` вместо анимации (`:364-372`), есть тесты на 320 dp и крупный шрифт (`test/widgets/appearance_palette_test.dart:73-113`). Минусы: пагинация палитры (A-14), плоскость кастомного цвета (A-03), `SwitchListTile` в обход единой строки (`:286-297`), «dp» в тексте (A-24). |
| `settings_wallpaper_screen.dart` | **не оценивался** | Тонкая обёртка (`:19-26`) над `WallpaperStudioScreen` — отдельный крупный экран, вне бюджета этого отчёта (см. «Не проверено»). |
| `settings_chats_screen.dart` | **3.5** | Строки и `Wrap` чипов переносятся (`settings_choice_buttons.dart:19-36`), `materialTapTargetSize.padded` (`:74`). Эмодзи-чипы без названий (A-12), `TextStyle(fontSize: 24)` числом (`:72`). |
| `settings_preferences_screen.dart` | **4.0** | Скрытие блока громкости через `M3Reveal` полностью убирает поддерево (`m3_reveal.dart:132-134,139-141`) — хорошо для SR. Минус: слайдер без контекста (A-09), тост-тест без объявления результата (A-11). |
| `settings_language_region_screen.dart` | **3.5** | Кнопки выбора в `Wrap`, шторка с `tooltip` закрытия (`:237-243`), поле поиска с `labelText`/`hintText`. Инверсия значения в заголовке (A-04), жёсткая высота шторки (A-21). |
| `settings_storage_screen.dart` | **4.0** | Диаграмма с осмысленной семантикой (`:247-257`), `tooltip` у обновления (`:235`), кнопка ретрая. Легенда может переполниться (A-21), загрузка молчит (A-10). |
| `settings_energy_saving_screen.dart` | **4.0** | Кнопки ≥48 (`:153`), явные `TextButton` вместо иконок. RTL-мелочь (A-20), пояснение режима меняется без объявления (`M3SpringSwitcher`, `:122-141`). |
| `settings_system_device_screen.dart` | **4.0** | Все значения — строки `value`-типа, `Tooltip` на ретрае (`:44-47`). Копирование без подсказки (A-15), логотип бренда декоративен без подписи (корректно, `:263-268`). |
| `settings_plus_screen.dart` | **3.5** | Состояние в подзаголовке строки, ретрай отдельной строкой (`:196-208`). Заголовок не локализован (A-27), загрузка/смена статуса без объявления (A-10, A-11), кнопка пробного периода появляется через `M3Reveal` (`:264-283`) — при обратной анимации кратко фокусируема. |
| `settings_about_screen.dart` | **3.5** | Вкладки — чипы в `Wrap`, `AnimatedSwitcher` отключён при `reduceMotion` (`:167-183`), копирование версии с тостом (`:69-73`). Прогресс обновления (`about_update_tile.dart:61-75`) и смена вкладок не объявляются. |
| `e2ee_settings_screen.dart` + `ordinary_e2ee_settings.dart` | **4.0** | Единственный `liveRegion` в настройках (`ordinary_e2ee_settings.dart:262-270`), подписанный QR (`:507-523`), `AlignmentDirectional` (`:272-273`), поля с `labelText` (`:442-451`). Минусы: `fontSize: 13` (A-22), отпечаток без метки (A-23), строка генерации ключа на старом API `SettingsTile` (`e2ee_settings_screen.dart:200-207`). |
| `settings_issue_card.dart` (общий) | **3.0** | Жёсткая русская подпись (A-05), не-directional выравнивание и низкая кнопка (A-19), фон-подложка 0.35 alpha влияет на контраст `onSurface` — **не проверено** замером. |

---

## 4. Требования к новой единой строке настроек

Цель: каждое требование ниже выполняется **внутри компонента**, экраны только передают данные.

### 4.1 Семантика
1. Один узел на строку: `Semantics(container: true, excludeSemantics: true, label: …, button/hasEnabledState/toggled/selected, onTap/onLongPress, onTapHint)` — по образцу `chat_tile.dart:290-304`.
2. Метка собирается из `title · subtitle · value · состояние`, порядок фиксирован, пустые части не добавляют запятых.
3. `toggle`-строка: `toggled: value`, `enabled:`, без отдельного узла `Switch` (`ExcludeSemantics` на самом `Switch`), действие — на всей строке. Проверить, что переключение объявляет новое состояние **после** ответа, а не до.
4. `radio`-строка: `checked` + `inMutuallyExclusiveGroup` + имя группы в `hint`; навигация стрелками внутри группы.
5. `slider`-строка: `Semantics(slider, value, increase, decrease)` + озвученное имя параметра; ступень/единица («dp», «%») — из l10n.
6. `action`-строка с побочным эффектом (копировать, поделиться, открыть ссылку): `onTapHint` словами.
7. `disabled`-строка: `enabled: false` **и** причина (`hint`), а не только 0.38 alpha.
8. `pending`-строка: `busy: true` и `liveRegion` на смене подписи.
9. Заголовок секции — видимый `Text` + `Semantics(header: true)` (уже есть, `settings_ui.dart:192-201`); подзаголовок секции — часть семантики группы, не отдельный фокус-стоп.

### 4.2 Клавиатура
10. Строка фокусируема целиком при любом типе, включая `toggle` (`keyboardFocusable: true`); Enter/Space активируют, `Shift+F10` — контекстное меню, если есть `onLongPress`.
11. Фокусная рамка 2 dp `colorScheme.primary` внутри `foregroundDecoration` без сдвига layout (`pressable_surface.dart:99-107` — оставить).
12. `FocusTraversalGroup` на секцию; порядок Tab = визуальному порядку; скрытые `M3Reveal`-ом блоки не в traversal.
13. Кнопки-иконки — только с `tooltip` (сейчас соблюдается почти везде) либо с `semanticLabel`; декоративные иконки — `ExcludeSemantics`.

### 4.3 Размеры и крупный шрифт
14. Минимальная высота строки 64 dp, но **никаких `maxHeight`**; высота растёт вместе с текстом.
15. `title` без `maxLines`, `subtitle` — до 2 строк с `overflow: ellipsis`; значение (`value`) — либо отдельной строкой, либо в конце, с переносом при масштабе > 1.3 (логику `inlineValue` из `settings_list_item.dart:169-174` сохранить).
16. Никаких фиксированных `height` у контейнеров с текстом; вместо этого `ConstrainedBox(minHeight:)` + `IntrinsicHeight`/естественная высота.
17. Иконка-слот 40×40 только как декор; вся площадь строки — цель касания ≥48 dp (уже так).
18. Все числовые `fontSize` — из `textTheme`; `TextStyle(fontSize:)` запрещён.

### 4.4 Цвет и контраст
19. Только `colorScheme`-роли; alpha для текста не ниже 0.72 (кроме отключённого 0.38 и декоративных обводок).
20. Подложки проблем/статусов — тональные `*Container` без alpha, текст — соответствующий `on*Container` (сейчас `onSurface` на 35 % `errorContainer`, `settings_issue_card.dart:29-35` — надо замерить).
21. Состояние никогда не передаётся только цветом: иконка/текст/`selected` в семантике.

### 4.5 Направление
22. `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `BorderRadiusDirectional`.
23. Иконки-стрелки: `matchTextDirection: true` для chevron/back/forward; для кастомных — `Transform.flip` при RTL.
24. Прогресс/диаграммы — `AlignmentDirectional`.

### 4.6 Движение и обратная связь
25. Все анимации строки (press scale, подсветка якоря, reveal) — `Duration.zero` при `MediaQuery.disableAnimations` (уже есть в `PressableSurface`, не хватает в `SettingsAnchor`, `settings_row.dart:120-131`).
26. Единый канал объявления: `Announcer` поверх `SemanticsService.announce` для «сохранено/ошибка/включено», плюс `liveRegion` для счётчиков и прогресса.

### 4.7 Адаптив (каркас, не строка)
27. `SafeArea` + нижний inset: `bottom = max(32, viewPadding.bottom + 16)`; учитывать `padding.left/right` в альбомной ориентации.
28. 320 dp: строка не должна иметь горизонтального скролла; `Wrap` вместо `Row` для пар «метка + значение» при масштабе ≥ 1.3.
29. Планшет: `maxWidth 860` сохранить, но разрешить две колонки секций (логика уже написана в мёртвом `SettingsScaffold`, `settings_ui.dart:34-71` — переиспользовать).
30. Клавиатура поверх полей: `Scaffold.resizeToAvoidBottomInset` + `viewInsets` в шторках (в `CustomColorPickerSheet` сделано верно, `:83-91`; в шторке часовых поясов — проверить).

---

## 5. Не проверено

1. **Реальное поведение TalkBack/VoiceOver** — главное. Нужны прогоны: чтение `nav`/`value`/`toggle`/`danger` строки, двойное касание, объявление переключения. Вывод A-01 (P1→P0?) подтверждается только устройством.
2. **Как Flutter складывает семантику `Semantics(button)` + вложенного `GestureDetector`** (`pressable_surface.dart:132-140`) — вложенный узел `onTap` может как спасать, так и создавать лишний фокус-стоп. Не проверено.
3. **Контраст замером** — alpha 0.35 подложки `SettingsIssueCard`, alpha 0.38 отключённого текста, `onSurfaceVariant` на `surfaceContainerLow` в тёмной теме.
4. **Объявление снекбаров** (`AppToast`) на Android/iOS — обычно объявляются, но `liveRegion` в коде нет; не проверено.
5. **RTL** — в приложении нет RTL-локали (`l10n/app_localizations.dart:96-99`), проверялось только по коду.
6. **`WallpaperStudioScreen`** (`features/wallpaper/presentation/wallpaper_studio_screen.dart`) — отдельный крупный экран, доступность не разбиралась (внутри найдены `Alignment.centerRight`/фиксированные цвета: `wallpaper_studio_screen.dart:185,206,267`).
7. **Подэкраны, открываемые из настроек**: `sessions_screen.dart`, `blocked_users_screen.dart` (частично: тултипы есть, `:111,143,225`), `privacy_rule_detail_screen.dart` (частично), `MyQrCodeSheet`, `call_devices_dialog.dart`, `showLicensePage` — не аудировались системно.
8. **Шторка часовых поясов при открытой клавиатуре** (`settings_language_region_screen.dart:222-268`) — по коду `isScrollControlled: true` и `useSafeArea: true` (`app_modal.dart:25,42`), но поведение при клавиатуре на 320 dp не проверено.
9. **Планшет/десктоп (>840 dp) и Windows**: master-detail, фокус-порядок между мастер-панелью и деталью, `shrinkWrap` тап-таргеты на десктопе — не проверено.
10. **Статический анализ и тесты** не запускались (запрет на `flutter`/`dart`). Существующие a11y-тесты: `test/privacy_blocklist_test.dart:163-216`, `test/widgets/appearance_palette_test.dart:73-113`, `test/features/security/app_lock_lifecycle_test.dart:173-263`, `test/onboarding_screens_test.dart:161-173` — покрывают точечно, настроек целиком не покрывают.
