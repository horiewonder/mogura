#!/bin/bash
#
# mogura uninstaller
#
set -euo pipefail

# Colors
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
BOLD=$'\033[1m'
NC=$'\033[0m'

info() { echo -e "${GREEN}==>${NC} ${BOLD}$*${NC}"; }
warn() { echo -e "${YELLOW}warning:${NC} $*"; }

BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.config/mogura"
LOG_DIR="${HOME}/.local/log/mogura"
LAUNCHD_DIR="${HOME}/Library/LaunchAgents"
LAUNCHD_PREFIX="com.mogura.tunnel"

echo ""
echo -e "${BOLD}mogura uninstaller${NC}"
echo "===================="
echo ""

# Stop all running tunnels
info "Stopping all mogura tunnels..."
for plist in "${LAUNCHD_DIR}/${LAUNCHD_PREFIX}."*.plist 2>/dev/null; do
    if [[ -f "$plist" ]]; then
        label=$(basename "$plist" .plist)
        if launchctl list "$label" &>/dev/null; then
            launchctl unload "$plist" 2>/dev/null || true
            echo "  Stopped: $label"
        fi
    fi
done

# Remove LaunchAgent plists
info "Removing LaunchAgent plists..."
for plist in "${LAUNCHD_DIR}/${LAUNCHD_PREFIX}."*.plist 2>/dev/null; do
    if [[ -f "$plist" ]]; then
        rm -f "$plist"
        echo "  Removed: $plist"
    fi
done

# Remove symlink
info "Removing mogura command..."
if [[ -L "${BIN_DIR}/mogura" ]]; then
    rm "${BIN_DIR}/mogura"
    echo "  Removed: ${BIN_DIR}/mogura"
fi

# Ask about config and logs
echo ""
read -p "Remove configuration files? (${CONFIG_DIR}) [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "${CONFIG_DIR}"
    info "Removed configuration: ${CONFIG_DIR}"
fi

read -p "Remove log files? (${LOG_DIR}) [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "${LOG_DIR}"
    info "Removed logs: ${LOG_DIR}"
fi

echo ""
info "Uninstallation complete!"
echo ""
echo "Note: The mogura source directory has not been removed."
echo "You can delete it manually if you no longer need it."
echo ""
