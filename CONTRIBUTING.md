# Contributing

Thanks for your interest in IPWatch!

## Разработка

```bash
swift build          # сборка
make run             # запуск меню-бар приложения
```

Сборка и запуск виджета:

```bash
make xcode           # сгенерировать IPWatch.xcodeproj
open IPWatch.xcodeproj
```

`IPWatch.xcodeproj` генерируется скриптом `scripts/generate-xcodeproj.rb` и не
хранится в репозитории. Если меняете состав файлов таргетов, правьте скрипт, а не
проект в Xcode.

## Правила

- Держите проект без сторонних зависимостей.
- Соблюдайте стиль существующего кода (Swift, SwiftUI).
- Перед PR убедитесь, что проходят проверки: `swift build -c release` и сборка
  Xcode-проекта (см. `.github/workflows/ci.yml`).
- Описывайте изменения понятно и по делу.

## Идеи

- Иконка приложения.
- Локализация RU/EN.
- Дополнительные провайдеры геолокации.
