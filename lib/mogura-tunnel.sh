#!/bin/bash
#
# mogura-tunnel.sh - Tunnel operations for mogura
#

# Connect to SSH (called by LaunchAgent)
tunnel_connect() {
    local name="$1"

    if [[ -z "$name" ]]; then
        die "Tunnel name is required"
    fi

    load_tunnel_config "$name"

    if [[ -z "$SSH_HOST" ]]; then
        die "SSH_HOST is not configured for tunnel '${name}'"
    fi

    # Log connection attempt
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Connecting to ${SSH_HOST}..."

    # Execute SSH with tunnel-optimized options
    exec /usr/bin/ssh -N \
        -o ExitOnForwardFailure=yes \
        -o ServerAliveInterval=30 \
        -o ServerAliveCountMax=3 \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=accept-new \
        "$SSH_HOST"
}

# Add a new tunnel
cmd_add() {
    local name=""
    local ssh_host=""
    local description=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --host|-h)
                ssh_host="$2"
                shift 2
                ;;
            --desc|-d)
                description="$2"
                shift 2
                ;;
            -*)
                die "Unknown option: $1"
                ;;
            *)
                if [[ -z "$name" ]]; then
                    name="$1"
                else
                    die "Unexpected argument: $1"
                fi
                shift
                ;;
        esac
    done

    # Validate
    if [[ -z "$name" ]]; then
        die "Usage: mogura add <name> --host <ssh-host> [--desc <description>]"
    fi

    if [[ -z "$ssh_host" ]]; then
        die "SSH host is required. Use: mogura add ${name} --host <ssh-host>"
    fi

    validate_tunnel_name "$name"
    validate_ssh_host "$ssh_host"

    if tunnel_exists "$name"; then
        die "Tunnel '${name}' already exists. Use 'mogura remove ${name}' first."
    fi

    # Create tunnel config
    save_tunnel_config "$name" "$ssh_host" "$description"
    info "Created tunnel config: ${name}"

    # Generate and load LaunchAgent
    generate_plist "$name"
    launchd_load "$name"

    echo ""
    echo "Tunnel '${name}' is now running!"
    echo "Use 'mogura status ${name}' to check status"
    echo "Use 'mogura logs ${name}' to view logs"
}

# Remove a tunnel
cmd_remove() {
    local name="$1"

    if [[ -z "$name" ]]; then
        die "Usage: mogura remove <name>"
    fi

    validate_tunnel_name "$name"

    if ! tunnel_exists "$name"; then
        die "Tunnel '${name}' not found"
    fi

    # Stop if running
    if launchd_is_running "$name"; then
        launchd_unload "$name"
    fi

    # Remove plist
    remove_plist "$name"

    # Remove config
    local conf
    conf="$(get_tunnel_config_path "$name")"
    rm -f "$conf"
    info "Removed tunnel config: ${name}"

    # Optionally remove logs
    local log_file err_file
    log_file="$(get_log_path "$name")"
    err_file="$(get_err_path "$name")"
    rm -f "$log_file" "$err_file"

    echo ""
    echo "Tunnel '${name}' has been removed."
}

# Start a tunnel
cmd_start() {
    local name="$1"

    if [[ -z "$name" ]]; then
        die "Usage: mogura start <name>"
    fi

    validate_tunnel_name "$name"

    if ! tunnel_exists "$name"; then
        die "Tunnel '${name}' not found"
    fi

    launchd_load "$name"
}

# Stop a tunnel
cmd_stop() {
    local name="$1"

    if [[ -z "$name" ]]; then
        die "Usage: mogura stop <name>"
    fi

    validate_tunnel_name "$name"

    if ! tunnel_exists "$name"; then
        die "Tunnel '${name}' not found"
    fi

    launchd_unload "$name"
}

# Restart a tunnel
cmd_restart() {
    local name="$1"

    if [[ -z "$name" ]]; then
        die "Usage: mogura restart <name>"
    fi

    validate_tunnel_name "$name"

    if ! tunnel_exists "$name"; then
        die "Tunnel '${name}' not found"
    fi

    launchd_unload "$name"
    sleep 1
    launchd_load "$name"
}

# Show tunnel status
cmd_status() {
    local name="${1:-}"

    if [[ -n "$name" ]]; then
        # Single tunnel status
        validate_tunnel_name "$name"

        if ! tunnel_exists "$name"; then
            die "Tunnel '${name}' not found"
        fi

        load_tunnel_config "$name"
        local status
        status="$(launchd_get_status "$name")"
        local enabled="no"
        if launchd_is_enabled "$name"; then
            enabled="yes"
        fi

        echo "${BOLD}Tunnel:${NC} ${name}"
        echo "  SSH Host:    ${SSH_HOST}"
        echo "  Status:      ${status}"
        echo "  Auto-start:  ${enabled}"
        if [[ -n "$DESCRIPTION" ]]; then
            echo "  Description: ${DESCRIPTION}"
        fi
        echo "  Log:         $(get_log_path "$name")"
    else
        # All tunnels status
        local tunnels
        tunnels=$(list_tunnel_names)

        if [[ -z "$tunnels" ]]; then
            echo "No tunnels configured."
            echo "Use 'mogura add <name> --host <ssh-host>' to add one."
            return
        fi

        printf "${BOLD}%-15s %-20s %-20s %-10s${NC}\n" "NAME" "HOST" "STATUS" "AUTO-START"
        echo "------------------------------------------------------------"

        while IFS= read -r name; do
            load_tunnel_config "$name"
            local status
            status="$(launchd_get_status "$name")"
            local enabled="no"
            if launchd_is_enabled "$name"; then
                enabled="yes"
            fi

            # Color status
            local status_color=""
            if [[ "$status" == running* ]]; then
                status_color="${GREEN}${status}${NC}"
            elif [[ "$status" == error* ]]; then
                status_color="${RED}${status}${NC}"
            else
                status_color="${YELLOW}${status}${NC}"
            fi

            printf "%-15s %-20s %-20b %-10s\n" "$name" "$SSH_HOST" "$status_color" "$enabled"
        done <<< "$tunnels"
    fi
}

# List all tunnels
cmd_list() {
    cmd_status
}

# Enable auto-start
cmd_enable() {
    local name="$1"

    if [[ -z "$name" ]]; then
        die "Usage: mogura enable <name>"
    fi

    validate_tunnel_name "$name"

    if ! tunnel_exists "$name"; then
        die "Tunnel '${name}' not found"
    fi

    launchd_enable "$name"
}

# Disable auto-start
cmd_disable() {
    local name="$1"

    if [[ -z "$name" ]]; then
        die "Usage: mogura disable <name>"
    fi

    validate_tunnel_name "$name"

    if ! tunnel_exists "$name"; then
        die "Tunnel '${name}' not found"
    fi

    launchd_disable "$name"
}

# View logs
cmd_logs() {
    local name="$1"
    local follow="${2:-}"

    if [[ -z "$name" ]]; then
        die "Usage: mogura logs <name> [-f]"
    fi

    validate_tunnel_name "$name"

    if ! tunnel_exists "$name"; then
        die "Tunnel '${name}' not found"
    fi

    local log_file err_file
    log_file="$(get_log_path "$name")"
    err_file="$(get_err_path "$name")"

    echo "${BOLD}==> Log: ${log_file}${NC}"
    if [[ -f "$log_file" ]]; then
        cat "$log_file"
    else
        echo "(empty)"
    fi

    echo ""
    echo "${BOLD}==> Error Log: ${err_file}${NC}"
    if [[ -f "$err_file" ]]; then
        cat "$err_file"
    else
        echo "(empty)"
    fi

    if [[ "$follow" == "-f" ]] || [[ "$2" == "-f" ]]; then
        echo ""
        echo "${BOLD}Following logs... (Ctrl+C to stop)${NC}"
        tail -f "$log_file" "$err_file" 2>/dev/null
    fi
}
