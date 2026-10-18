# Дополнительные Nios protocol v1 API

FastAPI routers устанавливаются рядом с действующим NiosMess. Авторизация
использует существующий opaque bearer и `authenticate_human_session`: учётная
запись, NiosID grant, срок сессии и отзыв проверяются тем же путём. Отдельных
логинов, фиксированных production tokens и нового публичного порта нет.

Данные лежат отдельно в `/var/lib/niosmess/protocol-v1/`: SQLite WAL/FULL,
зашифрованные blobs и постоянный seed подписи журнала. Существующие таблицы
чатов не переписываются. Хранилище принадлежит service user `niosmess`, каталог
имеет режим 0700, seed — 0600. Ключей файлов и исходных имён в blob API нет.

## Маршруты

| API | Назначение |
| --- | --- |
| `GET /v1/protocols` | Возможности сервиса и лимиты; bearer обязателен |
| `POST /v1/devices/{id}/challenge`, `PUT /v1/devices/{id}` | Свежая challenge, подпись identity и доказательство Link key; привязка к точной Session/token fingerprint |
| `GET /v1/devices/{id}/protocols`, `POST /v1/devices/{id}/revoke` | Directory/отзыв с проверкой прав |
| `POST /v1/messages`, `/v1/acks`, `/v1/confirm`, `GET /v1/inbox` | Сохранение до ACK, immutable retry, cursor и подтверждение устройства |
| `PUT /v1/manifests/{hash}`, `PUT/HEAD/GET /v1/blobs/{hash}` | Проверенная публикация ciphertext и закрытые HTTP ranges |
| `POST /v1/blobs/{hash}/grants` | Owner выдаёт доступ точным устройствам существующего секретного чата |
| `/v1/mls/...` | Signed KeyPackages, reservations, commits, inbox, confirmations и текущий delivery gate |
| `PUT /v1/iroh/address`, `GET /v1/iroh/devices/{id}/address?chat_id=...` | Дважды подписанные адреса, expiry до 5 минут, ACL действующего чата |
| `/v1/kt/...` | Подписанная история и Merkle proofs; независимый witness profile выключен |

Точные схемы и canonical sign bytes задают исполняемые Python/Dart тесты.
`tests/serve_*_fixture.py` и SDK support server — исключительно loopback fixtures;
production adapter их не импортирует. Native Iroh клиент проверяет decoded
Postcard EndpointId и не доверяет адресу по одному ответу сервера.

## Публикация и доступ к файлам

Manifest резервирует квоту один раз. PUT пишет приватный staging, проверяет
размер и SHA-256 каждого ciphertext-сегмента, выполняет fsync → atomic rename →
directory fsync → commit `ready`. Ответ раньше commit не выдаётся. При падении
процесса файлы `.partial` очищаются под OS lease; чужая активная загрузка не
удаляется. Отмена запроса освобождает в том числе ещё не возвращённые FD/leases.

Каждый HEAD/GET требует актуального устройства и owner/grant. Recipient также
проверяется по текущей привязке secret chat и membership. Grant сам по себе не
разрешает произвольный чат. При отправке сообщения сервер проверяет ready blob
и grant до сохранения ссылки; текст/manifest/key остаются внутри ratchet body.

GET принимает один закрытый `Range: bytes=start-end`, максимум 1 MiB + 16 bytes,
возвращает точный 206 с identity encoding и `private, no-store`. Nginx отдельным
`/v1/` location отключает request/response buffering; остальные приложения и
их лимиты остаются на прежних маршрутах.

Текущие консервативные квоты: ciphertext-файл до 256 MiB, суммарно 1 GiB и
512 MiB на пользователя, до 128 manifest на пользователя. Они учитывают
неоконченные публикации. Автоматического удаления сохранённых данных по TTL нет.
При исчерпании квоты новые публикации получают явный 507, локальная очередь
остаётся у отправителя. Увеличение квот требует проверки свободного диска;
учтённый manifest не означает бесконечное место на единственном VPS.

## Локальная проверка

```powershell
python -m venv output/protocol-backend-tools
output/protocol-backend-tools/Scripts/python -m pip install -r backend_changes/protocol_v1/requirements-test.txt
cd backend_changes/protocol_v1
../../output/protocol-backend-tools/Scripts/python -m pytest tests -q
```

`NIOS_HOST_SOURCE` включает тесты настоящего host adapter. В них фабрика
`AsyncSessionLocal` заменяется до первого обращения к обработчикам; production
DB не открывается. Старые hardening assertions также запускаются с корректными
32-byte X25519 fixture keys вместо устаревших строк-заглушек, без ослабления
проверок. Тесты с реальными процессами, sockets и криптографией работают в CI.

## Развёртывание и откат

`deploy.py stage` — рецепт **первой установки** в текущий legacy release. Он
копирует release, сохраняет ownership, проверяет, что patch targets не являются
shared symlinks, применяет четыре маленькие правки и запускает isolated tests
на настоящем серверном runtime. Полные fingerprints исходной и проверенной
копии защищают от незамеченной параллельной правки до activation.

`deploy.py activate --marker /opt/niosmess/protocol-tools/<release>/release.json`
проверяет receipt, создаёт отдельные данные от service UID, проверяет nginx и
атомарно переключает `/opt/niosmess/current`. Readiness и HTTPS auth проверяются
до успеха; ошибка возвращает предыдущий release. Чужой параллельный release
rollback не перезаписывает. SSH использует существующий helper и known_hosts;
пароль читается локально из `.env` и не выводится.

Для ручного отката использовать точный previous release и nginx backup из
приватного receipt, проверить текущий target перед переключением. Каталог
protocol-v1, seed и ciphertext сохранять: он нужен для возврата и восстановления
подготовленной очереди. На старом backend новый Stream upload остановится;
не следует очищать очередь или отправлять оригинал файла открытым текстом.
Этот initial installer нельзя повторять поверх уже установленного протокола
без отдельной совместимой миграции/рецепта обновления.
