#!/bin/bash
# Main test runner for VS Code Tunnel Setup Script
# Executes all test suites and generates reports

set -e

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test configuration
BATS_PARALLEL="${BATS_PARALLEL:-false}"
BATS_JOBS="${BATS_JOBS:-4}"
COVERAGE_ENABLED="${COVERAGE_ENABLED:-false}"
DOCKER_TESTS="${DOCKER_TESTS:-true}"
VERBOSE="${VERBOSE:-false}"

# Output directory for reports
REPORT_DIR="$SCRIPT_DIR/reports"
mkdir -p "$REPORT_DIR"

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

check_dependencies() {
    print_header "Checking Dependencies"
    
    local missing=()
    
    # Check for bats
    if ! command -v bats &>/dev/null; then
        missing+=("bats-core")
    else
        print_success "bats-core: $(bats --version)"
    fi
    
    # Check for Docker (optional for integration/e2e tests)
    if ! command -v docker &>/dev/null; then
        print_warning "Docker not found - integration/e2e tests will be skipped"
        DOCKER_TESTS=false
    else
        if docker info &>/dev/null; then
            print_success "Docker: $(docker --version | head -1)"
        else
            print_warning "Docker daemon not running - integration/e2e tests will be skipped"
            DOCKER_TESTS=false
        fi
    fi
    
    # Check for sshpass (needed for some tests)
    if command -v sshpass &>/dev/null; then
        print_success "sshpass: available"
    else
        print_warning "sshpass not found - some SSH tests may be skipped"
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing[*]}"
        echo ""
        echo "Install with:"
        echo "  brew install bats-core  # macOS"
        echo "  apt-get install bats    # Debian/Ubuntu"
        exit 1
    fi
    
    print_success "All required dependencies found"
}

build_docker_image() {
    if [[ "$DOCKER_TESTS" != "true" ]]; then
        return 0
    fi
    
    print_header "Building Docker Test Image"
    
    docker build \
        -t vscode-tunnel-test \
        -f "$SCRIPT_DIR/fixtures/Dockerfile.mock-server" \
        "$SCRIPT_DIR/fixtures/"
    
    print_success "Docker image built successfully"
}

run_unit_tests() {
    print_header "Running Unit Tests"
    
    local bats_args=()
    
    if [[ "$VERBOSE" == "true" ]]; then
        bats_args+=("--verbose-run")
    fi
    
    if [[ "$BATS_PARALLEL" == "true" ]]; then
        bats_args+=("--jobs" "$BATS_JOBS")
    fi
    
    bats_args+=("--tap")
    bats_args+=("$SCRIPT_DIR/unit/")
    
    # Run tests and capture output
    if bats "${bats_args[@]}" | tee "$REPORT_DIR/unit-tests.tap"; then
        print_success "Unit tests passed"
        return 0
    else
        print_error "Unit tests failed"
        return 1
    fi
}

run_integration_tests() {
    if [[ "$DOCKER_TESTS" != "true" ]]; then
        print_warning "Skipping integration tests (Docker not available)"
        return 0
    fi
    
    print_header "Running Integration Tests"
    
    local bats_args=()
    
    if [[ "$VERBOSE" == "true" ]]; then
        bats_args+=("--verbose-run")
    fi
    
    bats_args+=("--tap")
    bats_args+=("$SCRIPT_DIR/integration/")
    
    if bats "${bats_args[@]}" | tee "$REPORT_DIR/integration-tests.tap"; then
        print_success "Integration tests passed"
        return 0
    else
        print_error "Integration tests failed"
        return 1
    fi
}

run_e2e_tests() {
    if [[ "$DOCKER_TESTS" != "true" ]]; then
        print_warning "Skipping E2E tests (Docker not available)"
        return 0
    fi
    
    print_header "Running E2E Tests"
    
    local bats_args=()
    
    if [[ "$VERBOSE" == "true" ]]; then
        bats_args+=("--verbose-run")
    fi
    
    bats_args+=("--tap")
    bats_args+=("$SCRIPT_DIR/e2e/")
    
    if bats "${bats_args[@]}" | tee "$REPORT_DIR/e2e-tests.tap"; then
        print_success "E2E tests passed"
        return 0
    else
        print_error "E2E tests failed"
        return 1
    fi
}

cleanup_docker() {
    if [[ "$DOCKER_TESTS" == "true" ]]; then
        print_info "Cleaning up Docker resources..."
        docker stop vscode-tunnel-test-server 2>/dev/null || true
        docker rm vscode-tunnel-test-server 2>/dev/null || true
    fi
}

generate_summary() {
    print_header "Test Summary"
    
    local total=0
    local passed=0
    local failed=0
    
    # Parse TAP files for summary
    for tap_file in "$REPORT_DIR"/*.tap; do
        if [[ -f "$tap_file" ]]; then
            local file_total
            local file_passed
            local file_failed
            
            file_total=$(grep -c -E "^ok |^not ok " "$tap_file" 2>/dev/null) || file_total=0
            file_passed=$(grep -c -E "^ok " "$tap_file" 2>/dev/null) || file_passed=0
            file_failed=$(grep -c -E "^not ok " "$tap_file" 2>/dev/null) || file_failed=0
            
            total=$((total + file_total))
            passed=$((passed + file_passed))
            failed=$((failed + file_failed))
            
            echo "  $(basename "$tap_file" .tap): $file_passed/$file_total passed"
        fi
    done
    
    echo ""
    echo -e "${CYAN}Total: $passed/$total tests passed${NC}"
    
    if [[ $failed -gt 0 ]]; then
        echo -e "${RED}$failed tests failed${NC}"
        return 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    fi
}

show_help() {
    echo "VS Code Tunnel Setup Script - Test Runner"
    echo ""
    echo "Usage: $0 [options] [test-type]"
    echo ""
    echo "Test types:"
    echo "  all           Run all tests (default)"
    echo "  unit          Run only unit tests"
    echo "  integration   Run only integration tests"
    echo "  e2e           Run only E2E tests"
    echo ""
    echo "Options:"
    echo "  -p, --parallel    Run tests in parallel"
    echo "  -j, --jobs N      Number of parallel jobs (default: 4)"
    echo "  -v, --verbose     Verbose output"
    echo "  --no-docker       Skip Docker-dependent tests"
    echo "  -h, --help        Show this help"
    echo ""
    echo "Environment variables:"
    echo "  BATS_PARALLEL     Enable parallel execution (true/false)"
    echo "  BATS_JOBS         Number of parallel jobs"
    echo "  DOCKER_TESTS      Enable Docker tests (true/false)"
    echo "  VERBOSE           Verbose output (true/false)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run all tests"
    echo "  $0 unit               # Run only unit tests"
    echo "  $0 -p -j 8 all        # Run all tests in parallel with 8 jobs"
    echo "  $0 --no-docker unit   # Run unit tests without Docker"
}

# =============================================================================
# Main
# =============================================================================

main() {
    local test_type="all"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--parallel)
                BATS_PARALLEL=true
                shift
                ;;
            -j|--jobs)
                BATS_JOBS="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --no-docker)
                DOCKER_TESTS=false
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            unit|integration|e2e|all)
                test_type="$1"
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Trap for cleanup
    trap cleanup_docker EXIT
    
    print_header "VS Code Tunnel Setup Script - Test Suite"
    echo "Test type: $test_type"
    echo "Parallel: $BATS_PARALLEL"
    echo "Docker tests: $DOCKER_TESTS"
    echo ""
    
    # Check dependencies
    check_dependencies
    
    # Build Docker image if needed
    if [[ "$test_type" == "all" || "$test_type" == "integration" || "$test_type" == "e2e" ]]; then
        build_docker_image
    fi
    
    # Run tests based on type
    local exit_code=0
    
    case "$test_type" in
        unit)
            run_unit_tests || exit_code=1
            ;;
        integration)
            run_integration_tests || exit_code=1
            ;;
        e2e)
            run_e2e_tests || exit_code=1
            ;;
        all)
            run_unit_tests || exit_code=1
            run_integration_tests || exit_code=1
            run_e2e_tests || exit_code=1
            ;;
    esac
    
    # Generate summary
    generate_summary || exit_code=1
    
    exit $exit_code
}

main "$@"
