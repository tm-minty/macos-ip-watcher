# Contributing

Thanks for your interest in IPWatch!

## Development

```bash
swift build          # build
make run             # run the menu bar app
```

Building and running the widget:

```bash
make xcode           # open IPWatch.xcodeproj in Xcode
```

`IPWatch.xcodeproj` is committed so it can be built without extra tooling. If you
change the set of files in a target, edit `scripts/generate-xcodeproj.rb`, run
`make xcode-regen` (requires `gem install xcodeproj`), and commit the regenerated
project.

## Guidelines

- Keep the project free of third-party dependencies.
- Match the style of the existing code (Swift, SwiftUI).
- Before opening a PR, make sure the checks pass: `swift build -c release` and
  the Xcode project build (see `.github/workflows/ci.yml`).
- Keep descriptions clear and to the point.

## Ideas

- App icon.
- RU/EN localization.
- Additional geolocation providers.
