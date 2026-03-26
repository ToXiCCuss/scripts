#!/bin/bash
# =============================================================================
# setup_backup_tools.sh
# Installs restic & rclone and configures rclone with pCloud
# Supported systems: Debian / Ubuntu
# =============================================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Helper functions ──────────────────────────────────────────────────────────
info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
step()    { echo -e "\n${BOLD}${CYAN}▶ $*${RESET}"; }
divider() { echo -e "${CYAN}$(printf '─%.0s' {1..60})${RESET}"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (sudo ./setup_backup_tools.sh)"
        exit 1
    fi
}

check_debian() {
    if ! command -v apt-get &>/dev/null; then
        error "This script only supports Debian/Ubuntu (apt-get not found)"
        exit 1
    fi
}

# ── Banner ────────────────────────────────────────────────────────────────────
print_banner() {
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║          Backup Tools Setup – restic + rclone            ║"
    echo "║                   pCloud Integration                     ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# ── 1. Install restic ─────────────────────────────────────────────────────────
install_restic() {
    step "Install restic"

    if command -v restic &>/dev/null; then
        CURRENT=$(restic version | awk '{print $2}')
        warn "restic is already installed (${CURRENT}). Skipping installation."
        return
    fi

    info "Installing restic via apt..."
    apt-get update -qq
    apt-get install -y restic

    # Self-update in case the apt version is outdated
    info "Running restic self-update (latest version)..."
    restic self-update || warn "Self-update failed – using apt version."

    success "restic installed: $(restic version | awk '{print $2}')"
}

# ── 2. Install rclone ─────────────────────────────────────────────────────────
install_rclone() {
    step "Install rclone"

    if command -v rclone &>/dev/null; then
        CURRENT=$(rclone --version | head -1 | awk '{print $2}')
        warn "rclone is already installed (${CURRENT}). Skipping installation."
        return
    fi

    info "Installing rclone via official install script..."
    curl -fsSL https://rclone.org/install.sh | bash

    if ! command -v rclone &>/dev/null; then
        error "rclone installation failed!"
        exit 1
    fi

    success "rclone installed: $(rclone --version | head -1)"
}

# ── 3. Configure rclone with pCloud ──────────────────────────────────────────
configure_pcloud() {
    step "rclone – Configure pCloud"
    divider

    # Check if pCloud remote already exists
    if rclone listremotes 2>/dev/null | grep -q "^pCloud:"; then
        warn "A remote named 'pCloud' already exists."
        echo -e "  Currently configured remotes:"
        rclone listremotes | sed 's/^/    /'
        echo ""
        read -rp "$(echo -e ${YELLOW}Overwrite? [y/N]:${RESET} )" OVERWRITE
        if [[ ! "$OVERWRITE" =~ ^[yY]$ ]]; then
            info "Configuration will not be overwritten."
            return
        fi
        # Remove old remote
        rclone config delete pCloud
        info "Old pCloud remote removed."
    fi

    echo ""
    echo -e "${BOLD}pCloud configuration via OAuth${RESET}"
    echo ""
    echo -e "  rclone will now start interactively."
    echo -e "  ${BOLD}Follow these steps:${RESET}"
    echo ""
    echo -e "  ${CYAN}1.${RESET} Choose ${BOLD}n${RESET} → New remote"
    echo -e "  ${CYAN}2.${RESET} Name: ${BOLD}pCloud${RESET}"
    echo -e "  ${CYAN}3.${RESET} Storage type: search for ${BOLD}pcloud${RESET} (enter the number)"
    echo -e "  ${CYAN}4.${RESET} client_id / client_secret: ${BOLD}leave empty${RESET} (press Enter)"
    echo -e "  ${CYAN}5.${RESET} hostname: ${BOLD}api.pcloud.com${RESET} (EU users: eapi.pcloud.com)"
    echo -e "  ${CYAN}6.${RESET} Edit advanced config: ${BOLD}n${RESET}"
    echo -e "  ${CYAN}7.${RESET} Use web browser to authenticate: ${BOLD}y${RESET}"
    echo -e "       → Browser opens – log in to pCloud and grant access"
    echo -e "  ${CYAN}8.${RESET} Quit configuration with ${BOLD}q${RESET}"
    echo ""

    # Notice for headless servers
    if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
        echo -e "  ${YELLOW}⚠ No display detected (headless server).${RESET}"
        echo -e "  You have two options:"
        echo -e "  ${BOLD}A)${RESET} Run rclone config on a local machine,"
        echo -e "     then copy ${BOLD}~/.config/rclone/rclone.conf${RESET} to this server."
        echo -e "  ${BOLD}B)${RESET} At step 7, choose '${BOLD}n${RESET}' → rclone prints a URL"
        echo -e "     → Open the URL in a browser → paste the token back."
        echo ""
    fi

    read -rp "$(echo -e ${CYAN}Press Enter to start rclone config...${RESET})"
    echo ""

    rclone config

    # Check result
    echo ""
    if rclone listremotes 2>/dev/null | grep -q "^pCloud:"; then
        success "pCloud remote configured successfully!"
        test_pcloud_connection
    else
        warn "Remote 'pCloud' not found – configuration may have been cancelled."
        info "You can re-run the configuration later with 'rclone config'."
    fi
}

# ── 4. Connection test ────────────────────────────────────────────────────────
test_pcloud_connection() {
    step "Test pCloud connection"

    info "Attempting to list pCloud root..."
    if rclone lsd pCloud: --max-depth 1 2>/dev/null; then
        success "Connection to pCloud successful!"
    else
        warn "Connection test failed. Check your token and hostname setting."
        echo -e "  ${YELLOW}EU users:${RESET} hostname must be ${BOLD}eapi.pcloud.com${RESET}"
        echo -e "  ${YELLOW}To retry:${RESET} rclone config → edit pCloud remote"
    fi
}

# ── 5. Summary ────────────────────────────────────────────────────────────────
print_summary() {
    divider
    echo -e "\n${BOLD}${GREEN}✔ Setup complete!${RESET}\n"

    echo -e "${BOLD}Installed tools:${RESET}"
    command -v restic &>/dev/null && echo -e "  ${GREEN}✔${RESET} restic  $(restic version | awk '{print $2}')"
    command -v rclone &>/dev/null && echo -e "  ${GREEN}✔${RESET} rclone  $(rclone --version | head -1 | awk '{print $2}')"

    echo ""
    echo -e "${BOLD}Configured rclone remotes:${RESET}"
    rclone listremotes | sed 's/^/  ✔ /' || echo "  (none)"

    echo ""
    echo -e "${BOLD}Useful commands:${RESET}"
    echo -e "  ${CYAN}rclone lsd pCloud:${RESET}                       # List folders on pCloud"
    echo -e "  ${CYAN}rclone ls pCloud:Backups${RESET}                 # List files"
    echo -e "  ${CYAN}restic -r rclone:pCloud:/Backups/db init${RESET} # Initialize restic repo"
    echo -e "  ${CYAN}rclone config${RESET}                            # Edit rclone configuration"
    echo ""
    echo -e "  Config file: ${BOLD}$(rclone config file | tail -1)${RESET}"
    echo ""
    divider
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    print_banner
    check_root
    check_debian

    install_restic
    install_rclone
    configure_pcloud
    print_summary
}

main "$@"
