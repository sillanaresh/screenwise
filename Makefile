# Screenwise build commands. Run `make help` for the list.
SHELL := /bin/bash
SIM ?= iPhone 17 Pro
# Pick the first installed simulator with this name by its id. "OS:latest" can point at a newer
# iOS version that has no such phone.
comma := ,
lparen := (
SIM_ID ?= $(shell xcrun simctl list devices available 2>/dev/null | grep -m1 -F "    $(SIM) $(lparen)" | grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}')
DESTINATION ?= $(if $(SIM_ID),id=$(SIM_ID),platform=iOS Simulator$(comma)name=$(SIM))
DERIVED := .build/DerivedData
APP_ID := app.screenwise.ios
KIT := Screenwise/Packages/ScreenwiseKit
XCB := xcodebuild -project Screenwise.xcodeproj -scheme Screenwise -derivedDataPath $(DERIVED)

.PHONY: help bootstrap generate build test test-kit test-app test-ui run lint format fixtures colors icon screenshots archive data-check catalogue formats testflight clean

help:
	@echo "make bootstrap   install XcodeGen if needed and generate the Xcode project"
	@echo "make build       build the app for the simulator ($(SIM))"
	@echo "make test        logic tests on the Mac, then app unit tests in the simulator"
	@echo "make test-ui     UI flow tests in the simulator"
	@echo "make run         build, install and launch in the simulator"
	@echo "make lint        check Swift formatting"
	@echo "make fixtures    regenerate fixtures/scoring from ref/score_v2.py"
	@echo "make colors      regenerate the colour tokens in the asset catalog"
	@echo "make icon        redraw the app icon (scripts/gen_icon.py)"
	@echo "make screenshots App Store screenshots on the 6.9 inch iPhone"
	@echo "make catalogue   refresh data/catalogue.json from TMDB (needs TMDB_TOKEN)"
	@echo "make formats     apply data/film_formats.json to the current movie list"
	@echo "make archive     Release archive for the App Store (same as Product, Archive in Xcode)"
	@echo "make testflight  archive and upload to App Store Connect"

bootstrap:
	@command -v xcodegen >/dev/null || brew install xcodegen
	@$(MAKE) generate

generate:
	xcodegen generate --quiet

build: generate
	$(XCB) -destination '$(DESTINATION)' -quiet build

test: test-kit test-app

test-kit:
	cd $(KIT) && swift test

test-app: generate
	$(XCB) -destination '$(DESTINATION)' -only-testing:ScreenwiseTests -quiet test

test-ui: generate
	$(XCB) -destination '$(DESTINATION)' -only-testing:ScreenwiseUITests -quiet test

run: generate
	$(XCB) -destination '$(DESTINATION)' -quiet build
	xcrun simctl boot "$(or $(SIM_ID),$(SIM))" 2>/dev/null || true
	@# Newer Xcode shows simulators in Device Hub. Older Xcode uses the Simulator app.
	open "$$(xcode-select -p)/../Applications/DeviceHub.app" 2>/dev/null || open -a Simulator
	xcrun simctl install booted "$(DERIVED)/Build/Products/Debug-iphonesimulator/Screenwise.app"
	xcrun simctl launch booted $(APP_ID)

lint:
	swift format lint --strict --recursive Screenwise

format:
	swift format --in-place --recursive Screenwise

fixtures:
	python3 scripts/gen_scoring_fixtures.py

icon:
	python3 scripts/gen_icon.py

screenshots: build
	scripts/screenshots.sh

colors:
	python3 scripts/gen_colors.py

data-check: test-kit

catalogue:
	@# Reads TMDB_TOKEN from the environment, or from the private .env file (never committed).
	@set -a; [ -f .env ] && . ./.env; set +a; \
	test -n "$$TMDB_TOKEN" || (echo "Set TMDB_TOKEN to your TMDB API Read Access Token" && exit 1); \
	node scripts/catalogue/sync.mjs

# Archive and upload to App Store Connect for TestFlight. Needs your Apple ID in Xcode
# (Settings, then Accounts) and the app record in App Store Connect. Raise CURRENT_PROJECT_VERSION
# in project.yml before each new upload. You can do the same from Xcode: Product, then Archive.
archive: generate
	$(XCB) -configuration Release -destination 'generic/platform=iOS' -archivePath .build/Screenwise.xcarchive \
		-allowProvisioningUpdates archive

testflight: archive
	xcodebuild -exportArchive -archivePath .build/Screenwise.xcarchive -exportPath .build/export \
		-exportOptionsPlist scripts/ExportOptions.plist -allowProvisioningUpdates

formats:
	node scripts/catalogue/sync.mjs --formats-only

clean:
	rm -rf .build Screenwise.xcodeproj $(KIT)/.build
