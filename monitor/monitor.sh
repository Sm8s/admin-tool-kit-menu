#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/monitor.log"
SAVE_LOG=0
SHOW_TOP=1

show_help() {
  cat <<EOF
Usage:
  bash monitor.sh [options]

Options:
  --log           Ausgabe zusätzlich in monitor.log speichern
  --no-top        Keine Top-Prozesse im CPU-Modul
  -h, --help      Hilfe
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --log)
        SAVE_LOG=1
        shift
        ;;
      --no-top)
        SHOW_TOP=0
        shift
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        echo "Unbekanntes Argument: $1"
        exit 1
        ;;
    esac
  done
}

run_module() {
  local name="$1"
  shift

  echo
  echo "##################################################"
  echo "# Modul: $name"
  echo "##################################################"

  if [ "$SAVE_LOG" -eq 1 ]; then
    bash "$@" 2>&1 | tee -a "$LOG_FILE"
  else
    bash "$@"
  fi
}

main() {
  parse_args "$@"

  if [ "$SAVE_LOG" -eq 1 ]; then
    : > "$LOG_FILE"
  fi

  echo "=================================================="
  echo " Linux / Windows Monitoring Dashboard"
  echo "=================================================="
  echo "Zeit: $(date)"
  echo "Pfad: $SCRIPT_DIR"

  if [ "$SHOW_TOP" -eq 1 ]; then
    run_module "CPU" "$SCRIPT_DIR/cpu.sh" --top --top-count 5
  else
    run_module "CPU" "$SCRIPT_DIR/cpu.sh"
  fi

  run_module "RAM" "$SCRIPT_DIR/ram.sh" --details
  run_module "DISK" "$SCRIPT_DIR/disk.sh"
  run_module "NETWORK" "$SCRIPT_DIR/network.sh"

  echo
  echo "Monitoring abgeschlossen."
  if [ "$SAVE_LOG" -eq 1 ]; then
    echo "Logdatei: $LOG_FILE"
  fi
}

main "$@"