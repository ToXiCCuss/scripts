#!/bin/bash
# =============================================================================
# mariadb_binlog_backup.sh
# Sichert MariaDB Binary Logs via Restic nach pCloud
# Läuft alle 6 Stunden via Cronjob
#
# Cronjob einrichten:
#   0 */6 * * * /root/scripts/mariadb/mariadb_binlog_backup.sh >> /var/log/mariadb_binlog_backup.log 2>&1
# =============================================================================

set -euo pipefail

# Import notification library
source "$(dirname "$0")/../../linux/notifications.sh"
DISCORD_ERROR_TITLE="MariaDB Binary Log Backup"

# ── Configuration ─────────────────────────────────────────────────────────────
RESTIC_REPOSITORY="rclone:pCloud:/Backups/mariadb_binlog"
RESTIC_PASSWORD_FILE="/root/restic"

BINLOG_DIR="/var/log/mysql"
BINLOG_PREFIX="mysql-bin"

# Retention: 3 Tage
KEEP_WITHIN="3d"

# ── Helpers ───────────────────────────────────────────────────────────────────
log()   { echo "[INFO]  $(date '+%Y-%m-%d %H:%M:%S') $*"; }
error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2; send_discord_error "$*"; exit 1; }

echo "----------------------------------------------------------------------"
log "Starting MariaDB binary log backup..."

# ── Checks ────────────────────────────────────────────────────────────────────
command -v restic  &>/dev/null || error "restic is not installed"
command -v rclone  &>/dev/null || error "rclone is not installed"
command -v mariadb &>/dev/null || error "mariadb client is not installed"

[[ -f "$RESTIC_PASSWORD_FILE" ]] || error "Restic password file not found: $RESTIC_PASSWORD_FILE"
[[ -d "$BINLOG_DIR" ]]           || error "Binary log directory not found: $BINLOG_DIR"

# Check ob Binary Logs überhaupt aktiv sind
BINLOG_STATUS=$(mariadb -N -B -e "SHOW VARIABLES LIKE 'log_bin'" | awk '{print $2}')
if [[ "$BINLOG_STATUS" != "ON" ]]; then
    error "Binary logging is not enabled. Apply 99-binlog.cnf and restart MariaDB."
fi

# ── Flush Binary Logs ─────────────────────────────────────────────────────────
# Neues Binary Log starten damit aktuelle Datei abgeschlossen wird
log "Flushing binary logs..."
mariadb -e "FLUSH BINARY LOGS;" || error "Failed to flush binary logs"

# ── Upload via Restic ─────────────────────────────────────────────────────────
log "Uploading binary logs to Restic..."
restic -r "$RESTIC_REPOSITORY" \
    --password-file "$RESTIC_PASSWORD_FILE" \
    backup "$BINLOG_DIR" \
    || error "Restic upload of binary logs failed"

# ── Retention ─────────────────────────────────────────────────────────────────
log "Applying retention policy (keep within ${KEEP_WITHIN})..."
restic -r "$RESTIC_REPOSITORY" \
    --password-file "$RESTIC_PASSWORD_FILE" \
    forget \
    --keep-within "$KEEP_WITHIN" \
    --prune \
    || error "Restic retention policy failed"

echo "----------------------------------------------------------------------"
log "Binary log backup completed successfully."
echo "----------------------------------------------------------------------"
