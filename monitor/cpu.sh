#!/bin/bash

set -u

SHOW_DETAILS=0

show_help() {
  cat <<EOF
Usage:
  bash ram.sh [options]

Options:
  --details        Zusätzliche Details anzeigen
  -h, --help       Hilfe
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --details)
        SHOW_DETAILS=1
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

print_linux_free() {
  echo "[RAM via free]"
  free -h
}

print_windows_memory() {
  echo "[RAM via PowerShell]"
  powershell.exe -Command "
    \$os = Get-CimInstance Win32_OperatingSystem
    \$total = [math]::Round(\$os.TotalVisibleMemorySize / 1MB, 2)
    \$free  = [math]::Round(\$os.FreePhysicalMemory / 1MB, 2)
    \$used  = [math]::Round(\$total - \$free, 2)
    \$percent = [math]::Round((\$used / \$total) * 100, 2)
    Write-Output ('Total RAM : ' + \$total + ' GB')
    Write-Output ('Used RAM  : ' + \$used + ' GB')
    Write-Output ('Free RAM  : ' + \$free + ' GB')
    Write-Output ('Usage     : ' + \$percent + '%')
  " 2>/dev/null | tr -d '\r'
}

print_windows_details() {
  echo
  echo "[RAM Details]"
  powershell.exe -Command "
    Get-CimInstance Win32_PhysicalMemory |
    Select-Object BankLabel, Capacity, Speed, Manufacturer |
    Format-Table -AutoSize
  " 2>/dev/null | tr -d '\r'
}

main() {
  parse_args "$@"

  echo "=========================================="
  echo " RAM Monitor"
  echo "=========================================="

  if command -v free >/dev/null 2>&1; then
    print_linux_free
  elif command -v powershell.exe >/dev/null 2>&1; then
    print_windows_memory
  else
    echo "Keine RAM-Informationen verfügbar"
  fi

  if [ "$SHOW_DETAILS" -eq 1 ] && command -v powershell.exe >/dev/null 2>&1; then
    print_windows_details
  fi
}

main "$@"