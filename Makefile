SDK_PATH := $(shell xcrun --show-sdk-path)
SWIFTC := swiftc
TARGET := arm64-apple-macosx14.0
BUILD_DIR := .build
EXEC := $(BUILD_DIR)/CodexPetNest

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

run: $(EXEC)
	$(EXEC)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all debug release run clean
