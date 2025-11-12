# Makefile for ArchLinux ISO build system

.PHONY: all build clean test help

all: build

build:
	@echo "Building ArchLinux ISO with rust coreutils..."
	sudo ./build.sh

build-clean:
	@echo "Building ArchLinux ISO with clean build..."
	sudo ./build.sh --clean

test:
	@echo "Running tests..."
	./tests/build.test.sh

clean:
	@echo "Cleaning build artifacts..."
	sudo rm -rf work/ out/ build/

help:
	@echo "Available targets:"
	@echo "  make build       - Build the ISO"
	@echo "  make build-clean - Build the ISO with clean build"
	@echo "  make test        - Run unit tests"
	@echo "  make clean       - Remove build artifacts"
	@echo "  make help        - Show this help message"

