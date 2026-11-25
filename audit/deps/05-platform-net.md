# 05 — платформа, сеть, веб, звонки, идентификаторы, Firebase

Область: `pulse_flutter/lib`, `pulse_flutter/test`, `packages/nios_sdk`, `packages/nios_mls`,
`packages/nios_iroh`, `packages/nios_lab`. Считалось по grep: **файлов** — файлы с
`package:<pkg>/`; **обращений** — строки реального API (импорты не считаются). Версии и
обновления не проверялись. Игнорировались `*.g.dart`, `*.freezed.dart`,
`lib/l10n/secret/generated/**`, `build/`, `.dart_tool/`.

| пакет | файлов | обращений | где (топ-3) | вердикт |
|---|---|---|---|---|
| material_color_utilities | 2 | 4 | `lib/core/identity/nios_mark.dart:106,133,139` (`Hct.from`), `lib/core/theme/nios_chroma.dart:45` (`Blend.harmonize`) | нужен (прямой импорт, но узкий — 4 вызова) |
| uuid | 14 | 30 | `lib/services/secret_chat/secret_chat_engine.dart:42` (9 обращений), `lib/services/ordinary_e2ee/ordinary_e2ee_service.dart:1060`, `lib/core/network/web_socket_client.dart:608` | нужен |
| flutter_m3shapes | 10 (9 lib + 1 test) | 135 | `lib/widgets/wallpaper/curated_wallpaper_catalog.dart:12` (108 имён `Shapes.*`), `lib/core/identity/nios_mark.dart:8` (канон 10 форм), `lib/widgets/wallpaper/chat_wallpaper_painter.dart:565` | нужен |
| web_socket_channel | 6 | 27 | `lib/services/calls/ws_transport.dart:4`, `lib/services/calls/webrtc_signaling_client.dart:4`, `lib/core/network/web_socket_client.dart:9` | нужен; внимание: под WASM выбирается `ws_stub` |
| web | 8 (6 lib + 2 test) | 92 (45 lib + 47 test) | `lib/core/clipboard/file_drop_web.dart:4`, `lib/core/media/browser_playback_web.dart:4`, `lib/services/calls/microphone_meter_web.dart:4` | нужен; внимание: два web-файла всё ещё на `dart:html` |
| universal_io | 133 (41 lib + 54 test + 38 packages) | ≈600 | `lib/main.dart:11`, `lib/core/storage/local_storage_service.dart:1`, `lib/core/worker/headless_core_isolate.dart:9` | нужен |
| path | 15 (3 lib + 12 test/packages) | 150 (34 в lib) | `lib/services/protocol/nios_protocol_accounts.dart:15` (18 вызовов `p.*`), `lib/services/secret_chat/secret_stream_service.dart:9` (12), `lib/core/storage/local_storage_service.dart:6` (4) | нужен |
| flutter_webrtc | 12 (9 lib + 3 test) | 99 | `lib/services/calls/webrtc_call_session.dart:8` (44 обращения), `lib/providers/call_session_provider.dart:7`, `lib/services/calls/call_devices.dart:3` | нужен |
| motor | 9 (8 lib + 1 test) | ≈35 | `lib/core/motion/m3_motion.dart:2` (`SpringMotion` ×12), `lib/core/motion/nios_dismissible.dart:4`, `lib/widgets/chat/bubble/bubble_gestures.dart:4` | нужен (не дубль `M3SpringCurves` — разные роли) |
| firebase_core | 2 | 15 | `lib/main.dart:26,261` (`Firebase.initializeApp`), `lib/firebase_options.dart:3` (`FirebaseOptions`) | нужен |

Нативно (для полноты): `android/.../GeneratedPluginRegistrant.java:74` — `FlutterFirebaseCorePlugin`,
`:119` — `FlutterWebRTCPlugin`; `windows/flutter/generated_plugins.cmake:12` — `firebase_core`,
`:14` — `flutter_webrtc`. Остальные восемь пакетов этой группы — чисто Dart, нативной
регистрации не требуют (`universal_io`, `path`, `uuid`, `web`, `web_socket_channel`,
`material_color_utilities`, `flutter_m3shapes`, `motor`).

## Отдельный вопрос 1: `material_color_utilities` — напрямую или только через `dynamic_color`?

**Напрямую, но всего четырьмя вызовами.** Всё использование:

- `lib/core/identity/nios_mark.dart:106` — `Hct.from(hue, 44.0, tone).toInt()` (цвет аватара);
- `lib/core/identity/nios_mark.dart:133` — `Hct.from(hue, 50.0, tone)` (основной цвет метки);
- `lib/core/identity/nios_mark.dart:139` — `Hct.from(accentHue, 45.0, tone)` (акцент метки);
- `lib/core/theme/nios_chroma.dart:45` — `Blend.harmonize(partnerArgb, userPrimaryArgb)`.

Формулировка задачи («в проекте уже есть CAM16-код в `NiosChroma`») **не подтверждается**: grep по
`CAM16`/`Cam16` даёт ровно два результата, и оба — комментарии
(`lib/screens/calls/active_video_call_screen.dart:57`, `active_voice_call_screen.dart:62`).
`NiosChroma` (`lib/core/theme/nios_chroma.dart:9,45`) не считает CAM16 сам: он зовёт
`Blend.harmonize` из этого пакета и затем `ColorScheme.fromSeed`
(`:52`, CAM16 внутри Flutter). Своего HCT/CAM16-кода в проекте нет.

Вывод: пакет **не «только транзитивно»**. `dynamic_color` его и так тянет (зависит от
`material_color_utilities ^0.13.0`), но
`Hct` и `Blend.harmonize` — единственный источник тональной гармонизации в приложении; при удалении
придётся либо писать CAM16 вручную (и это будет уже настоящий дубль), либо терять
`Blend.harmonize` в Chroma. Удалять не надо, но стоит помнить: цена — 4 вызова на весь `lib/`.

## Отдельный вопрос 2: `web` и `path` — прямые импорты или транзитив?

Оба **прямые**:

- `web`: 6 файлов в `lib/`, все — реализация под `if (dart.library.js_interop)`, плюс 2 файла
  chrome-тестов. `web.` — 45 обращений в lib (`HTMLCanvasElement`, `Blob`, `URL`, `AudioContext`,
  `DataTransfer`, `Notification`, `navigator.mediaDevices`), 47 в test. Пакет приходит ещё и
  транзитивно (flutter_webrtc зависит от `web ^1.0.0`), но раз есть прямые импорты, объявление
  обязательно.
- `path`: 3 файла в `lib/` (34 вызова `p.join`/`p.dirname`/`p.basename`/`p.extension`), 12 файлов в
  тестах и локальных пакетах (`nios_sdk` и `nios_iroh` объявляют его сами у себя в pubspec).
  Транзитивно он и так есть (через `path_provider`, `flutter_cache_manager` и т.д.), но импорт
  прямой — значит объявление нужно.

**Внимание по `web`: смешаны два поколения web-API.** Шесть `_web.dart` уже на
`package:web` + `dart:js_interop`, а два — на устаревшем `dart:html` с
`// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter`:

- `lib/core/network/oauth_navigation_helper_web.dart:1-2` (`html.window.location`, `history.replaceState`);
- `lib/core/storage/ephemeral_storage_web.dart:1-2` (`html.window.sessionStorage`).

Плюс в родительских файлах этих двух остался устаревший ключ условного импорта
`dart.library.html` (`oauth_navigation_helper.dart:2`, `ephemeral_storage.dart:2`), тогда как
остальные используют `dart.library.js_interop`
(например `core/media/browser_playback_web.dart`, `core/clipboard/file_drop_web.dart:2`).

Практическое следствие: `dart.library.html` **false в dart2wasm**. При wasm-сборке подменяются на
заглушки не только эти два файла, но и `lib/core/network/ws_io.dart` → `ws_stub.dart`
(`web_socket_client.dart:10-12`), то есть **все сокеты начинают кидать**
`UnsupportedError('Cannot create websocket without dart:html or dart:io')`. CI собирает web в JS,
поэтому сейчас не стреляет; при переходе на wasm это блокер.

## Отдельный вопрос 3: `dart_webrtc` vs `flutter_webrtc` — кто реально в коде

**Реально работает `flutter_webrtc`**: 12 файлов, 99 обращений — `createPeerConnection`,
`RTCPeerConnection`, `RTCSessionDescription`, `RTCVideoRenderer` (`webrtc_call_session.dart:47,48`),
`navigator.mediaDevices.getUserMedia` (`:216`), `createPeerConnection` (`:288`),
`Helper.selectAudioOutput` / `setSpeakerphoneOn` / `clearAndroidCommunicationDevice`
(`lib/services/calls/call_devices.dart:62,66,68`), `RTCVideoView` в экранах звонка.

`dart_webrtc` используется **одним типом** — `MediaStreamWeb`, ради каста на web:
`lib/services/calls/microphone_meter_web.dart:5,35` (`(stream as MediaStreamWeb).jsStream`) и
`test/web/browser_workspace_calls_test.dart:11,235,265`. Больше ничего.

Почему прямое объявление оправдано: `flutter_webrtc` зависит от `dart_webrtc ^1.8.0`
(проверено по pub API), но `MediaStreamWeb` **не реэкспортирует** — в списке экспортов
`flutter_webrtc` такого имени нет. Убрать `dart_webrtc` из pubspec и оставить импорт — нарушение
`depend_on_referenced_packages`, убрать импорт — каст перестанет компилироваться. Так что:
`flutter_webrtc` — нужен, `dart_webrtc` — нужен, но помечен как «объявлен ради одного типа и одного
каста»; альтернатива без пакета — брать `jsStream` через `dart:js_interop`
(`(stream as JSObject).getProperty('jsStream')`).

## Отдельный вопрос 4: `motor` — сколько мест реально использует пружины пакета

Цифры по `lib/` и `test/`:

| что | файлов | обращений |
|---|---|---|
| `motor` (`SingleMotionController` 23, `SpringMotion` 12) | 9 | ≈35 |
| свои `M3SpringCurves` (`core/motion/m3_spring_constants.dart`) | 93 | 259 |
| свои `M3Durations` | — | 239 |
| свои `M3Spring` (`SpringDescription`) | — | 37 |

То есть **пружины пакета — это 8 файлов в `lib/`** (`m3_motion.dart`, `nios_dismissible.dart`,
`calls/active_video_call_screen.dart`, `widgets/calls/call_overlay.dart`,
`chat/expression_panel_frame.dart`, `chat/reorder_slide.dart`, `chat/swipe_action_row.dart`,
`chat/bubble/bubble_gestures.dart`) плюс тест `test/unit/m3_motion_test.dart`. Свои кривые — в 93
файлах, на порядок больше.

Дублем это не является, роли разделены явно и осознанно:

- `motor` берут там, где жест передаёт скорость и цель может смениться на лету —
  `SwipeActionRow` («возвратная пружина стартует со скоростью пальца»,
  `lib/widgets/chat/swipe_action_row.dart:13-14`), `bubble_gestures.dart`,
  `NiosDismissible` (передача `primaryVelocity` в пружину, `nios_dismissible.dart:22-27`),
  `reorder_slide.dart`, `call_overlay.dart`.
- `M3SpringCurves` берут там, где API принимает только `duration` + `curve`
  (`AnimatedContainer`, `AnimationController`, `AnimatedScale`) — их 93 файла.

Физика не дублируется: `lib/core/motion/m3_motion.dart:11-38` строит `SpringMotion` из **тех же**
`M3Spring.spatialFast/...` (`SpringDescription` с stiffness/damping из
`m3_spring_constants.dart:12-50`). Один набор констант, два способа его проиграть. Единственное, что
можно сказать против: `motor` — тонкий слой (≈35 обращений на 8 файлов), и его единственная
незаменимая функция — сохранение скорости при ретаргете; всё остальное закрывают свои кривые.

## Что стоит удалить/заменить

1. **`dart:html` в двух файлах — перевести на `package:web`.** `oauth_navigation_helper_web.dart:1-2`
   и `ephemeral_storage_web.dart:1-2` после перевода потеряют оба `ignore_for_file`, а вместе с ними
   уйдёт и `dart.library.html` в родительских файлах (`oauth_navigation_helper.dart:2`,
   `ephemeral_storage.dart:2`) — сейчас именно из-за этого ключа под dart2wasm подставляется
   `ws_stub.dart` и ломаются сокеты. Правка косметическая по объёму (≈30 строк) и снимает
   wasm-блокер.
2. **`dart_webrtc` — оставить, но зафиксировать причину в pubspec-комментарии.** Он объявлен ради
   `MediaStreamWeb` в `microphone_meter_web.dart:5`, и при следующем рефакторинге web-метра его
   легко удалить «как транзитив», после чего каст перестанет компилироваться. Альтернатива —
   `jsStream` через `js_interop` и минус одна прямая зависимость.
3. **`firebase_core` инициализируется не везде, а плагин собирается везде.**
   `lib/main.dart:258-263` вызывает `Firebase.initializeApp` только при
   `kIsWeb || Platform.isAndroid || Platform.isIOS`, а `windows/flutter/generated_plugins.cmake:12`
   всё равно линкует `firebase_core` в Windows-сборку. Либо инициализировать и на десктопе, либо
   осознанно принять «мёртвый нативный плагин» в установщике (то же касается
   `firebase_messaging`, но он не в этой группе).
4. **`web_socket_channel` один, а WS-обвязок три.** `lib/core/network/web_socket_client.dart`
   (свой backoff и «retire по epoch»: `:112,232,265,287-295`), `lib/services/calls/webrtc_signaling_client.dart`
   и `lib/services/calls/ws_transport.dart` (свой протокол кадров для SFU). Это разные бэкенды
   (основной API / сигналинг звонка / медиаплоскость), поэтому не дубль пакета, но три набора
   «connect/close/ошибка» — кандидат на один транспортный слой поверх `WebSocketChannel`.
5. **`ws_stub.dart` — не заглушка «на всякий случай», а активная ветка под wasm.** Пока ключ
   `dart.library.html` не заменён на `dart.library.js_interop`, файл остаётся единственным, что
   подключится в wasm-сборке. После правки из п.1 заглушка станет действительно мёртвой и её можно
   оставить только как защиту от экзотических платформ.
