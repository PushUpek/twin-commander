ODIN ?= odin
BUILD_DIR := build
TARGET := $(BUILD_DIR)/twin-commander

.PHONY: all build run clean

all: build

build: $(TARGET)

ODIN_SOURCES := $(shell find . -name '*.odin' -not -path './build/*')

$(TARGET): $(ODIN_SOURCES)
	mkdir -p $(BUILD_DIR)
	$(ODIN) build . -out:$(TARGET)

.PHONY: test
test:
	$(ODIN) test ./tui

run: build
	./$(TARGET)

clean:
	rm -rf $(BUILD_DIR)
