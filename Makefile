ODIN ?= odin
BUILD_DIR := build
TARGET := $(BUILD_DIR)/twin-commander
ODIN_FLAGS := -collection:tc=.

.PHONY: all build run clean

all: build

build: $(TARGET)

ODIN_SOURCES := $(shell find cmd pkg -name '*.odin')
CONFIG_SOURCES := $(shell find config -name '*.json')

$(TARGET): $(ODIN_SOURCES) $(CONFIG_SOURCES)
	mkdir -p $(BUILD_DIR)
	$(ODIN) build ./cmd/twin-commander $(ODIN_FLAGS) -out:$(TARGET)

.PHONY: test
test:
	$(ODIN) test ./pkg/tui $(ODIN_FLAGS)
	$(ODIN) test ./pkg/tui/terminal $(ODIN_FLAGS)
	$(ODIN) test ./pkg/fsops $(ODIN_FLAGS)
	$(ODIN) test ./pkg/themes $(ODIN_FLAGS)
	$(ODIN) test ./pkg/commander $(ODIN_FLAGS)

run: build
	./$(TARGET)

clean:
	rm -rf $(BUILD_DIR)
