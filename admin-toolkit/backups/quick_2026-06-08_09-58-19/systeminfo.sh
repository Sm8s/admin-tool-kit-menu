#!/bin/bash

set -u

VERSION="2.0.0"
SHOW_ENV=0
SHOW_PATHS=0
SHOW_PROCESSES=0
OUTPUT_FORMAT="text"

print_header() {
  echo "=========================================="
  echo " Advanced System Info"
  echo " Version: $VERSION"
  echo "=========================================="
}

show_help() {
  cat <<EOF
Usage:
  bash systeminfo.sh [options]

Options:
  --env             Umgebungsvariablen anzeigen
  --paths           Wichtige Pfade anzeigen
  --processes       Prozessliste anzeigen
  --json            Ausgabe als JSON-ähnlichen Text
  -h, --help        Hilfe
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --env)
        SHOW_ENV=1
        shift
        ;;
      --paths)
        SHOW_PATHS=1
        shift
        ;;
      --processes)
        SHOW_PROCESSES=1
        shift
        ;;
      --json)
        OUTPUT_FORMAT="json"
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

cmd_or_default() {
  local cmd="$1"
  local fallback="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "yes"
  else
    echo "$fallback"
  fi
}

get_hostname_value() {
  hostname 2>/dev/null || echo "unbekannt"
}

get_kernel_value() {
  uname -a 2>/dev/null || echo "nicht verfügbar"
}

get_os_value() {
  uname -s 2>/dev/null || echo "Windows/Git Bash"
}

get_arch_value() {
  uname -m 2>/dev/null || echo "unbekannt"
}

get_uptime_value() {
  uptime 2>/dev/null || echo "nicht verfügbar"
}

get_current_user() {
  whoami 2>/dev/null || echo "unbekannt"
}

get_shell_value() {
  echo "${SHELL:-nicht gesetzt}"
}

get_home_value() {
  echo "${HOME:-nicht gesetzt}"
}

get_path_value() {
  echo "${PATH:-nicht gesetzt}"
}

get_disk_overview() {
  df -h 2>/dev/null || echo "df nicht verfügbar"
}

get_memory_overview() {
  free -h 2>/dev/null || echo "free nicht verfügbar"
}

get_network_overview() {
  ipconfig 2>/dev/null || ifconfig 2>/dev/null || echo "Kein Netzwerkbefehl verfügbar"
}

get_process_overview() {
  ps -ef 2>/dev/null || ps 2>/dev/null || echo "ps nicht verfügbar"
}

print_text_output() {
  print_header
  echo "Benutzer        : $(get_current_user)"
  echo "Hostname        : $(get_hostname_value)"
  echo "Betriebssystem  : $(get_os_value)"
  echo "Architektur     : $(get_arch_value)"
  echo "Kernel          : $(get_kernel_value)"
  echo "Shell           : $(get_shell_value)"
  echo "Home            : $(get_home_value)"
  echo "Datum           : $(date)"
  echo "Verzeichnis     : $(pwd)"
  echo "Uptime          : $(get_uptime_value)"
  echo

  echo "[Disk]"
  get_disk_overview
  echo

  echo "[Memory]"
  get_memory_overview
  echo

  echo "[Network]"
  get_network_overview
  echo

  if [ "$SHOW_PATHS" -eq 1 ]; then
    echo "[Paths]"
    echo "$PATH" | tr ':' '\n'
    echo
  fi

  if [ "$SHOW_ENV" -eq 1 ]; then
    echo "[Environment]"
    env | sort
    echo
  fi

  if [ "$SHOW_PROCESSES" -eq 1 ]; then
    echo "[Processes]"
    get_process_overview
    echo
  fi
}

print_json_output() {
  cat <<EOF
{
  "user": "$(get_current_user)",
  "hostname": "$(get_hostname_value)",
  "os": "$(get_os_value)",
  "arch": "$(get_arch_value)",
  "shell": "$(get_shell_value)",
  "home": "$(get_home_value)",
  "date": "$(date)",
  "pwd": "$(pwd)"
}
EOF
}

main() {
  parse_args "$@"

  case "$OUTPUT_FORMAT" in
    text) print_text_output ;;
    json) print_json_output ;;
    *)
      echo "Ungültiges Format"
      exit 1
      ;;
  esac
}

main "$@"