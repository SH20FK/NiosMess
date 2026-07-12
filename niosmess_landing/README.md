# NiosMess Landing Page

## Stack

- **Next.js** (App Router) — SSR, routing
- **Framer Motion** — scroll-driven animations
- **Tailwind CSS** — styling

## Development

```bash
npm run dev
```

## Скриншоты

Текущие скриншоты в `public/screens/` — цветные заглушки. Чтобы заменить на реальные:

### Способ 1: Интеграционный тест

```bash
cd ../pulse_flutter
flutter test integration_test/screenshots_test.dart
```

Скриншоты сохранятся в `../niosmess_landing/public/screens/`.

### Способ 2: Вручную (через emulator)

```bash
cd ../pulse_flutter
# Запусти приложение
flutter run
# В другом терминале, пока открыт нужный экран:
adb exec-out screencap -p > ../niosmess_landing/public/screens/shot-chats.png
```

## Структура

```
src/
  app/          — страницы
  components/   — PhoneMockup, ScrollGallery
  data/         — конфиг слайдов
public/
  screens/      — PNG скриншоты 540×1170
  logo.svg      — логотип NiosMess
```
