# Аудит зависимостей NiosMess

81 hosted-пакет + 2 локальных path-пакета. Девять независимых агентов
(`itsxiao/free/deepseek-flash`) искали использования; обновления проверены отдельно
через pub.dev API.

Детали: `01-core-runtime.md` … `09-local-packages.md`, бриф — `_INSTRUCTIONS.md`.

## 1. Мёртвое — можно удалять

| пакет | доказательство | бонус |
|---|---|---|
| `cupertino_icons` | 0 импортов, 0 `CupertinoIcons.` | снимает MAJOR 1→2 |
| `google_fonts` | 0 импортов, шрифты лежат локальными ttf | снимает MAJOR 6→9 |
| `shimmer` | 0 импортов; импорт **запрещён тестом** `m3e_design_audit_test.dart:106` | снимает MAJOR 3→4 |
| `android_intent_plus` | 0 импортов; нужный интент уже в `MainActivity.kt:74` своим MethodChannel | — |
| `audio_waveforms` | 0 импортов; волна рисуется своим painter'ом (`voice_message_player.dart:508`, `voice_recording_panel.dart:167`) | — |
| `msix` | конфиг в pubspec есть, `msix:create` не вызывается; Windows-инсталлер — Inno Setup | — |
| `nios_mls` (path) | `openGroups` не вызывается нигде, `MlsDeviceAuthorizer` не реализован | build hook тянет `openmls_frb.dll` **11.7 МБ** |

Мёртвый код, найденный попутно (не зависимости):
`services/calls/video_pipeline.dart` + `providers/call_video_provider.dart` (0 импортов —
мёртвая копия видеозвонка), `nios_sdk`: `link.dart`, `trust.dart`,
`SqliteWalDurableStore`, `headlessWorkerClientProvider`; hive-бокс `messages_cache_box`;
ручная загрузка `Image.memory` в `media_viewer_screen.dart:661-703`.

## 2. Дубли и перекрытия

- **Аудио — три движка, но задачи разные.** `just_audio` + `audio_session` — длинное
  воспроизведение (`voice_message_player.dart`, `native_file_viewer_screen.dart`);
  `audioplayers` — UI-звуки и тон в звонке (`core/sound/app_sound.dart`);
  `audio_waveforms` мёртв. Реальная проблема не в дубле движков, а в том, что
  `audio_session` настраивается в трёх местах (`voice_message_player.dart:124`,
  `webrtc_call_session.dart:180`, `app_sound.dart:272`) и нет `setActive(false)` после звонка.
- **Видео — три стека, один мёртвый.** `video_player`+`chewie` — файлы,
  `flutter_webrtc` — звонки, `camera` — съёмка; `video_pipeline.dart` мёртв.
- **Крипта — три пакета, все нужны.** `cryptography` — весь E2EE,
  `pointycastle` — RSA/JWKS + потоковый AES-GCM, `crypto` — хэши (нужен и `nios_sdk`/`nios_mls`).
  Дублирование: 7 файлов тянут оба хэш-API, AES-GCM для конверта `[nonce12|ct|tag16]`
  реализован дважды.
- **Картинки — три пути.** `cached_network_image` (публичные), `WsCachedImage`/
  `WsMediaFetcher` (E2EE), ручной `Image.memory` (просмотрщик).
- **Просмотрщики — три.** `photo_view` (2 файла), `extended_image` (пока dev-демо),
  `InteractiveViewer` (4 места).
- `hive_flutter` держится ради одной строки `Hive.initFlutter()`.

## 3. Дефекты, найденные попутно

1. **Фото в чатах не сжимаются.** `flutter_image_compress.compressImageFile` не вызывается
   ни разу, хотя l10n обещает сжатие.
2. **wasm сломан.** `dart.library.html` в `oauth_navigation_helper.dart:2` и
   `ephemeral_storage.dart:2`; под dart2wasm ключ `false` → подставляется `ws_stub` →
   все сокеты кидают `UnsupportedError`.
3. **Голосовые на Windows не играют.** У `just_audio` нет Windows-реализации;
   `audioplayers` там зарегистрирован нативно, но он про другое.
4. **Headless-изолят не подключён.** `headless_core_isolate` + `HeadlessWorkerClient`
   написаны, провайдер не читает никто → Double Ratchet считает
   `AesGcm.with256bits()` в UI-изоляте (сходится с перф-аудитом).
5. `flutter_markdown` — **discontinued апстримом**, при этом единственный рендерер.
6. `flutter_pdfview` — только Android/iOS, на Windows заглушка плагина.
7. `flutter_secure_storage` — ни одной platform-опции не задано; плюс v11 удаляет
   устаревшие алгоритмы (см. мажоры).
8. `ref.read` в `build()` — 84 вызова в 37 файлах (лидеры: `main_shell_screen.dart` 8,
   `niosgram_screen.dart` 6, `chat_filter_bar.dart` 6).
9. `timezone` грузит всю базу зон на старте, `zonedSchedule` не используется.
10. `shared_preferences` — 101 `getInstance`, нет единой обёртки.

## 4. Обновления

56 из 81 можно поднять: **15 MAJOR**, 27 minor, 14 patch. После удаления мёртвых
мажоров остаётся **12**.

Минимум три мажора снимаются удалением строки, а не апгрейдом:
`cupertino_icons`, `google_fonts`, `shimmer`.

Из 12 оставшихся: 6 — миграция на `material_ui`/`cupertino_ui` (ровно то, что SDK 3.50.1
объявил вместо `flutter/material.dart`), 4 — нативные требования (compileSdk 37, AGP 9,
iOS SDK 13, C++20), 2 — реальные изменения поведения (`record`, `flutter_secure_storage`).

## 5. Предлагаемый порядок

1. Удалить мёртвое одним коммитом: `cupertino_icons`, `google_fonts`, `shimmer`,
   `android_intent_plus`, `audio_waveforms`, `msix`. Отдельно — `nios_mls` (снимает DLL 11.7 МБ).
2. Поднять patch + minor (41 пакет, риск низкий), прогнать тесты.
3. Мажоры по группам, не одной кучей: сначала нативные, потом поведенческие,
   `material_ui`-группу — только после решения по самой платформе.
4. `photo_view` убрать вместе с переходом просмотрщика на `extended_image`.

---

## 6. Фактический результат (26.11.2026)

Применено и проверено:

- Фаза 0: Flutter 3.50.1 / Dart 3.14.0 и локально, и в CI; анализатор чист.
- Фаза 1: удалены cupertino_icons, google_fonts, shimmer, android_intent_plus,
  audio_waveforms, msix, nios_mls (+ MLS-заглушка в nios_protocol_accounts.dart).
  Lock: 306 → 299 пакетов.
- Фаза 2: поднято 15 patch/minor, включая flutter_riverpod 3.5, chewie 1.18,
  lottie 3.8, flutter_svg 2.5, image 4.13, archive 4.7.
- Фаза 3: file_picker 13.4.1 (PlatformFile.length() стал Future<int?> — 3 правки),
  open_file 4.0.0.
- Фаза 4: flutter_markdown → flutter_markdown_plus 1.0.12, 4 файла импортов.
- Фаза 5: firebase_core 5.2.0, firebase_messaging 17.1.0,
  flutter_local_notifications 23.0.4, permission_handler 13.0.2,
  flutter_foreground_task 11.0.3; Gradle 9.5.0, AGP 9.3.1, Kotlin 2.4.20 (built-in Kotlin),
  compileSdk 37.
- Фаза 6: flutter_secure_storage 11.2.0, record 7.2.0.
- Регресс chewie 1.18 (нет Material-предка в fullscreen) исправлен в
  widgets/media/m3_video_controls.dart.

Итог: фазы 5 и 6.2 закрыты (`flutter_local_notifications 23.0.4`,
`permission_handler 13.0.2`, `flutter_foreground_task 11.0.3`, `record 7.2.0`).

- CI-прогон 45826065004 зелёный целиком: Android APK + startup gate на API 29,
  Windows Installer, Web, Analyze & Test, оба Protocol SDK, Publish Release.
- По пути нашлось три грабли:
  - release-lint AGP 9.3.1 падает на camera
    (`NoSuchMethodError: java.util.List.removeLast()` — JDK 21 API на демоне JDK 17);
    отключены все задачи `lintVital*`.
  - глобальный `CMAKE_CXX_STANDARD 20` ломал window_manager 0.5.2 (`error C4596`);
    убран — C++20 включает сам `flutter_local_notifications_windows`.
  - `audioplayers_android` 5.3.0 тянет junit5-плагин, несовместимый с AGP 9;
    вендорен в `packages/audioplayers_android` (`README-vendor.md`).

Доказательства: dart analyze lib test — No issues found;
flutter test test/suite_test.dart — 1912/1912 passed (дважды: после фаз 2–3 и после 6.1).

Осталось:

- Фаза 7 — миграция на material_ui: 410 импортов package:flutter/material.dart,
  1 cupertino, ~140 файлов с material-типами в сигнатурах; пакеты
  cached_network_image 4, dynamic_color 2, go_router 18.
- Заблокировано апстримом: desktop_drop 0.9.2 (конфликт cross_file с file_picker).
- Заблокировано тулчейном: window_manager 0.7.1 / tray_manager 0.9.1
  (nativeapi собирается через native_toolchain_c, нужен MSVC; готовая миграция —
  audit/desktop_window_service.nativeapi.dart.txt).