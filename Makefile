.PHONY: reload clean build build-example test test-debug open
 .PHONY: test-bundle

# Ensure a predictable shell
SHELL := /bin/bash

# Resolve TUIST command (assume on PATH for simplicity)
TUIST := tuist

# Default iOS Simulator device name for tests
DEST_SIM ?= iPhone 16
# Optionally pin the OS; Xcode supports 'latest' to auto-resolve
DEST_OS ?= latest

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
	@$(TUIST) test --no-selective-testing --configuration Debug -- -destination 'platform=iOS Simulator,name=$(DEST_SIM),OS=$(DEST_OS)' -parallel-testing-enabled YES

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
	@$(TUIST) test --no-selective-testing --configuration Debug -- -destination 'platform=iOS Simulator,name=$(DEST_SIM),OS=$(DEST_OS)' -parallel-testing-enabled YES 2>&1 | tee "$(TEST_LOG)"

# Run tests and save an .xcresult bundle with attachments/activities
# Usage: `make test-bundle RESULT_BUNDLE=Derived/TestResults.xcresult`
RESULT_BUNDLE ?= Derived/TestResults.xcresult
test-bundle:
	@echo "[Make] Running tests and saving result bundle to $(RESULT_BUNDLE)"
	@mkdir -p "$(dir $(RESULT_BUNDLE))"
	@$(TUIST) test --no-selective-testing --configuration Debug -- -resultBundlePath '$(RESULT_BUNDLE)' -destination 'platform=iOS Simulator,name=$(DEST_SIM),OS=$(DEST_OS)' -parallel-testing-enabled YES | tee "$(TEST_LOG)"
build-example:
	@echo "[Make] Building GenMarkExample via Tuist"
	@$(TUIST) build GenMarkExample --configuration Debug
