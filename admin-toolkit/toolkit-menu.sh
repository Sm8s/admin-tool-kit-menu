#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="$SCRIPT_DIR/reports"
BACKUP_DIR="$SCRIPT_DIR/backups"

pause_screen() {
  echo
  read -rp "Enter drücken zum Fortfahren..."
}

clear_screen() {
  clear 2>/dev/null || printf "\033c"
}

header() {
  clear_screen
  echo "============================================================"
  echo " ADMIN TOOLKIT CONTROL CENTER"
  echo "============================================================"
  echo "Projektordner : $SCRIPT_DIR"
  echo "Benutzer      : $(whoami 2>/dev/null || echo unknown)"
  echo "Datum         : $(date)"
  echo "============================================================"
  echo
}

section() {
  echo
  echo "------------------------------------------------------------"
  echo "$1"
  echo "------------------------------------------------------------"
}

run_script() {
  local script="$1"
  if [ -f "$SCRIPT_DIR/$script" ]; then
    bash "$SCRIPT_DIR/$script"
  else
    echo "Skript nicht gefunden: $script"
  fi
}

open_dashboard() {
  if [ -f "$SCRIPT_DIR/dashboard.html" ]; then
    if command -v cmd.exe >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
      cmd.exe /c start "" "$(cygpath -w "$SCRIPT_DIR/dashboard.html")" >/dev/null 2>&1
      echo "Dashboard wurde geöffnet."
    else
      echo "Browser-Start aus Git Bash nicht verfügbar."
    fi
  else
    echo "dashboard.html nicht gefunden."
  fi
}

show_project_tree() {
  section "PROJEKTDATEIEN"
  find "$SCRIPT_DIR" -maxdepth 2 | sort
}

show_project_health() {
  section "PROJECT HEALTH CHECK"

  local items=(
    "README.md"
    "backup.sh"
    "diskspace.sh"
    "systeminfo.sh"
    "usercheck.sh"
    "user-network-audit.sh"
    "dashboard.html"
    "reports"
    "backups"
  )

  local item
  for item in "${items[@]}"; do
    if [ -e "$SCRIPT_DIR/$item" ]; then
      echo "[OK]    $item"
    else
      echo "[FEHLT] $item"
    fi
  done
}

show_basic_stats() {
  section "PROJEKTSTATISTIK"

  local file_count dir_count report_count backup_count
  file_count="$(find "$SCRIPT_DIR" -maxdepth 1 -type f | wc -l)"
  dir_count="$(find "$SCRIPT_DIR" -maxdepth 1 -type d | wc -l)"
  report_count=0
  backup_count=0

  [ -d "$REPORT_DIR" ] && report_count="$(find "$REPORT_DIR" -maxdepth 1 -type f | wc -l)"
  [ -d "$BACKUP_DIR" ] && backup_count="$(find "$BACKUP_DIR" -maxdepth 1 | wc -l)"

  echo "Dateien im Hauptordner : $file_count"
  echo "Ordner im Hauptordner  : $dir_count"
  echo "Reports                : $report_count"
  echo "Backups                : $backup_count"
}

report_count_by_type() {
  local ext="$1"
  [ -d "$REPORT_DIR" ] || { echo "0"; return; }
  find "$REPORT_DIR" -maxdepth 1 -type f -name "*.$ext" | wc -l
}

show_reports_summary() {
  section "REPORT SUMMARY"

  if [ ! -d "$REPORT_DIR" ]; then
    echo "Report-Ordner nicht gefunden."
    return
  fi

  echo "TXT  : $(report_count_by_type txt)"
  echo "CSV  : $(report_count_by_type csv)"
  echo "JSON : $(report_count_by_type json)"
  echo
  echo "Neueste Dateien:"
  find "$REPORT_DIR" -maxdepth 1 -type f | sort | tail -n 10
}

open_latest_report() {
  section "NEUSTER REPORT"

  if [ ! -d "$REPORT_DIR" ]; then
    echo "Report-Ordner nicht gefunden."
    return
  fi

  local latest
  latest="$(find "$REPORT_DIR" -maxdepth 1 -type f | sort | tail -n 1)"

  if [ -z "$latest" ]; then
    echo "Kein Report gefunden."
    return
  fi

  echo "Datei: $(basename "$latest")"
  echo
  head -n 80 "$latest"
}

choose_report() {
  section "REPORT AUSWÄHLEN"

  if [ ! -d "$REPORT_DIR" ]; then
    echo "Report-Ordner nicht gefunden."
    return
  fi

  mapfile -t REPORTS < <(find "$REPORT_DIR" -maxdepth 1 -type f | sort)

  if [ "${#REPORTS[@]}" -eq 0 ]; then
    echo "Keine Reports gefunden."
    return
  fi

  local i=1
  for file in "${REPORTS[@]}"; do
    echo "$i) $(basename "$file")"
    i=$((i + 1))
  done

  echo
  read -rp "Nummer wählen: " number

  if [[ "$number" =~ ^[0-9]+$ ]] && [ "$number" -ge 1 ] && [ "$number" -le "${#REPORTS[@]}" ]; then
    local selected="${REPORTS[$((number - 1))]}"
    echo
    echo "Datei: $(basename "$selected")"
    echo "------------------------------------------------------------"
    head -n 100 "$selected"
  else
    echo "Ungültige Auswahl."
  fi
}

git_check_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

show_git_status() {
  section "GIT STATUS"
  if git_check_repo; then
    git status --short
  else
    echo "Kein Git-Repository."
  fi
}

show_git_branch() {
  section "GIT BRANCH"
  if git_check_repo; then
    git branch --show-current
  else
    echo "Kein Git-Repository."
  fi
}

show_git_log() {
  section "GIT LOG"
  if git_check_repo; then
    git log --oneline -10
  else
    echo "Kein Git-Repository."
  fi
}

show_git_remote() {
  section "GIT REMOTE"
  if git_check_repo; then
    git remote -v
  else
    echo "Kein Git-Repository."
  fi
}

git_quick_add_commit() {
  section "GIT QUICK COMMIT"
  if ! git_check_repo; then
    echo "Kein Git-Repository."
    return
  fi

  read -rp "Commit-Nachricht eingeben: " msg
  if [ -z "$msg" ]; then
    echo "Leere Nachricht nicht erlaubt."
    return
  fi

  git add .
  git commit -m "$msg"
}

show_backup_log() {
  section "BACKUP LOG"

  if [ -f "$SCRIPT_DIR/backup.log" ]; then
    tail -n 80 "$SCRIPT_DIR/backup.log"
  else
    echo "backup.log nicht gefunden."
  fi
}

run_quick_backup() {
  section "QUICK BACKUP"

  if [ -f "$SCRIPT_DIR/quick-backup-rsync.sh" ]; then
    bash "$SCRIPT_DIR/quick-backup-rsync.sh"
  elif [ -f "$SCRIPT_DIR/backup.sh" ]; then
    bash "$SCRIPT_DIR/backup.sh"
  else
    echo "Kein Backup-Skript gefunden."
  fi
}

show_system_tools() {
  section "SYSTEM TOOLS"

  echo "Aktuelles Verzeichnis : $(pwd)"
  echo "Benutzer              : $(whoami 2>/dev/null || echo unknown)"
  echo "Hostname              : $(hostname 2>/dev/null || echo unknown)"
  echo "Datum                 : $(date)"
  echo
  echo "[Speicherplatz]"
  df -h 2>/dev/null || echo "df nicht verfügbar"
}

submenu_audit() {
  while true; do
    header
    echo "AUDIT & SYSTEM"
    echo "1) user-network-audit.sh"
    echo "2) systeminfo.sh"
    echo "3) diskspace.sh"
    echo "4) usercheck.sh"
    echo "0) Zurück"
    echo
    read -rp "Auswahl: " choice

    case "$choice" in
      1) run_script "user-network-audit.sh"; pause_screen ;;
      2) run_script "systeminfo.sh"; pause_screen ;;
      3) run_script "diskspace.sh"; pause_screen ;;
      4) run_script "usercheck.sh"; pause_screen ;;
      0) break ;;
      *) echo "Ungültige Auswahl."; pause_screen ;;
    esac
  done
}

submenu_reports() {
  while true; do
    header
    echo "REPORT CENTER"
    echo "1) Report-Zusammenfassung"
    echo "2) Neuesten Report anzeigen"
    echo "3) Report auswählen"
    echo "4) Report-Ordner anzeigen"
    echo "0) Zurück"
    echo
    read -rp "Auswahl: " choice

    case "$choice" in
      1) show_reports_summary; pause_screen ;;
      2) open_latest_report; pause_screen ;;
      3) choose_report; pause_screen ;;
      4) ls -la "$REPORT_DIR" 2>/dev/null || echo "Ordner nicht gefunden."; pause_screen ;;
      0) break ;;
      *) echo "Ungültige Auswahl."; pause_screen ;;
    esac
  done
}

submenu_git() {
  while true; do
    header
    echo "GIT CENTER"
    echo "1) Git-Status"
    echo "2) Aktuelle Branch"
    echo "3) Letzte Commits"
    echo "4) Remote anzeigen"
    echo "5) Quick add + commit"
    echo "0) Zurück"
    echo
    read -rp "Auswahl: " choice

    case "$choice" in
      1) show_git_status; pause_screen ;;
      2) show_git_branch; pause_screen ;;
      3) show_git_log; pause_screen ;;
      4) show_git_remote; pause_screen ;;
      5) git_quick_add_commit; pause_screen ;;
      0) break ;;
      *) echo "Ungültige Auswahl."; pause_screen ;;
    esac
  done
}

submenu_backup() {
  while true; do
    header
    echo "BACKUP CENTER"
    echo "1) Quick Backup starten"
    echo "2) Backup-Ordner anzeigen"
    echo "3) Backup-Log anzeigen"
    echo "0) Zurück"
    echo
    read -rp "Auswahl: " choice

    case "$choice" in
      1) run_quick_backup; pause_screen ;;
      2) ls -la "$BACKUP_DIR" 2>/dev/null || echo "Ordner nicht gefunden."; pause_screen ;;
      3) show_backup_log; pause_screen ;;
      0) break ;;
      *) echo "Ungültige Auswahl."; pause_screen ;;
    esac
  done
}

submenu_project() {
  while true; do
    header
    echo "PROJECT CENTER"
    echo "1) Project Health Check"
    echo "2) Projektstatistik"
    echo "3) Projektdateien anzeigen"
    echo "4) Dashboard öffnen"
    echo "0) Zurück"
    echo
    read -rp "Auswahl: " choice

    case "$choice" in
      1) show_project_health; pause_screen ;;
      2) show_basic_stats; pause_screen ;;
      3) show_project_tree; pause_screen ;;
      4) open_dashboard; pause_screen ;;
      0) break ;;
      *) echo "Ungültige Auswahl."; pause_screen ;;
    esac
  done
}

submenu_tools() {
  while true; do
    header
    echo "TOOLS"
    echo "1) System-Werkzeuge anzeigen"
    echo "2) Aktuellen Pfad anzeigen"
    echo "3) Reports-Ordner öffnen"
    echo "4) Backups-Ordner öffnen"
    echo "0) Zurück"
    echo
    read -rp "Auswahl: " choice

    case "$choice" in
      1) show_system_tools; pause_screen ;;
      2) pwd; pause_screen ;;
      3) ls -la "$REPORT_DIR" 2>/dev/null || echo "Ordner nicht gefunden."; pause_screen ;;
      4) ls -la "$BACKUP_DIR" 2>/dev/null || echo "Ordner nicht gefunden."; pause_screen ;;
      0) break ;;
      *) echo "Ungültige Auswahl."; pause_screen ;;
    esac
  done
}

main_menu() {
  while true; do
    header
    echo "HAUPTMENÜ"
    echo "1) Audit & System"
    echo "2) Report Center"
    echo "3) Git Center"
    echo "4) Backup Center"
    echo "5) Project Center"
    echo "6) Tools"
    echo "0) Beenden"
    echo
    read -rp "Auswahl: " choice

    case "$choice" in
      1) submenu_audit ;;
      2) submenu_reports ;;
      3) submenu_git ;;
      4) submenu_backup ;;
      5) submenu_project ;;
      6) submenu_tools ;;
      0) echo "Programm beendet."; exit 0 ;;
      *) echo "Ungültige Auswahl."; pause_screen ;;
    esac
  done
}

main_menu