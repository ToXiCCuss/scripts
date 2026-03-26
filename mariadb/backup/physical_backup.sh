#!/bin/bash
# =============================================================================
# mariadb_physical_backup.sh
# MariaDB physical backup using mariabackup + restic
# - First run: creates a full backup
# - Subsequent runs: creates incremental, merges into full, uploads via restic
# =============================================================================

set -euo pipefail

# Import notification library
source "$(dirname "$0")/../../linux/notifications.sh"
DISCORD_ERROR_TITLE="MariaDB Physical Backup"

# ── Configuration ─────────────────────────────────────────────────────────────
RESTIC_REPOSITORY="rclone:pCloud:/Backups/mariadb_pb"
RESTIC_PASSWORD_FILE="/root/restic"

BACKUP_BASE="/var/backups/mariadb"
FULL_DIR="${BACKUP_BASE}/full"
INC_DIR="${BACKUP_BASE}/inc_$(date +%Y-%m-%d_%H-%M)"

# ── Helpers ───────────────────────────────────────────────────────────────────
log()   { echo "[INFO]  $*"; }
error() { echo "[ERROR] $*" >&2; send_discord_error "$*"; exit 1; }

echo "----------------------------------------------------------------------"
log "Starting MariaDB physical backup..."

# ── Check dependencies ────────────────────────────────────────────────────────
command -v mariabackup &>/dev/null || error "mariabackup is not installed"
command -v restic      &>/dev/null || error "restic is not installed"
command -v rclone      &>/dev/null || error "rclone is not installed"

[[ -f "$RESTIC_PASSWORD_FILE" ]] || error "Restic password file not found: $RESTIC_PASSWORD_FILE"

# ── Full backup ───────────────────────────────────────────────────────────────
run_full_backup() {
    log "No existing full backup found – creating initial full backup..."
    mkdir -p "$FULL_DIR"

    mariabackup --backup \
        --target-dir="$FULL_DIR" \
        || error "Full backup failed"

    log "Preparing full backup..."
    mariabackup --prepare \
        --target-dir="$FULL_DIR" \
        || error "Preparing full backup failed"

    log "Full backup created and prepared: $FULL_DIR"
}

# ── Incremental backup ────────────────────────────────────────────────────────
run_incremental_backup() {
    log "Existing full backup found – creating incremental backup..."
    mkdir -p "$INC_DIR"

    # 1. Upload current full backup BEFORE merging (safe restore point)
    log "Uploading current full backup to Restic before merge..."
    restic -r "$RESTIC_REPOSITORY" \
        --password-file "$RESTIC_PASSWORD_FILE" \
        backup "$FULL_DIR" \
        || error "Restic upload of full backup failed"

    # 2. Create incremental backup based on existing full
    log "Creating incremental backup..."
    mariabackup --backup \
        --target-dir="$INC_DIR" \
        --incremental-basedir="$FULL_DIR" \
        || error "Incremental backup failed"

    # 3. Merge incremental into full
    log "Merging incremental backup into full backup..."
    mariabackup --prepare \
        --target-dir="$FULL_DIR" \
        --incremental-dir="$INC_DIR" \
        || error "Merging incremental backup failed"

    # 4. Remove temporary incremental directory
    log "Removing temporary incremental directory..."
    rm -rf "$INC_DIR"

    log "Incremental backup merged into full: $FULL_DIR"
}

# ── Upload merged full backup ─────────────────────────────────────────────────
upload_backup() {
    log "Uploading merged full backup to Restic..."
    restic -r "$RESTIC_REPOSITORY" \
        --password-file "$RESTIC_PASSWORD_FILE" \
        backup "$FULL_DIR" \
        || error "Restic upload of merged backup failed"
}

# ── Main ──────────────────────────────────────────────────────────────────────
# Check if a full backup already exists and is non-empty
if [[ ! -d "$FULL_DIR" ]] || [[ -z "$(ls -A "$FULL_DIR" 2>/dev/null)" ]]; then
    run_full_backup
else
    run_incremental_backup
fi

upload_backup

echo "----------------------------------------------------------------------"
log "Physical backup completed successfully."
echo "----------------------------------------------------------------------"
