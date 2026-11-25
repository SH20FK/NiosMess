# 02 — медиа, файлы, пути, время, аудио

Область: `pulse_flutter/lib` (563 файла), `test/`, `packages/nios_sdk`, `packages/nios_mls`.
Считалось по grep: файлы = файлы с `package:<pkg>/`; обращения = строки реального API
(импорты не считаются). Версии и обновления не проверялись.

| пакет | файлов | обращений | где (топ-3) | вердикт |
|---|---|---|---|---|
| timezone | 1 | 6 (+13 потребителей `AppTimeSettings`) | `lib/core/utils/app_time.dart:16` (`initializeTimeZones`), `:53` (`TZDateTime.from`), `:73` (`getLocation`) | нужен |
| file_picker | 13 (12 lib + 1 test) | 12 | `lib/widgets/chat/chat_input_bar.dart:287`, `lib/widgets/media_grid_picker.dart:629`, `lib/widgets/m3_file_picker_bottom_sheet.dart:50` | нужен |
| cached_network_image | 15 lib (+4 test) | 20 | `lib/widgets/pulse_avatar.dart:90`, `lib/widgets/chat/chat_message_list.dart:937`, `lib/widgets/message_bubble.dart:673` (стикеры), `lib/widgets/post_card.dart:784` (провайдер) | нужен |
| flutter_cache_manager | 1 lib (+4 test) | 39 | `lib/core/network/ws_media_fetcher.dart:98` (`CacheManager('nios_private_media_v1')`), `:137` (`secret_playback_v2`), `:95` (`DefaultCacheManager()` для общих картинок) | нужен (не дубль — это движок `cached_network_image`) |
| dynamic_color | 2 | 2 | `lib/main.dart:367`, `lib/screens/settings_appearance_screen.dart:85` | нужен |
| video_player | 8 lib (+2 test) | 29 | `lib/screens/media_viewer_screen.dart:210`, `lib/widgets/chat/bubble/bubble_sticker_player.dart:178`, `lib/widgets/chat/bubble/bubble_circle_player.dart:152` | нужен; внимание: нет Windows-реализации (см. ниже) |
| open_file | 4 | 6 | `lib/core/utils/file_opener.dart:116,132,155`, `lib/providers/ota_update_provider.dart:492`, `lib/core/services/push_notification_service.dart:760` (установка APK) | нужен |
| path_provider | 12 | 23 | `lib/core/storage/local_storage_service.dart:75`, `lib/screens/media_viewer_screen.dart:162`, `lib/core/network/ws_media_fetcher.dart:146` | нужен |
| just_audio | 2 | 27 | `lib/widgets/voice_message_player.dart:72`, `lib/screens/native_file_viewer_screen.dart:1321` | нужен; внимание: второй аудио-движок рядом с `audioplayers` |
| audio_session | 2 | 4 (2 `configure`) | `lib/services/calls/webrtc_call_session.dart:180`, `lib/widgets/voice_message_player.dart:124` | нужен; внимание: конфиг размазан по трём местам, восстановления нет |

Нативно (для полноты): в `android/.../GeneratedPluginRegistrant.java` подключены
`filepicker`, `audio_session`, `audio_waveforms`, `audioplayers`, `dynamic_color`, `just_audio`,
`openfile`, `record`, `videoplayer`. В `windows/flutter/generated_plugins.cmake` из этой группы есть
только `dynamic_color` и `record_windows` (плюс `audioplayers_windows`). `path_provider_windows`
в `pubspec.lock` есть — это Dart-плагин, нативной регистрации не требует.

## Отдельный вопрос 1: `cached_network_image` ↔ `flutter_cache_manager`

Дублирования нет, разделение осмысленное:

- `cached_network_image` — только виджет/провайдер для **публичных** картинок: аватары, стикеры,
  эмодзи, медиа постов. Часть запросов идёт с `httpHeaders: cachedAuthHeaders(...)`
  (`pulse_avatar.dart:90`, `chat_message_list.dart:937`, `native_file_viewer_screen.dart:1054`).
- `flutter_cache_manager` объявлен напрямую, потому что `WsMediaFetcher` создаёт **свои** инстансы
  `CacheManager(Config('nios_private_media_v1'))` и `CacheManager(Config('secret_playback_v2'))`
  (`ws_media_fetcher.dart:98,137`), кладёт туда расшифрованные байты и очищает по выходу из аккаунта.
  Через `CachedNetworkImageProvider` это сделать нельзя (нужен свой ключ кеша + `putFile`/`putFileStream`).
- Третья точка — `DefaultCacheManager()` (`ws_media_fetcher.dart:95`), то есть **тот же singleton**,
  которым пользуется `cached_network_image`; он чистится при закрытии аккаунта (`clearPrivateCache`,
  `:81`) и не вычищается при рутинной очистке приватного кеша. Это осознанная координация
  (зафиксирована в `test/core/media_file_cache_pipeline_test.dart:120`), а не дубль.

Вывод: оба пакета нужны, `flutter_cache_manager` — не «лишний транзитив», а рабочий API.
Удалять нельзя, но и добавлять третью кеш-схему не стоит.

## Отдельный вопрос 2: свой кеш картинок — `WsCachedImage` / `WsMediaFetcher`

В проекте есть **собственный** слой кеширования медиа, и он частично перекрывает
`cached_network_image`:

- `WsMediaFetcher` (`lib/core/network/ws_media_fetcher.dart`) — LRU-память (`getMemoryCachedBytes`/
  `putMemoryCachedBytes`, лимиты и eviction), дисковый кеш через `flutter_cache_manager`,
  расшифровка E2EE, батч-префетч, staging-каталоги, ограничение 4 параллельных загрузок.
- `WsCachedImage` (`lib/widgets/chat/ws_cached_image.dart`) — виджет поверх него, с учётом
  `autoDownloadAllowedProvider` (фото не грузится на мобильном трафике без разрешения).
- `WsCachedImage` используется в 4 местах: `widgets/message_bubble.dart:942,959`,
  `widgets/chat/bubble/bubble_carousel.dart:66`, `widgets/profile/profile_shared_media_tab_view.dart:751`.
- Третий путь: `media_viewer_screen.dart:661-703` рисует через `Image.memory` +
  `WsMediaFetcher.getMemoryCachedBytes` вручную, без `WsCachedImage`.

Так что «свой кеш» делает `cached_network_image` ненужным **только для чатового E2EE-медиа**, но не
для публичных картинок: у `CachedNetworkImage` есть заголовки авторизации, `memCacheWidth`,
placeholder/errorWidget и общий дисковый кеш — переписывать 19 мест на `WsCachedImage` смысла нет,
он требует `chatId`/`isE2ee` и не умеет auth-headers. Реальный дубль здесь другой: **два независимых
хранилища картинок** (DefaultCacheManager + приватные `CacheManager`) и **два способа отрисовки**
(виджет и ручной `Image.memory` в просмотрщике). Это не удаление пакета, а унификация вызовов.

## Отдельный вопрос 3: `just_audio` + `audio_session` и дубли в `audioplayers`/`audio_waveforms`

Аудио-сессия инициализируется в трёх независимых местах — единого менеджера нет:

1. `lib/core/sound/app_sound.dart:216-229` — `AudioContext` для **audioplayers**
   (Android `gainTransientMayDuck`, iOS `AVAudioSessionCategory.ambient`), применяется глобально
   `AudioPlayer.global.setAudioContext` (`:272`).
2. `lib/widgets/voice_message_player.dart:122-138` — `AudioSession.instance.configure(...)`:
   Android `gainTransient`, iOS `playback` + `mixWithOthers`. Вызывается из `initState` **на каждый
   виджет** голосового сообщения.
3. `lib/services/calls/webrtc_call_session.dart:177-201` — `AudioSession.instance.configure(...)`:
   `playAndRecord`, `voiceChat`, Android `gain`, `willPauseWhenDucked`.

Проблемы, которые из этого следуют (проверяемо по коду):

- **Два движка аудио.** `just_audio` — голосовые сообщения и музыкальный плеер в файловом
  просмотрщике (2 файла); `audioplayers` — все UI-звуки, луп и тестовый тон (10 плееров
  создаются на старте: priority + 4 effect + 4 ui + loop, `app_sound.dart:278-313`).
  Оба претендуют на audio focus, у каждого своя настройка
  сессии, `suspendForCall()`/`resumeAfterCall()` (`app_sound.dart:235,246`) гасит только
  `audioplayers` — `just_audio`-плееры про звонок не знают.
- **Нет восстановления сессии.** `session.setActive(false)`/`deactivate` в проекте не встречается
  ни разу (grep: 0). После звонка iOS-сессия остаётся в `playAndRecord`/`voiceChat`, плюс любой
  новый `VoiceMessagePlayer` перебьёт её на `playback` прямо во время звонка.
- **`audio_waveforms` — мёртвый.** 0 импортов во всём `lib/`. Волна рисуется своим
  `_WaveformPainter` (`voice_message_player.dart:508`), а амплитуды пишет `record`
  (`core/utils/voice_recorder_service.dart:54`). При этом плагин всё ещё регистрируется на Android
  (`AudioWaveformsPlugin`) и висит в APK.

То есть `just_audio` и `audio_session` сами по себе нужны, дубль — в **сосуществовании двух
аудио-движков и трёх конфигураторов сессии**, а `audio_waveforms` — чистый кандидат на удаление.

## Что стоит удалить/заменить

1. **`audio_waveforms` — удалить.** Ноль импортов, функциональность закрыта своим
   `_WaveformPainter` + `record.getAmplitude()`. Экономия — нативный плагин в APK.
2. **Свести конфигурацию аудио-сессии в один сервис.** Сейчас `audio_session` настраивается в
   `voice_message_player.dart:124` и `webrtc_call_session.dart:180`, а параллельно
   `app_sound.dart:272` ставит глобальный `AudioContext` для `audioplayers`. Нужен один владелец
   (например, в `SoundService`) с `setActive(false)` после звонка и с явным приоритетом «звонок >
   голосовое > UI-звук».
3. **Определиться с аудио-движком.** `just_audio` (2 файла) и `audioplayers` (2 файла) — это два
   комплекта нативных плееров. Минимальный шаг: оставить `audioplayers` только под короткие
   UI-звуки и запретить ему трогать сессию, а медиаплееры держать на `just_audio`. Полный переход
   на один движок — отдельная задача, но сейчас audio focus делят двое.
4. **`voice_message_player` не должен конфигурировать глобальную сессию в `initState`.**
   Это per-widget побочный эффект: любой пересозданный бабл перебивает режим звонка.
5. **Windows: `video_player` и `just_audio` без платформенных реализаций.** В `pubspec.lock` нет
   `video_player_win`, нет `just_audio_windows`; в `windows/flutter/generated_plugins.cmake` —
   тоже. Windows-установщик собирается, но видео и голосовые/музыка на Windows, судя по набору
   зависимостей, не заиграют (на Android/iOS/web всё в порядке). Либо добавить windows-реализации,
   либо явно скрывать плееры на Windows через `ClientCapabilities`.

Мелочи по остальным:

- `timezone` нужен, но `tzdata.initializeTimeZones()` вызывается на старте (`main.dart:114`) и
  тянет всю базу зон только ради отображаемого часового пояса (`AppTimeSettings`), при этом
  `zonedSchedule` не используется ни разу. Если понадобится облегчить холодный старт — грузить
  зоны лениво в `AppTimeSettings.now()`.
- `file_picker` — рабочий, но файловых диалогов в проекте три: `file_picker` (выбор),
  `photo_manager` (галереи/альбомы), `flutter_file_dialog` (сохранение). Это не дубль по смыслу,
  но три API на одну задачу «показать файлы пользователю».
- `video_player_web` и `video_player_platform_interface` в `dev_dependencies` — легитимно: это
  фейки платформы в тестах (`test/web/browser_media_test.dart:12-13`), не лишние зависимости.
