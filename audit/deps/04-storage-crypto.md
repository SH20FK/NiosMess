# 04 — storage / crypto / плагины состояния

Область: `pulse_flutter/lib`, `pulse_flutter/test`, `pulse_flutter/integration_test`,
`packages/nios_sdk`, `packages/nios_mls`. Исключено: `build/`, `.dart_tool/`,
`windows|linux/flutter/ephemeral/.plugin_symlinks/**` (оттуда в grep лезут копии
исходников самих плагинов).

| пакет | файлов | обращений | где (топ-3) | вердикт |
|---|---|---|---|---|
| package_info_plus | 4 (3 lib + 1 test) | 12 (`PackageInfo`), из них 2 `fromPlatform` | `lib/services/update/app_update_service.dart:5,249` — сравнение текущей сборки с серверной; `lib/screens/settings_about_screen.dart:41,49`; `lib/widgets/settings/about_identity_widgets.dart:19` | нужен |
| flutter_secure_storage | 38 (16 lib + 22 test) | ~71 `FlutterSecureStorage`, 39 вызовов `_storage.read/write/delete` в проде | `lib/services/e2ee_service.dart:37,45-47` (X25519/Ed25519 приватные ключи); `lib/providers/auth_provider.dart:13` (токены, 4 обращения); `lib/core/storage/encrypted_message_cache.dart:7` (ключ AES-GCM кэша) | нужен; внимание: ни одной платформенной опции (`AndroidOptions`/`IOSOptions`/`WebOptions`) в проекте не задано — всё на дефолтах плагина, включая web-режим |
| photo_manager | 2 | 98 (`PhotoManager.*`, `AssetEntity`, `AssetPathEntity`) | `lib/widgets/media_grid_picker.dart:10,212` (`getAssetPathList`, пагинация 90); `lib/widgets/m3_file_picker_bottom_sheet.dart:6,170` (`requestPermissionExtend`, `presentLimited`); единственная точка входа — `lib/screens/chat_detail_screen.dart:1188` | нужен, но узко: галерея только Android/iOS/macOS, web и Windows/Linux уходят в `file_picker` |
| connectivity_plus | 1 | 15 в модуле + 18 потребителей провайдеров в 12 файлах | `lib/providers/connectivity_provider.dart:1,24,32` (`checkConnectivity`, `onConnectivityChanged`); `autoDownloadAllowedProvider` → `lib/widgets/chat/bubble/media_album_bubble.dart:69`, `lib/providers/upload_queue_provider.dart:108`, `lib/widgets/chat/ws_cached_image.dart` | нужен |
| hive | 16 (6 lib, из них 3 в `packages/`, + 10 test) | 77 `Hive.openBox/box/boxExists` (436 строк с `Box<`/`Hive.` по всему дереву) | `lib/core/storage/cache_service.dart:61-66` — 6 боксов на холодном старте (chats/messages/contacts/profiles/feed/stickers); `lib/core/storage/encrypted_message_cache.dart:90-91` (шифрованные значения); `lib/providers/secret_chat_provider.dart:146,155` (журнал на аккаунт) | нужен; hive_ce/JSON-замены в проекте нет |
| hive_flutter | 20 (8 lib + 12 test) | 1 реальный вызов (`Hive.initFlutter()`), остальное — реэкспорт `Hive` | `lib/core/storage/hive_bootstrap.dart:2,33` — единственное место; при этом 21 тестовый файл зовёт `Hive.init(path)` напрямую (`test/unit/hive_bootstrap_account_cache_test.dart:32` и др.) | нужен только ради одной строки; по сути тонкая обёртка над `hive` |
| cryptography | 49 (18 lib приложения + 6 lib пакетов + 25 тестов) | ~350 (`X25519`/`Ed25519` 72, `AesGcm/Chacha20` 53, `Hkdf/Hmac.sha256`, `Sha256()`) | `lib/services/double_ratchet_service.dart:175,191,342,442` — hot path сообщений; `lib/services/e2ee_service.dart:38`; `lib/core/network/web_socket_client.dart:22,39` (транспорт) | нужен — единственный реальный крипто-движок; внимание: чистый Dart, `cryptography_flutter` в pubspec нет |
| pointycastle | 3 | 4 (+5 строк импорта) | `lib/core/utils/e2ee_streaming_file_cipher.dart:92` (`GCMBlockCipher(AESEngine())`, потоковое шифрование файлов); `lib/services/ordinary_e2ee/enrollment_proof.dart:133` (`rsa.RSASigner` + `SHA256Digest`, проверка JWKS NiosID); `lib/core/utils/e2ee_file_crypto.dart:7,71` (только тип `InvalidCipherTextException`) | нужен ради RSA; внимание: вторая реализация AES-GCM и два обхода багов 4.0.0 |
| crypto | 32 (13 lib приложения + 11 lib пакетов + 8 тестов) | 37 вызовов (`sha256.`/`sha512.`/`sha1.`/`md5.`/`Hmac(`) | `lib/services/blob_hasher.dart:3`; `lib/services/update/update_integrity.dart:1` (подпись/хэш обновления); `lib/core/network/pkce_helper.dart:5` (PKCE); в пакетах — `packages/nios_sdk/lib/src/trust/merkle.dart:3`, `.../stream/bao_tree.dart:4`, `packages/nios_mls/lib/src/client.dart:6` (`Hmac` на `:321`) | нужен как хэш-движок; внимание: дублирует хэши из `cryptography` в 7 файлах |
| loading_indicator_m3e | 1 | 1 импорт + 1 конструктор, но 140 точек `AppLoadingIndicator` по приложению | `lib/widgets/pulse_loading_indicator.dart:2,56` — единственная обёртка, весь прогресс идёт через неё | нужен |

Нативно (без Dart-импорта): в `android/.../GeneratedPluginRegistrant.java` зарегистрированы
`connectivity_plus`, `flutter_secure_storage`, `package_info_plus`, `photo_manager`.
В `windows/flutter/generated_plugin_registrant.cc` — `connectivity_plus` и
`flutter_secure_storage_windows`; `photo_manager` на Windows нет, что совпадает с
платформенным guard'ом в пикере.

## Крипто-трио: `cryptography` + `pointycastle` + `crypto`

**Ни один из трёх не является «только транзитивным»**: все три объявлены в
`pulse_flutter/pubspec.yaml:72-74`, и `cryptography`/`crypto`/`hive` дополнительно
объявлены в `packages/nios_sdk/pubspec.yaml` и `packages/nios_mls/pubspec.yaml`.
`pointycastle` при этом не транзитивный, а прямой пин (`pointycastle: 4.0.0`), так что
вердикт «мёртвый» или «только транзитивно» не подходит ни к одному из трёх.
Отдельно: в репозитории есть ещё два локальных пакета, `packages/nios_iroh` и
`packages/nios_lab`, которые тоже объявляют и импортируют `crypto`/`cryptography`,
но `pulse_flutter` на них не ссылается (в pubspec и в `lib/` нет упоминаний `nios_iroh`).
Их файлы в счётчики ниже не входят.

Что делает каждый:

- **`cryptography` (2.9.0) — основной движок.** 24 файла в lib (18 приложение + 6 пакеты),
  ~350 обращений. Всё E2EE: `X25519` (DH ratchet, `double_ratchet_service.dart:175`),
  `Ed25519` (идентичность, `ed25519_identity_service.dart`), `Hkdf(hmac: Hmac.sha256())`
  для деривации ключей (`:191`), `AesGcm.with256bits()` для сообщений (`:342,442`),
  `Chacha20.poly1305Aead()` для bluetooth-mesh (`headless_core_isolate.dart:46`),
  транспорт `web_socket_client.dart:22,39`, `packages/nios_sdk/lib/src/trust/*` (VRF,
  transparency), `packages/nios_mls/lib/src/client.dart`.
  В pubspec **нет** `cryptography_flutter`, то есть работают чистые Dart-реализации
  (`DartAesGcm`, `DartX25519`) без платформенного ускорения.
- **`pointycastle` (4.0.0, пин) — две точечные задачи.** (1) RSA PKCS#1 v1.5
  (`enrollment_proof.dart:133-142`): проверка подписи JWKS `https://ni-os.ru/oauth/jwks`
  при авто-привязке NiosID. В `cryptography` 2.x RSA нет, так что это единственный
  безальтернативный потребитель. (2) потоковый AES-GCM для файлов секретных чатов
  (`e2ee_streaming_file_cipher.dart:92`) — с постоянным рабочим набором, по чанкам 64 КиБ.
  Плюс один импорт ради типа исключения (`e2ee_file_crypto.dart:7,71`).
  В самом файле зафиксированы два известных бага 4.0.0: `GCM.doFinal` хранит только
  младший uint32 длины, из-за чего на 2^29 байт длина «сворачивается» (`:15-18`), и
  баг обработки неполного блока в `processBytes` (`:116`) — оба обойдены вручную.
- **`crypto` (3.0.6) — только хэши и HMAC.** 24 файла в lib: 13 в приложении, 11 в
  пакетах (`nios_sdk` — 10, `nios_mls` — 1).
  Приложение: PKCE (`pkce_helper.dart:5`), целостность обновлений (`update_integrity.dart`),
  хэш блобов (`blob_hasher.dart`), хэш вложений (`ws_media_fetcher.dart:6`),
  отпечаток интерактивного сообщения (`models/interactive_message.dart:22`).

**Где дублирование реально есть:**

1. **Хэши в двух библиотеках.** 7 файлов импортируют и `cryptography`, и `crypto`:
   `core/worker/headless_core_isolate.dart`, `services/bluetooth_mesh/mesh_packet.dart`,
   `services/ordinary_e2ee/ordinary_e2ee_service.dart`,
   `services/protocol/nios_protocol_accounts.dart`,
   `packages/nios_sdk/lib/src/stream/crypto_executor.dart`,
   `packages/nios_sdk/lib/src/trust/vrf.dart`, `packages/nios_mls/lib/src/client.dart`.
   Типичный пример одной задачи двумя API: `enrollment_proof.dart:23` считает
   `await Sha256().hash(...)` (async, `cryptography`), а `headless_core_isolate.dart:159` —
   `digest.sha256.convert(...)` (sync, `crypto`). Аналогично HMAC: `Hmac.sha256()`
   (`double_ratchet_service.dart:191`) против `digest.Hmac(...)` (`nios_sdk/.../vrf.dart:71`,
   `nios_mls/.../client.dart:321`).
2. **AES-GCM реализован дважды для одного и того же конверта** `[nonce12|ciphertext|tag16]`:
   `AesGcm.with256bits()` в `cryptography` (маленькие файлы и всё остальное) и
   `GCMBlockCipher(AESEngine())` в `pointycastle` (потоковые файлы). `e2ee_streaming_file_cipher.dart:15-24`
   прямо держит переключатель по длине (≥512 МиБ уходит обратно на `cryptography`),
   то есть два движка сознательно сосуществуют и обязаны выдавать совместимый тег.
3. **RSA — единственное, чего `cryptography` не умеет.** Убрать `pointycastle` нельзя без
   замены проверки JWKS-подписи.

**Про «pure-Dart крипту в UI-изоляте» — картина такая:**

- Инфраструктура выноса уже написана: `lib/core/worker/headless_core_isolate.dart`
  (AesGcm + Chacha20 + sha256) и клиент `lib/core/worker/headless_worker_client.dart:11`
  с провайдером `headlessWorkerClientProvider`.
- Но в продовом коде провайдер **никем не читается**: единственные упоминания —
  сам файл и `test/unit/headless_worker_test.dart:15`. То есть крипто-воркер существует,
  покрыт тестом и не подключён.
- Файловое шифрование и транспорт вынесены: `e2ee_file_crypto.dart:36` (`Isolate.run`),
  `encrypted_message_cache.dart:152` (`Isolate.run`), `mesh_packet.dart:111`,
  `web_socket_client.dart:657,680` (порог 64 КиБ).
- А самый горячий путь — Double Ratchet на каждое сообщение — считает
  `AesGcm.with256bits()` прямо в вызывающем изоляте (`double_ratchet_service.dart:342,442`),
  без выноса. Это и есть то самое узкое место; лечится подключением уже написанного
  `HeadlessWorkerClient`, а не сменой пакета.

## `hive` 2.2.3: миграции нет, боксы несущие

- `hive_ce`, `HiveCE`, `sqflite`, `drift`, `isar` — **ноль упоминаний** во всём дереве
  (совпадения по `drift`/`isar` — это `isArchived`, «naming drift» в комментариях).
  Никакой параллельной миграции на форк не начато.
- Ручного JSON-хранилища вместо боксов тоже нет: в `lib/` **ни одного** `writeAsString(`.
- Боксы несущие, а не декоративные: 6 кэш-боксов (`cache_service.dart:61-66`), два бокса
  шифрованного кэша сообщений (`encrypted_message_cache.dart:90-91`), журнал секретов на
  аккаунт (`secret_chat_provider.dart:146,155`), вложения секретов
  (`secret_attachment_store.dart:225`), история уведомлений с `HiveAesCipher`
  (`notification_history_store.dart:50`, `legacy_notification_archive.dart:30`), bluetooth-mesh
  очередь (`bluetooth_mesh_service.dart:209`), медиа-кэш чата (`chat_media_cache.dart:76`),
  ленивый бокс медиа-черновиков (`niosgram_draft_store.dart:116`). Плюс `hive` внутри
  `nios_sdk` (`src/link`, `src/trust`) и `nios_mls` (`src`).
- Гибрид уже сложился сам: `niosgram_draft_store.dart` держит **блобы** в
  `Hive.openLazyBox<Uint8List>` (`:116`), а метаданные и AES-ключ — в
  `FlutterSecureStorage` (`:120-144`); `encrypted_message_cache` шифрует значения AES-GCM,
  ключ берёт из secure storage. То есть «свой слой шифрования над Hive» проект уже написал —
  но не «свой JSON вместо Hive».
- `hive_flutter` нужен ровно для `Hive.initFlutter()` в одном месте
  (`hive_bootstrap.dart:33`); 12 тестовых файлов импортируют его только ради реэкспорта
  `Hive`, а всего `Hive.init(path)` напрямую зовут 21 тестовый файл — то есть обёртка
  не нужна и там.
- Мёртвый бокс: `CacheService.saveMessages/getCachedMessages` (`cache_service.dart:123,137`)
  не вызываются ниоткуда за пределами класса — живёт `EncryptedMessageCache`
  (`backend_chat_provider.dart:2346,2382,3091`). При этом `messages_cache_box` открывается
  на каждом холодном старте (`:62`) и только очищается.

## `photo_manager`: не дубль `media_grid_picker`, а его фундамент

`media_grid_picker.dart` — собственный **UI**, но данные для него даёт именно
`photo_manager` (`AssetPathEntity`, `AssetEntity`, `getAssetPathList`,
`requestPermissionExtend`, `presentLimited`). Дублирования нет: своего доступа к
медиатеке проект не писал. Ограничения использования:

- одна точка входа — `lib/screens/chat_detail_screen.dart:1188` → `showM3FilePicker`;
- `kIsWeb` отдаёт выбор `file_picker` до всякой галереи
  (`m3_file_picker_bottom_sheet.dart:47`);
- галерея включается только при `!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)`
  (`m3_file_picker_bottom_sheet.dart:155`, `media_grid_picker.dart:125`);
- в Windows-регистранте плагина нет — согласовано с guard'ом.

## Что стоит удалить/заменить

1. **`hive_flutter` → убрать пакет.** Заменить один `Hive.initFlutter()` в
   `hive_bootstrap.dart:33` на `getApplicationSupportDirectory()` + `Hive.init(path)`
   (`path_provider` уже в зависимостях) и переписать 20 импортов на `package:hive/hive.dart`.
   Минус зависимость, поведение не меняется — тесты уже живут на `Hive.init`.
2. **Подключить `HeadlessWorkerClient` к Double Ratchet** (или удалить его вместе с
   `headless_core_isolate.dart`, раз он не используется). Сейчас на горячем пути
   `AesGcm.with256bits()` + `X25519.sharedSecretKey` считаются в UI-изоляте
   (`double_ratchet_service.dart:283,342,442`), при том что воркер для этого уже написан.
3. **Сузить поверхность `pointycastle` до RSA.** Потоковый AES-GCM
   (`e2ee_streaming_file_cipher.dart`) — дубль `cryptography`-конверта с двумя ручными
   обходами багов 4.0.0; либо оставить осознанно (ради постоянной памяти), либо
   переписать на `cryptography` с чанкованием и убрать `block/aes.dart`+`block/modes/gcm.dart`,
   оставив только `api.dart show InvalidCipherTextException` и RSA-импорт.
4. **Унифицировать хэши.** `crypto` всё равно остаётся (нужен `nios_sdk`/`nios_mls`), а в
   приложении 7 файлов тянут оба API для одного и того же — выбрать sync `crypto` для хэшей
   и не заводить `Sha256()` из `cryptography` там, где нет streaming-нужды.
5. **`CacheService` — выпилить `messages_cache_box`** (`:15,62,123,137`): единственный
   живой кэш сообщений — шифрованный, а этот бокс открывается на старте впустую.
