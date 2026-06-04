#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check_item() {
  local path="$1"
  local label="$2"

  if [ -e "$SCRIPT_DIR/$path" ]; then
    echo "[OK]    $label -> $path"
  else
    echo "[FEHLT] $label -> $path"
  fi
}

main() {
  echo "============================================"
  echo " PROJECT HEALTH CHECK"
  echo "============================================"
  echo "Projektordner: $SCRIPT_DIR"
  echo

  check_item "README.md" "README"
  check_item "backup.sh" "Backup Script"
  check_item "diskspace.sh" "Diskspace Script"
  check_item "systeminfo.sh" "Systeminfo Script"
  check_item "usercheck.sh" "Usercheck Script"
  check_item "user-network-audit.sh" "Audit Script"
  check_item "dashboard.html" "Dashboard"
  check_item "reports" "Report Ordner"
  check_item "backups" "Backup Ordner"

  echo
  echo "Dateiübersicht:"
  find "$SCRIPT_DIR" -maxdepth 1 -mindepth 1 | sort
}

main