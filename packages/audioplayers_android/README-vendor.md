# audioplayers_android (vendored)

Копия `audioplayers_android` **5.3.0** из pub.dev, подключённая через
`dependency_overrides`:

```yaml
dependency_overrides:
  audioplayers_android:
    path: ../packages/audioplayers_android
```

Sha256 официального архива для сверки при следующем re-vendor:
`f5ff5b15620fbab8cb0849e9636c48e2b96c3f0f71723bbbe2ad3c761b205f05`
(`https://pub.dev/api/archives/audioplayers_android-5.3.0.tar.gz`).

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

Изменены два файла — `android/build.gradle` и `pubspec.yaml` — плюс добавлен
этот README. Dart-код, Kotlin-исходники и манифест не менялись.

`android/build.gradle`:

- удалён `apply plugin: 'de.mannodermaus.android-junit5'` и его classpath;
- удалён `buildscript` с AGP 7.3.1 / KGP 1.7.10 (AGP и Kotlin даёт корневая сборка);
- удалены `testImplementation junit-jupiter` / `assertj-core` (тесты пакета не запускаются);
- `minSdkVersion` 19 → 23 (AGP 9 не поддерживает 19);
- `kotlin-stdlib-jdk7` убран: со Kotlin 2.x stdlib добавляется автоматически;
- убран блок `kotlin { compilerOptions { jvmTarget = JVM_17 } }`: при built-in
  Kotlin AGP `jvmTarget` берётся из `compileOptions` (там уже 17);
- убран условный `if (project.android.hasProperty('namespace'))` — `namespace`
  задан безусловно.

`pubspec.yaml`:

- удалена строка `resolution: workspace` (иначе как path-зависимость пакет
  не резолвится).

Версия пакета по-прежнему `5.3.0`: `pluginClass` и `implements` не менялись.

## Когда снимать вендор

При обновлении `audioplayers` проверить `dart pub deps`:

- если констрейнт на `audioplayers_android` стал `^6.x`, или
- если в `audioplayers_android` больше нет плагина `de.mannodermaus.android-junit5`,

удалить этот каталог и `dependency_overrides` из `pulse_flutter/pubspec.yaml`.
Стабильный 6.x ещё не вышел: 6.0.0-dev.0 тянет dev-каскад
(`audioplayers_platform_interface ^8.0.0-dev`).
