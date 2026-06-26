# WaterParty Makefile
# Centralized build and release tool for Human Connection OS

SERVER_DIR = server
SERVER_BINARY = partyserver
VERSION = $(shell grep '^version:' pubspec.yaml | sed 's/version: //' | tr -d ' ')
GO_BUILD_FLAGS = -ldflags="-s -w" -trimpath

.PHONY: all build build-server build-app build-app-native release release-server release-app install-deps clean build-linux build-android build-android-arm64 build-android-armv7 build-android-x86 build-android-x86_64 build-android-all build-web build-macos test test-server

all: build

# --- Dependencies ---
install-deps:
	@echo "--- Installing Dependencies ---"
	flutter pub get
	cd $(SERVER_DIR) && go mod download

# --- Testing ---
test: test-server

test-server:
	@echo "--- Running Go Server Tests ---"
	cd $(SERVER_DIR) && go test -v -cover ./...

# Detect OS for native app build
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
  NATIVE_APP_TARGET = build-linux
endif
ifeq ($(UNAME_S),Darwin)
  NATIVE_APP_TARGET = build-macos
endif

# --- Build ---
# 'make build' now only builds for the current platform
build: install-deps build-server build-app-native

build-server:
	@echo "--- Building Optimized Go Server (Native) ---"
	cd $(SERVER_DIR) && go build $(GO_BUILD_FLAGS) -o $(SERVER_BINARY) .

build-app-native: $(NATIVE_APP_TARGET)

build-app: build-android build-linux build-web build-macos

build-android:
	@echo "--- Building Android APKs (Universal + ABI Specific) ---"
	flutter build apk --release --obfuscate --split-debug-info=./debug-info
	flutter build apk --release --split-per-abi --obfuscate --split-debug-info=./debug-info

build-aab:
	@echo "--- Building Android App Bundle ---"
	flutter build appbundle --release --obfuscate --split-debug-info=./debug-info

# Android architecture-specific builds
build-android-arm64:
	@echo "--- Building Android ARM64 APK ---"
	flutter build apk --release --target-platform android-arm64 --obfuscate --split-debug-info=./debug-info

build-android-armv7:
	@echo "--- Building Android ARMv7 APK ---"
	flutter build apk --release --target-platform android-arm --obfuscate --split-debug-info=./debug-info

build-android-x86:
	@echo "--- Building Android x86 APK ---"
	flutter build apk --release --target-platform android-x86 --obfuscate --split-debug-info=./debug-info

build-android-x86_64:
	@echo "--- Building Android x86_64 APK ---"
	flutter build apk --release --target-platform android-x64 --obfuscate --split-debug-info=./debug-info

# Build all Android architectures
build-android-all: build-android-arm64 build-android-armv7 build-android-x86 build-android-x86_64

build-ios:
	@echo "--- Building iOS (No-Codesign) ---"
	flutter build ios --release --no-codesign

build-linux:
	@echo "--- Building Linux Bundle ---"
	flutter config --enable-linux-desktop
	flutter build linux --release --obfuscate --split-debug-info=./debug-info
	find build/linux/x64/release/bundle/ -maxdepth 1 -type f -executable -exec strip {} +

build-macos:
	@echo "--- Building macOS Bundle ---"
	flutter config --enable-macos-desktop
	flutter build macos --release --obfuscate --split-debug-info=./debug-info

build-web:
	@echo "--- Building Web Artifacts ---"
	flutter build web --release

# --- Release ---
release: release-server release-app

release-server: 
	@echo "--- Releasing Optimized Server (Multi-Platform Binaries) ---"
	mkdir -p release/server
	# Linux 64-bit
	cd $(SERVER_DIR) && GOOS=linux GOARCH=amd64 go build $(GO_BUILD_FLAGS) -o ../release/server/$(SERVER_BINARY)-linux-amd64 .
	# Linux ARM64
	cd $(SERVER_DIR) && GOOS=linux GOARCH=arm64 go build $(GO_BUILD_FLAGS) -o ../release/server/$(SERVER_BINARY)-linux-arm64 .
	# Windows 64-bit
	cd $(SERVER_DIR) && GOOS=windows GOARCH=amd64 go build $(GO_BUILD_FLAGS) -o ../release/server/$(SERVER_BINARY)-windows-amd64.exe .
	# macOS 64-bit (Intel)
	cd $(SERVER_DIR) && GOOS=darwin GOARCH=amd64 go build $(GO_BUILD_FLAGS) -o ../release/server/$(SERVER_BINARY)-darwin-amd64 .
	# macOS ARM64 (Apple Silicon)
	cd $(SERVER_DIR) && GOOS=darwin GOARCH=arm64 go build $(GO_BUILD_FLAGS) -o ../release/server/$(SERVER_BINARY)-darwin-arm64 .
	@echo "Optimized server binaries ready in release/server/"

release-app: build-android build-aab build-linux build-web
	@echo "--- Packaging App for Release v$(VERSION) ---"
	mkdir -p release/app
	# Android APKs
	cp build/app/outputs/flutter-apk/app-release.apk release/app/WaterParty-Universal.apk || true
	cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk release/app/WaterParty-Android-arm64.apk || true
	# Android AAB
	cp build/app/outputs/bundle/release/app-release.aab release/app/WaterParty.aab || true
	# Linux
	tar -czvf release/app/WaterParty-Linux.tar.gz -C build/linux/x64/release/bundle . || true
	# Web
	cd build/web && zip -r ../../release/app/WaterParty-Web.zip . || true
	@echo "App artifacts ready in release/app/"

# Dev Release: Android arm64 APK + Server Linux x64
release-dev: release-dev-app release-dev-server

release-dev-app:
	@echo "--- Building Dev App (ARM64 APK) - Fast Mode ---"
	mkdir -p release/dev
	flutter build apk --release --target-platform android-arm64
	cp build/app/outputs/flutter-apk/app-release.apk release/dev/WaterParty-Dev-arm64.apk || true

release-dev-server:
	@echo "--- Building Dev Server (Linux x64) ---"
	mkdir -p release/dev
	cd $(SERVER_DIR) && GOOS=linux GOARCH=amd64 go build $(GO_BUILD_FLAGS) -o ../release/dev/$(SERVER_BINARY)-dev-linux-amd64 .

clean:
	@echo "--- Cleaning Build Artifacts ---"
	flutter clean
	rm -rf build/
	rm -rf release/
	rm -f $(SERVER_DIR)/$(SERVER_BINARY)
