# Rust в NiosMess: технико-экономическое обоснование

Дата: 2026-11-28. Автор: исследовательский субагент.
Код не изменялся. Всё, что не подтверждено источником или замером, помечено
`confidence`.

Прочитано перед работой: `audit/PROJECT-CONTEXT.md`, `audit/perf/00-summary.md`
(в частности P0-2), `pulse_flutter/pubspec.yaml`. Дополнительно — фактические
пакеты в `packages/` и в pub-кэше (это оказалось важнее брифа, см. §2).

---

## 1. Вердикт

Переписывать мессенджер на Rust — не стоит. Переносить отдельные горячие
операции — стоит, но только одну группу: **Curve25519 (Ed25519 verify + X25519 DH)
на Android и Windows**.

1. `cryptography_flutter` **не закрывает P0-2**: на Android он ускоряет AES-GCM,
   ChaCha20, HMAC, PBKDF2, но Ed25519/X25519 у него есть **только на Apple**;
   web/windows/linux не поддержаны вовсе. Рекомендация из `perf/00-summary.md`
   («просто включить `FlutterCryptography.enable()`») проблему не решает.
2. На вебе Rust не нужен и вреден: `package:cryptography` уже использует WebCrypto
   (>500 МБ/с AES), а wasm-сборка FRB однопоточная, +~1 МБ и без `catch_unwind`.
3. MLS переносить не надо: `openmls` — 0.9.2 stable / 0.10.0-rc.1, обёртка на
   pub.dev без верифицированного издателя, +5.7 МБ на ABI. В приложении MLS
   вообще не используется.
4. JSON/serde, сжатие, Unicode, изображения — FFI не окупается: копирование
   дороже выигрыша, а в Dart уже есть нативные бэкенды.
5. Перед Rust — два бесплатных шага: батчинг в один долгоживущий isolate-воркер
   (не `Isolate.run` на сообщение) и профиль на целевом Android. Возможно, этого
   хватит.

---

## 2. Поправка к брифу: Rust в репозитории уже есть

Бриф говорит «`nios_mls` (MLS на Dart)». Фактически:

- `packages/nios_mls/pubspec.yaml` → `openmls: 3.2.1`, а пакет `openmls` на pub.dev
  — «Dart wrapper for OpenMLS — a Rust implementation of MLS», MIT,
  `flutter_rust_bridge: ">=2.13.0 <2.13.1"`, свой `hook/build.dart`.
- `.dart_tool/native_assets.yaml` в `nios_mls` регистрирует
  `openmls_frb.dll` — это FRB-бинарь, а не Dart-код.
- `nios_mls` **не входит** в `pulse_flutter` и не входит в `nios_sdk`. Его
  единственный потребитель — `packages/nios_lab`, вместе с `iroh_quic 1.1.0`
  («Loads a prebuilt Rust core over dart:ffi», издатель `snowpine.io`).

Вывод: команда уже обкатала паттерн «prebuilt Rust core + build hook + FRB» в
лабораторных пакетах. Вопрос не «сможем ли», а «где окупается». И там же лежит
готовый образец того, как обходить проблему сборки (§7.4).

---

## 3. Замеры на этой машине (база для всех оценок)

Методика: Windows x64, Dart 3.14.0 stable, `dart compile exe` (AOT),
`cryptography 2.9.0` (pure-Dart бэкенд — ровно то, что сейчас работает на
Android), прогрев + усреднение. Скрипты: `%TEMP%\opencode\bench_crypto`.

| Операция | Время | Комментарий |
|---|---|---|
| Ed25519 sign (64 B) | **2 170 µs** | |
| Ed25519 verify (64 B) | **2 122 µs** | доминанта стоимости сообщения |
| X25519 shared secret | **610 µs** | |
| AES-GCM-256 seal 64 B | 6.2 µs | |
| AES-GCM-256 seal 1 KB | 55 µs | ≈18 МБ/с |
| AES-GCM-256 open 1 KB | 53 µs | |
| SHA-256 1 KB | 15 µs | ≈65 МБ/с |
| `dart:ffi` вызов, 0 аргументов | **6.5 нс** | `GetTickCount64` |
| `dart:ffi` вызов, 3 int | **9.3 нс** | `MulDiv` |
| `Isolate.run()` пустой | 92 µs | |
| `Isolate.run()` echo 1 КБ | 296 µs | |
| `Isolate.run()` echo 1 МБ | 338 µs | |

Что из этого следует:

- **FFI сам по себе бесплатен** (единицы наносекунд). Дорог не вызов, а
  маршалинг/копирование и синхронность (см. §7.1).
- **Путь расшифровки одного сообщения** в `ordinary_e2ee_codec.decrypt`
  (1 verify + 1 X25519 + 2 AES) ≈ **2.7 мс** на десктопе. Экстраполяция на
  средний Android ×2–5 → **5–14 мс/сообщение** `confidence: medium`
  (на целевых устройствах не мерил; в аудите это помечено как «требует
  профилятора»).
- Догон 1000 сообщений = **5–14 с чистого CPU**. Это и есть P0-2.
- Изолят-хоп 92–300 µs на сообщение = **3–10 %** от 2.7 мс. То есть изолят
  лечит jank, но не стоимость; и спавнить изолят на каждое сообщение — плохо.

---

## 4. Таблица решений

| Задача | Вариант | Цена | Выигрыш | Риск | Вердикт |
|---|---|---|---|---|---|
| Ed25519 verify + X25519 DH (каждое сообщение) | **Rust-крейт** (`ed25519-dalek` 3.0.0, `x25519-dalek` 3.0.0) через FFI | +~0.3–1 МБ/ABI `conf: low`; +Rust в CI; +1 unsafe-граница | 2.7 мс → ~0.1–0.15 мс, **~20–30×** `conf: medium` | аудит крипто-поверхности; ключи в лишней памяти; ошибки FFI = краш | **Да, единственный оправданный кандидат.** Сначала замер на Android |
| AES-GCM на телефонах | `cryptography_flutter` (Android/iOS/macOS) | 1 зависимость, 0 кода | до ~50× (заявка автора пакета) | нет web/windows/linux; P0-2 по кривым не решает | **Да, дешёвый шаг** — но отдельно от Rust |
| AES-GCM на Windows/Linux | isolate-воркер (батч) | ~0, код есть | jank → 0, скорость та же | нет | **Да** |
| AES на web | ничего | 0 | уже WebCrypto >500 МБ/с | — | **Ничего не делать** |
| MLS | Rust `openmls` | +5.7 МБ/ABI, +942 КБ wasm | протокол целиком готов | 0.9.x/0.10-rc (pre-1.0), обёртка без издателя, single maintainer | **Нет.** В приложении MLS не используется |
| JSON/`serde` | Rust | копирование строк туда-обратно | `jsonDecode` в Dart уже нативный; serde быстрее в 1.5–2× | ломает всю модель данных | **Нет** |
| Сжатие (zstd) | Rust `zstd` | +0.3 МБ | заметно только на больших блобах | уже есть `archive` | **Только по профилю** |
| Unicode/текст | Rust `unicode-segmentation` | FFI на каждый символ | `characters` уже корректен | бессмысленно | **Нет** |
| Изображения | Rust (`image`) / Pixer | +1–2 МБ | Pixer: 24× в среднем vs `image` | уже есть `flutter_image_compress` (нативный) | **Нет.** Сначала `cacheWidth` (P0-4) |
| Парсинг Markdown/DOCX | Rust | высокая | нет данных | дублирование | **Нет** |

---

## 5. Web: что реально работает

**Работает без Rust, и это лучший вариант:**

- `package:cryptography` на web по умолчанию использует **Web Crypto API**;
  в README: «In browsers, the package uses Web Cryptography, reaching over
  500 MB/s», SHA-512 «over 100 times faster than package:crypto».
  То есть bulk-AES на web уже быстрый — Rust нечего улучшать.
- Что **не** ускоряется: Ed25519/X25519 (WebCrypto их не даёт в общем случае).
  Это единственная причина смотреть на wasm.

**Rust на web возможен, но с оговорками (всё из официального документа
«Limitations of WASM»):**

- FRB поддерживает web «both JavaScript and WebAssembly»; `flutter_rust_bridge`
  на pub.dev имеет теги `platform:web`, `is:wasm-ready`.
- Нет `std::thread::spawn`; Safari не умеет вложенные `Worker`.
- `panic::catch_unwind` **не работает** — паника в Rust = `RuntimeError` в JS,
  которое нельзя поймать по имени. Правило: `.expect()`/`Result` вместо `.unwrap()`.
- Rust→Dart стримы «flaky» на web.
- `Int64List`/`Uint64List` бросают на web; арифметика 64-бит обрезается, а не
  заворачивается.
- Синхронный `#[frb(sync)]` вызов не может ждать освобождения `RustAutoOpaque`;
  на web такие вызовы падают сразу.
- Code assets на web **не собираются вообще**: в хуке `openmls` прямо написано
  `buildCodeAssets is false for web platform`, и wasm копируется вручную в
  `<app_root>/web/pkg/` двумя файлами (`*.js` + `*_bg.wasm`). Это лишний шаг CI
  и лишний артефакт в `web/`, который проект запрещает трогать (см.
  PROJECT-CONTEXT: `web/` в списке «нельзя трогать»).

**Размер wasm:** `openmls_frb-2.5.0-wasm32.tar.gz` = **942 КБ** (MLS целиком).
Crypto-only модуль был бы меньше, но всё равно сотни КБ на первую загрузку.

**Вердикт по web:** Rust не добавлять. Если когда-нибудь понадобится Ed25519 на
web — это отдельное решение с отдельным бюджетом (wasm-загрузка, Safari,
отсутствие `catch_unwind`), а не побочный эффект мобильной оптимизации.

---

## 6. Крипто и MLS: три варианта с аргументами

### 6.1. `cryptography_flutter` — что он на самом деле даёт

Проверено по README пакета и pub.dev-манифесту (2.3.4, 2025-11-21, издатель
`dint.dev` verified, Apache-2.0):

| Алгоритм | Android | iOS/macOS | Windows/Linux | Web |
|---|---|---|---|---|
| AES-GCM | ✅ native | ✅ native | ⚠️ isolate (`BackgroundAesGcm`) | ❌ |
| ChaCha20-Poly1305 | ✅ native | ✅ native | ⚠️ isolate | ❌ |
| HMAC / PBKDF2 | ✅ native | ✅ / ⚠️ isolate | ⚠️ isolate | ❌ |
| **Ed25519** | ❌ | ✅ native | ❌ | ❌ |
| **X25519** | ❌ | ✅ native | ❌ | ❌ |
| NIST ECDH/ECDSA | ❌ | ✅ native | ❌ | ❌ |

`flutter.plugin.platforms` = только `android`, `ios`, `macos`. Ни web, ни
windows, ни linux.

Следствия:
- P0-2 (Ed25519/X25519 на Android в UI-изоляте) **не закрывается**.
- Для проекта с целями Android + Windows + Web пакет покрывает меньше половины
  матрицы.
- Плюс собственное предупреждение README: OS-вызовы «easier to inspect», чем
  pure-Dart реализация — для мессенджера это аргумент против, а не за.

### 6.2. Сравнение по трём осям

| | Rust-крейт | `cryptography_flutter` | isolate |
|---|---|---|---|
| Ed25519 verify (оценка) | ~30–60 µs `conf: low` | недоступно на Android | 2.1 мс + 0.1–0.3 мс хопа |
| X25519 (оценка) | ~50 µs `conf: low` | недоступно на Android | 0.61 мс + хоп |
| AES-GCM 1 КБ | ~1–5 µs | ~1–5 µs (Android) | 55 µs + хоп |
| Покрытие платформ | Android, Windows (+iOS/Linux/macOS) | Android, iOS, macOS | все, кроме web |
| Web | была бы отдельная wasm-сборка | нет | нет (изолятов нет) |
| Цена внедрения | Rust-тулчейн, unsafe-граница, аудит, +размер | один `pub add` | ноль |
| Что лечит | **CPU-стоимость** | CPU-стоимость (частично) | **только jank** |

Главный вывод: **isolate и Rust решают разные проблемы.** Изолят не ускоряет
крипто ни на процент — это подтверждается независимым замером в
dart-lang/sdk#47962: 10 МБ AES-GCM на Android в release:

```
decryption dart (on main thread) took 11380 ms
decryption native took 145 ms
decryption compute took 11993 ms
```

То есть `compute`/изолят дал **хуже**, чем main thread, а нативный вызов — в 78 раз
быстрее. Это ровно тот же профиль, что у нас: pure-Dart крипто дорого само по
себе, а не только потому, что блокирует UI. `confidence: medium` (2021 год,
другая версия Dart, но порядок величины показателен).

### 6.3. Почему «нативный плагин» для кривых на Android — тупик

Соблазн: не тащить Rust, а вызвать Android Keystore/Conscrypt.
Проверка: в CTS-тесте Android `Curve25519Test` генерация Ed25519 в
`AndroidKeyStore` разрешена только «from Android V preview», а в issue-трекере
Google прямо сказано: «Ed25519 signatures are not yet supported by Conscrypt in
the Android platform». Значит, нативный путь = тащить BouncyCastle в Java-слой,
то есть второй крипто-стек рядом с Dart-овым, с собственными багами и без
единого API. `confidence: medium-high` (два независимых источника, но оба не
официальная документация API).

Для Ed25519/X25519 на Android остаются ровно два варианта: pure Dart или Rust.

### 6.4. MLS отдельно

- Крейт: `openmls` **0.9.2** stable, **0.10.0-rc.1** (2026-11-23) — pre-1.0,
  semver-ломающие релизы ожидаемы.
- Dart-обёртка `openmls` на pub.dev: 4.0.0, **`publisherId: null`** — издатель
  не верифицирован, один мейнтейнер, MIT.
- Размер: `openmls_frb-2.5.0-android-arm64-v8a.tar.gz` = **5 817 КБ**,
  `wasm32` = 942 КБ. Это цена MLS-стека целиком, и она на порядок больше, чем
  нужно для крипто-примитивов.
- В `pulse_flutter` MLS нет. Секретные чаты идут через `ordinary_e2ee` и
  `secret_chat_engine`, а не через `nios_mls`.

**Вердикт:** MLS на Rust — не сейчас. Если MLS понадобится в продукте, это
решение уровня «взять openmls целиком» (протокол слишком сложен, чтобы писать
свой), и тогда Rust обязателен — но это отдельный проект, а не оптимизация.

---

## 7. Цена, риски, инфраструктура

### 7.1. Оверхед FFI и копирование

- Замерено: **6.5–9.3 нс** на вызов `dart:ffi` (AOT, x64). Для операции в
  2 000 µs это 0.0005 %.
- Но `dart:ffi`-вызовы **синхронны и выполняются в вызывающем потоке**
  (официальная документация Flutter: «If you invoke a heavy or blocking C function
  on your Flutter app's main UI thread, your app may freeze or drop frames… use
  `Isolate.run`»). То есть Rust **не отменяет** необходимость изолята — он
  уменьшает время, которое изолят держит поток.
- Копирование: 1 МБ туда-обратно через изолят — 338 µs (≈3 ГБ/с). Для 32-байтовых
  ключей и 200-байтовых сообщений это ничто; для блобов — надо `asTypedList`/
  zero-copy.
- Правило: Rust-функции должны быть «крупными» (≥100 µs), иначе маршалинг FRB
  съест выигрыш. Крипто-операция на сообщение — как раз на границе.

### 7.2. Размер

- Замерено на реальном артефакте: MLS+FRB+крипто = **5.7 МБ/ABI** (arm64),
  4.5 МБ (armeabi-v7a), 4.3 МБ (windows-x86_64), 942 КБ (wasm32).
- Независимый ориентир: bitdrift довели Rust-ядро мобильного SDK до **~1 МБ
  (сжатыми)**, стартовав с «several megabytes» — то есть 1–3 МБ на ABI это
  нормальная цена Rust-ядра, и её надо оптимизировать (`opt-level="z"`, LTO,
  `panic=abort`, `strip`).
- Только крипто-крейты (dalek + aes-gcm, без MLS) — оценочно **0.3–1 МБ/ABI**
  `confidence: low`: не собирал, cargo на машине нет.
- Для сравнения: APK и так большой (Flutter-рантайм 4–5 МБ/ABI), так что
  +0.5 МБ — это единицы процентов. Не блокер.

### 7.3. Сборка в CI на три платформы

- **Native assets/hooks — стабильны и рекомендованы.** dart.dev: build hooks
  с Dart 3.10, link hooks с 3.13. Flutter docs: «Since Flutter 3.38, the
  recommended way to bind to native code is `flutter create --template=package_ffi`
  … uses build hooks … no longer requires OS-specific build files». Проект на
  3.50.1 → это штатный путь, а не эксперимент.
- `native_toolchain_rust` 1.1.1 (MIT, издатель `gsconrad.com`, 2026-11-15)
  закрывает Android/iOS/Windows/Linux/macOS одной строкой в `hook/build.dart`.
  Web в списке целевых триплетов **отсутствует**.
- Android-специфика: FRB troubleshooting требует AGP ≥ 8.5.1 и NDK r28+ для
  native-assets-бэкенда. В проекте уже есть вендоренный `audioplayers_android`
  из-за AGP 9 — то есть Gradle-зона и так хрупкая, это добавляет риск.
- `native_assets_cli` (0.18.0, последний релиз 2025-04-29) — прежний,
  низкоуровневый путь. Актуальная документация Dart предлагает пакеты `hooks` +
  `code_assets` (2.2.0), а Flutter — шаблон `package_ffi`. Если предложение
  начинается с `native_assets_cli`, оно опирается на устаревшую инструкцию
  `confidence: medium` (прямого deprecation-заявления в источниках не нашёл).

### 7.4. Как обойти Rust-тулчейн в CI (готовый паттерн из репозитория)

`openmls` 3.2.1 не компилирует Rust у потребителя: `hook/build.dart`
**скачивает** prebuilt-бинарь с GitHub Releases, проверяет SHA256 (fail-closed,
есть только аварийный `OPENMLS_ALLOW_UNVERIFIED_DOWNLOAD`), кэширует по
версии+платформе, и для web копирует wasm в `web/pkg/`. Сборка бинарей — в
отдельном workflow пакета.

Это снимает главный риск «CI должен уметь cargo для 4 триплетов»: собирать
надо один раз в одном workflow, потребитель только скачивает. Минус: build
теперь зависит от сети и от чужого/своего GitHub Release.

---

## 8. Публичные кейсы с замерами (не маркетинг)

| Кейс | Что измерено | Источник | Доверие |
|---|---|---|---|
| Pixer (Rust + build hooks, Dart-пакет) | «24× в среднем vs `image`», resize FullHD→4K **62×**; есть код бенчмарков | lazebny.io, 2026-05-18 | medium-high (методика описана, но автор продаёт пакет) |
| bitdrift (Rust-ядро мобильного SDK) | размер: «several MB → ~1 MB compressed»; CI-гейт на размер каждого PR | blog.bitdrift.io, 2025-10-14 | high (инженерный разбор с цифрами) |
| dart-lang/sdk#47962 | AES 10 МБ, Android release: dart 11 380 мс / native 145 мс / compute 11 993 мс | github.com, 2021-12-17 | medium (старое, но прямой замер) |
| Список продовых пользователей FRB | rustdesk (52k★), spotube (5.9k★), Google `nearby` (598★), breez-sdk | fzyzcjy.github.io/flutter_rust_bridge/guides/users | high (факт использования, без цифр) |
| «Заменил FRB на ручной `dart:ffi`: сборка 18 → 9 мин» | цена FRB в build time | reddit r/FlutterDev (поисковая выдача) | **low** — тред не открывал, только сниппет |

Общая картина: **большой выигрыш там, где pure-Dart реализация наивная**
(изображения, resampling). Для крипто выигрыш тоже большой (десятки раз), но
его надо мерить на целевых Android-устройствах, а не переносить с десктопа.

---

## 9. При каких условиях стоит (гейты)

Rust заслуживает рассмотрения, только если выполнены **все** пункты:

1. Профиль на реальном Android показывает, что E2EE-расшифровка даёт
   ≥15–20 % кадра или ≥2 с на догон 300 сообщений — **после** батчинга в один
   isolate-воркер (не `Isolate.run` на сообщение).
2. Замер pure-Dart Ed25519 verify на целевом устройстве ≥3 мс, а X25519 ≥1 мс
   (мой десктопный замер 2.1/0.6 мс — нижняя граница).
3. Не жалко +0.5–1 МБ на ABI и готовы к аудиту unsafe-границы и хранения ключей
   в лишнем адресном пространстве.
4. Есть отдельный CI-workflow для сборки бинарей (по образцу `openmls`), иначе
   сборка приложения начнёт зависеть от Rust-тулчейна у каждого разработчика.

Если хотя бы один пункт не выполнен — оставить Dart + isolate-воркер +
`cryptography_flutter` (для AES на телефонах).

**Чего избегать:**

- Не тащить весь `openmls` ради крипто-примитивов.
- Не делать Rust на web (wasm без потоков, без `catch_unwind`, +1 МБ,
  ручной `web/pkg/` — а `web/` в проекте запрещено трогать).
- Не использовать FFI для мелких (<50 µs) операций: маршалинг съест выигрыш.
- Не строить Rust-слой «на будущее» — только под конкретный профиль.
- Не принимать `cryptography_flutter` за решение P0-2: на Android он **не**
  ускоряет Ed25519/X25519.

---

## 10. Что не удалось проверить

| Вопрос | Почему | Что нужно |
|---|---|---|
| Реальная скорость Ed25519/X25519 на целевом Android | нет устройства; Rust не установлен (`cargo`/`rustc` отсутствуют) | профиль на устройстве + сборка dalek-крейта |
| Скорость Rust-крейтов vs замеренный Dart | нечем собрать Rust на этой машине | `cargo bench` на x86_64 и arm64 |
| Точный оверхед маршалинга FRB на вызов | нет Rust; замерен только «пол» `dart:ffi` (6.5 нс) | бенчмарк на готовом FRB-проекте |
| Размер APK для crypto-only Rust | не собрано | `--analyze-size` на прототипе |
| `flutter_rust_bridge` 2.14 стабильность на web | 2.14 — beta (2.14.0-beta.2); 2.13.0 stable помечен `is:wasm-ready`, но web-чанжлоги 2.14 beta | дождаться 2.14 stable или тестировать на 2.13.0 |
| Reddit-кейс 18→9 мин | тред не открывал | открыть и проверить методику |
| Реальный профиль `DocxParser`/Markdown | вне задачи | профайлер |

Отдельно: в `pulse_flutter/pubspec.yaml` стоит `environment: sdk: ^3.10.7`, а
бриф говорит Dart 3.14.0 (подтверждено `dart --version`: 3.14.0 stable).
Фактическая версия SDK — 3.14, значит hooks (3.10+) и link hooks (3.13+)
доступны. На выводы это не влияет.

---

## 11. Источники

Все URL открыты 2026-11-28.

**Flutter/Dart официальное**
1. https://dart.dev/tools/hooks — Hooks: build hooks с Dart 3.10, link hooks с 3.13; `hooks` + `code_assets`; `CodeAsset` → `@Native` из `dart:ffi`.
2. https://raw.githubusercontent.com/dart-lang/site-www/main/src/content/tools/hooks.md — исходник той же страницы.
3. https://docs.flutter.dev/interop/bind-native-code — «Since Flutter 3.38 … `flutter create --template=package_ffi` … uses build hooks … no longer requires OS-specific build files».
4. https://docs.flutter.dev/interop/dart-ffi — «FFI calls are synchronous and run on the thread on which they're called… execute blocking FFI calls inside a background Dart isolate using `Isolate.run`».
5. https://raw.githubusercontent.com/dart-lang/site-www/main/src/content/interop/c-interop.md — `dart:ffi` только для Dart Native.
6. https://raw.githubusercontent.com/dart-lang/sdk/main/CHANGELOG.md — раздел 3.14.0; 3.13.x даты.

**flutter_rust_bridge**
7. https://github.com/fzyzcjy/flutter_rust_bridge (README) — «Support Android, iOS, Windows, Linux, MacOS, and Web (both JavaScript and WebAssembly)».
8. https://raw.githubusercontent.com/fzyzcjy/flutter_rust_bridge/master/CHANGELOG.md — 2.13.0 (native assets backend с 2.13.0-beta.2), 2.14.0-beta.2 («Support Dart Wasm output in build-web», «Document Dart WebAssembly support»).
9. https://fzyzcjy.github.io/flutter_rust_bridge/guides/miscellaneous/whats-new — 2.x фичи (async Rust, Rust→Dart, codec SSE).
10. `website/docs/manual/miscellaneous/04-wasm-limitations.md` (raw в репозитории) — полный список ограничений wasm: нет `std::thread::spawn`, нет `catch_unwind`, Safari без вложенных Worker, `Int64List`/`Uint64List`, sync-вызовы и `RustAutoOpaque`.
11. `website/docs/manual/integrate/03-native-assets.md` — `--integration-backend native-assets`, `flutter_rust_bridge_hooks`, `native_toolchain_rust`, требование `crate-type = ["staticlib","cdylib"]` и пина тулчейна.
12. `website/docs/guides/cross-platform/isolate.md` — на web изолятов нет, FRB эмулирует порты.
13. `website/docs/guides/performance/overview.md` — «benchmarked on CI», но цифры названы «coarse».
14. `website/docs/guides/users.md` — rustdesk, spotube, google/nearby, breez-sdk и др.
15. https://pub.dev/api/packages/flutter_rust_bridge — 2.13.0 (2026-08-23), publisher `cjycode.com`, 160/160 баллов, 670 лайков, 677 855 загрузок/30д, теги `platform:web`, `is:wasm-ready`, MIT.
16. https://pub.dev/api/packages/flutter_rust_bridge_hooks — 2.13.0 (2026-08-23).

**Крипто**
17. https://raw.githubusercontent.com/dint-dev/cryptography/master/cryptography_flutter/README.md — таблица «поведение по алгоритмам»: AES/ChaCha на Android+iOS, **Ed25519/X25519 только Apple**, HMAC/PBKDF2 Android; «up to ~50 times» для AES-GCM.
18. https://pub.dev/api/packages/cryptography_flutter — 2.3.4 (2025-11-21), publisher `dint.dev`, плагин только android/ios/macos.
19. https://pub.dev/api/packages/cryptography_flutter/publisher — `dint.dev` (verified).
20. https://raw.githubusercontent.com/dint-dev/cryptography/master/cryptography/README.md — «In browsers, the package uses Web Cryptography, reaching over 500 MB/s»; `BrowserCryptography`.
21. https://pub.dev/api/packages/cryptography — 2.9.0 (2025-11-21), Apache-2.0, платформы включают web.
22. https://github.com/dart-lang/sdk/issues/47962 — «Encryption is pretty slow», замер 10 МБ AES/GCM на Android release (dart 11 380 мс / native 145 мс / compute 11 993 мс), 2021-12-17.
23. https://issuetracker.google.com/issues/399856239 — «Ed25519 signatures are not yet supported by Conscrypt in the Android platform».
24. https://android.googlesource.com/platform/cts/+/refs/heads/main/tests/tests/keystore/src/android/keystore/cts/Curve25519Test.java — Ed25519 в `AndroidKeyStore` «from Android V preview».

**Rust-крейты (crates.io API, 2026-11-28)**
25. `openmls` 0.10.0-rc.1 / stable 0.9.2, 1.47 млн загрузок, repo openmls/openmls.
26. `ed25519-dalek` 3.0.0, `x25519-dalek` 3.0.0 (repo curve25519-dalek).
27. `aes-gcm` 0.11.1, `chacha20poly1305` 0.11.0 (RustCrypto/AEADs).
28. `ring` 0.17.14 (последний релиз 2025-03-11 — стагнация).
29. `libsodium-sys` 0.2.7 (2021 — фактически заброшен, не брать).
30. `serde` 1.0.229, `zstd` 0.14.5, `unicode-segmentation` 1.13.3, `image` 0.25.10.

**Пакеты и артефакты репозитория**
31. `F:\Niosmess V2\packages\nios_mls\pubspec.yaml` — `openmls: 3.2.1`; описание «using native OpenMLS».
32. `F:\Niosmess V2\packages\nios_mls\.dart_tool\native_assets.yaml` — `openmls_frb.dll`.
33. `C:\pubcache\hosted\pub.dev\openmls-3.2.1\pubspec.yaml` — MIT, `flutter_rust_bridge: ">=2.13.0 <2.13.1"`, `platforms: [... web]`, publisher unverified.
34. `…\openmls-3.2.1\hook\build.dart` — скачивание prebuilt + SHA256 fail-closed; `buildCodeAssets is false for web platform`; wasm → `web/pkg/`.
35. https://api.github.com/repos/djx-y-z/openmls_dart/releases — размеры: android-arm64 5 817 КБ, android-armeabi-v7a 4 521 КБ, windows-x86_64 4 257 КБ, wasm32 942 КБ.
36. https://raw.githubusercontent.com/GregoryConrad/native_toolchain_rust/main/README.md — MIT, `RustBuilder`, список триплетов без wasm, 16 KB page sizes.
37. https://pub.dev/api/packages/native_toolchain_rust — 1.1.1 (2026-11-15), publisher `gsconrad.com`.
38. https://pub.dev/api/packages/iroh_quic — 1.5.0 (2026-11-26), «Loads a prebuilt Rust core over dart:ffi», publisher `snowpine.io`.
39. `F:\Niosmess V2\pulse_flutter\lib\services\ordinary_e2ee\ordinary_e2ee_codec.dart:279-334` — путь `decrypt`: 1 verify + 1 X25519 + 2 AES на сообщение.

**Публичные кейсы**
40. https://lazebny.io/pixer-the-fastest-image-library-for-dart-flutter — 2026-05-18; 24× в среднем, resize 62×; «All Flutter platforms are supported, except for Web».
41. https://blog.bitdrift.io/post/optimizing-rust-mobile-sdk-binary-size — 2025-10-14; Rust-ядро «several MB → ~1 MB compressed», CI-гейт на размер.
42. https://www.reddit.com/r/FlutterDev/comments/1r63zx8/ — «18 min → 9 min build time» после отказа от FRB (не проверял, `confidence: low`).

**Собственные замеры** (скрипты в `%TEMP%\opencode\bench_crypto`)
43. `bin/bench_crypto.dart` — Ed25519/X25519/AES-GCM/SHA-256, `dart compile exe`.
44. `bin/bench_ffi3.dart` — оверхед `dart:ffi` через `kernel32.dll`.
45. `bin/bench_iso.dart` — стоимость `Isolate.run` и копирования.
