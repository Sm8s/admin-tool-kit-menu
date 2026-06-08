#!/bin/bash

set -u

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/reports"
TIMESTAMP="$(date +"%Y-%m-%d_%H-%M-%S")"

REPORT_FILE="$OUTPUT_DIR/user_network_audit_$TIMESTAMP.txt"
CSV_FILE="$OUTPUT_DIR/user_network_audit_$TIMESTAMP.csv"
JSON_FILE="$OUTPUT_DIR/user_network_audit_$TIMESTAMP.json"
LOG_FILE="$OUTPUT_DIR/user_network_audit_$TIMESTAMP.log"

SCAN_NETWORK=1
EXPORT_CSV=0
EXPORT_JSON=0
VERBOSE=0
PING_SWEEP=0
PING_LIMIT=30
INCLUDE_EVENTLOG=1
ONLY_ACTIVE_NEIGHBORS=1
CUSTOM_SUBNET=""
RESOLVE_HOSTNAMES=1

USE_COLOR=1
USE_UNICODE=1
TERM_WIDTH="$(tput cols 2>/dev/null || echo 100)"

if [ -n "${NO_COLOR:-}" ]; then
  USE_COLOR=0
fi

init_colors() {
  if [ "$USE_COLOR" -eq 1 ]; then
    RESET='\033[0m'
    BOLD='\033[1m'
    DIM='\033[2m'

    BLACK='\033[0;30m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[0;37m'

    BRIGHT_BLACK='\033[0;90m'
    BRIGHT_RED='\033[0;91m'
    BRIGHT_GREEN='\033[0;92m'
    BRIGHT_YELLOW='\033[0;93m'
    BRIGHT_BLUE='\033[0;94m'
    BRIGHT_MAGENTA='\033[0;95m'
    BRIGHT_CYAN='\033[0;96m'
    BRIGHT_WHITE='\033[0;97m'
  else
    RESET=''
    BOLD=''
    DIM=''

    BLACK=''
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    WHITE=''

    BRIGHT_BLACK=''
    BRIGHT_RED=''
    BRIGHT_GREEN=''
    BRIGHT_YELLOW=''
    BRIGHT_BLUE=''
    BRIGHT_MAGENTA=''
    BRIGHT_CYAN=''
    BRIGHT_WHITE=''
  fi
}

repeat_char() {
  local char="$1"
  local count="$2"
  local out=""
  local i=0
  while [ "$i" -lt "$count" ]; do
    out="${out}${char}"
    i=$((i + 1))
  done
  printf "%s" "$out"
}

print_rule() {
  printf "%b\n" "${BRIGHT_BLACK}$(repeat_char "─" "$TERM_WIDTH")${RESET}"
}

print_banner() {
  local title="$1"
  print_rule
  printf "%b\n" "${BOLD}${BRIGHT_CYAN}  $title${RESET}"
  printf "%b\n" "${DIM}${BRIGHT_WHITE}  Windows User & Network Audit${RESET}"
  print_rule
}

print_section_terminal() {
  local title="$1"
  echo
  printf "%b\n" "${BOLD}${BRIGHT_BLUE}▶ $title${RESET}"
  printf "%b\n" "${BRIGHT_BLACK}$(repeat_char "─" 60)${RESET}"
}

print_subsection() {
  local title="$1"
  echo
  printf "%b\n" "${BOLD}${CYAN}• $title${RESET}"
}

kv_line() {
  local key="$1"
  local value="$2"
  printf "%b %-24s %b %s\n" "${BRIGHT_WHITE}" "$key" "${BRIGHT_BLACK}:${RESET}" "$value"
}

status_badge() {
  local state="$1"
  case "$state" in
    OK|Reachable|Connected|Enabled|Up|True|Loaded|Active)
      printf "%b" "${BOLD}${GREEN}[OK]${RESET}"
      ;;
    WARN|Warning|Stale|Unknown)
      printf "%b" "${BOLD}${YELLOW}[WARN]${RESET}"
      ;;
    ERROR|Critical|Disabled|Down|False|Unreachable|Failed)
      printf "%b" "${BOLD}${RED}[ERR]${RESET}"
      ;;
    *)
      printf "%b" "${BOLD}${MAGENTA}[INFO]${RESET}"
      ;;
  esac
}

print_info() {
  printf "%b %s\n" "$(status_badge INFO)" "$1"
}

print_ok() {
  printf "%b %s\n" "$(status_badge OK)" "$1"
}

print_warn() {
  printf "%b %s\n" "$(status_badge WARN)" "$1"
}

print_error() {
  printf "%b %s\n" "$(status_badge ERROR)" "$1"
}

print_table_header() {
  printf "%b\n" "${BOLD}${BRIGHT_WHITE}%-18s %-22s %-22s %-12s${RESET}" "TYP" "NAME/IP" "DETAIL" "STATUS"
  printf "%b\n" "${BRIGHT_BLACK}$(repeat_char "─" 85)${RESET}"
}

print_table_row() {
  local c1="$1"
  local c2="$2"
  local c3="$3"
  local c4="$4"

  local status_colored
  case "$c4" in
    OK|Reachable|Enabled|Loaded|Active|True)
      status_colored="${GREEN}$c4${RESET}"
      ;;
    Warning|Stale|Unknown)
      status_colored="${YELLOW}$c4${RESET}"
      ;;
    Disabled|Unreachable|Error|Failed|False)
      status_colored="${RED}$c4${RESET}"
      ;;
    *)
      status_colored="${CYAN}$c4${RESET}"
      ;;
  esac

  printf "%-18s %-22s %-22s %b\n" "$c1" "$c2" "$c3" "$status_colored"
}

log() {
  local level="$1"
  local msg="$2"
  local now
  now="$(date +"%Y-%m-%d %H:%M:%S")"
  echo "[$now] [$level] $msg" >> "$LOG_FILE"
  if [ "$VERBOSE" -eq 1 ]; then
    echo "[$level] $msg"
  fi
}

show_help() {
  cat <<EOF
Usage:
  bash $SCRIPT_NAME [options]

Options:
  --no-network         Kein Netzwerkscan
  --csv                CSV-Datei exportieren
  --json               JSON-Datei exportieren
  --ping-sweep         Vorher kleines Ping-Warmup im Netzwerk
  --ping-limit N       Wie viele Hosts pro /24 geprüft werden (default: 30)
  --subnet X.Y.Z       Eigenes /24-Subnetz scannen, z. B. 192.168.178
  --no-eventlog        Kein Versuch, Eventlog-Logins zu lesen
  --all-neighbors      Auch nicht-aktive Nachbarn anzeigen
  --no-resolve         Keine Hostname-Auflösung
  -v, --verbose        Mehr Ausgabe
  -h, --help           Hilfe
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --no-network)
        SCAN_NETWORK=0
        shift
        ;;
      --csv)
        EXPORT_CSV=1
        shift
        ;;
      --json)
        EXPORT_JSON=1
        shift
        ;;
      --ping-sweep)
        PING_SWEEP=1
        shift
        ;;
      --ping-limit)
        PING_LIMIT="$2"
        shift 2
        ;;
      --subnet)
        CUSTOM_SUBNET="$2"
        shift 2
        ;;
      --no-eventlog)
        INCLUDE_EVENTLOG=0
        shift
        ;;
      --all-neighbors)
        ONLY_ACTIVE_NEIGHBORS=0
        shift
        ;;
      --no-resolve)
        RESOLVE_HOSTNAMES=0
        shift
        ;;
      -v|--verbose)
        VERBOSE=1
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

ensure_output_dir() {
  mkdir -p "$OUTPUT_DIR"
  : > "$REPORT_FILE"
  : > "$LOG_FILE"
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

write_separator() {
  print_section_terminal "$1"
  {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
  } >> "$REPORT_FILE"
}

write_line() {
  echo "$1" | tee -a "$REPORT_FILE"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

run_powershell() {
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$1" 2>>"$LOG_FILE" | tr -d '\r'
}

escape_json() {
  echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

check_environment() {
  log "INFO" "Prüfe Umgebung"

  if ! command_exists powershell.exe; then
    print_error "powershell.exe wurde nicht gefunden."
    echo "Dieses Skript ist für Windows + Git Bash gedacht."
    exit 1
  fi

  if ! is_number "$PING_LIMIT"; then
    print_error "PING_LIMIT muss numerisch sein."
    exit 1
  fi
}

collect_system_header() {
  write_separator "SYSTEM"

  local computer current_user now admin_status
  computer="$(hostname 2>/dev/null || echo unbekannt)"
  current_user="$(whoami 2>/dev/null || echo unbekannt)"
  now="$(date)"

  admin_status="$(run_powershell "
    \$current = [Security.Principal.WindowsIdentity]::GetCurrent()
    \$principal = New-Object Security.Principal.WindowsPrincipal(\$current)
    \$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  " | tail -n 1)"

  kv_line "Skriptname" "$SCRIPT_NAME"
  kv_line "Computername" "$computer"
  kv_line "Aktueller Benutzer" "$current_user"
  kv_line "Zeit" "$now"
  kv_line "Skriptpfad" "$SCRIPT_DIR"
  kv_line "Admin-Rechte" "${admin_status:-unbekannt}"

  {
    echo "Skriptname: $SCRIPT_NAME"
    echo "Computername: $computer"
    echo "Aktueller Benutzer: $current_user"
    echo "Zeit: $now"
    echo "Skriptpfad: $SCRIPT_DIR"
    echo "Admin-Rechte: ${admin_status:-unbekannt}"
  } >> "$REPORT_FILE"
}

collect_summary_stats() {
  write_separator "ZUSAMMENFASSUNG"

  local stats
  stats="$(run_powershell "
    \$localUsers = 0
    \$profiles = 0
    \$neighbors = 0

    try {
      if (Get-Command Get-LocalUser -ErrorAction SilentlyContinue) {
        \$localUsers = (Get-LocalUser).Count
      }
    } catch {}

    try {
      \$profiles = (Get-CimInstance Win32_UserProfile | Where-Object { \$_.Special -eq \$false -and \$_.LocalPath }).Count
    } catch {}

    try {
      \$neighbors = (Get-NetNeighbor -AddressFamily IPv4 | Where-Object { \$_.IPAddress -match '^\d+\.\d+\.\d+\.\d+$' }).Count
    } catch {}

    Write-Output ('LocalUsers=' + \$localUsers)
    Write-Output ('Profiles=' + \$profiles)
    Write-Output ('Neighbors=' + \$neighbors)
  ")"

  if [ -n "$stats" ]; then
    echo "$stats" | while IFS='=' read -r key value; do
      [ -n "$key" ] && kv_line "$key" "$value"
    done
    echo "$stats" >> "$REPORT_FILE"
  else
    print_warn "Keine Statistik verfügbar."
    write_line "Keine Statistik verfügbar."
  fi
}

collect_local_users() {
  write_separator "LOKALE BENUTZERKONTEN"

  local result
  result="$(run_powershell "
    if (Get-Command Get-LocalUser -ErrorAction SilentlyContinue) {
      Get-LocalUser |
      Select-Object Name, Enabled, PasswordRequired, LastLogon |
      ConvertTo-Csv -NoTypeInformation
    } else {
      ''
    }
  ")"

  if [ -n "$result" ]; then
    print_subsection "Benutzerübersicht"
    print_table_header

    echo "$result" | tail -n +2 | while IFS=',' read -r name enabled passwordrequired lastlogon; do
      name="${name%\"}"; name="${name#\"}"
      enabled="${enabled%\"}"; enabled="${enabled#\"}"
      passwordrequired="${passwordrequired%\"}"; passwordrequired="${passwordrequired#\"}"

      local state="Disabled"
      [ "$enabled" = "True" ] && state="Enabled"

      print_table_row "LocalUser" "$name" "PW:$passwordrequired" "$state"
    done

    echo "$result" >> "$REPORT_FILE"
  else
    print_warn "Keine lokalen Benutzerkonten ermittelbar."
    write_line "Keine lokalen Benutzerkonten ermittelbar."
  fi
}

collect_local_groups() {
  write_separator "LOKALE GRUPPEN"

  local result
  result="$(run_powershell "
    if (Get-Command Get-LocalGroup -ErrorAction SilentlyContinue) {
      Get-LocalGroup |
      Select-Object Name, Description |
      Sort-Object Name |
      Format-Table -AutoSize
    } else {
      net localgroup
    }
  ")"

  if [ -n "$result" ]; then
    print_ok "Lokale Gruppen erfolgreich gelesen."
    write_line "$result"
  else
    print_warn "Keine lokalen Gruppen ermittelbar."
    write_line "Keine lokalen Gruppen ermittelbar."
  fi
}

collect_user_profiles() {
  write_separator "BENUTZERPROFILE"

  local result
  result="$(run_powershell "
    Get-CimInstance -ClassName Win32_UserProfile |
    Where-Object { \$_.LocalPath -ne \$null -and \$_.Special -eq \$false } |
    Select-Object @{
        Name='UserName'; Expression={
          try {
            \$sid = New-Object System.Security.Principal.SecurityIdentifier(\$_.SID)
            \$sid.Translate([System.Security.Principal.NTAccount]).Value
          } catch {
            \$_.SID
          }
        }
      },
      LocalPath,
      SID,
      Loaded,
      @{
        Name='LastUseTime'; Expression={
          try { [Management.ManagementDateTimeConverter]::ToDateTime(\$_.LastUseTime) } catch { \$_.LastUseTime }
        }
      } |
    Sort-Object LocalPath |
    Format-Table -Wrap -AutoSize
  ")"

  if [ -n "$result" ]; then
    print_ok "Benutzerprofile erfolgreich gelesen."
    write_line "$result"
  else
    print_warn "Keine Benutzerprofile gefunden."
    write_line "Keine Benutzerprofile gefunden."
  fi
}

collect_profile_folder_details() {
  write_separator "PROFILORDNER DETAILS"

  local result
  result="$(run_powershell "
    Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue |
    Where-Object { \$_.Name -notin @('Public','Default','Default User','All Users','defaultuser0') } |
    ForEach-Object {
      \$ntUserPath = Join-Path \$_.FullName 'NTUSER.DAT'
      \$ntDate = \$null
      if (Test-Path \$ntUserPath) {
        \$ntDate = (Get-Item \$ntUserPath -Force).LastWriteTime
      }

      [PSCustomObject]@{
        Name = \$_.Name
        FullName = \$_.FullName
        FolderLastWrite = \$_.LastWriteTime
        NtUserDatLastWrite = \$ntDate
      }
    } |
    Sort-Object Name |
    Format-Table -Wrap -AutoSize
  ")"

  if [ -n "$result" ]; then
    print_ok "Profilordner gelesen."
    write_line "$result"
  else
    print_warn "Keine Profilordner gefunden."
    write_line "Keine Profilordner gefunden."
  fi
}

collect_logged_in_users() {
  write_separator "AKTUELL ANGEMELDETE USER"

  local result
  result="$(query user 2>/dev/null | tr -d '\r')"

  if [ -n "$result" ]; then
    print_ok "Angemeldete Benutzer gelesen."
    write_line "$result"
  else
    print_warn "query user liefert keine Daten oder benötigt andere Rechte."
    write_line "query user liefert keine Daten oder benötigt andere Rechte."
  fi
}

collect_last_logins_from_eventlog() {
  if [ "$INCLUDE_EVENTLOG" -ne 1 ]; then
    return
  fi

  write_separator "LETZTE INTERAKTIVE LOGINS AUS EVENTLOG"

  local result
  result="$(run_powershell "
    try {
      \$startDate = (Get-Date).AddDays(-14)

      Get-WinEvent -ProviderName 'Microsoft-Windows-Security-Auditing' -ErrorAction Stop |
      Where-Object {
        \$_.Id -eq 4624 -and
        \$_.TimeCreated -ge \$startDate
      } |
      Select-Object -First 300 |
      ForEach-Object {
        \$props = \$_.Properties
        [PSCustomObject]@{
          TimeCreated = \$_.TimeCreated
          TargetUser  = if (\$props.Count -gt 5) { \$props[5].Value } else { '' }
          TargetDomain = if (\$props.Count -gt 6) { \$props[6].Value } else { '' }
          LogonType   = if (\$props.Count -gt 8) { \$props[8].Value } else { '' }
          IpAddress   = if (\$props.Count -gt 18) { \$props[18].Value } else { '' }
        }
      } |
      Where-Object { \$_.TargetUser -and \$_.TargetUser -notmatch 'DWM-|UMFD-|SYSTEM|LOCAL SERVICE|NETWORK SERVICE' } |
      Sort-Object TimeCreated -Descending |
      Select-Object -First 30 |
      Format-Table -Wrap -AutoSize
    } catch {
      'Security-Eventlog nicht lesbar oder keine Berechtigung.'
    }
  ")"

  if [ -n "$result" ]; then
    print_ok "Eventlog-Einträge gelesen."
    write_line "$result"
  else
    print_warn "Keine Eventlog-Daten verfügbar."
    write_line "Keine Eventlog-Daten verfügbar."
  fi
}

detect_subnet_candidates() {
  run_powershell "
    try {
      Get-NetIPAddress -AddressFamily IPv4 |
      Where-Object {
        \$_.IPAddress -notlike '169.254*' -and
        \$_.IPAddress -notlike '127.*' -and
        \$_.PrefixLength -ge 24
      } |
      ForEach-Object {
        \$bytes = ([IPAddress]\$_.IPAddress).GetAddressBytes()
        \"\$($bytes[0]).\$($bytes[1]).\$($bytes[2])\"
      } |
      Sort-Object -Unique
    } catch {}
  "
}

warm_up_network_cache() {
  if [ "$PING_SWEEP" -ne 1 ]; then
    log "INFO" "Ping-Sweep deaktiviert"
    return
  fi

  log "INFO" "Starte Ping-Warmup"
  print_info "Starte Ping-Warmup für Neighbor-/ARP-Cache."

  local subnet_list
  if [ -n "$CUSTOM_SUBNET" ]; then
    subnet_list="$CUSTOM_SUBNET"
  else
    subnet_list="$(detect_subnet_candidates)"
  fi

  [ -z "$subnet_list" ] && return

  while IFS= read -r subnet; do
    [ -z "$subnet" ] && continue
    log "INFO" "Wärme ARP/Neighbor-Cache für Subnetz $subnet"

    run_powershell "
      \$base = '$subnet'
      1..$PING_LIMIT | ForEach-Object {
        Start-Job -ScriptBlock {
          param(\$target)
          Test-Connection -ComputerName \$target -Count 1 -Quiet | Out-Null
        } -ArgumentList (\"\$base.\$_\") | Out-Null
      }
      Start-Sleep -Seconds 4
      Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
    " >/dev/null
  done <<< "$subnet_list"
}

collect_network_interfaces() {
  write_separator "NETZWERK INTERFACES"

  local result
  result="$(run_powershell "
    try {
      Get-NetIPConfiguration |
      Select-Object InterfaceAlias, InterfaceDescription,
        @{Name='IPv4';Expression={ (\$_.IPv4Address | ForEach-Object { \$_.IPAddress }) -join ', ' }},
        @{Name='Gateway';Expression={ (\$_.IPv4DefaultGateway | ForEach-Object { \$_.NextHop }) -join ', ' }},
        @{Name='DNS';Expression={ (\$_.DNSServer.ServerAddresses) -join ', ' }} |
      Format-Table -Wrap -AutoSize
    } catch {
      'Keine Interface-Daten verfügbar.'
    }
  ")"

  if [ -n "$result" ]; then
    print_ok "Netzwerk-Interfaces gelesen."
    write_line "$result"
  else
    print_warn "Keine Netzwerk-Interfaces gefunden."
    write_line "Keine Netzwerk-Interfaces gefunden."
  fi
}

collect_network_neighbors() {
  write_separator "NETZWERK NACHBARN"

  local result
  result="$(run_powershell "
    \$rows = @()
    try {
      \$neighbors = Get-NetNeighbor -AddressFamily IPv4 |
        Where-Object {
          \$_.IPAddress -match '^\d+\.\d+\.\d+\.\d+$' -and
          \$_.IPAddress -notlike '127.*'
        }

      foreach (\$n in \$neighbors) {
        \$hostName = ''
        try {
          \$dns = Resolve-DnsName \$n.IPAddress -ErrorAction Stop
          \$hostName = (\$dns | Select-Object -First 1 -ExpandProperty NameHost)
        } catch {}

        \$rows += [PSCustomObject]@{
          IPAddress      = \$n.IPAddress
          Hostname       = \$hostName
          MACAddress     = \$n.LinkLayerAddress
          State          = \$n.State
          InterfaceAlias = \$n.InterfaceAlias
        }
      }

      \$rows | ConvertTo-Csv -NoTypeInformation
    } catch {}
  ")"

  if [ -n "$result" ]; then
    print_subsection "Gefundene Geräte"
    print_table_header

    echo "$result" | tail -n +2 | while IFS=',' read -r ip host mac state iface; do
      ip="${ip%\"}"; ip="${ip#\"}"
      host="${host%\"}"; host="${host#\"}"
      mac="${mac%\"}"; mac="${mac#\"}"
      state="${state%\"}"; state="${state#\"}"

      [ -z "$host" ] && host="-"
      [ -z "$mac" ] && mac="-"

      print_table_row "Network" "$ip" "$host" "$state"
    done

    echo "$result" >> "$REPORT_FILE"
  else
    print_warn "Keine Nachbarn ermittelt."
    write_line "Keine Nachbarn ermittelt."
  fi
}

collect_arp_cache() {
  write_separator "ARP CACHE"

  local result
  result="$(arp -a 2>/dev/null | tr -d '\r')"

  if [ -n "$result" ]; then
    print_ok "ARP-Cache gelesen."
    write_line "$result"
  else
    print_warn "Keine ARP-Daten verfügbar."
    write_line "Keine ARP-Daten verfügbar."
  fi
}

export_csv() {
  if [ "$EXPORT_CSV" -ne 1 ]; then
    return
  fi

  log "INFO" "Exportiere CSV nach $CSV_FILE"

  run_powershell "
    \$rows = New-Object System.Collections.Generic.List[Object]

    try {
      if (Get-Command Get-LocalUser -ErrorAction SilentlyContinue) {
        Get-LocalUser | ForEach-Object {
          \$rows.Add([PSCustomObject]@{
            Type = 'LocalUser'
            Name = \$_.Name
            Detail1 = ('Enabled=' + \$_.Enabled)
            Detail2 = ('LastLogon=' + \$_.LastLogon)
            Detail3 = ('SID=' + \$_.SID)
          })
        }
      }
    } catch {}

    try {
      Get-CimInstance Win32_UserProfile |
      Where-Object { \$_.Special -eq \$false -and \$_.LocalPath } |
      ForEach-Object {
        \$lastUse = \$_.LastUseTime
        try { \$lastUse = [Management.ManagementDateTimeConverter]::ToDateTime(\$_.LastUseTime) } catch {}

        \$rows.Add([PSCustomObject]@{
          Type = 'UserProfile'
          Name = \$_.LocalPath
          Detail1 = ('Loaded=' + \$_.Loaded)
          Detail2 = ('LastUse=' + \$lastUse)
          Detail3 = ('SID=' + \$_.SID)
        })
      }
    } catch {}

    try {
      Get-NetNeighbor -AddressFamily IPv4 |
      Where-Object { \$_.IPAddress -match '^\d+\.\d+\.\d+\.\d+$' } |
      ForEach-Object {
        \$hostName = ''
        try {
          \$dns = Resolve-DnsName \$_.IPAddress -ErrorAction Stop
          \$hostName = (\$dns | Select-Object -First 1 -ExpandProperty NameHost)
        } catch {}

        \$rows.Add([PSCustomObject]@{
          Type = 'NetworkDevice'
          Name = \$_.IPAddress
          Detail1 = ('Host=' + \$hostName)
          Detail2 = ('MAC=' + \$_.LinkLayerAddress)
          Detail3 = ('State=' + \$_.State)
        })
      }
    } catch {}

    \$rows | Export-Csv -Path '$CSV_FILE' -NoTypeInformation -Encoding UTF8
  " >/dev/null

  print_ok "CSV exportiert: $CSV_FILE"
  write_line "CSV exportiert: $CSV_FILE"
}

export_json() {
  if [ "$EXPORT_JSON" -ne 1 ]; then
    return
  fi

  log "INFO" "Exportiere JSON nach $JSON_FILE"

  run_powershell "
    \$data = [ordered]@{}

    try {
      \$data.System = [ordered]@{
        ComputerName = \$env:COMPUTERNAME
        CurrentUser  = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        CollectedAt  = (Get-Date).ToString('s')
      }
    } catch {}

    try {
      if (Get-Command Get-LocalUser -ErrorAction SilentlyContinue) {
        \$data.LocalUsers = Get-LocalUser |
          Select-Object Name, Enabled, LastLogon, SID, PrincipalSource
      }
    } catch {}

    try {
      \$data.UserProfiles = Get-CimInstance Win32_UserProfile |
        Where-Object { \$_.Special -eq \$false -and \$_.LocalPath } |
        Select-Object LocalPath, SID, Loaded, LastUseTime
    } catch {}

    try {
      \$data.Neighbors = Get-NetNeighbor -AddressFamily IPv4 |
        Where-Object { \$_.IPAddress -match '^\d+\.\d+\.\d+\.\d+$' } |
        Select-Object IPAddress, LinkLayerAddress, State, InterfaceAlias
    } catch {}

    \$data | ConvertTo-Json -Depth 6 | Set-Content -Path '$JSON_FILE' -Encoding UTF8
  " >/dev/null

  print_ok "JSON exportiert: $JSON_FILE"
  write_line "JSON exportiert: $JSON_FILE"
}

main() {
  init_colors
  parse_args "$@"
  ensure_output_dir
  check_environment

  clear 2>/dev/null
  print_banner "USER NETWORK AUDIT"

  log "INFO" "Skript gestartet"
  log "INFO" "Report-Datei: $REPORT_FILE"

  print_info "Starte Analyse ..."
  collect_system_header
  collect_summary_stats
  collect_local_users
  collect_local_groups
  collect_user_profiles
  collect_profile_folder_details
  collect_logged_in_users
  collect_last_logins_from_eventlog

  if [ "$SCAN_NETWORK" -eq 1 ]; then
    warm_up_network_cache
    collect_network_interfaces
    collect_network_neighbors
    collect_arp_cache
  else
    write_separator "NETZWERK"
    print_warn "Netzwerkscan deaktiviert."
    write_line "Netzwerkscan deaktiviert."
  fi

  export_csv
  export_json

  echo
  print_rule
  print_ok "Analyse abgeschlossen"
  kv_line "TXT Report" "$REPORT_FILE"
  [ "$EXPORT_CSV" -eq 1 ] && kv_line "CSV Export" "$CSV_FILE"
  [ "$EXPORT_JSON" -eq 1 ] && kv_line "JSON Export" "$JSON_FILE"
  print_rule

  log "INFO" "Skript abgeschlossen"
}

main "$@"