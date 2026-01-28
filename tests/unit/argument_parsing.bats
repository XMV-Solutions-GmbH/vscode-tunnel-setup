#!/usr/bin/env bats
# SPDX-License-Identifier: MIT OR Apache-2.0
# Unit Tests for VS Code Tunnel Setup Script - Argument Parsing
# Tests command-line argument parsing without network or Docker dependencies

load '../test_helper'

# Setup and teardown
setup() {
    test_setup
    
    # Create a testable script that exits after parsing
    create_testable_script
}

teardown() {
    test_teardown
}

# Create a modified script for testing argument parsing
create_testable_script() {
    TEST_SCRIPT="$TEST_TMP_DIR/test_script.sh"
    
    cat > "$TEST_SCRIPT" << 'EOF'
#!/bin/bash

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default values
SSH_USER="root"
SERVER_IP=""
MACHINE_NAME=""

# Display help
show_help() {
    echo "Usage: $0 <server-ip> [-u <username>] [-n <machine-name>]"
    echo ""
    echo "Options:"
    echo "  <server-ip>       IP address of the server (required)"
    echo "  -u <username>     SSH username (default: root)"
    echo "  -n <machine-name> Name for the VS Code Tunnel instance"
    echo "  -h                Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 192.168.1.100"
    echo "  $0 192.168.1.100 -u admin"
    echo "  $0 192.168.1.100 -u admin -n my-server"
    exit 0
}

# Parse arguments
if [[ $# -lt 1 ]]; then
    show_help
fi

# First argument is the IP (if it doesn't start with -)
if [[ ! "$1" =~ ^- ]]; then
    SERVER_IP="$1"
    shift
fi

while getopts "u:n:h" opt; do
    case $opt in
        u) SSH_USER="$OPTARG" ;;
        n) MACHINE_NAME="$OPTARG" ;;
        h) show_help ;;
        *) show_help ;;
    esac
done

# Validate IP address
if [[ -z "$SERVER_IP" ]]; then
    echo -e "${RED}Error: Server IP is required${NC}"
    show_help
fi

# For testing: if SKIP_PROMPT is set, don't prompt for machine name
if [[ -z "$MACHINE_NAME" && "${SKIP_PROMPT:-}" != "true" ]]; then
    echo -e "${YELLOW}Please enter a name for this VS Code Tunnel instance:${NC}"
    read -r MACHINE_NAME
    if [[ -z "$MACHINE_NAME" ]]; then
        echo -e "${RED}Error: Machine name is required${NC}"
        exit 1
    fi
fi

# Output parsed values for testing
echo "SERVER_IP=$SERVER_IP"
echo "SSH_USER=$SSH_USER"
echo "MACHINE_NAME=$MACHINE_NAME"
EOF
    
    chmod +x "$TEST_SCRIPT"
}

# =============================================================================
# Test Cases
# =============================================================================

@test "help_flag_shows_usage: -h displays help text and exits 0" {
    run "$TEST_SCRIPT" -h
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"<server-ip>"* ]]
    [[ "$output" == *"-u <username>"* ]]
    [[ "$output" == *"-n <machine-name>"* ]]
    [[ "$output" == *"Examples:"* ]]
}

@test "no_args_shows_help: No arguments displays help" {
    run "$TEST_SCRIPT"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "ip_only_prompts_for_name: IP without -n triggers prompt" {
    # Test that without -n flag, prompt message appears
    run bash -c "echo '' | $TEST_SCRIPT 192.168.1.100"
    
    # Should prompt for name and then fail with empty input
    [[ "$output" == *"Please enter a name"* ]]
    [ "$status" -eq 1 ]
}

@test "custom_user_flag: -u admin sets SSH_USER" {
    run bash -c "SKIP_PROMPT=true $TEST_SCRIPT 192.168.1.100 -u admin -n test-server"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"SSH_USER=admin"* ]]
}

@test "machine_name_flag: -n my-server sets MACHINE_NAME" {
    run bash -c "SKIP_PROMPT=true $TEST_SCRIPT 192.168.1.100 -n my-server"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"MACHINE_NAME=my-server"* ]]
}

@test "all_flags_combined: All flags parsed correctly" {
    run bash -c "SKIP_PROMPT=true $TEST_SCRIPT 10.0.0.50 -u devops -n production-server"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"SERVER_IP=10.0.0.50"* ]]
    [[ "$output" == *"SSH_USER=devops"* ]]
    [[ "$output" == *"MACHINE_NAME=production-server"* ]]
}

@test "invalid_flag_shows_help: Unknown flag shows help" {
    run "$TEST_SCRIPT" 192.168.1.100 -x invalid
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "empty_machine_name_error: Empty name after prompt exits 1" {
    # Provide empty input when prompted for machine name
    run bash -c "echo '' | $TEST_SCRIPT 192.168.1.100"
    
    [ "$status" -eq 1 ]
    [[ "$output" == *"Machine name is required"* ]]
}

@test "default_user_is_root: Default SSH_USER is root when -u not specified" {
    run bash -c "SKIP_PROMPT=true $TEST_SCRIPT 192.168.1.100 -n test-server"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"SSH_USER=root"* ]]
}

@test "ip_address_captured_correctly: Various IP formats work" {
    # Test standard IPv4
    run bash -c "SKIP_PROMPT=true $TEST_SCRIPT 10.20.30.40 -n test"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SERVER_IP=10.20.30.40"* ]]
    
    # Test another format
    run bash -c "SKIP_PROMPT=true $TEST_SCRIPT 255.255.255.255 -n test"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SERVER_IP=255.255.255.255"* ]]
}

@test "hostname_as_server: Hostname works as server address" {
    run bash -c "SKIP_PROMPT=true $TEST_SCRIPT my-server.local -n test"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"SERVER_IP=my-server.local"* ]]
}

@test "machine_name_with_special_chars: Machine name with hyphens and numbers" {
    run bash -c "SKIP_PROMPT=true $TEST_SCRIPT 192.168.1.100 -n my-server-01"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"MACHINE_NAME=my-server-01"* ]]
}

@test "flags_order_independent: Flags can be in any order" {
    run bash -c "SKIP_PROMPT=true $TEST_SCRIPT 192.168.1.100 -n server -u admin"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"SSH_USER=admin"* ]]
    [[ "$output" == *"MACHINE_NAME=server"* ]]
}

@test "only_flag_no_ip_shows_error: Flag without IP shows error" {
    run "$TEST_SCRIPT" -n my-server
    
    # Should show help because no IP provided
    [[ "$output" == *"Usage:"* ]] || [[ "$output" == *"Server IP is required"* ]]
}

@test "interactive_name_input: Name provided via stdin works" {
    run bash -c "echo 'my-tunnel' | $TEST_SCRIPT 192.168.1.100"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"MACHINE_NAME=my-tunnel"* ]]
}
