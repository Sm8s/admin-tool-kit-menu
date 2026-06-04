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
  {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
  } | tee -a "$REPORT_FILE"
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
    echo "powershell.exe wurde nicht gefunden."
    echo "Dieses Skript ist für Windows + Git Bash gedacht."
    exit 1
  fi

  if ! is_number "$PING_LIMIT"; then
    echo "PING_LIMIT muss numerisch sein."
    exit 1
  fi
}

collect_system_header() {
  write_separator "SYSTEM"
  write_line "Skriptname       : $SCRIPT_NAME"
  write_line "Computername     : $(hostname 2>/dev/null || echo unbekannt)"
  write_line "Aktueller Benutzer: $(whoami 2>/dev/null || echo unbekannt)"
  write_line "Zeit             : $(date)"
  write_line "Skriptpfad       : $SCRIPT_DIR"

  local admin_status
  admin_status="$(run_powershell "
    \$current = [Security.Principal.WindowsIdentity]::GetCurrent()
    \$principal = New-Object Security.Principal.WindowsPrincipal(\$current)
    \$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  " | tail -n 1)"

  write_line "Admin-Rechte     : ${admin_status:-unbekannt}"
}

collect_local_users() {
  write_separator "LOKALE BENUTZERKONTEN"

  local result
  result="$(run_powershell "
    if (Get-Command Get-LocalUser -ErrorAction SilentlyContinue) {
      Get-LocalUser |
      Select-Object Name, Enabled, PasswordRequired, LastLogon, SID, PrincipalSource |
      Sort-Object Name |
      Format-Table -AutoSize
    } else {
      net user
    }
  ")"

  if [ -n "$result" ]; then
    write_line "$result"
  else
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
    write_line "$result"
  else
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
    write_line "$result"
  else
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
    write_line "$result"
  else
    write_line "Keine Profilordner gefunden."
  fi
}

collect_logged_in_users() {
  write_separator "AKTUELL ANGEMELDETE USER"

  local result
  result="$(query user 2>/dev/null | tr -d '\r')"

  if [ -n "$result" ]; then
    write_line "$result"
  else
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
    write_line "$result"
  else
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
    write_line "$result"
  else
    write_line "Keine Netzwerk-Interfaces gefunden."
  fi
}

collect_network_neighbors() {
  write_separator "NETZWERK NACHBARN"

  local only_active_filter="1 -eq 1"
  if [ "$ONLY_ACTIVE_NEIGHBORS" -eq 1 ]; then
    only_active_filter="\$_.State -ne 'Unreachable' -and \$_.State -ne 'Permanent'"
  fi

  local resolve_code=""
  if [ "$RESOLVE_HOSTNAMES" -eq 1 ]; then
    resolve_code='
      $hostName = ""
      try {
        $dns = Resolve-DnsName $n.IPAddress -ErrorAction Stop
        $hostName = ($dns | Select-Object -First 1 -ExpandProperty NameHost)
      } catch {
        $hostName = ""
      }'
  else
    resolve_code='$hostName = ""'
  fi

  local result
  result="$(run_powershell "
    \$rows = @()
    try {
      \$neighbors = Get-NetNeighbor -AddressFamily IPv4 |
        Where-Object {
          $only_active_filter -and
          \$_.IPAddress -match '^\d+\.\d+\.\d+\.\d+$' -and
          \$_.IPAddress -notlike '127.*'
        }

      foreach (\$n in \$neighbors) {
        $resolve_code

        \$rows += [PSCustomObject]@{
          IPAddress      = \$n.IPAddress
          Hostname       = \$hostName
          MACAddress     = \$n.LinkLayerAddress
          State          = \$n.State
          InterfaceAlias = \$n.InterfaceAlias
        }
      }

      if (\$rows.Count -gt 0) {
        \$rows | Sort-Object IPAddress | Format-Table -Wrap -AutoSize
      } else {
        'Keine Netzwerk-Nachbarn gefunden.'
      }
    } catch {
      'Get-NetNeighbor nicht verfügbar.'
    }
  ")"

  if [ -n "$result" ]; then
    write_line "$result"
  else
    write_line "Keine Nachbarn ermittelt."
  fi
}

collect_arp_cache() {
  write_separator "ARP CACHE"

  local result
  result="$(arp -a 2>/dev/null | tr -d '\r')"

  if [ -n "$result" ]; then
    write_line "$result"
  else
    write_line "Keine ARP-Daten verfügbar."
  fi
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
    write_line "$stats"
  else
    write_line "Keine Statistik verfügbar."
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

  write_line "JSON exportiert: $JSON_FILE"
}

main() {
  parse_args "$@"
  ensure_output_dir
  check_environment

  log "INFO" "Skript gestartet"
  log "INFO" "Report-Datei: $REPORT_FILE"

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
    write_line "Netzwerkscan deaktiviert."
  fi

  export_csv
  export_json

  echo
  echo "Fertig."
  echo "TXT : $REPORT_FILE"
  [ "$EXPORT_CSV" -eq 1 ] && echo "CSV : $CSV_FILE"
  [ "$EXPORT_JSON" -eq 1 ] && echo "JSON: $JSON_FILE"

  log "INFO" "Skript abgeschlossen"
}

main "$@"