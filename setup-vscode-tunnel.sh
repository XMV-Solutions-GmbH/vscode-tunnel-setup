#!/bin/bash
# SPDX-License-Identifier: MIT OR Apache-2.0
set -e

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Colour

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

# Prompt for machine name if not provided
if [[ -z "$MACHINE_NAME" ]]; then
    echo -e "${YELLOW}Please enter a name for this VS Code Tunnel instance:${NC}"
    read -r MACHINE_NAME
    if [[ -z "$MACHINE_NAME" ]]; then
        echo -e "${RED}Error: Machine name is required${NC}"
        exit 1
    fi
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}VS Code Tunnel Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${CYAN}Server:${NC} $SSH_USER@$SERVER_IP"
echo -e "${CYAN}Maschinenname:${NC} $MACHINE_NAME"
echo -e "${BLUE}========================================${NC}"
echo ""

# Remote script to be executed on the server
# shellcheck disable=SC2016
REMOTE_SCRIPT='

MACHINE_NAME="'"$MACHINE_NAME"'"

echo "🔍 Checking system..."

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)  ARCH_NAME="x64" ;;
    aarch64) ARCH_NAME="arm64" ;;
    armv7l)  ARCH_NAME="armhf" ;;
    *)       echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "📦 Architecture: $ARCH_NAME"

# Check if VS Code CLI is already installed
VSCODE_CLI="/usr/local/bin/code"
INSTALL_NEEDED=false

if [[ -f "$VSCODE_CLI" ]]; then
    echo "✅ VS Code CLI already installed"
else
    INSTALL_NEEDED=true
fi

if $INSTALL_NEEDED; then
    echo "📥 Installing VS Code CLI..."
    
    # Temporary directory
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    
    # Download
    DOWNLOAD_URL="https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-$ARCH_NAME"
    echo "📥 Downloading from: $DOWNLOAD_URL"
    
    if command -v curl &> /dev/null; then
        curl -L "$DOWNLOAD_URL" -o vscode_cli.tar.gz
    elif command -v wget &> /dev/null; then
        wget -O vscode_cli.tar.gz "$DOWNLOAD_URL"
    else
        echo "❌ Neither curl nor wget available"
        exit 1
    fi
    
    # Extract
    tar -xzf vscode_cli.tar.gz
    
    # Install
    sudo mv code /usr/local/bin/code 2>/dev/null || mv code /usr/local/bin/code
    chmod +x /usr/local/bin/code
    
    # Clean up
    cd /
    rm -rf "$TMP_DIR"
    
    echo "✅ VS Code CLI installed"
fi

# Check if systemd service exists
SERVICE_FILE="/etc/systemd/system/code-tunnel.service"
SERVICE_NEEDED=false

if [[ -f "$SERVICE_FILE" ]]; then
    # Check if the name matches
    if grep -q "name $MACHINE_NAME" "$SERVICE_FILE"; then
        echo "✅ Systemd service already configured"
    else
        echo "⚠️  Service exists with different name, updating..."
        SERVICE_NEEDED=true
    fi
else
    SERVICE_NEEDED=true
fi

if $SERVICE_NEEDED; then
    echo "🔧 Creating systemd service..."
    
    # Create service file
    sudo tee "$SERVICE_FILE" > /dev/null << SERVICEEOF
[Unit]
Description=VS Code Tunnel
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/code tunnel --accept-server-license-terms --name $MACHINE_NAME
Restart=always
RestartSec=10
Environment=HOME=/root

[Install]
WantedBy=multi-user.target
SERVICEEOF

    # Reload systemd
    sudo systemctl daemon-reload
    sudo systemctl enable code-tunnel.service
    
    echo "✅ Systemd service created and enabled"
fi

# Check if already authenticated
echo ""
echo "🔐 Starting VS Code Tunnel for authentication..."
echo ""

# Stop any existing tunnel process
sudo systemctl stop code-tunnel.service 2>/dev/null || true
sleep 2

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  The GitHub Device Code will appear below.                     ║"
echo "║  Open: https://github.com/login/device                         ║"
echo "║  Enter the code and authenticate with GitHub.                  ║"
echo "║                                                                ║"
echo "║  After authenticating, press Ctrl+C to continue.               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# First set GitHub as the auth provider
/usr/local/bin/code tunnel user login --provider github || true

# Run tunnel in foreground - user sees output directly and presses Ctrl+C when done
/usr/local/bin/code tunnel --accept-server-license-terms --name "$MACHINE_NAME" || true

echo ""

echo ""
echo "=========================================="
echo "🚀 Starting tunnel as service..."
echo "=========================================="

# Start service
sudo systemctl start code-tunnel.service

# Check status
sleep 3
if sudo systemctl is-active --quiet code-tunnel.service; then
    echo ""
    echo "✅ VS Code Tunnel is running!"
    echo ""
    echo "=========================================="
    echo "🎉 COMPLETE!"
    echo "=========================================="
    echo ""
    echo "Open VS Code and connect via:"
    echo "  1. Remote Explorer → Tunnels"
    echo "  2. Or: vscode.dev/tunnel/$MACHINE_NAME"
    echo ""
else
    echo "❌ Service could not be started"
    sudo systemctl status code-tunnel.service
    exit 1
fi

echo ""
echo "Press ENTER to close this session..."
read -r
'

# Establish SSH connection and execute script
echo -e "${GREEN}🔗 Connecting to $SSH_USER@$SERVER_IP...${NC}"
echo ""

ssh -t "$SSH_USER@$SERVER_IP" "$REMOTE_SCRIPT"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Setup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${CYAN}Connect via:${NC}"
echo -e "  ${YELLOW}https://vscode.dev/tunnel/$MACHINE_NAME${NC}"
echo ""
echo -e "${CYAN}Or in VS Code Desktop:${NC}"
echo -e "  Remote Explorer → Tunnels → $MACHINE_NAME"
echo ""
