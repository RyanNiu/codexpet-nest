SDK_PATH := $(shell xcrun --show-sdk-path)
SWIFTC := swiftc
BUILD_DIR := .build
EXEC := $(BUILD_DIR)/CodexPetNest
APP_NAME := CodexPet Nest
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app

SOURCES := $(shell find Sources -name '*.swift')

all: $(EXEC)

$(EXEC): $(SOURCES)
	@mkdir -p $(BUILD_DIR)
	$(SWIFTC) \
		-sdk $(SDK_PATH) \
		-framework AppKit \
		-framework Security \
		-framework Foundation \
		-o $@ \
		$(SOURCES)

debug: $(EXEC)

release: $(SOURCES)
	@mkdir -p $(BUILD_DIR)
	$(SWIFTC) -O \
		-sdk $(SDK_PATH) \
		-framework AppKit \
		-framework Security \
		-framework Foundation \
		-o $(EXEC) \
		$(SOURCES)

app: release
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp $(EXEC) "$(APP_BUNDLE)/Contents/MacOS/CodexPetNest"
	@cp Resources/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	@chmod +x "$(APP_BUNDLE)/Contents/MacOS/CodexPetNest"
	@echo "App bundle created: $(APP_BUNDLE)"

run: app
	open "$(APP_BUNDLE)"

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all debug release app run clean
