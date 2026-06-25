## codegraph (preferred)

Этот проект проиндексирован CodeGraph (`codegraph` CLI) — граф знаний на основе tree-sitter со всеми символами, связями и файлами. Чтение субмиллисекундное. **Всегда используй codegraph вместо ручного поиска (grep/glob/чтение файлов) для структурных вопросов.**

### Когда какой инструмент использовать

| Вопрос | Инструмент |
|---|---|
| "Где определён X?" / "Найти символ X" | `codegraph query <X>` |
| "Кто вызывает функцию Y?" | `codegraph callers <Y>` |
| "Что вызывает Y?" | `codegraph callees <Y>` |
| "Что сломается, если изменить Z?" | `codegraph impact <Z>` |
| "Покажи сигнатуру/исходник Y" | `codegraph query <Y>` (вернёт расположение + код) |
| "Какие файлы есть в lib/?" | `codegraph files` |
| "Дай контекст для задачи про ..." | `codegraph context "<описание задачи>"` |
| "Здоров ли индекс?" | `codegraph status` |

### Правила

- **Не grep'ь первым.** Для любого вопроса о символах, структуре, архитектуре — сначала codegraph. Ручной grep используй только для поиска строковых литералов, комментариев, логов.
- **Доверяй результатам codegraph.** Они из полного AST-парсинга. Не перепроверяй grep'ом.
- **Не ходи по файлам вручную.** codegraph выдаёт расположение + сигнатуру + исходник за один вызов. Не читай файл целиком, если codegraph уже вернул нужный фрагмент.
- **Лаг индекса:** файловый вотчер debounce'ит ~500мс. Не делай повторный запрос сразу после редактирования файла в том же шаге.

### graphify (резерв)

Этот проект также имеет граф знаний в graphify-out/ (god nodes,社区-структура).

When the user types `/graphify`, invoke the `skill` tool with `skill: "graphify"` before doing anything else.

Rules:
- Используй graphify только если codegraph не справляется (странные кросс-файловые запросы, семантические вопросы).
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
