# Rust-кандидаты и оптимизация размера/старта — проверка по коду

Дата: 2026-11-28. Проект: `F:\Niosmess V2\pulse_flutter` (код не изменялся).
Метод: чтение кода + микробенчмарки на этой машине (Windows x64, Dart VM 3.14, Flutter 3.50.1).
Все замеры производительности — **чистый Dart** (`cryptography` 2.x без `cryptography_flutter`, в `pubspec.yaml`/`pubspec.lock` его нет), т.е. без нативного ускорения даже на телефоне.
**Числа для Android/ARM не измерялись** — оценочный коэффициент ×2–4 не проверен (см. §4).

---

## Раздел 1. Кандидаты на Rust: живые/горячие?

### 1.1 Что реально происходит (факты по коду)

**Кто создаёт `BluetoothMeshService`.** Ровно одно место — `bluetoothMeshProvider`
(`lib/services/bluetooth_mesh/bluetooth_mesh_service.dart:658`). Условия создания (там же, :662):

- `meshPlatformSupported` = `!kIsWeb && (Android || Windows)` — `mesh_preferences.dart:6`;
- есть `session.userId` (залогинен);
- есть `ordinaryE2eeProvider`.

Провайдер **не** `autoDispose`, поэтому живёт до конца контейнера. Первое создание — `ref.read(bluetoothMeshProvider)`
в `chatsProvider.build` (`lib/providers/backend_chat_provider.dart:403`), т.е. на первой загрузке списка чатов
после логина. Дальше он используется ещё в 8 местах (в т.ч. `chat_message_list.dart:747` — на каждый bubble).

**Настройка/флаг.** `MeshPreference.build` (`mesh_preferences.dart:18-36`) читает
`niosmess.bluetooth_fallback.v1` и **по умолчанию `true`**: `prefs.getBool(key) ?? true` (:27).
Автозапуск: `if (ref.read(meshPreferenceProvider)) unawaited(startWhenReady())` (:758), плюс повторные
попытки на `ws.onConnected` (:709), на смену ключей E2EE (:693), на `connectivityProvider` (:750),
на `AppLifecycleListener.onResume` (:749) и в таймере каждые 2 с (:745-748).

**Итог:** на Android/Windows mesh **включён по умолчанию и стартует на каждом запуске** при залогиненной сессии,
даже если пользователь ни разу не отправлял сообщение по BLE.

**Что вызывает `MeshRouter`.** `_start()` (`bluetooth_mesh_service.dart:196-343`):

1. `ordinary.open()` / `prepareMesh()`;
2. `Hive.openBox<String>('bluetooth_mesh_ciphertext_v1')` (:209);
3. `_router.restore(_box.get(scope()))` (:241) → `MeshRouter.restore` (`mesh_router.dart:84-113`) → **`MeshPacket.parse` на каждый из <=128 сохранённых wire-пакетов**;
4. разбор `outbox` (:243-258) → ещё до 256 `MeshPacket.parse(..., forBackfill: true)`;
5. `transport.events.listen(_event)` (:293) — на каждый `frame` из BLE: `MeshRouter.receive` (:367);
6. `Timer.periodic(30s)` (:310): `connected(peer)` для каждого пира + `replay()` + `flushCloud()`;
7. `Provider`-таймер 2 с (`checkAccessAndPreparation`, :745).

**Очередь/батчинг.** Есть только сериализация без батчинга: `MeshRouter._run` (`mesh_router.dart:32-39`)
складывает операции в цепочку `_serial`. Батчей нет, параллелизма нет, каждое входящее сообщение обрабатывается
целиком (parse → persist → send stored → deliver) до следующего. Лимиты (`mesh_router.dart:16-17`):
`256 frames/мин` и `256 КБ/мин` на пира, до 32 пиров ⇒ теоретический потолок ~8192 пакетов/мин.

**Сколько Ed25519-верификаций на один входящий пакет: 3.**

| шаг | что проверяется | вызовы |
|---|---|---|
| `MeshPacket.parse` (`mesh_packet.dart:222-228`) | подпись `device` над `niosmess-ble-v1:$body` | 1 × Ed25519 verify |
| `MeshPacket.parse` (`mesh_packet.dart:239-245`) | подпись `author` (ed) над `inner.body` | 1 × Ed25519 verify |
| `_deliver` → `ordinary.openMeshPacket` → `OrdinaryCodec.decrypt` (`ordinary_e2ee_codec.dart:297-301`) | **та же** подпись `author` над тем же `inner.body` | 1 × Ed25519 verify (дубль) |

Дублирование подтверждено: в `parse` проверяется `inner['body']`/`inner['signature']` ключом `author`
(`mesh_packet.dart:240-242`), а в `decrypt` — `p['body']`/`p['signature']` ключом `sender['ed']`
(`ordinary_e2ee_codec.dart:297-300`), причём `author` из `parse` уже сверен с `peer['ed']` в `openMeshPacket`
(`ordinary_e2ee_service.dart:578-580`). Один и тот же пакет проверяется дважды.

Дополнительно на пакет: 2 × SHA-256 (`_id` + проверка PoW, `mesh_packet.dart:172-179`), 2 × `jsonDecode`
(wire + body), `permitClaims` (base64 + jsonDecode), и при успешном decrypt — 1 × X25519 shared secret + HKDF + 2 × AES-GCM.
Пакеты, адресованные не нам (релей), всё равно проходят все 3 верификации — проверка «есть ли наш box»
стоит уже после verify (`ordinary_e2ee_codec.dart:297` → `:307`).

**Замеры (эта машина, Dart VM x64):**

| операция | время |
|---|---|
| Ed25519 verify (512 B) | **2.40–2.46 мс** |
| Ed25519 sign | 2.17–2.55 мс |
| X25519 shared secret | 0.89–1.01 мс |
| AES-GCM open 1 КБ | 92–102 мкс |
| SHA-256 ×2 (id + work) | 27–35 мкс |
| PoW mining (ожидание ~65 536 итераций) | ~0.9 с (уже в `Isolate.run`) |

⇒ **~8.3 мс CPU на один входящий пакет** на десктопе (3×2.4 + 0.9 + 0.2), и это на UI-изоляте.
⇒ `restore` полного стора (128 пакетов) ≈ **0.6 с** на десктопе; плюс outbox до 256 ≈ **1.2 с**;
на телефоне ожидаемо 2–4× больше. Всё это — в `_start()`, без изолята, после первого кадра (не блокирует
первый кадр, но подвешивает UI).

**Уже есть изолят рядом?** Только для PoW при создании пакета: `Isolate.run(() => _mine(id))`
(`mesh_packet.dart:110-111`). Для parse/verify/decrypt изолята нет.

**Побочно:** на каждое принятое сообщение создаётся квитанция — `createMeshPacket` → Ed25519 sign + PoW в изоляте
(`bluetooth_mesh_service.dart:501-517`), т.е. ~0.9 с CPU в фоне на каждое входящее сообщение (это уже вне UI-изолята).

### 1.2 Аудио: `VoiceFilterProcessor`

- Вызов ровно один: `VoiceRecorderService.stopRecording` (`lib/core/utils/voice_recorder_service.dart:95`), **после** `_recorder.stop()`, только если `!kIsWeb && preset != none && path.endsWith('.wav')`.
- **Не в реальном времени** — пост-обработка всего файла на UI-изоляте, синхронно (`applyToWavBytes` — чистая синхронная функция, `voice_filter_processor.dart:13-31`).
- Объём: запись WAV **24 кГц, моно, 16 бит** (`voice_recorder_service.dart:39-47`) ⇒ 48 КБ/с; 60 с ≈ 2.75 МБ ≈ 1.44 млн сэмплов. Внутри создаётся `List<double>` (11.5 МБ) + промежуточные копии (`_toMonoNormalized`, `out`, `pitched`, `norm` в pitch-shift) — десятки МБ аллокаций.
- Замер `applyToWavBytes` на реальном коде (x64):

| пресет | 10 с | 60 с |
|---|---|---|
| echo | 28 мс | 202 мс |
| robot | 33 мс | 199 мс |
| radio | 43 мс | 236 мс |
| helium | 64 мс | 372 мс |
| anonymous | 63 мс | 435 мс |
| deep | 64 мс | 439 мс |

⇒ **0.2–0.44 с фриза UI на десктопе за одно голосовое с эффектом**; на телефоне ожидаемо 0.6–2 с.
Частота: только когда пользователь выбрал эффект ≠ none и отправил голосовое — редко, но заметно.
Изолята рядом нет. Прецедент в проекте есть: `compute`/`Isolate.run` уже используются в 14 местах, в т.ч.
пороговый паттерн `_kCryptoIsolateThresholdBytes = 64*1024` (`core/network/web_socket_client.dart:15,675`).

### 1.3 `message_model.dart:314` / `DateTime.tryParse`

- `sentAt: parseApiDateTime(...)` (`lib/models/api/message_model.dart:314`) → `parseApiDateTime` (`core/utils/datetime_helpers.dart:9`): `trim()` + `DateTime.tryParse` + regex `_hasExplicitTimeZone` + `DateTime.utc(...)`. То же на `edited_at` (:315), и в `session_model`, `call_models`.
- Путь: `ApiMessage.fromJson` — при чтении кэша чата, при fetch истории, при push. Т.е. на каждое сообщение, O(n) на чат.
- Замер: **1.90 мкс/сообщение** (из них `DateTime.tryParse` 1.11 мкс). 500 сообщений ≈ **1 мс**. Для сравнения — одна Ed25519-верификация = 2400 мкс.
- Хранить epoch int вместо ISO можно только ценой смены протокола (сервер отдаёт ISO-строки) и формата Hive-кэша. Выигрыш ~0.8 мкс/сообщение.
- **Не кандидат ни для Rust, ни для срочной Dart-оптимизации.**

### 1.4 Таблица вердиктов

| кандидат | живой | частота | уже есть изолят | вердикт |
|---|---|---|---|---|
| `MeshPacket.parse` (2× Ed25519 verify + SHA-256 + json) | **да** — default-on на Android/Windows, стартует на каждом запуске (`mesh_preferences.dart:27`, `bluetooth_mesh_service.dart:758`) | низкая-средняя по сообщениям, но всплески до 256 кадров/мин/пир (32 пира); на старте — до 128+256 пакетов подряд | нет (изолят только для PoW, `mesh_packet.dart:111`) | **Единственный по-настоящему живой кандидат.** Сначала бесплатные шаги: убрать дубль-верификацию в `decrypt` (3→2), не парсить один wire дважды, вынести parse в `Isolate.run` с порогом. Rust (FFI/JNI) — только после этого, если профиль покажет p95 > 50 мс или ≥10 верификаций/с |
| `OrdinaryCodec.decrypt` (Ed25519 + X25519 + HKDF + AES) | да (тот же путь + все E2EE-сообщения) | на каждое входящее mesh-сообщение и на каждое обычное E2EE-сообщение (`backend_chat_provider.dart` decrypt) | нет | **Живой, но это уже известный P0-2** из `audit/perf-status.md`. Rust-обёртка над ed25519/x25519/aes-gcm даст 5–20× на всё E2EE сразу — это более ценно, чем только mesh |
| `VoiceFilterProcessor.applyToWavBytes` | да, но редко (`voice_recorder_service.dart:95`) | один раз на отправленное голосовое с эффектом; 0.2–0.44 с (десктоп) | нет | **Rust не первый шаг.** Достаточно `Isolate.run`/`compute` (функция чистая, вход/выход `Uint8List`). Rust имеет смысл только если понадобится real-time превью эффекта |
| `parseApiDateTime` (`message_model.dart:314`) | да, но микро | 1.9 мкс × сообщения | нет | **Не кандидат.** Ни Rust, ни переделка модели не оправданы |

---

## Раздел 2. Размер и запуск: что ещё можно оптимизировать

Опорные замеры этой машины:

- `assets/` = **62.8 МБ / 1267 файлов** (подтверждено `Measure-Object`), из них:
  `fonts/` 45.2 МБ (material_symbols **33.0 МБ** = 14.39 + 10.16 + 8.43; NotoColorEmoji **10.2 МБ**),
  `emoji/animated` **10.1 МБ / 881 файл**, `developers` **5.4 МБ / 6 файлов**.
- Собранный бандл `build/flutter_assets` = **66.1 МБ** (assets + `MaterialIcons-Regular.otf` 1.6 МБ).

### 2.1 Material Symbols (33 МБ)

- Используются все три семейства: единственное место выбора — `_resolveFontFamily`
  (`lib/widgets/wallpaper/chat_wallpaper_painter.dart:743-751`) по `MaterialSymbolsStyle.outlined/rounded/sharp`.
  Удалить семейство нельзя без удаления стиля обоев.
- Glyph-subsetting для кастомных шрифтов Flutter не делает (`uses-material-design` tree-shake касается только MaterialIcons), поэтому обрезка по codepoints — только вручную.
- **В репозитории есть `tool/optimize_symbol_fonts.py`** (пинит оси `GRAD`/`opsz`, сохраняет все codepoints и веса 100–700). Исходные файлы **не оптимизированы** — проверено `fontTools`: у всех трёх `axes=['FILL','GRAD','opsz','wght']`, 6605 глифов.
- **Прогнал инструмент в temp (`--output-dir`) — результат:**

| файл | сейчас | после | экономия |
|---|---|---|---|
| MaterialSymbolsOutlined.ttf | 10.16 МБ | 3.02 МБ | −7.1 МБ |
| MaterialSymbolsRounded.ttf | 14.39 МБ | 4.05 МБ | −10.3 МБ |
| MaterialSymbolsSharp.ttf | 8.43 МБ | 2.53 МБ | −5.9 МБ |
| **итого** | **33.0 МБ** | **9.6 МБ** | **−23.4 МБ** |

- **Важно:** в CI шаг `python3 tool/optimize_symbol_fonts.py` есть **только в job `build-android`**
  (`.github/workflows/build.yml:226-229`). В `build-windows` (:303-341) и `build-web` (:380-409) его **нет** ⇒
  **Windows-инсталлятор и веб-сборка везут все 33 МБ**. Добавление одного шага в два job'а — самый дешёвый выигрыш.

### 2.2 `assets/developers` 5.4 МБ

Код ссылается только на `Sanlsan_clean.png` (0.18 МБ) и `SH20FK_clean.png` (0.23 МБ) — `lib/core/constants/team.dart:44,52`.
`KarlovPrime_clean.png`, `KarlovPrime.png`, `Sanlsan.jpg`, `SH20FK.png` не используются нигде (grep по `lib/`) ⇒ **−5.0 МБ** без риска.

### 2.3 Анимированные emoji 10.1 МБ / 881 файл

Скриптовая сверка `animatedNotoEmojiIds` (`core/utils/noto_emoji_catalog.dart`) с содержимым
`assets/emoji/animated`: **881 id ↔ 881 файл, 0 лишних, 0 недостающих**. Т.е. удалить часть нельзя без отключения анимации
для соответствующих emoji. Потенциал: перевести на догрузку по требованию (CDN + локальный кэш, как уже делается
для стикеров/медиа) ⇒ −10.1 МБ на всех платформах. Риск средний: анимация перестанет работать офлайн «из коробки».

### 2.4 NotoColorEmoji 10.2 МБ

Объявлен как font family `NotoColorEmoji` (`pubspec.yaml:160-162`) и используется в типографике
(`core/theme/app_typography.dart:16`, `core/utils/noto_emoji.dart:12`). На Android/Windows есть системный
цветной emoji-шрифт. Отказ от бандла ⇒ −10.2 МБ, но меняется вид эмодзи (и, возможно, набор). Риск средне-высокий (дизайн).

### 2.5 Тяжёлые зависимости из `pubspec.yaml`

Проверено по коду (`grep` + точки инициализации):

| зависимость | грузится на старте? | можно ли лениво |
|---|---|---|
| `firebase_core` / `firebase_messaging` | **нет** — `Firebase.initializeApp` вызывается в `addPostFrameCallback` (`main.dart:239-294`), плюс `prepareDeferredFirebase()` (`main.dart:90`) | уже отложено; Android-only cost |
| `flutter_webrtc` / `dart_webrtc` | **нет** — `createPeerConnection` только в звонках (`services/calls/webrtc_call_session.dart:371`) | уже лениво; влияет только на размер APK/нативные libs |
| `camera` | **нет** — только экраны съёмки (`quick_camera_capture_screen.dart`, `circle_video_recorder_screen.dart`, `video_pipeline.dart`) | уже лениво |
| `video_player` / `chewie` | **нет** — только при воспроизведении | уже лениво |
| `just_audio` / `audioplayers` | **частично да**: `soundServiceProvider` создаётся при первом UI-тике (`widgets/nav/app_nav_item.dart:74`, `widgets/settings/pressable_surface.dart:82`) и в `SoundService.initialize()` создаёт **8 `AudioPlayer`** (`core/sound/app_sound.dart:278-309`) | можно инициализировать по первому реальному звуку — но это про старт, не про размер |
| `photo_manager` | **нет** — только пикеры (`m3_file_picker_bottom_sheet.dart`, `media_grid_picker.dart`) | уже лениво |
| `flutter_pdfview` | **нет** — только `native_file_viewer_screen.dart` | уже лениво; кандидат в Android dynamic feature |
| `qr_flutter` | **нет** — только экраны/шиты с QR | уже лениво |
| `hive` | **да**, осознанно (`main.dart:97-106`) | см. 2.6 |
| `pointycastle` | нет отдельной инициализации; используется только в `enrollment_proof.dart` (RSA) и потоковом AES-GCM шифре файлов | влияет только на размер кода |

**`deferred-components` / `deferred import` в проекте отсутствуют** (grep по `lib/`, `android/`, `tool/`, `.github/`: нет `deferred as`, нет `deferred_components`).
**Конфигурации `--analyze-size` тоже нет** ни в одном скрипте/воркфлоу (`.github/workflows/build.yml` собирает APK/AAB/Windows/Web без анализа размера).
Потенциал: Android Play Feature Delivery для `flutter_pdfview`/`camera`/`qr_flutter`-экранов; для web — `deferred import` тяжёлых экранов. Требует замера базовой линии (§3), риск средний (усложнение сборки/публикации).

### 2.6 Старт `lib/main.dart` и Hive

- Первый кадр: `runApp(AppStartupGate(...))` (`main.dart:65-75`) — рисуется сплэш, и только в `addPostFrameCallback`
  стартует `_initializeLocalState` (`widgets/app_startup_gate.dart:36`). Это сделано правильно.
- **Но** поддерево приложения не монтируется, пока не завершится `_initializeLocalState` (`main.dart:86-117`), а там:
  `Future.wait([ Hive.initFlutter + CacheService(6 боксов) + EncryptedMessageCache(2 бокса) + ChatMediaCache(1 бокс), SharedPreferences ])`.
  Параллелизм есть (`Future.wait`), но всё это — до первого кадра приложения.
- `BackgroundService.init()` (`main.dart:115`) — синхронный вызов после хранилищ.
- **Hive-боксы на старте: 9** — `CacheService._openBoxes` (`core/storage/cache_service.dart:58-68`, 6 боксов:
  chats/messages/contacts/profiles/feed/stickers), `EncryptedMessageCache._initialize` (`encrypted_message_cache.dart:87-115`, `enc_messages_v1` + `enc_sender_plaintext_v2`), `ChatMediaCache.ensureInitialized` (`chat_media_cache.dart:73-78`).
  Плюс **после** первого кадра, при залогиненной сессии: `secret_journal_v2_$userId` и `secret_attachments_v2_$userId`
  (`providers/secret_chat_provider.dart:146,172` — с `journal.restore()` и `WsMediaFetcher.clearPrivateCache`), и
  зашифрованный `app_notifications_v1` (`notifications_provider.dart:139` → `notification_history_store.dart:39-51`, ещё и secure storage + легаси-миграция).
- **Риск в `EncryptedMessageCache._initialize`:** при наличии старого бокса выполняется синхронная миграция
  `legacy.toMap()` с построчным шифрованием/сверкой (`encrypted_message_cache.dart:93-115`) — на большом легаси-кэше это
  блокирующий старт. Проверить на реальных данных.
- Объёмы Hive на этой машине (Documents): `enc_messages_v1` 1.48 МБ, `chats_cache_box` 0.51 МБ, `enc_history_archive_v1` 0.46 МБ,
  остальные ≈0 ⇒ открытие 9 боксов тут дешёвое; у активного пользователя будет больше. Инструментального замера нет.
- Скрытая цена старта: **autostart mesh** — открытие бокса + `restore`/outbox (до 384 пакетов, ~0.6–3 с крипты на UI-изоляте, §1.1) на каждом запуске, плюс таймер 2 с и 30 с. Для пользователей, которым BLE не нужен, это чистые потери: можно откладывать до первого открытия чата/включения в настройках.

### 2.7 Таблица «что / сейчас / потенциал / как проверить / риск»

| что | сейчас | потенциал | как проверить | риск |
|---|---|---|---|---|
| Material Symbols (3 семейства) | 33.0 МБ в `assets/fonts/material_symbols`; оптимизация применяется **только** в Android-job CI (`build.yml:226`), Windows/Web везут полные файлы | **−23.4 МБ** на Windows и Web (Android уже получает это в CI) | прогнать `python tool/optimize_symbol_fonts.py --output-dir <tmp>` и сравнить размеры; затем добавить тот же шаг в `build-windows`/`build-web` | низкий: все codepoints и веса 100–700 сохранены, инструмент сам сверяет границы глифов; визуально проверить обои |
| Неиспользуемые фото команды | `assets/developers` 5.4 МБ, код ссылается только на 2 файла (0.41 МБ) | **−5.0 МБ** | grep `assets/developers` по `lib/` (2 совпадения в `team.dart`) | нулевой |
| Анимированные emoji | 10.1 МБ, 881 `.json.gz`, все 881 id используются каталогом | **−10.1 МБ** (догрузка по требованию) | сверка каталога и каталога файлов (уже сделана: 881↔881) | средний: нужен CDN + кэш + офлайн-фолбэк; для web/desktop тоже |
| NotoColorEmoji.ttf | 10.2 МБ как font family | **−10.2 МБ** при переходе на системный emoji-шрифт | сравнить рендер эмодзи с системным шрифтом на Android/Windows | средне-высокий: меняется вид/набор эмодзи |
| code splitting (`deferred import` / dynamic feature) | нет нигде; `--analyze-size` не настроен | не измерено; кандидаты: pdfview, camera, qr, экраны редактора | `flutter build appbundle --release --analyze-size`; смотреть вклад `libflutter`/плагинов | средний: усложняет сборку и публикацию; web-only выигрыш реален |
| Bootstrap до первого кадра | 9 Hive-боксов + SharedPreferences + `AppStartupGate` до монтирования приложения (`main.dart:86-117`) | ранний первый кадр приложения: оставить в критическом пути только `chats_cache_box` + `enc_messages_v1` + prefs; остальное (media/feed/stickers/sender-plaintext) — post-frame | уже есть логи: `AppLogger` пишет `Local storage initialization started / Hive initialized / Local caches opened / Preferences loaded / Application started` (`main.dart:96-116`) — снять дельты | низкий-средний: гонки при раннем чтении кэша; нужен ленивый `ensureInitialized` (он уже есть в каждом классе) |
| Легаси-миграция sender-plaintext | при наличии старого бокса — полный `toMap()` + шифрование в bootstrap | убрать из критического пути (перенести в post-frame/фон) | проверить на устройстве с реальным `enc_sender_plaintext_legacy`; залогировать размер бокса | средний: не потерять данные при миграции |
| Autostart mesh | на каждом запуске: Hive-бокс + до 384 `MeshPacket.parse` + 2 таймера | 0.6–3 с CPU на UI-изоляте + постоянный таймер можно убрать из старта | временно залогировать `Stopwatch` вокруг `restore()`/outbox и число пакетов | низкий-средний: offline-доставка начнёт работать позже (после открытия чата) |
| `SoundService` | 8 `AudioPlayer` при первом UI-тике (`app_sound.dart:278-309`) | ленивая инициализация на первый реальный звук | профиль старта с `--trace-startup`, смотреть platform-channel вызовы | низкий: задержка первого тика, если инициализировать на лету |
| Материал-иконки в бандле | `build/flutter_assets/fonts/MaterialIcons-Regular.otf` 1.6 МБ — признак **не-release** бандла (tree-shake не применён) | в release ожидается единицы КБ; нужно подтвердить на релизной сборке | `flutter build apk --release --analyze-size` и размер `MaterialIcons` в отчёте | нет (это проверка, а не правка) |

---

## Раздел 3. Что измерять перед правками

### 3.1 Базовая линия размера (до любых изменений)

```powershell
cd "F:\Niosmess V2\pulse_flutter"

# Android: json-отчёт по секциям (Dart AOT, нативные libs, assets, шрифты)
flutter build appbundle --release --target-platform android-arm64 --analyze-size `
  --dart-define=NIOSMESS_BUILD_COMMIT=baseline

# Windows: то же для десктопа
flutter build windows --release --analyze-size --dart-define=NIOSMESS_BUILD_COMMIT=baseline

# Web
flutter build web --release --analyze-size --dart-define=NIOSMESS_BUILD_COMMIT=baseline
```

Смотреть: размер `assets/fonts/*`, `assets/emoji/animated`, `assets/developers`, вклад каждого плагина,
`MaterialIcons-Regular.otf`. Зафиксировать в отчёте как «до».
Плюс быстрая локальная проверка без полной сборки:

```powershell
$t=(Get-ChildItem build\flutter_assets -Recurse -File | Measure-Object Length -Sum); "{0:N1} MB" -f ($t.Sum/1MB)
python tool\optimize_symbol_fonts.py --output-dir "$env:TEMP\symbols"   # ожидаемо 33.0 -> 9.6 MB
```

### 3.2 Метрики старта

```powershell
# первый кадр / время до интерактива (Android, профиль)
flutter run --profile --trace-startup --target-platform android-arm64
# затем в DevTools → Performance: startup timeline, и adb:
adb shell am start -W -n com.niosmess.pulse/.MainActivity
```

Метрики, которые надо получить и записать:

- время от `main()` до первого кадра (уже логируется: `BOOTSTRAP_FIRST_FRAME`, `main.dart:77`);
- дельты между `Local storage initialization started` → `Hive initialized` → `Local caches opened` → `Preferences loaded` → `Application started`;
- время `Hive.openBox` по каждому из 9 боксов (обернуть `Stopwatch` временно, либо `Hive` лог);
- время `MeshRouter.restore()` и разбора outbox (число пакетов + мс);
- `am start -W` TotalTime / WaitTime до и после правок.

### 3.3 Метрики mesh (решение «Rust или нет»)

Временная инструментация (по образцу `PERF_TRACE`, `core/performance/adaptive_performance_provider.dart`):

- счётчики: пакетов/мин принято, пакетов/мин отдано, верификаций/с, среднее и p95 времени `MeshPacket.parse`
  и `openMeshPacket`, глубина очереди `_serial`;
- сценарий: 2 устройства, 1 личный чат, отправка 20 сообщений подряд при включённом BLE + отдельно «релей» (третье устройство).

**Порог решения:**

- если `verifies/s < 2` и p95 обработки пакета < 30 мс — Rust **не нужен**;
- если p95 > 50 мс или ≥10 верификаций/с — сначала (1) убрать дубль-верификацию (3→2 verify на пакет),
  (2) вынести `parse`+`decrypt` в `Isolate.run` с порогом (как в `web_socket_client.dart:675`),
  (3) только потом Rust-ядро (ed25519/x25519/aes-gcm) через FFI.

### 3.4 Метрики аудио

```powershell
# локально (уже воспроизводимо): тот же бенч на реальном процессоре
dart --packages=".dart_tool\package_config.json" <script_с_applyToWavBytes>
```

На устройстве: записать 30 и 60 с голосовое с пресетами `deep`, `anonymous`, `helium`; снять DevTools timeline,
найти кадры > 16 мс после `_recorder.stop()`; целевой показатель — **ни одного кадра > 32 мс** (после переноса в изолят).

---

## Раздел 4. Что проверить не удалось (явно)

1. **Реальные тайминги на Android/ARM.** Все цифры крипты и DSP — Dart VM x64. Коэффициент для телефона оценочный.
2. **Реальная частота mesh-пакетов в продакшене.** Телеметрии в репозитории нет; лимиты роутера (`256 кадров/мин/пир`, 32 пира) — только потолок. Нужны счётчики из §3.3.
3. **Размеры релизных артефактов.** В `build/` лежат тестовые/отладочные assets (`unit_test_assets`, полный `MaterialIcons-Regular.otf` 1.6 МБ), поэтому вывод «иконки не subset'ятся» к release не применять — нужно собрать с `--analyze-size`.
4. **Применяется ли оптимизация шрифтов к Windows/Web в CI.** По коду `build.yml` шаг есть только в `build-android` (строки 226-229) и не найден в `build-windows`/`build-web`; фактический размер опубликованных артефактов не проверялся.
5. **Размеры Hive-боксов у реальных пользователей.** Локальные данные (2.5 МБ суммарно) не репрезентативны; эффект отложенного открытия боксов не измерен.
6. **Наличие легаси-бокса `enc_sender_plaintext_legacy`** на устройствах (влияет на блокирующую миграцию при старте) — не проверялось.
7. **Нужен ли NotoColorEmoji дизайну** (уникальный вид эмодзи) — продуктовое решение, не проверяемо по коду.
8. **Используют ли пользователи голосовые эффекты** — аналитики в репозитории нет, поэтому приоритет аудио-правки не определить по данным.
