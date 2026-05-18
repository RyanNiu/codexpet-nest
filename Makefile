SDK_PATH := $(shell xcrun --show-sdk-path)
SWIFTC := swiftc
BUILD_DIR := .build
EXEC_DEBUG := $(BUILD_DIR)/CodexPetNest-Debug
EXEC_RELEASE := $(BUILD_DIR)/CodexPetNest
APP_NAME := CodexPet Nest
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
FRAMEWORKS_SRC := Frameworks
APP_VERSION := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
BUILD_VERSION := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Resources/Info.plist)
DMG_NAME := $(APP_NAME)-$(APP_VERSION).dmg
DMG_VOLUME_NAME := $(APP_NAME) $(APP_VERSION)

GEN_VERSION_FILE := $(BUILD_DIR)/AppBuildInfo.swift

# Signing configuration
CODESIGN_IDENTITY ?= -

SOURCES := $(shell find Sources -name '*.swift')

all: $(EXEC_DEBUG)

$(GEN_VERSION_FILE): Resources/Info.plist
	@mkdir -p $(BUILD_DIR)
	@echo "enum AppBuildInfo {" > $@
	@echo "    static let marketingVersion = \"$(APP_VERSION)\"" >> $@
	@echo "    static let buildVersion = \"$(BUILD_VERSION)\"" >> $@
	@echo "}" >> $@

$(EXEC_DEBUG): $(SOURCES) $(GEN_VERSION_FILE)
	@mkdir -p $(BUILD_DIR)
	$(SWIFTC) \
		-sdk $(SDK_PATH) \
		-framework AppKit \
		-framework Security \
		-framework Foundation \
		-F $(FRAMEWORKS_SRC) \
		-framework Sparkle \
		-Xlinker -rpath -Xlinker @executable_path/../Frameworks \
		-D DEBUG \
		-o $@ \
		$(SOURCES) $(GEN_VERSION_FILE)

debug: $(EXEC_DEBUG)

$(EXEC_RELEASE): $(SOURCES) $(GEN_VERSION_FILE)
	@mkdir -p $(BUILD_DIR)
	$(SWIFTC) -O \
		-sdk $(SDK_PATH) \
		-framework AppKit \
		-framework Security \
		-framework Foundation \
		-F $(FRAMEWORKS_SRC) \
		-framework Sparkle \
		-Xlinker -rpath -Xlinker @executable_path/../Frameworks \
		-o $@ \
		$(SOURCES) $(GEN_VERSION_FILE)

release: $(EXEC_RELEASE)

app: release
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Frameworks"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources/BundledNests"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources/BundledPets"
	@cp $(EXEC_RELEASE) "$(APP_BUNDLE)/Contents/MacOS/CodexPetNest"
	@cp -R $(FRAMEWORKS_SRC)/Sparkle.framework "$(APP_BUNDLE)/Contents/Frameworks/"
	@cp Resources/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	@cp Resources/CodexPetNest.icns "$(APP_BUNDLE)/Contents/Resources/CodexPetNest.icns"
	@cp Resources/MenuBarIconTemplate*.png "$(APP_BUNDLE)/Contents/Resources/"
	@cp -R docs/test-fixtures/nests-v1.1/basket-pomodoro-nest "$(APP_BUNDLE)/Contents/Resources/BundledNests/"
	@cp -R docs/test-fixtures/nests-v1.1/legend-status-nest "$(APP_BUNDLE)/Contents/Resources/BundledNests/"
	@cp -R docs/test-fixtures/nests-v1.1/window-desk-nest "$(APP_BUNDLE)/Contents/Resources/BundledNests/"
	@cp -R docs/test-fixtures/nests-v1.1/quick-actions-demo-nest "$(APP_BUNDLE)/Contents/Resources/BundledNests/"
	@cp -R docs/test-fixtures/builtin-default-pet "$(APP_BUNDLE)/Contents/Resources/BundledPets/builtin-default"
	@chmod +x "$(APP_BUNDLE)/Contents/MacOS/CodexPetNest"
	@if [ "$(CODESIGN_IDENTITY)" = "-" ]; then \
		echo "Warning: Using ad-hoc signing. This is not suitable for distribution."; \
	fi
	@codesign --force --deep --sign "$(CODESIGN_IDENTITY)" "$(APP_BUNDLE)"
	@echo "App bundle created and signed with '$(CODESIGN_IDENTITY)': $(APP_BUNDLE)"

run: app
	@pkill -x CodexPetNest 2>/dev/null || true
	open -n "$(APP_BUNDLE)"

dev: $(EXEC_DEBUG)
	@cp Resources/MenuBarIconTemplate*.png .build/
	@mkdir -p .build/BundledNests
	@cp -R docs/test-fixtures/nests-v1.1/basket-pomodoro-nest .build/BundledNests/
	@cp -R docs/test-fixtures/nests-v1.1/legend-status-nest .build/BundledNests/
	@cp -R docs/test-fixtures/nests-v1.1/window-desk-nest .build/BundledNests/
	@cp -R docs/test-fixtures/nests-v1.1/quick-actions-demo-nest .build/BundledNests/
	@mkdir -p .build/BundledPets
	@cp -R docs/test-fixtures/builtin-default-pet .build/BundledPets/builtin-default
	@echo "Starting app with console logging..."
	./$(EXEC_DEBUG)

dmg: app
	@echo "Creating DMG..."
	@rm -f "$(BUILD_DIR)/$(APP_NAME).dmg" "$(BUILD_DIR)/$(DMG_NAME)"
	@mkdir -p "$(BUILD_DIR)/dmg_temp"
	@cp -R "$(APP_BUNDLE)" "$(BUILD_DIR)/dmg_temp/"
	@ln -s /Applications "$(BUILD_DIR)/dmg_temp/Applications"
	@hdiutil create -volname "$(DMG_VOLUME_NAME)" -srcfolder "$(BUILD_DIR)/dmg_temp" -ov -format UDZO "$(BUILD_DIR)/$(DMG_NAME)"
	@rm -rf "$(BUILD_DIR)/dmg_temp"
	@swift -e 'import AppKit; NSWorkspace.shared.setIcon(NSImage(contentsOfFile: "Resources/CodexPetNest.icns"), forFile: "$(BUILD_DIR)/$(DMG_NAME)", options: [])'
	@echo "DMG created with icon: $(BUILD_DIR)/$(DMG_NAME)"

verify-dmg: dmg
	@set -e; \
	MOUNT_PATH="$(BUILD_DIR)/dmg_verify_mount"; \
	rm -rf "$$MOUNT_PATH"; \
	mkdir -p "$$MOUNT_PATH"; \
	hdiutil attach "$(BUILD_DIR)/$(DMG_NAME)" -nobrowse -readonly -mountpoint "$$MOUNT_PATH" >/dev/null; \
	echo "Mounted at: $$MOUNT_PATH"; \
	APP_PATH="$$MOUNT_PATH/$(APP_NAME).app"; \
	echo "DMG app version:"; \
	/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$$APP_PATH/Contents/Info.plist"; \
	/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$$APP_PATH/Contents/Info.plist"; \
	echo "Build and DMG executable match:"; \
	cmp -s "$(APP_BUNDLE)/Contents/MacOS/CodexPetNest" "$$APP_PATH/Contents/MacOS/CodexPetNest"; \
	echo "yes"; \
	hdiutil detach "$$MOUNT_PATH" >/dev/null; \
	rmdir "$$MOUNT_PATH"

clean:
	@rm -rf $(BUILD_DIR)
	@echo "Cleaned build directory."

package-nests-v1.1:
	@echo "Packaging v1.1 nests..."
	@rm -f docs/test-fixtures/nests-v1.1/*.zip
	@(cd docs/test-fixtures/nests-v1.1/basket-pomodoro-nest && zip -r -X ../basket-pomodoro-nest.zip . -x ".*" -x "__MACOSX")
	@(cd docs/test-fixtures/nests-v1.1/legend-status-nest && zip -r -X ../legend-status-nest.zip . -x ".*" -x "__MACOSX")
	@(cd docs/test-fixtures/nests-v1.1/trainer-card-nest && zip -r -X ../trainer-card-nest.zip . -x ".*" -x "__MACOSX")
	@(cd docs/test-fixtures/nests-v1.1/window-desk-nest && zip -r -X ../window-desk-nest.zip . -x ".*" -x "__MACOSX")
	@echo "v1.1 nests packaged successfully."

validate-nests-v1.1: $(EXEC_DEBUG)
	@echo "Starting v1.1 nest validation..."
	@CODEXPET_VALIDATE_NESTS_V11=1 ./$(EXEC_DEBUG)

.PHONY: all debug release app run clean dmg verify-dmg package-nests-v1.1 validate-nests-v1.1
