APP := IPWatch

.PHONY: build run app app-universal share xcode xcode-build xcode-regen screenshots clean

build:
	swift build -c release

run:
	swift run -c release

app:
	./scripts/build-app.sh release native

app-universal:
	./scripts/build-app.sh release universal

share:
	./scripts/package-adhoc.sh

xcode:
	open IPWatch.xcodeproj

xcode-build:
	xcodebuild -project IPWatch.xcodeproj -scheme IPWatch -configuration Release \
		-derivedDataPath .build/xcode \
		CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" PROVISIONING_PROFILE_SPECIFIER="" build

xcode-regen:
	ruby scripts/generate-xcodeproj.rb

screenshots:
	./scripts/make-screenshots.sh

clean:
	rm -rf .build dist
