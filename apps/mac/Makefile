.PHONY: all clean rust-dev rust-release xcode-project build run dev

RUST_TARGET := aarch64-apple-darwin
RUST_LIB_NAME := libswipe_engine.a
RUST_SRC := ../../crates/swipe-engine
RUST_OUT := Rust/$(RUST_LIB_NAME)

# Default target
all: build

# Build Rust library for development (debug)
rust-dev:
	cd $(RUST_SRC) && cargo build --features ffi --target $(RUST_TARGET)
	mkdir -p Rust
	cp $(RUST_SRC)/../../target/$(RUST_TARGET)/debug/$(RUST_LIB_NAME) $(RUST_OUT)
	@echo "Built debug Rust library: $(RUST_OUT)"

# Build Rust library for release
rust-release:
	cd $(RUST_SRC) && cargo build --release --features ffi --target $(RUST_TARGET)
	mkdir -p Rust
	cp $(RUST_SRC)/../../target/$(RUST_TARGET)/release/$(RUST_LIB_NAME) $(RUST_OUT)
	@echo "Built release Rust library: $(RUST_OUT)"

# Generate Xcode project from project.yml
xcode-project:
	xcodegen generate
	@echo "Generated Xcode project"

# Build the app (requires Xcode project and Rust library)
build: rust-release xcode-project
	xcodebuild -project SwipeTypeMac.xcodeproj -scheme SwipeTypeMac -configuration Release build
	@echo "Built SwipeTypeMac.app"

# Build release version
build-release: rust-release xcode-project
	xcodebuild -project SwipeTypeMac.xcodeproj -scheme SwipeTypeMac -configuration Release build
	@echo "Built SwipeTypeMac.app (Release)"

# Run the app executable directly
run:
	$$(ls -d ~/Library/Developer/Xcode/DerivedData/SwipeTypeMac-*/Build/Products/Release/SwipeType.app)/Contents/MacOS/SwipeType

# Development: build and run
dev: build
	$$(ls -d ~/Library/Developer/Xcode/DerivedData/SwipeTypeMac-*/Build/Products/Release/SwipeType.app)/Contents/MacOS/SwipeType

# Clean build artifacts
clean:
	rm -rf build
	rm -rf Rust/*.a
	rm -rf SwipeTypeMac.xcodeproj
	rm -rf ~/Library/Developer/Xcode/DerivedData/SwipeTypeMac-*
	@echo "Cleaned build artifacts"

# Help
help:
	@echo "Available targets:"
	@echo "  make rust-dev      - Build Rust library (debug)"
	@echo "  make rust-release  - Build Rust library (release)"
	@echo "  make xcode-project - Generate Xcode project"
	@echo "  make build         - Build the app (debug)"
	@echo "  make build-release - Build the app (release)"
	@echo "  make run           - Run the app"
	@echo "  make dev           - Build and run (development)"
	@echo "  make clean         - Clean all build artifacts"
