#!/bin/bash
# Mock systemctl command for Alpine Linux testing
# Simulates basic systemd service management

SERVICE_STATE_DIR="/var/run/mock-systemd"
mkdir -p "$SERVICE_STATE_DIR"

# Get service name from argument (remove .service suffix if present)
get_service_name() {
    local name="$1"
    echo "${name%.service}"
}

# Get state file path for a service
get_state_file() {
    local service=$(get_service_name "$1")
    echo "$SERVICE_STATE_DIR/${service}.state"
}

# Get enabled file path for a service
get_enabled_file() {
    local service=$(get_service_name "$1")
    echo "$SERVICE_STATE_DIR/${service}.enabled"
}

# Command handling
case "$1" in
    daemon-reload)
        echo "Mock: Reloading systemd daemon"
        exit 0
        ;;
    
    start)
        service=$(get_service_name "$2")
        state_file=$(get_state_file "$2")
        echo "active" > "$state_file"
        echo "Mock: Starting $service"
        exit 0
        ;;
    
    stop)
        service=$(get_service_name "$2")
        state_file=$(get_state_file "$2")
        echo "inactive" > "$state_file"
        echo "Mock: Stopping $service"
        exit 0
        ;;
    
    restart)
        service=$(get_service_name "$2")
        state_file=$(get_state_file "$2")
        echo "active" > "$state_file"
        echo "Mock: Restarting $service"
        exit 0
        ;;
    
    enable)
        service=$(get_service_name "$2")
        enabled_file=$(get_enabled_file "$2")
        echo "enabled" > "$enabled_file"
        echo "Mock: Enabling $service"
        exit 0
        ;;
    
    disable)
        service=$(get_service_name "$2")
        enabled_file=$(get_enabled_file "$2")
        rm -f "$enabled_file"
        echo "Mock: Disabling $service"
        exit 0
        ;;
    
    is-active)
        shift
        # Handle --quiet flag
        quiet=false
        if [[ "$1" == "--quiet" ]]; then
            quiet=true
            shift
        fi
        
        service=$(get_service_name "$1")
        state_file=$(get_state_file "$1")
        
        if [[ -f "$state_file" ]] && [[ "$(cat "$state_file")" == "active" ]]; then
            if [[ "$quiet" != "true" ]]; then
                echo "active"
            fi
            exit 0
        else
            if [[ "$quiet" != "true" ]]; then
                echo "inactive"
            fi
            exit 3
        fi
        ;;
    
    is-enabled)
        shift
        # Handle --quiet flag
        quiet=false
        if [[ "$1" == "--quiet" ]]; then
            quiet=true
            shift
        fi
        
        service=$(get_service_name "$1")
        enabled_file=$(get_enabled_file "$1")
        
        if [[ -f "$enabled_file" ]]; then
            if [[ "$quiet" != "true" ]]; then
                echo "enabled"
            fi
            exit 0
        else
            if [[ "$quiet" != "true" ]]; then
                echo "disabled"
            fi
            exit 1
        fi
        ;;
    
    status)
        service=$(get_service_name "$2")
        state_file=$(get_state_file "$2")
        enabled_file=$(get_enabled_file "$2")
        
        echo "● ${service}.service - Mock Service"
        
        if [[ -f "$state_file" ]]; then
            state=$(cat "$state_file")
        else
            state="inactive"
        fi
        
        if [[ -f "$enabled_file" ]]; then
            enabled="enabled"
        else
            enabled="disabled"
        fi
        
        echo "   Loaded: loaded (/etc/systemd/system/${service}.service; $enabled)"
        echo "   Active: $state"
        
        if [[ "$state" == "active" ]]; then
            exit 0
        else
            exit 3
        fi
        ;;
    
    cat)
        service=$(get_service_name "$2")
        service_file="/etc/systemd/system/${service}.service"
        
        if [[ -f "$service_file" ]]; then
            cat "$service_file"
            exit 0
        else
            echo "No files found for ${service}.service" >&2
            exit 1
        fi
        ;;
    
    list-units)
        echo "Mock: Listing units"
        ls -1 "$SERVICE_STATE_DIR"/*.state 2>/dev/null | while read f; do
            service=$(basename "${f%.state}")
            state=$(cat "$f")
            echo "${service}.service    loaded $state running Mock Service"
        done
        exit 0
        ;;
    
    *)
        echo "Mock systemctl: Unknown command '$1'" >&2
        echo "Supported commands: daemon-reload, start, stop, restart, enable, disable, is-active, is-enabled, status, cat, list-units" >&2
        exit 1
        ;;
esac
