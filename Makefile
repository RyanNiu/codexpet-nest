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
		-D DEBUG \
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

dev: all
	@echo "Starting app with console logging..."
	./$(EXEC)

package-nests-v1.1:
	@echo "Packaging v1.1 nests..."
	@rm -f docs/test-fixtures/nests-v1.1/*.zip
	@(cd docs/test-fixtures/nests-v1.1/legend-status-nest && zip -r -X ../legend-status-nest.zip . -x ".*" -x "__MACOSX")
	@(cd docs/test-fixtures/nests-v1.1/trainer-card-nest && zip -r -X ../trainer-card-nest.zip . -x ".*" -x "__MACOSX")
	@(cd docs/test-fixtures/nests-v1.1/window-desk-nest && zip -r -X ../window-desk-nest.zip . -x ".*" -x "__MACOSX")
	@echo "v1.1 nests packaged successfully."

validate-nests-v1.1: all
	@echo "Starting v1.1 nest validation..."
	@CODEXPET_VALIDATE_NESTS_V11=1 ./$(EXEC)

.PHONY: all debug release app run clean package-nests-v1.1 validate-nests-v1.1
