#!/bin/bash

set -u

show_header() {
  echo "============================================================"
  echo " NETWORK SWEEP"
  echo "============================================================"
}

validate_base() {
  case "$1" in
    *[!0-9.]*|'')
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

ping_host() {
  local host="$1"

  if ping -n 1 -w 300 "$host" >/dev/null 2>&1; then
    return 0
  fi

  if ping -c 1 -W 1 "$host" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

sweep_range() {
  local base="$1"
  local start="$2"
  local end="$3"

  echo
  echo "[Scan von $base.$start bis $base.$end]"
  echo

  for ((i=start; i<=end; i++)); do
    host="$base.$i"
    if ping_host "$host"; then
      echo "[UP]   $host"
    else
      echo "[DOWN] $host"
    fi
  done
}

main() {
  show_header

  read -rp "IP-Basis eingeben (z.B. 192.168.178): " base
  read -rp "Start-Host (z.B. 1): " start
  read -rp "End-Host (z.B. 20): " end

  if ! validate_base "$base"; then
    echo "Ungültige IP-Basis."
    exit 1
  fi

  if ! [[ "$start" =~ ^[0-9]+$ ]] || ! [[ "$end" =~ ^[0-9]+$ ]]; then
    echo "Start und Ende müssen Zahlen sein."
    exit 1
  fi

  if [ "$start" -gt "$end" ]; then
    echo "Start darf nicht größer als Ende sein."
    exit 1
  fi

  sweep_range "$base" "$start" "$end"
}

main