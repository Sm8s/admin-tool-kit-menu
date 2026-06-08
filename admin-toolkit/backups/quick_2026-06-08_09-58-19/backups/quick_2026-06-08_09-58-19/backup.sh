#!/bin/bash

set -u

SCRIPT_NAME="$(basename "$0")"
VERSION="2.0.0"

DEFAULT_SOURCE="."
DEFAULT_BACKUP_ROOT="./backups"
DEFAULT_RETENTION_DAYS=7
DEFAULT_LOG_FILE="./backup.log"

SOURCE_DIR="$DEFAULT_SOURCE"
BACKUP_ROOT="$DEFAULT_BACKUP_ROOT"
RETENTION_DAYS="$DEFAULT_RETENTION_DAYS"
LOG_FILE="$DEFAULT_LOG_FILE"
MODE="auto"
DRY_RUN=0
VERBOSE=0
CREATE_CHECKSUM=1
TIMESTAMP="$(date +"%Y-%m-%d_%H-%M-%S")"

print_banner() {
  echo "=========================================="
  echo " Advanced Backup Utility"
  echo " Script: $SCRIPT_NAME"
  echo " Version: $VERSION"
  echo "=========================================="
}

log() {
  local level="$1"
  local message="$2"
  local now
  now="$(date +"%Y-%m-%d %H:%M:%S")"
  echo "[$now] [$level] $message" | tee -a "$LOG_FILE"
}

debug() {
  if [ "$VERBOSE" -eq 1 ]; then
    log "DEBUG" "$1"
  fi
}

show_help() {
  cat <<EOF
Usage:
  bash backup.sh [options]

Options:
  -s, --source PATH        Quellordner
  -d, --dest PATH          Backup-Zielordner
  -m, --mode MODE          backup mode: auto | rsync | tar
  -r, --retention DAYS     Aufbewahrung in Tagen
  -l, --log PATH           Logdatei
  -n, --dry-run            Nur simulieren
  -v, --verbose            Ausführliche Ausgabe
  --no-checksum            Keine SHA256-Datei erzeugen
  -h, --help               Hilfe anzeigen

Examples:
  bash backup.sh
  bash backup.sh -s "./data" -d "./backups" -m rsync
  bash backup.sh --source "." --dest "./backups" --retention 14 --verbose
EOF
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

normalize_path() {
  local p="$1"
  if [ -z "$p" ]; then
    echo ""
    return
  fi
  if [ -d "$p" ] || [ -f "$p" ]; then
    cd "$p" 2>/dev/null && pwd && return
  fi
  echo "$p"
}

validate_number() {
  case "$1" in
    ''|*[!0-9]*)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -s|--source)
        SOURCE_DIR="$2"
        shift 2
        ;;
      -d|--dest)
        BACKUP_ROOT="$2"
        shift 2
        ;;
      -m|--mode)
        MODE="$2"
        shift 2
        ;;
      -r|--retention)
        RETENTION_DAYS="$2"
        shift 2
        ;;
      -l|--log)
        LOG_FILE="$2"
        shift 2
        ;;
      -n|--dry-run)
        DRY_RUN=1
        shift
        ;;
      -v|--verbose)
        VERBOSE=1
        shift
        ;;
      --no-checksum)
        CREATE_CHECKSUM=0
        shift
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        echo "Unbekanntes Argument: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

prepare_environment() {
  mkdir -p "$BACKUP_ROOT"
  touch "$LOG_FILE" 2>/dev/null || {
    echo "Logdatei konnte nicht erstellt werden: $LOG_FILE"
    exit 1
  }
}

validate_inputs() {
  if [ ! -d "$SOURCE_DIR" ]; then
    log "ERROR" "Quellordner existiert nicht: $SOURCE_DIR"
    exit 1
  fi

  if ! validate_number "$RETENTION_DAYS"; then
    log "ERROR" "Retention muss eine Zahl sein: $RETENTION_DAYS"
    exit 1
  fi

  case "$MODE" in
    auto|rsync|tar) ;;
    *)
      log "ERROR" "Ungültiger Modus: $MODE"
      exit 1
      ;;
  esac
}

detect_backup_mode() {
  if [ "$MODE" = "auto" ]; then
    if command_exists rsync; then
      MODE="rsync"
    else
      MODE="tar"
    fi
  fi
  log "INFO" "Verwendeter Backup-Modus: $MODE"
}

get_source_size() {
  du -sh "$SOURCE_DIR" 2>/dev/null | awk '{print $1}'
}

generate_checksum_file() {
  local target="$1"
  local checksum_file="${target}.sha256"

  if [ "$CREATE_CHECKSUM" -eq 0 ]; then
    debug "Checksum deaktiviert"
    return
  fi

  if command_exists sha256sum; then
    sha256sum "$target" > "$checksum_file"
    log "INFO" "SHA256 erstellt: $checksum_file"
  elif command_exists certutil; then
    certutil -hashfile "$target" SHA256 > "$checksum_file" 2>/dev/null
    log "INFO" "SHA256 via certutil erstellt: $checksum_file"
  else
    log "WARN" "Keine Prüfsummenfunktion verfügbar"
  fi
}

perform_rsync_backup() {
  local backup_dir="$BACKUP_ROOT/rsync_backup_$TIMESTAMP"
  mkdir -p "$backup_dir"

  local rsync_cmd=(
    rsync
    -avh
    --delete
    --stats
    "$SOURCE_DIR"/
    "$backup_dir"/
  )

  if [ "$DRY_RUN" -eq 1 ]; then
    rsync_cmd=(rsync -avh --delete --stats --dry-run "$SOURCE_DIR"/ "$backup_dir"/)
  fi

  log "INFO" "Starte rsync-Backup nach: $backup_dir"
  "${rsync_cmd[@]}" | tee -a "$LOG_FILE"
  local status=${PIPESTATUS[0]:-0}

  if [ "$status" -eq 0 ]; then
    log "INFO" "Rsync-Backup erfolgreich"
  else
    log "ERROR" "Rsync-Backup fehlgeschlagen"
    exit 1
  fi
}

perform_tar_backup() {
  local archive_name="backup_$TIMESTAMP.tar.gz"
  local target_archive="$BACKUP_ROOT/$archive_name"

  log "INFO" "Starte tar-Backup: $target_archive"

  if [ "$DRY_RUN" -eq 1 ]; then
    log "INFO" "[Dry-Run] Würde Archiv erstellen aus: $SOURCE_DIR"
    return
  fi

  tar -czf "$target_archive" "$SOURCE_DIR" 2>>"$LOG_FILE"
  local status=$?

  if [ "$status" -eq 0 ]; then
    log "INFO" "Tar-Backup erfolgreich"
    generate_checksum_file "$target_archive"
  else
    log "ERROR" "Tar-Backup fehlgeschlagen"
    exit 1
  fi
}

cleanup_old_backups() {
  log "INFO" "Bereinige Backups älter als $RETENTION_DAYS Tage"

  if command_exists find; then
    find "$BACKUP_ROOT" -mindepth 1 -mtime +"$RETENTION_DAYS" -exec rm -rf {} + 2>>"$LOG_FILE"
    log "INFO" "Alte Backups bereinigt"
  else
    log "WARN" "find nicht verfügbar, Cleanup übersprungen"
  fi
}

print_summary() {
  echo
  echo "Backup abgeschlossen."
  echo "Quelle: $SOURCE_DIR"
  echo "Ziel:   $BACKUP_ROOT"
  echo "Modus:  $MODE"
  echo "Größe:  $(get_source_size)"
  echo "Log:    $LOG_FILE"
}

main() {
  print_banner
  parse_args "$@"
  prepare_environment
  validate_inputs

  SOURCE_DIR="$(normalize_path "$SOURCE_DIR")"
  BACKUP_ROOT="$(normalize_path "$BACKUP_ROOT" 2>/dev/null || echo "$BACKUP_ROOT")"

  log "INFO" "Backup gestartet"
  log "INFO" "Quelle: $SOURCE_DIR"
  log "INFO" "Ziel: $BACKUP_ROOT"

  detect_backup_mode

  case "$MODE" in
    rsync)
      if command_exists rsync; then
        perform_rsync_backup
      else
        log "ERROR" "rsync wurde angefordert, ist aber nicht installiert"
        exit 1
      fi
      ;;
    tar)
      perform_tar_backup
      ;;
  esac

  cleanup_old_backups
  log "INFO" "Backup abgeschlossen"
  print_summary
}

main "$@"