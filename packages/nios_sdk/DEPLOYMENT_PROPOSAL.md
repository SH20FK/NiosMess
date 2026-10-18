# Nios SDK: архив первоначального предложения

Это исторический план до реализации серверных API. Текущее состояние и
проверяемые границы описаны в [DEPLOYMENT.md](DEPLOYMENT.md).

**Статус на 18 октября 2026: проект развёртывания, production не изменён.**
SDK, локальные reference-сервисы и адаптер владения данными аккаунта уже
существуют. Они не добавляют обработчики в действующий NiosMess, не регистрируют
возможности устройств и не включают новый протокол в обычных/секретных чатах.
Этот документ задаёт границы следующих серверных работ и проверки перед
включением. Сам документ не подтверждает готовность выпуска.

Предлагается добавить отдельный versioned service origin с mailbox, blob и
служебными API, сохранив существующий протокол до завершения миграции.
Iroh relay, журнал прозрачности и независимые свидетели имеют
разные функции и владельцев. Замена или размещение всего на одном процессе
не даёт описанных ниже свойств независимости.

## 1. Что именно нужно согласовать

| Изменение | Предлагаемая граница | Условие включения |
| --- | --- | --- |
| Device registration и capabilities | Дополнение существующей авторизации; отдельные версии Link/Stream/MLS/KT | Проверенная привязка аккаунт → устройство → ключи; старые клиенты не получают новый формат |
| Mailbox и blob | Новый HTTPS origin, новые таблицы/объекты и маршруты `/v1/...` | Device-scoped ACL, транзакционная фиксация, квоты, проверки повтора/отказа |
| MLS delivery service | Отдельный упорядоченный служебный поток, KeyPackage directory и fanout | Durable reservation перед созданием commit, восстановление координатора, подтверждения каждого устройства |
| Key transparency | Постоянный append-only log и отдельный log signing key | Независимые witness operators/keys, pinning, мониторинг и политика свежести |
| Iroh relay и signaling | Отдельно согласованные relay URLs и канал обновления адресов | Проверенная endpoint identity; реальные NAT/mobile проверки |

До изменений на сервере владелец утверждает реальные hostname/host placement,
операторов свидетелей, бюджет, размеры/квоты, срок хранения завершённых
записей и способ выдачи device credentials. Секреты в документ не помещаются.
Миграция существующих пользователей и изменение текущих серверных обработчиков
тоже требуют согласования; локальный lab этим разрешением не является.

## 2. Разделение сервисов и доверия

```text
Аккаунт / enrollment ──> подписанный device bundle + capability directory
                                   |
                          pinned client identities
                                   |
Клиент A ── Iroh QUIC / relay ── Клиент B
    |                               |
    +── HTTPS mailbox для офлайна ──+
    +── immutable ciphertext blob ──+

Key log ── consistency proofs ── независимые witnesses ── pinned clients
MLS coordinator ── ordered control events / Welcome ── device inboxes
```

Mailbox хранит конверты отсутствующего получателя. Iroh relay помогает передать
байты между работающими endpoints и не заменяет offline mailbox. В текущем
`IrohLinkTransport` relays по умолчанию выключены, default DNS/pkarr lookup
заменён пустым lookup; адреса и HTTPS `relayUrls` задаёт приложение явно.
ALPN — `nios.link/1`; framing — 4-byte big-endian length + JSON, максимум 2 MiB.
QUIC write/stream completion не означает сохранение или применение операции.

HTTPS bearer credentials должны иметь audience сервиса, account/device binding,
ограниченные права, отзыв и обновление. Reference mailbox использует фиксированную
карту device → token, blob helper — token одного владельца. Это тестовая
авторизация, а не готовый multi-tenant issuer. Production должен проверять
получателя/owner namespace и право доступа на каждом HTTP-запросе; знание hash
объекта или device ID не является разрешением. После регистрации/отзыва ключа
обновляется и привязка уже открытого WebSocket/signaling соединения.

Account identity key остаётся у владельца аккаунта; MLS/device signing secrets,
Link Ed25519 secret, Iroh secret identity и file keys не передаются сервисам
открытым текстом. File key доставляется получателю внутри E2EE operation.
Device bundle v2 связывает account/device, MLS signing key, Link signing key и
Iroh endpoint key подписью account identity. Новый адрес Iroh может менять
маршрут, но не закреплённую identity без отдельного enrollment решения.

## 3. Capabilities и включение на клиенте

**Серверный wire contract ниже предлагается; обработчиков и negotiation client
для него сейчас нет.** Существующий `secret_protocol_version: 2` относится к
старому секретному протоколу и не означает поддержку Link v1.

Предлагаемые дополнения к device directory:

- `PUT /v1/devices/{device}/protocols`: device-authenticated регистрация
  `link:[1]`, `stream:[1]`, `mls:{versions:["1.0"],suites:["0x0001"]}`,
  `ktStatements:[1,2]`, `irohAlpn:["nios.link/1"]`,
  проверенных лимитов размеров и доступных native modules.
- `GET /v1/protocols`: версии сервисов, лимиты, canonical origins, relay policy,
  log ID и идентификаторы утверждённого trust configuration. Ответ не может
  самостоятельно заменить зашитые/ранее закреплённые signing keys.
- `GET /v1/devices/{device}/protocols`: разрешённые вызывающему capabilities,
  device bundle revision и состояние отзыва. Подписанный enrollment связывает
  перечисленные ключи; capabilities дополнительно привязаны к текущей
  device-authenticated регистрации и проверяются против downgrade policy.

Клиент объявляет native capability только после загрузки библиотек на своей
платформе. Desktop setup cache не подтверждает наличие Android libraries в APK.
File-backed адаптеры не рекламируются браузерному клиенту как уже поддержанные.

Negotiation вычисляет пересечение возможностей отправителя, всех устройств
получателя и сервисов. Неизвестная версия, неподдержанный suite, stale trust
checkpoint, смена закреплённой identity или отсутствие mandatory capability
приостанавливают новую доставку с сохранением данных. Отправка plaintext,
автоматический сброс trust и переименование старого протокола запрещены.
Продолжение явно выбранной старой переписки остаётся отдельным старым маршрутом;
новая очередь не должна незаметно уходить через него.

В текущем app adapter `startDelivery(negotiatedVersion: 1, ...)` проверяет только
переданный номер. Реальные запросы выше, регистрация, автоматическое построение
transport factory и вызовы из chat flows ещё нужны. `account.enqueue` до
`startDelivery` выдаёт `protocol_delivery_not_configured`: такой отказ не даёт
права очищать поле ввода. До выпуска нужен durable intent/configuration gate,
позволяющий сохранить пользовательскую операцию до окончания negotiation.
Отсутствующий peer key после настройки delivery уже поддерживается:
`prepareImmediately:false` сохраняет payload, а `wakePeer` возобновляет подготовку.

## 4. Mailbox v1: существующий контракт

Источник: [mailbox server](example/mailbox_server.dart),
[HTTP transport](lib/src/link/transport.dart), [envelope](lib/src/link/models.dart).
Все запросы используют `Authorization: Bearer <device credential>` и JSON.

| Метод и путь | Вход | Успешный ответ / смысл |
| --- | --- | --- |
| `POST /v1/messages` | `EncryptedEnvelope`, `kind:"operation"`, sender равен аутентифицированному устройству | `200 {"stored":true,"digest":"<envelope SHA-256>"}` после commit |
| `POST /v1/acks` | Такой же envelope, `kind:"ack"` | Та же квитанция; это сохранение зашифрованного ACK в mailbox |
| `GET /v1/inbox[?after=<digest>]` | Inbox определяется credential, а не произвольным query device | `200 {"envelopes":[...],"next":<digest или null>}` |
| `POST /v1/confirm` | `{"digest":"..."}` | `200 {"confirmed":true}`; только recipient может подтвердить получение |

Envelope содержит `v,kind,sender,recipient,session,id,sequence,nonce,ciphertext,mac`
и, при device authentication, `signature`. Reference server ограничивает body
1,500,000 bytes, ciphertext — 1 MiB; inbox page — 100 записей/примерно
1,800,000 encoded bytes, клиент — 2 MiB полного ответа. Слишком большая одна
операция не становится вложением автоматически. JSON metadata маршрутизации,
размеры и факт взаимодействия видны сервису; текст и ключи остаются внутри E2EE.

`after` — cursor обхода, не подтверждение. `next:null` завершает обход; следующий
poll снова начинает с оставшихся pending records. Неправильная страница не
продвигает cursor. Клиент вызывает confirm только после своего durable receive
или сохранения recipient ACK. Confirm не означает human read, не удаляет
recipient history и не заменяет прикладную дедупликацию.

Production storage transaction фиксирует уникальную операцию по
`(sender_device,recipient_device,session_id,operation_id)` и digest. Повтор с теми
же bytes возвращает ту же квитанцию; другой digest с тем же ключом — `409`.
Для ACK нельзя использовать только этот operation key: stored/applied/read ACK
относятся к одной операции, но имеют разные bytes. Они идентифицируются digest
и сохраняются/дедуплицируются отдельно. Никаких повторных unread increments,
notifications или списаний upload quota при повторе.

Транзакция сохраняет envelope, delivery state и event outbox **до** ответа.
WebSocket/push отправляет только уведомление о доступной синхронизации, а не
единственный экземпляр данных. Consumer событий восстанавливает пропуски из
inbox. Получение mailbox receipt добавляет только `mailboxStored`;
`recipientApplied` требует проверенного ACK конкретного устройства.
При общем MLS exporter нужны `SignedEnvelopeCipher` и закреплённый Link signing
key; участник группы, знающий общий AES secret, не получает право представляться
другим устройством.

## 5. Blob v1: существующий контракт и права доступа

Источник: [publication/source](lib/src/stream/http_blob_store.dart) и
[формат](lib/src/stream/FORMAT.md). `{hash}` — hash канонического manifest.

| Метод и путь | Требование | Ответ |
| --- | --- | --- |
| `HEAD /v1/blobs/{hash}` | Разрешённый owner/recipient | `404` либо `200` с `X-Nios-Manifest-Hash` и `X-Nios-Ciphertext-Length` |
| `PUT /v1/manifests/{hash}` | Canonical public manifest, проверка hash/лимитов | `201` новый / `200` идентичный существующий |
| `PUT /v1/blobs/{hash}` | Exact ciphertext, правильный `Content-Length`, SHA-256 каждого сегмента | `201`/`200` с теми же двумя receipt headers после durable publication |
| `GET /v1/blobs/{hash}` | Один закрытый `Range: bytes=start-end` | Exact `206`, `Content-Range`, длина и identity encoding; некорректный range — `416` |

Range не превышает 1 MiB + 16 bytes. Redirects, compressed representation и
whole-file `200` fallback клиентом отвергаются. Reverse proxy не меняет диапазон,
body и receipt headers. Публичного `GET manifest` текущему клиенту не требуется:
manifest, его authenticated hash и key приходят в E2EE operation. Receipt body
ограничен 4096 bytes. Blob helper по умолчанию допускает ciphertext до 1 GiB;
лимит формата Stream не является лимитом согласованного сервиса.

Сначала immutable manifest, затем ciphertext в staging, проверка всех segment
hashes, flush/close и atomic publication. Повтор не перезаписывает другой объект;
незавершённый staging после падения не получает ready receipt. Сохраняются owner,
size reservation, publication state и grants для recipient devices. Сам hash
не открывает доступ. Серверу не передаются key, filename, caption или plaintext.

`_BlobBeforeEnvelopeTransport` уже ставит publication barrier перед доставкой
attachment envelope. При отсутствии blob service он оставляет очередь с ошибкой
`blob_service_unavailable`. Привязка grants к действительным получателям и их
отзыв сейчас требуют backend/client wiring. В production успешный HEAD должен
проверять существование **и** разрешения вызывающего, а не утекать object existence
постороннему аккаунту.

Докачка v1 относится к чтению проверяемых диапазонов. Interrupted upload
повторяет целый PUT с тем же prepared ciphertext; offset/multipart upload
continuation не реализован. Remote blob delete/GC API также не входит в текущий
клиентский контракт и требует отдельно версионированной политики.

## 6. MLS: служебный поток нужно ещё реализовать

[NiosMlsClient](../nios_mls/README.md) использует MLS 1.0 suite `0x0001`, реальные
KeyPackages/Welcome/commits и долговременное состояние. Backend не держит group
secrets и не создаёт commits за устройства. Он проверяет transport authorization,
хранит opaque control records и обеспечивает порядок/fanout.

Предлагаемые, пока отсутствующие HTTP API:

| Путь | Назначение и идемпотентность |
| --- | --- |
| `PUT /v1/mls/keypackages/{device}/{hash}` | Проверенный bounded KeyPackage, expiry и device binding; повтор exact bytes; atomically claim once при invite |
| `POST /v1/mls/groups/{group}/reservations` | Durable reservation `(operation_id,base_epoch,head_digest,coordinator_device)` до локального создания commit |
| `PUT /v1/mls/groups/{group}/commits/{operation_id}` | Exact commit, reservation token и Welcome fanout; CAS base epoch/head, конфликт bytes — `409` |
| `GET /v1/mls/inbox?after=<cursor>` | Device-scoped упорядоченные control events, paginated/replayable |
| `POST /v1/mls/confirm` | Подтверждение control event после durable MLS receive/join на конкретном устройстве |

Commit, новый group head, сообщения существующим участникам и Welcome новым
устройствам фиксируются одной DB transaction с event outbox. У каждого delivery
есть постоянный event ID; Welcome выдаётся только целевому устройству. Текущий
MLS adapter принимает message/Welcome до 4 MiB, а Link envelope — 1 MiB:
control service нужен отдельный bounded body contract; заворачивать любой Welcome
в текущий Link JSON без проверки размера нельзя.

Получатель сначала применяет недостающие commits по порядку, затем application
messages нового epoch. Отсутствие commit блокирует расшифровку, сохраняя событие.
Membership/handshake records не попадают в bubbles, preview, unread count или
обычный message TTL. Удалённое устройство не включается в fanout будущих epochs.
Старые доставленные ему данные отозвать невозможно.

**Конкурирующий commit — незавершённая интеграция.** `addDevices/removeDevices`
уже merge локальный pending commit до возврата результата. Поэтому CAS отказ
после генерации не даёт приложению готового безопасного rebase. Для первого
развёртывания предлагается один назначенный commit coordinator на группу плюс
durable reservation. Reservation нельзя просто истечь и отдать следующему
writer: старый coordinator мог уже продвинуть своё локальное состояние.
Сначала восстанавливается/завершается тот же operation ID и exact bytes.
Смена coordinator, отмена незавершённой reservation и rebase требуют отдельного
проверенного client recovery protocol; до него это release blocker.

`NiosMlsClient.acknowledge` отмечает durable transport receipt, не применение
commit всеми участниками. Backend хранит individual delivery confirmations.
Нужен также постоянный bridge из MLS `pendingOperations` в transport outbox;
два независимых `await` не образуют общую транзакцию.

Link session IDs и exporter-key cache должны включать group/epoch. Prepared
конверт не переименовывается и не шифруется заново при retry. При отзыве участника
нельзя продолжать автоматически отправлять ему новые данные под старым exporter.
Политика для уже подготовленной старой очереди — пауза с сохранением, затем
явная journaled migration/cancellation с новыми delivery IDs и прикладной
дедупликацией logical message ID — ещё нуждается в реализации и тестах.

## 7. Key transparency: постоянный log и независимые witnesses

Сейчас есть [verifier/witness API](lib/src/trust/transparency.dart), encrypted
snapshot stores и [in-memory proof producer](lib/src/trust/merkle.dart).
Постоянного сетевого log service и HTTP codec для этих Dart objects пока нет.

Предлагаемые API log service:

- `POST /v1/kt/statements`: account-authorized device statement + signature;
  сервер проверяет identity signature, непрерывную account revision/previous hash
  и выделяет постоянный leaf index. Повтор того же statement hash возвращает
  прежний index; конфликт revision/содержимого отвергается.
- `GET /v1/kt/checkpoint`: `LogCheckpoint.toJson()` + log signature + witness
  signatures; размер, root и timestamp относятся к одному точному checkpoint.
- `GET /v1/kt/consistency?from=<size>&to=<size>`: bounded proof между двумя
  сохранёнными heads; roots/checkpoints не пересоздаются после перезапуска.
- `GET /v1/kt/accounts/{account}/statements?afterRevision=...&atSize=...`:
  все новые непрерывные revisions, authorized statement, leaf index и inclusion
  proof на выбранный checkpoint; максимум 4096 statements на apply batch.
- Служебный witness endpoint `POST /v1/witness/approve`: log-signed candidate
  и consistency proof от последнего собственного checkpoint свидетеля.

Canonical signing bytes берутся из SDK, а не из произвольной пересериализации
JSON. `DeviceKeyStatement` v1 остаётся читаемым; v2 подписывает также Link и Iroh
keys вместе. Account identity сначала независимо закрепляется через enrollment
или ранее доверенное устройство. Login response/имя пользователя само по себе
не доказывает правильность нового identity key.

Log transaction хранит leaf bytes/index, account head и Merkle metadata;
durable checkpoint подписывается только после фиксации соответствующего дерева.
Log signing key отдельно от account keys и каждого witness signing key.
Каждый witness хранит собственный последний checkpoint в долговременном store,
проверяет append-only consistency и фиксирует его **до** выдачи подписи.
Восстановление witness из старого backup без reconciliation/gossip недопустимо.
Четыре ключа в одном SSH `.env` не создают четырёх независимых свидетелей.

Для согласования предлагается профиль из четырёх независимо управляемых
witnesses и quorum 3, с отдельно проверенной моделью не более одного
злонамеренного witness. Два quorums тогда пересекаются как минимум по двум
свидетелям. Это не заменяет checkpoint gossip, мониторинг и независимую проверку
операторов. Пока владельцы/ключи не утверждены, нельзя выпускать обещание
независимой защиты от split view. Более слабый quorum требует явного изменения
модели доверия, а не автоматического снижения при недоступности свидетелей.

Клиент по умолчанию допускает checkpoint age 7 days и clock skew 5 minutes;
witness требует candidate в пределах 5 minutes. Это не обещание мгновенного
отзыва. Нужно согласовать более строгую freshness policy, периодическое
обновление checkpoint и поведение длительно offline клиента. App wrapper сейчас
не экспортирует настройку этих freshness параметров. Проверка age при `apply`
не создаёт таймер автоматического отзыва: coordinator должен проверять свежесть
checkpoint и перед новым trust-sensitive действием; восстановленный snapshot
сам по себе не означает свежую проверку сервера.

Inclusion + consistency доказывают включение и append-only history; ответ account
lookup может утаить более свежую revision. Нужен независимый monitor/сверка
account heads, либо протокол проверки полноты свежего каталога. Такой completeness
proof текущий SDK не предоставляет. При подозрении очередь приостанавливается,
checkpoint/pins не стираются. Старые ключи/отзывы остаются tombstones.

## 8. HTTPS proxy и absolute paths

Все текущие HTTP adapters используют root-relative `/v1/...`: mailbox/blob —
`baseUri.resolve('/v1/...')`.
Следовательно `https://host.example/nios/` **не** создаёт
`https://host.example/nios/v1/...`; запрос уйдёт на `https://host.example/v1/...`.
Требуется отдельный origin с `/v1` на корне или proxy routing по root paths.
Поддержка path-prefix требует отдельного изменения клиента и тестов; конфигом
base URI её сейчас не включить. Hostname в этом примере поясняющий, DNS не создан.

TLS завершается на утверждённом proxy; helpers слушают loopback/private network.
Сертификат проверяется клиентом обычным platform trust, test TLS fixtures не
используются. Не включать insecure loopback option для внешнего host и не
перенаправлять credentials на другой origin. Iroh relay требует собственного
протокольного endpoint, а не forwarding на mailbox HTTP handlers.

Proxy сохраняет Authorization, Range, Content-Range, Content-Length и X-Nios
headers, отключает трансформацию/compression ciphertext representation и
общий cache для private responses. Request/body/header budgets задаются отдельно
для mailbox, MLS control, manifests и больших blob PUT. Настройка одного
глобального «безлимитного upload» недопустима. Absolute timeouts/abort/connection
limits должны работать и на proxy, и на service; access logs не содержат token,
request body, file keys или query credentials.

## 9. Durability, retention и rollback

Текущие тесты проверяют process termination, flush и atomic publication.
Portable Dart APIs не предоставляют parent-directory fsync: внезапное отключение
питания после rename, дисковый контроллер и потеря volume — отдельные поверхности
проверки. Для обещания power-loss durability нужны выбранная DB/WAL policy,
fsync файлов и parent directories на поддержанных ОС, проверенные storage
acknowledgements и независимые restore/power-failure tests.

Production квоты считаются на аккаунт/устройство/owner и stage reservation.
При заполнении сервис отказывает в **новом** приёме; уже подтверждённый pending
конверт не удаляется по возрасту, размерам, обычному message TTL или LRU.
Reference mailbox останавливает приём при 100,000 records / 128 MiB и держит
подтверждённые записи; это демонстрационный предел, не production quota policy.
Клиент при `507`, `429` или временной недоступности сохраняет payload/ciphertext.
После исправления auth/permanent error нужен явный retry/wake, а не потеря записи.

Completed envelopes/ACKs, dedup tombstones, blobs и KT log имеют разные
retention policies. Удаление finished bytes не должно позволять повторно
применить старую операцию; protocol v1 не объявляет deadline операции, поэтому
ограниченный срок dedup требует отдельного epoch/checkpoint/retirement agreement.
KT history/отзывы не подчиняются message TTL. Blob GC проверяет ссылки pending
delivery и explicit deletion; сам факт mailbox receipt не разрешает удалить
единственную доступную копию вложения. Утверждаются цены и пользовательское
действие при нехватке места, а не скрытый срок исчезновения данных.

Rollback выключает **новую отправку** через capability/feature gate, сохраняя
account directories, native generations, prepared bytes, receipt records, keys
и server delivery queues. Старый клиент не открывает/не переписывает новый
journal. Read/ACK/sync endpoints сохраняются совместимыми для восстановления.
Возврат backup server DB без согласования high-water marks/dedup и KT/witness
checkpoints не допускается. Непонятные записи уходят в наблюдаемую паузу.

Confirmed logout сначала останавливает producers, native/network handlers,
gateways и downloads, затем удаляет только выбранный account directory и
secure-store root key. `shutdownAccount(erase:false)` сохраняет данные; текущий
auth logout вызывает adapter. Обычный logout не является remote deletion
истории собеседника. File deletion не гарантирует физическое стирание SSD,
backups и уже полученных копий.

## 10. Порядок работ и обязательные проверки

1. **Согласование.** Утвердить изменения из раздела 1, device/auth model,
   независимых владельцев, quotas/retention и rollback. SSH/deploy до этого
   не выполняется.
2. **Изолированный backend.** Реализовать additive handlers/tables с migrations,
   outbox, credentials/ACL и audit states без содержимого. В staging использовать
   отдельные DB, buckets, signing keys и device accounts. Existing production
   backend здесь не исследовался и его schema/service manager не предполагаются.
3. **Контрактные тесты через настоящий TLS/proxy.** Lost reply после commit →
   один объект; concurrent duplicate/collision; cross-account sender/read/confirm;
   отозванный token; 101+ inbox records и cursor replay; oversized/slow body,
   redirect, timeout/abort; exact Range без compression; interrupted PUT и restart.
4. **MLS/KT и file tests.** Два concurrent membership changes, coordinator
   death до/после server commit, delayed Welcome, commit-before-application,
   недействительная device signature; log/witness restart/backup/fork/withholding,
   stale checkpoint; authenticated file ranges, tampering, interrupted download,
   restart и восстановление key/manifest backup.
5. **Client wiring.** Capability registration/discovery, durable gate до
   negotiation, trust pin/enrollment UX, authorized cipher/transport factory,
   MLS reservation bridge и epoch queue policy, attachment grants и range sources.
   Детерминированный reducer не делает внешние side effects:
   chat DB, notifications и read models требуют своей транзакции/idempotency.
6. **Устройства.** Native packaging/CI checks и два Android с реальными Wi-Fi,
   mobile/NAT, background/Doze, offline restart, process kill и account logout.
   Локальный Windows lab и unit tests эти проверки не заменяют. FPS, батарея,
   доступность relay и power-loss свойства подтверждаются отдельными замерами.
7. **Ограниченный выпуск.** Сначала совместимые server additions без включения
   на клиентах; затем allowlisted тестовые accounts/devices. Включать capabilities
   только после прохождения release gates; провести rollback rehearsal с
   сохранением очереди. После этого отдельно согласовать production rollout.

Наблюдаемость: queue depth/age, retry error codes, mailbox capacity, publication
latency, MLS reservation/epoch lag и witness freshness/quorum.
Тексты, envelope bodies, file keys, identity secrets и credentials в
telemetry/logs не входят.

## Исходники для проверки решения

- [SDK scope и ограничения](README.md).
- [Durable Link](lib/src/link/durable_session.dart) и [reference mailbox](example/mailbox_server.dart).
- [Stream format / HTTP publication](lib/src/stream/FORMAT.md).
- [MLS semantics и durability](../nios_mls/README.md).
- [Iroh deployment boundaries](../nios_iroh/README.md).
- [Transparency verification и persistent witness](lib/src/trust/transparency.dart).
- [App account adapter](../../pulse_flutter/lib/services/protocol/nios_protocol_accounts.dart).
- [Native integration lab](../nios_lab/README.md).
