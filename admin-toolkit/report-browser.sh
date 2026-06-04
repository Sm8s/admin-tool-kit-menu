#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="$SCRIPT_DIR/reports"

show_header() {
  echo "============================================"
  echo " REPORT BROWSER"
  echo "============================================"
}

list_reports() {
  if [ ! -d "$REPORT_DIR" ]; then
    echo "Report-Ordner nicht gefunden: $REPORT_DIR"
    return 1
  fi

  mapfile -t REPORTS < <(find "$REPORT_DIR" -maxdepth 1 -type f | sort)

  if [ "${#REPORTS[@]}" -eq 0 ]; then
    echo "Keine Reports gefunden."
    return 1
  fi

  local i=1
  for file in "${REPORTS[@]}"; do
    echo "$i) $(basename "$file")"
    i=$((i + 1))
  done
}

show_latest_report() {
  local latest
  latest="$(find "$REPORT_DIR" -maxdepth 1 -type f | sort | tail -n 1)"

  if [ -z "$latest" ]; then
    echo "Kein neuester Report gefunden."
    return
  fi

  echo
  echo "Neuester Report: $(basename "$latest")"
  echo "--------------------------------------------"
  head -n 40 "$latest"
}

open_selected_report() {
  local number="$1"
  mapfile -t REPORTS < <(find "$REPORT_DIR" -maxdepth 1 -type f | sort)

  if [ -z "${REPORTS[$((number - 1))]:-}" ]; then
    echo "Ungültige Auswahl."
    return
  fi

  local file="${REPORTS[$((number - 1))]}"
  echo
  echo "Datei: $(basename "$file")"
  echo "--------------------------------------------"
  head -n 80 "$file"
}

main() {
  show_header
  list_reports || exit 1

  echo
  read -rp "Nummer zum Anzeigen oder [L] für latest: " choice

  case "$choice" in
    [Ll]) show_latest_report ;;
    *)
      if [[ "$choice" =~ ^[0-9]+$ ]]; then
        open_selected_report "$choice"
      else
        echo "Ungültige Eingabe."
      fi
      ;;
  esac
}

main