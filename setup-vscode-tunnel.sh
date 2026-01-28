#!/bin/bash
# SPDX-License-Identifier: MIT OR Apache-2.0
# =============================================================================
# VS Code Tunnel Setup Script
# =============================================================================
# Sets up VS Code CLI and systemd tunnel service on a remote server via SSH.
# Can also export the remote script for manual execution or testing.
#
# Usage:
#   ./setup-vscode-tunnel.sh <server-ip> [-u <username>] [-n <machine-name>]
#   ./setup-vscode-tunnel.sh --export [-n <machine-name>]
#   ./setup-vscode-tunnel.sh --export-script
#
# =============================================================================

set -e

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Colour

# Default values
SSH_USER="root"
SSH_PORT=""
SSH_IDENTITY=""
SSH_FORCE_HOST_KEY=false
SERVER_IP=""
MACHINE_NAME=""
EXPORT_MODE=false
EXPORT_SCRIPT_ONLY=false

# Display help
show_help() {
    echo "Usage: $0 <server-ip> [-u <username>] [-n <machine-name>] [-p <port>] [-i <keyfile>] [-f]"
    echo "       $0 --export [-n <machine-name>] [-u <username>]"
    echo "       $0 --export-script"
    echo ""
    echo "Options:"
    echo "  <server-ip>       IP address or hostname of the server (required for SSH mode)"
    echo "  -u <username>     SSH username and service user (default: root)"
    echo "                    If user doesn't exist, script will connect as root,"
    echo "                    create the user, and copy SSH keys automatically."
    echo "  -n <machine-name> Name for the VS Code Tunnel instance"
    echo "  -p <port>         SSH port (default: 22)"
    echo "  -i <keyfile>      Path to SSH private key file"
    echo "  -f                Force: skip host key verification (useful for reinstalled servers)"
    echo "  --export          Export the remote script with machine name for copy/paste"
    echo "  --export-script   Export only the core script function (for testing)"
    echo "  -h, --help        Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 192.168.1.100 -n my-server"
    echo "  $0 192.168.1.100 -u vscode -n my-server     # Creates user 'vscode' if needed"
    echo "  $0 server.example.com -p 2222 -n my-server  # Custom SSH port"
    echo "  $0 server.example.com -i ~/.ssh/id_ed25519 -n my-server"
    echo "  $0 server.example.com -f -n my-server       # Skip host key check"
    exit 0
}

# Parse arguments
if [[ $# -lt 1 ]]; then
    show_help
fi

# Check for --export and --export-script first
for arg in "$@"; do
    case "$arg" in
        --export)
            EXPORT_MODE=true
            ;;
        --export-script)
            EXPORT_SCRIPT_ONLY=true
            ;;
        --help)
            show_help
            ;;
    esac
done

# First argument is the IP (if it doesn't start with -)
if [[ ! "$1" =~ ^- ]]; then
    SERVER_IP="$1"
    shift
fi

while getopts "u:n:p:i:fh-:" opt; do
    case $opt in
        u) SSH_USER="$OPTARG" ;;
        n) MACHINE_NAME="$OPTARG" ;;
        p) SSH_PORT="$OPTARG" ;;
        i) SSH_IDENTITY="$OPTARG" ;;
        f) SSH_FORCE_HOST_KEY=true ;;
        h) show_help ;;
        -)
            case "${OPTARG}" in
                export|export-script|help) ;; # Already handled
                *) show_help ;;
            esac
            ;;
        *) show_help ;;
    esac
done

# Validate arguments based on mode
if [[ "$EXPORT_SCRIPT_ONLY" == "true" ]]; then
    # Export script mode - no validation needed
    :
elif [[ "$EXPORT_MODE" == "true" ]]; then
    # Export mode - only need machine name
    if [[ -z "$MACHINE_NAME" ]]; then
        echo -e "${YELLOW}Please enter a name for this VS Code Tunnel instance:${NC}" >&2
        read -r MACHINE_NAME
        if [[ -z "$MACHINE_NAME" ]]; then
            echo -e "${RED}Error: Machine name is required${NC}" >&2
            exit 1
        fi
    fi
elif [[ -z "$SERVER_IP" ]]; then
    echo -e "${RED}Error: Server IP is required (or use --export mode)${NC}"
    show_help
fi

# Validate Linux username format
# Linux usernames: lowercase, start with letter, can contain letters, digits, underscore, hyphen
# Max 32 chars, no dots or special characters
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

if [[ "$SSH_USER" != "root" ]] && ! validate_linux_username "$SSH_USER"; then
    echo -e "${RED}Error: Invalid Linux username '$SSH_USER'${NC}"
    echo -e "${RED}  Linux usernames must:${NC}"
    echo -e "${RED}    - Start with a lowercase letter${NC}"
    echo -e "${RED}    - Contain only lowercase letters, digits, underscore (_), or hyphen (-)${NC}"
    echo -e "${RED}    - Be 1-32 characters long${NC}"
    echo -e "${RED}    - NOT contain dots, spaces, or uppercase letters${NC}"
    echo ""
    echo -e "${YELLOW}Suggestion: Use 'dkoller' or 'david-koller' instead of 'david.koller'${NC}"
    exit 1
fi

# Prompt for machine name if not provided (SSH mode)
if [[ "$EXPORT_MODE" != "true" && "$EXPORT_SCRIPT_ONLY" != "true" && -z "$MACHINE_NAME" ]]; then
    echo -e "${YELLOW}Please enter a name for this VS Code Tunnel instance:${NC}"
    read -r MACHINE_NAME
    if [[ -z "$MACHINE_NAME" ]]; then
        echo -e "${RED}Error: Machine name is required${NC}"
        exit 1
    fi
fi

# Build SSH options array
build_ssh_opts() {
    local opts=()
    
    if [[ -n "$SSH_PORT" ]]; then
        opts+=(-p "$SSH_PORT")
    fi
    
    if [[ -n "$SSH_IDENTITY" ]]; then
        opts+=(-i "$SSH_IDENTITY")
    fi
    
    if [[ "$SSH_FORCE_HOST_KEY" == "true" ]]; then
        opts+=(-o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null")
    fi
    
    echo "${opts[@]}"
}

# SSH command wrapper (non-interactive)
ssh_cmd() {
    local user="$1"
    local host="$2"
    shift 2
    local opts
    opts=$(build_ssh_opts)
    
    # shellcheck disable=SC2086
    ssh $opts "$user@$host" "$@"
}

# SSH command wrapper (interactive with TTY)
ssh_cmd_tty() {
    local user="$1"
    local host="$2"
    shift 2
    local opts
    opts=$(build_ssh_opts)
    
    # shellcheck disable=SC2086
    ssh -t $opts "$user@$host" "$@"
}

# SSH test command (batch mode, with timeout)
ssh_test() {
    local user="$1"
    local host="$2"
    local opts
    opts=$(build_ssh_opts)
    
    # shellcheck disable=SC2086
    ssh -o BatchMode=yes -o ConnectTimeout=10 $opts "$user@$host" "echo ok" &>/dev/null
}

# =============================================================================
# Remote Script Definition
# =============================================================================
# This is the core script that runs on the target machine.
# It can be executed via SSH, exported for copy/paste, or used by tests.
# =============================================================================

generate_remote_script() {
    local machine_name="$1"
    local run_as_user="${2:-root}"
    
    cat << 'REMOTE_SCRIPT_EOF'
#!/bin/bash
# =============================================================================
# VS Code Tunnel Remote Setup Script
# =============================================================================
# This script is designed to be executed on the target machine.
# It installs VS Code CLI and configures the systemd tunnel service.
# =============================================================================

set -e

REMOTE_SCRIPT_EOF

    # Inject machine name and user variables
    echo "MACHINE_NAME=\"$machine_name\""
    echo "RUN_AS_USER=\"$run_as_user\""
    echo ""
    
    # The rest of the script (static part)
    cat << 'REMOTE_SCRIPT_EOF'

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

print_step() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

print_success() {
    echo "✓ $1"
}

print_error() {
    echo "✗ $1"
}

print_info() {
    echo "  $1"
}

# -----------------------------------------------------------------------------
# Step 1: Detect Architecture
# -----------------------------------------------------------------------------

print_step "Detecting System Architecture"

ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH_NAME="x64"
        ;;
    aarch64)
        ARCH_NAME="arm64"
        ;;
    armv7l)
        ARCH_NAME="armhf"
        ;;
    *)
        print_error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

print_success "Architecture: $ARCH → $ARCH_NAME"

# -----------------------------------------------------------------------------
# Step 2: Install VS Code CLI
# -----------------------------------------------------------------------------

print_step "Installing VS Code CLI"

VSCODE_CLI="/usr/local/bin/code"

if [[ -f "$VSCODE_CLI" ]]; then
    CLI_VERSION=$("$VSCODE_CLI" --version 2>/dev/null | head -1 || echo "unknown")
    print_success "VS Code CLI already installed: $CLI_VERSION"
else
    print_info "Downloading VS Code CLI..."
    
    DOWNLOAD_URL="https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-$ARCH_NAME"
    TMP_DIR=$(mktemp -d)
    
    cd "$TMP_DIR"
    
    if command -v curl &> /dev/null; then
        curl -L "$DOWNLOAD_URL" -o vscode_cli.tar.gz
    elif command -v wget &> /dev/null; then
        wget -O vscode_cli.tar.gz "$DOWNLOAD_URL"
    else
        print_error "Neither curl nor wget available"
        exit 1
    fi
    
    print_info "Extracting..."
    tar -xzf vscode_cli.tar.gz
    
    print_info "Installing to /usr/local/bin/code..."
    if [[ -w /usr/local/bin ]]; then
        mv code /usr/local/bin/code
    else
        sudo mv code /usr/local/bin/code
    fi
    chmod +x /usr/local/bin/code
    
    # Clean up
    cd /
    rm -rf "$TMP_DIR"
    
    CLI_VERSION=$(/usr/local/bin/code --version 2>/dev/null | head -1 || echo "installed")
    print_success "VS Code CLI installed: $CLI_VERSION"
fi

# -----------------------------------------------------------------------------
# Step 3: Create Systemd Service
# -----------------------------------------------------------------------------

print_step "Configuring Systemd Service"

SERVICE_FILE="/etc/systemd/system/code-tunnel.service"
SERVICE_NEEDED=false

# Determine home directory for the service user
if [[ "$RUN_AS_USER" == "root" ]]; then
    SERVICE_USER_HOME="/root"
else
    SERVICE_USER_HOME=$(getent passwd "$RUN_AS_USER" | cut -d: -f6 || echo "/home/$RUN_AS_USER")
fi

if [[ -f "$SERVICE_FILE" ]]; then
    if grep -q "name $MACHINE_NAME" "$SERVICE_FILE" && grep -q "User=$RUN_AS_USER" "$SERVICE_FILE"; then
        print_success "Systemd service already configured for '$MACHINE_NAME' (user: $RUN_AS_USER)"
    else
        print_info "Service exists with different config, updating..."
        SERVICE_NEEDED=true
    fi
else
    SERVICE_NEEDED=true
fi

if $SERVICE_NEEDED; then
    print_info "Creating service file (running as user: $RUN_AS_USER)..."
    
    SERVICE_CONTENT="[Unit]
Description=VS Code Tunnel
After=network.target

[Service]
Type=simple
User=$RUN_AS_USER
ExecStart=/usr/local/bin/code tunnel --accept-server-license-terms --name $MACHINE_NAME
Restart=always
RestartSec=10
Environment=HOME=$SERVICE_USER_HOME

[Install]
WantedBy=multi-user.target"

    if [[ -w /etc/systemd/system ]]; then
        echo "$SERVICE_CONTENT" > "$SERVICE_FILE"
    else
        echo "$SERVICE_CONTENT" | sudo tee "$SERVICE_FILE" > /dev/null
    fi
    
    print_info "Reloading systemd..."
    if command -v sudo &> /dev/null && [[ $EUID -ne 0 ]]; then
        sudo systemctl daemon-reload
        sudo systemctl enable code-tunnel.service
    else
        systemctl daemon-reload
        systemctl enable code-tunnel.service
    fi
    
    print_success "Systemd service created and enabled (user: $RUN_AS_USER)"
fi

# -----------------------------------------------------------------------------
# Step 4: Start Service & GitHub Authentication
# -----------------------------------------------------------------------------

print_step "Starting Service & GitHub Authentication"

# Stop any existing tunnel process
if command -v sudo &> /dev/null && [[ $EUID -ne 0 ]]; then
    sudo systemctl stop code-tunnel.service 2>/dev/null || true
else
    systemctl stop code-tunnel.service 2>/dev/null || true
fi
sleep 2

# Start the service (it will request GitHub auth)
print_info "Starting tunnel service..."
if command -v sudo &> /dev/null && [[ $EUID -ne 0 ]]; then
    sudo systemctl start code-tunnel.service
else
    systemctl start code-tunnel.service
fi

sleep 3

# Wait for device code to appear in logs
print_info "Waiting for GitHub Device Code..."

DEVICE_CODE=""
WAIT_COUNT=0
MAX_WAIT=60

while [[ $WAIT_COUNT -lt $MAX_WAIT ]]; do
    LOG_OUTPUT=$(journalctl -u code-tunnel --no-pager -n 50 2>/dev/null || true)
    
    if echo "$LOG_OUTPUT" | grep -q "use code"; then
        DEVICE_CODE=$(echo "$LOG_OUTPUT" | grep -o '[A-Z0-9]\{4\}-[A-Z0-9]\{4\}' | tail -1)
        break
    fi
    
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

if [[ -n "$DEVICE_CODE" ]]; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║   GitHub Device Code:  $DEVICE_CODE"
    echo "║"
    echo "║   Open: https://github.com/login/device"
    echo "║   Enter the code and authenticate with GitHub."
    echo "║"
    echo "║   Waiting for authentication (up to 180 seconds)..."
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
else
    print_error "Could not detect Device Code from service logs"
    print_info "Check logs: journalctl -u code-tunnel -f"
    exit 1
fi

# Wait for tunnel to connect (authentication complete)
TUNNEL_CONNECTED=false
WAIT_COUNT=0
MAX_WAIT=180

while [[ $WAIT_COUNT -lt $MAX_WAIT ]]; do
    LOG_OUTPUT=$(journalctl -u code-tunnel --no-pager -n 100 2>/dev/null || true)
    
    # Check for successful connection
    if echo "$LOG_OUTPUT" | grep -qi "open this link\|connected\|tunnel/"; then
        TUNNEL_CONNECTED=true
        break
    fi
    
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
    printf "\r  Waiting for authentication... %ds / %ds " "$WAIT_COUNT" "$MAX_WAIT"
done

echo ""

if [[ "$TUNNEL_CONNECTED" != "true" ]]; then
    print_error "Timeout waiting for tunnel connection"
    print_info "Check logs: journalctl -u code-tunnel -f"
    exit 1
fi

# -----------------------------------------------------------------------------
# Step 5: Verify Service Running
# -----------------------------------------------------------------------------

print_step "Verifying Tunnel Service"

sleep 3

# Check status
if systemctl is-active --quiet code-tunnel.service; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║"
    echo "║  🎉 VS Code Tunnel is running!"
    echo "║"
    echo "║  Connect via:"
    echo "║    • VS Code: Remote Explorer → Tunnels → $MACHINE_NAME"
    echo "║    • Browser: https://vscode.dev/tunnel/$MACHINE_NAME"
    echo "║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    print_success "Setup complete!"
else
    print_error "Service could not be started"
    systemctl status code-tunnel.service --no-pager || true
    exit 1
fi

echo ""
echo "Press ENTER to close this session..."
read -r
REMOTE_SCRIPT_EOF
}

# =============================================================================
# Export Script Only Mode (for testing)
# =============================================================================

if [[ "$EXPORT_SCRIPT_ONLY" == "true" ]]; then
    # Output the generate_remote_script function itself for sourcing
    declare -f generate_remote_script
    exit 0
fi

# =============================================================================
# Export Mode
# =============================================================================

if [[ "$EXPORT_MODE" == "true" ]]; then
    # Output the complete remote script for copy/paste or piping
    # In export mode, default to root if no user specified
    generate_remote_script "$MACHINE_NAME" "${SSH_USER:-root}"
    exit 0
fi

# =============================================================================
# SSH Mode (default)
# =============================================================================

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  ${BOLD}VS Code Tunnel Setup${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Server:       ${CYAN}$SSH_USER@$SERVER_IP${NC}"
if [[ -n "$SSH_PORT" ]]; then
    echo -e "  SSH Port:     ${CYAN}$SSH_PORT${NC}"
fi
if [[ -n "$SSH_IDENTITY" ]]; then
    echo -e "  SSH Key:      ${CYAN}$SSH_IDENTITY${NC}"
fi
echo -e "  Tunnel name:  ${CYAN}$MACHINE_NAME${NC}"
echo ""

# -----------------------------------------------------------------------------
# Check if user exists and handle user creation if needed
# -----------------------------------------------------------------------------

USER_EXISTS=true
USER_CREATED=false

# Test SSH connection with specified user
echo -e "${GREEN}🔗 Testing connection as $SSH_USER@$SERVER_IP...${NC}"
if ! ssh_test "$SSH_USER" "$SERVER_IP"; then
    USER_EXISTS=false
    echo -e "${YELLOW}⚠ Cannot connect as '$SSH_USER'${NC}"
    
    # Only try root fallback if user is not root
    if [[ "$SSH_USER" != "root" ]]; then
        echo -e "${YELLOW}  Trying to connect as root to create user...${NC}"
        
        if ! ssh_test "root" "$SERVER_IP"; then
            echo -e "${RED}✗ Cannot connect as root either.${NC}"
            echo -e "${RED}  Please ensure:${NC}"
            echo -e "${RED}    - User '$SSH_USER' exists on the server, or${NC}"
            echo -e "${RED}    - Root SSH access is available to create the user${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}✓ Connected as root${NC}"
        echo -e "${YELLOW}  Creating user '$SSH_USER'...${NC}"
        
        # Create user setup script
        USER_SETUP_SCRIPT=$(cat << 'USERSCRIPT'
#!/bin/bash
set -e
TARGET_USER="__TARGET_USER__"

# Check if user already exists
if id "$TARGET_USER" &>/dev/null; then
    echo "✓ User '$TARGET_USER' already exists"
    exit 0
fi

# Create user with home directory
useradd -m -s /bin/bash "$TARGET_USER"
echo "✓ User '$TARGET_USER' created"

# Get user's home directory
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

# Create .ssh directory for the user
mkdir -p "$USER_HOME/.ssh"
chmod 700 "$USER_HOME/.ssh"

# Copy root's authorized_keys to the new user
if [[ -f /root/.ssh/authorized_keys ]]; then
    cp /root/.ssh/authorized_keys "$USER_HOME/.ssh/authorized_keys"
    chmod 600 "$USER_HOME/.ssh/authorized_keys"
    chown -R "$TARGET_USER:$TARGET_USER" "$USER_HOME/.ssh"
    echo "✓ SSH keys copied from root to '$TARGET_USER'"
else
    echo "⚠ No /root/.ssh/authorized_keys found"
fi

# Add user to sudo group (for service management)
if command -v usermod &>/dev/null; then
    usermod -aG sudo "$TARGET_USER" 2>/dev/null || usermod -aG wheel "$TARGET_USER" 2>/dev/null || true
    echo "✓ User added to sudo group"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Please set a password for '$TARGET_USER' (required for sudo):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
passwd "$TARGET_USER"

echo ""
echo "✓ User setup complete"
USERSCRIPT
)
        # Replace placeholder with actual username
        USER_SETUP_SCRIPT="${USER_SETUP_SCRIPT//__TARGET_USER__/$SSH_USER}"
        
        # Copy script to server and execute with TTY
        echo "$USER_SETUP_SCRIPT" | ssh_cmd "root" "$SERVER_IP" "cat > /tmp/user_setup.sh && chmod +x /tmp/user_setup.sh"
        ssh_cmd_tty "root" "$SERVER_IP" "/tmp/user_setup.sh && rm /tmp/user_setup.sh"
        
        USER_CREATED=true
        echo -e "${GREEN}✓ User '$SSH_USER' created and SSH keys copied${NC}"
        
        # Verify we can now connect as the new user
        sleep 1
        if ! ssh_test "$SSH_USER" "$SERVER_IP"; then
            echo -e "${RED}✗ Still cannot connect as '$SSH_USER' after creation${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓ Connection as '$SSH_USER' verified${NC}"
    else
        echo -e "${RED}✗ Cannot connect as root@$SERVER_IP${NC}"
        exit 1
    fi
fi

echo ""

# Generate the remote script with the target user
REMOTE_SCRIPT=$(generate_remote_script "$MACHINE_NAME" "$SSH_USER")

# -----------------------------------------------------------------------------
# Background job: Poll for device code and open browser + clipboard locally
# -----------------------------------------------------------------------------
(
    sleep 8  # Wait for service to start
    
    for _ in {1..30}; do
        # Fetch device code from server
        DEVICE_CODE=$(ssh_cmd "$SSH_USER" "$SERVER_IP" "journalctl -u code-tunnel --no-pager -n 50 2>/dev/null | grep -o '[A-Z0-9]\{4\}-[A-Z0-9]\{4\}' | tail -1" 2>/dev/null)
        
        if [[ -n "$DEVICE_CODE" && "$DEVICE_CODE" =~ ^[A-Z0-9]{4}-[A-Z0-9]{4}$ ]]; then
            # Copy to clipboard (macOS)
            if command -v pbcopy &>/dev/null; then
                echo -n "$DEVICE_CODE" | pbcopy
            # Copy to clipboard (Linux with xclip)
            elif command -v xclip &>/dev/null; then
                echo -n "$DEVICE_CODE" | xclip -selection clipboard
            # Copy to clipboard (Linux with xsel)
            elif command -v xsel &>/dev/null; then
                echo -n "$DEVICE_CODE" | xsel --clipboard --input
            fi
            
            # Open browser (macOS)
            if command -v open &>/dev/null; then
                open "https://github.com/login/device"
            # Open browser (Linux)
            elif command -v xdg-open &>/dev/null; then
                xdg-open "https://github.com/login/device" &>/dev/null
            fi
            
            break
        fi
        
        sleep 2
    done
) &
DEVICE_CODE_PID=$!

# Establish SSH connection and execute script
echo -e "${GREEN}🔗 Connecting to $SSH_USER@$SERVER_IP...${NC}"
echo ""

ssh_cmd_tty "$SSH_USER" "$SERVER_IP" "$REMOTE_SCRIPT"

# Clean up background job if still running
kill $DEVICE_CODE_PID 2>/dev/null || true

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}  ${BOLD}✅ Setup complete!${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Connect via:"
echo -e "    ${CYAN}https://vscode.dev/tunnel/$MACHINE_NAME${NC}"
echo ""
echo -e "  Or in VS Code Desktop:"
echo -e "    Remote Explorer → Tunnels → ${CYAN}$MACHINE_NAME${NC}"
echo ""
