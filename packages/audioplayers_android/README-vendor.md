# audioplayers_android (vendored)

Копия `audioplayers_android` **5.3.0** из pub.dev (sha пакета: см. `pubspec.lock`
основного проекта до вендоринга), подключённая через `dependency_overrides`:

```yaml
dependency_overrides:
  audioplayers_android:
    path: ../packages/audioplayers_android
```

## Зачем

Версия 5.3.0 в `android/build.gradle` применяет `de.mannodermaus.android-junit5`
и тянет в buildscript собственный `com.android.tools.build:gradle:7.3.1`.
Плагин junit5 нужен только для собственных unit-тестов пакета, но он приводит
`LibraryExtensionImpl` к `BaseExtension`, которого в новом DSL AGP 9 нет:

```
Failed to apply plugin 'de.mannodermaus.android-junit5'
> LibraryExtensionImpl$AgpDecorated_Decorated cannot be cast to BaseExtension
```

Из-за этого не конфигурируется модуль `:audioplayers_android`, а значит не
собирается и приложение.

В upstream (ветка `main`) это уже исправлено, но стабильного релиза с фиксом
нет: `audioplayers_android` 6.0.0-dev.0 требует
`audioplayers_platform_interface ^8.0.0-dev`, что тянет каскад dev-пакетов.

## Что изменено относительно 5.3.0

- удалён `apply plugin: 'de.mannodermaus.android-junit5'` и его classpath;
- удалён `buildscript` с AGP 7.3.1 / KGP 1.7.10 (AGP и Kotlin даёт корневая сборка);
- удалены `testImplementation junit-jupiter` / `assertj-core` (тесты пакета не запускаются);
- `minSdkVersion` 19 → 23 (AGP 9 не поддерживает 19);
- `kotlin-stdlib-jdk7` убран: со Kotlin 2.x stdlib добавляется автоматически.

Dart-код, манифест, `pluginClass` и версия (`5.3.0`) не менялись.

## Когда убрать

Как только выйдет стабильный `audioplayers_android` без плагина junit5
(в 6.x), удалить этот каталог и `dependency_overrides` из
`pulse_flutter/pubspec.yaml`.
