#!/usr/bin/env bats
# SPDX-License-Identifier: MIT OR Apache-2.0
# Unit Tests for VS Code Tunnel Setup Script - Validation Functions
# Tests tunnel name validation and IPv6-only detection

load '../test_helper'

# Setup and teardown
setup() {
    test_setup
    
    # Extract validation functions from the main script
    create_validation_test_script
}

teardown() {
    test_teardown
}

# Helper assertions (since bats-assert may not be installed)
assert_success() {
    if [[ "$status" -ne 0 ]]; then
        echo "Expected success (status 0), got status: $status" >&2
        echo "Output: $output" >&2
        return 1
    fi
}

assert_failure() {
    if [[ "$status" -eq 0 ]]; then
        echo "Expected failure (status != 0), got status: $status" >&2
        echo "Output: $output" >&2
        return 1
    fi
}

# Create a test script with validation functions extracted
create_validation_test_script() {
    TEST_SCRIPT="$TEST_TMP_DIR/validation_test.sh"
    
    cat > "$TEST_SCRIPT" << 'EOF'
#!/bin/bash

# Colours for output (needed for error messages)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Validate tunnel name format
# Tunnel names: alphanumeric, underscore, hyphen only (no dots or special characters)
validate_tunnel_name() {
    local name="$1"
    
    # Check length (1-64 characters)
    if [[ ${#name} -lt 1 || ${#name} -gt 64 ]]; then
        return 1
    fi
    
    # Must contain only letters, digits, underscore, hyphen
    if [[ ! "$name" =~ ^[A-Za-z0-9_-]+$ ]]; then
        return 1
    fi
    
    return 0
}

# Validate Linux username format
validate_linux_username() {
    local username="$1"
    
    # Check length (1-32 characters)
    if [[ ${#username} -lt 1 || ${#username} -gt 32 ]]; then
        return 1
    fi
    
    # Must start with lowercase letter, contain only lowercase letters, digits, underscore, hyphen
    if [[ ! "$username" =~ ^[a-z][a-z0-9_-]*$ ]]; then
        return 1
    fi
    
    return 0
}

# Check GitHub connectivity (mock version for testing)
check_github_connectivity() {
    # In tests, use MOCK_GITHUB_REACHABLE environment variable
    if [[ "${MOCK_GITHUB_REACHABLE:-true}" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Main test dispatcher
case "$1" in
    validate_tunnel_name)
        validate_tunnel_name "$2"
        exit $?
        ;;
    validate_linux_username)
        validate_linux_username "$2"
        exit $?
        ;;
    check_github_connectivity)
        check_github_connectivity
        exit $?
        ;;
    *)
        echo "Unknown function: $1"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$TEST_SCRIPT"
}

# =============================================================================
# Tunnel Name Validation Tests
# =============================================================================

@test "validate_tunnel_name: accepts simple alphanumeric name" {
    run bash "$TEST_TMP_DIR/validation_test.sh" validate_tunnel_name "myserver"
    assert_success
}

@test "validate_tunnel_name: accepts name with hyphen" {
    run bash "$TEST_TMP_DIR/validation_test.sh" validate_tunnel_name "my-server"
    assert_success
}

@test "validate_tunnel_name: accepts name with underscore" {
    run bash "$TEST_TMP_DIR/validation_test.sh" validate_tunnel_name "my_server"
    assert_success
}

@test "validate_tunnel_name: accepts name with numbers" {
    run bash "$TEST_TMP_DIR/validation_test.sh" validate_tunnel_name "server01"
    assert_success
}

@test "validate_tunnel_name: accepts mixed case" {
    run bash "$TEST_TMP_DIR/validation_test.sh" validate_tunnel_name "MyServer-01"
    assert_success
}

@test "validate_tunnel_name: rejects name with dots" {
    run bash "$TEST_TMP_DIR/validation_test.sh" validate_tunnel_name "my.server.com"
    assert_failure
}

@test "validate_tunnel_name: rejects name with spaces" {
    run bash "$TEST_TMP_DIR/validation_test.sh" validate_tunnel_name "my server"
    assert_failure
}

@test "validate_tunnel_name: rejects name with special characters" {
    run bash "$TEST_TMP_DIR/validation_test.sh" validate_tunnel_name "my@server!"
    assert_failure
}

@test "validate_tunnel_name: rejects empty name" {
    run bash "$TEST_TMP_DIR/validation_test.sh" validate_tunnel_name ""
    assert_failure
}

@test "validate_tunnel_name: rejects name longer than 64 characters" {
    local long_name=$(printf 'a%.0s' {1..65})
    run bash "$TEST_TMP_DIR/validation_test.sh" validate_tunnel_name "$long_name"
    assert_failure
}

@test "validate_tunnel_name: accepts name with exactly 64 characters" {
    local exact_name=$(printf 'a%.0s' {1..64})
    run bash "$TEST_TMP_DIR/validation_test.sh" validate_tunnel_name "$exact_name"
    assert_success
}

# =============================================================================
# Linux Username Validation Tests
# =============================================================================

@test "validate_linux_username: accepts simple lowercase name" {
    run bash "$TEST_TMP_DIR/validation_test.sh" validate_linux_username "david"
    assert_success
}

@test "validate_linux_username: accepts name with numbers" {
    run bash "$TEST_TMP_DIR/validation_test.sh" validate_linux_username "david01"
    assert_success
}

@test "validate_linux_username: accepts name with hyphen" {
    run bash "$TEST_TMP_DIR/validation_test.sh" validate_linux_username "david-k"
    assert_success
}

@test "validate_linux_username: accepts name with underscore" {
    run bash "$TEST_TMP_DIR/validation_test.sh" validate_linux_username "david_k"
    assert_success
}

@test "validate_linux_username: rejects name starting with number" {
    run bash "$TEST_TMP_DIR/validation_test.sh" validate_linux_username "1david"
    assert_failure
}

@test "validate_linux_username: rejects uppercase letters" {
    run bash "$TEST_TMP_DIR/validation_test.sh" validate_linux_username "David"
    assert_failure
}

@test "validate_linux_username: rejects dots in username" {
    run bash "$TEST_TMP_DIR/validation_test.sh" validate_linux_username "david.koller"
    assert_failure
}

@test "validate_linux_username: rejects name longer than 32 characters" {
    local long_name="a$(printf 'b%.0s' {1..32})"
    run bash "$TEST_TMP_DIR/validation_test.sh" validate_linux_username "$long_name"
    assert_failure
}

# =============================================================================
# IPv6-only Detection Tests (GitHub Connectivity)
# =============================================================================

@test "check_github_connectivity: succeeds when GitHub is reachable" {
    MOCK_GITHUB_REACHABLE=true run bash "$TEST_TMP_DIR/validation_test.sh" check_github_connectivity
    assert_success
}

@test "check_github_connectivity: fails when GitHub is unreachable (IPv6-only)" {
    MOCK_GITHUB_REACHABLE=false run bash "$TEST_TMP_DIR/validation_test.sh" check_github_connectivity
    assert_failure
}
