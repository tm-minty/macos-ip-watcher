# IPWatch

[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-black)](#requirements)
[![Swift](https://img.shields.io/badge/swift-5.9-orange)](#requirements)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![CI](https://github.com/tm-minty/macos-ip-watcher/actions/workflows/ci.yml/badge.svg)](https://github.com/tm-minty/macos-ip-watcher/actions/workflows/ci.yml)

**EN** — IPWatch is a native macOS menu bar app and Notification Center widget
that shows your external IP address, the country flag and whether a VPN/proxy is
active. No third-party dependencies, SwiftUI + `MenuBarExtra` + WidgetKit.

**RU** — IPWatch — нативное приложение в строке меню macOS и виджет для Центра
уведомлений: внешний IP, флаг страны и статус VPN.

## Возможности

- Флаг страны и внешний IP прямо в строке меню (каждую часть можно отключить).
- В поповере: страна/город, регион, таймзона, провайдер (ISP), организация, ASN,
  активный сетевой интерфейс и туннельные интерфейсы.
- **Статус VPN** — сравнение текущего IP/страны с сохранённой «домашней» сетью
  плюс независимая проверка сетевых интерфейсов:
  - `Direct connection` — совпадает с домашним IP, туннеля нет;
  - `IP changed (same country)` — IP другой, страна та же;
  - `Tunnel active (utunN)` — туннельный интерфейс поднят (VPN/прокси), даже если IP пока не сменился;
  - `VPN / proxy likely` — страна сменилась (сильный признак VPN/прокси).
- **Событийное обновление**: помимо таймера, IP перезапрашивается сразу при
  изменении сетевой конфигурации — подключение/отключение VPN, смена маршрута,
  переход между Wi-Fi и т.д. (тумблер `Refresh on VPN / network change`).
- **Виджет для Центра уведомлений** (клик по часам): флаг, IP, страна, ISP, статус
  VPN и кнопка обновления.
- Кнопки: обновить, сохранить текущую сеть как домашнюю, скопировать IP, открыть
  детали в браузере.
- Настройки: интервал автообновления, что показывать в строке меню, автозапуск
  при входе, обновление по событиям сети.

## Требования

- macOS 13+ (виджет — macOS 14+).
- Xcode Command Line Tools для сборки приложения.
- Полный Xcode для сборки widget-расширения.
- Ruby и гем `xcodeproj` для генерации Xcode-проекта:
  `gem install xcodeproj`.

## Быстрый старт

```bash
git clone https://github.com/tm-minty/macos-ip-watcher.git
cd macos-ip-watcher

# меню-бар приложение (без виджета)
make app
open dist/IPWatch.app
```

Приложение появится в строке меню (иконки в Dock не будет). Откройте поповер и
нажмите **Set as home**, чтобы зафиксировать домашнюю сеть — после этого проект
начнёт сигнализировать о смене IP/страны.

Проверка сети из терминала:

```bash
dist/IPWatch.app/Contents/MacOS/IPWatch --probe
# -> 🇸🇪 203.0.113.1 | Sweden | SomeISP | via ip-api.com
# -> network: tunnel utun4 up | primary=utun4 | vpn=utun4
```

Запуск без упаковки в `.app` (для разработки):

```bash
make run
```

## Виджет в Центре уведомлений (клик по часам)

Клик по часам открывает Центр уведомлений, куда добавляются только
WidgetKit-виджеты, поэтому в проекте есть extension `IPWatchWidget`. Он собирается
через Xcode-проект (Swift Package Manager `.appex` не собирает).

```bash
make xcode          # сгенерировать IPWatch.xcodeproj
make xcode-build    # собрать app + widget с автоматической подписью
```

Либо в Xcode: откройте `IPWatch.xcodeproj`, в обоих таргетах (**IPWatch** и
**IPWatchWidget**) выберите свою Team и нажмите Run.

Установка и добавление:

```bash
# собрать подписанный билд (укажите свой TEAM_ID) и положить в /Applications
DEVELOPMENT_TEAM=<TEAM_ID> ruby scripts/generate-xcodeproj.rb
xcodebuild -project IPWatch.xcodeproj -scheme IPWatch -configuration Release \
  -derivedDataPath .build/xcode -allowProvisioningUpdates build
cp -R .build/xcode/Build/Products/Release/IPWatch.app /Applications/
open /Applications/IPWatch.app
```

Затем **клик по часам → «Изменить виджеты» → найти `External IP` → добавить в
Центр уведомлений**. Виджет появляется в галерее после того, как приложение хотя
бы раз запущено из `/Applications`.

Особенности виджета:

- Обновление регулирует система (обычно не чаще ~15 минут); кнопка обновления
  форсирует перезапрос.
- Сравнение с «домашней» сетью между приложением и виджетом работает через
  App Group `group.com.local.ipwatch`. Включите capability **App Groups** у обоих
  таргетов и подпишите одной командой (нужен платный Apple Developer; Personal
  Team может не поддерживать App Groups). Без App Group виджет тоже определяет
  туннель по сетевым интерфейсам, но не сравнивает с домашней сетью.

## Как определяется VPN

Два независимых сигнала:

1. **По внешнему IP** — сравнение страны/IP с сохранённой домашней сетью.
2. **По сетевой конфигурации** — читается системный dynamic store
   (`State:/Network/Global/IPv4` → `PrimaryInterface`) и список интерфейсов через
   `getifaddrs`. Если default-route или активно используемый интерфейс имеет имя
   вида `utun*/ppp*/ipsec*/tun*/tap*/wg*`, туннель считается активным.

События приходят из двух источников: `SCDynamicStore` (уведомления системной
конфигурации) и `NWPathMonitor` (Network framework). Изменения дебаунсятся
(~1.2 c) и запускают немедленный перезапрос IP, не дожидаясь таймера.

## Источники данных

1. **ip-api.com** (основной) — бесплатный тариф отдаёт данные только по HTTP,
   поэтому в `Resources/Info.plist` добавлено ATS-исключение для домена
   `ip-api.com`.
2. **ipwho.is** (HTTPS) — автоматический резерв, если основной источник недоступен.

## Автозапуск

Включите тумблер **Launch at login** в поповере — используется `SMAppService`.
Надёжнее всего работает, если `.app` лежит в `/Applications` или в стабильном
месте (`~/Applications`).

## Распространение

Приложение и виджет подписываются ad-hoc — получателям не нужен ваш Apple ID:

```bash
make share          # -> dist/IPWatch.app.zip (app + widget, ad-hoc)
```

Получатель:

```bash
unzip IPWatch.app.zip
xattr -dr com.apple.quarantine IPWatch.app   # снять карантин ad-hoc подписи
open IPWatch.app
```

Если macOS блокирует запуск: **Системные настройки → Конфиденциальность и
безопасность → «Всё равно открыть»**.

Для публичной раздачи без предупреждений Gatekeeper нужен сертификат
**Developer ID Application** и нотаризация (`xcodebuild archive` → `notarytool
submit` → `stapler staple`). Песочница обязательна только для Mac App Store.

## Структура

```
Sources/IPWatch/                 меню-бар приложение (SwiftPM target)
  IPWatchApp.swift               @main, MenuBarExtra, режим --probe
  AppState.swift                 состояние, таймер, события сети, автозапуск
  NetworkMonitor.swift           мониторинг VPN/маршрутов (SCDynamicStore + NWPathMonitor)
  IPService.swift                запрос к ip-api.com с фолбэком на ipwho.is
  Models.swift                   модель IPInfo, эмодзи-флаг, статус VPN
  SharedStore.swift              общее хранилище (App Group) для app + widget
  ContentView.swift              интерфейс поповера
Widget/                          WidgetKit extension (Xcode target)
  IPWatchWidgetBundle.swift      @main WidgetBundle
  IPWatchWidget.swift            виджет, timeline provider, вёрстка
  RefreshIntent.swift            interactive-кнопка обновления
  Info.plist, *.entitlements
Resources/Info.plist             LSUIElement + ATS-исключение
scripts/build-app.sh             сборка .app-бандла (SwiftPM)
scripts/generate-xcodeproj.rb    генерация IPWatch.xcodeproj (app + widget)
scripts/package-adhoc.sh         ad-hoc сборка + zip для раздачи
```

## Лицензия

[MIT](LICENSE) © 2026 Timur Mingaliev
