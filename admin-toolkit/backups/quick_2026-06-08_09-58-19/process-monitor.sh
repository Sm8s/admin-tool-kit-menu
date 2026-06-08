#!/bin/bash

set -u

show_header() {
  echo "============================================================"
  echo " PROCESS MONITOR"
  echo "============================================================"
}

show_all_processes() {
  echo
  echo "[Top 25 Prozesse]"
  ps -ef 2>/dev/null | head -n 25 || ps 2>/dev/null | head -n 25
}

search_process() {
  echo
  read -rp "Prozessname suchen: " pname

  if [ -z "$pname" ]; then
    echo "Kein Prozessname eingegeben."
    return
  fi

  echo
  echo "[Suche nach: $pname]"
  ps -ef 2>/dev/null | grep -i "$pname" | grep -v grep || \
  ps 2>/dev/null | grep -i "$pname" | grep -v grep || \
  echo "Kein passender Prozess gefunden."
}

show_user_processes() {
  echo
  echo "[Prozesse des aktuellen Benutzers]"
  ps -u "$(whoami 2>/dev/null)" 2>/dev/null || echo "Benutzerfilter nicht verfügbar."
}

main() {
  while true; do
    show_header
    echo "1) Top Prozesse anzeigen"
    echo "2) Prozess suchen"
    echo "3) Meine Prozesse anzeigen"
    echo "0) Beenden"
    echo

    read -rp "Auswahl: " choice

    case "$choice" in
      1) show_all_processes ;;
      2) search_process ;;
      3) show_user_processes ;;
      0) exit 0 ;;
      *) echo "Ungültige Auswahl." ;;
    esac

    echo
    read -rp "Enter drücken zum Fortfahren..." _
  done
}

main