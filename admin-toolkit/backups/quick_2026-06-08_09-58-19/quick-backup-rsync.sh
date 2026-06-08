#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR"
BACKUP_DIR="$SCRIPT_DIR/backups/quick_$(date +%Y-%m-%d_%H-%M-%S)"

main() {
  echo "============================================"
  echo " QUICK BACKUP"
  echo "============================================"

  mkdir -p "$BACKUP_DIR"

  if command -v rsync >/dev/null 2>&1; then
    echo "Nutze rsync..."
    rsync -av --exclude 'backups' --exclude 'reports' "$SOURCE_DIR/" "$BACKUP_DIR/"
  else
    echo "rsync nicht gefunden, nutze cp..."
    cp -r "$SOURCE_DIR"/* "$BACKUP_DIR"/ 2>/dev/null
  fi

  echo
  echo "Backup erstellt in:"
  echo "$BACKUP_DIR"
}

main