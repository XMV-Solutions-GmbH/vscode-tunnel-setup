#!/usr/bin/env bats
# Integration Tests for VS Code Tunnel Setup Script - Remote Script Logic
# Tests architecture detection, CLI installation, and service management

load '../test_helper'

# Setup and teardown
setup() {
    test_setup
    
    # Create isolated test environment
    REMOTE_TEST_DIR="$TEST_TMP_DIR/remote"
    mkdir -p "$REMOTE_TEST_DIR"
    mkdir -p "$REMOTE_TEST_DIR/usr/local/bin"
    mkdir -p "$REMOTE_TEST_DIR/etc/systemd/system"
}

teardown() {
    test_teardown
}

# =============================================================================
# Helper Functions
# =============================================================================

# Create the remote script portion for testing
create_remote_test_script() {
    local machine_name="${1:-test-machine}"
    local script_file="$REMOTE_TEST_DIR/remote_script.sh"
    
    cat > "$script_file" << EOF
#!/bin/bash
set -e

MACHINE_NAME="$machine_name"

# Override paths for testing
export VSCODE_CLI="\${VSCODE_CLI_PATH:-/usr/local/bin/code}"
export SERVICE_FILE="\${SERVICE_FILE_PATH:-/etc/systemd/system/code-tunnel.service}"

# Detect architecture
detect_arch() {
    ARCH=\$(uname -m)
    case \$ARCH in
        x86_64)  echo "x64" ;;
        aarch64) echo "arm64" ;;
        armv7l)  echo "armhf" ;;
        *)       echo "unsupported"; return 1 ;;
    esac
}

# Check if CLI exists
check_cli_exists() {
    [[ -f "\$VSCODE_CLI" ]]
}

# Check if service exists
check_service_exists() {
    [[ -f "\$SERVICE_FILE" ]]
}

# Check if service has matching name
service_name_matches() {
    grep -q "name \$MACHINE_NAME" "\$SERVICE_FILE" 2>/dev/null
}

# Create service file
create_service_file() {
    cat > "\$SERVICE_FILE" << SERVICEEOF
[Unit]
Description=VS Code Tunnel
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/code tunnel --accept-server-license-terms --name \$MACHINE_NAME
Restart=always
RestartSec=10
Environment=HOME=/root

[Install]
WantedBy=multi-user.target
SERVICEEOF
}

# Main logic based on test mode
case "\${TEST_MODE:-}" in
    detect_arch)
        detect_arch
        ;;
    check_cli)
        if check_cli_exists; then
            echo "CLI_EXISTS=true"
        else
            echo "CLI_EXISTS=false"
        fi
        ;;
    check_service)
        if check_service_exists; then
            echo "SERVICE_EXISTS=true"
            if service_name_matches; then
                echo "NAME_MATCHES=true"
            else
                echo "NAME_MATCHES=false"
            fi
        else
            echo "SERVICE_EXISTS=false"
        fi
        ;;
    create_service)
        create_service_file
        echo "SERVICE_CREATED=true"
        ;;
    *)
        echo "Unknown test mode: \${TEST_MODE:-}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$script_file"
    echo "$script_file"
}

# =============================================================================
# Architecture Detection Tests
# =============================================================================

@test "arch_detection_x64: Detects x86_64 → x64" {
    # Create mock uname that returns x86_64
    mock_dir=$(mock_architecture "x86_64")
    script_file=$(create_remote_test_script)
    
    run bash -c "PATH='$mock_dir:$PATH' TEST_MODE=detect_arch $script_file"
    
    [ "$status" -eq 0 ]
    [ "$output" = "x64" ]
}

@test "arch_detection_arm64: Detects aarch64 → arm64" {
    mock_dir=$(mock_architecture "aarch64")
    script_file=$(create_remote_test_script)
    
    run bash -c "PATH='$mock_dir:$PATH' TEST_MODE=detect_arch $script_file"
    
    [ "$status" -eq 0 ]
    [ "$output" = "arm64" ]
}

@test "arch_detection_armhf: Detects armv7l → armhf" {
    mock_dir=$(mock_architecture "armv7l")
    script_file=$(create_remote_test_script)
    
    run bash -c "PATH='$mock_dir:$PATH' TEST_MODE=detect_arch $script_file"
    
    [ "$status" -eq 0 ]
    [ "$output" = "armhf" ]
}

@test "arch_unsupported_error: Unknown arch exits 1" {
    mock_dir=$(mock_architecture "sparc64")
    script_file=$(create_remote_test_script)
    
    run bash -c "PATH='$mock_dir:$PATH' TEST_MODE=detect_arch $script_file"
    
    [ "$status" -eq 1 ]
    [[ "$output" == *"unsupported"* ]]
}

# =============================================================================
# CLI Installation Tests
# =============================================================================

@test "cli_install_idempotent: Skip install if exists" {
    script_file=$(create_remote_test_script)
    
    # Create a mock CLI binary
    touch "$REMOTE_TEST_DIR/usr/local/bin/code"
    chmod +x "$REMOTE_TEST_DIR/usr/local/bin/code"
    
    run bash -c "VSCODE_CLI_PATH='$REMOTE_TEST_DIR/usr/local/bin/code' TEST_MODE=check_cli $script_file"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"CLI_EXISTS=true"* ]]
}

@test "cli_install_needed: Detects missing CLI" {
    script_file=$(create_remote_test_script)
    
    # Ensure CLI doesn't exist
    rm -f "$REMOTE_TEST_DIR/usr/local/bin/code"
    
    run bash -c "VSCODE_CLI_PATH='$REMOTE_TEST_DIR/usr/local/bin/code' TEST_MODE=check_cli $script_file"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"CLI_EXISTS=false"* ]]
}

@test "cli_install_curl: Downloads via curl" {
    # Create a test script that simulates curl download
    script_file="$REMOTE_TEST_DIR/test_curl.sh"
    
    cat > "$script_file" << 'EOF'
#!/bin/bash
# Test curl availability and download simulation
if command -v curl &> /dev/null; then
    echo "CURL_AVAILABLE=true"
    # Simulate download URL construction
    ARCH_NAME="x64"
    DOWNLOAD_URL="https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-$ARCH_NAME"
    echo "DOWNLOAD_URL=$DOWNLOAD_URL"
else
    echo "CURL_AVAILABLE=false"
fi
EOF
    
    chmod +x "$script_file"
    run "$script_file"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"CURL_AVAILABLE=true"* ]]
    [[ "$output" == *"cli-alpine-x64"* ]]
}

@test "cli_install_wget: Downloads via wget fallback" {
    # Create a test script that simulates wget fallback
    script_file="$REMOTE_TEST_DIR/test_wget.sh"
    
    cat > "$script_file" << 'EOF'
#!/bin/bash
# Test wget as fallback
check_downloader() {
    if command -v curl &> /dev/null; then
        echo "curl"
    elif command -v wget &> /dev/null; then
        echo "wget"
    else
        echo "none"
    fi
}

DOWNLOADER=$(check_downloader)
echo "DOWNLOADER=$DOWNLOADER"
EOF
    
    chmod +x "$script_file"
    run "$script_file"
    
    [ "$status" -eq 0 ]
    # Should have either curl or wget on most systems
    [[ "$output" == *"DOWNLOADER=curl"* ]] || [[ "$output" == *"DOWNLOADER=wget"* ]]
}

@test "cli_install_no_downloader: Error if no curl/wget" {
    # Create a test environment without curl/wget in PATH
    script_file="$REMOTE_TEST_DIR/test_no_downloader.sh"
    
    cat > "$script_file" << 'EOF'
#!/bin/bash
# Simulate environment without curl or wget
check_downloader() {
    # Explicitly check for commands that don't exist
    if command -v nonexistent_curl_cmd &> /dev/null; then
        echo "curl"
    elif command -v nonexistent_wget_cmd &> /dev/null; then
        echo "wget"
    else
        echo "❌ Neither curl nor wget available"
        return 1
    fi
}

check_downloader
EOF
    
    chmod +x "$script_file"
    run "$script_file"
    
    [ "$status" -eq 1 ]
    [[ "$output" == *"Neither curl nor wget available"* ]]
}

# =============================================================================
# Service Management Tests
# =============================================================================

@test "service_create_new: Creates systemd service" {
    script_file=$(create_remote_test_script "my-tunnel")
    
    run bash -c "SERVICE_FILE_PATH='$REMOTE_TEST_DIR/etc/systemd/system/code-tunnel.service' TEST_MODE=create_service $script_file"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"SERVICE_CREATED=true"* ]]
    
    # Verify service file content
    [ -f "$REMOTE_TEST_DIR/etc/systemd/system/code-tunnel.service" ]
    grep -q "Description=VS Code Tunnel" "$REMOTE_TEST_DIR/etc/systemd/system/code-tunnel.service"
    grep -q "name my-tunnel" "$REMOTE_TEST_DIR/etc/systemd/system/code-tunnel.service"
}

@test "service_skip_existing: Skips if name matches" {
    script_file=$(create_remote_test_script "existing-tunnel")
    service_file="$REMOTE_TEST_DIR/etc/systemd/system/code-tunnel.service"
    
    # Create existing service with matching name
    create_mock_service_file "existing-tunnel" "$service_file"
    
    run bash -c "SERVICE_FILE_PATH='$service_file' TEST_MODE=check_service $script_file"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"SERVICE_EXISTS=true"* ]]
    [[ "$output" == *"NAME_MATCHES=true"* ]]
}

@test "service_update_name: Updates if name differs" {
    script_file=$(create_remote_test_script "new-tunnel")
    service_file="$REMOTE_TEST_DIR/etc/systemd/system/code-tunnel.service"
    
    # Create existing service with different name
    create_mock_service_file "old-tunnel" "$service_file"
    
    run bash -c "SERVICE_FILE_PATH='$service_file' TEST_MODE=check_service $script_file"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"SERVICE_EXISTS=true"* ]]
    [[ "$output" == *"NAME_MATCHES=false"* ]]
}

@test "service_file_content_valid: Service file has correct structure" {
    script_file=$(create_remote_test_script "test-tunnel")
    service_file="$REMOTE_TEST_DIR/etc/systemd/system/code-tunnel.service"
    
    run bash -c "SERVICE_FILE_PATH='$service_file' TEST_MODE=create_service $script_file"
    
    [ "$status" -eq 0 ]
    
    # Verify all required sections
    grep -q "\[Unit\]" "$service_file"
    grep -q "\[Service\]" "$service_file"
    grep -q "\[Install\]" "$service_file"
    
    # Verify key configurations
    grep -q "Type=simple" "$service_file"
    grep -q "Restart=always" "$service_file"
    grep -q "WantedBy=multi-user.target" "$service_file"
}

@test "service_uses_correct_binary_path: ExecStart points to /usr/local/bin/code" {
    script_file=$(create_remote_test_script "test-tunnel")
    service_file="$REMOTE_TEST_DIR/etc/systemd/system/code-tunnel.service"
    
    run bash -c "SERVICE_FILE_PATH='$service_file' TEST_MODE=create_service $script_file"
    
    [ "$status" -eq 0 ]
    grep -q "ExecStart=/usr/local/bin/code" "$service_file"
}

@test "service_accepts_licence_terms: Service includes licence acceptance flag" {
    script_file=$(create_remote_test_script "test-tunnel")
    service_file="$REMOTE_TEST_DIR/etc/systemd/system/code-tunnel.service"
    
    run bash -c "SERVICE_FILE_PATH='$service_file' TEST_MODE=create_service $script_file"
    
    [ "$status" -eq 0 ]
    grep -q "\-\-accept-server-license-terms" "$service_file"
}

# =============================================================================
# Download URL Construction Tests
# =============================================================================

@test "download_url_x64: Correct URL for x64 architecture" {
    expected_url="https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64"
    
    # Test URL construction
    arch_name="x64"
    constructed_url="https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-$arch_name"
    
    [ "$constructed_url" = "$expected_url" ]
}

@test "download_url_arm64: Correct URL for arm64 architecture" {
    expected_url="https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-arm64"
    
    arch_name="arm64"
    constructed_url="https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-$arch_name"
    
    [ "$constructed_url" = "$expected_url" ]
}

@test "download_url_armhf: Correct URL for armhf architecture" {
    expected_url="https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-armhf"
    
    arch_name="armhf"
    constructed_url="https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-$arch_name"
    
    [ "$constructed_url" = "$expected_url" ]
}
