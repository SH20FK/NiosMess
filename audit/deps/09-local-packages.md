# 09 — flutter_launcher_icons и локальные path-пакеты

## Таблица

| пакет | файлов | обращений | где (топ-3) | вердикт |
|---|---|---|---|---|
| flutter_launcher_icons | 0 (Dart) | 2 (обе в pubspec) | `pubspec.yaml:132` (dev_dependency), `pubspec.yaml:252-260` (конфиг), артефакты `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` + `ios/Runner/Assets.xcassets/AppIcon.appiconset/*` | **нужен** (офлайн-генератор иконок) — но гоняется только вручную, в CI шага нет |
| nios_sdk | 4 в `lib/`, 4 в `test/` | ~68 в `lib/`, ~23 в `test/`, 13 import-строк | `lib/services/protocol/nios_protocol_accounts.dart:11-14` (47), `lib/services/secret_chat/secret_stream_service.dart:7-8` (13), `lib/core/media/background_stream_crypto.dart:4` (6) | **нужен** только `stream.dart` + `media.dart`; `link.dart` (кроме `SqliteWalDurableStore`) и `trust.dart` — **мёртвые** внутри приложения |
| nios_mls | 1 в `lib/` | 3 (импорт + поле + сигнатура) | `lib/services/protocol/nios_protocol_accounts.dart:10`, `:215`, `:515-527` | **мёртвый** (в приложении нулевой вызов) |

## Локальные пакеты: детали

### nios_sdk — `F:\Niosmess V2\packages\nios_sdk` (v0.1.0)

**Размер:** 53 файла без `.dart_tool`; 43 `.dart` (23 в `lib/`, 19 в `test/`, 1 в `example/`); `lib/` — 5282 строки, ~179 КБ.

**Что экспортирует** (`lib/`):
- `nios_sdk.dart` — зонтичная библиотека, реэкспорт всех четырёх ниже (в приложении не используется, импортируются под-библиотеки — это штатный паттерн из README);
- `link.dart` → `src/link/{cipher, durable_session, models, transport}` + `sqlite_durable_store` с conditional-export (`_stub` на web, `ffi`-версия на нативе);
- `stream.dart` → `src/stream/{bao_tree, cancellation, crypto_executor, http_blob_store, manifest, source, stream_object}`;
- `media.dart` → `src/media/authenticated_media_gateway.dart`;
- `trust.dart` → `src/trust/{merkle, transparency, vrf}`.

**Кто импортирует в `lib/`:**
1. `lib/services/protocol/nios_protocol_accounts.dart` — `link`, `media`, `stream`, `trust` (единственный файл, тянущий все четыре);
2. `lib/services/secret_chat/secret_stream_service.dart` — `media`, `stream`;
3. `lib/core/media/background_stream_crypto.dart` — `stream` (`StreamCrypto*`, `executeStreamCrypto` в изоляте);
4. `lib/core/worker/headless_core_isolate.dart` — `link` (`SqliteWalDurableStore`).

Тесты: `test/services/nios_protocol_accounts_test.dart`, `test/services/secret_stream_service_test.dart`, `test/services/secret_stream_chat_delivery_test.dart`, `test/core/background_stream_crypto_test.dart`.

**Что реально живо в рантайме, а что нет:**

| модуль | статус в приложении |
|---|---|
| `stream.dart` | **жив.** `SecretStreamService.prepareFile` → `NiosStream.prepareFile` (`secret_stream_service.dart:165`), `NiosStreamDownload.open` (`:327`), `HttpCiphertextBlobStore` (`:112`). Гейт — `GET /v1/protocols` должен отдать `stream: [1]` (`secret_stream_service.dart:133-150`), иначе фолбэк на старый `E2eeFileCrypto` |
| `media.dart` | **жив.** `AuthenticatedMediaGateway.bind` (`secret_stream_service.dart:414`) для playback зашифрованных вложений |
| `link.dart` | **мёртв**, кроме `SqliteWalDurableStore`. `DurableSession`, `SavedOperation`, `LinkTransport`, `EncryptedEnvelope`, `TransportReceipt` встречаются только как типы `NiosProtocolAccount.startDelivery/…/enqueue*` (`nios_protocol_accounts.dart:301-466`), а `.startDelivery(` / `.enqueueAttachment(` / `.openAttachment(` в `lib/` не вызываются **ни разу** (только `nios_protocol_accounts_test.dart:185,204,259,315,329,400`) |
| `trust.dart` | **мёртв.** `KeyTransparencyClient` / `HiveTransparencyStateStore` живут только внутри `configureTransparency` (`nios_protocol_accounts.dart:483-511`), вызовов `.configureTransparency(` в `lib/` — 0. Дополнительно `nios_protocol_enrollment.dart:40` объявляет `'ktStatements': <int>[]` — пусто |
| `SqliteWalDurableStore` | **мёртв по цепочке владения.** Используется в `headless_core_isolate.dart:47,70`, тот поднимается из `headless_worker_client.dart:64`, а `headlessWorkerClientProvider` (`headless_worker_client.dart:11`) не читается ни в одном файле `lib/` — только в `test/core/worker/headless_worker_test.dart` |

**Собственные зависимости:** `crypto ^3.0.6`, `cryptography ^2.9.0`, `hive ^2.2.3`, `http ^1.5.0`, `path ^1.9.1`, `universal_io ^2.3.1`, `sqlite3 ^2.4.0`.

Пересечение с приложением: `crypto`, `cryptography`, `hive`, `http`, `path`, `universal_io` уже объявлены в `pulse_flutter/pubspec.yaml` с теми же констрейнтами — версии не разъезжаются (в локе `crypto 3.0.7`, `cryptography 2.9.0`, `hive 2.2.3`, `http 1.6.0`, `path 1.9.1`, `universal_io 2.3.1`). **Единственная добавка — `sqlite3 ^2.4.0` (в локе 2.9.4)**: приложение его нигде не импортирует, он приходит только транзитивно и тянет нативный бинарник.

### nios_mls — `F:\Niosmess V2\packages\nios_mls` (v0.1.0)

**Размер:** 17 файлов; 10 `.dart` (4 в `lib/`, 6 в `test/`); `lib/` — 2059 строк, ~72 КБ. Плюс `THIRD_PARTY_NOTICES.txt` на 563 КБ и `pubspec.lock`.

**Что экспортирует:** `nios_mls.dart` → `src/client.dart` (+ `part`-файлы `delivery_coordinator.dart`, `http_delivery_api.dart`). Публичный API: `NiosMlsClient`, `NiosMlsDevice`, `NiosMlsOutbound`, `NiosMlsIncoming`, `NiosMlsException`, `NiosMlsDeliveryCoordinator`, `MlsControlPage`, `HttpMlsDeliveryApi`, `MlsServerHead`, `MlsMembershipReservation`, `MlsCommitReceipt`, `MlsControlEvent`, `MlsApplicationDelivery`, `MlsQueuedIntent`.

**Кто импортирует в `lib/`:** ровно один файл — `lib/services/protocol/nios_protocol_accounts.dart:10`. Дальше:
- поле `NiosMlsClient? _groups` (`:215`) — только чтобы закрыть его в `_close` (`:592`);
- метод `openGroups({required MlsDeviceAuthorizer})` (`:515-527`) — единственная точка входа.

**Вызовов `openGroups(` в `lib/` — ноль.** Ни в `lib/`, ни в `test/`, ни в `integration_test/` нет ни одного `.openGroups(`; `MlsDeviceAuthorizer` не реализуется нигде в приложении, `NiosMlsClient` не инстанцируется нигде, кроме самого `openGroups`.

**Косвенное подтверждение, что MLS не включён:** `lib/services/protocol/nios_protocol_enrollment.dart:38` объявляет в capability-манифесте `'mls': {'versions': <int>[], 'suites': <String>[]}` — пустые списки; бэкенд ждёт ровно это (`backend_changes/protocol_v1/tests/test_devices.py:89`). Сам `packages/nios_mls/README.md:133` требует: «It must not advertise MLS support before those integrations are enabled and qualified».

**Где MLS всё-таки живой:** только вне приложения — свои тесты (`packages/nios_mls/test/*`, включая `native_probe_test.dart` с реальной нативной OpenMLS) и `packages/nios_lab/lib/nios_lab.dart:99-224` (интеграционная лаборатория, гоняется в `protocol-sdk.yml`).

**Собственные зависимости:** `crypto ^3.0.7`, `cryptography ^2.9.0`, `hive ^2.2.3`, `http ^1.5.0`, `universal_io ^2.3.1`, `openmls 3.2.1`.

Пересечение с приложением — то же самое, что у `nios_sdk` (все шесть уже есть в корне, `crypto` разрешается в 3.0.7 — констрейнты совместимы). **Добавка — `openmls 3.2.1`, и она нативная и дорогая:** в `pulse_flutter/.dart_tool/lib/openmls_frb.dll` лежит 11.7 МБ, а `pulse_flutter/.dart_tool/native_assets.yaml` мапит `package:openmls/openmls` в эту DLL. То есть build hook OpenMLS отрабатывает для сборки приложения, хотя ни одна MLS-строка в рантайме не исполняется (Dart-код вырезается тришейкером, нативные ассеты — нет).

**Дублирование крипты в самом проекте (сверх пакетов):** в `lib/services/` параллельно живут `e2ee_service.dart` (620 строк), `double_ratchet_service.dart`, `services/ordinary_e2ee/`, `services/secret_chat/` — три собственных крипто-стека, плюс `nios_sdk` stream/link/trust и `nios_mls`. Конкретно вложения шифруются двумя живыми путями: `nios_sdk`-стрим (`secret_chat_provider.dart:726-744`) и legacy `E2eeFileCrypto` (`:745+`). Загрузка по содержимому-адресу тоже в двух местах: `lib/services/blob_store_service.dart` (233 строки) и `HttpCiphertextBlobStore` из `nios_sdk`.

Отдельная мелочь: `lib/services/nios_link_service.dart` (315 строк, HTTP-клиент фичи «Nios Link») не имеет отношения к `package:nios_sdk/link.dart` — совпадение имён, стоит переименовать, чтобы не путать.

## Что стоит удалить/заменить

1. **`nios_mls` — вынести из сборки приложения.** Ноль вызовов, пустой MLS-capability в enrollment, но 11.7 МБ нативного `openmls_frb.dll` попадает в native assets графа `pulse_flutter`. Пакет нужен для CI (`nios_mls` тесты + `nios_lab`), но не для APK: убрать path-зависимость из `pulse_flutter/pubspec.yaml` вместе с `openGroups`/`_groups` в `nios_protocol_accounts.dart`, вернуть когда MLS реально включат.
2. **Неподключённые методы `NiosProtocolAccount`.** `startDelivery`, `enqueue`, `enqueueAttachment`, `openAttachment`, `openMedia`, `configureTransparency` — 0 вызовов в `lib/`, живут только в тестах; на них держится ~47 из ~68 обращений к `nios_sdk`. Либо подключить, либо удалить — сейчас `link.dart` и `trust.dart` держатся в графе ради неисполняемого кода.
3. **Headless worker без потребителя.** `headlessWorkerClientProvider` не читается нигде; вместе с ним мёртв `SqliteWalDurableStore` и транзитивный `sqlite3 2.9.4` (нативная зависимость, которую приложение само никогда не импортирует).
4. **Два пути шифрования вложений** (`NiosStream` vs `E2eeFileCrypto`) и **два блоб-стора** (`BlobStoreService` vs `HttpCiphertextBlobStore`). Пока оба живы, любой фикс крипты/докачки надо делать дважды; стоит зафиксировать один как целевой и объявить второй deprecated.
5. **`flutter_launcher_icons`: конфиг в `pubspec.yaml:252-260` живой, но в CI нет шага генерации** — иконки (`mipmap-*`, `AppIcon.appiconset`, adaptive+monochrome `ic_launcher.xml`) обновляются только руками. Либо добавить проверочный шаг, либо явно записать в доки, что `dart run flutter_launcher_icons` — обязательный ручной этап при смене логотипа.
