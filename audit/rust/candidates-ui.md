# Rust-кандидаты: UI, экраны, модели (NiosMess)

Зона этого прохода: `lib/widgets` (все, включая `chat/bubble/settings`), `lib/screens`,
`lib/features`, `lib/models`, `lib/core/utils`, `lib/providers`, `lib/repositories`
(последние два — только с точки зрения вычислений).

Дата: 2026-11-28. Код не изменялся.

**Просмотрено:** 400 `.dart` файлов зоны (128 422 строки, без `*.g.dart`/`*.freezed.dart`),
полностью прочитаны 34 «горячих» файла + 9 пакетов из pub-кэша (`qr_flutter`,
`flutter_markdown_plus`, `archive`, `markdown`).

## Главный вывод

В этой зоне Rust оправдан **в двух местах** и только потому, что там он решает то,
чего Dart не может:

1. **`DateTime.tryParse` стоит 32 µs на строку** (в SDK это RegExp + `int.tryParse`).
   Для истории в 2000 сообщений это **46–92 ms чистого UI-изолята** — и это
   единственная зона, где **web не спасает `Isolate.run`**: на web `compute`
   выполняется в том же потоке, параллелизма нет, помогает только более быстрая
   реализация (Rust→wasm).
2. **markdown → plain text превью: 40 / 162 / 473 µs** на строке 7 / 153 / 444
   символа. Это синхронный вызов из `itemBuilder` каждого ряда инбокса, в isolate
   его не вынести (нужен результат прямо в кадре).

Всё остальное — либо **isolate-first** (снять с UI-потока, Rust потом и по желанию),
либо **не кандидат** (правка в Dart на 3–10 строк), либо **native-plugin-first**
(задачу уже делает нативный пакет).

Ключевое ограничение всей темы: **web собирается в CI**. `dart:ffi` на web нет,
поэтому любой Rust-кандидат = два бэкенда (FFI для Android/Windows + wasm для web)
и два артефакта в сборке. Для задач, где `Isolate.run` даёт тот же результат,
Rust не окупает эту цену. Для двух пунктов выше — окупает, потому что на web
изолята нет как такового.

## Замеры (не оценки)

Скрипты: `dart --packages=.dart_tool/package_config.json` (JIT, Windows x64, warm).
На AOT/Android абсолютные числа будут другими, но порядок и соотношения — те же.
Скрипты лежат в `%TEMP%\opencode\rustaudit\` (`bench.dart`, `bench2.dart`, `bench3.dart`).

| Операция | Замер |
|---|---|
| `messagePreviewText` (GFM), 7 / 153 / 444 символа | **40 / 162 / 473 µs** |
| то же, только `Document.parseLines` (без обхода) | 128 µs |
| `DateTime.tryParse('2026-11-28T10:11:12.123456')` | **32 µs** (2000 шт = 64 ms) |
| `parseApiDateTime` (tryParse + tz-RegExp + `DateTime.utc`) | 22.9 µs → **2000 сообщений = 45.8 ms** |
| tz-RegExp `_hasExplicitTimeZone` отдельно | 0.5 µs (не она дорогая) |
| `jsonDecode` полезной нагрузки 572 KB / 2000 сообщений | 12.6 ms |
| `customEmojiLength` на 8400 code units | **294 µs** (из них 245 — `replaceAll`) |
| `text.characters.length` на 8400 units | 48 µs |
| `split('\n')` на тексте 1 MB (20 000 строк) | **3.85 ms** |
| `toLowerCase()` на тексте 1 MB | **5.55 ms** |
| docx: outer RegExp `<w:(p\|tbl).*?</w:\1>` на 610 KB XML | 8 ms |
| docx: 1000 абзацев (run-regex + text-regex + 5× `replaceAll`) | 13 ms |
| docx: `ZipDecoder().decodeBytes` (19 KB zip → 610 KB) | 3.4 ms |
| создание `RegExp` + 1 match | 0.62 µs (**не** является стоимостью) |

Отдельно проверено и **опровергнуто**: гипотеза «`RegExp` создаётся внутри цикла в
`docx_parser`, поэтому парсинг медленный». 2000 итераций с созданием RegExp и без —
2 ms в обоих случаях. Компиляция RegExp ручьём — не проблема; дорогие вещи другие.

## Таблица кандидатов (по ожидаемой выгоде)

| # | Место | Что | Стоимость (замер) | Вердикт |
|---|---|---|---|---|
| 1 | `lib/core/utils/datetime_helpers.dart:14` + `lib/models/api/message_model.dart:314` | ISO-дата через `DateTime.tryParse` на каждое поле каждого сообщения | 32 µs/дата → **46–92 ms** на восстановление 2000 сообщений | **rust-candidate** |
| 2 | `lib/core/utils/message_preview_text.dart:36` | markdown → plain для превью инбокса, полный GFM-парсер на вызов | **40–473 µs/строка** → 3.7–32 ms на видимый экран | **rust-candidate** |
| 3 | `lib/core/utils/docx_parser.dart:70` | zip+inflate и regex-разбор `document.xml` в `initState`, UI-изолят | ~50 ms на 1 MB док (8+13+3.4) | **isolate-first** |
| 4 | `lib/screens/native_file_viewer_screen.dart:870` | `_content.split('\n')` в `build()` + `toLowerCase` на строку, на каждый символ поиска | 3.85 + 5.55 ms на 1 MB → 20–50 ms на 5 MB **за нажатие** | **isolate-first** |
| 5 | `lib/models/api/custom_emoji_model.dart:3` (из `lib/widgets/chat/custom_emoji_text.dart:159`) | подсчёт «длины» с эмодзи: `replaceAll` + сегментация графем на весь текст | **294 µs за нажатие** при лимите 10 000 | **no** (правка в 1 строку) |
| 6 | `lib/providers/backend_chat_provider.dart:860` (+ `lib/screens/chat_list_screen.dart:985-1057`) | полная пересортировка + копии списка + `idToIndex` на **каждое** входящее | 0.2–2 ms/сообщение при 200–2000 чатах | **no** (инкрементально) |
| 7 | `lib/providers/search_provider.dart:50` | локальный поиск по чатам и постам с `toLowerCase` синхронно на каждое нажатие | 0.5–1.5 ms/нажатие на 200 постах | **no** (дебаунс/прединдекс) |
| 8 | `lib/widgets/post_card.dart:384` | `MarkdownBody` + `CustomEmojiSyntax` создаются в `build()` каждой карточки ленты | 0.2–1 ms на монтирование карточки | **no** (кэш по content) |
| 9 | `lib/widgets/settings/ordinary_e2ee_settings.dart:518` | `QrImageView` пересчитывает матрицу (Reed–Solomon) в `build()`, а страница пересобирается на **каждое сообщение** (`:581`) | ~0.15 ms × каждое сообщение при открытой странице | **no** (кэш `QrCode`) |
| 10 | `lib/core/utils/image_compressor.dart:32` | сжатие/ресайз изображений перед отправкой | — | **native-plugin-first** |

Дальше — по каждому: цитата, алгоритм, доказательство горячести, риск, вердикт.

---

## 1. `DateTime.tryParse` на каждом поле сообщения — `rust-candidate`

`lib/core/utils/datetime_helpers.dart:9-29`:

```dart
  final String value = iso.trim();
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  if (_hasExplicitTimeZone(value)) return parsed.toUtc();
  return DateTime.utc(
    parsed.year, parsed.month, parsed.day,
    parsed.hour, parsed.minute, parsed.second,
    parsed.millisecond, parsed.microsecond,
  );
```

Вызов: `lib/models/api/message_model.dart:314`

```dart
      sentAt: parseApiDateTime((json['sent_at'] ?? json['created_at']) as String?),
      editedAt: parseApiDateTimeNullable(json['edited_at'] as String?),
```

**Алгоритм.** На каждую дату: `trim()` (копия строки) → `DateTime.tryParse`
(в SDK это `RegExp` + `int.tryParse` на 5–7 компонентов) → `_hasExplicitTimeZone`
(ещё один RegExp по строке) → `DateTime.utc(...)`. Итого 2 regex-матча, 1 копия
строки и 2 конструктора даты на одно поле. O(1) по длине строки, но с большой
константой: **32 µs**, из которых 0.5 µs — второй RegExp.

**Почему горячо.** Не одна операция, а произведение на объём истории:

- `lib/core/storage/encrypted_message_cache.dart:335`
  `return messagesJson.map((e) => ApiMessage.fromJson(e)).toList();` — до **2000**
  сообщений секретного чата (лимит `maxLimit = 2000` на `:236`) пересобираются в
  модели **на UI-изоляте**: расшифровка и `jsonDecode` уже в `_runCompute`, а
  `fromJson` — уже нет. Это зеркало perf P1 #20 (там был только `toJson`-путь).
- Догон истории: `backend_chat_provider.dart:3223-3225,3358-3359,2610` — страницы
  декодируются пачками, каждая страница = `parseApiDateTime` на каждое сообщение.
- Холодный старт инбокса: `ApiChatSummary.fromJson` парсит `lastActivity`,
  `pinnedAt` и `lastMessage` (ещё один `ApiMessage.fromJson`) — 2–3 даты на чат,
  то есть **15–20 ms на 200 чатов** только на датах.

**Текущая стоимость.** 2000 сообщений × 22.9 µs = **45.8 ms** (замер, 1 поле на
сообщение) и до **92 ms**, если у сообщений есть `edited_at`. Плюс `jsonDecode`
12.6 ms и полевая сборка модели. Бюджет кадра — 8.3 ms, то есть один restore —
это 6–11 пропущенных кадров подряд.

**Риск.** Низкий по границе: `String → (int64 epochMicros, bool hasOffset)` —
ничего не маршалится кроме 24 байт, FFI-вызов ~0.3–1 µs, выигрыш ~30×. Нужен
батч-вариант (`List<String> → Int64List`), иначе 2000 отдельных FFI-вызовов
съедят выигрыш. **Web:** FFI нет; на web `Isolate.run` не даёт параллелизма
(`compute` идёт в том же потоке), поэтому для web это ровно тот случай, где
Rust→wasm — единственный способ ускорить, а не отложить. Но: модуль обязан
собирать идентичный ISO-разбор (включая ветку «нет зоны → трактовать как UTC»),
иначе поедут все сортировки и разделители дат.

**Вердикт: `rust-candidate`.** Если не хотят второй бэкенд: сначала
`Isolate.run` вокруг `map(fromJson)` (снимает 46–92 ms с UI-потока на
Android/Windows, на web не помогает), а дату в самом Dart заменить на
фиксированный парсер без `DateTime.tryParse` — это ~1 µs и без Rust.

---

## 2. markdown → plain text для превью инбокса — `rust-candidate`

`lib/core/utils/message_preview_text.dart:36-43`:

```dart
  final document = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  );
  for (final node in document.parseLines(source.split('\n'))) {
    write(node);
  }
  final plain = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
```

**Алгоритм.** Каждый вызов: `split('\n')` (O(n) аллокаций), новый `md.Document` с
полным GFM-набором inline-синтаксисов, блочный + инлайновый разбор в AST, обход AST
со сборкой в `StringBuffer`, затем финальный `replaceAll(\s+)` (ещё один проход +
новая строка). То есть 3 полных прохода по тексту и дерево объектов — ради
однострочного превью.

**Почему горячо.** Вызов идёт из `itemBuilder` каждого ряда инбокса:
`lib/screens/chat_list_screen.dart:1334-1348` → `_previewFormatter.format(text)` →
`messagePreviewText`. Кэш есть (`MessagePreviewFormatter`, 512 записей, `:48-59`),
но:

- он **пуст на старте** → первый экран инбокса = 15 видимых рядов × 162 µs ≈
  **2.4 ms**, а «прокрутил весь список из 200 чатов» ≈ **32 ms** суммарно;
- каждое новое сообщение = один промах кэша (162 µs) — на активном групповом
  чате (5 msg/s) это 0.8 ms/s, не страшно;
- `cache: !chat.isSecret` (`:1416`) — **для секретных чатов кэш выключен**, парсинг
  на каждый rebuild ряда;
- кэш очищается при смене аккаунта/фильтра (`:464`), то есть сценарий «открыл,
  переключил, вернулся» повторяется.

**Текущая стоимость.** Замер: 40 µs (7 симв.) / 162 µs (153) / 473 µs (444).
Из 162 µs — 128 µs это `parseLines`, то есть сам парсер, а не обход.

**Риск.** Граница чистая и батчится идеально: `List<String> → List<String>`
(offsets/длины можно вернуть одним `Int32List` + один общий буфер, чтобы не гонять
строки туда-сюда). Полутона: Rust-парсер (`pulldown-cmark`) — **не тот же** GFM,
что `package:markdown`; превью может разойтись на экзотике (таблицы, сноски,
`<html>`), а превью видно в списке рядом с полным текстом — расхождение заметят.
Безопаснее держать паритет: реализовать только «выкинуть разметку, схлопнуть
пробелы», а не полный GFM. **Web:** нужен wasm-бэкенд; на web это единственный
путь к ускорению (isolate не параллелит).

**Вердикт: `rust-candidate`** (батч по видимому окну инбокса). Более дешёвый
шаг в Dart: быстрый путь `if (!hasMarkdownChars(source)) return collapse (source)`
— большинство сообщений не содержат разметки вообще, и 90 % вызовов станут ~5 µs.

---

## 3. Разбор DOCX на UI-изоляте — `isolate-first`

`lib/core/utils/docx_parser.dart:70-80`:

```dart
  static DocxDocument parseBytes(Uint8List bytes) {
    try {
      final Archive archive = ZipDecoder().decodeBytes(bytes);
      final ArchiveFile? docFile = archive.findFile('word/document.xml');
      ...
      final String xml = utf8.decode(docFile.content as List<int>, allowMalformed: true);
      final List<DocxBlock> blocks = _parseDocumentXml(xml);
```

и внешний regex `:95`:

```dart
    final RegExp elementRegex = RegExp(r'<w:(p|tbl)[\s>].*?<\/w:\1>', dotAll: true);
    final Iterable<Match> matches = elementRegex.allMatches(xml);
```

**Алгоритм.** `ZipDecoder` → inflate всего архива → `findFile` (линейный) →
`utf8.decode` → один проход `dotAll`-regex с ленивым `.*?` и обратной ссылкой по
всему XML → на каждый абзац ещё 2 regex → на каждый run ещё regex → на каждый
текстовый узел `_unescapeXml` (5 последовательных `replaceAll`, то есть 5 проходов
по строке). Плюс ветка `_parseParagraph` для каждого абзаца. Итого O(размер XML) с
множителем ~8 проходов.

**Почему горячо.** `lib/screens/native_file_viewer_screen.dart:608-618` —
`_parse()` в `initState` вызывает `DocxParser.parseBytes(data)` **синхронно на
UI-изоляте**; `setState(_isLoading = false)` идёт уже после. То есть тап по
`.docx`-вложению = замороженный UI на всё время разбора, без возможности
показать прогресс. `00-summary.md` уже ставит это в «требует профилятора»
(`DocxParser.parseBytes` на 50–200 КБ).

**Текущая стоимость (замер, экстраполяция).** 610 KB `document.xml`:
8 ms (outer regex) + 13 ms на 1000 абзацев (при 3000 → ~39 ms) + 3.4 ms inflate
≈ **50 ms** на 1 MB документа. Для их 50–200 КБ — 5–20 ms; на Android-устройстве
среднего класса с AOT множитель обычно 1.5–3×.

**Риск.** `compute` уже доступен, вход/выход — `Uint8List`/плоские объекты
(`List<DocxBlock>`), копируется один раз. **Web:** `compute` на web выполняет
работу в том же потоке — то есть для web изолят-фикс ничего не даёт (останется
те же 5–20 ms, но без блокировки кадра они не станут меньше). Rust (inflate +
`quick-xml` без regex) срезал бы это до 2–5 ms и на web через wasm — но
документ открывается раз в жизни на файл, поэтому это оптимизация второго порядка.

**Вердикт: `isolate-first`.** Rust имеет смысл только вместе с полноценным
docx-ридером (стили, списки, таблицы, картинки), а не с этим regex-парсером.

---

## 4. Просмотрщик текстовых файлов: `split` в `build()` — `isolate-first`

`lib/screens/native_file_viewer_screen.dart:870`:

```dart
    final List<String> lines = _content.split('\n');
```

и на каждый видимый ряд, `:948-949`:

```dart
                final bool isMatch = _searchQuery.isNotEmpty &&
                    line.toLowerCase().contains(_searchQuery);
```

**Алгоритм.** `split` — один проход + N новых строк (для 1 MB лога это 20–100 тыс.
объектов) **на каждый build**. `build()` вызывается на каждый символ поиска
(`onChanged: (val) => setState(...)`, `:912-913`), на переключение переносов
(`:926`) и на любую смену темы/размера. Подсветка дополнительно делает
`toLowerCase()` на каждую видимую строку на каждый build.

**Почему горячо.** Просмотрщик открывается на вложенные `.txt/.log/.json/.md`-файлы
из чата; объём не ограничен ничем (в отличие от docx, где обычно 50–200 КБ).
Замер: **3.85 ms** на `split` 1 MB и **5.55 ms** на `toLowerCase` 1 MB. Для файла
5 MB это **~20 ms на каждое нажатие** в поиске, для 20 MB — 80 ms (уже «залипает
клавиатура»). Плюс perf P1 #18 фиксирует то же место, но без второй половины
(`toLowerCase` в `itemBuilder`).

**Текущая стоимость.** 1 MB: 3.85 ms (`split`) + до 5.55 ms (если бы
`toLowerCase` шёл по всему файлу; сейчас — только по видимым строкам, ~30 × 0.2 µs,
что мало). Главная статья — именно `split` в `build()`.

**Риск.** Изолят: результат — `List<String>` на 20–100 тыс. элементов, это копия
через границу изолята (TransferableTypedData не применим к `List<String>`;
придётся вернуть один `String` + `Int32List` смещений, что даже лучше). **Web:**
`compute` не параллелит — для web выигрыша не будет, только уберётся повторная
работа за счёт кэша. Rust на байтах (разбить UTF-8 на смещения) даст ~0.3 ms на
1 MB, но наружу всё равно надо отдать смещения и один буфер текста — то есть
граница «плоская», и это единственный честный способ ускорить web.

**Вердикт: `isolate-first`** (`split` один раз при загрузке + пересчёт только
`_searchQuery`; индекс совпадений — по смещениям). Тот же код потом без изменений
переносится в Rust, если понадобится web.

---

## 5. `customEmojiLength` на каждое нажатие — `no`

`lib/models/api/custom_emoji_model.dart:3-4`:

```dart
int customEmojiLength(String text) =>
    text.replaceAll(customEmojiPattern, '\uFFFC').characters.length;
```

вызывается из форматтера ввода, `lib/widgets/chat/custom_emoji_text.dart:157-161`:

```dart
  ) =>
      !newValue.composing.isCollapsed ||
          customEmojiLength(newValue.text) <= maximum
      ? newValue
      : oldValue;
```

**Алгоритм.** `replaceAll(RegExp, …)` — полный проход + новая строка (даже если
совпадений нет), затем `characters.length` — полная сегментация на графемы
(таблицы Unicode + `BreakIterator`-логика в Dart). O(n), две аллокации.

**Почему горячо.** `CustomEmojiLengthFormatter` стоит на `inputFormatters` в
композере комментариев с лимитом **10 000** (`lib/screens/post_comments_screen.dart:472-473`),
в создании поста (лимит 4096, `lib/screens/create_post_screen.dart:869-870`);
в `create_post_screen.dart:935` та же функция вызывается **ещё раз в build()** для
счётчика `X / 4096`, и на каждой перерисовке. На длинном комментарии это два
вызова на нажатие.

**Текущая стоимость.** Замер: **294 µs** на 8400 code units, из них 245 µs —
`replaceAll` (регекс-скан + копия). На Android это, скорее всего, 0.6–1.5 ms
на нажатие в конце длинного комментария — заметно, но не «залипание».

**Риск/почему `no`.** Выигрыш Rust был бы реален (30–80 µs против 294), но:
стоимость убивается строкой `if (text.length <= maximum) return value;` перед
подсчётом (code units ≥ графем, 99.9 % нажатий отсекаются), а для счётчика
достаточно мемоизации по `text`. Плагин ради 0.3 ms на нажатие — не та цена,
особенно с обязательным wasm для web.

**Вердикт: `no`.** Правка в Dart.

---

## 6. Пересортировка инбокса и пересборка проекции на каждое сообщение — `no`

`lib/providers/backend_chat_provider.dart:860`:

```dart
      updated.sort(compareChatRecency);

      state = AsyncData<List<ApiChatSummary>>(updated);
      _persistChats(updated);
```

и `lib/screens/chat_list_screen.dart:985-990, 1006, 1056-1058`:

```dart
    final List<ApiChatSummary> filtered = archiveOpen
        ? List<ApiChatSummary>.of(archived)
        : List<ApiChatSummary>.of(
            _applyFilter(
              (folder == null ? chats : chats.where(folder.includes))
                  .where((ApiChatSummary c) => !c.isArchived)
                  .toList(),
              filter,
            ),
          );
```

```dart
      final index = filtered.indexWhere((chat) => chat.isSaved);
```

```dart
    final Map<int, int> idToIndex = <int, int>{
      for (int i = 0; i < filtered.length; i++) filtered[i].id: i,
    };
```

**Алгоритм.** На каждое входящее сообщение: O(n log n) сортировка по
`(pinnedAt, lastActivity, lastMessage.id, id)` (`compareChatRecency`), затем полный
rebuild экрана → `where` + `List.of` (две копии) + `_applyFilter` + `indexWhere` +
`Map` на n элементов. Всё в UI-изоляте, синхронно, в обработчике websocket-события.

**Почему горячо.** Каждое сообщение в любом чате (а в групповом — каждые 200 ms)
дергает `chatsProvider`, а на нём висит весь инбокс. Есть готовый
`insertSorted(updated, chat, compareChatRecency)` (`:1150`), который применяется
только в одном пути из семи.

**Текущая стоимость.** 200 чатов: сортировка ~0.1 ms + проекция ~0.2 ms. 2000
чатов: **~2–3 ms на сообщение**. Это не блокер, но это линейная работа на каждое
событие, и она складывается с пересборкой 15 рядов.

**Риск/почему `no`.** Rust тут не поможет: сортировать 2000 указателей через FFI
дороже, чем сам `sort` в Dart (сравнение уже `DateTime.compareTo`, ~20 ns).
Работа должна стать инкрементальной и мемоизированной — это Dart-правка.

**Вердикт: `no`.**

---

## 7. Локальный поиск в `search_provider` синхронно на каждое нажатие — `no`

`lib/providers/search_provider.dart:45-54`:

```dart
    for (final ApiChatSummary chat in localChats) {
      final String name = chat.name;
      final String? username = chat.username;
      final String? lastMsg = chat.lastMessage?.content;

      final bool nameMatch = name.toLowerCase().contains(lowerQuery);
```

**Алгоритм.** Дебаунс 300 ms стоит **только** на backend-запрос (`:109`), а
локальный проход по всем чатам и всем постам ленты (`:92-98` — три `toLowerCase`
на пост, включая `post.content`) выполняется синхронно в `search()`, то есть на
каждое нажатие. Каждый `toLowerCase()` — новая строка.

**Почему горячо.** `contacts_screen.dart:523` и `chat_members_screen.dart:109`
зовут `search(q)` прямо из `onChanged`. Лента: 200 постов × ~1 KB =
200 KB `toLowerCase` (~1.1 ms по замеру 5.55 ms/MB) + 600 аллокаций строк.

**Текущая стоимость.** 0.5–1.5 ms на нажатие при полной ленте. Не «лаг», но
бесполезная работа на каждый символ.

**Риск/почему `no`.** Изолят на нажатие не годится (round-trip 0.1–1 ms +
переупорядочивание результатов). Правильно: дебаунс локального прохода, нижний
регистр в нормализованном кэше рядом с моделью. Rust — только если появится
локальный полнотекстовый поиск по истории (сейчас его нет: поиск сообщений
серверный), вот там инвертированный индекс на Rust был бы оправдан.

**Вердикт: `no`.**

---

## 8. `MarkdownBody` в `build()` каждой карточки ленты — `no`

`lib/widgets/post_card.dart:384-387`:

```dart
    final markdown = MarkdownBody(
      data: post.content,
      inlineSyntaxes: [CustomEmojiSyntax()],
      builders: {'nios-emoji': CustomEmojiMarkdownBuilder()},
```

**Алгоритм.** Новый `MarkdownBody` + новый `CustomEmojiSyntax` + новый builder-map
создаются на каждый build карточки. Внутри `flutter_markdown_plus` состояние
пересобирает AST только при смене `data` (то есть на монтирование карточки, а не
на каждый скролл) — это проверено по исходникам пакета. Но `CustomEmojiSyntax()`
создаёт экземпляр `InlineSyntax`, который несёт свой `RegExp`, — на каждый build
карточки.

**Почему горячо.** Лента: карточки монтируются при скролле, `MarkdownBody`
разбирает markdown (пост 400+ символов, ограничение «свернуть» — `:383`) и строит
виджет-дерево на каждый блок/инлайн. Плюс рядом уже известный perf P1 #8
(`MarkdownStyleSheet.fromTheme` в build — починен: `_markdownStyle` кэшируется).

**Текущая стоимость.** 0.2–1 ms на монтирование карточки (оценка по замеру
`parseLines` 128 µs на 153 символа + построение виджетов). На скролл ленты это
накладывается на декод изображений — заметно, но это стоимость UI-построения,
которую Rust не убирает.

**Риск/почему `no`.** Парсер markdown можно унести в Rust, но результат — это
`InlineSpan`/виджеты, и весь выигрыш съедается обратной сборкой дерева в Dart.
Единственное осмысленное — не создавать `CustomEmojiSyntax()` в build.
Perf-аудит уже трогал это место; новой причины не появилось.

**Вердикт: `no`.**

---

## 9. Пересчёт QR-матрицы на каждое сообщение — `no`

`lib/widgets/settings/ordinary_e2ee_settings.dart:518-520`:

```dart
                            child: QrImageView(
                              data: _pairCode!,
                              size: constraints.maxWidth.clamp(0, 210),
```

и тот же `build()` содержит `:581`:

```dart
    final chats = ref.watch(chatsProvider).value ?? const [];
```

**Алгоритм.** `QrImageView` (qr_flutter 4.1.0, `qr_image_view.dart`) пересчитывает
**в `build()`**: `QrValidator.validate → QrCode.fromData` — сборка битового потока
+ Reed–Solomon по всем codewords + проверка версии. Кэша нет, `withQr`
(`QrImageView.withQr`) не используется.

**Почему горячо.** `_contactSection()` (`:580`) читает `chatsProvider` без
`select` (уже известно как perf P1 #14), страница пересобирается на **любое**
сообщение в аккаунте — и вместе с ней пересчитывается QR (пока висит pair-code).

**Текущая стоимость.** Payload — короткий код/номер безопасности, QR версии 2–5,
~100–200 µs на пересчёт. На каждое сообщение — не страшно, но это чистая
бесполезная работа в момент, когда пользователь читает страницу.

**Риск/почему `no`.** Правка: посчитать `QrCode.fromData` один раз в `initState`
и передать в `QrImageView.withQr`, плюс `select` на нужное поле провайдера.
Rust (rcq/fast_qr) на одном коротком QR — микрооптимизация без масштаба.

**Вердикт: `no`.**

---

## 10. Сжатие изображений перед отправкой — `native-plugin-first`

`lib/core/utils/image_compressor.dart:32-38`:

```dart
      final Uint8List result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxWidth ?? _maxWidth,
        minHeight: maxHeight ?? _maxHeight,
        quality: quality,
        format: CompressFormat.jpeg,
      );
```

Ресайз и JPEG-энкод уже делаются нативным кодом платформы
(`flutter_image_compress`: Android/Windows — нативный, web — `flutter_image_compress_web`
есть в дереве пакетов). Dart-сторона только решает, стоит ли сжимать
(`bytes.length < 100 KB` → пропуск). **Rust не нужен и был бы регрессом**:
пришлось бы тащить свой JPEG-энкодер и wasm-бэкенд ради того, что платформа уже
делает на аппаратном/нативном коде.

Аналогично (проверено, Rust не нужен):

| Место | Почему не кандидат |
|---|---|
| `lib/widgets/media_grid_picker.dart:1470`, `:1386` | `photo_manager.thumbnailDataWithSize` — нативные превью галереи, окно в 1920 px, на web не используется |
| `lib/widgets/chat/bubble/media_album_bubble.dart:42,318-337` | `MediaAlbum.decode` уже в `compute`; декод фото — `ui.ImageDescriptor.instantiateCodec(targetWidth:)`, то есть движок декодирует сразу в нужный размер (правильно) |
| `lib/core/utils/sticker_formatter.dart:59` | уже `compute(_formatStickerImage, …)` |
| `lib/screens/chat_detail_screen.dart:1150` | zip-альбом уже `compute(_encodeAlbum, images)` |
| `lib/widgets/wallpaper/wallpaper_image_cache.dart:319-340` | растр строится через `PictureRecorder`/`toImage` — это движок Flutter; Rust не может отдать `ui.Image` без того же прохода |
| `lib/core/utils/noto_emoji.dart:19-50` | одна проверка на бабл: `length > 128` отсекает всё, дальше 1–2 графемы + lookup в `const Set` из ~3000 строк |
| `lib/widgets/chat/m3_emoji_search_view.dart:177` | поиск по каталогу эмодзи через `EmojiPickerUtils` — единицы тысяч подстрок на нажатие, ~1 ms, каталог статичен |
| `lib/widgets/chat/bubble/bubble_text_renderer.dart:99-122` | токены разбираются один раз в `initState`/при смене текста, а не в `build()` |

## Пересечение с perf-аудитом (не повторяю, только отмечаю состояние)

| perf | Место | Статус сейчас |
|---|---|---|
| #18 | `native_file_viewer_screen.dart` `split` в build | **still**, строка 870; добавляю вторую статью — `toLowerCase` в `itemBuilder` (`:949`) |
| #19 | `legal_viewer_screen.dart` поиск по абзацам | **still** (`:341-347`), но это не Rust: пересборка `Column`, правка — ленивый список |
| #11 | `interactive_message.dart:43` `parse` на бабл | **still** (`message_bubble.dart:1569-1571`); на текст без маркера это `lastIndexOf` (−1) — дёшево, Rust не оправдан |
| #20 | `encrypted_message_cache.dart:236-242` `toJson` до изолята | **still**, но появилось зеркало: `fromJson` **после** изолята (`:335`) — см. кандидат 1 |
| #14 | `ordinary_e2ee_settings.dart:574` (`chatsProvider` без select) | **still**, теперь `:581`; следствие — пересчёт QR (кандидат 9) |
| #8 | `post_card.dart` markdown в build | стили **починены** (`_markdownStyle`), `MarkdownBody`/`CustomEmojiSyntax()` — **still** |
| #56 | `datetime_helpers.dart:55,200` RegExp в литералах | **still**; замер: RegExp — 0.5 µs, реальная цена — `DateTime.tryParse` 32 µs (кандидат 1) |

## Итог

- **2 rust-candidate:** ISO-дата в моделях (46–92 ms на restore 2000 сообщений) и
  markdown→plain для превью (до 32 ms на экран инбокса). Оба — синхронные вызовы
  на пути кадра, где изолят либо невозможен (нужен результат в кадре), либо на web
  бесполезен.
- **2 isolate-first:** docx и просмотрщик текста. Оба — `compute` + кэш, Rust потом.
- **6 no / native-plugin-first:** цены реальные, но правка в Dart дешевле, либо
  задачу уже решает нативный пакет.
