.PHONY: reload clean build build-example test

# Ensure a predictable shell
SHELL := /bin/bash

# Resolve TUIST command (assume on PATH for simplicity)
TUIST := tuist

# Default iOS Simulator device name for tests
DEST_SIM ?= iPhone 16

reload:
	@echo "[Make] Regenerating project via Tuist"
	@$(TUIST) generate"

clean:
	@echo "[Make] Installing Tuist dependencies and regenerating"
	@$(TUIST) install
	@$(TUIST) generate

# Run unit tests using Tuist
test:
	@echo "[Make] Running unit tests via Tuist on $(DEST_SIM)"
	@$(TUIST) test --configuration Debug -- -destination 'platform=iOS Simulator,name=$(DEST_SIM)' -parallel-testing-enabled YES

# Build the SDK (framework) only via Tuist
build:
	@echo "[Make] Building GenMark SDK via Tuist"
	@$(TUIST) build GenMark --configuration Debug

# Build the iOS example app via Tuist

build-example:
	@echo "[Make] Building GenMarkExample via Tuist"
	@$(TUIST) build GenMarkExample --configuration Debug
