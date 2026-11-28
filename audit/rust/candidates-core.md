# Кандидаты «Dart → Rust»: `lib/core`, `lib/services`, `packages/nios_sdk`, `packages/nios_mls`

Дата: 2026-11-28. Код не изменялся. Профилировщик не запускался — оценки стоимости
выведены из алгоритма, объёмов данных и известных констант (см. `audit/perf/00-summary.md`,
там уже подтверждён P0 по E2EE-крипте).

Зона: `pulse_flutter/lib/core/**`, `pulse_flutter/lib/services/**`,
`packages/nios_mls/lib`, `packages/nios_sdk/lib` (чтение).
Просмотрено: 47 файлов целиком/крупными фрагментами + grep по всем 224 `.dart` зоны.

Цели сборки, влияющие на вердикт: Android, Windows, **Web**. На web нет `Isolate`,
поэтому `compute()`/`Isolate.run()` там выполняются в главном потоке — это отдельный
риск для каждого кандидата.

## Главный вывод заранее

В этой зоне почти весь CPU-bound код — **криптопримитивы на чистом Dart**
(`package:cryptography`, `package:crypto`, `pointycastle`). Для них Rust почти никогда
не первый шаг:

1. `cryptography_flutter` (native AES/X25519/Ed25519) + один долгоживущий изолят-воркер
   дешевле, чем FFI-мост, и не ломает web-сборку.
2. На web выигрыш даёт WebCrypto (`SubtleCrypto`), а не WASM.
3. `jsonDecode` → Dart `Map` через FFI не окупается: стоимость конвертации
   сопоставима с самим парсингом. Сериализацию выгодно отдавать в Rust только там,
   где результат остаётся байтами (журнал, манифест, файл).

Поэтому `rust-candidate` здесь получают ровно те места, где: (а) данные — это
`Uint8List`/`String` на входе и на выходе, (б) нет web-сборки (BLE, WAV-DSP),
(в) изолят не решает проблему (нужна реальная скорость на потоке кадров/пакетов).

## Таблица кандидатов (по ожидаемой выгоде)

| # | id | file:line | что | вердикт | оценка выгоды |
|---|----|-----------|-----|---------|----------------|
| 1 | `e2ee-message-open` | `services/ordinary_e2ee/ordinary_e2ee_codec.dart:220-223,289,297` | Ed25519+X25519+HKDF+AES-GCM + 4–5 полных разборов конверта на сообщение | `isolate-first` | 300 сообщений: ~3–8 с → ~0,1–0,3 с (батч в одном изоляте) |
| 2 | `secret-journal-snapshot` | `services/secret_chat/secret_journal.dart:314-331` | `jsonEncode` всего аккаунта + AES-GCM в UI-изоляте каждые 128 событий | `isolate-first` | снапшот 1–2 МБ: ~50–150 мс → ~10–20 мс |
| 3 | `mesh-packet-verify` | `services/bluetooth_mesh/mesh_packet.dart:222-245` | 2× Ed25519 verify на каждый BLE-пакет | `rust-candidate` | ~10–20 мс → <1 мс на пакет; до 256 пакетов/мин на пира |
| 4 | `dr-window-decrypt` | `services/double_ratchet_service.dart:254-267,394-409` | ratchet: копия сессии + до 100 HKDF на пропуск + AES-GCM, последовательно на 300 сообщений | `isolate-first` | открытие секрет-чата: ~0,5–2 с → ~50–150 мс |
| 5 | `voice-filter-dsp` | `services/audio/voice_filter_processor.dart:150-189` | O(n) DSP с `sin`/`round` + granular pitch-shift (4×n умножений) в UI-изоляте | `rust-candidate` | 3-мин WAV (4,3 млн сэмплов): ~0,3–1 с → ~30–80 мс |
| 6 | `ws-frame-crypto` | `core/network/web_socket_client.dart:36-52,669-702` | AES-GCM + двойной base64 на каждый WS-фрейм, порог изолята 64 КБ | `isolate-first` | 0,3–1 мс/фрейм → ~0,05 мс (native AES) |
| 7 | `stream-reverify-open` | `packages/nios_sdk/lib/src/stream/stream_object.dart:325-349` | при открытии кэша — расшифровка каждого верифицированного сегмента, `Isolate.run` на сегмент | `isolate-first` | 1 ГиБ видео: 1024 спавна изолята ~1–3 с → ~0,2 с (один воркер) |
| 8 | `album-crc32` | `core/media/media_album.dart:69` | CRC32 по всему альбому (до 40 МБ) в UI-изоляте | `isolate-first` | ~0,3–0,8 с → ~0 (изолят) |
| 9 | `update-sha256` | `services/update/update_integrity.dart:32` | SHA-256 APK (~100 МБ) на чистом Dart в UI-изоляте | `isolate-first` | ~1–2 с заморозки → ~0,2 с |

---

## 1. `e2ee-message-open` — открытие обычного E2EE-сообщения

**Файл:** `lib/services/ordinary_e2ee/ordinary_e2ee_codec.dart:220-223, 289, 297-301`

```dart
  static E2eJson packet(String encoded) =>
      jsonDecode(utf8.decode(decodeE2e(encoded))) as E2eJson;
  static E2eJson header(String encoded) =>
      jsonDecode(packet(encoded)['body'] as String) as E2eJson;
```

```dart
    final p = packet(encoded), h = header(encoded);
    ...
        !await verify(
          p['body'] as String,
          p['signature'] as String,
          sender['ed'] as String,
        ))
```

**Что считается.** Одно сообщение = `base64Decode` всего конверта (1–4 КБ) → `utf8.decode`
→ `jsonDecode` внешнего JSON → `jsonDecode` вложенного `body` (двойное кодирование).
`header()` вызывает `packet()` заново, `recognises()` вызывает `header()` — то есть
3–5 полных разборов одного и того же конверта на сообщение. Дальше: Ed25519 verify,
X25519 `sharedSecretKey` с эфемерным ключом, HKDF-SHA256 (64 байта), AES-256-GCM,
`_aad()` (два `jsonEncode` одного и того же массива в строке 314). Всё — чистый Dart
(`package:cryptography`, `cryptography_flutter` в pubspec **нет**).

Сложность: O(размер конверта) на разбор ×4–5 + O(1) крипто с очень большой константой
(Ed25519/X25519 в `cryptography` 2.9 — арифметика на BigInt, единицы-десятки мс на ARM).

**Доказательство горячести.**
- `OrdinaryCodec.recognises(...)` — 7 мест: `providers/backend_chat_provider.dart:679, 687, 741, 890, 3861, 3875, 3914`,
  плюс `widgets/chat/ordinary_encryption_settings_button.dart:14`, `services/bluetooth_mesh/mesh_history.dart:7`.
  Каждый вызов делает полный разбор конверта только чтобы прочитать `h['v'] == 1`.
- `_handleNewMessagePush` (`backend_chat_provider.dart:684-687`) — `recognises` на **каждый** пуш.
- `_hydrateInboxPreviews` (`:724-745`) — обход **всех** чатов батчами по 4 и по одному
  `decrypt` на чат при холодном старте.
- `mergeMeshHistory` (`services/bluetooth_mesh/mesh_history.dart:24-43`) — `meshOperation()`
  на каждое сообщение, а внутри `recognises()` + `header()` = 3 разбора на сообщение;
  для 300 сообщений mesh-чата это ~900 полных декодирований одной функцией.
- Догон истории без границы (`backend_chat_provider.dart:2589-2615`, P0-3 в perf-аудите) —
  после офлайна тысячи расшифровок на видимом окне 300.

**Стоимость и механизм.** Последовательно в UI-изоляте: на каждое сообщение ~до 5 полных
разборов JSON + 4 BigInt-операции. При окне 300 сообщений — секунды блокировки кадра;
`_hydrateInboxPreviews` на 100–200 чатов — секунды на старте.

**Риск.**
- web: изолятов нет; WASM-модуль Rust на web тянет ~200–400 КБ и грузится отдельно;
  для web дешевле `WebCrypto` (Ed25519 в WebCrypto уже есть в Chromium, X25519 — нет).
- FFI-оверхед не проблема: ~10 мс работы на вызов против ~1–5 µs моста. Но нужен
  аккуратный батч (массив конвертов → массив результатов), иначе выигрыша нет.
- Данные копируются: конверт `String`/`Uint8List` → Rust (`malloc`+copy) → обратно
  открытый JSON. Копия 1–4 КБ на сообщение — приемлемо.
- Ключи уже лежат как seed-байты, их можно передавать в Rust как `[u8;32]`, не как объекты.

**Вердикт: `isolate-first`.** Правильный первый шаг — убрать 3–5-кратный разбор
(`recognises` по префиксу строки, `header` один раз) и открыть окно сообщений батчем в одном
изоляте (+ `cryptography_flutter`). Rust даёт те же ~10× только на web, где выгоднее WebCrypto.

---

## 2. `secret-journal-snapshot` — чекпоинт журнала секретных чатов

**Файл:** `lib/services/secret_chat/secret_journal.dart:314-331` (и `:298-303`)

```dart
            final snapshot = {
              'conversations': [
                for (final chat in _states.keys)
                  {
                    'chat': chat,
                    'state': _states[chat],
                    'messages': _messages[chat],
                  },
              ],
            };
            final encryptedSnapshot = await _aes.encrypt(
              utf8.encode(jsonEncode(snapshot)),
              secretKey: key,
              aad: _aad(0),
            );
```

**Что считается.** На каждое событие — `jsonEncode` транзакции + AES-GCM + base64 +
`flush` (`:298-303`). Каждые 128 событий — `jsonEncode` **всего аккаунта** (все чаты,
все сообщения, включая base64-шифртексты вложений) + AES-GCM по этому объёму, всё на
вызывающем изоляте. Плюс `secretCopy()`/`secretFreeze()` — рекурсивное копирование дерева.

Сложность: O(объём аккаунта) на снапшот; `jsonEncode` в Dart ~30–60 МБ/с, AES-GCM чистым
Dart (pointycastle/cryptography) ~20–40 МБ/с.

**Доказательство горячести.** `commit()` вызывается на каждое входящее/исходящее
событие секретного чата (`secret_chat_engine._commit`, `_receive`, `_sendNext`).
Порог 128 (`:306`) означает: при активной переписке чекпоинт срабатывает каждые ~2–4 минуты,
а при импорте истории — несколько раз подряд. Уже отмечено в perf-аудите (P1 #15) как
«чекпоинт сериализует весь аккаунт в UI-изоляте».

**Стоимость и механизм.** 1–2 МБ JSON (5 чатов × 300 сообщений × ~0,7–1,2 КБ) — это
~50–150 мс на `jsonEncode` + AES + base64 в одном кадре, синхронно с приёмом сообщений.

**Риск.** Данные для Rust — уже дерево Dart-объектов; чтобы отдать их в Rust, нужно
сначала сериализовать, то есть сделать ту работу, которую оптимизируем. Реальный
Rust-вариант — сменить формат: держать состояние чата как байтовый блоб и инкрементально
патчить его в Rust (append-only). Это переделка модели данных, не «переписать функцию».

**Вердикт: `isolate-first`.** Снапшот и `jsonEncode` уходят в изолят в 2 строки; Rust
даёт 5–10× на `serde_json`, но только при смене формата хранения.

---

## 3. `mesh-packet-verify` — проверка BLE-mesh пакета

**Файл:** `lib/services/bluetooth_mesh/mesh_packet.dart:222-245`

```dart
    if (!await OrdinaryCodec.verify(
      'niosmess-ble-v1:$body',
      signature,
      device,
    )) {
      throw const FormatException('Invalid mesh signature');
    }
    final envelope = value['packet'] as String;
    ...
    if (!await OrdinaryCodec.verify(
      inner['body'] as String,
      inner['signature'] as String,
      author,
    )) {
```

**Что считается.** `parse()` на каждый принятый пакет: `utf8.encode` всего wire (для
проверки лимита), `jsonDecode` ×2, `sha256` для `_id(body)`, `sha256` для proof-of-work,
затем **два** Ed25519-verify (внешняя подпись устройства и внутренняя подпись автора),
плюс `base64Decode` ×2 и `jsonDecode` внутри `OrdinaryCodec.packet/header`.
Ed25519 на чистом Dart — самая дорогая операция в зоне.

Сложность: O(1) по числу операций, но 2 BigInt-подписи + 2 SHA-256 на пакет.

**Доказательство горячести.**
- `MeshRouter.receive` (`mesh_router.dart:161-175`) — `MeshPacket.parse` на каждый
  входящий кадр `type: 'packet'`; `MeshRouter.restore` (`:93`) — на каждый из ≤128
  сохранённых пакетов при старте; `bluetooth_mesh_service.dart:248` — на каждый из ≤256
  пакетов outbox.
- Лимиты: `maxPackets = 128`, `peerBytesPerMinute = 256 КБ`, ≤256 кадров/мин на пира,
  до 32 пиров (`MeshRouter:16-17`). Телефон-ретранслятор в людном месте обрабатывает
  десятки пакетов в минуту — это десятки × ~20 мс.
- Всё внутри `_run()` — **одна последовательная очередь** (`mesh_router.dart:32-39`):
  медленная проверка пакета задерживает инвентаризацию и доставку всем пирам.

**Стоимость и механизм.** ~10–20 мс на пакет (2× Ed25519 verify чистым Dart +
2× SHA-256 + 4–6 разборов JSON/base64). При 30 пакетах/мин — до 0,5–1 с CPU в минуту,
и всё это в главном потоке между кадрами UI.

**Риск.** Низкий: сигнатура функции — `bytes → bool` (или `bytes → (bool, id)`), мост
тонкий, состояние не разделяется. **Web-сборки нет** (`meshPlatformSupported` = false на
web; BLE только Android/Windows) — значит требование «работает на web» на этот код не
распространяется. Сборка: `cargo` + `flutter_rust_bridge`/`ffi` для Android (arm64/armv7)
и Windows (x64); нужен CI-шаг.

**Вердикт: `rust-candidate`.** Чистая CPU-bound функция без web-обязательств и с готовым
батч-интерфейсом (массив кадров → массив результатов) — лучший профиль для Rust в зоне.

---

## 4. `dr-window-decrypt` — открытие окна секретного чата (Double Ratchet)

**Файл:** `lib/services/double_ratchet_service.dart:254-267` и `:394-409`

```dart
    if (session.chnKrx != null) {
      while (session.numRcv < until) {
        final result = await kdfck(session.chnKrx!);
        session.chnKrx = result.newChain;
        session.skipKs['${base64Encode(session.dhrKeyBytes)}_${session.numRcv}'] =
            result.msgKey;
        session.numRcv++;
      }
    }
```

**Что считается.** На каждое сообщение: `session.copy()` (копия `Map<String, SecretKey>`
`skipKs`), `base64Decode` заголовка, `jsonDecode`, `kdfck` (HKDF на 64 байта = 2 HMAC-SHA256
+ 2 `sublist`), AES-GCM decrypt, `jsonDecode` метаданных. При пропуске сообщений —
цикл `skipKs` по одному HKDF на каждое пропущенное (лимит 100). На отправку — `_restoreDhs`
(X25519 из seed) на каждое сообщение + `AesGcm` + двойной base64 заголовка.

Сложность: O(k) HKDF, где k = размер пропуска (до 100), + постоянная крипто-работа.

**Доказательство горячести.** `secret_chat_engine._receiveMessage` (`:1131-1211`) —
`DoubleRatchetSession.fromJson` + `_dr.decrypt` на каждое сообщение; вызывается из
`backend_chat_provider.dart:2774-2823` **в последовательном цикле `await`** по всем
загружаемым сообщениям. Окно по умолчанию — 300 (`encrypted_history_archive.dart:262-263`,
`limit = 300`). После пропущенной пачки (офлайн, второе устройство) каждый пакет
дотягивает ratchet через `skipKs` до 100 шагов.

**Стоимость и механизм.** 300 сообщений × (крипто + разборы) последовательно, без
параллелизма: ~0,5–2 с на открытие чата, кадры не рисуются.

**Риск.** Состояние сессии (`numSnt`, `numRcv`, `skipKs`, ключи) меняется в процессе —
в изолят нужно передавать снимок сессии и возвращать новый; при ошибке нельзя
применять частичный результат. Это же ограничение и для Rust. Ключи нельзя оставлять в
Rust между вызовами (сейчас они живут в Dart-памяти) — либо передавать снимок каждый раз
(копия ~0,5–2 КБ), либо держать сессии в Rust-стороне, что увеличивает риск.

**Вердикт: `isolate-first`.** Батч «снимок сессии + N конвертов → снимок + N текстов»
в одном изоляте решает проблему без нового состояния и без FFI.

---

## 5. `voice-filter-dsp` — голосовые эффекты при отправке голосового

**Файл:** `lib/services/audio/voice_filter_processor.dart:168-175` (ядро pitch-shift)

```dart
    for (int outPos = 0; outPos + grainSize <= n; outPos += hopOut) {
      final int srcStart = inPos.round().clamp(0, math.max(0, n - grainSize));
      for (int k = 0; k < grainSize; k++) {
        final double w = window[k];
        out[outPos + k] += input[srcStart + k] * w;
        norm[outPos + k] += w;
      }
```

**Что считается.** `_parsePcm16Wav` (полный проход выборки), `_toMonoNormalized`
(`List<double>.generate` на весь файл), эффект (`robot`: `sin` на каждый сэмпл;
`radio`: HP+LP+LCG-шум+`tanhApprox`; `deep`/`anonymous`/`helium`: pitch-shift
`n/hopOut × grainSize` = 4n умножений, дважды), `_encodePcm16Wav` (ещё проход + запись).
Итого 6–12 полных проходов по выборке, на `List<double>` (куча), синхронно.

**Доказательство горячести.** `voice_recorder_service.dart:87-104` — вызывается
**синхронно в UI-изоляте** сразу после `_recorder.stop()`, до возврата пути в UI:
запись идёт 24 кГц моно (`:43`), 3-минутное голосовое = 4,32 млн сэмплов, 5 минут = 7,2 млн.
`applyToWavBytes` не в изоляте, не в `compute`.

**Стоимость и механизм.** Один кадр-заморозка на 4–7 млн сэмплов: ~0,3–1 с на среднем
Android (Dart AOT, double-циклы + `sin`), на web — хуже (JS, без изолятов).

**Риск.** Очень низкий: `Uint8List → Uint8List`, чистая функция, состояние не нужно.
Дополнительный плюс — web не нужен: запись WAV идёт только на нативных платформах
(`recordWav = !kIsWeb`, `voice_recorder_service.dart:33`). Сборка: тот же Rust-модуль,
что и для mesh.

**Вердикт: `rust-candidate`.** Единственное место в зоне, где Rust даёт не «те же 10×,
что изолят», а качественно новую возможность: realtime-обработку голоса в звонке
(`VoiceFilterPreset` уже доезжает до `WebRtcCallSession._voiceEffect`, но DSP для звонка
нет — только флаг в сигналинге). Для оффлайн-обработки достаточно изолята.

---

## 6. `ws-frame-crypto` — шифрование/расшифровка каждого WS-фрейма

**Файл:** `lib/core/network/web_socket_client.dart:675-679` и `:36-52`

```dart
    if (!kIsWeb && jsonStr.length >= _kCryptoIsolateThresholdBytes) {
      return compute(_encryptEnvelopeWorker, job);
    }
    return _encryptEnvelopeWorker(job);
```

```dart
Future<Map<String, dynamic>> _encryptEnvelopeWorker(
  Map<String, dynamic> job,
) async {
  final String base64Json = base64Encode(utf8.encode(job['json'] as String));
```

**Что считается.** Каждый фрейм: `jsonEncode` → `base64Encode` (+33 % объёма) →
`utf8.encode` → AES-256-GCM → `base64Encode` шифртекста/iv/tag. Приём: обратный путь.
Порог изолята 64 КБ (`:15`) означает, что **все обычные сообщения и пуш-события
обрабатываются в вызывающем изоляте** — то есть в UI, всегда.

Сложность: O(размер фрейма); постоянные ~3 лишних прохода по байтам (base64 туда-обратно)
на фрейм.

**Доказательство горячести.** `_onMessage` (`:375-527`) — на каждый входящий фрейм;
`_doRequest` (`:629`) — на каждый исходящий запрос. Типичный чат: сообщение + ack +
mark_read + typing + 2–5 запросов догрузки; в активной переписке — десятки фреймов в секунду.

**Стоимость и механизм.** ~0,3–1 мс на фрейм в UI-изоляте (AES-GCM чистым Dart на 1–4 КБ +
2 base64). Это не «много», но это постоянный налог на каждое действие в UI и 100 % на web.

**Риск.** `cryptography_flutter` снимает вопрос нативными AES/X25519/Ed25519 без единой
строки FFI; альтернатива для Rust — только на web (WASM), где WebCrypto проще и быстрее.
Формат `base64(JSON)` внутри GCM менять нельзя без совместимости с сервером.

**Вердикт: `isolate-first`.** Это место лечится нативным AES (`cryptography_flutter`) —
Rust здесь тратит сложность сборки на выигрыш, который даёт одна строка `enable()`.

---

## 7. `stream-reverify-open` — открытие закэшированного шифрованного видео

**Файл:** `packages/nios_sdk/lib/src/stream/stream_object.dart:325-343`

```dart
      for (var index = 0; index < manifest.segmentCount; index++) {
        cancellation?.throwIfCancelled();
        if (!download.isSegmentVerified(index) && index != pendingIndex) {
          continue;
        }
        download._setVerified(index, false);
        ...
          final plain = await NiosStream.decryptSegment(
```

**Что считается.** При каждом `NiosStreamDownload.open` — проход по всем
верифицированным сегментам, чтение с диска и AES-GCM-расшифровка каждого (только ради
проверки тега), причём через `cryptoExecutor` = `BackgroundStreamCrypto.run`
(`core/media/background_stream_crypto.dart:42-46`), а это **`Isolate.run` на сегмент** —
новый изолят на каждый мегабайт.

Сложность: O(число сегментов) × (спавн изолята + 1 МБ AES).

**Доказательство горячести.** `secret_stream_service.dart:327-334` (`NiosStreamDownload.open`)
вызывается на каждое открытие секретного вложения/плеера; `readBytes` (`:439-474`)
и `withExport` (`:479-549`) — на каждое скачивание. Файл 1 ГиБ = 1024 сегмента = 1024 спавна
изолята при открытии плеера.

**Стоимость и механизм.** Спавн изолята ~1–3 мс + копия 1 МБ туда/обратно: суммарно
~1–3 с на 1 ГиБ — до первого кадра. Для 200 МБ — ~200–600 мс.

**Риск.** Крипто уже изолировано; проблема — **гранулярность** (изолят на сегмент),
а не скорость примитива. Rust-воркер тут не обязателен: долгоживущий Dart-изолят с
очередью сегментов даёт тот же эффект. Плюс verif-проход можно не делать при открытии
(битмап уже персистентный).

**Вердикт: `isolate-first`.** Один долгоживущий воркер вместо `Isolate.run` на сегмент.
Rust дал бы 10× на самом AES, но 90 % времени здесь — спавн и копии.

---

## 8. `album-crc32` — CRC32 по всему фотоальбому

**Файл:** `lib/core/media/media_album.dart:69`

```dart
      final n = utf8.encode(name), crc = getCrc32(bytes), offset = local.length;
```

**Что считается.** `getCrc32` из `package:archive` (табличный, чистый Dart) по каждому
изображению; для альбома до 40 МБ (`maxBytes`) — один полный проход по 40 МБ при сборке
и ещё один при разборе (`:138`), плюс `decode` дополнительно проверяет директорию.

Сложность: O(объём альбома), ~50–150 МБ/с.

**Доказательство горячести.** `screens/chat_detail_screen.dart:3475` — `_encodeAlbum`
вызывается при отправке альбома; `widgets/chat/bubble/media_album_bubble.dart:42,52`
использует `compute(MediaAlbum.decode, ...)` — то есть декод уже в изоляте, а **энкод нет**.

**Стоимость и механизм.** Отправка альбома на 30–40 МБ: ~0,3–0,8 с синхронно в UI
(перед отправкой), кадр не рисуется.

**Риск.** Нулевой для Rust (`Uint8List → Uint8List`), но и выигрыш достигается
`compute(_encodeAlbum, ...)` в одну строку.

**Вердикт: `isolate-first`.** Асимметрия очевидна: декод уже в `compute`, энкод — нет.

---

## 9. `update-sha256` — проверка целостности APK

**Файл:** `lib/services/update/update_integrity.dart:32`

```dart
    final digest = await sha256.bind(file.openRead()).first;
```

**Что считается.** SHA-256 потока файла на чистом Dart (`package:crypto`), ~100 МБ APK,
на вызывающем изоляте. Ни изолята, ни нативного хеша.

**Доказательство горячести.** `app_update_service.dart` (8 `RegExp`/разборов манифеста)
вызывает `verifyForInstall` перед установкой; `update_asset_selector.dart` — на выбор
артефакта. Частота — раз на обновление, но это **заморозка UI на 1–2 с** в момент,
когда пользователь ждёт установку (и на Android это ещё и перед системным инсталлятором).

**Стоимость и механизм.** ~1–2 с чистого CPU (Dart SHA-256 ~60–100 МБ/с) против
~0,1–0,2 с нативной реализации.

**Риск.** Однократная операция — по правилам аудита это низкий приоритет; Rust-модуль
ради одного хеша не оправдан, `Isolate.run` + `compute` достаточно. На web обновления нет.

**Вердикт: `isolate-first`.** Не кандидат на Rust: одна операция, лечится изолятом.

---

## Что уже нативно / уже в изоляте — Rust не нужен

| Место | Почему не кандидат |
|---|---|
| `packages/nios_mls/**` | Не зависимость `pulse_flutter` (нет в pubspec, нет импортов) **и** уже `openmls: 3.2.1` — FFI к Rust OpenMLS. Групповая криптография уже на Rust. |
| `lib/core/utils/image_compressor.dart` | `flutter_image_compress` — нативный код (Android/Windows). |
| `packages/nios_sdk/lib/src/stream/crypto_executor.dart` | Вызывается только через `BackgroundStreamCrypto` (`Isolate.run`); проблема — гранулярность (см. #7), а не язык. |
| `lib/core/utils/sticker_formatter.dart` | Уже `compute(_formatStickerImage, ...)`; однократно на стикер. |
| `lib/core/utils/e2ee_file_crypto.dart` | Уже `Isolate.run`/`Isolate.spawn`, файловый AES-GCM через pointycastle в воркере. |
| `lib/core/storage/encrypted_message_cache.dart`, `encrypted_history_archive.dart` | Уже `_runCompute` (Isolate.run) на запись/чтение окна; на web — главный поток, там лечится WebCrypto. |
| `lib/services/blob_hasher.dart` | Уже `compute` + потоковое чтение. Ускорить можно только нативным SHA-256 (не потоком Rust-логики). |
| `lib/services/bluetooth_mesh/mesh_packet.dart:111` | Майнинг PoW уже `Isolate.run` — трогать не надо. |
| `lib/services/protocol/nios_protocol_accounts.dart` | Требует нативного хранилища (`kIsWeb` → `UnsupportedError`), вызывается только при согласованном v1 — не горячий путь. |

## Мёртвый код в зоне — не приоритизировать

| Место | Статус |
|---|---|
| `lib/services/calls/video_pipeline.dart` (7,7 КБ, JPEG-энкод каждого кадра через `Isolate.run`) | **Нет ни одного вызова** — `VideoPipeline(` не встречается вне самого файла. Похоже на самый дорогой CPU-код зоны (15 кадров/с × спавн изолята × JPEG), но он не подключён. Если его включат — это кандидат №1 на Rust (JPEG-энкод Dart `image` ~в 10–20 раз медленнее Rust); сейчас — `no`. |
| `lib/core/network/api_client.dart` | `apiClientProvider` объявлен, но нигде не читается. Заодно снимает вопрос про `jsonDecode` больших ответов. |
| `lib/services/e2ee_service.dart` + `double_ratchet_service.dart` (легаси-путь) | Жив, но используется только для секретных чатов и хелперов; новый обычный E2EE идёт через `ordinary_e2ee`. |

## Оговорки, которые нужно учесть при решении

1. **Web не получает изолятов.** Всё, что «уже в `compute`», на web выполняется в главном
   потоке. Для web правильный ответ — WebCrypto (`crypto.subtle`), а не WASM: у Rust-WASM
   нет ни SIMD по умолчанию в сборке Flutter web, ни доступа к нативным AES-инструкциям
   браузера так, как у `SubtleCrypto`.
2. **`jsonDecode` → Dart-объекты через FFI не окупается.** Стоимость материализации
   `Map`/`List` в Dart сравнима с парсингом. Rust-сериализация имеет смысл только если
   результат остаётся байтами (журнал, манифест, файл на диске).
3. **Один Rust-модуль на все кандидаты** имеет смысл только для нативных целей
   (mesh + voice DSP + потенциальный video JPEG). Это Android (arm64-v8a, armeabi-v7a) и
   Windows (x64) — два CI-таргета; web остаётся на Dart-фолбэке.
4. **Оценки не профайлерные.** Числа — из алгоритма и объёмов. Приоритет стоит
   подтвердить на устройстве: 300 E2EE-сообщений, открытие 1 ГиБ стрима, 3-минутный
   WAV с фильтром «robot», 30 BLE-пакетов подряд.
