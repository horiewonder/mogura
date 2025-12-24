#!/bin/bash
#
# mogura-core.sh - Core functions for mogura
#

# Configuration directories
MOGURA_CONFIG_DIR="${HOME}/.config/mogura"
MOGURA_TUNNELS_DIR="${MOGURA_CONFIG_DIR}/tunnels"
MOGURA_LOG_DIR="${HOME}/.local/log/mogura"

# LaunchAgent settings
LAUNCHD_LABEL_PREFIX="com.mogura.tunnel"
LAUNCHD_DIR="${HOME}/Library/LaunchAgents"

# Colors (only if terminal supports it)
if [[ -t 1 ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[0;33m'
    BLUE=$'\033[0;34m'
    BOLD=$'\033[1m'
    NC=$'\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    NC=''
fi

# Initialize required directories
mogura_init() {
    mkdir -p "${MOGURA_TUNNELS_DIR}"
    mkdir -p "${MOGURA_LOG_DIR}"
    mkdir -p "${LAUNCHD_DIR}"
}

# Output helpers
die() {
    echo -e "${RED}error:${NC} $*" >&2
    exit 1
}

info() {
    echo -e "${GREEN}==>${NC} ${BOLD}$*${NC}"
}

warn() {
    echo -e "${YELLOW}warning:${NC} $*" >&2
}

# Check if tunnel exists
tunnel_exists() {
    local name="$1"
    [[ -f "${MOGURA_TUNNELS_DIR}/${name}.conf" ]]
}

# Load tunnel configuration
load_tunnel_config() {
    local name="$1"
    local conf="${MOGURA_TUNNELS_DIR}/${name}.conf"

    if [[ ! -f "$conf" ]]; then
        die "Tunnel '${name}' not found"
    fi

    # Reset variables
    SSH_HOST=""
    DESCRIPTION=""
    ENABLED="true"

    # shellcheck source=/dev/null
    source "$conf"
}

# Save tunnel configuration
save_tunnel_config() {
    local name="$1"
    local ssh_host="$2"
    local description="${3:-}"
    local conf="${MOGURA_TUNNELS_DIR}/${name}.conf"

    cat > "$conf" <<EOF
# mogura tunnel configuration
# Name: ${name}
SSH_HOST="${ssh_host}"
DESCRIPTION="${description}"
ENABLED="true"
EOF
}

# Validate SSH host exists in ~/.ssh/config
validate_ssh_host() {
    local host="$1"

    if ! ssh -G "$host" &>/dev/null; then
        die "SSH host '${host}' not found in ~/.ssh/config"
    fi
}

# Validate tunnel name (alphanumeric, dash, underscore only)
validate_tunnel_name() {
    local name="$1"

    if [[ -z "$name" ]]; then
        die "Tunnel name is required"
    fi

    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        die "Invalid tunnel name: '${name}'. Use only alphanumeric, dash, and underscore."
    fi
}

# Get tunnel config file path
get_tunnel_config_path() {
    local name="$1"
    echo "${MOGURA_TUNNELS_DIR}/${name}.conf"
}

# Get LaunchAgent plist path
get_plist_path() {
    local name="$1"
    echo "${LAUNCHD_DIR}/${LAUNCHD_LABEL_PREFIX}.${name}.plist"
}

# Get LaunchAgent label
get_launchd_label() {
    local name="$1"
    echo "${LAUNCHD_LABEL_PREFIX}.${name}"
}

# Get log file path
get_log_path() {
    local name="$1"
    echo "${MOGURA_LOG_DIR}/${name}.log"
}

# Get error log file path
get_err_path() {
    local name="$1"
    echo "${MOGURA_LOG_DIR}/${name}.err"
}

# List all tunnel names
list_tunnel_names() {
    if [[ -d "${MOGURA_TUNNELS_DIR}" ]]; then
        find "${MOGURA_TUNNELS_DIR}" -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort
    fi
}

# Help command
cmd_help() {
    cat <<EOF
${BOLD}mogura${NC} - SSH tunnel manager using macOS LaunchAgent

${BOLD}USAGE:${NC}
    mogura <command> [options]

${BOLD}COMMANDS:${NC}
    add <name> --host <ssh-host>    Add a new tunnel
    remove <name>                   Remove a tunnel
    start <name>                    Start a tunnel
    stop <name>                     Stop a tunnel
    restart <name>                  Restart a tunnel
    status [name]                   Show tunnel status
    list                            List all tunnels
    enable <name>                   Enable auto-start
    disable <name>                  Disable auto-start
    logs <name>                     Show tunnel logs

${BOLD}EXAMPLES:${NC}
    # Add SSH tunnel config to ~/.ssh/config first:
    #   Host my-tunnel
    #       HostName example.com
    #       User myuser
    #       LocalForward 3306 localhost:3306
    #       DynamicForward 1080

    # Then register with mogura:
    mogura add dev --host my-tunnel

    # Check status
    mogura status

    # View logs
    mogura logs dev

${BOLD}OPTIONS:${NC}
    -h, --help      Show this help
    -v, --version   Show version

EOF
}
