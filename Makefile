# Makefile for VS Code Tunnel Setup Script
# Provides convenient targets for development and testing

.PHONY: all test test-unit test-integration test-e2e clean lint help docker-build docker-clean

# Default target
all: lint test

# =============================================================================
# Testing
# =============================================================================

# Run all tests
test:
	@./tests/run_tests.sh all

# Run only unit tests (no Docker required)
test-unit:
	@./tests/run_tests.sh unit

# Run only integration tests (requires Docker)
test-integration:
	@./tests/run_tests.sh integration

# Run only E2E tests (requires Docker)
test-e2e:
	@./tests/run_tests.sh e2e

# Run tests in parallel
test-parallel:
	@./tests/run_tests.sh --parallel all

# Run tests with verbose output
test-verbose:
	@./tests/run_tests.sh --verbose all

# Run tests without Docker
test-no-docker:
	@./tests/run_tests.sh --no-docker all

# Run real tunnel integration test (requires GitHub auth)
test-real:
	@./tests/manual/real_tunnel_test.sh

# Run real tunnel test and keep tunnel running
test-real-keep:
	@./tests/manual/real_tunnel_test.sh --keep

# Run Docker-based integration test (real tunnel in container)
test-docker-real:
	@./tests/docker-integration/run_docker_integration.sh

# Run Docker-based integration test with cleanup
test-docker-real-cleanup:
	@./tests/docker-integration/run_docker_integration.sh --cleanup

# =============================================================================
# Docker
# =============================================================================

# Build the test Docker image
docker-build:
	@docker build -t vscode-tunnel-test -f tests/fixtures/Dockerfile.mock-server tests/fixtures/

# Start the test container
docker-start:
	@docker-compose -f tests/fixtures/docker-compose.test.yml up -d mock-server

# Stop the test container
docker-stop:
	@docker-compose -f tests/fixtures/docker-compose.test.yml down

# Clean up Docker resources
docker-clean:
	@docker stop vscode-tunnel-test-server 2>/dev/null || true
	@docker rm vscode-tunnel-test-server 2>/dev/null || true
	@docker rmi vscode-tunnel-test 2>/dev/null || true

# =============================================================================
# Linting
# =============================================================================

# Lint shell scripts
lint:
	@echo "Linting shell scripts..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck setup-vscode-tunnel.sh; \
		shellcheck tests/run_tests.sh; \
		shellcheck tests/test_helper.bash; \
		echo "✓ Linting passed"; \
	else \
		echo "⚠ shellcheck not found, skipping lint"; \
	fi

# Lint Markdown files
lint-md:
	@echo "Linting Markdown files..."
	@if command -v markdownlint >/dev/null 2>&1; then \
		markdownlint docs/ README.md; \
		echo "✓ Markdown linting passed"; \
	else \
		echo "⚠ markdownlint not found, skipping Markdown lint"; \
	fi

# =============================================================================
# Development
# =============================================================================

# Install development dependencies
install-deps:
	@echo "Installing development dependencies..."
	@if [[ "$$(uname)" == "Darwin" ]]; then \
		brew install bats-core shellcheck markdownlint-cli sshpass; \
	else \
		echo "Please install: bats-core, shellcheck, markdownlint-cli, sshpass"; \
	fi

# Format shell scripts (requires shfmt)
fmt:
	@echo "Formatting shell scripts..."
	@if command -v shfmt >/dev/null 2>&1; then \
		shfmt -w -i 4 setup-vscode-tunnel.sh; \
		shfmt -w -i 4 tests/run_tests.sh; \
		shfmt -w -i 4 tests/test_helper.bash; \
		echo "✓ Formatting complete"; \
	else \
		echo "⚠ shfmt not found, skipping format"; \
	fi

# =============================================================================
# Cleaning
# =============================================================================

# Clean test artifacts
clean:
	@echo "Cleaning test artifacts..."
	@rm -rf tests/reports/
	@rm -rf tests/tmp/
	@echo "✓ Clean complete"

# Full clean including Docker
clean-all: clean docker-clean
	@echo "✓ Full clean complete"

# =============================================================================
# Help
# =============================================================================

help:
	@echo "VS Code Tunnel Setup Script - Makefile"
	@echo ""
	@echo "Testing targets:"
	@echo "  make test             Run all tests"
	@echo "  make test-unit        Run only unit tests"
	@echo "  make test-integration Run only integration tests"
	@echo "  make test-e2e         Run only E2E tests"
	@echo "  make test-parallel    Run tests in parallel"
	@echo "  make test-verbose     Run tests with verbose output"
	@echo "  make test-no-docker   Run tests without Docker"
	@echo ""
	@echo "Docker targets:"
	@echo "  make docker-build     Build test Docker image"
	@echo "  make docker-start     Start test container"
	@echo "  make docker-stop      Stop test container"
	@echo "  make docker-clean     Remove Docker resources"
	@echo ""
	@echo "Development targets:"
	@echo "  make lint             Lint shell scripts"
	@echo "  make lint-md          Lint Markdown files"
	@echo "  make fmt              Format shell scripts"
	@echo "  make install-deps     Install dev dependencies"
	@echo ""
	@echo "Cleaning targets:"
	@echo "  make clean            Clean test artifacts"
	@echo "  make clean-all        Full clean including Docker"
	@echo ""
	@echo "Other:"
	@echo "  make help             Show this help"
