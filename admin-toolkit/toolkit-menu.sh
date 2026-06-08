#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="$SCRIPT_DIR/reports"
BACKUP_DIR="$SCRIPT_DIR/backups"
LOG_FILE="$SCRIPT_DIR/toolkit-session.log"

USE_COLOR=1
[ -n "${NO_COLOR:-}" ] && USE_COLOR=0

init_theme() {
  if [ "$USE_COLOR" -eq 1 ]; then
    RESET='\033[0m'
    BOLD='\033[1m'
    DIM='\033[2m'
    GREEN='\033[0;32m'
    BRIGHT_GREEN='\033[1;32m'
    CYAN='\033[0;36m'
    YELLOW='\033[0;33m'
    RED='\033[0;31m'
    WHITE='\033[1;37m'
    GRAY='\033[0;90m'
  else
    RESET=''
    BOLD=''
    DIM=''
    GREEN=''
    BRIGHT_GREEN=''
    CYAN=''
    YELLOW=''
    RED=''
    WHITE=''
    GRAY=''
  fi
}

log_action() {
  local msg="$1"
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$msg" >> "$LOG_FILE"
}

pause_screen() {
  echo
  read -rp "Enter drücken zum Fortfahren..." _
}

clear_screen() {
  clear 2>/dev/null || printf "\033c"
}

line() {
  printf "%b\n" "${GREEN}============================================================${RESET}"
}

section() {
  echo
  printf "%b\n" "${CYAN}------------------------------------------------------------${RESET}"
  printf "%b\n" "${WHITE}$1${RESET}"
  printf "%b\n" "${CYAN}------------------------------------------------------------${RESET}"
}

menu_item() {
  printf "%b %b\n" "${BRIGHT_GREEN}[$1]${RESET}" "$2"
}

status_ok() {
  printf "%b\n" "${BRIGHT_GREEN}[OK]${RESET} $1"
}

status_warn() {
  printf "%b\n" "${YELLOW}[WARN]${RESET} $1"
}

status_fail() {
  printf "%b\n" "${RED}[FAIL]${RESET} $1"
}

status_info() {
  printf "%b\n" "${CYAN}[INFO]${RESET} $1"
}

header() {
  clear_screen
  line
  printf "%b\n" "${BRIGHT_GREEN}${BOLD}   █████╗ ██████╗ ███╗   ███╗██╗███╗   ██╗${RESET}"
  printf "%b\n" "${BRIGHT_GREEN}${BOLD}  ██╔══██╗██╔══██╗████╗ ████║██║████╗  ██║${RESET}"
  printf "%b\n" "${BRIGHT_GREEN}${BOLD}  ███████║██║  ██║██╔████╔██║██║██╔██╗ ██║${RESET}"
  printf "%b\n" "${BRIGHT_GREEN}${BOLD}  ██╔══██║██║  ██║██║╚██╔╝██║██║██║╚██╗██║${RESET}"
  printf "%b\n" "${BRIGHT_GREEN}${BOLD}  ██║  ██║██████╔╝██║ ╚═╝ ██║██║██║ ╚████║${RESET}"
  printf "%b\n" "${BRIGHT_GREEN}${BOLD}  ╚═╝  ╚═╝╚═════╝ ╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝${RESET}"
  printf "%b\n" "${CYAN}              TOOLKIT CONTROL CENTER${RESET}"
  line
  printf "%b\n" "${WHITE}Projektordner :${RESET} $SCRIPT_DIR"
  printf "%b\n" "${WHITE}Benutzer      :${RESET} $(whoami 2>/dev/null || echo unknown)"
  printf "%b\n" "${WHITE}Datum         :${RESET} $(date '+%d.%m.%Y %H:%M:%S')"
  printf "%b\n" "${WHITE}Status        :${RESET} ${BRIGHT_GREEN}ONLINE${RESET}"
  line
  echo
}

hacker_boot() {
  clear_screen
  line
  printf "%b\n" "${BRIGHT_GREEN}${BOLD}[BOOT] Initializing toolkit core...${RESET}"
  sleep 0.10
  status_ok "Loading audit modules"
  sleep 0.10
  status_ok "Loading report center"
  sleep 0.10
  status_ok "Loading backup controller"
  sleep 0.10
  status_ok "Loading git center"
  sleep 0.10
  status_ok "Loading project tools"
  sleep 0.10
  status_ok "Loading visual engine"
  sleep 0.10
  status_info "Session log: $LOG_FILE"
  sleep 0.25
}

run_script() {
  local script="$1"
  log_action "Run script requested: $script"
  if [ -f "$SCRIPT_DIR/$script" ]; then
    bash "$SCRIPT_DIR/$script"
  else
    status_fail "Skript nicht gefunden: $script"
  fi
}

open_dashboard() {
  section "DASHBOARD"
  if [ -f "$SCRIPT_DIR/dashboard.html" ]; then
    if command -v cmd.exe >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
      cmd.exe /c start "" "$(cygpath -w "$SCRIPT_DIR/dashboard.html")" >/dev/null 2>&1
      status_ok "Dashboard wurde geöffnet."
    else
      status_warn "Browser-Start aus Git Bash nicht verfügbar."
    fi
  else
    status_fail "dashboard.html nicht gefunden."
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
    "process-monitor.sh"
    "network-sweep.sh"
    "log-analyzer.sh"
    "matrix.sh"
    "dashboard.html"
    "reports"
    "backups"
  )

  local item
  for item in "${items[@]}"; do
    if [ -e "$SCRIPT_DIR/$item" ]; then
      status_ok "$item"
    else
      status_fail "$item"
    fi
  done
}

show_basic_stats() {
  section "PROJEKTSTATISTIK"

  local file_count dir_count report_count backup_count shell_count
  file_count="$(find "$SCRIPT_DIR" -maxdepth 1 -type f | wc -l)"
  dir_count="$(find "$SCRIPT_DIR" -maxdepth 1 -type d | wc -l)"
  shell_count="$(find "$SCRIPT_DIR" -maxdepth 1 -type f -name '*.sh' | wc -l)"
  report_count=0
  backup_count=0

  [ -d "$REPORT_DIR" ] && report_count="$(find "$REPORT_DIR" -maxdepth 1 -type f | wc -l)"
  [ -d "$BACKUP_DIR" ] && backup_count="$(find "$BACKUP_DIR" -maxdepth 1 | wc -l)"

  echo "Dateien im Hauptordner : $file_count"
  echo "Ordner im Hauptordner  : $dir_count"
  echo "Shell-Skripte          : $shell_count"
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
    status_warn "Report-Ordner nicht gefunden."
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
    status_warn "Report-Ordner nicht gefunden."
    return
  fi

  local latest
  latest="$(find "$REPORT_DIR" -maxdepth 1 -type f | sort | tail -n 1)"

  if [ -z "$latest" ]; then
    status_warn "Kein Report gefunden."
    return
  fi

  status_info "Datei: $(basename "$latest")"
  echo
  head -n 80 "$latest"
}

choose_report() {
  section "REPORT AUSWÄHLEN"

  if [ ! -d "$REPORT_DIR" ]; then
    status_warn "Report-Ordner nicht gefunden."
    return
  fi

  mapfile -t REPORTS < <(find "$REPORT_DIR" -maxdepth 1 -type f | sort)

  if [ "${#REPORTS[@]}" -eq 0 ]; then
    status_warn "Keine Reports gefunden."
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
    status_info "Datei: $(basename "$selected")"
    echo "------------------------------------------------------------"
    head -n 100 "$selected"
  else
    status_fail "Ungültige Auswahl."
  fi
}

search_reports() {
  section "REPORT SUCHE"

  if [ ! -d "$REPORT_DIR" ]; then
    status_warn "Report-Ordner nicht gefunden."
    return
  fi

  read -rp "Suchbegriff: " term

  if [ -z "$term" ]; then
    status_warn "Leerer Suchbegriff."
    return
  fi

  local found=0
  while read -r file; do
    [ -z "$file" ] && continue
    if grep -i -q "$term" "$file" 2>/dev/null; then
      echo "Treffer in $(basename "$file")"
      found=1
    fi
  done < <(find "$REPORT_DIR" -maxdepth 1 -type f | sort)

  if [ "$found" -eq 0 ]; then
    status_warn "Keine Treffer gefunden."
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
    status_warn "Kein Git-Repository."
  fi
}

show_git_branch() {
  section "GIT BRANCH"
  if git_check_repo; then
    git branch --show-current
  else
    status_warn "Kein Git-Repository."
  fi
}

show_git_log() {
  section "GIT LOG"
  if git_check_repo; then
    git log --oneline -10
  else
    status_warn "Kein Git-Repository."
  fi
}

show_git_remote() {
  section "GIT REMOTE"
  if git_check_repo; then
    git remote -v
  else
    status_warn "Kein Git-Repository."
  fi
}

git_quick_add_commit() {
  section "GIT QUICK COMMIT"

  if ! git_check_repo; then
    status_warn "Kein Git-Repository."
    return
  fi

  read -rp "Commit-Nachricht eingeben: " msg
  if [ -z "$msg" ]; then
    status_warn "Leere Nachricht nicht erlaubt."
    return
  fi

  git add .
  git commit -m "$msg"
}

git_quick_add_commit() {
  section "GIT QUICK COMMIT"

  if ! git_check_repo; then
    status_warn "Kein Git-Repository."
    return
  fi

  read -rp "Commit-Nachricht eingeben: " msg
  if [ -z "$msg" ]; then
    status_warn "Leere Nachricht nicht erlaubt."
    return
  fi

  git add .
  git commit -m "$msg"
}

show_github_deploy_info() {
  section "GITHUB DEPLOY INFO"

  if ! git_check_repo; then
    status_warn "Kein Git-Repository."
    return
  fi

  echo "Repository: Sm8s/admin-tool-kit-menu"
  echo "Deploy-Ziel: GitHub Pages"
  echo "Voraussetzungen:"
  echo "- Remote origin muss auf GitHub zeigen"
  echo "- index.html ist ideal als Startdatei"
  echo "- Vor jedem Deploy wird automatisch ein Backup erstellt"
  echo "- GitHub Pages muss in den Repo-Settings aktiviert sein"
  echo

  if [ -f "$SCRIPT_DIR/index.html" ]; then
    status_ok "index.html gefunden"
  elif [ -f "$SCRIPT_DIR/dashboard.html" ]; then
    status_ok "dashboard.html gefunden"
    status_info "Hinweis: Für GitHub Pages ist index.html als Startdatei besser."
  elif [ -f "$SCRIPT_DIR/dashboard-3.html" ]; then
    status_ok "dashboard-3.html gefunden"
    status_info "Hinweis: Benenne die Datei am besten in index.html um."
  else
    status_warn "Keine HTML-Startdatei gefunden."
  fi

  echo
  if git remote get-url origin >/dev/null 2>&1; then
    status_info "Remote origin:"
    git remote get-url origin
  else
    status_warn "Kein Remote origin gefunden."
  fi

  echo
  status_info "Mögliche GitHub Pages URL:"
  echo "https://sm8s.github.io/admin-tool-kit-menu/"
}

run_predeploy_backup() {
  section "PRE-DEPLOY BACKUP"

  local stamp
  local target_dir
  local archive_file

  stamp="$(date '+%Y-%m-%d_%H-%M-%S')"
  mkdir -p "$BACKUP_DIR"

  if command -v rsync >/dev/null 2>&1; then
    target_dir="$BACKUP_DIR/predeploy_$stamp"
    mkdir -p "$target_dir"

    status_info "Erstelle rsync-Backup vor Deploy..."
    if rsync -av \
      --exclude ".git" \
      --exclude "backups" \
      --exclude "reports" \
      "$SCRIPT_DIR/" "$target_dir/"; then
      status_ok "Pre-Deploy-rsync-Backup erfolgreich: $target_dir"
      return 0
    else
      status_fail "rsync-Backup fehlgeschlagen."
      return 1
    fi
  fi

  archive_file="$BACKUP_DIR/predeploy_$stamp.tar.gz"
  status_warn "rsync nicht gefunden, nutze tar.gz Fallback..."

  if tar -czf "$archive_file" \
    --exclude=".git" \
    --exclude="backups" \
    --exclude="reports" \
    -C "$SCRIPT_DIR" .; then
    status_ok "Pre-Deploy-tar-Backup erfolgreich: $archive_file"
    return 0
  else
    status_fail "tar-Backup fehlgeschlagen."
    return 1
  fi
}

github_deploy() {
  section "GITHUB DEPLOY"

  if ! git_check_repo; then
    status_fail "Kein Git-Repository."
    return
  fi

  if ! git remote get-url origin >/dev/null 2>&1; then
    status_fail "Kein Remote 'origin' gefunden."
    echo "Beispiel:"
    echo "git remote add origin https://github.com/Sm8s/admin-tool-kit-menu.git"
    return
  fi

  if [ ! -f "$SCRIPT_DIR/index.html" ] && [ ! -f "$SCRIPT_DIR/dashboard.html" ] && [ ! -f "$SCRIPT_DIR/dashboard-3.html" ]; then
    status_warn "Keine HTML-Startdatei gefunden."
    echo "Für GitHub Pages solltest du eine index.html im Projektordner haben."
    return
  fi

  if ! run_predeploy_backup; then
    status_fail "Deploy abgebrochen, weil das Backup fehlgeschlagen ist."
    return
  fi

  local current_branch
  current_branch="$(git branch --show-current 2>/dev/null)"

  if [ -z "$current_branch" ]; then
    status_fail "Aktuelle Branch konnte nicht erkannt werden."
    return
  fi

  read -rp "Commit-Nachricht für Deploy [default: deploy update]: " deploy_msg
  [ -z "$deploy_msg" ] && deploy_msg="deploy update"

  status_info "Aktuelle Branch: $current_branch"
  status_info "Remote: $(git remote get-url origin 2>/dev/null)"

  git add .

  if git diff --cached --quiet && git diff --quiet; then
    status_warn "Keine Änderungen gefunden. Es wird trotzdem ein Push versucht."
  else
    if git commit -m "$deploy_msg"; then
      status_ok "Commit erstellt."
    else
      status_warn "Commit fehlgeschlagen oder nichts zu committen."
    fi
  fi

  if git push -u origin "$current_branch"; then
    status_ok "Code erfolgreich nach GitHub gepusht."
  else
    status_fail "Push fehlgeschlagen."
    return
  fi

  echo
  status_info "Danach auf GitHub prüfen:"
  echo "1) Repository öffnen: https://github.com/Sm8s/admin-tool-kit-menu"
  echo "2) Settings -> Pages"
  echo "3) Source: Deploy from a branch"
  echo "4) Branch: $current_branch"
  echo "5) Folder: /(root)"
  echo
  status_info "Mögliche Live-URL:"
  echo "https://sm8s.github.io/admin-tool-kit-menu/"
}

show_backup_log() {
  section "BACKUP LOG"

  if [ -f "$SCRIPT_DIR/backup.log" ]; then
    tail -n 80 "$SCRIPT_DIR/backup.log"
  else
    status_warn "backup.log nicht gefunden."
  fi
}

run_quick_backup() {
  section "QUICK BACKUP"

  if [ -f "$SCRIPT_DIR/quick-backup-rsync.sh" ]; then
    bash "$SCRIPT_DIR/quick-backup-rsync.sh"
  elif [ -f "$SCRIPT_DIR/backup.sh" ]; then
    bash "$SCRIPT_DIR/backup.sh"
  else
    status_fail "Kein Backup-Skript gefunden."
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

show_recent_logs() {
  section "SESSION LOG"

  if [ -f "$LOG_FILE" ]; then
    tail -n 50 "$LOG_FILE"
  else
    status_warn "Noch kein Session-Log vorhanden."
  fi
}

submenu_git() {
  while true; do
    header
    echo "GIT CENTER"
    menu_item 1 "Git-Status"
    menu_item 2 "Aktuelle Branch"
    menu_item 3 "Letzte Commits"
    menu_item 4 "Remote anzeigen"
    menu_item 5 "Quick add + commit"
    menu_item 6 "GitHub Deploy Info"
    menu_item 7 "GitHub Deploy starten"
    menu_item 0 "Zurück"
    echo
    read -rp "Auswahl: " choice

    case "$choice" in
      1) show_git_status; pause_screen ;;
      2) show_git_branch; pause_screen ;;
      3) show_git_log; pause_screen ;;
      4) show_git_remote; pause_screen ;;
      5) git_quick_add_commit; pause_screen ;;
      6) show_github_deploy_info; pause_screen ;;
      7) github_deploy; pause_screen ;;
      0) break ;;
      *) status_fail "Ungültige Auswahl."; pause_screen ;;
    esac
  done
}

submenu_reports() {
  while true; do
    header
    echo "REPORT CENTER"
    menu_item 1 "Report-Zusammenfassung"
    menu_item 2 "Neuesten Report anzeigen"
    menu_item 3 "Report auswählen"
    menu_item 4 "Report-Ordner anzeigen"
    menu_item 5 "Reports durchsuchen"
    menu_item 6 "log-analyzer.sh"
    menu_item 0 "Zurück"
    echo
    read -rp "Auswahl: " choice

    case "$choice" in
      1) show_reports_summary; pause_screen ;;
      2) open_latest_report; pause_screen ;;
      3) choose_report; pause_screen ;;
      4) ls -la "$REPORT_DIR" 2>/dev/null || echo "Ordner nicht gefunden."; pause_screen ;;
      5) search_reports; pause_screen ;;
      6) run_script "log-analyzer.sh"; pause_screen ;;
      0) break ;;
      *) status_fail "Ungültige Auswahl."; pause_screen ;;
    esac
  done
}

submenu_git() {
  while true; do
    header
    echo "GIT CENTER"
    menu_item 1 "Git-Status"
    menu_item 2 "Aktuelle Branch"
    menu_item 3 "Letzte Commits"
    menu_item 4 "Remote anzeigen"
    menu_item 5 "Quick add + commit"
    menu_item 6 "GitHub Deploy Info"
    menu_item 7 "GitHub Deploy starten"
    menu_item 0 "Zurück"
    echo
    read -rp "Auswahl: " choice

    case "$choice" in
      1) show_git_status; pause_screen ;;
      2) show_git_branch; pause_screen ;;
      3) show_git_log; pause_screen ;;
      4) show_git_remote; pause_screen ;;
      5) git_quick_add_commit; pause_screen ;;
      6) show_github_deploy_info; pause_screen ;;
      7) github_deploy; pause_screen ;;
      0) break ;;
      *) status_fail "Ungültige Auswahl."; pause_screen ;;
    esac
  done
}

submenu_backup() {
  while true; do
    header
    echo "BACKUP CENTER"
    menu_item 1 "Quick Backup starten"
    menu_item 2 "Backup-Ordner anzeigen"
    menu_item 3 "Backup-Log anzeigen"
    menu_item 0 "Zurück"
    echo
    read -rp "Auswahl: " choice

    case "$choice" in
      1) run_quick_backup; pause_screen ;;
      2) ls -la "$BACKUP_DIR" 2>/dev/null || echo "Ordner nicht gefunden."; pause_screen ;;
      3) show_backup_log; pause_screen ;;
      0) break ;;
      *) status_fail "Ungültige Auswahl."; pause_screen ;;
    esac
  done
}

submenu_project() {
  while true; do
    header
    echo "PROJECT CENTER"
    menu_item 1 "Project Health Check"
    menu_item 2 "Projektstatistik"
    menu_item 3 "Projektdateien anzeigen"
    menu_item 4 "Dashboard öffnen"
    menu_item 5 "Session-Log anzeigen"
    menu_item 6 "matrix.sh starten"
    menu_item 0 "Zurück"
    echo
    read -rp "Auswahl: " choice

    case "$choice" in
      1) show_project_health; pause_screen ;;
      2) show_basic_stats; pause_screen ;;
      3) show_project_tree; pause_screen ;;
      4) open_dashboard; pause_screen ;;
      5) show_recent_logs; pause_screen ;;
      6) run_script "matrix.sh"; pause_screen ;;
      0) break ;;
      *) status_fail "Ungültige Auswahl."; pause_screen ;;
    esac
  done
}

submenu_tools() {
  while true; do
    header
    echo "TOOLS"
    menu_item 1 "System-Werkzeuge anzeigen"
    menu_item 2 "Aktuellen Pfad anzeigen"
    menu_item 3 "Reports-Ordner öffnen"
    menu_item 4 "Backups-Ordner öffnen"
    menu_item 5 "Boot-Sequenz erneut anzeigen"
    menu_item 0 "Zurück"
    echo
    read -rp "Auswahl: " choice

    case "$choice" in
      1) show_system_tools; pause_screen ;;
      2) pwd; pause_screen ;;
      3) ls -la "$REPORT_DIR" 2>/dev/null || echo "Ordner nicht gefunden."; pause_screen ;;
      4) ls -la "$BACKUP_DIR" 2>/dev/null || echo "Ordner nicht gefunden."; pause_screen ;;
      5) hacker_boot; pause_screen ;;
      0) break ;;
      *) status_fail "Ungültige Auswahl."; pause_screen ;;
    esac
  done
}

main_menu() {
  while true; do
    header
    echo "HAUPTMENÜ"
    menu_item 1 "Audit & System"
    menu_item 2 "Report Center"
    menu_item 3 "Git Center"
    menu_item 4 "Backup Center"
    menu_item 5 "Project Center"
    menu_item 6 "Tools"
    menu_item 0 "Beenden"
    echo
    read -rp "Auswahl: " choice

    case "$choice" in
      1) submenu_audit ;;
      2) submenu_reports ;;
      3) submenu_git ;;
      4) submenu_backup ;;
      5) submenu_project ;;
      6) submenu_tools ;;
      0) status_ok "Programm beendet."; exit 0 ;;
      *) status_fail "Ungültige Auswahl."; pause_screen ;;
    esac
  done
}

init_theme
hacker_boot
log_action "Toolkit menu started"
main_menu