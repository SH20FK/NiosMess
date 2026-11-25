# 04. Настройки NiosMess глазами лучших мессенджеров

Роль: **сторонник лучших мессенджеров**. Позиция: у Telegram, WhatsApp и Signal настройки отточены годами на миллиардах людей. Наша задача — взять их структуру и названия, а не изобретать свою таксономию.

Дата: 2026-11-22. Код: `F:/Niosmess V2/pulse_flutter`.

Что проверено: наш хаб и все подэкраны прочитаны; структура Telegram Android и Signal Android — **по исходникам на GitHub** (актуальный `master`/`main` на дату отчёта); WhatsApp и MAX — по официальной справке и обзорам (справка WhatsApp отдаётся только через прокси-рендер, см. «Не проверено»); Telegram iOS — частично по справке/обзорам.

---

## 1. Главные выводы

1. **У нас нет точки входа в обои вообще.** Студия обоев существует (`pulse_flutter/lib/features/wallpaper/presentation/wallpaper_studio_screen.dart:17`), маршрут есть (`pulse_flutter/lib/router/app_router.dart:571-582`), экран-обёртка есть (`pulse_flutter/lib/screens/settings_wallpaper_screen.dart:20`), но из UI на него не ведёт ни одна ссылка: `grep` по `settings/wallpaper` даёт только роутер и `app_url_launcher` для deep-link. Это единственная настройка из шести «типовых», до которой у нас **бесконечно много** нажатий. У Telegram — 2, у WhatsApp — 3, у Signal — 3.
2. **Наш корень в целом повторяет Telegram, но с двумя перекосами.** Совпадают: Уведомления, Приватность, Данные, Язык, Папки, Энергосбережение, Подписка, Помощь (`pulse_flutter/lib/services/settings/settings_registry.dart:40-319`). Не совпадают: **«Аккаунт» выкинут из хаба** (`settings_registry.dart:700-709`), а **«Устройства/сеансы» спрятаны на третьем уровне** (Приватность → «Аккаунт и защита» → Активные сеансы, `pulse_flutter/lib/widgets/settings/account_security_section.dart:104-121`). У всех четырёх конкурентов аккаунт и устройства — строки корня.
3. **«Аккаунт» не просто спрятан — он открыт по умолчанию на десктопе.** `DesktopSettingsSectionNotifier.build() => SettingsSectionId.account` (`pulse_flutter/lib/providers/settings_navigation_provider.dart:31`), а в списке хаба этой строки нет. На широком экране пользователь видит раздел, которого нет в навигации, и не может вернуться к нему после ухода. Это баг структуры, а не стиля.
4. **Уведомления — самый большой функциональный разрыв.** У нас один глобальный набор: push, messages, calls, activity, preview, sound + громкость (`pulse_flutter/lib/widgets/notifications/notification_settings_section.dart:149-167`, `pulse_flutter/lib/screens/settings_preferences_screen.dart:78-157`). У Telegram — личные/группы/каналы/истории/реакции, звонки, in-app (звук/вибрация/превью/pop-up), события, исключения, счётчик, keep-alive. У Signal — mentions/replies, while muted, notification profiles. У WhatsApp — сообщения/звонки/статусы + тон на каждый тип.
5. **Автозагрузка у нас — два тумблера** (Wi-Fi / мобильная сеть, `pulse_flutter/lib/screens/settings_storage_screen.dart:338-381`). У всех трёх конкурентов — матрица «сеть × тип медиа» (фото/видео/файлы/аудио, + роуминг). Это то, из-за чего люди и заходят в «Данные».
6. **Нет удаления аккаунта.** `grep` по `deleteAccount|DeleteAccount` не даёт ничего. У Telegram — `Delete My Account` в Privacy, у WhatsApp — `Settings > Account > Delete my account`, у Signal — в Account. Для магазинов приложений и для доверия это обязательный пункт.
7. **Безопасность аккаунта уходит в браузер.** Строка «Безопасность Nios ID» открывает `https://ni-os.ru/id/account` (`account_security_section.dart:31-33, 167-174`). Ни один из конкурентов не выкидывает 2FA/пароль из приложения.
8. **«Энергосбережение» — наша сильная сторона, но с перепутанной упаковкой.** Telegram тоже держит `Power Saving` в корне (`SettingsActivity.java:805`), так что сам раздел — не ошибка. Ошибка — что у нас туда же сложены «Анимации в чатах» и **фоновое соединение** (`pulse_flutter/lib/screens/settings_energy_saving_screen.dart:30-184`), которое Telegram держит в уведомлениях (Keep-Alive Service / Background Connection), а Signal — в «Данных» (Stay connected in background).
9. **«Система и устройство» — наша уникальная секция, которой нет ни у кого.** Характеристики CPU/RAM/камеры (`pulse_flutter/lib/screens/settings_system_device_screen.dart:107-196`) — это диагностика, её место в «О приложении → Диагностика» (там она уже и вызывается, `pulse_flutter/lib/screens/settings_about_screen.dart:231-245`), а не отдельный маршрут настроек.
10. **Поиск у нас лучше, чем у Signal, и сравним с Telegram.** `SearchAnchor` + реестр с хлебными крошками (`pulse_flutter/lib/screens/profile_screen.dart:290-373`, `settings_registry.dart:725-819`). Но поиск живёт только в корне: в подэкранах (`SettingsShell`) его нет. Telegram ищет и по справке/FAQ из того же поля, мы — только по названиям/ключам.
11. **Мы не обязаны копировать всё.** Telegram перегружает корень монетизацией (Premium, Stars, Gram Earnings, Business, Send a Gift, Wallet — `SettingsActivity.java:791-835`), WhatsApp разносит автозагрузку между «Чатами» и «Хранилищем», Signal ставит «Donate» выше «Оформления». Это антипримеры, см. §2.6.

---

## 2. Как устроены настройки у конкурентов

### 2.1 Telegram Android — по исходникам (эталон структуры)

Источник: `TMessagesProj/src/main/java/org/telegram/ui/SettingsActivity.java`, метод `fillItems` — <https://github.com/DrKLO/Telegram/blob/master/TMessagesProj/src/main/java/org/telegram/ui/SettingsActivity.java> (строки 717–862; ниже — по этому файлу).

Сверху вниз:

| # | Что | Подпись/подсказка | Код |
|---|---|---|---|
| 0 | **Поиск по настройкам** (внутри — ещё и статьи FAQ) | — | 719–720, 906–913 |
| 1 | Шапка: аватар, имя, `+phone • @username`, версия | — | 724, 524–542 |
| 2 | Карточки-подсказки (Premium grace, подтвердить номер, напомнить пароль) | — | 743–781 |
| 3 | Заголовок «Аккаунты» + список аккаунтов | — | 783–789 |
| 4 | Кошелёк (если доступен) | — | 791–796 |
| 5 | **Аккаунт** | Number, Username, Bio | 798 |
| 6 | **Настройки чатов** | Wallpaper, Night Mode, Animations | 799 |
| 7 | **Приватность и безопасность** | Last Seen, Devices, Passkeys | 800 |
| 8 | **Уведомления и звуки** | Sounds, Calls, Badges | 801 |
| 9 | **Данные и хранилище** | Media download settings | 802 |
| 10 | **Папки с чатами** | Sort chats into folders | 803 |
| 11 | **Устройства** | Manage connected devices | 804 |
| 12 | **Энергосбережение** | Reduce power usage on low charge | 805 |
| 13 | **Язык** (значение — текущий язык) | — | 806 |
| 14 | Telegram Premium / Stars / Gram Earnings / Business / Send a Gift | — | 815–835 |
| 15 | Заголовок «Помощь»: Ask a Question, Telegram FAQ, Telegram Features, Privacy Policy | — | 839–843 |
| 16 | Experimental (если включено): Round video, Audio recorder, Header | — | 845–851 |
| 17 | Debug (только dev-сборки) | — | 853–859 |
| 18 | Версия внизу | — | 861 |

Ключевое: **десять содержательных строк, один заголовок групп, никаких «групп настроек»**. Коммерческие строки — отдельным блоком ниже языковых, чтобы не мешать. Переходы: `case 2 → ThemeActivity(THEME_TYPE_BASIC)` (924), `case 8 → SessionsActivity` (939), `case 9 → LiteModeSettingsActivity` (942).

Подэкраны (по исходникам):

- **Уведомления и звуки** (`NotificationsSettingsActivity.java`): `Notifications for chats` → Private Chats / Groups / Channels / Stories / Reactions (Messages, Stories); `Voice calls` → Ringtone, Vibrate; `In-app notifications` → In-App Sounds / Vibrate / Preview / Pop on Screen; `Events` → Contact joined, Pinned Messages; `Badge Counter` (Enabled, Include Muted Chats, Count Unread Messages); `Keep-Alive Service`, `Background Connection`; `Exceptions` / View Exceptions; `Reset All Notifications`.
- **Приватность и безопасность** (`PrivacySettingsActivity.java`): Privacy → Phone Number, Last Seen & Online, Profile Photo, Bio, Saved Music, Date of Birth, Gifts, Forwarded Messages, Voice Messages, Messages, Calls, Invites (у каждого — селектор Everybody/Contacts/Nobody + Never/Always Share With); Security → Passcode, Two-Step Verification, Email Login, Active Sessions, Telegram Passport, Auto-Delete Messages, Delete My Account; Secret chats; Bots and websites; Contacts; New chats from unknown users; Archive and Mute; Delete Synced Contacts; Map Preview Provider; Clear Payment and Shipping Info; Delete My Account.
- **Данные и хранилище** (`DataSettingsActivity.java`): Disk and network usage (Storage Usage, Data Usage, Storage Path) → Automatic media download (When using mobile data / Wi-Fi / roaming × Photos, Videos, Files) → Save to Gallery (Private/Groups/Channels) → Streaming (Stream Videos and Audio) → Autoplay (GIFs, Videos) → Use less data for calls → Proxy Settings → Reset Auto-Download Settings → Delete All Cloud Drafts.
- **Энергосбережение** (`LiteModeSettingsActivity.java`): Power Usage → Low power mode (Off / On / When below X%) → Power saving options (Animated Stickers, Autoplay in keyboard/chat, Animated Emoji, Autoplay reactions menu, Animations in Chats/Calls, Autoplay Videos/GIFs, Particles, Enable Smooth Transitions).
- **Настройки чатов** = `ThemeActivity` (924): обои, ночной режим, авто-ночной режим, размер текста, анимации (подпись строки прямо говорит: «Wallpaper, Night Mode, Animations»).

### 2.2 Telegram iOS

Источники: Telegram FAQ (<https://telegram.org/faq> — «Settings > Privacy & Security (on iOS, there is one more step > Data Settings)»), Kaspersky о настройках на iPhone (<https://privacy.kaspersky.com/articles/telegram-iphone-medium> — путь «шестерёнка → Data and Storage», «Devices → Active Sessions»), обзор 2024 (<https://blog.invitemember.com/2024-master-guide-to-telegram-settings-for-android-and-ios>), упоминание «Saved Messages в настройках на iPhone» (<https://tuckii.app/blog/telegram-saved-messages>).

- Вход: шестерёнка в правом нижнем углу (у Android — «гамбургер» слева).
- Корень: шапка профиля, **Saved Messages**, Premium/Stars, далее те же строки, что на Android: Notifications and Sounds, Privacy and Security, Data and Storage, Chat Settings, Devices, Language, Help (Ask a Question / Telegram FAQ / Privacy Policy), добавление аккаунта.
- Отличия iOS от Android (подтверждены): часть приватности убрана в подэкран **Data Settings** внутри Privacy; нет отдельного «Power Saving» в корне (энергосбережение живёт в Chat Settings → Animations). *Порядок строк — по памяти + обзоры, не по исходникам; помечено в §7.*

Вывод для нас: **iOS и Android у Telegram расходятся** (Saved Messages, Data Settings, Power Saving). Это то, чего нам копировать не надо — у нас один Flutter-код и master-detail на десктопе.

### 2.3 Signal Android — по исходникам

Источник: `feature/app-settings/src/main/java/org/signal/appsettings/home/AppSettingsScreen.kt` — <https://github.com/signalapp/Signal-Android/blob/main/feature/app-settings/src/main/java/org/signal/appsettings/home/AppSettingsScreen.kt> (порядок задан блоками `item { Rows.TextRow(...) }`, имена — `AppSettingsTestTags.ROW_*`).

| # | Строка | testTag |
|---|---|---|
| 1 | Шапка профиля (аватар + бейдж, имя, username, about) | `ROW_PROFILE` |
| 2 | Предупреждение о бэкапе (если есть проблема) | `ROW_BACKUP_WARNING` |
| 3 | **Аккаунт** | `ROW_ACCOUNT` |
| 4 | **Связанные устройства** (только primary) | `ROW_LINKED_DEVICES` |
| 5 | **Donate to Signal** | `ROW_DONATE` |
| 6 | — разделитель — | |
| 7 | **Оформление** | `ROW_APPEARANCE` |
| 8 | **Чаты** | `ROW_CHATS` |
| 9 | **Истории** | `ROW_STORIES` |
| 10 | **Уведомления** | `ROW_NOTIFICATIONS` |
| 11 | **Приватность** | `ROW_PRIVACY` |
| 12 | **Бэкапы** | `ROW_BACKUPS` |
| 13 | **Данные и хранилище** | `ROW_DATA_AND_STORAGE` |
| 14 | Обновления приложения | `ROW_APP_UPDATES` |
| 15 | Платежи (если есть) | `PaymentsRow` |
| 16 | **Помощь** | `ROW_HELP` |
| 17 | **Пригласить друзей** | `ROW_INVITE` |
| 18 | Labs / Internal (для внутренних сборок) | `ROW_LABS` |

Подэкраны (по исходникам, порядок ключей в файлах):
- **Оформление**: Язык, Тема, Цвет чата и обои, Иконка приложения, Размер текста сообщений, Размер навигационной панели.
- **Чаты**: превью ссылок, автовоспроизведение стикеров/GIF, фото из адресной книги, оставлять заглушённые в архиве, папки чатов, экспорт истории, клавиатура (системные эмодзи, отправка по Enter).
- **Уведомления**: включить, показывать, while muted, реакции, напоминания о непрочитанном, «контакт присоединился», повторные оповещения, звуки → Customize (звук, вибрация, LED), звуки в чате, troubleshoot, приоритет, звонки (рингтон), профили уведомлений, сброс.
- **Приватность**: номер телефона, скрытые и заблокированные, read receipts, typing indicators, исчезающие сообщения, App security (screen lock, screen security, incognito keyboard, payment lock), Advanced (PIN).
- **Данные и хранилище**: Manage storage, Media auto-download (mobile/Wi-Fi/roaming × images/audio/video/documents), качество отправляемых медиа, «меньше данных для звонков», Stay connected in background, Proxy.

Наблюдения: Signal — **самый плоский и предсказуемый** корень, но у него **нет поиска по настройкам** (в `AppSettingsScreen.kt` нет поля поиска; проверено по исходнику), а «Donate» стоит выше «Оформления».

### 2.4 WhatsApp

Официальная справка (проверенные пути):
- `Settings > Privacy` — <https://faq.whatsapp.com/3307102709559968> (Privacy — **корневая** строка, не внутри Account).
- `Settings > Account > Two-step verification / Email address` — <https://faq.whatsapp.com/1920866721452534>, <https://faq.whatsapp.com/1082491466048496>.
- `Settings > Account > Delete my account` — <https://faq.whatsapp.com/227626810186044>.
- `Settings > Linked devices` — <https://faq.whatsapp.com/378279804439436>, <https://faq.whatsapp.com/647349420360876>.
- `Settings (или фото профиля) > Chats > Wallpaper` — <https://faq.whatsapp.com/6298875896807790>.
- `Settings > Chats > Media auto-download` — <https://faq.whatsapp.com/366146522333492>; `Settings > Chats > Chat backup` — <https://faq.whatsapp.com/5503646096388294>.
- `Settings > Storage and data > Manage storage` — <https://faq.whatsapp.com/5503646096388294>.
- `Settings > App language` — <https://faq.whatsapp.com/779773243128935>, <https://faq.whatsapp.com/859053323029647>.
- `Privacy > Advanced` (блокировать сообщения с неизвестных аккаунтов, скрыть IP в звонках, отключить превью ссылок, Strict Account Settings) — обзор <https://www.makeuseof.com/dug-through-whatsapps-settings-found-surprisingly-useful-privacy-options>.

Реконструированный корень (порядок — средне-уверенный, §7): шапка профиля (фото, имя, about) → **Аккаунт** (безопасность, 2FA/пароль, email, смена номера, запрос информации, удаление) → **Приватность** (+ Advanced) → **Чаты** (тема/обои, история, автозагрузка, резервная копия, media visibility, keep archived) → **Уведомления** → **Хранилище и данные** (manage storage, network usage, media quality, proxy) → **Связанные устройства** → **Язык приложения** → **Помощь и обратная связь**.

Переходный момент: в 2026 WhatsApp выносит тему/обои в отдельный **Appearance** (`Settings → Appearance → Default chat theme`, обзоры: <https://www.youtube.com/watch?v=U6sOORF5K_8>, <https://www.nextpit.com/how-tos/whatsapp-chat-themes-messages-colors-how-to-use>, бета-репорты WABetaInfo: <https://wabetainfo.com/whatsapp-is-rolling-out-new-chat-themes-on-android-beta>), тогда как официальная справка всё ещё описывает `Chats → Wallpaper`. То есть WhatsApp сейчас **сам копирует** структуру Telegram/Signal — это аргумент в пользу нашей целевой схемы.

### 2.5 MAX (для российского контекста)

Источники: <https://hi-tech.mail.ru/articles/150486-nastrojki-v-makse>, <https://www.rbc.ru/life/news/69c29b389a794708413e7f7c>, <https://maxofficial.ru/blog/nastroyki-maks-messendzhera>.

Вход — «Настройки» в правом нижнем углу. Внутри: **Уведомления и звук**, **Безопасность и приватность** (включая безопасный режим), **Сообщения**, **Медиа** (автозагрузка, качество видео, кэш), **Оформление** (размер текста, тема, цвет фона сообщений), **Язык**, **Папки**, **Избранное**.

Для нас важно: MAX — это **плоский Telegram-подобный список** с отдельным «Медиа». Российский пользователь, приходящий из MAX/Telegram, ждёт в корне ровно те слова: «Уведомления», «Приватность», «Данные/Медиа», «Оформление», «Язык», «Папки».

### 2.6 Что у конкурентов сделано плохо — не копировать

1. **Telegram: монетизация в корне настроек.** Premium, Stars, Gram Earnings, Business, Send a Gift, Wallet — шесть строк между «Языком» и «Помощью» (`SettingsActivity.java:791-835`). Пользователь ищет «Данные», а пролистывает витрину. Нам хватает одной строки «Nios+».
2. **Telegram: скрытые/экспериментальные пункты в проде.** `Experimental` (845–851) и Debug-строки (853–859) появляются в обычном списке при определённых флагах.
3. **Telegram: разные структуры на Android и iOS** (Saved Messages в корне iOS, Data Settings внутри Privacy, Power Saving только на Android). Наш единый master-detail — преимущество, не уравнивайте платформы «как у них».
4. **Telegram: «Настройки чатов» — мешанина из обоев, ночного режима, текста и анимаций.** Название не говорит, что внутри; мы уже разнесли это лучше (обои — в «Чаты», тема/текст — в «Оформление»), просто доведите до конца.
5. **WhatsApp: автозагрузка живёт в «Чатах», а управление хранилищем — в «Хранилище и данных»** (сравните faq 366146522333492 и faq 5503646096388294). Одна тема в двух разделах.
6. **WhatsApp: ключевые защиты спрятаны в `Privacy > Advanced`** (скрыть IP в звонках, блокировка неизвестных, Strict Account Settings). Это не «продвинутое», это базовая безопасность 2026.
7. **WhatsApp: «Аккаунт» остался пустым бакетом** после выноса Privacy в корень — там вход/2FA/удаление, а «приватность» отдельно. Пользователи до сих пор ищут приватность в аккаунте (сотни инструкций «Settings > Account > Privacy»).
8. **Signal: нет поиска по настройкам** и «Donate» выше «Оформления» — донат важнее персонализации только для самой Signal.
9. **Signal: «Истории» отдельной строкой корня** — фича, которая у большинства выключена, занимает место в главном списке.
10. **У всех: настройки приватности размазаны по 3–4 экранам** с одинаковыми названиями («Privacy», «Security», «Advanced», «Data Settings»). Наш один экран «Приватность и безопасность» с 4 группами — читаемее; не дробим.

---

## 3. Таблица сопоставления: наш раздел → где у конкурентов

Наши данные: `settings_registry.dart:40-319`, `profile_screen.dart:378-436`.

| Наш раздел (ru) | Что внутри у нас | Telegram (Android) | WhatsApp | Signal | Расхождение / вердикт |
|---|---|---|---|---|---|
| **Шапка профиля** «Имя, @username, Изменить, QR» (`profile_screen.dart:545-553`) | аватар, имя, @username, Edit, QR | Шапка: имя, `+phone • @username`, версия; тап → Аккаунт (`SettingsActivity.java:724, 798`) | Фото, имя, about; тап → профиль | Аватар, имя, username, about (`ROW_PROFILE`) | У нас нет телефона и статуса/about в шапке. Добавить телефон + about. |
| **Аккаунт** (`settings_registry.dart:42-65`; `settings_account_screen.dart:31-83`) | имя, username, Nios ID (copy), ссылка «Безопасность» | **Аккаунт** в корне (798) | **Аккаунт** в корне | **Аккаунт** в корне | У нас **исключён из хаба** (`:700-709`) → P1. Вернуть в корень. |
| **Оформление** (`:68-94`; `settings_appearance_screen.dart:221-229`) | тема, палитра, системные цвета, стиль палитры, шрифт, плотность, радиус | «Настройки чатов» (обои, ночь, анимации, текст) | «Чаты» → тема/обои (или новый «Appearance») | «Оформление» (язык, тема, обои, иконка, текст, навбар) | По наполнению мы **сильнее** всех. Не хватает только обоев (P0). |
| **Чаты и звонки** (`:97-120`; `settings_chats_screen.dart:35-101`) | папки, отправка по Enter, быстрая реакция, устройства звонков | «Настройки чатов» + «Папки» отдельной строкой (799, 803) | «Чаты» | «Чаты» (папки, автоплей, Enter, архив, экспорт) | Папки у Telegram — корень, у Signal — внутри «Чатов». У нас внутри → допустимо, но «звонки» тут лишние. |
| **Уведомления и звуки** (`:123-144`, экран `settings_preferences_screen.dart:74-159`) | push, messages, calls, activity, preview, sound, громкость, haptics | «Уведомления и звуки»: Private/Groups/Channels/Stories/Reactions, Calls, In-app, Events, Badge, Keep-Alive, Exceptions | «Уведомления»: сообщения/группы/статусы, тон, звонки | «Уведомления»: реакции, mentions/replies, while muted, профили, звуки, звонки | Нет типов чатов и исключений → P1. Громкость-слайдер — наша фича, оставить. |
| **Приватность и безопасность** (`:147-173`; `settings_privacy_screen.dart:63-306`) | 4 группы правил + блокировки + сессии + app lock + E2EE | «Приватность и безопасность»: правила, passcode, 2FA, сессии, удаление аккаунта | «Приватность» + Advanced; 2FA в «Аккаунте» | «Приватность»: правила, app security, исчезающие, PIN | Структура совпадает. Лишнее: сессии и 2FA живут здесь, а должны в «Аккаунте»/«Устройствах». |
| **Данные и память** (`:176-196`; `settings_storage_screen.dart:281-381`) | объём, категории, очистка кэша/черновиков, автозагрузка Wi-Fi/сота | «Данные и хранилище»: storage/data usage, автозагрузка по типам, галерея, стриминг, автоплей, экономия в звонках, прокси | «Хранилище и данные»: manage storage, network usage, качество медиа, прокси | «Данные и хранилище»: то же + фоновое соединение | Название «память» — не то слово, которое ищут. Автозагрузка без типов медиа → P1. |
| **Язык и время** (`:199-220`; `settings_language_region_screen.dart:29-113`) | ru/en + часовой пояс + превью времени | «Язык» в корне (806) | «Язык приложения» в корне | «Язык» внутри «Оформления» | У нас два в одном. Разнести: «Язык» в корень, часовой пояс — в «Дополнительно». |
| **Система и устройство** (`:223-246`; скрыт из хаба `:700-709`) | CPU, RAM, экран, камеры, патч | нет (только Debug) | нет | нет | Уникальная техническая секция. В «Помощь → Диагностика» (уже вызывается оттуда, `settings_about_screen.dart:231-245`). P2. |
| **Анимации и энергосбережение** (`:249-271`; `settings_energy_saving_screen.dart:30-184`) | стикеры, эмодзи, оптимизация, фоновый режим, батарея | «Энергосбережение» в корне (805): режим + granular-анимации | нет | нет (есть «Stay connected in background» в «Данных») | Название совпадает с Telegram — хорошо. Фоновый режим перенести в «Уведомления». |
| **Nios+ · NiosAI** (`:273-294`; `settings_plus_screen.dart:179-283`) | статус, покупка, буст-лист, триал | Premium / Stars / Business / Gift (5 строк) | нет | Donate to Signal | Мы ближе к Telegram, но у них 5 строк, у нас 1 — правильно. Убрать «· NiosAI» из названия строки. |
| **Помощь и о приложении** (`:297-318`; `settings_about_screen.dart:113-262`) | версия, обновления, что нового, юр., команда, FAQ, баг, шеринг, alpha, диагностика, сброс | Блок «Помощь»: Ask a Question / FAQ / Features / Privacy Policy (839-843) | «Помощь и обратная связь» | «Помощь» + «Пригласить» | У нас Help и About слиты — это ок (как у WhatsApp). |
| **Сеансы** (внутри Приватности, `account_security_section.dart:104-121`) | текущее устройство, другие, завершить все | «Устройства» в корне (804) | «Связанные устройства» в корне | «Связанные устройства» в корне | P1: поднять в корень отдельной строкой «Устройства». |
| **Секретные чаты / E2EE** (внутри Приватности, `settings_privacy_screen.dart:285-304`) | ключ устройства, отпечаток, стирание, «как работает» | Строка «Secret chats» в Privacy | нет (E2EE везде) | нет (E2EE везде) | Нормально. Но «стереть все секретные чаты» лучше в «Опасной зоне» аккаунта. |
| **Папки** (внутри Чатов, `settings_chats_screen.dart:37-41`) | открывает папки чатов | «Папки с чатами» в корне (803) | «Списки» | «Папки» внутри «Чатов» | Оставить внутри «Чатов» (как Signal) или вынести (как Telegram) — решить дизайном. |

---

## 4. Глубина: сколько нажатий до типовой настройки

Считаем тапы от момента, когда открыт экран настроек (наш хаб = 0, корень конкурента = 0). Изменение значения — отдельный тап, если это радио/селектор.

| Настройка | У нас | Telegram Android | WhatsApp | Signal | Комментарий |
|---|---|---|---|---|---|
| Тема (светлая/тёмная) | **2** (Оформление → сегмент) | 3 (Настройки чатов → ночь) | 3 (Чаты → тема) или 3 (Appearance → Default chat theme) | 3 (Оформление → Тема) | Мы быстрее всех. |
| Обои чата | **∞** (нет входа) | 2–3 (Настройки чатов → Wallpaper) | 3 (Чаты → Wallpaper) | 3 (Оформление → Цвет чата и обои) | P0. |
| Звук уведомления (сменить) | **2** до экрана, но сменить нельзя — только вкл/выкл + громкость | 4 (Уведомления → Private chats → Sound) | 3 (Уведомления → Message notifications → Tone) | 4 (Уведомления → Sounds → Customize) | У нас нет выбора звука/рингтона вообще. |
| Кто видит «время захода» | **3** до экрана правила + 1 тап (Приватность → Последняя активность) | 3 + 1 | 3 + 1 (Приватность → Last seen) | 3 + 1 (Приватность → Phone/… правила) | Паритет, не проблема. |
| Активные сеансы | **3** (Приватность → «Аккаунт и защита» → сеансы) | **2** (Устройства) | **2** (Связанные устройства) | **2** (Связанные устройства) | P1: на один уровень глубже всех. |
| Очистка кэша | **2** + подтверждение | 3 (Данные → Storage Usage → Clear) | 2–3 (Хранилище → Manage storage) | 3 (Данные → Manage storage) | Мы быстрее. Хорошо. |
| Язык | **2** (Язык и время → сегмент) | **2** (Язык) | **2** (Язык приложения) | **3** (Оформление → Язык) | Паритет с TG/WA. |
| Автозагрузка медиа | **2** до экрана, но только 2 тумблера | 3–4 до матрицы «сеть × тип» | 3 до матрицы | 3 до матрицы | Глубина ок, **гранулярность** — нет. |
| Уведомления по типам чатов | **нет** | 2 (Private/Groups/Channels) | 2 | 2 | P1. |
| Удаление аккаунта | **нет** | 2 (Приватность → Delete My Account) | 2 (Аккаунт) | 2 (Аккаунт) | P0. |
| Прокси | **нет** | 3 (Данные → Proxy) | 3 (Хранилище → Прокси) | 2 (Данные → Прокси) | P1 (для РФ-аудитории). |
| Фоновое соединение / надёжность пушей | **2**, но в «Энергосбережении» | 2 (Уведомления → Keep-Alive) | нет | 2 (Данные → Stay connected) | P2: место не то, где ищут. |
| 2FA / пароль входа | **3** и **в браузере** | 2 (Приватность → Two-Step) | 2 (Аккаунт) | 2 (Приватность → PIN) | P1: уводим из приложения. |
| Часы/часовой пояс | **2** | нет | нет | нет | Наша фича, ок. |

---

## 5. Таблица находок

Severity: **P0** — ломает ожидания/блокирует фичу, **P1** — заметно хуже конкурентов, **P2** — неудобно/непривычно, **P3** — полировка.

| # | Sev | Место | Что не так | Что предлагаю |
|---|---|---|---|---|
| 1 | **P0** | `app_router.dart:571-582`, `settings_wallpaper_screen.dart:20`, `features/wallpaper/.../wallpaper_studio_screen.dart:17` | Студия обоев недостижима из UI: маршрут есть, входа нет (grep: только router + deep-link `app_url_launcher.dart:277-288`) | Строка «Обои и тема чата» в «Чаты» + дубль «Обои» в «Оформление». Одна строка, открывающая `WallpaperStudioScreen` (`chatId: null`) |
| 2 | **P0** | весь `lib/` (grep `deleteAccount` пуст) | Нет удаления аккаунта ни в одном экране | «Аккаунт → Удалить аккаунт» с подтверждением и сроком (как Telegram `Delete My Account`) |
| 3 | **P1** | `settings_registry.dart:700-709` | Секция `account` исключена из хаба — профиль/username/Nios ID недоступны из списка | Вернуть первой строкой «Аккаунт» (подпись: «Номер, имя, Nios ID») |
| 4 | **P1** | `settings_navigation_provider.dart:31` | На десктопе по умолчанию открыт «Аккаунт», которого нет в master-списке | После п.3 выбирать `account` осознанно; либо дефолт — «Оформление» |
| 5 | **P1** | `account_security_section.dart:104-121`, `settings_privacy_screen.dart:266` | Сеансы — третий уровень; у TG/WA/Signal — корень | Отдельная строка корня «Устройства» (или «Активные сеансы») с бейджем количества |
| 6 | **P1** | `notification_settings_section.dart:149-167` | Уведомления только глобальные: нет личных/групп/каналов, нет исключений, нет выбора звука | Блок «Личные чаты / Группы / Каналы / Реакции» + «Исключения» + выбор звука (как TG) |
| 7 | **P1** | `settings_storage_screen.dart:338-381` | Автозагрузка: только Wi-Fi/сота, без фото/видео/файлов и роуминга | Матрица «сеть (Wi-Fi / моб. / роуминг) × тип (фото/видео/файлы/аудио)» как у TG/Signal |
| 8 | **P1** | `account_security_section.dart:31-33, 167-174` | «Безопасность Nios ID» уводит в браузер (`https://ni-os.ru/id/account`) | Встроенный экран 2FA/пароля входа (или хотя бы in-app webview с возвратом) |
| 9 | **P1** | нет в коде (grep `proxy` — только сетевой слой) | Нет настройки прокси | «Данные и хранилище → Прокси» (TG/Signal/WA) |
| 10 | **P2** | `settings_registry.dart:176-196`, `app_ru.arb:497` | Название «Данные и память» — пользователи ищут «Хранилище»/«Данные» | «Данные и хранилище» |
| 11 | **P2** | `settings_registry.dart:199-220` | «Язык и время» смешивает язык и часовой пояс | «Язык» в корень (как TG/WA), часовой пояс/формат времени — «Дополнительно» |
| 12 | **P2** | `settings_registry.dart:223-246` + `settings_about_screen.dart:231-245` | «Система и устройство» — техническая секция с отдельным маршрутом, скрытая из хаба | Убрать маршрут, оставить «Диагностика» внутри «О приложении» |
| 13 | **P2** | `settings_energy_saving_screen.dart:75-184` | Фоновый режим/батарея лежат в «Энергосбережении» | Перенести в «Уведомления» (TG Keep-Alive) или «Данные» (Signal) |
| 14 | **P2** | `settings_registry.dart:97-120`, `settings_chats_screen.dart:88-100` | «Чаты и звонки»: устройства звонков — не настройка чатов | Вынести в «Звонки» (внутри «Уведомлений») или в «Данные» |
| 15 | **P2** | `settings_registry.dart:273-294` | Название строки «Nios+ · NiosAI» смешивает подписку и продукт | «Nios+» (значение — статус), AI — внутри |
| 16 | **P2** | `settings_storage_screen.dart:180-384` | Нет «Сохранять в галерею»/видимости медиа, нет статистики трафика | Блок «Сохранение в галерею» + «Трафик» (TG/Signal) |
| 17 | **P2** | `settings_chats_screen.dart:35-101` | Нет «Архив», «Оставлять заглушённые в архиве», «Архивировать незнакомцев», автоплея GIF/видео, превью ссылок | Добавить в «Чаты» (Signal/TG) |
| 18 | **P2** | нет в коде | Нет экспорта данных / «Запросить информацию об аккаунте» | «Аккаунт → Экспорт данных» (WA/Signal) |
| 19 | **P2** | `profile_screen.dart:290-373` | Поиск только в корне; не ищет по FAQ/справке, не ищет значения | Оставить в корне, но добавить статьи помощи в индекс (как TG, `SettingsActivity.java:906-913`) |
| 20 | **P3** | `settings_registry.dart:123-144` | `id: 'notifications'` при `sectionId: preferences` — рассинхрон идентификаторов | Переименовать секцию в `notifications` целиком |
| 21 | **P3** | `profile_screen.dart:378-399` | Четыре самодельные группы («Общение», «Оформление», «Аккаунт и защита», «Приложение») — ни у кого из конкурентов нет заголовков групп | Плоский список + 2 разделителя (как TG/Signal) |
| 22 | **P3** | `profile_screen.dart:438-447` | Карточки «здоровья настроек» над списком сдвигают привычные строки | Оставить, но убрать выше первого экрана / показывать в конце |
| 23 | **P3** | `settings_plus_screen.dart:179-283` | Подписка смешана с AI-лимитами и бустом | Разделить «Nios+» и «NiosAI» внутри экрана, не в корне |
| 24 | **P3** | `settings_about_screen.dart:212-227` | В «О приложении» строка «Telegram» с @niosmess — визуально конкурирует с брендом | Оставить в «Ссылки», ниже юр. блока |

---

## 6. Целевая структура «как у лучших»

Принципы: плоский корень 9–10 строк, один заголовок «Помощь», коммерция одной строкой, устройства и аккаунт — в корне, ничего важного глубже второго уровня.

```
[Шапка: аватар · Имя · телефон · @username · about · QR · «Изменить»]
[Поиск настроек]

Аккаунт                     Номер, имя, Nios ID
Устройства                  Активные сеансы и привязанные устройства
Уведомления и звуки         Чаты, звонки, превью, звук, исключения
Приватность и безопасность  Видимость, блокировки, код-пароль, шифрование
Чаты                        Ввод, реакции, папки, архив, обои
Оформление                  Тема, палитра, шрифт, плотность
Данные и хранилище          Кэш, автозагрузка, трафик, прокси
Язык                        Русский
Nios+                       Подписка и NiosAI

Помощь и о приложении       FAQ, поддержка, документы, диагностика, версия

[Выйти]
```

Почему именно так (сверка с эталоном):
- «Аккаунт» + «Устройства» двумя строками — Telegram (`SettingsActivity.java:798, 804`) и Signal (`ROW_ACCOUNT`, `ROW_LINKED_DEVICES`); WhatsApp держит и то и другое в корне.
- «Язык» отдельной строкой со значением — Telegram 806 и WhatsApp «App language».
- «Данные и хранилище» — дословно как TG/Signal, вместо «память».
- «Оформление» отдельно от «Чатов» — Signal (Appearance) и новый WhatsApp (Appearance); Telegram ошибочно смешал в «Настройки чатов».
- Одна коммерческая строка вместо шести — антипример Telegram.

Подэкраны:

**Аккаунт**
1. Профиль: имя, username, телефон, about, дата рождения, аватар, QR, поделиться.
2. Безопасность входа: двухэтапная проверка (in-app), passkey, e-mail для восстановления, «Завершить все сеансы» (ссылка на «Устройства»).
3. Данные аккаунта: экспорт информации, удалить аккаунт (опасная зона, с подтверждением).

**Устройства**
Текущее устройство · Другие сеансы (платформа, место, последняя активность) · «Завершить все другие» · «Привязать устройство» (QR).

**Уведомления и звуки**
- Сообщения: личные · группы · каналы · реакции/упоминания.
- Звонки: рингтон, вибрация.
- В приложении: звук, вибрация, превью, всплывающее.
- События: контакт присоединился, закреплённые сообщения.
- Исключения (чаты/контакты, у которых свои настройки).
- Надёжность: фоновое соединение, оптимизация батареи (перенос из «Энергосбережения»).
- Сброс всех уведомлений.

**Приватность и безопасность**
1. Кто видит: последняя активность/онлайн, фото, about, ДР, подарки, музыка, пересылка, голосовые, звонки, приглашения (+ «Всегда/Никогда»).
2. Сообщения: отчёты о прочтении, индикатор набора, автоудаление по умолчанию.
3. Блокировки: чёрный список.
4. Безопасность: код-пароль/биометрия + автоблокировка, скрытие содержимого в переключателе, запрет скриншотов, инкогнито-клавиатура (если появится).
5. Шифрование: секретные чаты, ключ устройства, отпечаток, «как это работает».

**Чаты**
- Ввод: отправка по Enter, Enter = перенос строки.
- Реакции: быстрая реакция.
- Медиа: автовоспроизведение стикеров/эмодзи/GIF/видео, превью ссылок, сохранение в галерею.
- Список чатов: папки, архив, «оставлять заглушённые в архиве», «архивировать незнакомцев».
- Обои и тема чата (вход в `WallpaperStudioScreen`).

**Оформление**
Тема (система/светлая/тёмная) · палитра/системные цвета · стиль палитры · размер текста · плотность/компакт · скругления (в «Дополнительно»).

**Данные и хранилище**
Занято всего + разбивка · очистка кэша/черновиков/секретного кэша · автозагрузка (Wi-Fi/моб./роуминг × фото/видео/файлы/аудио) · качество отправки · «меньше данных в звонках» · трафик · прокси.

**Язык**
Русский/English/Системный · формат времени и часовой пояс — «Дополнительно» внутри.

**Nios+**
Статус · тарифы · что входит · AI-лимиты · триал.

**Помощь и о приложении**
FAQ · поддержка/баг · документы · что нового · команда · диагностика (бывшая «Система и устройство») · сбросить настройки · версия.

**Внизу** — «Выйти» (как у WhatsApp: выход в конце списка, а не в шапке).

Что переносим и что удаляем из текущего:
- `system_device` → внутри «Помощи», маршрут `/settings/system-device` убрать из публичных.
- `energy_saving` → остаётся, но только «Анимации/производительность»; фоновый режим уходит в «Уведомления».
- `language_region` → «Язык», часовой пояс в «Дополнительно».
- `preferences` → переименовать в `notifications` (id и section).
- `account` → вернуть в корень, наполнить (2FA, экспорт, удаление).
- `sessions` → отдельная строка корня.
- `appearance` → оставить как есть + строка «Обои».
- `chats` → убрать «устройства звонков», добавить архив/автоплей/галерею/обои.

---

## 7. Не проверено

1. **Порядок строк в корне WhatsApp.** Официального списка «сверху вниз» нет; собран из путей в справке + обзоров. Точный порядок (и наличие «Appearance» в стабильной сборке) — **не проверено**.
2. **WhatsApp `Appearance` как корневая строка.** Подтверждается обзорами 2026 и WABetaInfo, но официальная справка всё ещё пишет `Chats → Wallpaper`. Считать «переходным периодом» — **не проверено** на живом приложении.
3. **Наличие поиска по настройкам в WhatsApp** на обеих платформах — **не проверено** (в справке не описано).
4. **Точный порядок корня Telegram iOS.** Исходники корневого экрана iOS в открытом репозитории `TelegramMessenger/Telegram-iOS` я не нашёл (в `submodules/SettingsUI/Sources` только подэкраны; в `TelegramUI/Sources` и `Components/Settings` корневого контроллера нет). Список собран по FAQ/обзорам и памяти — **не проверено**.
5. **Signal iOS** — предполагается зеркальность с Android; исходники iOS не смотрел — **не проверено**.
6. **WhatsApp «Proxy»** в «Хранилище и данные» — по памяти, в справке не подтвердил — **не проверено**.
7. **MAX**: список разделов собран по трём обзорам (hi-tech.mail.ru, RBC, maxofficial.ru); официальной документации по структуре настроек нет, порядок — **не проверено**.
8. **Telegram «Энергосбережение» vs «Lite Mode»**: в коде `case 9 → LiteModeSettingsActivity`, строки — `SettingsPowerSaving`; как это подписано в русской локали сейчас — **не проверял** (в `values/strings.xml` только английский).
9. **Есть ли у Telegram поиск по FAQ в настройках на iOS** — по коду Android есть (`SettingsActivity.java:906-913`); iOS — **не проверено**.
10. **VK Мессенджер** не разбирал (роль допускала «по возможности»); в отчёт включён MAX как более релевантный российский пример.

### Источники (кроме нашего кода)

- Telegram Android: <https://github.com/DrKLO/Telegram> — `SettingsActivity.java`, `PrivacySettingsActivity.java`, `DataSettingsActivity.java`, `NotificationsSettingsActivity.java`, `LiteModeSettingsActivity.java`, `res/values/strings.xml`.
- Telegram iOS (частично): <https://github.com/TelegramMessenger/Telegram-iOS>, <https://telegram.org/faq>, <https://privacy.kaspersky.com/articles/telegram-iphone-medium>.
- Signal Android: <https://github.com/signalapp/Signal-Android> — `feature/app-settings/src/main/java/org/signal/appsettings/{home,appearance,chats,notifications,privacy,dataandstorage}`.
- WhatsApp Help Center: faq 3307102709559968, 1920866721452534, 1082491466048496, 227626810186044, 378279804439436, 647349420360876, 6298875896807790, 366146522333492, 5503646096388294, 779773243128935, 859053323029647; обзор Advanced: <https://www.makeuseof.com/dug-through-whatsapps-settings-found-surprisingly-useful-privacy-options>; темы: <https://wabetainfo.com/whatsapp-is-rolling-out-new-chat-themes-on-android-beta>, <https://www.nextpit.com/how-tos/whatsapp-chat-themes-messages-colors-how-to-use>.
- MAX: <https://hi-tech.mail.ru/articles/150486-nastrojki-v-makse>, <https://www.rbc.ru/life/news/69c29b389a794708413e7f7c>, <https://maxofficial.ru/blog/nastroyki-maks-messendzhera>.
