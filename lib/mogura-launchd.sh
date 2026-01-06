#!/bin/bash
#
# mogura-launchd.sh - LaunchAgent management for mogura
#

# Generate LaunchAgent plist
generate_plist() {
    local name="$1"
    local label
    local plist
    local mogura_bin
    local log_file
    local err_file

    label="$(get_launchd_label "$name")"
    plist="$(get_plist_path "$name")"
    mogura_bin="${MOGURA_ROOT}/bin/mogura"
    log_file="$(get_log_path "$name")"
    err_file="$(get_err_path "$name")"

    cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${label}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${mogura_bin}</string>
        <string>_connect</string>
        <string>${name}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>10</integer>
    <key>StandardOutPath</key>
    <string>${log_file}</string>
    <key>StandardErrorPath</key>
    <string>${err_file}</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
EOF

    info "Generated LaunchAgent: ${plist}"
}

# Remove LaunchAgent plist
remove_plist() {
    local name="$1"
    local plist
    plist="$(get_plist_path "$name")"

    if [[ -f "$plist" ]]; then
        rm -f "$plist"
        info "Removed LaunchAgent: ${plist}"
    fi
}

# Load (start) LaunchAgent
launchd_load() {
    local name="$1"
    local plist
    local label

    plist="$(get_plist_path "$name")"
    label="$(get_launchd_label "$name")"

    if [[ ! -f "$plist" ]]; then
        die "LaunchAgent plist not found: ${plist}"
    fi

    # Check if already loaded
    if launchctl list "$label" &>/dev/null; then
        warn "Tunnel '${name}' is already running"
        return 0
    fi

    launchctl load -w "$plist"
    info "Started tunnel: ${name}"
}

# Unload (stop) LaunchAgent
launchd_unload() {
    local name="$1"
    local plist
    local label

    plist="$(get_plist_path "$name")"
    label="$(get_launchd_label "$name")"

    if [[ ! -f "$plist" ]]; then
        warn "LaunchAgent plist not found: ${plist}"
        return 0
    fi

    # Check if loaded
    if ! launchctl list "$label" &>/dev/null; then
        warn "Tunnel '${name}' is not running"
        return 0
    fi

    launchctl unload "$plist"
    info "Stopped tunnel: ${name}"
}

# Check if LaunchAgent is running
launchd_is_running() {
    local name="$1"
    local label
    label="$(get_launchd_label "$name")"

    launchctl list "$label" &>/dev/null
}

# Get LaunchAgent status (returns PID or status)
launchd_get_status() {
    local name="$1"
    local label
    local status_line
    local pid
    local exit_code

    label="$(get_launchd_label "$name")"

    if ! launchctl list "$label" &>/dev/null; then
        echo "stopped"
        return
    fi

    # Parse launchctl list output: PID, LastExitStatus, Label
    status_line=$(launchctl list | grep "$label" || true)

    if [[ -z "$status_line" ]]; then
        echo "stopped"
        return
    fi

    pid=$(echo "$status_line" | awk '{print $1}')
    exit_code=$(echo "$status_line" | awk '{print $2}')

    if [[ "$pid" == "-" ]]; then
        if [[ "$exit_code" != "0" ]]; then
            echo "error (exit: ${exit_code})"
        else
            echo "loaded"
        fi
    else
        echo "running (pid: ${pid})"
    fi
}

# Enable auto-start (RunAtLoad)
launchd_enable() {
    local name="$1"
    local plist
    plist="$(get_plist_path "$name")"

    if [[ ! -f "$plist" ]]; then
        die "LaunchAgent plist not found: ${plist}"
    fi

    # Use PlistBuddy to set RunAtLoad to true
    /usr/libexec/PlistBuddy -c "Set :RunAtLoad true" "$plist"
    info "Enabled auto-start for: ${name}"

    # Update config
    local conf
    conf="$(get_tunnel_config_path "$name")"
    if [[ -f "$conf" ]]; then
        sed -i '' 's/^ENABLED=.*/ENABLED="true"/' "$conf"
    fi
}

# Disable auto-start (RunAtLoad)
launchd_disable() {
    local name="$1"
    local plist
    plist="$(get_plist_path "$name")"

    if [[ ! -f "$plist" ]]; then
        die "LaunchAgent plist not found: ${plist}"
    fi

    # Use PlistBuddy to set RunAtLoad to false
    /usr/libexec/PlistBuddy -c "Set :RunAtLoad false" "$plist"
    info "Disabled auto-start for: ${name}"

    # Update config
    local conf
    conf="$(get_tunnel_config_path "$name")"
    if [[ -f "$conf" ]]; then
        sed -i '' 's/^ENABLED=.*/ENABLED="false"/' "$conf"
    fi
}

# Check if auto-start is enabled
launchd_is_enabled() {
    local name="$1"
    local plist
    plist="$(get_plist_path "$name")"

    if [[ ! -f "$plist" ]]; then
        return 1
    fi

    local run_at_load
    run_at_load=$(/usr/libexec/PlistBuddy -c "Print :RunAtLoad" "$plist" 2>/dev/null || echo "false")

    [[ "$run_at_load" == "true" ]]
}
