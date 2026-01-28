#!/bin/bash
# Mock VS Code CLI for testing
# Simulates the VS Code CLI without requiring actual authentication

VERSION="1.0.0-mock"
MOCK_DEVICE_CODE="MOCK-1234-ABCD"
MOCK_TUNNEL_URL="https://vscode.dev/tunnel/mock-tunnel"

# Parse arguments
ACCEPT_LICENCE=false
TUNNEL_NAME=""
ACTION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        tunnel)
            ACTION="tunnel"
            shift
            ;;
        --accept-server-license-terms)
            ACCEPT_LICENCE=true
            shift
            ;;
        --name)
            TUNNEL_NAME="$2"
            shift 2
            ;;
        --version|-v)
            echo "VS Code CLI Mock v$VERSION"
            exit 0
            ;;
        --help|-h)
            echo "VS Code CLI Mock - For Testing Only"
            echo ""
            echo "Usage: code <command> [options]"
            echo ""
            echo "Commands:"
            echo "  tunnel    Start a VS Code tunnel"
            echo ""
            echo "Options:"
            echo "  --accept-server-license-terms  Accept the server licence terms"
            echo "  --name <name>                  Name for the tunnel"
            echo "  --version, -v                  Show version"
            echo "  --help, -h                     Show this help"
            exit 0
            ;;
        *)
            # Unknown option, ignore for mock
            shift
            ;;
    esac
done

# Handle tunnel action
if [[ "$ACTION" == "tunnel" ]]; then
    if [[ "$ACCEPT_LICENCE" != "true" ]]; then
        echo "Error: You must accept the server licence terms" >&2
        echo "Use --accept-server-license-terms flag" >&2
        exit 1
    fi
    
    if [[ -z "$TUNNEL_NAME" ]]; then
        echo "Error: Tunnel name is required" >&2
        echo "Use --name <name> flag" >&2
        exit 1
    fi
    
    # Simulate the authentication flow
    echo ""
    echo "* Visual Studio Code Server"
    echo ""
    echo "To grant access to the server, please log into"
    echo "https://github.com/login/device"
    echo "and use code $MOCK_DEVICE_CODE"
    echo ""
    
    # In mock mode, simulate successful authentication after a brief wait
    sleep 2
    
    echo "✔ Authenticated with GitHub"
    echo ""
    echo "Open this link in your browser $MOCK_TUNNEL_URL/$TUNNEL_NAME"
    echo ""
    
    # Keep running to simulate a tunnel service
    # In test mode, this will be killed after verification
    if [[ "${MOCK_FOREGROUND:-}" == "true" ]]; then
        echo "Tunnel '$TUNNEL_NAME' is running..."
        # Wait indefinitely (will be killed by test)
        while true; do
            sleep 60
        done
    fi
    
    exit 0
fi

# Default: show help
echo "VS Code CLI Mock - use 'code --help' for usage"
exit 0
