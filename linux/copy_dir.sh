#!/bin/bash

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"

log() { [ "${QUIET:-0}" = "1" ] && return 0; echo -e "$*"; }
log_err() { echo -e "[ERROR] $*" 1>&2; }

show_help() {
  cat <<EOF
$SCRIPT_NAME - Sync source into target with ownership reset

Usage:
  $SCRIPT_NAME -s <source> -t <target> -o <uid:gid|user:group>

Options:
  -s, --source    SOURCE_DIR   Source directory (required)
  -t, --target    TARGET_DIR   Target directory (required)
  -o, --owner     OWNER        Owner spec uid:gid or user:group (required)

Environment variables (alternatives to flags):
  SOURCE_DIR, TARGET_DIR, OWNER
EOF
}

SOURCE_DIR="${SOURCE_DIR:-}"
TARGET_DIR="${TARGET_DIR:-}"
OWNER="${OWNER:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    -s|--source) SOURCE_DIR="$2"; shift 2;;
    -t|--target) TARGET_DIR="$2"; shift 2;;
    -o|--owner)  OWNER="$2"; shift 2;;
    -h|--help)   show_help; exit 0;;
    --) shift; break;;
    -*) log_err "Unknown option: $1"; show_help; exit 1;;
    *)  break;;
  esac
done

if [ -z "${SOURCE_DIR}" ] || [ -z "${TARGET_DIR}" ] || [ -z "${OWNER}" ]; then
  log_err "Missing required arguments."
  show_help
  exit 1
fi

SOURCE_DIR="$(readlink -f -- "$SOURCE_DIR")" || true
TARGET_DIR="$(readlink -f -- "$TARGET_DIR" 2>/dev/null || echo "$TARGET_DIR")"

if [ ! -d "$SOURCE_DIR" ]; then
  log_err "Source directory does not exist or is not a directory: $SOURCE_DIR"
  exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
  log "Creating target directory: $TARGET_DIR"
  mkdir -p -- "$TARGET_DIR"
fi

if [ "$TARGET_DIR" = "/" ] || [ "$TARGET_DIR" = "/root" ]; then
  log_err "Refusing to operate on critical directory: $TARGET_DIR"
  exit 1
fi

resolve_id() {
  local type="$1" value="$2" resolved=""
  if [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "$value"
    return 0
  fi
  if [ "$type" = "user" ]; then
    resolved=$(id -u "$value" 2>/dev/null || true)
  else
    resolved=$(getent group "$value" | awk -F: '{print $3}' 2>/dev/null || true)
  fi
  if [ -z "$resolved" ]; then
    log_err "Failed to resolve $type: $value"
    exit 1
  fi
  echo "$resolved"
}

OWNER_USER_PART="${OWNER%%:*}"
OWNER_GROUP_PART="${OWNER##*:}"
if [ -z "$OWNER_USER_PART" ] || [ -z "$OWNER_GROUP_PART" ] || [ "$OWNER" = "$OWNER_USER_PART" ]; then
  log_err "OWNER must be in format uid:gid or user:group"
  exit 1
fi

UID_NUM=$(resolve_id user "$OWNER_USER_PART")
GID_NUM=$(resolve_id group "$OWNER_GROUP_PART")

log "Source: $SOURCE_DIR"
log "Target: $TARGET_DIR"
log "Owner:  $UID_NUM:$GID_NUM (from input '$OWNER')"

log "Deleting contents of target directory: $TARGET_DIR"
if ! find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +; then
  log_err "Failed to delete contents of $TARGET_DIR"
  exit 2
fi

copy_with_rsync() {
  if command -v rsync >/dev/null 2>&1; then
    rsync -aHAX --delete --numeric-ids "$SOURCE_DIR/" "$TARGET_DIR/"
  else
    cp -aT -- "$SOURCE_DIR" "$TARGET_DIR"
  fi
}

log "Copying contents from source to target"
if ! copy_with_rsync; then
  log_err "Copy operation failed"
  exit 2
fi

log "Setting ownership recursively on target"
if ! chown -R -- "${UID_NUM}:${GID_NUM}" "$TARGET_DIR"; then
  log_err "Failed to chown $TARGET_DIR"
  exit 2
fi

log "Done."
