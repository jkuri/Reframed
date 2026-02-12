.PHONY: build run dmg format clean help install uninstall dev

all: help

release:
	$(eval ARCH := $(shell uname -m))
	$(eval DEVELOPMENT_TEAM := $(shell xcodebuild -quiet -scheme Frame -destination "platform=macOS,arch=$(ARCH)" -showBuildSettings 2>/dev/null | awk -F' = ' '/DEVELOPMENT_TEAM =/ {print $$2}' | tail -1))
	@xcodebuild -scheme Frame -configuration Release build -quiet CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) -derivedDataPath .build -destination 'platform=macOS,arch=$(ARCH)'

build:
	$(eval ARCH := $(shell uname -m))
	$(eval DEVELOPMENT_TEAM := $(shell xcodebuild -quiet -scheme Frame -destination "platform=macOS,arch=$(ARCH)" -showBuildSettings 2>/dev/null | awk -F' = ' '/DEVELOPMENT_TEAM =/ {print $$2}' | tail -1))
	@xcodebuild -scheme Frame -configuration Debug build -quiet CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) CODE_SIGN_IDENTITY="Apple Development" -derivedDataPath .build -destination 'platform=macOS,arch=$(ARCH)'

run: release
	@open .build/Build/Products/Release/Frame.app

dev: build
	@open .build/Build/Products/Debug/Frame.app

dmg: release
	@./scripts/create-dmg.sh

install: uninstall release
	@cp -rf .build/Build/Products/Release/Frame.app /Applications/

uninstall:
	@rm -rf /Applications/Frame.app

format:
	@swift format -i -r Frame/

clean:
	@rm -rf .build dist

help:
	@echo "Frame Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build     - Build debug version"
	@echo "  release   - Build release version (default)"
	@echo "  dmg       - Create .dmg installer"
	@echo "  install   - Install to /Applications"
	@echo "  uninstall - Remove from /Applications"
	@echo "  run       - Build and run the app"
	@echo "  dev       - Run in dev mode"
	@echo "  format    - Format Swift source files"
	@echo "  clean     - Clean build artifacts"
	@echo "  help      - Show this help"
