#!/bin/bash

set -u

TARGET_USER=""
SHOW_GROUPS=1
SHOW_HOME=1
SHOW_LASTLOG=0

show_help() {
  cat <<EOF
Usage:
  bash usercheck.sh [username] [options]

Options:
  --no-groups       Gruppen nicht anzeigen
  --no-home         Home-Verzeichnis nicht anzeigen
  --lastlog         lastlog versuchen
  -h, --help        Hilfe
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --no-groups)
        SHOW_GROUPS=0
        shift
        ;;
      --no-home)
        SHOW_HOME=0
        shift
        ;;
      --lastlog)
        SHOW_LASTLOG=1
        shift
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        if [ -z "$TARGET_USER" ]; then
          TARGET_USER="$1"
          shift
        else
          echo "Unbekanntes Argument: $1"
          exit 1
        fi
        ;;
    esac
  done
}

detect_user() {
  if [ -z "$TARGET_USER" ]; then
    TARGET_USER="$(whoami 2>/dev/null || echo unknown)"
  fi
}

print_header() {
  echo "=========================================="
  echo " User Check Utility"
  echo "=========================================="
}

show_basic_info() {
  echo "Benutzer        : $TARGET_USER"

  if command -v id >/dev/null 2>&1; then
    echo "ID Info         : $(id "$TARGET_USER" 2>/dev/null || echo 'nicht verfügbar')"
  else
    echo "ID Info         : id nicht verfügbar"
  fi
}

show_groups() {
  if [ "$SHOW_GROUPS" -eq 1 ]; then
    if command -v groups >/dev/null 2>&1; then
      echo "Gruppen         : $(groups "$TARGET_USER" 2>/dev/null || echo 'nicht verfügbar')"
    else
      echo "Gruppen         : groups nicht verfügbar"
    fi
  fi
}

show_home() {
  if [ "$SHOW_HOME" -eq 1 ]; then
    if [ "$TARGET_USER" = "$(whoami 2>/dev/null)" ]; then
      echo "Home            : ${HOME:-nicht gesetzt}"
    else
      echo "Home            : Fremder Benutzer unter Windows/Git Bash evtl. nicht auflösbar"
    fi
  fi
}

show_lastlog() {
  if [ "$SHOW_LASTLOG" -eq 1 ]; then
    if command -v lastlog >/dev/null 2>&1; then
      echo
      echo "[Lastlog]"
      lastlog -u "$TARGET_USER" 2>/dev/null || echo "lastlog fehlgeschlagen"
    else
      echo "Lastlog         : lastlog nicht verfügbar"
    fi
  fi
}

show_directory_info() {
  echo "Aktuelles Verzeichnis : $(pwd)"
  echo "Shell                 : ${SHELL:-nicht gesetzt}"
}

main() {
  parse_args "$@"
  detect_user
  print_header
  show_basic_info
  show_groups
  show_home
  show_directory_info
  show_lastlog
}

main "$@"