# 03 — аудио, видео, просмотрщики, «мелочи ОС»

Пакеты: `audio_waveforms`, `photo_view`, `extended_image`, `chewie`, `camera`, `audioplayers`, `record`, `lottie`, `flutter_file_dialog`, `url_launcher`.
Считались только `*.dart` в `pulse_flutter/{lib,test,integration_test}` и `packages/`; `*.g.dart`, `*.freezed.dart`, `build/`, `.dart_tool/` игнорировались. В `packages/nios_sdk`, `packages/nios_mls` ни одного из этих пакетов нет.

| пакет | файлов | обращений | где (топ-3) | вердикт |
|---|---|---|---|---|
| audio_waveforms | 0 | 0 | только `pubspec.yaml:56` и `pubspec.lock:116` | **мёртвый** (но нативный плагин всё равно линкуется в APK/IPA — см. ниже) |
| photo_view | 2 | 7 | `lib/screens/media_viewer_screen.dart:768`, `lib/screens/dev/extended_image_demo_screen.dart:299` | **нужен**, но дублируется с `extended_image` и с `InteractiveViewer` |
| extended_image | 1 | 19 | `lib/screens/dev/extended_image_demo_screen.dart:264` (весь файл — сравнение движков) | **не используется**: только dev-демо + маршрут `/dev/image-viewer` |
| chewie | 4 | 17 | `lib/screens/media_viewer_screen.dart:213`, `lib/screens/native_file_viewer_screen.dart:1108`, `lib/widgets/media/m3_video_controls.dart:209` | **нужен** |
| camera | 4 + 1 тест | 73 | `lib/screens/circle_video_recorder_screen.dart` (32), `lib/services/calls/video_pipeline.dart` (18, мёртвый), `lib/widgets/quick_camera_capture_screen.dart` (15) | **нужен** (съёмка фото/кружков), но один из его потребителей — мёртвый дубль WebRTC |
| audioplayers | 2 | 46 | `lib/core/sound/app_sound.dart:201-310,430-583`, `lib/services/calls/output_tone_stub.dart:7-13` | **нужен** (другой класс задач, чем `just_audio`) |
| record | 1 | 9 | `lib/core/utils/voice_recorder_service.dart:10-88` | **нужен** |
| lottie | 3 | 38 (12 lib + 26 тест) | `lib/widgets/chat/noto_message_emoji.dart:18-126`, `lib/screens/onboarding_screen.dart:440`, `test/widgets/noto_message_emoji_test.dart` | **нужен** |
| flutter_file_dialog | 2 | 7 | `lib/screens/media_viewer_screen.dart:486,513`, `lib/widgets/m3_file_preview_bottom_sheet.dart:383,416` | **нужен**, **внимание**: плагин только Android/iOS, во втором файле нет платформенного гейта |
| url_launcher | 7 | 23 | `lib/core/services/app_url_launcher.dart:426-477`, `lib/core/utils/file_opener.dart:21,146`, `lib/widgets/chat/live_location_card.dart:171` | **нужен** |

Нативное подтверждение (без Dart-импорта): `windows/flutter/generated_plugin_registrant.cc:10,22,26` — `audioplayers_windows`, `record_windows`, `url_launcher_windows`; `android/app/src/main/AndroidManifest.xml:27-28` — `CAMERA`, `RECORD_AUDIO`, строки `100-115` — `<queries>` под `canLaunchUrl`; `test/widgets/circle_recorder_design_test.dart:21-60` мокает канал `plugins.flutter.io/camera`.

---

## Карта движков: где что живёт

### Аудио — три объявленных стека + один рекордер

**1. `just_audio` + `audio_session` — длинное воспроизведение (2 файла, ~20 обращений)**
- `lib/widgets/voice_message_player.dart:72` (`AudioPlayer(handleInterruptions: true)`), `:122-134` (`AudioSession.instance` + `AudioSessionConfiguration`), `:177-180` (`setAudioSource` с `AudioSource.uri`/`.file`), `:193` (`ProcessingState.completed`) — голосовые сообщения: перемотка, буферизация, реакция на прерывания.
- `lib/screens/native_file_viewer_screen.dart:1312-1353` — `_MusicPlayer` для аудиофайлов в просмотрщике.
- `audio_session` дополнительно в `lib/services/calls/webrtc_call_session.dart:6` (конфиг сессии под WebRTC).
- **Вердикт: другая задача, не дубль.** Это «медиаплеер с сессией и перемоткой».
- **Внимание:** у `just_audio` нет Windows-реализации (в pubspec пакета платформы только `android/ios/macos/web`, `just_audio_windows` в проекте не подключён). На Windows-сборке голосовые и аудиопревью в `native_file_viewer_screen` работать не будут, а `audioplayers` там работает (`audioplayers_windows` зарегистрирован).

**2. `audioplayers` — короткие звуки и пул плееров (2 файла, 46 обращений)**
- `lib/core/sound/app_sound.dart:201-204` — четыре пула (`_priorityPlayer`, `_effectPlayers`, `_uiPlayers`, `_loopPlayer`), `:216-227` общий `AudioContext`, `:256-259` `PlayerMode.mediaPlayer` + `ReleaseMode`, `:473`/`:550` `AssetSource` + `volume`.
- `lib/services/calls/output_tone_stub.dart:7-13` — тестовый тон в звонке (нативный бранч; веб-бранч `output_tone_web.dart` подключается через условный импорт в `call_devices_dialog.dart:11-12`).
- **Вердикт: другая задача, не дубль.** UI-SFX, зацикленные звуки, громкость из настроек, кроссплатформенность включая Windows. Пересечение с `just_audio` ровно одно — «умеет играть файл».

**3. `audio_waveforms` — мёртвый (0 импортов)**
- Ни одного `package:audio_waveforms/...` во всём репозитории (ни `lib/`, ни `test/`, ни `packages/`).
- Функциональность написана руками: `lib/widgets/voice_message_player.dart:508` `_WaveformPainter` (CustomPainter), `lib/widgets/chat/voice_recording_panel.dart:167` `_waveform`, буфер амплитуд `lib/widgets/chat/chat_input_bar.dart:118-119,430-449`, источник амплитуд — `record.getAmplitude()` в `lib/core/utils/voice_recorder_service.dart:50-66`.
- Плагин при этом регистрируется нативно (`.flutter-plugins-dependencies`, ios-секция: `audio_waveforms-2.0.2`, `native_build: true`) — то есть в сборку тянется нативный код без единой строки использования.
- **Вердикт: мёртвый. Проект написал эту функциональность сам.**

**4. `record` — только запись (1 файл)**
- `lib/core/utils/voice_recorder_service.dart:10` `AudioRecorder`, `:34-41` `RecordConfig(encoder: aacLc)`, `:54` `getAmplitude()`. Единственный потребитель — `chat_input_bar.dart:437,484,501`.

### Видео — три стека

**1. `video_player` + `chewie` — воспроизведение (8 файлов lib + 2 теста)**
- `lib/screens/media_viewer_screen.dart:210-213` (создание `VideoPlayerController.networkUrl/.file` + `ChewieController`), `:433` `Chewie(controller:)`, второй плеер в том же файле `:587-590,625`.
- `lib/screens/native_file_viewer_screen.dart:1086-1108,1169`.
- `lib/widgets/media/m3_video_controls.dart:209-249` — свои M3-контролы, вставленные внутрь `Chewie` через `ChewieController.of(context)`.
- Остальное: `niosgram_video_screen.dart:11`, `create_post_screen.dart:34`, `chat/video_message_preview.dart:6`, `chat/bubble/bubble_circle_player.dart:6`, `chat/bubble/bubble_sticker_player.dart:8`; тесты `test/web/browser_media_test.dart:11`, `test/widgets/niosgram_video_test.dart:15`.
- **Вердикт: нужен, единственный стек проигрывания. Не дубль.**

**2. `flutter_webrtc` (+ `dart_webrtc`) — realtime-звонки (12 файлов)**
- `lib/services/calls/webrtc_call_session.dart:8`, `lib/screens/calls/active_video_call_screen.dart:6` + `:267,459` (`RTCVideoView`, object fit cover), `lib/providers/call_session_provider.dart:7`, `call_devices.dart:3`, `call_overlay.dart:5`, `call_devices_dialog.dart:5`, `call_sender_quality.dart:2`, `microphone_meter_stub.dart:1` / `microphone_meter_web.dart:5-6`; тесты `call_negotiation_test.dart:6`, `call_sender_quality_test.dart:2`, `test/web/browser_workspace_calls_test.dart:15`.
- `dart_webrtc` — **не дубль**: берётся только за типом `MediaStreamWeb` на вебе — `lib/services/calls/microphone_meter_web.dart:5`, `test/web/browser_workspace_calls_test.dart:11`. По сути транзитивная зависимость `flutter_webrtc`, объявленная напрямую.
- **Вердикт: нужен, другая задача (живой звонок, а не файл).**

**3. `camera` — съёмка (4 файла lib)**
- Живые потребители: `lib/widgets/quick_camera_capture_screen.dart` (фото; вызывается из `widgets/media_grid_picker.dart:468`, `widgets/m3_file_picker_bottom_sheet.dart:415`, `widgets/create_chat_wizard_view.dart:170`, `router/app_router.dart:794`) и `lib/screens/circle_video_recorder_screen.dart` (кружок-видео; из `widgets/chat/chat_input_bar.dart:409`).
- **Мёртвый дубль WebRTC:** `lib/services/calls/video_pipeline.dart` (снимает кадры через `startImageStream`, жмёт в JPEG и шлёт как «Type 2 video» в SFU) и `lib/providers/call_video_provider.dart` (`localCameraControllerProvider`, `remoteVideoFrameProvider`). Оба файла не импортируются **нигде** — проверено по всему `pulse_flutter`, включая `test/`. Видеозвонок давно идёт через `active_video_call_screen.dart` + `RTCVideoView`.
- **Вердикт: нужен для съёмки; третий видеостек (JPEG-кадры поверх SFU) — мёртвая копия задач WebRTC.**

### Просмотрщики изображений — три реализации на один экран

| реализация | где | чем обусловлена |
|---|---|---|
| `photo_view` | `lib/screens/media_viewer_screen.dart:768`, дублируется в dev-демо `extended_image_demo_screen.dart:299` | основной просмотрщик медиа |
| `extended_image` | `lib/screens/dev/extended_image_demo_screen.dart:264` | экспериментальный кандидат на замену, прод не использует |
| `InteractiveViewer` (SDK) | `lib/screens/native_file_viewer_screen.dart:1008` | зум картинок в файловом просмотрщике сделан встроенным виджетом |

`photo_view` импортируют ровно два файла; сам `media_viewer_screen.dart` при этом импортируют `router/app_router.dart:441`, `screens/chat_detail_screen.dart:58`, `widgets/profile/profile_shared_media_tab_view.dart:23`.

`extended_image` добавлен в `pubspec.yaml:58`, но:
- в `pubspec.lock` его нет;
- в `.dart_tool/package_config.json` его нет;
- в pub-кэше (`C:\pubcache\hosted\pub.dev`) каталога `extended_image-*` нет.

То есть после добавления `pub get` не проходил, и сейчас проект в этом виде не соберётся. Плюс маршрут `/dev/image-viewer` зарегистрирован безусловно (`router/app_router.dart:206-210`), поэтому демо-экран и пакет попали бы в релизную сборку.

---

## Что стоит удалить/заменить

1. **`audio_waveforms` — удалить.** 0 импортов, вся функциональность уже нарисована своим `_WaveformPainter`. Пока пакет висит в pubspec, в Android/iOS-сборку линкуется его нативный плагин.
2. **`extended_image` — убрать из `dependencies` (или перенести в `dev_dependencies` вместе с демо-экраном).** Продового кода нет, `pub get` с ним даже не проходил. Если решение по замене `photo_view` ещё не принято — держать его в `dev_dependencies` и открывать экран только по `--dart-define`, а не безусловным маршрутом.
3. **`lib/services/calls/video_pipeline.dart` + `lib/providers/call_video_provider.dart` — удалить.** Мёртвый третий видеостек (JPEG-кадры через `camera.startImageStream` в SFU) при живом WebRTC; после удаления `camera` останется ровно на съёмке фото и кружков.
4. **`flutter_file_dialog` — оставить, но привести к одному гейту.** В `media_viewer_screen.dart:485,508` есть проверка `Platform.isAndroid || Platform.isIOS` с фолбэком в documents, в `m3_file_preview_bottom_sheet.dart:383,416` её нет (только `kIsWeb`) — на Windows сохранение файла из превью падает в исключение. Плагин поддерживает только Android/iOS (pubspec пакета), так что это не «аудио/видео», а реальный баг кроссплатформенности.
5. **Разобраться с `just_audio` на Windows.** Windows-реализации нет, а голосовые сообщения и аудиопревью в файловом просмотрщике на неё завязаны без платформенного фолбэка (в отличие от тестового тона, где фолбэк на веб сделан условным импортом). Либо `just_audio_windows`, либо переход на уже подключённый `audioplayers` на десктопе.
