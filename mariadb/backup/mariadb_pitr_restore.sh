#!/bin/bash
# =============================================================================
# mariadb_pitr_restore.sh
# Point-in-Time Recovery für MariaDB
#
# Ablauf:
#   1. Physisches Full-Backup aus Restic wiederherstellen
#   2. Binary Logs aus Restic wiederherstellen
#   3. Binary Logs bis zum gewünschten Zeitpunkt einspielen
#
# Verwendung:
#   ./mariadb_pitr_restore.sh "2024-03-15 09:47:00"
# =============================================================================

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
RESTIC_REPO_PHYSICAL="rclone:pCloud:/Backups/mariadb_pb"
RESTIC_REPO_BINLOG="rclone:pCloud:/Backups/mariadb_binlog"
RESTIC_PASSWORD_FILE="/root/restic"

RESTORE_BASE="/var/restore/mariadb"
RESTORE_DATA_DIR="${RESTORE_BASE}/data"
RESTORE_BINLOG_DIR="${RESTORE_BASE}/binlogs"

MARIADB_DATADIR="/var/lib/mysql"
BINLOG_PREFIX="mysql-bin"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
log()     { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }
step()    { echo -e "\n${BOLD}${CYAN}▶ $*${RESET}"; }

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
    echo ""
    echo -e "  ${BOLD}Usage:${RESET} $0 \"YYYY-MM-DD HH:MM:SS\""
    echo ""
    echo -e "  ${BOLD}Example:${RESET} $0 \"2024-03-15 09:47:00\""
    echo ""
    exit 1
}

# ── Arguments ─────────────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
    echo -e "${RED}[ERROR]${RESET} No target time specified."
    usage
fi

TARGET_TIME="$1"

# Validate format YYYY-MM-DD HH:MM:SS
if ! [[ "$TARGET_TIME" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
    error "Invalid time format. Use: YYYY-MM-DD HH:MM:SS"
fi

# ── Root check ────────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root."
fi

# ── Dependency checks ─────────────────────────────────────────────────────────
command -v restic      &>/dev/null || error "restic is not installed"
command -v rclone      &>/dev/null || error "rclone is not installed"
command -v mariabackup &>/dev/null || error "mariabackup is not installed"
command -v mariadb-binlog &>/dev/null || error "mariadb-binlog is not installed"

[[ -f "$RESTIC_PASSWORD_FILE" ]] || error "Restic password file not found: $RESTIC_PASSWORD_FILE"

# ── Confirm ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${RED}⚠ WARNING: Point-in-Time Recovery${RESET}"
echo ""
echo -e "  Target time : ${BOLD}${TARGET_TIME}${RESET}"
echo -e "  Data dir    : ${BOLD}${MARIADB_DATADIR}${RESET}"
echo ""
echo -e "  This will ${RED}${BOLD}STOP MariaDB${RESET} and ${RED}${BOLD}REPLACE${RESET} all data in:"
echo -e "  ${BOLD}${MARIADB_DATADIR}${RESET}"
echo ""
read -rp "$(echo -e ${YELLOW}Type YES to continue:${RESET} )" CONFIRM
if [[ "$CONFIRM" != "YES" ]]; then
    log "Aborted."
    exit 0
fi

echo ""

# ── Step 1: Stop MariaDB ──────────────────────────────────────────────────────
step "Stopping MariaDB"
systemctl stop mariadb || error "Failed to stop MariaDB"
success "MariaDB stopped."

# ── Step 2: Restore physical backup ──────────────────────────────────────────
step "Restoring physical backup from Restic"

log "Available snapshots in physical backup repository:"
restic -r "$RESTIC_REPO_PHYSICAL" \
    --password-file "$RESTIC_PASSWORD_FILE" \
    snapshots --compact

echo ""
read -rp "$(echo -e ${CYAN}Enter snapshot ID to restore \(or 'latest'\):${RESET} )" SNAPSHOT_ID
SNAPSHOT_ID="${SNAPSHOT_ID:-latest}"

log "Restoring snapshot ${SNAPSHOT_ID} to ${RESTORE_DATA_DIR}..."
mkdir -p "$RESTORE_DATA_DIR"

restic -r "$RESTIC_REPO_PHYSICAL" \
    --password-file "$RESTIC_PASSWORD_FILE" \
    restore "$SNAPSHOT_ID" \
    --target "$RESTORE_DATA_DIR" \
    || error "Failed to restore physical backup"

success "Physical backup restored to: ${RESTORE_DATA_DIR}"

# ── Step 3: Copy back to MariaDB data directory ───────────────────────────────
step "Copying data to MariaDB data directory"

log "Clearing existing data directory..."
rm -rf "${MARIADB_DATADIR:?}"/*

log "Running mariabackup --copy-back..."
mariabackup --copy-back \
    --target-dir="${RESTORE_DATA_DIR}/var/backups/mariadb/full" \
    --datadir="$MARIADB_DATADIR" \
    || error "mariabackup --copy-back failed"

log "Fixing permissions..."
chown -R mysql:mysql "$MARIADB_DATADIR"

success "Data directory restored."

# ── Step 4: Restore binary logs ───────────────────────────────────────────────
step "Restoring binary logs from Restic"

mkdir -p "$RESTORE_BINLOG_DIR"

log "Available snapshots in binary log repository:"
restic -r "$RESTIC_REPO_BINLOG" \
    --password-file "$RESTIC_PASSWORD_FILE" \
    snapshots --compact

log "Restoring latest binary log snapshot..."
restic -r "$RESTIC_REPO_BINLOG" \
    --password-file "$RESTIC_PASSWORD_FILE" \
    restore latest \
    --target "$RESTORE_BINLOG_DIR" \
    || error "Failed to restore binary logs"

success "Binary logs restored to: ${RESTORE_BINLOG_DIR}"

# ── Step 5: Start MariaDB without binary logging ─────────────────────────────
step "Starting MariaDB (skip-log-bin for recovery)"

systemctl start mariadb --no-block || true
mariadbd_safe_opts="--skip-log-bin --skip-slave-start"

# Restart with recovery options
systemctl stop mariadb 2>/dev/null || true
mysqld_safe $mariadbd_safe_opts &
MYSQLD_PID=$!
sleep 5

# ── Step 6: Replay binary logs ────────────────────────────────────────────────
step "Replaying binary logs up to: ${TARGET_TIME}"

BINLOG_FILES=$(find "${RESTORE_BINLOG_DIR}" -name "${BINLOG_PREFIX}.[0-9]*" | sort)

if [[ -z "$BINLOG_FILES" ]]; then
    error "No binary log files found in: ${RESTORE_BINLOG_DIR}"
fi

log "Found binary log files:"
echo "$BINLOG_FILES" | sed 's/^/    /'
echo ""

log "Replaying binary logs..."
mariadb-binlog \
    --stop-datetime="$TARGET_TIME" \
    $BINLOG_FILES \
    | mariadb \
    || error "Failed to replay binary logs"

success "Binary logs replayed up to: ${TARGET_TIME}"

# ── Step 7: Restart MariaDB normally ─────────────────────────────────────────
step "Restarting MariaDB normally"

kill $MYSQLD_PID 2>/dev/null || true
sleep 3
systemctl start mariadb || error "Failed to start MariaDB"

success "MariaDB restarted."

# ── Cleanup ───────────────────────────────────────────────────────────────────
step "Cleanup"
read -rp "$(echo -e ${YELLOW}Remove temporary restore directories? [y/N]:${RESET} )" CLEANUP
if [[ "$CLEANUP" =~ ^[yY]$ ]]; then
    rm -rf "$RESTORE_BASE"
    success "Temporary directories removed."
else
    log "Restore data kept at: ${RESTORE_BASE}"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "----------------------------------------------------------------------"
echo -e "${BOLD}${GREEN}✔ Point-in-Time Recovery complete!${RESET}"
echo ""
echo -e "  Restored to : ${BOLD}${TARGET_TIME}${RESET}"
echo -e "  Verify data integrity before putting back into production."
echo "----------------------------------------------------------------------"
