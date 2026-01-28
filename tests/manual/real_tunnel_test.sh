#!/bin/bash
# SPDX-License-Identifier: MIT OR Apache-2.0
# =============================================================================
# Real Tunnel Integration Test
# =============================================================================
# This test creates an ACTUAL VS Code tunnel and verifies it works.
# Requires manual GitHub authentication via Device Code flow.
#
# Usage:
#   ./tests/manual/real_tunnel_test.sh [options]
#
# Options:
#   -n, --name <name>     Tunnel name (default: test-tunnel-<random>)
#   -t, --timeout <secs>  Auth timeout in seconds (default: 120)
#   -k, --keep            Keep tunnel running after test
#   -s, --skip-cleanup    Don't remove CLI after test
#   -h, --help            Show this help
#
# Requirements:
#   - Internet connection
#   - GitHub account
#   - curl or wget
# =============================================================================

set -e

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$(mktemp -d)"
TUNNEL_NAME="test-tunnel-$(date +%s)"
AUTH_TIMEOUT=120
KEEP_RUNNING=false
SKIP_CLEANUP=false
CLI_PATH="$TEST_DIR/code"
LOG_FILE="$TEST_DIR/tunnel.log"
PID_FILE="$TEST_DIR/tunnel.pid"

# Test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "  ${NC}$1${NC}"
}

run_test() {
    local test_name="$1"
    local test_cmd="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "  Testing: $test_name... "
    
    if eval "$test_cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

cleanup() {
    print_header "Cleanup"
    
    # Stop tunnel if running
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            print_step "Stopping tunnel (PID: $pid)..."
            kill "$pid" 2>/dev/null || true
            sleep 2
            kill -9 "$pid" 2>/dev/null || true
            print_success "Tunnel stopped"
        fi
    fi
    
    # Clean up test directory
    if [[ "$SKIP_CLEANUP" != "true" && -d "$TEST_DIR" ]]; then
        print_step "Removing test directory..."
        rm -rf "$TEST_DIR"
        print_success "Cleaned up"
    else
        print_info "Test artifacts preserved in: $TEST_DIR"
    fi
}

show_help() {
    echo "Real Tunnel Integration Test"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -n, --name <name>     Tunnel name (default: test-tunnel-<timestamp>)"
    echo "  -t, --timeout <secs>  Auth timeout in seconds (default: 120)"
    echo "  -k, --keep            Keep tunnel running after test"
    echo "  -s, --skip-cleanup    Don't remove CLI/artifacts after test"
    echo "  -h, --help            Show this help"
    echo ""
    echo "This test will:"
    echo "  1. Download the real VS Code CLI"
    echo "  2. Start a tunnel (requires GitHub auth)"
    echo "  3. Verify the tunnel is accessible"
    echo "  4. Clean up (unless --keep specified)"
    echo ""
    echo "You will need to authenticate via GitHub Device Code flow."
    exit 0
}

# =============================================================================
# Parse Arguments
# =============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--name)
            TUNNEL_NAME="$2"
            shift 2
            ;;
        -t|--timeout)
            AUTH_TIMEOUT="$2"
            shift 2
            ;;
        -k|--keep)
            KEEP_RUNNING=true
            SKIP_CLEANUP=true
            shift
            ;;
        -s|--skip-cleanup)
            SKIP_CLEANUP=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            ;;
    esac
done

# =============================================================================
# Main Test Flow
# =============================================================================

# Trap for cleanup
trap cleanup EXIT

print_header "Real VS Code Tunnel Integration Test"

echo -e "Configuration:"
echo -e "  Tunnel name:    ${CYAN}$TUNNEL_NAME${NC}"
echo -e "  Auth timeout:   ${CYAN}${AUTH_TIMEOUT}s${NC}"
echo -e "  Keep running:   ${CYAN}$KEEP_RUNNING${NC}"
echo -e "  Test directory: ${CYAN}$TEST_DIR${NC}"
echo ""

# -----------------------------------------------------------------------------
# Step 1: Detect Architecture
# -----------------------------------------------------------------------------

print_header "Step 1: Detect Architecture"

ARCH=$(uname -m)
case $ARCH in
    x86_64)  ARCH_NAME="x64" ;;
    aarch64|arm64) ARCH_NAME="arm64" ;;
    armv7l)  ARCH_NAME="armhf" ;;
    *)
        print_error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Detect OS for CLI variant
OS=$(uname -s)
case $OS in
    Linux)  OS_NAME="linux" ;;
    Darwin) OS_NAME="darwin" ;;
    *)
        print_error "Unsupported OS: $OS"
        exit 1
        ;;
esac

print_success "Architecture: $ARCH → $ARCH_NAME"
print_success "OS: $OS → $OS_NAME"

# -----------------------------------------------------------------------------
# Step 2: Download VS Code CLI
# -----------------------------------------------------------------------------

print_header "Step 2: Download VS Code CLI"

# Use alpine variant for Linux (static binary), darwin for macOS
if [[ "$OS_NAME" == "linux" ]]; then
    DOWNLOAD_URL="https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-$ARCH_NAME"
else
    DOWNLOAD_URL="https://code.visualstudio.com/sha/download?build=stable&os=cli-$OS_NAME-$ARCH_NAME"
fi

print_step "Downloading from: $DOWNLOAD_URL"

cd "$TEST_DIR"

if command -v curl &>/dev/null; then
    curl -L "$DOWNLOAD_URL" -o vscode_cli.tar.gz --progress-bar
elif command -v wget &>/dev/null; then
    wget -O vscode_cli.tar.gz "$DOWNLOAD_URL"
else
    print_error "Neither curl nor wget available"
    exit 1
fi

print_step "Extracting..."
tar -xzf vscode_cli.tar.gz

if [[ ! -f "$CLI_PATH" ]]; then
    # Sometimes extracted as 'code' directly, sometimes in a folder
    if [[ -f "$TEST_DIR/code" ]]; then
        CLI_PATH="$TEST_DIR/code"
    else
        print_error "CLI binary not found after extraction"
        ls -la "$TEST_DIR"
        exit 1
    fi
fi

chmod +x "$CLI_PATH"
print_success "CLI downloaded and extracted"

# -----------------------------------------------------------------------------
# Step 3: Verify CLI
# -----------------------------------------------------------------------------

print_header "Step 3: Verify CLI"

run_test "CLI is executable" "[[ -x '$CLI_PATH' ]]"
run_test "CLI responds to --version" "'$CLI_PATH' --version"
run_test "CLI responds to --help" "'$CLI_PATH' --help"

CLI_VERSION=$("$CLI_PATH" --version 2>/dev/null | head -1)
print_success "CLI Version: $CLI_VERSION"

# -----------------------------------------------------------------------------
# Step 4: Start Tunnel (requires authentication)
# -----------------------------------------------------------------------------

print_header "Step 4: Start Tunnel"

print_warning "GitHub authentication required!"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  IMPORTANT: Watch for the GitHub Device Code below!${NC}"
echo -e "${YELLOW}  You have ${AUTH_TIMEOUT} seconds to authenticate.${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Start tunnel in background, capturing output
"$CLI_PATH" tunnel --accept-server-license-terms --name "$TUNNEL_NAME" > "$LOG_FILE" 2>&1 &
TUNNEL_PID=$!
echo "$TUNNEL_PID" > "$PID_FILE"

print_info "Tunnel started with PID: $TUNNEL_PID"
print_info "Waiting for Device Code..."

# Wait for device code to appear in log
DEVICE_CODE=""
AUTH_URL=""
WAIT_COUNT=0
MAX_WAIT=30

while [[ $WAIT_COUNT -lt $MAX_WAIT ]]; do
    if [[ -f "$LOG_FILE" ]]; then
        # Look for device code pattern
        if grep -q "use code" "$LOG_FILE" 2>/dev/null; then
            DEVICE_CODE=$(grep -o '[A-Z0-9]\{4\}-[A-Z0-9]\{4\}' "$LOG_FILE" | head -1)
            AUTH_URL=$(grep -o 'https://github.com/login/device' "$LOG_FILE" | head -1)
            break
        fi
    fi
    
    # Check if process died
    if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
        print_error "Tunnel process died unexpectedly"
        echo "Log output:"
        cat "$LOG_FILE"
        exit 1
    fi
    
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

if [[ -n "$DEVICE_CODE" ]]; then
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  GitHub Device Code: ${YELLOW}$DEVICE_CODE${NC}"
    echo -e "${GREEN}  Auth URL: ${CYAN}${AUTH_URL:-https://github.com/login/device}${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Try to open browser on macOS
    if [[ "$OS_NAME" == "darwin" ]]; then
        print_info "Opening browser..."
        open "https://github.com/login/device" 2>/dev/null || true
    fi
    
    print_info "Please authenticate in your browser..."
else
    print_warning "Could not detect Device Code (may already be authenticated)"
    echo "Log output so far:"
    cat "$LOG_FILE"
fi

# -----------------------------------------------------------------------------
# Step 5: Wait for Tunnel to be Ready
# -----------------------------------------------------------------------------

print_header "Step 5: Waiting for Tunnel Connection"

TUNNEL_URL=""
WAIT_COUNT=0

while [[ $WAIT_COUNT -lt $AUTH_TIMEOUT ]]; do
    # Check for tunnel URL in log
    if grep -q "https://vscode.dev/tunnel/" "$LOG_FILE" 2>/dev/null; then
        TUNNEL_URL=$(grep -o 'https://vscode.dev/tunnel/[^[:space:]]*' "$LOG_FILE" | head -1)
        break
    fi
    
    # Check for "Connected" or similar success message
    if grep -qi "connected\|listening\|ready" "$LOG_FILE" 2>/dev/null; then
        TUNNEL_URL="https://vscode.dev/tunnel/$TUNNEL_NAME"
        break
    fi
    
    # Check if process died
    if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
        print_error "Tunnel process died"
        echo "Log output:"
        cat "$LOG_FILE"
        exit 1
    fi
    
    # Progress indicator
    echo -ne "\r  Waiting... ${WAIT_COUNT}s / ${AUTH_TIMEOUT}s "
    
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

echo ""

if [[ -n "$TUNNEL_URL" ]]; then
    print_success "Tunnel is ready!"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Tunnel URL: ${CYAN}$TUNNEL_URL${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
else
    print_error "Timeout waiting for tunnel (${AUTH_TIMEOUT}s)"
    echo "Log output:"
    cat "$LOG_FILE"
    exit 1
fi

# -----------------------------------------------------------------------------
# Step 6: Verify Tunnel is Accessible
# -----------------------------------------------------------------------------

print_header "Step 6: Verify Tunnel Accessibility"

# Test 1: Process is still running
run_test "Tunnel process is running" "kill -0 $TUNNEL_PID"

# Test 2: Try to reach vscode.dev (basic connectivity)
run_test "vscode.dev is reachable" "curl -s -o /dev/null -w '%{http_code}' https://vscode.dev | grep -q '200\|301\|302'"

# Test 3: Check if tunnel endpoint responds (may redirect)
TUNNEL_CHECK_URL="https://vscode.dev/tunnel/$TUNNEL_NAME"
run_test "Tunnel endpoint responds" "curl -s -o /dev/null -w '%{http_code}' -L '$TUNNEL_CHECK_URL' | grep -qE '200|302|303'"

# Test 4: Verify tunnel name in running process
run_test "Tunnel name in process" "grep -q '$TUNNEL_NAME' '$LOG_FILE'"

# -----------------------------------------------------------------------------
# Step 7: Summary
# -----------------------------------------------------------------------------

print_header "Test Summary"

echo -e "  Tests run:    ${CYAN}$TESTS_RUN${NC}"
echo -e "  Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "  Tests failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✓ ALL TESTS PASSED${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  ✗ SOME TESTS FAILED${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
fi

echo ""
echo -e "Tunnel URL: ${CYAN}$TUNNEL_URL${NC}"
echo ""

# Keep running if requested
if [[ "$KEEP_RUNNING" == "true" ]]; then
    echo -e "${YELLOW}Tunnel is still running (--keep flag).${NC}"
    echo -e "Press Ctrl+C to stop."
    echo ""
    
    # Remove EXIT trap to keep tunnel running
    trap - EXIT
    
    # Wait for user to stop
    wait "$TUNNEL_PID"
fi

exit $TESTS_FAILED
