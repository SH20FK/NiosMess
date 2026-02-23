# Flutter (Android) skeleton for NiosMess

Это базовый каркас под нативный Flutter‑клиент. Дальше наполняем экраны и API.

## 1) Предварительно
- Flutter SDK установлен
- Android Studio / Android SDK

## 2) Настроить пакет
Пакет уже указан: `com.niosmess.app`

## 3) Подключить Firebase (push)
Пока код зависимостей есть, но FCM не сконфигурирован.
Когда будешь готов:
1. Создай Firebase project
2. Добавь Android app с package `com.niosmess.app`
3. Скачай `google-services.json`
4. Положи в `niosmess_flutter/android/app/google-services.json`
5. Добавь в `android/build.gradle` и `android/app/build.gradle` плагины (я могу сделать)

## 4) API base
Используем `https://web.sa2rn.fun` (переключатель dev/prod добавим позже)

## 5) Команды
```
cd f:\NiosMess\niosmess_flutter
flutter pub get
flutter run
```

## 6) Следующие шаги
- сделать полноценный роутинг
- реализовать API клиент (dio)
- авторизация, чаты, сообщения
- оффлайн кеш (предлагаю Isar или Drift)
- push + background sync

Если хочешь — я продолжу и начну перенос UI/логики по экранам.
