ODIN ?= odin
BUILD_DIR := build
TARGET := $(BUILD_DIR)/twin-commander
ODIN_FLAGS := -collection:tc=.

.PHONY: all build run clean

all: build

build: $(TARGET)

ODIN_SOURCES := $(shell find cmd internal -name '*.odin')

$(TARGET): $(ODIN_SOURCES)
	mkdir -p $(BUILD_DIR)
	$(ODIN) build ./cmd/twin-commander $(ODIN_FLAGS) -out:$(TARGET)

.PHONY: test
test:
	$(ODIN) test ./internal/tui $(ODIN_FLAGS)
	$(ODIN) test ./internal/fsops $(ODIN_FLAGS)

run: build
	./$(TARGET)

clean:
	rm -rf $(BUILD_DIR)
