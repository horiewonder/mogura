#!/bin/bash
#
# mogura installer
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
die() { echo -e "${RED}error:${NC} $*" >&2; exit 1; }

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.config/mogura"
LOG_DIR="${HOME}/.local/log/mogura"

echo ""
echo -e "${BOLD}mogura installer${NC}"
echo "=================="
echo ""

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
    die "mogura only supports macOS"
fi

# Create directories
info "Creating directories..."
mkdir -p "${BIN_DIR}"
mkdir -p "${CONFIG_DIR}/tunnels"
mkdir -p "${LOG_DIR}"

# Create symlink
info "Installing mogura to ${BIN_DIR}..."
if [[ -L "${BIN_DIR}/mogura" ]]; then
    rm "${BIN_DIR}/mogura"
fi

if [[ -f "${BIN_DIR}/mogura" ]]; then
    die "${BIN_DIR}/mogura already exists and is not a symlink. Please remove it first."
fi

ln -sf "${SCRIPT_DIR}/bin/mogura" "${BIN_DIR}/mogura"

# Make executable
chmod +x "${SCRIPT_DIR}/bin/mogura"

info "Installation complete!"
echo ""

# Check PATH
if [[ ":${PATH}:" != *":${BIN_DIR}:"* ]]; then
    warn "${BIN_DIR} is not in your PATH"
    echo ""
    echo "Add this to your shell config (~/.zshrc or ~/.bashrc):"
    echo ""
    echo -e "  ${BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    echo ""
    echo "Then restart your shell or run:"
    echo ""
    echo -e "  ${BOLD}source ~/.zshrc${NC}"
    echo ""
else
    echo "You can now use mogura!"
    echo ""
fi

echo "Quick start:"
echo ""
echo "  # First, add SSH tunnel config to ~/.ssh/config:"
echo "  # Host my-tunnel"
echo "  #     HostName example.com"
echo "  #     User myuser"
echo "  #     LocalForward 3306 localhost:3306"
echo ""
echo "  # Then register with mogura:"
echo -e "  ${BOLD}mogura add dev --host my-tunnel${NC}"
echo ""
echo "  # Check status:"
echo -e "  ${BOLD}mogura status${NC}"
echo ""
