# IPWatch

[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-black)](#requirements)
[![Swift](https://img.shields.io/badge/swift-5.9-orange)](#requirements)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![CI](https://github.com/tm-minty/macos-ip-watcher/actions/workflows/ci.yml/badge.svg)](https://github.com/tm-minty/macos-ip-watcher/actions/workflows/ci.yml)

IPWatch is a native macOS menu bar app and Notification Center widget that shows
your external IP address, the country flag and whether a VPN/proxy is active.
No third-party dependencies — SwiftUI + `MenuBarExtra` + WidgetKit.

## Features

- Country flag and external IP right in the menu bar (each part can be toggled).
- Popover details: country/city, region, timezone, ISP, organization, ASN, the
  active network interface and tunnel interfaces.
- **VPN status** — compares the current IP/country against a saved "home" network
  and independently inspects network interfaces:
  - `Direct connection` — matches the home IP, no tunnel;
  - `IP changed (same country)` — different IP, same country;
  - `Tunnel active (utunN)` — a tunnel interface is up (VPN/proxy) even if the IP has not changed yet;
  - `VPN / proxy likely` — the country changed (a strong VPN/proxy signal).
- **Event-driven updates**: besides the timer, the IP is re-fetched immediately
  when the network configuration changes — VPN connect/disconnect, route changes,
  Wi-Fi switching, etc. (the `Refresh on VPN / network change` toggle).
- **Notification Center widget** (click the clock): flag, IP, country, ISP, VPN
  status and a refresh button.
- Buttons: refresh, set the current network as home, copy the IP, open details in
  the browser.
- Settings: refresh interval, what to show in the menu bar, launch at login,
  refresh on network events.

## Requirements

- macOS 13+ (the widget needs macOS 14+).
- Xcode Command Line Tools to build the menu bar app.
- Full Xcode to build the widget extension.

The Xcode project (`IPWatch.xcodeproj`) is committed, so no extra tooling is
required. Regenerating it is optional and only for maintainers (see below).

## Quick start

```bash
git clone https://github.com/tm-minty/macos-ip-watcher.git
cd macos-ip-watcher

# menu bar app (without the widget)
make app
open dist/IPWatch.app
```

The app appears in the menu bar (there is no Dock icon). Open the popover and
click **Set as home** to remember your home network — after that the app will
signal IP/country changes.

Self-check from the terminal:

```bash
dist/IPWatch.app/Contents/MacOS/IPWatch --probe
# -> 🇸🇪 203.0.113.1 | Sweden | SomeISP | via ip-api.com
# -> network: tunnel utun4 up | primary=utun4 | vpn=utun4
```

Run without packaging into a `.app` (for development):

```bash
make run
```

## Notification Center widget (click the clock)

Clicking the clock opens Notification Center, which only accepts WidgetKit
widgets, so the project includes the `IPWatchWidget` extension. It is built
through an Xcode project (Swift Package Manager cannot produce an `.appex`).

```bash
make xcode          # open IPWatch.xcodeproj in Xcode
make xcode-build    # build the app + widget with xcodebuild
```

Or in Xcode: open `IPWatch.xcodeproj`, pick your Team for both targets
(**IPWatch** and **IPWatchWidget**) and press Run.

Install and add the widget:

```bash
# build a signed build (set your TEAM_ID) and copy it to /Applications
xcodebuild -project IPWatch.xcodeproj -scheme IPWatch -configuration Release \
  -derivedDataPath .build/xcode -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=<TEAM_ID> build
cp -R .build/xcode/Build/Products/Release/IPWatch.app /Applications/
open /Applications/IPWatch.app
```

Then **click the clock → "Edit Widgets" → find `External IP` → add it to
Notification Center**. The widget appears in the gallery once the app has been
launched from `/Applications` at least once.

Widget notes:

- The system controls refresh cadence (usually no more than every ~15 minutes);
  the refresh button forces an immediate re-fetch.
- Sharing the "home" network between the app and the widget uses the App Group
  `group.com.local.ipwatch`. Enable the **App Groups** capability on both targets
  and sign them together (this requires a paid Apple Developer account; a Personal
  Team may not support App Groups). Without the App Group the widget still detects
  a tunnel from the network interfaces, but does not compare against the home
  network.

## How VPN detection works

Two independent signals:

1. **By external IP** — comparing the country/IP against the saved home network.
2. **By network configuration** — reading the system dynamic store
   (`State:/Network/Global/IPv4` → `PrimaryInterface`) and the interface list via
   `getifaddrs`. If the default route or the actively used interface is named like
   `utun*/ppp*/ipsec*/tun*/tap*/wg*`, a tunnel is considered active.

Events come from two sources: `SCDynamicStore` (system configuration
notifications) and `NWPathMonitor` (Network framework). Changes are debounced
(~1.2 s) and trigger an immediate IP re-fetch without waiting for the timer.

## Data sources

1. **ip-api.com** (primary) — the free tier serves data over HTTP only, so an ATS
   exception for the `ip-api.com` domain is added in `Resources/Info.plist`.
2. **ipwho.is** (HTTPS) — automatic fallback when the primary source is
   unavailable.

## Launch at login

Turn on the **Launch at login** toggle in the popover — it uses `SMAppService`.
It works most reliably when the `.app` lives in `/Applications` or another stable
location (`~/Applications`).

## Distribution

The app and widget are ad-hoc signed — recipients do not need your Apple ID:

```bash
make share
# -> dist/IPWatch.app.zip         universal (arm64 + x86_64)
# -> dist/IPWatch-arm64.app.zip   Apple Silicon only
# -> dist/IPWatch-amd64.app.zip   Intel only
#    plus a .sha256 checksum for each
```

Recipient:

```bash
unzip IPWatch.app.zip
xattr -dr com.apple.quarantine IPWatch.app   # clear the ad-hoc quarantine flag
open IPWatch.app
```

If macOS still blocks it: **System Settings → Privacy & Security → "Open Anyway"**.

Warning-free public distribution requires a **Developer ID Application**
certificate and notarization (`xcodebuild archive` → `notarytool submit` →
`stapler staple`). Sandboxing is only required for the Mac App Store.

## Project structure

```
Sources/IPWatch/                 menu bar app (SwiftPM target)
  IPWatchApp.swift               @main, MenuBarExtra, --probe mode
  AppState.swift                 state, timer, network events, launch at login
  NetworkMonitor.swift           VPN/route monitoring (SCDynamicStore + NWPathMonitor)
  IPService.swift                ip-api.com request with ipwho.is fallback
  Models.swift                   IPInfo model, emoji flag, VPN status
  SharedStore.swift              shared storage (App Group) for app + widget
  ContentView.swift              popover UI
Widget/                          WidgetKit extension (Xcode target)
  IPWatchWidgetBundle.swift      @main WidgetBundle
  IPWatchWidget.swift            widget, timeline provider, layout
  RefreshIntent.swift            interactive refresh button
  Info.plist, *.entitlements
Resources/Info.plist             LSUIElement + ATS exception
IPWatch.xcodeproj                Xcode project (committed)
scripts/build-app.sh             build the .app bundle (SwiftPM)
scripts/generate-xcodeproj.rb    regenerate IPWatch.xcodeproj (maintainers only)
scripts/package-adhoc.sh         ad-hoc build + universal/arch zips for sharing
scripts/package-arch.sh          thin per-architecture (arm64/amd64) zips
```

The Xcode project is committed so it can be opened and built without any extra
tooling. If you change the set of files in a target, edit
`scripts/generate-xcodeproj.rb` and run `make xcode-regen` (requires
`gem install xcodeproj`), then commit the regenerated project.

## License

[MIT](LICENSE) © 2026 Timur Mingaliev
