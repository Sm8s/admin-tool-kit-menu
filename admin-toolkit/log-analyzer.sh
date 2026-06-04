#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="$SCRIPT_DIR/reports"

show_header() {
  echo "============================================================"
  echo " LOG ANALYZER"
  echo "============================================================"
}

list_files() {
  find "$REPORT_DIR" -maxdepth 1 -type f | sort
}

analyze_file() {
  local file="$1"

  echo
  echo "Datei: $(basename "$file")"
  echo "------------------------------------------------------------"

  grep -inE 'error|warn|warning|fail|failed|critical|success|ok' "$file" 2>/dev/null | head -n 30

  if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    echo "Keine typischen Log-Treffer gefunden."
  fi
}

analyze_all() {
  local found=0
  while read -r file; do
    [ -z "$file" ] && continue
    found=1
    analyze_file "$file"
  done < <(list_files)

  if [ "$found" -eq 0 ]; then
    echo "Keine Dateien in reports/ gefunden."
  fi
}

search_custom_term() {
  read -rp "Suchbegriff: " term

  if [ -z "$term" ]; then
    echo "Leerer Suchbegriff."
    return
  fi

  while read -r file; do
    [ -z "$file" ] && continue
    echo
    echo "Datei: $(basename "$file")"
    grep -in "$term" "$file" 2>/dev/null | head -n 20 || echo "Kein Treffer."
  done < <(list_files)
}

main() {
  show_header

  if [ ! -d "$REPORT_DIR" ]; then
    echo "Ordner reports/ nicht gefunden."
    exit 1
  fi

  echo "1) Alle Reports analysieren"
  echo "2) Eigenen Begriff suchen"
  echo
  read -rp "Auswahl: " choice

  case "$choice" in
    1) analyze_all ;;
    2) search_custom_term ;;
    *) echo "Ungültige Auswahl." ;;
  esac
}

main