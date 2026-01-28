#!/usr/bin/env bash
# SPDX-License-Identifier: MIT OR Apache-2.0
# Test helper functions for VS Code Tunnel Setup Script tests
# Provides common utilities, setup, and teardown functions
# shellcheck disable=SC2155,SC2154

# Colours for test output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m'

# Test environment paths
export TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"
export SCRIPT_PATH="$PROJECT_ROOT/setup-vscode-tunnel.sh"
export FIXTURES_DIR="$TEST_DIR/fixtures"

# Docker configuration
export DOCKER_IMAGE_NAME="vscode-tunnel-test"
export DOCKER_CONTAINER_NAME="vscode-tunnel-test-server"
export MOCK_SSH_PORT="${MOCK_SSH_PORT:-2222}"
export MOCK_SSH_USER="testuser"
export MOCK_SSH_PASSWORD="testpass"

# Temporary directory for test artifacts
export TEST_TMP_DIR=""

# =============================================================================
# Setup and Teardown Functions
# =============================================================================

# Global setup - runs once before all tests in a file
global_setup() {
    # Create temporary directory for test artifacts
    TEST_TMP_DIR=$(mktemp -d)
    export TEST_TMP_DIR
}

# Global teardown - runs once after all tests in a file
global_teardown() {
    # Clean up temporary directory
    if [[ -n "$TEST_TMP_DIR" && -d "$TEST_TMP_DIR" ]]; then
        rm -rf "$TEST_TMP_DIR"
    fi
}

# Per-test setup
test_setup() {
    # Create fresh temp directory for each test
    TEST_TMP_DIR=$(mktemp -d)
    export TEST_TMP_DIR
}

# Per-test teardown
test_teardown() {
    # Clean up temp directory
    if [[ -n "$TEST_TMP_DIR" && -d "$TEST_TMP_DIR" ]]; then
        rm -rf "$TEST_TMP_DIR"
    fi
}

# =============================================================================
# Docker Helper Functions
# =============================================================================

# Build the mock server Docker image
build_mock_server() {
    docker build -t "$DOCKER_IMAGE_NAME" -f "$FIXTURES_DIR/Dockerfile.mock-server" "$FIXTURES_DIR"
}

# Start the mock server container
start_mock_server() {
    # Stop any existing container
    stop_mock_server 2>/dev/null || true
    
    docker run -d \
        --name "$DOCKER_CONTAINER_NAME" \
        -p "${MOCK_SSH_PORT}:22" \
        "$DOCKER_IMAGE_NAME"
    
    # Wait for SSH to be ready
    wait_for_ssh
}

# Stop the mock server container
stop_mock_server() {
    docker stop "$DOCKER_CONTAINER_NAME" 2>/dev/null || true
    docker rm "$DOCKER_CONTAINER_NAME" 2>/dev/null || true
}

# Wait for SSH to be available
wait_for_ssh() {
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if nc -z localhost "$MOCK_SSH_PORT" 2>/dev/null; then
            # SSH port is open, wait a bit more for service to be ready
            sleep 1
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    
    echo "Timeout waiting for SSH to be ready" >&2
    return 1
}

# Execute command in mock server
exec_in_container() {
    docker exec "$DOCKER_CONTAINER_NAME" "$@"
}

# Execute command via SSH to mock server
ssh_to_mock_server() {
    sshpass -p "$MOCK_SSH_PASSWORD" ssh \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -p "$MOCK_SSH_PORT" \
        "${MOCK_SSH_USER}@localhost" \
        "$@"
}

# =============================================================================
# Assertion Helper Functions
# =============================================================================

# Assert that output contains a string
assert_output_contains() {
    local expected="$1"
    if [[ "$output" != *"$expected"* ]]; then
        echo "Expected output to contain: $expected" >&2
        echo "Actual output: $output" >&2
        return 1
    fi
}

# Assert that output does not contain a string
assert_output_not_contains() {
    local unexpected="$1"
    if [[ "$output" == *"$unexpected"* ]]; then
        echo "Expected output NOT to contain: $unexpected" >&2
        echo "Actual output: $output" >&2
        return 1
    fi
}

# Assert that a file exists
assert_file_exists() {
    local file_path="$1"
    if [[ ! -f "$file_path" ]]; then
        echo "Expected file to exist: $file_path" >&2
        return 1
    fi
}

# Assert that a file does not exist
assert_file_not_exists() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        echo "Expected file NOT to exist: $file_path" >&2
        return 1
    fi
}

# Assert that a file contains a string
assert_file_contains() {
    local file_path="$1"
    local expected="$2"
    if ! grep -q "$expected" "$file_path" 2>/dev/null; then
        echo "Expected file $file_path to contain: $expected" >&2
        return 1
    fi
}

# Assert exit status
assert_status() {
    local expected="$1"
    if [[ "$status" -ne "$expected" ]]; then
        echo "Expected status: $expected, got: $status" >&2
        echo "Output: $output" >&2
        return 1
    fi
}

# =============================================================================
# Script Extraction Functions
# =============================================================================

# Extract the remote script portion from the main script
extract_remote_script() {
    # Extract REMOTE_SCRIPT content from main script
    sed -n "/^REMOTE_SCRIPT='/,/^'/p" "$SCRIPT_PATH" | \
        sed '1d;$d' | \
        sed "s/\$MACHINE_NAME/$1/g"
}

# Create a testable version of the script with mocked functions
create_test_script() {
    local output_file="$1"
    local machine_name="${2:-test-machine}"
    
    cat > "$output_file" << 'HEADER'
#!/bin/bash
set -e
HEADER
    
    # Add the remote script content
    extract_remote_script "$machine_name" >> "$output_file"
    
    chmod +x "$output_file"
}

# =============================================================================
# Mock Function Helpers
# =============================================================================

# Create a mock command that logs calls and returns specified output
create_mock_command() {
    local cmd_name="$1"
    local return_code="${2:-0}"
    local output="${3:-}"
    local mock_dir="$TEST_TMP_DIR/mocks"
    local log_file="$TEST_TMP_DIR/${cmd_name}_calls.log"
    
    mkdir -p "$mock_dir"
    
    cat > "$mock_dir/$cmd_name" << EOF
#!/bin/bash
echo "\$@" >> "$log_file"
echo "$output"
exit $return_code
EOF
    
    chmod +x "$mock_dir/$cmd_name"
    echo "$mock_dir"
}

# Get the call log for a mock command
get_mock_calls() {
    local cmd_name="$1"
    local log_file="$TEST_TMP_DIR/${cmd_name}_calls.log"
    
    if [[ -f "$log_file" ]]; then
        cat "$log_file"
    fi
}

# Check if mock command was called with specific arguments
mock_was_called_with() {
    local cmd_name="$1"
    local expected_args="$2"
    
    get_mock_calls "$cmd_name" | grep -q "$expected_args"
}

# =============================================================================
# Utility Functions
# =============================================================================

# Generate a random string for unique identifiers
generate_random_string() {
    local length="${1:-8}"
    LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c "$length"
}

# Check if Docker is available
docker_available() {
    command -v docker &>/dev/null && docker info &>/dev/null
}

# Skip test if Docker is not available
skip_if_no_docker() {
    if ! docker_available; then
        skip "Docker is not available"
    fi
}

# Create a minimal script for argument parsing tests
create_arg_parse_script() {
    local output_file="$1"
    
    # Extract only the argument parsing portion of the script
    head -n 70 "$SCRIPT_PATH" > "$output_file"
    
    # Remove the show_help exit and remote execution parts
    # Just test argument parsing
    chmod +x "$output_file"
}

# Print debug information
debug() {
    if [[ "${DEBUG:-}" == "true" ]]; then
        echo "DEBUG: $*" >&2
    fi
}

# =============================================================================
# Architecture Detection Helpers
# =============================================================================

# Simulate different architectures for testing
mock_architecture() {
    local arch="$1"
    local mock_dir="$TEST_TMP_DIR/mocks"
    
    mkdir -p "$mock_dir"
    
    cat > "$mock_dir/uname" << EOF
#!/bin/bash
if [[ "\$1" == "-m" ]]; then
    echo "$arch"
else
    /usr/bin/uname "\$@"
fi
EOF
    
    chmod +x "$mock_dir/uname"
    echo "$mock_dir"
}

# =============================================================================
# Service File Helpers
# =============================================================================

# Create a mock service file
create_mock_service_file() {
    local machine_name="$1"
    local output_file="$2"
    
    cat > "$output_file" << EOF
[Unit]
Description=VS Code Tunnel
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/code tunnel --accept-server-license-terms --name $machine_name
Restart=always
RestartSec=10
Environment=HOME=/root

[Install]
WantedBy=multi-user.target
EOF
}

# Verify service file has correct content
verify_service_file() {
    local service_file="$1"
    local expected_name="$2"
    
    assert_file_exists "$service_file"
    assert_file_contains "$service_file" "Description=VS Code Tunnel"
    assert_file_contains "$service_file" "name $expected_name"
    assert_file_contains "$service_file" "WantedBy=multi-user.target"
}
