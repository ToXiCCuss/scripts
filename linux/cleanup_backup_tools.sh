#!/bin/bash
# =============================================================================
# cleanup_backup_tools.sh
# Removes restic & rclone and their configuration files
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

# ── Banner ────────────────────────────────────────────────────────────────────
print_banner() {
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║         Backup Tools Cleanup – restic + rclone           ║"
    echo "║              Uninstall & Remove Config                   ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# ── Sanity checks ─────────────────────────────────────────────────────────────
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (sudo ./cleanup_backup_tools.sh)"
        exit 1
    fi
}

# ── Confirm ───────────────────────────────────────────────────────────────────
confirm() {
    echo -e "${YELLOW}${BOLD}⚠ This will remove restic, rclone and their config files.${RESET}"
    echo -e "  This does ${BOLD}not${RESET} delete any data in your restic repository on pCloud."
    echo ""
    read -rp "$(echo -e ${YELLOW}Are you sure you want to continue? [y/N]:${RESET} )" CONFIRM
    if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
        info "Aborted. Nothing was removed."
        exit 0
    fi
    echo ""
}

# ── Remove restic ─────────────────────────────────────────────────────────────
remove_restic() {
    step "Remove restic"

    if ! command -v restic &>/dev/null; then
        warn "restic is not installed. Skipping."
        return
    fi

    RESTIC_PATH=$(command -v restic)
    info "Removing restic binary: ${RESTIC_PATH}..."
    rm -f "$RESTIC_PATH"

    # Remove if installed via apt as well
    if dpkg -l restic &>/dev/null 2>&1; then
        info "Removing apt package..."
        apt-get remove -y restic
    fi

    success "restic removed."
}

# ── Remove rclone ─────────────────────────────────────────────────────────────
remove_rclone() {
    step "Remove rclone"

    if ! dpkg -l rclone &>/dev/null 2>&1; then
        warn "rclone is not installed. Skipping."
        return
    fi

    info "Removing rclone via apt..."
    apt-get remove -y rclone

    success "rclone removed."
}

# ── Remove rclone config ──────────────────────────────────────────────────────
remove_rclone_config() {
    step "Remove rclone configuration"

    RCLONE_CONF_SYSTEM="/root/.config/rclone/rclone.conf"
    RCLONE_CONF_DIR="/root/.config/rclone"

    if [[ -f "$RCLONE_CONF_SYSTEM" ]]; then
        echo -e "  Found config: ${BOLD}${RCLONE_CONF_SYSTEM}${RESET}"
        read -rp "$(echo -e ${YELLOW}Remove rclone config file? [y/N]:${RESET} )" REMOVE_CONF
        if [[ "$REMOVE_CONF" =~ ^[yY]$ ]]; then
            rm -f "$RCLONE_CONF_SYSTEM"
            rmdir --ignore-fail-on-non-empty "$RCLONE_CONF_DIR" 2>/dev/null || true
            success "rclone config removed."
        else
            info "rclone config kept at: ${RCLONE_CONF_SYSTEM}"
        fi
    else
        warn "No rclone config found at ${RCLONE_CONF_SYSTEM}. Skipping."
    fi

    # Also check for cache
    RCLONE_CACHE="/root/.cache/rclone"
    if [[ -d "$RCLONE_CACHE" ]]; then
        info "Removing rclone cache: ${RCLONE_CACHE}..."
        rm -rf "$RCLONE_CACHE"
        success "rclone cache removed."
    fi
}

# ── Summary ───────────────────────────────────────────────────────────────────
print_summary() {
    divider
    echo -e "\n${BOLD}${GREEN}✔ Cleanup complete!${RESET}\n"

    echo -e "${BOLD}Removal status:${RESET}"
    command -v restic &>/dev/null \
        && echo -e "  ${YELLOW}⚠${RESET} restic  still present" \
        || echo -e "  ${GREEN}✔${RESET} restic  removed"

    command -v rclone &>/dev/null \
        && echo -e "  ${YELLOW}⚠${RESET} rclone  still present" \
        || echo -e "  ${GREEN}✔${RESET} rclone  removed"

    echo ""
    echo -e "  ${CYAN}Note:${RESET} Your restic repository on pCloud has ${BOLD}not${RESET} been touched."
    echo -e "        Run ${BOLD}setup_backup_tools.sh${RESET} to reinstall everything."
    echo ""
    divider
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    print_banner
    check_root
    confirm
    remove_restic
    remove_rclone
    remove_rclone_config
    print_summary
}

main "$@"
