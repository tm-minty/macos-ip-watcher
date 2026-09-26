APP := IPWatch

.PHONY: build run app app-universal share xcode xcode-build clean

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
	ruby scripts/generate-xcodeproj.rb

xcode-build: xcode
	xcodebuild -project IPWatch.xcodeproj -scheme IPWatch -configuration Release \
		-derivedDataPath .build/xcode -allowProvisioningUpdates build

clean:
	rm -rf .build dist IPWatch.xcodeproj
