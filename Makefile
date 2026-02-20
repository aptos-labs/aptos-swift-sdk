# Aptos Swift SDK Makefile

.PHONY: build test clean format format-check lint ci help

# Default target
help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Build
build: ## Build the SDK
	swift build

build-release: ## Build the SDK in release mode
	swift build -c release

# Test
test: ## Run all tests
	swift test

test-verbose: ## Run all tests with verbose output
	swift test --verbose

# Clean
clean: ## Clean build artifacts
	swift package clean

# Format
format: ## Format all Swift source files
	@if command -v swiftformat >/dev/null 2>&1; then \
		swiftformat Sources/ Tests/; \
	else \
		echo "Error: swiftformat not found. Install with: brew install swiftformat"; \
		exit 1; \
	fi

format-check: ## Check formatting without modifying files (CI mode)
	@if command -v swiftformat >/dev/null 2>&1; then \
		swiftformat --lint Sources/ Tests/; \
	else \
		echo "Error: swiftformat not found. Install with: brew install swiftformat"; \
		exit 1; \
	fi

# Lint
lint: ## Run SwiftLint
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint Sources/ Tests/; \
	else \
		echo "Error: swiftlint not found. Install with: brew install swiftlint"; \
		exit 1; \
	fi

lint-fix: ## Run SwiftLint with auto-fix
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint --fix Sources/ Tests/; \
	else \
		echo "Error: swiftlint not found. Install with: brew install swiftlint"; \
		exit 1; \
	fi

# CI
ci: build test format-check lint ## Run all CI checks (build, test, format, lint)

# Resolve
resolve: ## Resolve package dependencies
	swift package resolve

# Update
update: ## Update package dependencies
	swift package update
