.PHONY: reload clean build build-example test test-debug open
 .PHONY: test-bundle

# Ensure a predictable shell
SHELL := /bin/bash

# Resolve TUIST command (assume on PATH for simplicity)
TUIST := tuist

# Default iOS Simulator device name for tests
DEST_SIM ?= Pro
# Optionally pin the OS; default to the latest installed that works on this machine
DEST_OS ?= 18.6
# Explicit architecture to avoid duplicate simulator matches
DEST_ARCH ?= arm64
# Specific simulator identifier; overrides name/OS/arch when provided
DEST_ID ?= 5EF2F0EC-1201-45AF-8747-D8D1A8CA2C48

ifeq ($(strip $(DEST_ID)),)
DEST_FLAGS := -destination 'platform=iOS Simulator,arch=$(DEST_ARCH),name=$(DEST_SIM),OS=$(DEST_OS)'
else
DEST_FLAGS := -destination 'id=$(DEST_ID)'
endif

reload:
	@echo "[Make] Regenerating project via Tuist"
	@$(TUIST) generate

# Generate and open the workspace in Xcode
open:
	@echo "[Make] Generating project via Tuist and opening in Xcode"
	@$(TUIST) generate
	@xed .

clean:
	@echo "[Make] Installing Tuist dependencies and regenerating"
	@$(TUIST) install
	@$(TUIST) generate

# Run unit tests using Tuist  
test:
	@echo "[Make] Running unit tests via Tuist on $(DEST_SIM)"
	@$(TUIST) test --no-selective-testing --configuration Debug -- $(DEST_FLAGS) -parallel-testing-enabled YES

# Build the SDK (framework) only via Tuist
build:
	@echo "[Make] Building GenMark SDK via Tuist"
	@$(TUIST) build GenMark --configuration Debug

# Dedicated debug target: pipes output to a log file for easy sharing
# Usage: `make test-debug` or override path with `TEST_LOG=build/test.log make test-debug`
TEST_LOG ?= test-output.txt

test-debug:
	@echo "[Make] Running unit tests via Tuist on $(DEST_SIM) (debug log -> $(TEST_LOG))"
	@mkdir -p "$(dir $(TEST_LOG))"
	@$(TUIST) test --no-selective-testing --configuration Debug -- $(DEST_FLAGS) -parallel-testing-enabled YES 2>&1 | tee "$(TEST_LOG)"

# Run tests and save an .xcresult bundle with attachments/activities
# Usage: `make test-bundle RESULT_BUNDLE=Derived/TestResults.xcresult`
RESULT_BUNDLE ?= Derived/TestResults.xcresult
test-bundle:
	@echo "[Make] Running tests and saving result bundle to $(RESULT_BUNDLE)"
	@mkdir -p "$(dir $(RESULT_BUNDLE))"
	@$(TUIST) test --no-selective-testing --configuration Debug -- -resultBundlePath '$(RESULT_BUNDLE)' $(DEST_FLAGS) -parallel-testing-enabled YES | tee "$(TEST_LOG)"
build-example:
	@echo "[Make] Building GenMarkExample via Tuist"
	@$(TUIST) build GenMarkExample --configuration Debug
