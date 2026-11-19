# Screenwise build commands. Run `make help` for the list.
SHELL := /bin/bash
SIM ?= iPhone 17 Pro
DESTINATION ?= platform=iOS Simulator,name=$(SIM)
DERIVED := .build/DerivedData
APP_ID := app.screenwise.ios
KIT := Screenwise/Packages/ScreenwiseKit
XCB := xcodebuild -project Screenwise.xcodeproj -scheme Screenwise -derivedDataPath $(DERIVED)

.PHONY: help bootstrap generate build test test-kit test-app test-ui run lint format fixtures colors data-check catalogue testflight clean

help:
	@echo "make bootstrap   install XcodeGen if needed and generate the Xcode project"
	@echo "make build       build the app for the simulator ($(SIM))"
	@echo "make test        logic tests on the Mac, then app unit tests in the simulator"
	@echo "make test-ui     UI flow tests in the simulator"
	@echo "make run         build, install and launch in the simulator"
	@echo "make lint        check Swift formatting"
	@echo "make fixtures    regenerate fixtures/scoring from ref/score_v2.py"
	@echo "make colors      regenerate the colour tokens in the asset catalog"
	@echo "make catalogue   refresh data/catalogue.json from TMDB (needs TMDB_TOKEN)"
	@echo "make testflight  archive and upload (needs TEAM_ID)"

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
	xcrun simctl boot "$(SIM)" 2>/dev/null || true
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

colors:
	python3 scripts/gen_colors.py

data-check: test-kit

catalogue:
	@# Reads TMDB_TOKEN from the environment, or from the private .env file (never committed).
	@set -a; [ -f .env ] && . ./.env; set +a; \
	test -n "$$TMDB_TOKEN" || (echo "Set TMDB_TOKEN to your TMDB API Read Access Token" && exit 1); \
	node scripts/catalogue/sync.mjs

testflight: generate
	@test -n "$(TEAM_ID)" || (echo "Set TEAM_ID to your Apple Developer team id (open question 4)" && exit 1)
	$(XCB) -configuration Release -destination 'generic/platform=iOS' -archivePath .build/Screenwise.xcarchive \
		DEVELOPMENT_TEAM=$(TEAM_ID) archive
	xcodebuild -exportArchive -archivePath .build/Screenwise.xcarchive -exportPath .build/export \
		-exportOptionsPlist scripts/ExportOptions.plist -allowProvisioningUpdates DEVELOPMENT_TEAM=$(TEAM_ID)

clean:
	rm -rf .build Screenwise.xcodeproj $(KIT)/.build
