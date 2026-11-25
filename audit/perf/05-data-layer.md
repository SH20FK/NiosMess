# Перф-аудит: слой данных (providers / services / repositories / features / models)

Дата: 2026-11-25
Зона: `pulse_flutter/lib/providers/**` (43), `lib/services/**` (~70), `lib/repositories/**` (11),
`lib/features/**` (application/domain/data), `lib/models/**` (30).
Эталоны: https://docs.flutter.dev/perf/best-practices + «Motion & Performance Protocol» (AGENTS.md).
Режим: только чтение. Код не правился, сборка/`pub get` не запускались.

## Счётчики

| severity | шт. |
|---|---|
| blocker | 2 |
| major | 10 |
| minor | 8 |
| nit | 6 |
| **всего** | **26** |

Общая оценка: слой данных **не** «зелёный луг» — центральный чат-провайдер (`backend_chat_provider.dart`,
4628 строк) уже переработан грамотно (окно в 300 сообщений, `LazyBox`-архив, дебаунс записи кеша,
single-flight по refresh/older/newer). Основная системная проблема одна и она архитектурная:
**весь E2EE-крипто и большая часть сериализации работают в main isolate**. Плюс два очага
неограниченного объёма работы (catch-up истории и `secret_journal`).

---

## BLOCKER

### B1. E2EE-расшифровка каждого сообщения целиком в main isolate (нет ни изолята, ни нативной крипты)

- `lib/services/ordinary_e2ee/ordinary_e2ee_codec.dart:297` — `verify(...)`, `:315-319` — `_wrap` (X25519 + HKDF),
  `:322` — AES-GCM; всё это pure-Dart `cryptography` (в `pubspec.yaml:71` есть только `cryptography: ^2.9.0`,
  **`cryptography_flutter` отсутствует**, `FlutterCryptography.enable()` нигде не вызывается).
- `lib/providers/backend_chat_provider.dart:2693-2706` — по одному `ordinary.decrypt(message)` на сообщение;
  `:2761-2861` — **последовательный** `for (int i…)` с `await e2eeService.decryptE2EEMessage(...)` для secret-чатов.

```dart
// ordinary_e2ee_codec.dart:297
!await verify(p['body'] as String, p['signature'] as String, sender['ed'] as String))
// :317
await _wrap(await own.dh, h['ephemeral'] as String, binding)
```

Нарушено: правило 1 (тяжёлая работа в main isolate) и «16 мс».
Почему дорого: на одно сообщение приходится 1 Ed25519-verify + 1 X25519-shared-secret + 2 AES-GCM
(в pure Dart на мобиле это единицы миллисекунд). Для страницы истории в 80 сообщений — сотни
миллисекунд CPU, нарезанные на 80 последовательных `await`; кадры проседают, открытие чата «залипает».
Для 300-сообщенного окна — до секунды.

Фикс: (а) добавить `cryptography_flutter` и `await FlutterCryptography.enable()` в `main()` — одна строка,
даёт нативный AES/Ed25519; (б) либо одним `Isolate.run` расшифровывать пачку `List<ApiMessage>` (в изоляте
уже есть рабочий паттерн: `lib/core/network/web_socket_client.dart:657-683`,
`lib/core/storage/encrypted_message_cache.dart:148-153`). Для DR-пути (`e2ee_service.dart:190-219`) — то же.

### B2. Catch-up истории не ограничен по количеству сообщений, и каждая страница расшифровывается в main isolate

- `lib/providers/backend_chat_provider.dart:2589-2615` — `while (true) { _fetchHistoryPage(page…); … }`,
  выход только по `batch.length < 80` **или** по `batch.any((m) => m.id <= newestKnown)`.
- `:3239` — внутри `_fetchHistoryPage` сразу `_decryptE2eeMessages(remote)` (см. B1).

```dart
while (true) {
  final fetched = await _fetchHistoryPage(page: page, pageSize: 80);
  …
  if (!catchUp || newestKnown == 0 || batch.length < 80 ||
      batch.any((message) => message.id <= newestKnown)) break;
```

Нарушено: правило 1 + «16 мс» (нет батчинга/стриминга и нет потолка объёма).
Почему дорого: `newestKnown` = максимальный известный id. После недели офлайна догон = десятки страниц;
5000 новых сообщений → 5000 последовательных расшифровок в main isolate → многосекундный фриз ровно
в момент реконнекта (когда пользователь уже смотрит в экран). Видимое окно при этом всё равно 300:
вся остальная работа — выброшенная.

Фикс: ограничить догон (например, максимум 5 страниц за проход + «продолжить в фоне»), а саму пачку
расшифровывать одним изолированным вызовом. Архив уже умеет держать всё на диске — расшифровывать
нужно только видимое окно, остальное писать в архив как есть.

---

## MAJOR

### M1. Один и тот же конверт парсится base64+JSON 4 раза на сообщение

- `lib/services/ordinary_e2ee/ordinary_e2ee_codec.dart:220-223` — `header()` вызывает `packet()`, т.е. каждый
  `header()` = 2 прохода `base64Decode` + `jsonDecode`;
- `lib/services/ordinary_e2ee/ordinary_e2ee_service.dart:692` (`recognises` → `header`), `:700` (`header`),
  `:723` (`OrdinaryCodec.decrypt` → `:289` `packet` + `header`);
- то же в mesh: `lib/services/bluetooth_mesh/mesh_packet.dart:230-234` (`recognises` + `packet` + `header`).

```dart
static E2eJson header(String encoded) =>
    jsonDecode(packet(encoded)['body'] as String) as E2eJson;   // packet() уже распарсил base64+json
```

Нарушено: правило 1 (лишняя работа в горячем пути).
Почему дорого: 4× лишний `base64Decode` + 4× `jsonDecode` на каждое сообщение (конверты по 0.5-2 КБ).
Умножается на B1/B2: это чистые накладные расходы поверх крипты.

Фикс: распарсить конверт один раз (`_Parsed = (packet, header)`) и передавать по цепочке;
`recognises` должен работать по уже разобранному объекту.

### M2. Secret journal: один commit (AES + jsonEncode + base64 + Hive `flush`) на **каждое** событие синка

- `lib/services/secret_chat/secret_chat_engine.dart:731-733`
```dart
for (final event in ordered) {
  await _serial.run(key, () => _receive(key, event));   // внутри — _commit (строка 888)
}
```
- `lib/services/secret_chat/secret_journal.dart:69-72` — `append()` делает `box.add` **и `box.flush()`**;
- `:298-303` — `_aes.encrypt(utf8.encode(jsonEncode(tx)))` в main isolate.

Нарушено: правило 1 и 2 (нет батчинга), плюс «16 мс».
Почему дорого: пачка из 100 событий (лимит страницы `limit: 100`, строка 711) = 100 fsync + 100 AES-GCM +
100 `jsonEncode`. Каждое событие в отдельной транзакции — это ещё и 100 записей в append-log, из-за чего
чекпоинт (M3) наступает в 128 раз быстрее, чем мог бы.

Фикс: собрать все события страницы в **одну** транзакцию (`_apply` уже умеет принимать
`Map<String, SecretJson> messages` + курсор) и один `flush` на страницу.

### M3. Чекпоинт журнала сериализует и шифрует **весь** аккаунт в main isolate

- `lib/services/secret_chat/secret_journal.dart:306-332`

```dart
if (_sequence >= 128 || …) {
  final snapshot = {'conversations': [for (final chat in _states.keys) {…'messages': _messages[chat]}…]};
  final encryptedSnapshot = await _aes.encrypt(utf8.encode(jsonEncode(snapshot)), …);
```

Нарушено: правило 1.
Почему дорого: объём снапшота пропорционален всей истории всех секретных чатов (мегабайты при активном
использовании), а работа — синхронная в главном изоляте, без потолка. Это разовый, но **многосотмиллисекундный**
фриз, причём в момент отправки/получения сообщения. Вместе с M2 срабатывает в ~128 сообщений.

Фикс: строить и шифровать снапшот в `Isolate.run` (передавать уже плоский `Map`, ключ — байтами), либо
делать чекпоинт по таймеру простого состояния (idle), а не в середине пользовательской операции.

### M4. `journal.restore()` при старте расшифровывает и парсит журнал целиком в main isolate, блокируя инбокс

- `lib/providers/secret_chat_provider.dart:181` — `await journal.restore();` внутри `_open()`, который
  ожидается из `ChatsNotifier.build()` (`lib/providers/backend_chat_provider.dart:360`);
- `lib/services/secret_chat/secret_journal.dart:206-240` — цикл по всем записям: `base64Decode` →
  `_aes.decrypt` → `jsonDecode` → `_apply` (глубокая заморозка `secretFreeze` каждого сообщения).

```dart
for (final encoded in records.skip(checkpoint < 0 ? 0 : checkpoint)) {
  final packed = base64Decode(…);
  final bytes = await _aes.decrypt(box, secretKey: key, aad: _aad(_sequence));
  final tx = secretMap(jsonDecode(utf8.decode(bytes)));
```

Нарушено: правило 7 («тяжёлые операции в инициализации на главном потоке при старте»), правило 1.
Почему дорого: до 128 записей + потенциально полный снапшот (M3) — это сотни миллисекунд до того, как
`chatsProvider.build()` вернёт данные. Холодный старт с активными секретными чатами получает заметную
задержку первого списка чатов.

Фикс: `restore` в `Isolate.run` (ключ и записи — примитивы), либо в отдельном фоновом изоляте с
публикацией «готово» через событие, не блокируя `ChatsNotifier`.

### M5. Синхронное чтение Hive + полный `fromJson` в `build()` провайдера (чаты и лента)

- `lib/providers/backend_chat_provider.dart:349-355`
```dart
cached = ref.read(cacheServiceProvider).getCachedChats(accountId: identity.$1);
final List<ApiChatSummary> plain = cached.where((c) => !c.isSecret).toList(growable: false);
```
- `lib/core/storage/cache_service.dart:186-200` — синхронный `box.get` + `ApiChatSummary.fromJson` на каждый чат
  (внутри каждого — вложенный `ApiMessage.fromJson` для `last_message`);
- то же для ленты: `lib/providers/niosgram_provider.dart:284` + `cache_service.dart:245-260`.

Нарушено: правило 6 («синхронные чтения storage в горячем пути») и 7.
Почему дорого: `getCachedChats` — не `await`, он исполняется прямо в `build()`, то есть блокирует кадр,
в котором впервые читается провайдер. 300-500 чатов с `lastMessage` = десятки миллисекунд жёсткого
блокирования (и это **первый** кадр инбокса).

Фикс: сделать чтение асинхронным (`await box.get`) и/или перенести `fromJson`-маппинг в `compute`;
показывать скелетон до готовности кеша, как это уже сделано для `AsyncLoading`.

### M6. У секретного чата нет окна: на каждое изменение журнала вся история заново конвертируется из JSON

- `lib/providers/backend_chat_provider.dart:2067-2074`
```dart
final subscription = secret.engine.changes.listen((chatKey) {
  …
  final messages = _secretMessages();     // :2247
  state = AsyncData(messages);
```
- `:2247-2249` — `_secret?.engine.messages(_chatId).map(ApiMessage.fromJson).toList()`;
- `lib/services/secret_chat/secret_chat_engine.dart:363-412` — `messages()` возвращает **все** видимые
  сообщения архива, без ограничения (в отличие от обычных чатов с `maxVisibleMessages = 300`).

Нарушено: правило 2 (полная пересборка большого состояния), правило 5 (нет O(1)-доступа к модели).
Почему дорого: `_commit` вызывает `_changes.add(key)` (строка 122) на каждое событие, значит на каждое
принятое/отправленное сообщение выполняется `fromJson` для всей истории (2000 сообщений ≈ 10-30 мс) и
публикуется список из 2000 новых объектов — весь `ListView` перестраивается, identity-сравнения не спасают.

Фикс: кешировать `List<ApiMessage>` рядом с `_projections` (пересобирать только изменённую строку), либо
ввести окно и для secret-чата (переиспользовать `MessageHistorySnapshot.replacements`).

### M7. Комментарии под постом: `Timer.periodic(8s)` перезапрашивает **все** загруженные страницы

- `lib/providers/backend_chat_provider.dart:4600-4602`
```dart
final timer = Timer.periodic(const Duration(seconds: 8), (_) {
  unawaited(refresh(silent: true));
});
```
- `:4643-4653` — `refresh` идёт `do { page(afterId: items.last.id) } while (more && items.last.id < target)`,
  где `target = _cursor`, т.е. перечитывает всё, что уже загружено пользователем (при скролле — десятки страниц);
- `:4668-4670` — при каждом тике `state = AsyncData([...])` даже если ничего не изменилось.

Нарушено: правило 6 (отсутствие кеша/пагинации), правило 7 (polling).
Почему дорого: 8 запросов в минуту независимо от наличия новых данных; при 300 прокрученных комментариях
это 6 сетевых round-trip каждые 8 секунд + полная замена списка (перестройка всех бабблов) + сериализация.
Плюс дублирующие триггеры: push `feed_comment_changed` (`:4606-4616`) и `onConnected` (`:4603`).

Фикс: убрать периодический таймер (push уже есть), либо оставить его только для «холодного» состояния и
тянуть дельту `after_id = _cursor` (не с нуля).

### M8. На каждое своё сообщение — запись в Hive с `flush()` из цикла расшифровки

- `lib/providers/backend_chat_provider.dart:2784-2792` — внутри `_decryptE2eeMessages`:
```dart
if (msg.id > 0) {
  unawaited(EncryptedMessageCache.saveSenderPlaintext(
      chatId: _chatId, messageId: msg.id, plaintext: msg.content, userId: …));
}
```
- `lib/core/storage/encrypted_message_cache.dart:167-174` — `_encodeSender` (AES в main isolate, `:121-129`)
  + `box.put` + **`await box.flush()`** на **каждую** запись.

Нарушено: правило 1 (батчинг I/O), «16 мс».
Почему дорого: первая загрузка страницы 80, где много своих сообщений → до 80 fsync подряд,
каждый со своим AES. Даже `unawaited` не спасает: Hive пишет последовательно, а `flush` — это диск.

Фикс: собрать пачку `Map<id, plaintext>` и записать/флашнуть один раз на страницу.

### M9. История уведомлений переписывается целиком (двойной `jsonEncode`) + `flush` на каждое уведомление

- `lib/providers/notifications_provider.dart:303-314` — на каждый `accept`: `_setEvents(...)` и
  `await _store?.save(snapshot)`;
- `lib/core/notifications/notification_history_store.dart:54-65`
```dart
final snapshot = events.map((e) => jsonEncode(e.toJson())).toList();  // N отдельных jsonEncode
await box.put('snapshot', jsonEncode(snapshot));                      // и ещё один поверх
await box.flush();
```

Нарушено: правило 1/2 (нет дебаунса записи), «16 мс».
Почему дорого: `accept` сериализован цепочкой `_delivery` (`:221`), т.е. всплеск из 20 уведомлений =
20 × (до 100 `jsonEncode` + общий `jsonEncode` + fsync) подряд, и каждое блокирует следующее.

Фикс: дебаунс 500-1000 мс на запись снапшота (как `_persistChats` в `backend_chat_provider.dart:171`),
и не двойное кодирование — хранить `List<Map>` (Hive сам сериализует).

### M10. Видеозвонок: новый изолят на **каждый** кадр (`Isolate.run` при 15 fps)

- `lib/services/calls/video_pipeline.dart:150-160`
```dart
return await Isolate.run(() {
  return _encodeFrameJpeg(planes: planes, …);
});
```
- контекст: `targetFps = 15` (`:29`), `_onCameraImage` ограничивает частоту `_frameIntervalMs` (`:104`).

Нарушено: правило 1 (правильная идея — увести с UI-потока, но `Isolate.run` = spawn на вызов).
Почему дорого: 15 спавнов изолята в секунду + передача BGRA-буфера 640×480 (≈1.2 МБ) в обе стороны;
`Uint8List.fromList(plane.bytes)` (`:141`) — ещё и копия в main isolate. Спавн изолята на мобиле 1-5 мс,
то есть до 75 мс/сек только на создание изолятов, не считая копирования и JPEG-энкода.

Фикс: один долгоживущий воркер (в проекте уже есть каркас — `lib/core/worker/headless_worker_client.dart:63`)
или пул из 1-2 изолятов с `SendPort`-протоколом.

---

## MINOR

### m1. `mergeChats` — O(секретные × все чаты) + полная сортировка на каждое изменение журнала
`lib/providers/secret_chat_provider.dart:611` (`remote.where((c) => c.id == data['remote_id']).firstOrNull`
внутри цикла по секретным чатам), `:658` (`result.sort(compareChatRecency)`); вызывается из
`backend_chat_provider.dart:363-368` на каждый `engine.changes`. Фикс: один `Map<int, ApiChatSummary>`
из `remote` перед циклом; сортировку — только при реальном изменении порядка.

### m2. Синк черновиков: запись в `FlutterSecureStorage` **внутри цикла по черновикам**, каждые 15 с
`lib/services/encrypted_draft_sync.dart:146-152` (jsonEncode всего метадата-блоба + `secure.write` на каждый
черновик), `:63` (`Timer.periodic(15s)`). Каждая запись — операция через Keystore. 10 черновиков =
10 записей каждые 15 секунд в фоне. Фикс: собирать `metadata` и писать один раз после цикла.

### m3. Лишний round-trip `toJson()` → `fromJson()` на каждое расшифрованное сообщение
`lib/services/ordinary_e2ee/ordinary_e2ee_service.dart:746-759`
```dart
final verified = ApiMessage.fromJson({...message.toJson(), 'is_e2ee': true, …});
```
Нарушено: правило 1 (лишняя работа в самом горячем месте). Фикс: `message.copyWith(isE2ee: true, isDecrypted: false, …)`.

### m4. `select` по списку = линейный скан на каждого слушателя на каждый push
`lib/providers/backend_chat_provider.dart:1495-1504` (`chatByIdProvider`), `:1515-1519` (`chatOnlineProvider`).
Presence-пуш → M видимых строк × O(N) скан. Архитектурно верно (select сужен до значения), но списковый
`select` не даёт O(1). Фикс: держать `Map<int, ApiChatSummary>` (пересобирать инкрементально) и селектить по ключу.

### m5. Secret-чат: событие `read` копирует **все** сообщения
`lib/services/secret_chat/secret_chat_engine.dart:863-874` — цикл по `journal.messageViews(key)` с `secretCopy`
на каждое и последующий `_commit`. Если сервер присылает несколько read-событий, получаем O(n) на событие.
Фикс: помечать read-флаг отдельной дешёвой операцией индекса (без копирования строк).

### m6. Локальный поиск делает `toLowerCase()` для каждого поста/чата на каждое нажатие
`lib/providers/search_provider.dart:92-98`, `lib/features/chats/presentation/inbox_search_results.dart:83-89`.
Бэкенд дебаунсится (300 мс, `search_provider.dart:109`), а локальный проход — нет. Фикс: предвычислять
lowercase-поля в модели или в поисковом индексе.

### m7. `_fetchWindow` делает 5 полных копий окна за один fetch
`lib/providers/backend_chat_provider.dart:2577-2657` — `before`, `current`, `merged`, `retained`, `fetched`,
плюс `mergeSorted` и `_overlayHistoryMutations` (со своим `sort`). n ≤ 300, поэтому не критично, но это
5-6 проходов и 3 аллокации списка на каждый refresh. Фикс: один проход по `Map<int, ApiMessage>`.
**Требует замера**, чтобы понять, попадает ли в frame budget.

### m8. Mesh: `jsonEncode` всего списка relayed + `box.put` на каждый релей
`lib/services/bluetooth_mesh/bluetooth_mesh_service.dart:230-235`. До 256 строк на каждый пересланный
пакет. Фикс: писать в Hive раз в N секунд/по таймеру простоя.

---

## NIT

- **n1.** `ApiMessage.fromJson` вынесен **из** изолята в архивном декоде:
  `lib/core/storage/encrypted_history_archive.dart:117` (`(await _decodeJson(rows)).map(ApiMessage.fromJson)`),
  хотя сам `_decodeJson` уже в `Isolate.run` (`:124`). 300 сообщений × парсинг ≈ 5 мс в кадре открытия чата.
- **n2.** SHA-256 обновления на main isolate: `lib/services/update/update_integrity.dart:32`
  (`sha256.bind(file.openRead()).first`) — потоково, но CPU-bound; для APK в ~100 МБ это сотни мс,
  нарезанных по event loop. Редкое разовое действие → nit, но правильнее в `Isolate.run`.
- **n3.** Скан temp-директории в `build()` провайдера: `lib/providers/upload_queue_provider.dart:107`
  (`unawaited(_sweepStaleEncryptions())`, `:121-139` — `dir.list()` + `stat` на каждый файл).
  Не блокирует (fire-and-forget), но это I/O в момент первого чтения провайдера.
- **n4.** `pending.removeAt(0)` в `_pump`: `lib/providers/upload_queue_provider.dart:194` — O(n) сдвиг,
  при `n ≤ maxConcurrentUploads` (3) безобидно; чище — `Queue.removeFirst()`.
- **n5.** `Timer.periodic(5s)` ради гейта в 30 с: `lib/services/ordinary_e2ee/ordinary_e2ee_service.dart:1209`
  + `:1196-1207`. 12 пробуждений в минуту ради 2 полезных.
- **n6.** Поиск по настройкам делает `toLowerCase()` на каждый keyword на каждое нажатие:
  `lib/services/settings/settings_registry.dart:876`. Список маленький, но лоуэркейс можно кешировать.

---

## Проверено и признано нормальным

1. **Списки сообщений: бинарная вставка и линейный merge, без O(n²).**
   `lib/core/storage/sorted_history.dart:3-32` — `insertSorted` (бинарный поиск + один сдвиг) и `mergeSorted`
   (два указателя). В `backend_chat_provider` нет `sort()` на каждый апдейт одного сообщения — только
   `insertSorted`/`mergeSorted`; полный `sort` встречается на границах окна (`:1850`, `:3346`) и это O(n log n) разово.
2. **Окно обычной истории и дисковое хранилище сделаны правильно.**
   `maxVisibleMessages = 300` (`backend_chat_provider.dart:1617`), окно публикуется через
   `MessageHistorySnapshot` с `replacements`/`inserted` (адресные обновления вместо полной пересборки,
   `:2293-2305`, `:2433-2439`, `:2452-2466`); архив — `LazyBox` с бинарным поиском по диапазону ключей
   (`encrypted_history_archive.dart:19`, `:50-69`), шифрование/дешифрование строк — в `Isolate.run`
   (`:96`, `:124`); запись кеша сообщений дебаунсится 2 с и single-flight
   (`backend_chat_provider.dart:3019-3042`), как и архив (`:1717-1726`).
3. **Нет конкатенации строк в циклах** ни в providers, ни в services (grep по `+=` дал только числовые
   аккумуляторы: `blob_hasher.dart:127-129`, `call_quality.dart:69-70`, `video_pipeline.dart:232-238`).
   Прогресс загрузки троттлится (80 мс / 1 %, `upload_queue_provider.dart:101`, `:280-298`),
   presence-пуш в инбоксе сужен через `chatOnlineProvider` (`backend_chat_provider.dart:1507-1519`),
   а не через `watch` всего списка.

## Требует профилирования (а не чтения кода)

- **Стоимость одной E2EE-операции на целевом устройстве.** Нужен DevTools timeline: сколько реально
  занимает `OrdinaryCodec.decrypt` (Ed25519+X25519+2×AES, pure Dart) на среднем Android. От этого зависит,
  B1 — «заметный джанк» или «блокер».
- **Реальный размер gap при catch-up (B2).** Нужен лог/метрика `страниц на догон` после 1 ч / 1 дн / 1 нед офлайна.
- **Доля fsync в M2/M8.** Hive `flush()` на Android может быть и 0.2 мс (страница в page cache), и 5 мс
  (fsync на flash). Нужен замер на устройстве, чтобы понять, где узкое место — в AES+json или в диске.
- **Реальный объём снапшота журнала (M3).** Замерить размер `snapshot` в байтах на аккаунте с 10+ секретными
  чатами и длинной историей: если это < 100 КБ, M3 — minor, если мегабайты — blocker.
- **Частота presence/`chat_updated` пушей в реальном трафике** (m4, `_ChatListPushSync`): от неё зависит,
  важна ли оптимизация сканов.
- **Сколько комментариев реально загружает пользователь** в шторке комментариев (M7): 20 или 500.
- **Плавающие кадры при видеозвонке** (M10): сравнить `FrameTiming` с `Isolate.run` и с постоянным воркером.
