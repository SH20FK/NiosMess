# 07 — файлы, медиа, десктоп

Аудит по `pulse_flutter/lib`, `test`, `integration_test`, `packages/` (исключены `*.g.dart`,
`*.freezed.dart`, `l10n/secret/generated`, `build`, `.dart_tool`). Нативные подключения —
`android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, `windows/`, `macos/`, `linux/`.

Считаемое по случаю `Select-String` без учёта регистра: в `chat_wallpaper_painter.dart` 12
«совпадений» `SvgPicture` — это локальные переменные `svgPicture`/`paletteSvgPictures`, они исключены.

| пакет | файлов | обращений | где (топ-3) | вердикт |
|---|---|---|---|---|
| flutter_svg | 19 | 52 | lib/core/illustration/app_illustration.dart:30, lib/widgets/wallpaper/wallpaper_image_cache.dart:100, lib/widgets/chat/custom_emoji.dart:31 | нужен |
| permission_handler | 7 | 53 | lib/services/permission_service.dart:12, lib/widgets/m3_file_picker_bottom_sheet.dart:207, lib/providers/ota_update_provider.dart:470 | нужен; внимание: проверки разрешений продублированы в трёх местах, часть API мёртвая |
| image | 3 | 29 | lib/core/utils/sticker_formatter.dart:70, lib/services/calls/video_pipeline.dart:186, test/unit/sticker_formatter_test.dart:12 | нужен (не транзитивный) |
| archive | 4 | 12 | lib/core/utils/docx_parser.dart:72, lib/core/media/media_album.dart:69,138 | нужен; внимание: в `MediaAlbum` используется только `getCrc32` |
| share_plus | 5 | 19 | lib/screens/native_file_viewer_screen.dart:173, lib/screens/media_viewer_screen.dart:149, lib/widgets/profile/my_qr_code_sheet.dart:80 | нужен |
| flutter_pdfview | 1 | 2 | lib/screens/native_file_viewer_screen.dart:8, :1247 | нужен только Android/iOS; внимание: на десктопе нет fallback |
| qr_flutter | 5 | 19 | lib/screens/login_screen.dart:785, lib/widgets/chat/e2ee_verification_sheet.dart:177, lib/widgets/settings/ordinary_e2ee_settings.dart:511 | нужен |
| pasteboard | 1 | 3 | lib/core/services/desktop_pasteboard_service.dart:24, :38 | нужен (только десктоп) |
| desktop_drop | 3 | 15 | lib/widgets/chat/chat_file_drop_target.dart:174, lib/widgets/chat/desktop_drag_drop_area.dart:32, lib/screens/chat_detail_screen.dart:2463 | нужен; внимание: две реализации drag-and-drop на одном экране |
| window_manager | 1 | 21 | lib/core/services/desktop_window_service.dart:34, :43, :117 | нужен (только десктоп) |

## Детали по запрошенным вопросам

### `image` и `archive` — реальные, не транзитивные

Проверены зависимости потенциальных «родителей»:

- `flutter_image_compress 2.5.1` тянет только `flutter_image_compress_*` + `cross_file` (`image` нет).
- `file_picker 12.3.0` тянет `file_picker_*`, `android_file_picker`, `cross_file` (`archive`/`image` нет).

Оба пакета объявлены прямыми и импортируются прямо:

- `image` — `sticker_formatter.dart:70-152` (декод, кроп/фит в 512×512 RGBA, PNG с альфой;
  `flutter_image_compress` этого не умеет — он не работает с прозрачностью и не даёт canvas-композит),
  `video_pipeline.dart:186-207` (BGRA/YUV420 кадр WebRTC → `encodeJpg`, тоже не задача
  `flutter_image_compress`), плюс `test/unit/sticker_formatter_test.dart`.
- `archive` — `docx_parser.dart:72-73` (`ZipDecoder().decodeBytes`, `findFile('word/document.xml')`)
  и `media_album.dart` только ради `getCrc32` (:69 запись, :138 проверка).

Крипта архивов проекта — своя: `MediaAlbum.encode/decode` пишет STORE-only ZIP вручную
(`0x04034b50` / `0x02014b50`, media_album.dart:71,81,111,155,187), шифрование — `E2eeFileCrypto`
(ws_media_fetcher.dart:341-446, niosgram_draft_store.dart:158). Пакет `archive` к шифрованию
отношения не имеет, ZIP-writer из него не используется вообще.

Частичное пересечение: `image` и `flutter_image_compress` оба ресайзят/кодируют JPEG/PNG, но
наборы задач не пересекаются (альфа-канвас стикеров и raw YUV → JPEG против платформенного сжатия
вложений в `image_compressor.dart:32,64`). Это не дубль, но держать оба приходится сознательно.

### `flutter_pdfview` — Android/iOS-only, десктопного fallback нет

- Пакет `flutter_pdfview 1.4.5`: `pubspec.yaml` → `platforms: android, ios`; в пакете только
  каталоги `android/` и `ios/`. В `pdf_view.dart:307-319` на не-Android/iOS возвращается
  `Text('$defaultTargetPlatform is not yet supported by the pdfview_flutter plugin')`.
- В `native_file_viewer_screen.dart` fallback есть только для web: `:416-421`
  (`ft.isPdf && kIsWeb` → «нельзя посмотреть» + кнопка скачивания). Дальше `:423-429` —
  `_PdfViewer` без проверки платформы, `:1247` — `PDFView(filePath: ...)`.
- Путь достижим на Windows: `m3_file_preview_bottom_sheet.dart:264-271` пушит `/file-viewer` для
  любого PDF без платформенной ветки, `app_router.dart:764` отдаёт `NativeFileViewerScreen`.
  Итог на Windows: экран с английской заглушкой плагина, без кнопки «открыть системным
  просмотрщиком», хотя `FileOpener.openFile` (`core/utils/file_opener.dart:106-155`) уже есть.

### `pasteboard`, `desktop_drop`, `window_manager` — только десктоп, guard-ы на месте

- `window_manager`: `desktop_window_service.dart:16-20` `isDesktop => !kIsWeb && (windows|macOS|linux)`,
  все публичные методы (`initialize`, `setTitle`, `showWindow`, `hideWindow`, `quitApp`,
  `flashTaskbar`) начинаются с проверки `isDesktop`/`isWindows`. Вызовы из `main.dart:256-257`
  (`DesktopWindowService.isDesktop`) и `websocket_dispatcher_provider.dart:169` (`isWindows`).
- `pasteboard`: `desktop_pasteboard_service.dart:10-14` тот же `isDesktop` с `!kIsWeb`, `:20`
  ранний выход. Все три точки вызова закрыты: `chat_detail_screen.dart:2390,2403`,
  `chat_input_bar.dart:892`.
- `desktop_drop`: `chat_file_drop_target.dart:66-71` (`kIsWeb || windows|macOS|linux`) и `:173`
  `if (kIsWeb) return surface;` — на web `DropTarget` вообще не строится, вместо него
  `core/clipboard/file_drop_web.dart` через `dart.library.js_interop`;
  `desktop_drag_drop_area.dart:26` ранний возврат при `!DesktopPasteboardService.isDesktop`.
- Нативные подключения: `windows/flutter/generated_plugin_registrant.cc` —
  `DesktopDropPlugin`, `PasteboardPlugin`, `WindowManagerPlugin` (+ `PermissionHandlerWindowsPlugin`,
  `SharePlusWindowsPluginCApi`); `macos/Flutter/GeneratedPluginRegistrant.swift` и
  `linux/flutter/generated_plugin_registrant.cc` — те же три. `flutter_pdfview` нет ни в одном
  десктопном регистранте, что подтверждает пункт выше.
- Android-разрешения под `permission_handler` прописаны полностью (`AndroidManifest.xml`:
  CAMERA, RECORD_AUDIO, READ_MEDIA_IMAGES/VIDEO/AUDIO, POST_NOTIFICATIONS, REQUEST_INSTALL_PACKAGES,
  storage ≤ SDK 32), iOS — `Info.plist`: NSCamera/NSMicrophone/NSPhotoLibrary(Add)/NSDocumentsFolder.

## Что стоит удалить/заменить

1. **`DesktopDragDropArea` — удалить.** На одном экране живут два `DropTarget`:
   `chat_detail_screen.dart:2370` оборачивает весь чат в `ChatFileDropTarget` (читает байты,
   лимиты 10 файлов / 100 МБ, есть web-реализация) и `:2463` оборачивает body в
   `DesktopDragDropArea` (отдаёт пути в `_uploadDesktopFiles`, без лимитов). Два разных пайплайна
   на одно и то же действие, плюс `DesktopDragDropArea` для проверки платформы дёргает
   `DesktopPasteboardService.isDesktop` — сервис буфера обмена как источник истины про
   drag-and-drop. Остаётся `ChatFileDropTarget`.
2. **`flutter_pdfview` — оставить, но закрыть десктоп.** В `native_file_viewer_screen.dart` рядом
   с web-веткой (`:416`) нужен такой же guard на `windows/macOS/linux` → отдавать файл в
   `FileOpener.openFile`/`OpenFile`. Сейчас на Windows PDF-вложение ведёт в тупик с английским
   текстом плагина (`pdf_view.dart:319`) — это единственное место в отчёте, где фича реально сломана,
   а не просто продублирована.
3. **`archive` в `MediaAlbum` — сузить или расширить осознанно.** Сейчас рукописный ZIP-writer
   (`0x04034b50`/`0x02014b50`) + один `getCrc32` из пакета. Либо оставить CRC32 локальным
   хелпером (20 строк, минус одна зависимость от внутренностей `archive`), либо переписать альбом
   на `Archive`/`ZipEncoder` и перестать поддерживать свой формат. Половинчатое состояние —
   худший вариант: формат свой, а багфиксы CRC — чужие.
4. **`permission_handler` — свести проверки в `PermissionService`.** `requestPhotos`/`hasPhotos`
   (`permission_service.dart:40,68`) не вызываются ниоткуда, при этом те же проверки
   photos/videos/storage скопированы в `media_grid_picker.dart:174-182` и
   `m3_file_picker_bottom_sheet.dart:204-212`, а `notification_settings_section.dart:162` дёргает
   `openAppSettings()` напрямую. Три реализации одного правила — и мёртвая четвёртая.
   Отдельно: `permission_handler` не имеет linux-реализации (в `linux`-регистранте его нет) —
   сейчас не больно, потому что CI собирает только Android/Windows/Web.
