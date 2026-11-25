# 08 — Dev-инструменты, desktop-плагины и platform-интерфейсы

Пакеты: `tray_manager`, `windows_taskbar`, `geolocator`, `video_player_web`,
`video_player_platform_interface`, `test`, `audioplayers_platform_interface`,
`flutter_lints`, `flutter_native_splash`, `msix`.

Методика: grep по `pulse_flutter/lib`, `pulse_flutter/test`, `pulse_flutter/integration_test`,
`packages/*/lib`, `packages/*/test`, плюс `pubspec.yaml`, `analysis_options.yaml`,
`.github/workflows/build.yml`, `android/app/src/main/AndroidManifest.xml`.

| пакет | файлов | обращений | где (топ-3) | вердикт |
|---|---|---|---|---|
| tray_manager | 1 | 8 | lib/core/services/desktop_window_service.dart:5,60,79,95 | нужен |
| windows_taskbar | 1 | 3 | lib/core/services/desktop_window_service.dart:8,163,176 | нужен |
| geolocator | 1 (косвенно 8) | 6 | lib/services/live_location_platform.dart:2,24,54 | нужен |
| video_player_web | 1 (тест) | 2 | test/web/browser_media_test.dart:12,155 | нужен (только тесты) |
| video_player_platform_interface | 4 (тесты) | 21 | test/widgets/niosgram_video_test.dart:14,30; test/widgets/create_post_media_submission_test.dart:66; test/widgets/settings_refresh_test.dart:100 | нужен (только тесты) |
| audioplayers_platform_interface | 1 (тест) | 17 | test/unit/sound_service_test.dart:3,8 | нужен (только тесты) |
| test | 33 | 33 | test/pure_dart/*.dart, packages/nios_sdk/test/link/*.dart, packages/nios_mls/test/*.dart | нужен |
| flutter_lints | 1 (yaml) | 1 | pulse_flutter/analysis_options.yaml:10 (`include: package:flutter_lints/flutter.yaml`) | нужен |
| flutter_native_splash | 0 dart | 2 (конфиг) | pulse_flutter/flutter_native_splash.yaml:1; pubspec.yaml:130 | нужен (ручной генератор) |
| msix | 0 | 0 | pubspec.yaml:131 (dep), pubspec.yaml:238–250 (`msix_config`) | мёртвый |

## Детали по спорным пунктам

### tray_manager + windows_taskbar — не дубль

Оба импортируются из одного файла `lib/core/services/desktop_window_service.dart`, но делают
разные вещи:

- `tray_manager` (:60, :79, :80, :95, :148, :205) — иконка в системном трее, тултип, контекстное
  меню (`Menu`/`MenuItem` с ключами `show_window` / `exit_app`), `TrayListener`
  (`onTrayIconMouseDown`, `onTrayIconRightMouseDown`, `onTrayMenuItemClick`). Это трей и
  «свернуть в трей» (`windowManager.setPreventClose(true)` + `onWindowClose` → `hideWindow`).
- `windows_taskbar` (:163, :176) — подсветка/мигание кнопки на панели задач при входящем
  сообщении (`setFlashTaskbarAppIcon` с `TaskbarFlashMode.all | TaskbarFlashMode.timernofg`,
  `resetFlashTaskbarAppIcon`), вызов из `lib/providers/websocket_dispatcher_provider.dart:169–170`.

Пересечения API нет: трей против панели задач. Третий сосед — `window_manager` (окно, заголовок,
`setTitle` из `lib/widgets/nav/shell_window_title.dart`) — тоже отдельная зона ответственности.
Все три живут под гейтом `kIsWeb`/`TargetPlatform`, `initialize()` вызывается из
`lib/main.dart:256–257` через `guarded('desktop_window', ...)`.

Замечание: `desktop_window_service.dart:86` и `:91` — жёстко зашитые русские подписи меню
(`'Открыть NiosMess'`, `'Выйти'`), хотя по конвенции проекта все пользовательские строки идут
через `context.l10n`. Для трея `context` нет — нужен `AppLocalizations` через сохранённую локаль.

### geolocator — живой, не мёртвый вес

Не «подозрительный лишний пакет»: в 3.118.0 добавлена фича live location, она полностью
прошита, а не заготовка.

- `lib/services/live_location_platform.dart:2` — единственная точка импорта: `Geolocator
  .isLocationServiceEnabled` (:10), `checkPermission` (:13), `requestPermission` (:15),
  `getCurrentPosition` (:24), `getPositionStream` (:54). На Android используется
  `AndroidSettings` + `ForegroundNotificationConfig` (уведомление «Передача геопозиции»,
  `intervalDuration: 15s`, `distanceFilter: 10`, `enableWakeLock`, `setOngoing`).
- Дальше фича расходится по 8 файлам `lib/`: `providers/live_location_provider.dart:7,37,41`
  (`liveLocationProvider`, `liveLocationChangesProvider`), `services/live_location_service.dart`,
  `models/live_location.dart` (кодирование в текст сообщения), `widgets/chat/live_location_card.dart`,
  `screens/chat_detail_screen.dart:2700` (`showLiveLocationComposer`),
  `widgets/message_bubble.dart:1566–1568`, `chat_list_screen.dart:1182`,
  `backend_chat_provider.dart:904,3776` (принудительный E2EE для live-location сообщений).
- Тесты: `test/services/live_location_service_test.dart` (в `suite_test.dart:21`),
  `test/widgets/chat_extras_test.dart:82–111`.

Разрешения в `android/app/src/main/AndroidManifest.xml` — используются, не «лишние»:
`ACCESS_FINE_LOCATION` (:8), `ACCESS_COARSE_LOCATION` (:9), `FOREGROUND_SERVICE_LOCATION` (:14),
`FOREGROUND_SERVICE_CONNECTED_DEVICE` (:13, для `BluetoothMeshKeepAliveService` с
`foregroundServiceType="connectedDevice|location"`, :38–39). На iOS есть
`NSLocationWhenInUseUsageDescription` (`ios/Runner/Info.plist:52`). `BLUETOOTH_SCAN` объявлен с
`neverForLocation` (:10), то есть аналитика «BLE ради геолокации» сознательно отключена —
конфликта с geolocator нет. Вердикт: **нужен**, разрешения оправданы.

Мелкое: `live_location_platform.dart:11,19–21,41–43` — русские строки ошибок прямо в сервисе,
без l10n (тот же класс проблемы, что и меню трея).

### video_player_web / video_player_platform_interface / audioplayers_platform_interface — не «пины ради версии», а реальные импорты в тестах

Проверено по `pubspec.lock`: все три — `dependency: "direct dev"`. Импорты настоящие:

- `test/web/browser_media_test.dart:12` + `:155`/`:221` — `VideoPlayerPlatform.instance =
  VideoPlayerPlugin();` то есть тест явно ставит **web-реализацию** из `video_player_web`,
  иначе на `--platform chrome` виджет `VideoPlayer` в тесте не инициализируется. Файл гоняется
  в CI: `.github/workflows/build.yml:118` (`flutter test test/web/browser_media_test.dart
  --platform chrome`). Импорт `video_player_platform_interface` там же (:13) — ради типа
  `VideoPlayerPlatform`.
- `video_player_platform_interface` — ещё 3 файла виджет-тестов пишут фейковые платформы:
  `test/widgets/create_post_media_submission_test.dart:66` (`class _VideoProbe extends
  VideoPlayerPlatform`), `test/widgets/niosgram_video_test.dart:30` (`class _Video extends ...`,
  подмены на :142, :194, :255), `test/widgets/settings_refresh_test.dart:100` (+ :973). Все три
  входят в `test/suite_test.dart` (:39, :160, :46) → CI :114.
- `audioplayers_platform_interface` — `test/unit/sound_service_test.dart:8`
  (`class MockAudioplayersPlatform extends AudioplayersPlatformInterface`, ~17 переопределений
  методов, `AudioEvent`-стримы). В `suite_test.dart:211,347` → CI :114. Коммит-первопричина:
  `009367f7 fix(test): mock audioplayers and path_provider platforms in sound_service_test`.

То есть это не workaround «чтобы `pub` выбрал версию», а необходимость: без прямого объявления
нельзя легально импортировать пакет (lint `depend_on_referenced_packages`) и нельзя зафиксировать
версию интерфейса, под который написаны фейки. Комментариев-объяснений в `pubspec.yaml`
(строки 114–122) нет — стоит добавить, иначе следующий аудит снова будет гадать.
Отдельно: `video_player_web` уже приходит транзитивно как web-реализация `video_player`, так что
для сборки он не нужен — только для прямого импорта в тесте. Первопричина появления —
`f45f340b feat(web): adapt workspace and browser media in 3.109.0`.

### test — нужен, но фреймворки смешаны

33 файла, 33 импорта `package:test/test.dart`: 11 в `pulse_flutter/test`, 13 в
`packages/nios_sdk/test`, 9 в `packages/nios_mls/test`. Ни один файл не импортирует
одновременно `package:test` и `package:flutter_test` — разделение чистое. В `lib/` импортов
`package:test` нет (0). CI гоняет `dart test test/pure_dart` (:127) и
`dart test test/pure_dart/notification_event_test.dart` (:89) — без пакета `test` это не
работает.

Но 8 из 11 «package:test» файлов **также** импортируются в `test/suite_test.dart`, который
запускается под `flutter_test` (`flutter test test/suite_test.dart`, CI :114):
`suite_test.dart:45,74,107,116,120,123,125,166`. Формально это работает (оба фреймворка
сходятся на `test_api`), но в одном прогоне оказываются два набора `test()`/`expect` —
хрупкое место: при добавлении `setUpAll`/`binding`-зависимостей или `tags` поведение начнёт
расходиться между `dart test` и `flutter test`.

### flutter_lints — нужен, объявлен ровно там, где используется

`pulse_flutter/analysis_options.yaml:10` — `include: package:flutter_lints/flutter.yaml`.
Dart-импортов нет и быть не должно. CI: `flutter analyze --fatal-infos` (:111) — без пакета
анализ падает на резолве include. Локальные пакеты (`packages/nios_sdk`, `nios_mls`,
`nios_iroh`, `nios_lab`) на `flutter_lints` не завязаны — у них `package:lints/recommended.yaml`.

### flutter_native_splash — нужен, но только как ручной генератор

`pulse_flutter/flutter_native_splash.yaml` (цвет `#18181A`, `image: assets/NiosMess_icon.png`,
блок `android_12`) — конфиг есть, результат **закоммичен**:

- Android: `android/app/src/main/res/drawable*/splash.png`, `drawable*/android12splash.png`,
  `drawable/launch_background.xml:7` (`@drawable/splash`), `values-v31/styles.xml:9–10`
  (`windowSplashScreenBackground` / `windowSplashScreenAnimatedIcon`), `values-night-v31`.
- Web: `web/index.html:35,94–103` (`#splash-screen-style`, `#splash`, `removeSplashFromWeb`) —
  тоже продукт этого пакета.

При этом **ни CI, ни скрипты его не запускают** (в `.github/workflows/build.yml` нет
`flutter_native_splash:create`). То есть пакет нужен для перегенерации сплэша, но об этом знает
только тот, кто помнит. После правки конфига или иконки CI об этом не напомнит.

### msix — мёртвый

`msix` объявлен в `dev_dependencies` (pubspec.yaml:131), плюс 13 строк `msix_config`
(:238–250: identity, publisher `CN=NiosMess Team`, `certificate_path: NiosMessCert.pfx`,
capabilities). При этом:

- Dart-импортов — 0, вызовов `msix:create` — 0 во всём репозитории (md/ps1/sh/bat/yml/iss тоже).
- Windows-инсталлятор в CI собирается **Inno Setup**: `build.yml:302,316–319,342,359–367`
  (`windows/installer/inno_setup.iss`), MSIX в релизном пайплайне не участвует.
- `NiosMessCert.pfx` лежит локально и в git не попадает (`.gitignore:27` → `*.pfx`), поэтому
  конфиг нерабочий и в чистом клоне.

Вывод: конфиг создаёт ложное впечатление, что релиз Windows идёт через MSIX, и тянет dev-пакет
ради файла, который никто не запускает.

## Что стоит удалить/заменить

1. **Удалить `msix`** вместе с блоком `msix_config` (pubspec.yaml:131, 238–250) — или, если
   MSIX-сборка нужна вручную, вынести её в `tool/` скрипт и строку в `AGENTS.md`. Сейчас это
   единственный в списке полностью мёртвый пакет; установщик Windows — Inno Setup.
2. **Добавить комментарии к четырём dev-пинам** (pubspec.yaml:115–117, 122): «фейки/реализации
   платформ для тестов, см. test/web/browser_media_test.dart, test/unit/sound_service_test.dart».
   Пакеты не удалять — импорты настоящие.
3. **Развести тестовые фреймворки**: 8 файлов с `package:test` одновременно гоняются внутри
   `test/suite_test.dart` под `flutter_test` (suite_test.dart:45,74,107,116,120,123,125,166).
   Либо оставить их только в `dart test`, либо перевести на `flutter_test` — сейчас один и тот же
   файл исполняется двумя фреймворками, и расхождение проявится при первом же `SetUp` с binding.
4. **Вынести строки трея и live location в l10n**: `desktop_window_service.dart:86,91`
   (`'Открыть NiosMess'`, `'Выйти'`) и `live_location_platform.dart:11,19–21,41–43` —
   единственные найденные в этом наборе нарушения правила «никаких строк в коде».
5. **Закрепить генерацию сплэша**: `flutter_native_splash` работает, но запускается вручную;
   добавить шаг (или проверку diffs сгенерированных `res/drawable*/splash*.png` и `web/index.html`)
   в CI, иначе конфиг и закоммиченный результат тихо разъедутся.
