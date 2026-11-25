# 06 — UI, уведомления, платформенные обёртки

Проверено: `pulse_flutter/lib` (563 файла), `pulse_flutter/test`, `pulse_flutter/integration_test`,
`pulse_flutter/tool`, `packages/nios_sdk`, `packages/nios_mls`, плюс нативные каталоги
`android/`, `ios/`, `windows/`. Без запуска `flutter/dart/pub`.

| пакет | файлов | обращений | где (топ-3) | вердикт |
|---|---|---|---|---|
| firebase_messaging | 1 | 21 | `lib/core/services/push_notification_service.dart:28`, `:424`, `:507` | нужен |
| flutter_local_notifications | 3 | 23 | `lib/core/services/push_notification_service.dart:440`, `:226`; `lib/providers/ota_update_provider.dart:547` | нужен |
| app_links | 1 | 7 | `lib/core/services/deep_link_service.dart:14`, `:18`, `:33` | нужен |
| flutter_markdown | 4 | 8 | `lib/widgets/post_card.dart:383`, `:388`; `lib/screens/native_file_viewer_screen.dart:519` | нужен, внимание: пакет discontinued |
| markdown | 2 | 10 | `lib/widgets/chat/custom_emoji.dart:119`; `lib/core/utils/message_preview_text.dart:36` | нужен |
| local_auth | 3 | 12 | `lib/core/services/biometric_service.dart:48`; `lib/features/security/application/app_lock_controller.dart:131` | нужен |
| flutter_image_compress | 4 | 8 | `lib/core/utils/image_compressor.dart:32`, `:64`; `lib/screens/create_post_screen.dart:174` | нужен |
| flutter_foreground_task | 2 | 12 | `lib/core/services/background_service.dart:112`, `:147`, `:78` | нужен |
| android_intent_plus | 0 | 0 | — (только `pubspec.yaml:98`) | мёртвый |
| shimmer | 0 | 0 | — (только `pubspec.yaml:99`) | мёртвый, функциональность написана сама |

## Детали по спорным

**`markdown`** — объявлен прямым (`pubspec.lock:1232`), и это оправдано: помимо транзитивного
использования через `flutter_markdown`, код импортирует пакет напрямую.
`lib/widgets/chat/custom_emoji.dart:119` регистрирует собственный `md.InlineSyntax`
(`:shortcode:` → нода `nios-emoji`), который потом передаётся в `MarkdownBody` через
`inlineSyntaxes:` (`lib/widgets/post_card.dart:385`). `lib/core/utils/message_preview_text.dart:36`
парсит `md.Document` + `md.ExtensionSet.gitHubFlavored` для текстового превью в списке чатов.
Без прямого `markdown` оба места развалятся — не «только транзитивно».

**`flutter_markdown`** — реально рендерит три поверхности: контент поста в NiosGram
(`post_card.dart:383`, кэшированный `MarkdownStyleSheet` в `:85`), просмотрщик `.md`-файлов
(`native_file_viewer_screen.dart:519`) и кастомные эмодзи-билдеры (`custom_emoji.dart:128`).
Но в README самого пакета (локальный кэш `0.7.7+1`) первым разделом стоит «Discontinued»:
апстрим закрыт, обновлений не будет. Версия последняя, риска прямо сейчас нет, но это
единственный markdown-рендерер в проекте.

**`flutter_image_compress`** — единственная точка сжатия `lib/core/utils/image_compressor.dart`
(1920 px, q80, только файлы ≥100 КБ, всегда JPEG). Вызывается ровно из трёх мест:
`create_post_screen.dart:174` и `:449` (фото поста NiosGram), `account_profile_section.dart:103`
(аватар). `compressImageFile` не вызывается ни разу — только `compressImageBytes`.
С `image` (`package:image`, используется в `sticker_formatter.dart:116` и
`video_pipeline.dart:205-207`) пересечение по возможностям есть — оба умеют resize + JPEG-энкод, —
но пайплайны разные: `image` считает в Dart-изоляте на кадр звонка/на стикер, где плагинный
`flutter_image_compress` неприменим. Дублированием считать не стоит.
Отдельно: чат-вложения через `enqueueAttachment*` (`chat_detail_screen.dart:962-981`)
не сжимаются вообще, хотя l10n-строка обещает «Images are automatically compressed»
(`lib/l10n/app_localizations_en.dart:3801`). Это не про дубль пакета, но про расхождение
обещания и кода.

**`android_intent_plus`** — ноль импортов во всём репозитории. Платформенных guard-ов искать
негде: пакет не вызывается ни на Android, ни где-либо ещё. Функциональность, ради которой его
обычно берут, реализована нативно: `MainActivity.kt:74-87` (`requestIgnoreBatteryOptimizations`
через `Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)`), доступ из Dart —
`lib/core/utils/system_utils.dart:20-29` через `MethodChannel('app.niosmess/system')`.

**`shimmer`** — ноль импортов. Более того, импорт запрещён тестом
`test/m3e_design_audit_test.dart:106` («lib/ contains 0 imports of package:shimmer») и гейтом
`tool/verify_m3e.dart:30-37`. Скелетоны написаны сами: `lib/widgets/pulse_skeleton.dart`
(`ChatListSkeleton:42`, `MessageListSkeleton:275`, `PostCardSkeleton:354`, `PostFeedSkeleton:554`)
плюс локальные `_ShimmerPlaceholder` (`pulse_avatar.dart:171`), `_MediaPlaceholderShimmer`
(`post_card.dart:1538`), `_buildShimmerGrid` (`profile_shared_media_tab_view.dart:478`).
Пакет в pubspec остался мёртвым хвостом.

**`firebase_messaging`** — вся логика в одном файле: токен (`getToken`/vapid, `:547-554`),
разрешения (`:159-189`), foreground/background/opened-app подписки (`:424`, `:507-512`),
`getInitialMessage` (`:519`), регистрация токена из `auth_provider.dart:709`. Данные-only пуши
рисуются локальными уведомлениями, поэтому `firebase_messaging` и
`flutter_local_notifications` — не дубль, а связка. Инициализация обёрнута в
`kIsWeb || Android || iOS` (`main.dart:258-270`), на десктопе не поднимается.

**`flutter_local_notifications`** — каналы `niosmess_messages`, `niosmess_messages_silent`,
`niosmess_calls`, `niosmess_updates`; `MessagingStyle`-треды по чатам, отдельные id для звонков
(`:46-52`), отмена по read receipt (`notifications_provider.dart:191-240`), прогресс скачивания
APK (`ota_update_provider.dart:547`). На Windows плагин зарегистрирован
(`windows/flutter/generated_plugins.cmake:29`), но `WindowsNotificationDetails` не передаются
нигде — на десктопе системных уведомлений фактически нет.

**`app_links`** — только `lib/core/services/deep_link_service.dart`: `AppLinks()` (`:14`),
`getInitialLink` (`:18`), `uriLinkStream` (`:33`), дальше в `AppUrlLauncher.handleDeepLink`.
Guard `kIsWeb` в `main.dart:255`. Схемы объявлены в манифесте: `https://ni-os.ru`
с `autoVerify`, `niosmess://`, `nios://` (`AndroidManifest.xml:61-81`), Windows-плагин
зарегистрирован. Замена `uni_links` в pubspec нет — дубля нет.

**`local_auth`** — `BiometricService` (обёртка, все ошибки гасятся в `false`) +
`AppLockNotifier` (веб отключён через `clientCapabilitiesProvider.isWeb`,
`app_lock_controller.dart:15-30`). Android: `MainActivity : FlutterFragmentActivity`
(`MainActivity.kt:20`), `USE_BIOMETRIC` приходит из манифеста `local_auth_android-2.3.0`.
Windows: `local_auth_windows` подключён. iOS: `NSFaceIDUsageDescription` в
`ios/Runner/Info.plist` **отсутствует** — Face ID вернёт ошибку; iOS в CI не собирается,
поэтому вживую не всплывало.

**`flutter_foreground_task`** — `BackgroundService` держит dataSync-сервис по политике аккаунта
(`applyPolicy`), `ForegroundTaskEventAction.nothing()` (без Dart-колбэка), guard
`kIsWeb || != android` в `_enqueuePolicy` (`background_service.dart:59`). Android-манифест
регистрирует `com.pravera.flutter_foreground_task.service.ForegroundService`
(`AndroidManifest.xml:94-97`). Рядом живёт собственный нативный foreground-сервис
`BluetoothMeshKeepAliveService` (`types connectedDevice|location`) — это не дубль плагина,
а другой тип сервиса, но в приложении их два.

## Что стоит удалить/заменить

1. **`shimmer: ^3.0.0` — удалить из `pubspec.yaml`.** Ноль импортов, импорт запрещён тестом
   `m3e_design_audit_test.dart:106` и `tool/verify_m3e.dart`, скелетоны давно свои
   (`pulse_skeleton.dart`). Пакет тянется в APK/AAB впустую.
2. **`android_intent_plus: ^6.0.0` — удалить.** Ноль импортов; единственный нужный интент
   (battery optimization) уже висит на своём `MethodChannel` + `MainActivity.kt:74`.
3. **`flutter_markdown` — держать, но зафиксировать решение.** Апстрим discontinued, версия
   0.7.7+1 последняя. Либо принять «заморожен и работает» (сейчас так и есть), либо заранее
   выбрать поддерживаемый форк, пока пакет не начнёт конфликтовать с Flutter.
4. **`flutter_image_compress`: либо расширить, либо убрать неиспользуемую половину.**
   `compressImageFile` (`image_compressor.dart:48`) не вызывается ни разу — 25 строк мёртвого
   API. И заодно решить, сжимать ли фото в чатах: сейчас обещание в l10n не выполняется.
