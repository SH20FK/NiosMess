Полный аудит проекта — 100+ пунктов
КРИТИЧЕСКИЕ БАГИ
1. Утечка памяти в pulse_avatar.dart — ImageStreamListener не хранится в поле, removeListener создаёт новый экземпляр → старый listener никогда не отписывается, накапливаются утечки при каждом rebuild
2. Фейковый mounted в search_provider.dart:106 — bool get mounted => true перекрывает реальный mounted из AsyncNotifier, проверки mounted бесполезны → возможен setState() during build
3. Гонка ключей в encrypted_message_cache.dart:16-36 — _getOrCreateKey() async, при параллельных вызовах два потока создают разные ключи → одно зашифрованное сообщение становится нечитаемым
4. Реконнект WebSocket после close() в web_socket_client.dart:134 — таймер _scheduleReconnect не отменяется при вызове close() → WebSocket переподключается после логаута
5. connectivity_provider.dart:9 — инвертированная семантика — true = "нет сети", false = "есть сеть" → все вызывающие стороны логически перевёрнуты
6. downloadMedia в chat_repository.dart:732-761 — обходит ApiClient, не использует перехватчик 401, токен передаётся в теле вместо Bearer-заголовка
7. jelly_switch.dart:86-91 — двойное срабатывание — onTap и onPanEnd оба вызывают _toggle(), быстрый тап переключает значение дважды → возврат к исходному состоянию
8. progress.clamp(0, 1) в file_upload_progress_widget.dart:96 — clamp с int аргументами возвращает num, а не double → возможна ошибка типа
БАГИ / НЕКОРРЕКТНОСТЬ
9. l10n.dart:5 — краш при отсутствии Localizations — AppLocalizations.of(this)! бросает Null check operator если виджет вне дерева локализации
10. bot_repository.dart:34,47 — мёртвый параметр botToken — параметр принимается но не используется в WebSocket-запросе, вызывающие думают что авторизация происходит через токен
11. app_sound.dart:93-95 — playUiTick — пустой метод — принимает параметр, возвращает Future, но ничего не делает
12. app_resume_provider.dart:43-49 — setLastRoute и clear — заглушки — вызываются при логауте но не делают ничего, мёртвый код
13. backend_chat_provider.dart:331 — коллизия ID — DateTime.now().millisecondsSinceEpoch как ID оптимистичного сообщения → при двух отправках в ту же миллисекунду один сообщение удаляется
14. backend_chat_provider.dart:387-419 — ручное копирование ApiMessage — при ошибке отправки все 15+ полей копируются вручную → при добавлении нового поля оно будет потеряно
15. ui_settings_provider.dart:126-128 — async _load() без await — build() вызывает async метод без await → начальный рендер с дефолтами, ошибки теряются
16. cache_service.dart:16 — Hive.initFlutter() без guard — повторный вызов может бросить HiveError: Already initialized
17. sound_service.dart:134-153 — initialize() без await — если инициализация упадёт, ошибка проглочена; race между dispose и init
ГОНКИ СОСТОЯНИЙ / CONCURRENCY
18. web_socket_client.dart:88 — StreamSubscription не сохраняется — при close() или реконнекте старая подписка не отменяется явно
19. web_socket_client.dart:47 — _pendingRequests растёт бесконечно — при медленном сервере map накапливает записи без лимита
20. backend_chat_provider.dart:36-45 — кеш загружается синхронно в async build() — установка state до завершения future, нестандартный паттерн для AsyncNotifier
ОШИБКИ ОБРАБОТКИ
21. api_client.dart:254-260 — проверка типа через строку — error.runtimeType.toString() == 'SocketException' хрупко и может совпасть с посторонними типами
22. web_socket_client.dart:362-364 — нет проверок при парсинге зашифрованных сообщений — data['ciphertext'] без null/type-check → TypeError при повреждённых данных
23. encrypted_message_cache.dart:85-88 — нет bounds-checking — sublist при повреждённых данных бросает RangeError
24. m3_file_preview_bottom_sheet.dart:203-208 — stale context после pop — Navigator.of(context).push() после pop() bottom sheet → context может быть unmounted
25. m3_file_preview_bottom_sheet.dart:407-408 — нет таймаута на скачивание — http.Client().send() без timeout → бесконечное зависание при медленном сервере
26. m3_file_preview_bottom_sheet.dart:560-563 — нет try/catch на воспроизведение аудио — _player.play() может бросить при ошибке сети/файла
27. chat_creation_surfaces.dart:27 — username не URL-кодируется — context.push('/chat/dm/$username') сломается при спецсимволах в username
УТЕЧКИ ПАМЯТИ / РЕСУРСЫ
28. chat_creation_surfaces.dart:10 — TextEditingController не dispose — создаётся в builder диалога, никогда не освобождается
29. adaptive_polling.dart:99-103 — RouteAware без подписки — миксин добавлен но RouteObserver не зарегистрирован → callback'и никогда не вызываются
30. app_sound.dart:119-125 — последовательный dispose без try/catch — если _effectPlayer.dispose() бросит, остальные плееры не освобождаются
31. pulse_avatar.dart:160 — ImageStreamListener не == comparible — каждое addListener/removeListener создаёт новый экземпляр → remove не работает
ДУБЛИРОВАНИЕ КОДА
32. asStringMap скопирован 7 раз — api_client.dart, web_socket_client.dart, chat_repository.dart, call_repository.dart, bot_repository.dart, auth_repository.dart, admin_repository.dart
33. _getIconData / _getFileIcon скопирован 4 раза — message_bubble.dart, m3_file_preview_bottom_sheet.dart, file_upload_progress_widget.dart, file_attachment_chip.dart
34. Дублирование градиентов — AppColors.heroGradient и AppTheme.heroGradient() — одно имя, два определения
ЗАГЛУШКИ / МЁРТВЫЙ КОД
35. app_sound.dart:93-95 — playUiTick — пустой метод (дубль с #11)
36. app_resume_provider.dart:43-49 — setLastRoute и clear — заглушки (дубль с #12)
37. pulse_scaffold_body.dart:1 — unused import package:universal_io/io.dart
38. badge_chip.dart:141 — параметр color принят но никогда не используется — всегда scheme.primary
УСТАРЕВШИЕ API
39. ws_web.dart:2 — dart:html deprecated — нужно мигрировать на package:web
40. token_provider.dart:2 — import flutter_riverpod/legacy.dart — не нужен, StateProvider доступен напрямую
БЕЗОПАСНОСТЬ
41. admin_repository.dart — admin пароль в открытом виде в payload — передаётся как plaintext в каждом WebSocket-запросе, логируется через debugPrint
42. web_socket_client.dart:294 — логирование JSON запросов — потенциально чувствительные данные в debug-логах
43. auth_repository.dart:220 — session ID как строка — sessionId.toString() вместо int, несогласованность с остальным API
ЛОКАЛИЗАЦИЯ — ХАРДКОД СТРОК
44. m3_file_preview_bottom_sheet.dart:115 — 'Save' не локализовано
45. m3_file_preview_bottom_sheet.dart:119 — 'Link' не локализовано
46. m3_file_preview_bottom_sheet.dart:127 — 'Open' не локализовано
47. m3_file_preview_bottom_sheet.dart:134 — 'Forward' не локализовано
48. m3_file_preview_bottom_sheet.dart:164 — 'File name' не локализовано
49. m3_file_preview_bottom_sheet.dart:169 — 'Close' не локализовано
50. m3_file_preview_bottom_sheet.dart:309 — 'Link copied to clipboard' не локализовано
51. m3_file_preview_bottom_sheet.dart:312 — 'File path copied to clipboard' не локализовано
52. m3_file_preview_bottom_sheet.dart:433 — 'File saved' не локализовано
53. m3_file_preview_bottom_sheet.dart:438 — 'Could not save file: $error' не локализовано
54. m3_file_preview_bottom_sheet.dart:507,582 — 'Pause'/'Play' не локализовано
55. m3_file_picker_bottom_sheet.dart:83 — 'Gallery' не локализовано
56. m3_file_picker_bottom_sheet.dart:91 — 'Document' не локализовано
57. m3_file_picker_bottom_sheet.dart:103 — 'Audio' не локализовано
58. m3_file_picker_bottom_sheet.dart:111 — 'File' не локализовано
59. m3_file_picker_bottom_sheet.dart:61 — 'Could not read selected file' не локализовано
60. message_bubble.dart:408 — 'Image unavailable' не локализовано
61. offline_banner.dart:33 — 'Ожидание сети...' — хардкод на русском
62. fluid_preview_card.dart:149 — 'SH20FK' — хардкод юзернейма
63. fluid_preview_card.dart:183 — 'Оформление M3 Expressive' — хардкод на русском
64. fluid_preview_card.dart:191 — 'Новые индикаторы...' — хардкод на русском
65. fluid_preview_card.dart:215-223 — 'SH20FK'/'@sh20fk' — хардкод юзернеймов
66. settings_ui.dart:544 — cancelLabel = 'Cancel' — дефолт на английском
67. settings_ui.dart:658 — 'Revoke session' не локализовано
68. badge_screen.dart — все строки 'Name', 'Description', 'Icon (emoji)', 'Color (hex)', 'User ID', 'Badge ID' — хардкод
69. bot_screen.dart — 'Bot Name', 'Username', 'Description (optional)', 'Enter bot token' — хардкод
70. profile_screen.dart:56 — 'Avatar updated' не локализовано
71. profile_screen.dart:61 — 'Error: $e' не локализовано
ХАРДКОД ЦВЕТОВ
72. profile_header_delegate.dart:188 — Colors.white в CircularProgressIndicator — не адаптируется к теме
73. message_bubble.dart:122 — Colors.black.withValues(alpha: 0.04) — тень не адаптируется к dark/light
74. animated_background_blobs.dart — вложенные Scaffold визуально артефактят
75. animated_mesh_background.dart:54-66 — вложенные Scaffold аналогично
ДОСТУПНОСТЬ (A11Y)
76. gooey_segment.dart — нет Semantics меток на сегментах
77. jelly_switch.dart — нет Semantics для состояния toggle
78. app_bottom_nav.dart — нет Semantics для иконок навигации
79. message_context_menu_sheet.dart:176-178 — InkWell без borderRadius → прямоугольный ripple
80. message_bubble.dart — нет альтернативного текста для изображений
НЕКОНСИСТЕНТНЫЕ ОТСТУПЫ / РАЗМЕРЫ
81. profile_header_delegate.dart:61 — магическое число collapsedAvatarLeft = 16
82. profile_header_delegate.dart:275 — магическое число left: 64
83. profile_header_delegate.dart:280 — магическое число screenWidth - 140
84. liquid_logout_tile.dart:86-87 — магические числа left: -50, top: -50, bottom: -50
85. animated_mesh_background.dart:80-89 — магические числа 100, 120, 150, 80, 70
86. gooey_segment.dart:121 — хардкод fontSize: 12 вместо textTheme
ОТСУТСТВУЮЩИЕ АНИМАЦИИ
87. chat_tile.dart — нет анимации раскрытия long-press меню
88. message_context_menu_sheet.dart — нет анимации появления реакций
89. settings_ui.dart — нет анимации переключения SettingsSwitchTile
90. badge_chip.dart — нет анимации появления бейджа
91. file_attachment_chip.dart — нет анимации удаления аттачмента
ПЛОХИЕ LOADING / EMPTY СОСТОЯНИЯ
92. chat_detail_screen.dart — нет skeleton-загрузки для сообщений при первом входе
93. contacts_screen.dart — нет pull-to-refresh
94. public_profile_screen.dart — нет skeleton для профиля
95. sessions_screen.dart — нет skeleton для списка сессий
96. badge_screen.dart — нет skeleton для списка бейджей
МАЛЫЕ TOUCH TARGETS
97. message_context_menu_sheet.dart — кнопки реакций слишком малы (< 44px)
98. chat_tile.dart — область long-press не визуально обозначена
99. settings_ui.dart — SettingsTile subtitle текст слишком мелкий для тапа
100. post_comments_screen.dart — кнопка отправки комментария мала
DARK MODE ПРОБЛЕМЫ
101. animated_background_blobs.dart — вложенные Scaffold ломают тему
102. fluid_preview_card.dart:149 — хардкод текста не учитывает контраст dark mode
103. message_bubble.dart:122 — Colors.black тень невидима в dark mode
НЕКОНСИСТЕНТНАЯ ТИПОГРАФИКА
104. chat_tile.dart — textTheme.titleMedium для имени, но bodySmall для превью — разрыв размеров
105. settings_ui.dart — разнобой в titleLarge/titleMedium/bodyMedium для tile
106. badge_screen.dart — bodyLarge с fontWeight: w600 для badge name — нестандартно
ОТСУТСТВУЮЩИЙ HAPTIC FEEDBACK
107. jelly_switch.dart — нет тактильной отклика при переключении
108. chat_list_screen.dart — нет haptic при pull-to-refresh
109. message_bubble.dart — нет haptic при long-press
110. app_bottom_nav.dart — нет haptic при переключении вкладок
111. settings_ui.dart — нет haptic при SettingsSwitchTile
ПРОБЛЕМЫ С МАЛЫМИ ЭКРАНАМИ
112. chat_detail_screen.dart — панель ввода может перекрываться клавиатурой на маленьких экранах
113. create_chat_screen.dart — форма создания чата не скроллируется
114. settings_about_screen.dart — контент обрезается на экранах < 360px
ПРОИЗВОДИТЕЛЬНОСТЬ
115. api_client.dart:222-231 — compute() для JSON decode добавляет overhead isolate для маленьких ответов
116. active_color_orb.dart:59-62 — ColorScheme.fromSeed() в build() на каждый rebuild — тяжёлые вычисления HCT
117. animated_background_blobs.dart:76 — sigmaX: 85, sigmaY: 85 — очень дорогой blur для低端设备
118. animated_mesh_background.dart:149 — аналогично sigmaX: 85, sigmaY: 85
119. pulse_loading_indicator.dart:28-29 — анимация крутится бесконечно даже когда off-screen
ОБЩАЯВот полный аудит проекта — 137 пунктов по категориям:
---
🔴 КРИТИЧЕСКИЕ БАГИ (8)
1. pulse_avatar.dart — утечка памяти ImageStreamListener не ==-сравним, removeListener создаёт новый экземпляр — старый listener никогда не отписывается, накапливается
2. search_provider.dart:106 — фейковый mounted геттер bool get mounted => true перекрывает настоящий из AsyncNotifier — проверка if (seq == _seq && mounted) бесполезна, может вызвать setState during build
3. connectivity_provider.dart:9 — инвертированная семантика true = "нет сети", false = "сеть есть" — запутанно, вызовет баги в местах использования
4. backend_chat_provider.dart:331 — коллизия ID DateTime.now().millisecondsSinceEpoch как tempId — два сообщения в ту же миллисекунду получат одинаковый ID, первый success удалит оба placeholder'а
5. encrypted_message_cache.dart:16-36 — race condition на ключе два одновременных вызова _getOrCreateKey() оба увидят _cachedKey == null и создадут разные ключи — один перезапишет другой в SecureStorage, сообщения станут невосстанавливаемыми
6. chat_repository.dart:732-761 — downloadMedia обходит авторизацию использует raw http.post вместо ApiClient, токен передаётся в JSON body вместо Bearer header — 401 не обрабатывается
7. web_socket_client.dart:134 — reconnect timer не отменяется при close() после logout таймер срабатывает и переподключает WebSocket
8. l10n.dart:5 — краш без Localizations AppLocalizations.of(this)! — force-unwrap упадёт если контекст вне subtree
---
🟠 ГЛУБОКИЕ БАГИ (12)
9. badge_chip.dart:141,221 — параметр color полностью игнорируется принимается в конструкторе, но effectiveColor = scheme.primary хардкодится
10. jelly_switch.dart:86-91 — двойной toggle onTap + onPanEnd оба вызывают _toggle() — быстрый тап может сработать оба, значение вернётся обратно
11. file_upload_progress_widget.dart:96 — progress.clamp(0, 1) clamp с int аргументами на double возвращает num — LinearProgressIndicator.value ожидает double?
12. bot_repository.dart:34,47 — мёртвый параметр botToken принимается но никогда не отправляется в payload
13. app_resume_provider.dart:43-49 — пустые методы setLastRoute() и clear() ничего не делают, вызываются при logout
14. app_sound.dart:93-95 — playUiTick — no-op принимает параметр, возвращает Future, но ничего не делает
15. ui_settings_provider.dart:126 — async _load() не awaited в sync build() при первом рендере показываются дефолты, потом мигает реальный темп
16. backend_chat_provider.dart:387-419 — ручное копирование ApiMessage при ошибке отправки поля копируются вручную — при добавлении нового поля в модель оно будет упущено
17. local_storage_service.dart:142-147 — prefs.getString(key) без присваивания итерация по черновикам ничего не делает
18. app_sound.dart:119-125 — partial dispose если _effectPlayer.dispose() упадёт, _uiPlayers и _loopPlayer не освободятся
19. ws_web.dart:2 — dart:html deprecated должен мигрировать на package:web
20. web_socket_client.dart:88 — stream subscription не сохраняется при close() или реконнекте старая подписка не отменяется явно
---
🟡 ГОНОЧНЫЕ УСЛОВИЯ И ПАМЯТЬ (7)
21. web_socket_client.dart — reconnect после logout таймер не отменяется в close()
22. encrypted_message_cache.dart — два потока создают разные ключи нет lock/Completer
23. cache_service.dart:16 — Hive.initFlutter() без guard повторный вызов может крашнуть
24. adaptive_polling.dart:99 — RouteAware mixin без подписки dead code
25. sound_service.dart:134 — async init не awaited в Provider race между init и dispose
26. pulse_avatar.dart:160 — listener leak при смене URL каждый URL change создаёт новый listener без отписки старого
27. m3_file_preview_bottom_sheet.dart:203,287 — stale context Navigator.of(context).push() после pop() — context может быть detached
---
🔵 ОШИБКИ ОБРАБОТКИ (8)
28. api_client.dart:254 — проверка типа через runtimeType.toString() хрупко, ломается на web
29. web_socket_client.dart:362-364 — нет null-check на ciphertext, iv, tag краш при невалидном JSON
30. encrypted_message_cache.dart:85-92 — нет bounds check на sublist краш при битых данных
31. m3_file_preview_bottom_sheet.dart:407 — нет timeout на HTTP download зависает навсегда
32. m3_file_preview_bottom_sheet.dart:560 — нет try/catch на _player.play() краш при ошибке воспроизведения
33. chat_creation_surfaces.dart:27 — username не URL-encoded ломает маршрут при спецсимволах
34. admin_repository.dart — admin password в plaintext в каждом payload, в debug логах
35. auth_repository.dart:220 — sessionId.toString() int → String несоответствие типа
---
⚪ ДУБЛИРОВАНИЕ КОДА (10)
36. asStringMap скопирован 7 раз — api_client.dart, web_socket_client.dart, chat_repository.dart, call_repository.dart, bot_repository.dart, auth_repository.dart, admin_repository.dart
37. _getIconData / _getFileIcon скопирован 4 раза — message_bubble.dart, file_upload_progress_widget.dart, file_attachment_chip.dart, m3_file_preview_bottom_sheet.dart
38. _ExpressiveProfileFogPainter — дублирование AppColors.heroGradient и AppTheme.heroGradient оба определения градиента с одним именем
39. bot_screen.dart и badge_screen.dart — паттерн диалога с полями вынести в shared helper
40. Обработка ошибок API — try/catch + ScaffoldMessenger.showSnackBar повторяется в каждом экране
---
🔤 ЛОКАЛИЗАЦИЯ — ХАРДКОД СТРОК (35)
41. profile_screen.dart — 'Edit profile', 'Update your public name and short bio.'
42. m3_file_preview_bottom_sheet.dart — 'Save', 'Link', 'Open', 'Forward', 'File name', 'Close', 'Link copied to clipboard', 'File path copied', 'File saved', 'Could not save file:', 'Pause', 'Play'
43. m3_file_picker_bottom_sheet.dart — 'Gallery', 'Document', 'Audio', 'File', 'Could not read selected file'
44. offline_banner.dart — 'Ожидание сети...'
45. fluid_preview_card.dart — 'SH20FK', 'Оформление M3 Expressive', 'Новые индикаторы и плавные переходы...'
46. settings_ui.dart:544 — cancelLabel = 'Cancel' дефолт
47. settings_ui.dart:658 — 'Revoke session'
48. badge_chip.dart — hardcoded emoji reactions
49. message_bubble.dart:408 — 'Image unavailable'
50. message_context_menu_sheet.dart:54 — hardcoded reactions list ['👍', '❤️', '🔥', '😂', '🎉', '👎']
51. profile_header_delegate.dart:188 — Colors.white вместо scheme.onPrimary
---
🎨 UI/UX — ГРАФИЧЕСКИЕ ПРОБЛЕМЫ (25)
52. profile_header_delegate.dart:61,275,280 — magic numbers 16, 64, screenWidth - 140
53. settings_ui.dart:69 — maxWidth: 920 хардкод
54. animated_background_blobs.dart:47 — вложенный Scaffold
55. animated_mesh_background.dart:54 — вложенный Scaffold
56. animated_background_blobs.dart:76 — sigmaX: 85极度дорогой blur
57. active_color_orb.dart:59 — ColorScheme.fromSeed в build() на каждый rebuild — дорого
58. message_bubble.dart:122 — Colors.black.withValues(alpha: 0.04) не адаптируется к теме
59. gooey_segment.dart:121 — fontSize: 12 хардкод
60. gooey_segment.dart — нет Semantics для screen readers
61. message_context_menu_sheet.dart:176 — InkWell без borderRadius — ripple прямоугольный
62. file_attachment_chip.dart:25 — tap на remove button триггерит и outer onTap
63. pulse_scaffold_body.dart:84 — 80-секундная анимация фона — почти незаметна
64. Нет haptic feedback при отправке сообщения,长按 меню, переключении вкладок (12 мест)
65. Нет skeleton loading для экрана контактов
66. Нет empty state для поиска сообщений
67. Touch targets < 48dp в gooey_segment, badge_chip actions
68. chat_tile.dart — draft indicator визуально неотличим от обычного текста
69. Нет анимации перехода между вкладками bottom nav
70. Нет shimmer/skeleton при загрузке аватарок в чат-листе
71. Нет pull-to-refresh на экране контактов
72. Нет swipe-to-action на сообщениях (archive/delete)
73. Нет лоадера при первичной загрузке профиля — мигает дефолт
74. Нет toast/snackbar после копирования в буфер в chat_tile
75. Нет визуального фидбека при тапе на кнопку AI-трансформации
76. Нет progress indicator при загрузке изображений в CachedNetworkImage (только fade)
77. Нет анимации появления/исчезновения draft banner
78. Нет плавного перехода expanded → collapsed в profile header (рёбра видны)
79. Нет dark mode проверки в fluid_preview_card.dart — хардкод фона
80. Нет adaptive layout — на планшетах всё растянуто на всю ширину
81. Нет RTL поддержки — left: 16, right: 16 вместо start/end
---
♿ ДОСТУПНОСТЬ (8)
82. Нет Semantics label на аватарках в чат-листе
83. Нет Semantics label на кнопках AI-трансформации
84. Нет Semantics label на reaction chips
85. Нет Semantics label на кнопке camera overlay в profile header
86. Нет ExcludeSemantics на decorative fog painter
87. Нет Semantics на draft indicators
88. Нет Semantics на badge chips
89. Нет Semantics на file type indicators
---
🔒 БЕЗОПАСНОСТЬ (5)
90. Admin password в plaintext в каждом WebSocket payload (admin_repository.dart)
91. Admin password в debug логах — debugPrint логирует JSON с паролем
92. Bot token показывается в SnackBar — bot_screen.dart:65
93. Нет保护 на скриншоты для экрана 2FA / admin password
94. Weak login — нет minimum password length проверки на клиенте
---
🏗 АРХИТЕКТУРА И КАЧЕСТВО КОДА (15)
95. 7x дублирование asStringMap — вынести в shared utility
96. 4x дублирование _getIconData — вынести в file_type_detector.dart
97. Дублирование gradient — AppColors.heroGradient vs AppTheme.heroGradient
98. compute(jsonDecode) для маленьких JSON — overhead изолата > время парсинга
99. _pendingRequests растёт бесконечно — нет max limit
100. myChatRoleProvider возвращает 'member' пока грузится — прячет admin UI
101. FlutterSecureStorage как static const — дефолт protection level для ключей
102. Нет retry logic для API запросов — одна ошибка = пользователь видит ошибку
103. Нет offline queue для отправки сообщений
104. Нет optimistic concurrency для edit/delete операций
105. Нет pagination для списка сообщений (только infinite scroll)
106. Нет image compressor перед upload — большие фото загружаются как есть
107. Нет retry на WebSocket reconnect — один failure = 3 секунды и стоп
108. appResumeProvider — мёртвый класс, можно удалить
109. StateProvider в token_provider.dart — legacy паттерн в Riverpod 2+
---
📱 ПЛАТФОРМЕННЫЕ ПРОБЛЕМЫ (5)
110. dart:html deprecated — ws_web.dart мигрировать на package:web
111. Нет PopScope вместо WillPopScope (deprecated) — проверить все экраны
112. Нет safe area handling для chat_detail_screen — composer может залезть под notch
113. Нет AppLifecycleListener вместо WidgetsBindingObserver (deprecated)
114. Нет ImageFilter.compose — везде standalone BackdropFilter
---
⚡ ПРОИЗВОДИТЕЛЬНОСТЬ (5)
115. BackdropFilter sigma: 85 в animated_background_blobs и animated_mesh_background —极度дорогой на低端
116. ColorScheme.fromSeed в build() — active_color_orb.dart пересчитывает на каждый rebuild
117. Нет RepaintBoundary на message bubbles — перерисовка одного перерисовывает все
118. Нет AutomaticKeepAliveClientMixin для вкладок bottom nav — пересоздаётся при переключении
119. Нет const конструкторов в 10+ местах где возможно
---
🎯 МЕЛКИЕ ИСПРАВЛЕНИЯ (18)
120. pulse_avatar.dart:160 — listener leak (уже исправлено выше как #1)
121. profile_header_delegate.dart:299 — shouldRebuild не проверяет onEdit, onUploadAvatar
122. profile_header_delegate.dart:447 — reimplements dart:ui lerpDouble
123. chat_tile.dart:89-93 — long press callback вызывается до анимации expansion
124. message_bubble.dart:496-519 — _getFileIcon дублируется
125. color_ripple_overlay.dart:25 — unsafe cast as RenderBox без null check
126. liquid_logout_tile.dart:73 — missing const
127. jelly_switch.dart:121 — missing const
128. active_color_orb.dart:96 — missing const
129. pulse_button.dart:28 — extra space в CircularProgressIndicator( strokeWidth: 2)
130. search_provider.dart:35,78 — missing type annotations на for loop variables
131. local_storage_service.dart:78 — value.length * 2 неточный estimate байтов
132. file_type_detector.dart:177 — .gitignore → extension = "gitignore"
133. web_socket_client.dart:294 — debugPrint логирует чувствительные данные запросов
134. app_time.dart:47-49 — .toLocal() на уже local DateTime — no-op
135. call_provider.dart:5-9 — callableChatsProvider возвращает ВСЕ чаты без фильтрации
136. settings_ui.dart:649 — '$subtitle · $ip' middot хардкод
137. auth_repository.dart:220 — sessionId.toString() вместо native int
---
