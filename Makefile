APP_NAME = Reframed
SCHEME = Reframed
ARCH = $(shell uname -m)
DESTINATION = platform=macOS,arch=$(ARCH)
BUILD_DIR = .build
VERSION = $(shell grep MARKETING_VERSION Config.xcconfig | cut -d'=' -f2 | tr -d ' ')
RELEASE_DIR = $(BUILD_DIR)/Build/Products/Release
DEBUG_DIR = $(BUILD_DIR)/Build/Products/Debug

.PHONY: build release run dev dmg dmg-release format clean help install uninstall changelog tag appcast publish

all: help

build:
	@xcodebuild -project Reframed.xcodeproj -scheme $(SCHEME) -configuration Debug build -quiet -derivedDataPath $(BUILD_DIR) -destination '$(DESTINATION)'

release:
	@xcodebuild -project Reframed.xcodeproj -scheme $(SCHEME) -configuration Release build -quiet -derivedDataPath $(BUILD_DIR) -destination 'generic/platform=macOS' ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO

run: release
	@open $(RELEASE_DIR)/$(APP_NAME).app

dev: build
	@open $(DEBUG_DIR)/$(APP_NAME).app

dmg: release
	@./scripts/create-dmg.sh

dmg-release: release
	@./scripts/create-dmg.sh --sign "$(REFRAMED_SIGNING_IDENTITY)" --notarize

install: uninstall release
	@cp -rf $(RELEASE_DIR)/$(APP_NAME).app /Applications/

uninstall:
	@rm -rf /Applications/$(APP_NAME).app

tag:
	@if git rev-parse "v$(VERSION)" >/dev/null 2>&1; then \
		echo "Tag v$(VERSION) already exists"; exit 1; \
	fi
	@git tag -a "v$(VERSION)" -m "v$(VERSION)"
	@echo "Created tag v$(VERSION)"
	@$(MAKE) changelog

changelog:
	@./scripts/changelog.sh --unreleased

appcast:
	@./scripts/generate-appcast.sh

publish: tag dmg-release appcast
	@./scripts/publish-release.sh

format:
	@swift format -i -r Reframed/

clean:
	@rm -rf $(BUILD_DIR) dist

help:
	@echo "Reframed Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build     - Build debug version"
	@echo "  release   - Build release version"
	@echo "  dmg         - Create .dmg installer"
	@echo "  dmg-release - Create signed and notarized .dmg installer"
	@echo "  install   - Install to /Applications"
	@echo "  uninstall - Remove from /Applications"
	@echo "  run       - Build release and run"
	@echo "  dev       - Build debug and run"
	@echo "  format    - Format Swift source files"
	@echo "  clean     - Clean build artifacts"
	@echo "  tag       - Create git tag from Config.xcconfig version and generate changelog"
	@echo "  changelog - Generate CHANGELOG.md"
	@echo "  appcast   - Generate appcast.xml for Sparkle updates"
	@echo "  publish   - Full release: tag + dmg-release + appcast"
	@echo "  help      - Show this help"
