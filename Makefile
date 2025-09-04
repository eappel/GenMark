.PHONY: reload clean open build build-example

# Ensure a predictable shell
SHELL := /bin/bash

# Resolve TUIST command:
# 1) Respect user-provided TUIST
# 2) Use tuist on PATH if available
# 3) Fallback to running via mise if available
# 4) Otherwise, default to plain "tuist"
ifndef TUIST
TUIST := $(shell command -v tuist 2>/dev/null)
ifeq ($(strip $(TUIST)),)
  ifneq ($(shell command -v mise 2>/dev/null),)
    TUIST := mise exec tuist@latest -- tuist
  else
    TUIST := tuist
  endif
endif
endif

reload:
	@echo "[Make] Regenerating project via Tuist"
	@$(TUIST) generate --no-open

clean:
	@echo "[Make] Installing Tuist dependencies and regenerating"
	@$(TUIST) install
	@$(TUIST) generate --no-open

open:
	@echo "[Make] Generating and opening the workspace via Tuist"
	@$(TUIST) generate

# Build the SDK (framework) only
build:
	@echo "[Make] Generating project and building GenMark SDK (iOS Simulator)"
	@$(TUIST) generate --no-open
	@xcodebuild -project GenMark.xcodeproj -scheme GenMark -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -configuration Debug build

# Build the iOS example app target using Tuist (without launching a simulator)
build-example:
	@echo "[Make] Generating project and building GenMarkExample (iOS Simulator)"
	@$(TUIST) generate --no-open
	@xcodebuild -project GenMark.xcodeproj -target GenMarkExample -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -configuration Debug build
