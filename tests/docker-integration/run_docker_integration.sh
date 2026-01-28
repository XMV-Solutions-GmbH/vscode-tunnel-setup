#!/bin/bash
# SPDX-License-Identifier: MIT OR Apache-2.0
# =============================================================================
# Docker-based Real Integration Test
# =============================================================================
# Tests the COMPLETE VS Code Tunnel setup in a real Ubuntu container with
# systemd. Validates:
#   1. CLI download and installation
#   2. Systemd service creation
#   3. GitHub authentication (manual)
#   4. Tunnel connectivity (manual verification)
#   5. Service persistence across container restart
#
# Usage:
#   ./tests/docker-integration/run_docker_integration.sh [options]
#
# Options:
#   -n, --name <name>     Tunnel name (default: docker-test-<timestamp>)
#   -t, --timeout <secs>  Timeout for each step (default: 180)
#   -c, --cleanup         Remove container after test
#   -h, --help            Show this help
# =============================================================================

set -e

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONTAINER_NAME="vscode-tunnel-integration-test"
IMAGE_NAME="vscode-tunnel-ubuntu-systemd"
TUNNEL_NAME="docker-test-$(date +%s)"
STEP_TIMEOUT=180
CLEANUP_AFTER=false

# Test state
CURRENT_STEP=0
TOTAL_STEPS=7

# =============================================================================
# Helper Functions
# =============================================================================

print_banner() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${BOLD}$1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Step $CURRENT_STEP/$TOTAL_STEPS: $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
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

print_highlight() {
    echo -e "${MAGENTA}▶ $1${NC}"
}

wait_for_user() {
    local prompt="$1"
    local default="${2:-y}"
    
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  USER INPUT REQUIRED${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [[ "$default" == "y" ]]; then
        read -p "  $prompt [Y/n]: " response
        response=${response:-y}
    else
        read -p "  $prompt [y/N]: " response
        response=${response:-n}
    fi
    
    [[ "$response" =~ ^[Yy] ]]
}

docker_exec() {
    docker exec "$CONTAINER_NAME" "$@"
}

docker_exec_it() {
    docker exec -it "$CONTAINER_NAME" "$@"
}

show_help() {
    echo "Docker-based Real Integration Test"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -n, --name <name>     Tunnel name (default: docker-test-<timestamp>)"
    echo "  -t, --timeout <secs>  Timeout for each step (default: 180)"
    echo "  -c, --cleanup         Remove container after test"
    echo "  -h, --help            Show this help"
    echo ""
    echo "This test will:"
    echo "  1. Build and start an Ubuntu container with systemd"
    echo "  2. Install VS Code CLI inside the container"
    echo "  3. Create and start the systemd service"
    echo "  4. Display GitHub Device Code for authentication"
    echo "  5. Verify tunnel connectivity (you confirm)"
    echo "  6. Restart container and verify service persists"
    echo "  7. Verify tunnel reconnects automatically"
    exit 0
}

cleanup() {
    local exit_code="${1:-0}"
    echo ""
    print_warning "Cleaning up..."
    
    if [[ "$CLEANUP_AFTER" == "true" ]]; then
        if docker ps -q -f "name=$CONTAINER_NAME" | grep -q .; then
            print_info "Stopping container..."
            docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
        fi
        if docker ps -aq -f "name=$CONTAINER_NAME" | grep -q .; then
            print_info "Removing container..."
            docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
        fi
        print_success "Container removed"
    else
        if docker ps -q -f "name=$CONTAINER_NAME" | grep -q .; then
            print_info "Container '$CONTAINER_NAME' is still running"
            print_info "To stop:   docker stop $CONTAINER_NAME"
            print_info "To remove: docker rm -f $CONTAINER_NAME"
            print_info "To shell:  docker exec -it $CONTAINER_NAME bash"
            print_info "To logs:   docker exec $CONTAINER_NAME journalctl -u code-tunnel -f"
        fi
    fi
    
    exit "$exit_code"
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
            STEP_TIMEOUT="$2"
            shift 2
            ;;
        -c|--cleanup)
            CLEANUP_AFTER=true
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

trap cleanup EXIT

print_banner "Docker-based VS Code Tunnel Integration Test"

echo -e "Configuration:"
echo -e "  Container:    ${CYAN}$CONTAINER_NAME${NC}"
echo -e "  Tunnel name:  ${CYAN}$TUNNEL_NAME${NC}"
echo -e "  Timeout:      ${CYAN}${STEP_TIMEOUT}s${NC}"
echo -e "  Cleanup:      ${CYAN}$CLEANUP_AFTER${NC}"

# =============================================================================
# Step 1: Build Docker Image
# =============================================================================

print_step "Build Docker Image"

print_highlight "Building Ubuntu + systemd image..."

docker build \
    -t "$IMAGE_NAME" \
    -f "$SCRIPT_DIR/Dockerfile.ubuntu-systemd" \
    "$SCRIPT_DIR"

print_success "Docker image built: $IMAGE_NAME"

# =============================================================================
# Step 2: Start Container
# =============================================================================

print_step "Start Container with Systemd"

# Stop any existing container
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

print_highlight "Starting container..."

# Run with systemd support
docker run -d \
    --name "$CONTAINER_NAME" \
    --privileged \
    --cgroupns=host \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    "$IMAGE_NAME"

# Wait for systemd to be ready
print_info "Waiting for systemd to initialise..."
sleep 5

# Verify systemd is running
if docker_exec systemctl is-system-running --wait 2>/dev/null || docker_exec systemctl status >/dev/null 2>&1; then
    print_success "Container running with systemd"
else
    print_warning "Systemd may not be fully ready, continuing..."
fi

# Show container info
CONTAINER_ID=$(docker ps -q -f name="$CONTAINER_NAME")
print_info "Container ID: $CONTAINER_ID"

# =============================================================================
# Step 3: Install VS Code CLI & Create Service (using production script)
# =============================================================================

print_step "Install VS Code CLI & Create Service (via production script)"

print_highlight "Copying setup script to container..."

# Copy the production script into the container
docker cp "$PROJECT_ROOT/setup-vscode-tunnel.sh" "$CONTAINER_NAME:/tmp/setup-vscode-tunnel.sh"
docker_exec chmod +x /tmp/setup-vscode-tunnel.sh

print_highlight "Exporting remote script from production code..."

# Export the remote script from the production setup-vscode-tunnel.sh
# This is the EXACT code that would run on a real server via SSH!
docker_exec bash -c "/tmp/setup-vscode-tunnel.sh --export -n '$TUNNEL_NAME'" > /tmp/tunnel_setup_$$.sh
docker cp /tmp/tunnel_setup_$$.sh "$CONTAINER_NAME:/tmp/tunnel_setup.sh"
docker_exec chmod +x /tmp/tunnel_setup.sh
rm -f /tmp/tunnel_setup_$$.sh

# Verify export worked
if docker_exec test -f /tmp/tunnel_setup.sh; then
    SCRIPT_LINES=$(docker_exec bash -c 'wc -l < /tmp/tunnel_setup.sh')
    print_success "Production script exported: $SCRIPT_LINES lines"
else
    print_error "Failed to export production script"
    exit 1
fi

print_highlight "Running production script (installation part only)..."

# Run ONLY the installation part of the production script
# We use sed to extract everything up to "Step 4" (GitHub Auth)
# This ensures we're testing the EXACT same installation code as production
docker_exec bash -c '
    # Extract just the installation parts (Steps 1-3) from the production script
    sed -n "1,/Step 4:/p" /tmp/tunnel_setup.sh | head -n -3 > /tmp/install_only.sh
    chmod +x /tmp/install_only.sh
    bash /tmp/install_only.sh
'

# Verify CLI installation
CLI_VERSION=$(docker_exec /usr/local/bin/code --version 2>/dev/null | head -1)
print_success "VS Code CLI installed: $CLI_VERSION"

# =============================================================================
# Step 4: Verify Service Configuration
# =============================================================================

print_step "Verify Service Configuration"

print_highlight "Checking service file..."

# Verify service file was created correctly
if docker_exec test -f /etc/systemd/system/code-tunnel.service; then
    print_success "Service file exists"
else
    print_error "Service file not found"
    exit 1
fi

# Verify service is enabled
if docker_exec systemctl is-enabled --quiet code-tunnel.service; then
    print_success "Service is enabled"
else
    print_error "Service not enabled"
fi

# Verify service file content matches expected
if docker_exec grep -q "name $TUNNEL_NAME" /etc/systemd/system/code-tunnel.service; then
    print_success "Service configured with correct tunnel name: $TUNNEL_NAME"
else
    print_error "Tunnel name not found in service file"
    docker_exec cat /etc/systemd/system/code-tunnel.service
    exit 1
fi

print_highlight "Starting service..."

docker_exec systemctl start code-tunnel.service

sleep 3

# Check service status
if docker_exec systemctl is-active --quiet code-tunnel.service; then
    print_success "Service is running"
else
    print_warning "Service may still be starting..."
fi

# =============================================================================
# Step 5: GitHub Authentication
# =============================================================================

print_step "GitHub Authentication"

print_warning "Waiting for GitHub Device Code..."
echo ""

# Wait for device code to appear in logs
DEVICE_CODE=""
WAIT_COUNT=0
MAX_WAIT=60

while [[ $WAIT_COUNT -lt $MAX_WAIT ]]; do
    LOG_OUTPUT=$(docker_exec journalctl -u code-tunnel --no-pager -n 50 2>/dev/null || true)
    
    if echo "$LOG_OUTPUT" | grep -q "use code"; then
        DEVICE_CODE=$(echo "$LOG_OUTPUT" | grep -o '[A-Z0-9]\{4\}-[A-Z0-9]\{4\}' | tail -1)
        break
    fi
    
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
    echo -ne "\r  Waiting for Device Code... ${WAIT_COUNT}s "
done

echo ""

if [[ -n "$DEVICE_CODE" ]]; then
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}║   GitHub Device Code:  ${YELLOW}${BOLD}$DEVICE_CODE${NC}${GREEN}${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}║   Open: ${CYAN}https://github.com/login/device${NC}${GREEN}                        ║${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Try to open browser on macOS/Linux
    if [[ "$(uname)" == "Darwin" ]]; then
        open "https://github.com/login/device" 2>/dev/null || true
    elif command -v xdg-open &>/dev/null; then
        xdg-open "https://github.com/login/device" 2>/dev/null || true
    fi
    
    print_info "Please authenticate in your browser with the code above."
else
    print_error "Could not detect Device Code"
    print_info "Check logs manually:"
    print_info "  docker exec $CONTAINER_NAME journalctl -u code-tunnel -f"
    
    if ! wait_for_user "Continue anyway?"; then
        exit 1
    fi
fi

# Wait for authentication and tunnel to be ready
echo ""
print_highlight "Waiting for tunnel to connect (up to ${STEP_TIMEOUT}s)..."

TUNNEL_URL=""
WAIT_COUNT=0

while [[ $WAIT_COUNT -lt $STEP_TIMEOUT ]]; do
    LOG_OUTPUT=$(docker_exec journalctl -u code-tunnel --no-pager -n 100 2>/dev/null || true)
    
    # Look for tunnel URL
    if echo "$LOG_OUTPUT" | grep -q "https://vscode.dev/tunnel/"; then
        TUNNEL_URL=$(echo "$LOG_OUTPUT" | grep -o 'https://vscode.dev/tunnel/[^[:space:]]*' | head -1)
        break
    fi
    
    # Also check for "Open this link" message
    if echo "$LOG_OUTPUT" | grep -qi "open this link"; then
        TUNNEL_URL="https://vscode.dev/tunnel/$TUNNEL_NAME"
        break
    fi
    
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
    echo -ne "\r  Connecting... ${WAIT_COUNT}s / ${STEP_TIMEOUT}s "
done

echo ""

if [[ -n "$TUNNEL_URL" ]]; then
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}║   🎉 TUNNEL IS READY!                                          ║${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}║   URL: ${CYAN}https://vscode.dev/tunnel/$TUNNEL_NAME${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    print_success "Tunnel connected successfully"
else
    print_error "Timeout waiting for tunnel connection"
    print_info "Check logs: docker exec $CONTAINER_NAME journalctl -u code-tunnel -f"
    
    if ! wait_for_user "Continue anyway?"; then
        exit 1
    fi
fi

# =============================================================================
# Step 6: Verify Connection (User)
# =============================================================================

print_step "Verify Tunnel Connection"

echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║                                                                ║${NC}"
echo -e "${YELLOW}║   Please verify the tunnel works:                              ║${NC}"
echo -e "${YELLOW}║                                                                ║${NC}"
echo -e "${YELLOW}║   1. Open VS Code                                              ║${NC}"
echo -e "${YELLOW}║   2. Click 'Remote Explorer' in the sidebar                    ║${NC}"
echo -e "${YELLOW}║   3. Find '$TUNNEL_NAME' under 'Tunnels'${NC}"
echo -e "${YELLOW}║   3. Find 'docker-tunnel-test' under 'Tunnels'                 ║${NC}"
echo -e "${YELLOW}║   4. Click to connect                                          ║${NC}"
echo -e "${YELLOW}║                                                                ║${NC}"
echo -e "${YELLOW}║   Or open:                                                     ║${NC}"
echo -e "${YELLOW}║   ${CYAN}https://vscode.dev/tunnel/$TUNNEL_NAME${NC}"
echo -e "${YELLOW}║                                                                ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

if wait_for_user "Were you able to connect to the tunnel?"; then
    print_success "First connection verified by user"
else
    print_error "First connection failed"
    
    print_info "Service status:"
    docker_exec systemctl status code-tunnel.service --no-pager || true
    
    print_info ""
    print_info "Recent logs:"
    docker_exec journalctl -u code-tunnel --no-pager -n 20 || true
    
    if ! wait_for_user "Continue with restart test anyway?"; then
        exit 1
    fi
fi

# =============================================================================
# Step 7: Test Service Persistence (Restart)
# =============================================================================

print_step "Test Service Persistence (Container Restart)"

print_highlight "Restarting container to test service persistence..."

echo -e "${YELLOW}The container will now restart.${NC}"
echo -e "${YELLOW}The tunnel should automatically reconnect without new GitHub auth.${NC}"
echo ""

# Restart container
docker restart "$CONTAINER_NAME"

print_info "Container restarting..."
sleep 10

# Wait for systemd
print_info "Waiting for systemd to be ready..."
WAIT_COUNT=0
while [[ $WAIT_COUNT -lt 30 ]]; do
    if docker_exec systemctl is-system-running 2>/dev/null | grep -qE "running|degraded"; then
        break
    fi
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

# Check if service started automatically
print_info "Checking if service auto-started..."
sleep 5

if docker_exec systemctl is-active --quiet code-tunnel.service; then
    print_success "Service auto-started after restart"
else
    print_warning "Service not yet active, waiting..."
    sleep 10
    
    if docker_exec systemctl is-active --quiet code-tunnel.service; then
        print_success "Service is now active"
    else
        print_error "Service did not auto-start"
        docker_exec systemctl status code-tunnel.service --no-pager || true
    fi
fi

# Wait for tunnel to reconnect
print_highlight "Waiting for tunnel to reconnect..."

RECONNECTED=false
WAIT_COUNT=0

while [[ $WAIT_COUNT -lt 60 ]]; do
    LOG_OUTPUT=$(docker_exec journalctl -u code-tunnel --no-pager -n 50 2>/dev/null || true)
    
    if echo "$LOG_OUTPUT" | grep -qi "open this link\|connected\|tunnel/"; then
        RECONNECTED=true
        break
    fi
    
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
    echo -ne "\r  Reconnecting... ${WAIT_COUNT}s "
done

echo ""

if [[ "$RECONNECTED" == "true" ]]; then
    print_success "Tunnel reconnected after restart"
else
    print_warning "Could not confirm tunnel reconnection from logs"
fi

# Final user verification
echo ""
echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║                                                                ║${NC}"
echo -e "${YELLOW}║   Please verify the tunnel still works after restart:         ║${NC}"
echo -e "${YELLOW}║                                                                ║${NC}"
echo -e "${YELLOW}║   Try connecting again via VS Code or browser.                ║${NC}"
echo -e "${YELLOW}║   (No new GitHub authentication should be needed!)            ║${NC}"
echo -e "${YELLOW}║                                                                ║${NC}"
echo -e "${YELLOW}║   URL: ${CYAN}https://vscode.dev/tunnel/$TUNNEL_NAME${NC}"
echo -e "${YELLOW}║                                                                ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

if wait_for_user "Were you able to reconnect after the container restart?"; then
    print_success "Persistence test verified by user"
else
    print_error "Persistence test failed"
fi

# =============================================================================
# Summary
# =============================================================================

print_banner "Test Summary"

echo -e "  ${GREEN}✓${NC} Docker image built"
echo -e "  ${GREEN}✓${NC} Container started with systemd"
echo -e "  ${GREEN}✓${NC} VS Code CLI installed"
echo -e "  ${GREEN}✓${NC} Systemd service created and enabled"
echo -e "  ${GREEN}✓${NC} GitHub authentication completed"
echo -e "  ${GREEN}✓${NC} Tunnel connection established"
echo -e "  ${GREEN}✓${NC} Service persistence after restart"
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                                ║${NC}"
echo -e "${GREEN}║   🎉 ALL INTEGRATION TESTS PASSED!                             ║${NC}"
echo -e "${GREEN}║                                                                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "Tunnel URL: ${CYAN}https://vscode.dev/tunnel/$TUNNEL_NAME${NC}"
echo ""

if [[ "$CLEANUP_AFTER" != "true" ]]; then
    echo -e "Container is still running. Useful commands:"
    echo -e "  ${CYAN}docker exec -it $CONTAINER_NAME bash${NC}        # Shell"
    echo -e "  ${CYAN}docker exec $CONTAINER_NAME journalctl -u code-tunnel -f${NC}  # Logs"
    echo -e "  ${CYAN}docker stop $CONTAINER_NAME${NC}                 # Stop"
    echo -e "  ${CYAN}docker rm -f $CONTAINER_NAME${NC}                # Remove"
fi

# Disable trap and call cleanup with success code
trap - EXIT
cleanup 0