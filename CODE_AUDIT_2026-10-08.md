# Аудит кода NiosMess — 8 октября 2026

Этот документ фиксирует состояние до исправлений. Восстановление секретных чатов для версии 3.96.0 описано в [пакете выпуска](backend_changes/secret_chat_v2/README.md); результаты исходного аудита ниже оставлены для сравнения.

Исходный снимок: Git `e8fade3`, версия `3.95.0+212`. Рабочее дерево перед проверкой было чистым. Инвентаризация: 405 Dart-файлов без generated l10n/Freezed/JSON-файлов, 123 235 строк, включая большие каталоги иконок; 96 файлов `*test.dart`, включая агрегатор. Проведён обзор архитектуры и углублённая проверка выбранных путей: авторизация, logout, секретные чаты, история/кэши, входящие события, блокировка, тема, движение и CI. Это не построчный обзор всех 123 тысяч строк.

**Вывод:** у приложения есть работающая основа и заметная работа над M3 Expressive. Основной риск сейчас — корректность секретных чатов и жизненного цикла данных. До исправления перечисленных P1 нельзя считать обещания о безопасности секретных чатов и блокировки подтверждёнными. Массовый переписанный UI не нужен для устранения найденных дефектов.

Бэкенд не изменялся и подключение к серверу не выполнялось. `.env` не потребовался: значения секретов не читались и не копировались. Авторизация на сервере, права доступа, rate limits, хранение данных сервером, поведение production API и реальная сеть не проверены. APK не собирался. Визуальные экраны не запускались и не снимались: оценка дизайна ниже относится к коду, а не к скриншотам, контрасту или измеренному FPS.

## Результаты проверок

Локальная среда фактически: Flutter 3.44.6, Dart 3.12.2. В AGENTS.md указаны старые локальные версии, CI фиксирует Flutter 3.47.5; результаты ниже относятся к локальной среде.

| Проверка | Результат |
| --- | --- |
| `flutter analyze --no-pub` | Без замечаний, exit 0 |
| `flutter test --no-pub --reporter expanded` | 1390 успешных запусков тестов, 3 падения, exit 1 |
| `flutter test --no-pub test/suite_test.dart --timeout 90s --reporter expanded` | 619 тестов, все прошли, exit 0 |
| `dart tool/verify_m3e.dart` | 30/30 проверок |
| `dart tool/check_ui_architecture.dart` | 11/11 проверок |
| Отдельные воспроизведения с production-классами | 7/7 наблюдений подтвердились |
| После изменения метаданных: повторный `flutter analyze --no-pub` | Без замечаний, exit 0 |
| После изменения метаданных: About/update service tests | 14/14, exit 0 |

Полный запуск выполняет часть тестов дважды: как отдельные файлы и внутри `suite_test.dart`. Поэтому 1390 — число успешных выполнений, а не уникальных тестов. Тесты проекта импортируют `flutter_test`; использован Flutter runner согласно исключению в AGENTS.md, а CLI-проверки запущены напрямую через Dart. Зависимости не обновлялись.

Три падения находятся в [entry_screens_reachability_test.dart](<F:/Niosmess V2/pulse_flutter/test/unit/entry_screens_reachability_test.dart:139>): проверки требуют текст `M3SpringCurves.spatial`, `AppRadii.lgRadius` и `_cachedPicture`. Код теперь использует другие кривые/формы и кэш `ui.Image`. Это падения проверок текстовых фрагментов, а не доказательство краша этих экранов.

## P1 — исправить в первую очередь

### 1. Исходящий текст секретного чата сохраняется на диск открытым

[encrypted_message_cache.dart:78](<F:/Niosmess V2/pulse_flutter/lib/core/storage/encrypted_message_cache.dart:78>) записывает `plaintext` напрямую в Hive-box `enc_sender_plaintext_v1`. При открытии этого box не передаётся `encryptionCipher`. Основной кэш сообщений действительно шифруется AES-GCM, но это отдельное хранилище его обходит. Вызов из отправки секретного сообщения расположен в [backend_chat_provider.dart:1301](<F:/Niosmess V2/pulse_flutter/lib/providers/backend_chat_provider.dart:1301>).

**Воспроизведение:** `saveSenderPlaintext` записал синтетический секретный текст; прямое чтение Hive вернуло тот же текст. Это локальная утечка при доступе к данным приложения/резервной копии, а не утверждение о передаче открытого текста серверу.

**Исправление:** шифровать sender-кэш, мигрировать старые записи, определить срок жизни и очистку при удалении/истечении сообщения. Сохранение своих исходящих сообщений нужно Double Ratchet, но оно должно использовать тот же уровень защиты, что основной кэш.

### 2. Ключи секретных вложений попадают в незашифрованный медиакэш

[chat_media_cache.dart:64](<F:/Niosmess V2/pulse_flutter/lib/core/storage/chat_media_cache.dart:64>) открывает обычный Hive-box. Затем [chat_media_cache.dart:155](<F:/Niosmess V2/pulse_flutter/lib/core/storage/chat_media_cache.dart:155>) сохраняет `ApiMessage.toJson()`, а [message_model.dart:377](<F:/Niosmess V2/pulse_flutter/lib/models/api/message_model.dart:377>) включает туда `e2ee_file_key`. После расшифровки секретных сообщений вызывается `ChatMediaCache.saveMediaMessages`.

**Воспроизведение:** production-кэш сохранил синтетический ключ вложения и расшифрованную подпись как обычные поля Hive. Наличие шифрования самого файла не защищает его, когда ключ лежит рядом открытым.

**Исправление:** отдельное зашифрованное хранилище секретных медиа либо шифрование полного payload. Исключение ключа из JSON само по себе потребует другого защищённого способа восстановления вложения.

### 3. Logout не очищает все локальные данные и E2EE-состояние

[auth_provider.dart:353](<F:/Niosmess V2/pulse_flutter/lib/providers/auth_provider.dart:353>) вызывает только `CacheService.clearAll()`. [cache_service.dart:256](<F:/Niosmess V2/pulse_flutter/lib/core/storage/cache_service.dart:256>) очищает шесть старых boxes; `enc_messages_v1`, `enc_sender_plaintext_v1` и `chat_shared_media_v1` в этот список не входят. Нет и вызова очистки памяти E2EE. Ключи и DR-сессии используют глобальные storage-имена, а статические карты E2EE индексируются только `chatId` — [e2ee_service.dart:45](<F:/Niosmess V2/pulse_flutter/lib/services/e2ee_service.dart:45>).

**Воспроизведение:** вызов того же `CacheService.clearAll()`, который используется при logout, оставил sender-текст и медиакэш на месте. Сам logout через сеть не запускался.

**Последствие:** данные остаются после выхода; аккаунты на одном устройстве не имеют полной изоляции криптографического состояния. Демонстрация отображения чужой переписки в другом аккаунте не выполнялась; доступность таких чатов дополнительно зависит от сервера.

**Исправление:** единый logout coordinator с account-scoped storage и очисткой памяти, кэшей, фоновых задач и активного звонка. Не удалять долгосрочные ключи без политики восстановления: можно необратимо потерять собственную историю. Локальный выход должен завершаться независимо от доступности сети.

### 4. Инициатор завершает E2EE-рукопожатие без проверки подписи ACK

[backend_chat_provider.dart:937](<F:/Niosmess V2/pulse_flutter/lib/providers/backend_chat_provider.dart:937>) передаёт в `completeHandshake` только DH- и Ed-ключи. Подпись из HELO не передаётся. [e2ee_service.dart:346](<F:/Niosmess V2/pulse_flutter/lib/services/e2ee_service.dart:346>) принимает Ed-ключ и переключает статус в `secured`; переданный ephemeral DH вообще не используется. Проверка подписи есть на отвечающей стороне, но не здесь.

**Воспроизведение:** ACK с заведомо некорректной строкой DH и произвольным Ed-ключом перевёл pending-сессию в `secured` без подписи.

**Последствие:** статус и идентичность собеседника можно установить без доказательства владения ключом. Это подтверждает дефект аутентификации рукопожатия, но само по себе не доказывает возможность расшифровать весь обмен или провести полный MITM.

**Исправление:** обе стороны проверяют подпись, допустимые ключи, ожидаемую identity и привязку transcript к участникам/чату/сеансу до `secured`. Изменение wire-протокола требует отдельного согласования бэкенда.

### 5. Смена DH-ключа стирает ранее проверенную identity

[e2ee_service.dart:281](<F:/Niosmess V2/pulse_flutter/lib/services/e2ee_service.dart:281>) и ветка persisted-сессии вызывают `resetSession(..., clearVerifiedPeer: true)` при несовпадении DH-ключа. Это стирает trust pin до проверки новой Ed-identity. Следующее рукопожатие уже не видит прежний pin и его защиту от смены личности.

**Воспроизведение:** после `verifyPeer` другой DH-ключ снял верификацию и перевёл статус в `none`, а не в состояние изменения ключей/компрометации.

**Исправление:** хранить проверенную identity отдельно от сбрасываемой DR-сессии, явно показывать изменение ключей и требовать повторной проверки по выбранной политике. Автоматический reset транспорта не должен автоматически забывать доверие.

### 6. Параллельная отправка рассинхронизирует Double Ratchet

[double_ratchet_service.dart:313](<F:/Niosmess V2/pulse_flutter/lib/services/double_ratchet_service.dart:313>) читает `session.chnKsx`, затем делает `await kdfck`, после чего меняет chain и счётчик. На уровне E2eeService нет очереди/блокировки для операций одной сессии. Два вызова успевают взять одинаковую chain key.

**Воспроизведение:** две отправки через `Future.wait` дали расшифрованное первое сообщение и `null`/ошибку MAC для второго. Контрольный последовательный обмен теми же двумя текстами успешно расшифровался.

**Исправление:** сериализовать все операции одной DR-сессии, включая отправку, приём, handshake/reset и сохранение. Приём использует копию до проверки MAC — это полезная защита, но параллельные операции всё равно могут перезаписать state.

### 7. Два быстрых push-сообщения теряют одно из UI-state

[backend_chat_provider.dart:736](<F:/Niosmess V2/pulse_flutter/lib/providers/backend_chat_provider.dart:736>) сохраняет `current` до `await _decryptE2eeMessages`, затем собирает новый список из этого старого снимка. Dispatcher вызывает обработчики без ожидания. Аналогичный шаблон есть в обработке edit.

**Воспроизведение:** два последовательных вызова `handlePush` в настоящем `ChatMessagesNotifier` оставили в состоянии только сообщение №2. Сервер и repository заменены синтетическими doubles; production reducer не заменялся. Это воспроизводится и без E2EE.

**Исправление:** очередь событий на чат и/или атомарное объединение с актуальным состоянием после await, с повторной дедупликацией. Тестировать совместные new/edit/delete/read/reaction, а также смену аккаунта и загрузку истории. Потеря серверной записи не доказана: найдено исчезновение из клиентского списка.

### 8. Сохранённая блокировка приложения при запуске сначала выключена

[app_lock_controller.dart:14](<F:/Niosmess V2/pulse_flutter/lib/features/security/application/app_lock_controller.dart:14>) запускает async `_init`, но возвращает `AppLockState` с `isEnabled=false`, `isLocked=false`. Сначала ожидается ответ биометрического плагина, потом читается secure storage. [app_lock_gate.dart:29](<F:/Niosmess V2/pulse_flutter/lib/features/security/presentation/app_lock_gate.dart:29>) показывает дочернее дерево, пока оба флага не установлены.

**Воспроизведение:** при заранее сохранённом `app_lock.enabled=true` state оставался разблокированным до завершения отложенного ответа биометрии. После инициализации блокировка включалась. Видимое раскрытие конкретного кадра зависит от порядка загрузки auth и lock; измерение на телефоне не выполнялось.

**Исправление:** явное loading/hydrated-состояние блокировки, которое закрывает приватный UI до чтения политики; обработка ошибок storage/плагина. Политику таймаута применять до первого приватного кадра после resume.

## P2 — следующий этап

### 9. Чтение и запись истории используют разные ключи кэша

[backend_chat_provider.dart:598](<F:/Niosmess V2/pulse_flutter/lib/providers/backend_chat_provider.dart:598>) читает cache без `userId`; `_fetch` на строке 782 также пишет без него. `_writeCache` на строке 1062 пишет с `userId` и флагом `isSecretChat`. В [encrypted_message_cache.dart:24](<F:/Niosmess V2/pulse_flutter/lib/core/storage/encrypted_message_cache.dart:24>) это разные ключи: `chatId` и `userId_chatId`.

После обновлений свежая история попадает в account-scoped запись, а холодный запуск смотрит в другую. Для ratchet-чата это особенно важно: повторно расшифровать уже потреблённый message key обычно невозможно. Также `_fetch` использует лимит обычного чата вместо секретного.

Нужен обязательный account ID во всех cache APIs, единый формат и миграция. Не использовать молчаливый fallback на общий cache другого аккаунта. Полный рестарт секретного разговора на двух клиентах ещё предстоит проверить.

### 10. Provider каждого посещённого чата остаётся с секундным таймером

[backend_chat_provider.dart:1671](<F:/Niosmess V2/pulse_flutter/lib/providers/backend_chat_provider.dart:1671>) создаёт family без `autoDispose`. `build` каждого чата запускает `Timer.periodic` раз в секунду, `_evictExpiredMessages` просматривает список даже для поиска самого факта наличия TTL. Закрытие экрана не инвалидирует этот provider.

Это накопление фоновой работы и памяти по числу посещённых чатов; фактический jank/FPS не измерен. Следует ограничить retention provider, использовать таймер ближайшего срока истечения или общий scheduler и прекращать фоновые проходы для чатов без TTL. При dispose аудит также получил Riverpod assertion из cache flush: `_writeCache` читает `ref` внутри `onDispose` — [backend_chat_provider.dart:584](<F:/Niosmess V2/pulse_flutter/lib/providers/backend_chat_provider.dart:584>). Захватывать storage/account зависимости нужно заранее.

### 11. CI не запускает весь набор и часть «интеграционных» тестов проверяет копию логики

[build.yml:45](<F:/Niosmess V2/.github/workflows/build.yml:45>) запускает только `test/suite_test.dart`. Агрегатор импортирует 64 из 95 остальных тестовых файлов, 31 отсутствует: среди них `services/secret_chat_e2ee_test.dart`, `features/security/app_lock_policy_test.dart`, router, input bar, anti-slop, performance и WebRTC signaling.

В [e2e_cold_start_and_logout_test.dart:180](<F:/Niosmess V2/pulse_flutter/test/integration/e2e_cold_start_and_logout_test.dart:180>) объявлен отдельный `ColdStartAndLogoutManager` прямо в тесте. Его успешный logout не проверяет `AuthNotifier.logout`, поэтому пропускает реальные boxes и статические E2EE-сессии. [secret_chat_e2ee_test.dart:135](<F:/Niosmess V2/pulse_flutter/test/services/secret_chat_e2ee_test.dart:135>) проверяет фильтр self-HELO через локальную функцию, а не production handshake-handler.

Запускать весь каталог либо генерировать и проверять полноту агрегатора. Предпочитать тесты production providers/services с doubles только на границах сети, storage и плагинов. Не обновлять source-substring tests механически: определить поведение, которое они должны защищать.

### 12. Системный размер текста игнорируется

[main.dart:300](<F:/Niosmess V2/pulse_flutter/lib/main.dart:300>) заменяет platform `textScaler` на `TextScaler.linear(fontScale.scale)`. По умолчанию масштаб приложения normal. Большой шрифт и нелинейное масштабирование ОС теряются.

Нужно сочетать пользовательскую настройку приложения с исходным системным scaler, сохраняя accessibility-политику. Проверить маленькие ширины, длинные RU/EN строки и большие размеры текста. Контрастность по скриншотам не проверялась.

### 13. Новые интерфейсы частично обходят локализацию

[app_lock_gate.dart:87](<F:/Niosmess V2/pulse_flutter/lib/features/security/presentation/app_lock_gate.dart:87>) содержит жёстко заданные заголовок, пояснение и кнопки на русском. То же касается biometric reason в controller и новых подтверждений категорий storage — [settings_storage_screen.dart:66](<F:/Niosmess V2/pulse_flutter/lib/screens/settings_storage_screen.dart:66>).

В EN-режиме эти участки остаются русскими. Перенести текст в ARB, использовать `context.l10n`, а в services передавать локализованный reason из UI. Не редактировать generated l10n вручную.

## Material 3 Expressive: что подтверждается кодом

Сильная основа: `useMaterial3: true`, tonal surfaces, zero-elevation темы, `DynamicColorBuilder`, Bricolage/Onest/Golos, `RoundedSuperellipseBorder`, `flutter_m3shapes`, общий spring/motion kit и morphing loading indicator. Есть единый modal слой. Списки чатов и сообщений используют O(1) ID → index maps, `TouchContainer` по умолчанию `Clip.none`, input/list разделены repaint boundaries. Холодный старт использует `Future.wait`. Это реальные архитектурные решения.

Непоследовательности:

- [wallpaper_studio_screen.dart:216](<F:/Niosmess V2/pulse_flutter/lib/features/wallpaper/presentation/wallpaper_studio_screen.dart:216>) использует `PopupMenuButton`, вопреки проектному правилу MenuAnchor/expressive action panel.
- [pulse_loading_indicator.dart:37](<F:/Niosmess V2/pulse_flutter/lib/widgets/pulse_loading_indicator.dart:37>) при `value != null` переключается на стандартный `LinearProgressIndicator`. В комментарии обоснована читаемость определённого прогресса, но требование проекта о wave/morphing expressive индикаторе выполняется лишь в неопределённом режиме. Стандартный LinearProgressIndicator при M3-theme сам по себе не является доказательством MD2.
- [m3_spring_constants.dart:88](<F:/Niosmess V2/pulse_flutter/lib/core/motion/m3_spring_constants.dart:88>) содержит boundary clamps, хотя AGENTS.md требует нормализацию без них. При этом `raw/rawEnd` уже нормализует endpoint; это вопрос согласованности протокола, а не доказанный скачок анимации.
- Есть фиксированные white/black в настройках, логотипах и call overlays. Некоторые осмысленны поверх видео/фото; переносить всё на `onSurface` без проверки контраста нельзя. Для theme UI нужны semantic color roles и явные документированные media-исключения.
- `verify_m3e` проходит, но в основном ищет фрагменты кода и старые version thresholds. Он не ловит перечисленные runtime/security ошибки и не подтверждает визуальное соответствие всей спецификации.

Flutter описывает `useMaterial3` как переключатель M3 цветов, типографики и компонентов; самостоятельного доказательства полного Expressive-соответствия этот флаг не даёт. Это вывод из области действия флага и найденных реализаций, а не заявление об отсутствии M3E в конкретной версии Flutter. Источники: [Flutter ThemeData.useMaterial3](https://api.flutter.dev/flutter/material/ThemeData/useMaterial3.html), [Material component catalogue](https://m3.material.io/components).

Для завершения оценки дизайна нужен отдельный проход по реальным мобильным/desktop экранам: вход, пустой/заполненный inbox, обычный/секретный чат, медиагрузки, звонок, настройки, светлая/тёмная темы, EN, большой шрифт и reduced motion. Измерить frame timings на profile/release устройстве. Набор красивых radius/spring токенов не заменяет эту проверку.

## Архитектура и порядок исправлений

`screens/providers/repositories/services/core` дают понятную основу. Начата feature-архитектура для chats/settings/security/sessions, но она сосуществует со старым разбиением; это допустимый этап миграции, не самостоятельный дефект. Главный узел риска — [backend_chat_provider.dart](<F:/Niosmess V2/pulse_flutter/lib/providers/backend_chat_provider.dart>): 1823 строки объединяют события, E2EE-handshake, optimistic UI, persistence, TTL, notifications и network mutations. `chat_detail_screen.dart` — 2644 строки, `profile_screen.dart` — 2038. Разделение по ответственности уменьшит вероятность следующих гонок, но начинать стоит с воспроизводимых дефектов.

1. Защитить sender/media cache и определить очистку/logout/account isolation.
2. Сериализовать ratchet и чатовые события; добавить regression tests на production код.
3. Исправить handshake identity/signatures/trust reset и startup app lock.
4. Выравнять cache namespaces и покрытие CI.
5. Завершить accessibility/l10n/M3E-компоненты; затем визуально проверить и профилировать.

Дополнительные проверки с сервером после согласования: idempotency повторных send/upload (WebSocket retry создаёт новый message ID), авторизация чужого chat/media URL, отзыв сессии, storage TTL, восстановление handshake после потери ACK, offline/logout и реальный reconnect звонка. По фронтенду нельзя подтвердить, что server-side ACL, deduplication или lifecycle работают неверно.

## Артефакты и изменения этого аудита

[Семь воспроизведений](<C:/CodexHome/visualizations/2026/10/08/01a11c25-70c3-7c90-ad26-03bcc0600750/niosmess_audit_probes_test.dart>) используют реальные crypto/cache/providers и синтетические данные. Они находятся вне набора CI и **утверждают наблюдаемое ошибочное поведение**; их зелёный результат подтверждает дефекты, а не исправления. После исправления нужны обычные regression tests с ожидаемым безопасным поведением.

Сохранены логи: [полный набор](<C:/CodexHome/visualizations/2026/10/08/01a11c25-70c3-7c90-ad26-03bcc0600750/niosmess-audit-tests.log>), [CI-агрегатор](<C:/CodexHome/visualizations/2026/10/08/01a11c25-70c3-7c90-ad26-03bcc0600750/niosmess-audit-ci-suite.log>), [воспроизведения](<C:/CodexHome/visualizations/2026/10/08/01a11c25-70c3-7c90-ad26-03bcc0600750/niosmess-audit-probes.log>), [About/update service](<C:/CodexHome/visualizations/2026/10/08/01a11c25-70c3-7c90-ad26-03bcc0600750/niosmess-audit-metadata-tests.log>).

Команда повторения из `pulse_flutter`:

```powershell
flutter test --no-pub --reporter expanded 'C:/CodexHome/visualizations/2026/10/08/01a11c25-70c3-7c90-ad26-03bcc0600750/niosmess_audit_probes_test.dart'
```

Добавлен этот отчёт. По SemVer-протоколу AGENTS.md документационная задача поднимает patch до **3.95.1+213**. Метаданные `BuildInfo` синхронизированы: до аудита там оставались `3.88.2+188`, старые дата и commit, хотя pubspec уже был `3.95.0+212`; экран About использовал эти значения в некоторых местах. Changelog обновлён в корне и assets. Runtime-дефекты выше не исправлялись. Коммит и push не выполнялись.
