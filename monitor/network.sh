#!/bin/bash

set -u

SHOW_ALL=0
SHOW_GATEWAY=1
SHOW_DNS=1

show_help() {
  cat <<EOF
Usage:
  bash network.sh [options]

Options:
  --all           Volle Netzwerkausgabe
  --no-gateway    Gateway nicht anzeigen
  --no-dns        DNS nicht anzeigen
  -h, --help      Hilfe
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --all)
        SHOW_ALL=1
        shift
        ;;
      --no-gateway)
        SHOW_GATEWAY=0
        shift
        ;;
      --no-dns)
        SHOW_DNS=0
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

print_windows_summary() {
  echo "[Windows Netzwerkübersicht]"

  if command -v ipconfig.exe >/dev/null 2>&1; then
    ipconfig.exe | tr -d '\r'
  else
    echo "ipconfig.exe nicht verfügbar"
  fi
}

print_ip_only() {
  echo "[IPv4]"
  if command -v ipconfig.exe >/dev/null 2>&1; then
    ipconfig.exe | tr -d '\r' | grep -i "IPv4"
  elif command -v ifconfig >/dev/null 2>&1; then
    ifconfig | grep -i "inet "
  else
    echo "Keine IP-Informationen verfügbar"
  fi
}

print_gateway() {
  if [ "$SHOW_GATEWAY" -eq 1 ]; then
    echo
    echo "[Gateway]"
    if command -v ipconfig.exe >/dev/null 2>&1; then
      ipconfig.exe | tr -d '\r' | grep -i "Default Gateway"
    else
      echo "Gateway nicht verfügbar"
    fi
  fi
}

print_dns() {
  if [ "$SHOW_DNS" -eq 1 ]; then
    echo
    echo "[DNS]"
    if command -v ipconfig.exe >/dev/null 2>&1; then
      ipconfig.exe /all | tr -d '\r' | grep -i "DNS"
    else
      echo "DNS nicht verfügbar"
    fi
  fi
}

main() {
  parse_args "$@"

  echo "=========================================="
  echo " Network Monitor"
  echo "=========================================="

  if [ "$SHOW_ALL" -eq 1 ]; then
    print_windows_summary
  else
    print_ip_only
    print_gateway
    print_dns
  fi
}

main "$@"