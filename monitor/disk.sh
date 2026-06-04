#!/bin/bash

set -u

WARNING_THRESHOLD=80
CRITICAL_THRESHOLD=90
SHOW_ALL=1
SORT_OUTPUT=1

show_help() {
  cat <<EOF
Usage:
  bash disk.sh [options]

Options:
  -w, --warning NUM     Warning threshold in %
  -c, --critical NUM    Critical threshold in %
  -a, --all             Alle Dateisysteme anzeigen
  -s, --sort            Nach Belegung sortieren
  -h, --help            Hilfe
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -w|--warning)
        WARNING_THRESHOLD="$2"
        shift 2
        ;;
      -c|--critical)
        CRITICAL_THRESHOLD="$2"
        shift 2
        ;;
      -a|--all)
        SHOW_ALL=1
        shift
        ;;
      -s|--sort)
        SORT_OUTPUT=1
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

is_number() {
  case "$1" in
    ''|*[!0-9]*)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

print_header() {
  echo "=========================================="
  echo " Disk Monitor"
  echo "=========================================="
}

collect_data() {
  df -hP 2>/dev/null | awk 'NR>1 {
    filesystem=$1
    size=$2
    used=$3
    avail=$4
    usep=$5
    mount=$6
    gsub(/%/, "", usep)
    print filesystem "|" size "|" used "|" avail "|" usep "|" mount
  }'
}

print_line() {
  local filesystem="$1"
  local size="$2"
  local used="$3"
  local avail="$4"
  local usep="$5"
  local mount="$6"
  local state="OK"

  if ! is_number "$usep"; then
    printf "%-10s | %-20s | size=%-8s used=%-8s avail=%-8s use=%-5s | %s\n" \
      "SKIPPED" "$mount" "$size" "$used" "$avail" "$usep" "$filesystem"
    return
  fi

  if [ "$usep" -ge "$CRITICAL_THRESHOLD" ]; then
    state="CRITICAL"
  elif [ "$usep" -ge "$WARNING_THRESHOLD" ]; then
    state="WARNING"
  fi

  if [ "$SHOW_ALL" -eq 1 ] || [ "$state" != "OK" ]; then
    printf "%-10s | %-20s | size=%-8s used=%-8s avail=%-8s use=%-5s | %s\n" \
      "$state" "$mount" "$size" "$used" "$avail" "${usep}%" "$filesystem"
  fi
}

main() {
  parse_args "$@"
  print_header

  local data
  data="$(collect_data)"

  if [ -z "$data" ]; then
    echo "Keine verwertbare df-Ausgabe gefunden."
    exit 1
  fi

  if [ "$SORT_OUTPUT" -eq 1 ]; then
    data="$(echo "$data" | sort -t'|' -k5,5nr)"
  fi

  while IFS='|' read -r filesystem size used avail usep mount; do
    [ -z "$filesystem" ] && continue
    print_line "$filesystem" "$size" "$used" "$avail" "$usep" "$mount"
  done <<< "$data"
}

main "$@"