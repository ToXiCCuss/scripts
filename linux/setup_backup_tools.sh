#!/bin/bash
# =============================================================================
# setup_backup_tools.sh
# Installiert restic & rclone und richtet rclone mit pCloud ein
# Unterstützte Systeme: Debian / Ubuntu
# =============================================================================

set -euo pipefail

# ── Farben ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Hilfsfunktionen ───────────────────────────────────────────────────────────
info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
step()    { echo -e "\n${BOLD}${CYAN}▶ $*${RESET}"; }
divider() { echo -e "${CYAN}$(printf '─%.0s' {1..60})${RESET}"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Dieses Script muss als root ausgeführt werden (sudo ./setup_backup_tools.sh)"
        exit 1
    fi
}

check_debian() {
    if ! command -v apt-get &>/dev/null; then
        error "Dieses Script unterstützt nur Debian/Ubuntu (apt-get nicht gefunden)"
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

# ── 1. Restic installieren ────────────────────────────────────────────────────
install_restic() {
    step "Restic installieren"

    if command -v restic &>/dev/null; then
        CURRENT=$(restic version | awk '{print $2}')
        warn "Restic ist bereits installiert (${CURRENT}). Überspringe Installation."
        return
    fi

    info "Installiere restic über apt..."
    apt-get update -qq
    apt-get install -y restic

    # Self-update falls apt-Version veraltet ist
    info "Führe restic self-update durch (neueste Version)..."
    restic self-update || warn "Self-update fehlgeschlagen – apt-Version wird verwendet."

    success "Restic installiert: $(restic version | awk '{print $2}')"
}

# ── 2. rclone installieren ────────────────────────────────────────────────────
install_rclone() {
    step "rclone installieren"

    if command -v rclone &>/dev/null; then
        CURRENT=$(rclone --version | head -1 | awk '{print $2}')
        warn "rclone ist bereits installiert (${CURRENT}). Überspringe Installation."
        return
    fi

    info "Installiere rclone über offizielles Installationsscript..."
    curl -fsSL https://rclone.org/install.sh | bash

    if ! command -v rclone &>/dev/null; then
        error "rclone-Installation fehlgeschlagen!"
        exit 1
    fi

    success "rclone installiert: $(rclone --version | head -1)"
}

# ── 3. rclone pCloud konfigurieren ────────────────────────────────────────────
configure_pcloud() {
    step "rclone – pCloud konfigurieren"
    divider

    # Prüfen ob pCloud bereits konfiguriert ist
    if rclone listremotes 2>/dev/null | grep -q "^pCloud:"; then
        warn "Ein Remote namens 'pCloud' existiert bereits."
        echo -e "  Aktuell konfigurierte Remotes:"
        rclone listremotes | sed 's/^/    /'
        echo ""
        read -rp "$(echo -e ${YELLOW}Überschreiben? [j/N]:${RESET} )" OVERWRITE
        if [[ ! "$OVERWRITE" =~ ^[jJyY]$ ]]; then
            info "Konfiguration wird nicht überschrieben."
            return
        fi
        # Altes Remote entfernen
        rclone config delete pCloud
        info "Altes pCloud-Remote entfernt."
    fi

    echo ""
    echo -e "${BOLD}pCloud-Konfiguration via OAuth${RESET}"
    echo ""
    echo -e "  rclone wird jetzt interaktiv gestartet."
    echo -e "  ${BOLD}Folge diesen Schritten:${RESET}"
    echo ""
    echo -e "  ${CYAN}1.${RESET} Wähle ${BOLD}n${RESET} → New remote"
    echo -e "  ${CYAN}2.${RESET} Name: ${BOLD}pCloud${RESET}"
    echo -e "  ${CYAN}3.${RESET} Storage-Typ: Suche nach ${BOLD}pcloud${RESET} (Nummer eingeben)"
    echo -e "  ${CYAN}4.${RESET} client_id / client_secret: ${BOLD}leer lassen${RESET} (Enter)"
    echo -e "  ${CYAN}5.${RESET} hostname: ${BOLD}api.pcloud.com${RESET} (EU: eapi.pcloud.com)"
    echo -e "  ${CYAN}6.${RESET} Edit advanced config: ${BOLD}n${RESET}"
    echo -e "  ${CYAN}7.${RESET} Use web browser to authenticate: ${BOLD}y${RESET}"
    echo -e "       → Browser öffnet sich, bei pCloud einloggen & Zugriff erlauben"
    echo -e "  ${CYAN}8.${RESET} Konfiguration mit ${BOLD}q${RESET} beenden"
    echo ""

    # Hinweis für headless Server
    if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
        echo -e "  ${YELLOW}⚠ Kein Display erkannt (headless Server).${RESET}"
        echo -e "  Du hast zwei Möglichkeiten:"
        echo -e "  ${BOLD}A)${RESET} rclone config auf einem lokalen Rechner ausführen,"
        echo -e "     dann die Datei ${BOLD}~/.config/rclone/rclone.conf${RESET} hierher kopieren."
        echo -e "  ${BOLD}B)${RESET} Bei Schritt 7 '${BOLD}n${RESET}' wählen → rclone gibt eine URL aus"
        echo -e "     → URL im Browser öffnen → Token zurückkopieren."
        echo ""
    fi

    read -rp "$(echo -e ${CYAN}Enter drücken um rclone config zu starten...${RESET})"
    echo ""

    rclone config

    # Ergebnis prüfen
    echo ""
    if rclone listremotes 2>/dev/null | grep -q "^pCloud:"; then
        success "pCloud-Remote erfolgreich konfiguriert!"
        test_pcloud_connection
    else
        warn "Remote 'pCloud' wurde nicht gefunden – Konfiguration möglicherweise abgebrochen."
        info "Du kannst die Konfiguration später mit 'rclone config' erneut starten."
    fi
}

# ── 4. Verbindungstest ────────────────────────────────────────────────────────
test_pcloud_connection() {
    step "pCloud-Verbindung testen"

    info "Versuche pCloud-Root zu listen..."
    if rclone lsd pCloud: --max-depth 1 2>/dev/null; then
        success "Verbindung zu pCloud erfolgreich!"
    else
        warn "Verbindungstest fehlgeschlagen. Prüfe Token und Hostname-Einstellung."
        echo -e "  ${YELLOW}EU-Nutzer:${RESET} hostname muss ${BOLD}eapi.pcloud.com${RESET} sein"
        echo -e "  ${YELLOW}Neustart:${RESET}  rclone config → pCloud bearbeiten"
    fi
}

# ── 5. Zusammenfassung ────────────────────────────────────────────────────────
print_summary() {
    divider
    echo -e "\n${BOLD}${GREEN}✔ Setup abgeschlossen!${RESET}\n"

    echo -e "${BOLD}Installierte Tools:${RESET}"
    command -v restic &>/dev/null && echo -e "  ${GREEN}✔${RESET} restic  $(restic version | awk '{print $2}')"
    command -v rclone &>/dev/null && echo -e "  ${GREEN}✔${RESET} rclone  $(rclone --version | head -1 | awk '{print $2}')"

    echo ""
    echo -e "${BOLD}Konfigurierte rclone-Remotes:${RESET}"
    rclone listremotes | sed 's/^/  ✔ /' || echo "  (keine)"

    echo ""
    echo -e "${BOLD}Nützliche Befehle:${RESET}"
    echo -e "  ${CYAN}rclone lsd pCloud:${RESET}                      # Ordner auf pCloud listen"
    echo -e "  ${CYAN}rclone ls pCloud:Backups${RESET}                # Dateien listen"
    echo -e "  ${CYAN}restic -r rclone:pCloud:/Backups/db init${RESET} # Restic-Repo initialisieren"
    echo -e "  ${CYAN}rclone config${RESET}                           # rclone-Konfiguration bearbeiten"
    echo ""
    echo -e "  Konfigurationsdatei: ${BOLD}$(rclone config file | tail -1)${RESET}"
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
