#!/bin/bash

set -u

ADB="${ADB:-}"
DISCOVER_SECONDS="${ADB_WIFI_DISCOVER_SECONDS:-4}"
PAIR_TARGET=""
PAIR_CODE=""
MANUAL_CONNECT=""
SKIP_PAIR=0
RESTART_ADB=0
AUTO_YES=0
TMP_DIR=""

usage() {
  cat <<'EOF'
ADB Wi-Fi connect helper

Usage:
  ./adb-wifi-connect.command
  ./adb-wifi-connect.command --pair 192.168.1.20:36451 868723
  ./adb-wifi-connect.command --connect 192.168.1.20:45109

Options:
  --pair IP:PORT [CODE]   Pair with the phone pairing-code page first.
  --connect IP:PORT       Connect to a known wireless debugging connect port.
  --skip-pair             Do not ask for pairing information.
  --restart-adb           Run adb kill-server before starting.
  --seconds N             mDNS scan duration; N must be positive. Default: 4.
  -y, --yes               Non-interactive mode. Do not prompt.
  -h, --help              Show this help.

Tip:
  The pairing-code page port is for "adb pair".
  The Wireless debugging main-page port is for "adb connect".
EOF
}

info() {
  printf '\033[1;34m%s\033[0m\n' "$*" >&2
}

warn() {
  printf '\033[1;33m%s\033[0m\n' "$*" >&2
}

die() {
  printf '\033[1;31m%s\033[0m\n' "$*" >&2
  exit 1
}

is_positive_integer() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *[1-9]*) return 0 ;;
    *) return 1 ;;
  esac
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

find_adb() {
  if [ -n "$ADB" ]; then
    if [ -x "$ADB" ]; then
      printf '%s\n' "$ADB"
      return 0
    fi

    if command -v "$ADB" >/dev/null 2>&1; then
      command -v "$ADB"
      return 0
    fi
  fi

  if command -v adb >/dev/null 2>&1; then
    command -v adb
    return 0
  fi

  for candidate in \
    "${ANDROID_HOME:-}/platform-tools/adb" \
    "${ANDROID_SDK_ROOT:-}/platform-tools/adb" \
    "$HOME/Library/Android/sdk/platform-tools/adb" \
    "/Applications/Android Studio.app/Contents/bin/adb"
  do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

run_for() {
  local seconds="$1"
  local outfile="$2"
  shift 2

  "$@" >"$outfile" 2>&1 &
  local pid=$!
  sleep "$seconds"
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
}

show_devices() {
  echo
  info "Current adb devices:"
  "$ADB" devices -l
}

connect_target() {
  local target="$1"
  local output

  info "Trying adb connect $target"
  output=$("$ADB" connect "$target" 2>&1 || true)
  printf '%s\n' "$output"

  printf '%s\n' "$output" | grep -Eiq 'connected to|already connected to'
}

do_pair_if_needed() {
  if [ "$SKIP_PAIR" -eq 1 ]; then
    return 0
  fi

  if [ -z "$PAIR_TARGET" ] && [ "$AUTO_YES" -eq 0 ] && [ -t 0 ]; then
    echo
    info "Optional pairing"
    echo "If this computer is already paired with the phone, press Enter."
    printf 'Pairing page IP:PORT: '
    IFS= read -r PAIR_TARGET
  fi

  if [ -z "$PAIR_TARGET" ]; then
    return 0
  fi

  if [ -z "$PAIR_CODE" ]; then
    printf '6-digit pairing code: '
    IFS= read -r PAIR_CODE
  fi

  [ -n "$PAIR_CODE" ] || die "Pairing code is empty."

  info "Pairing with $PAIR_TARGET"
  printf '%s\n' "$PAIR_CODE" | "$ADB" pair "$PAIR_TARGET" || true

  if [ "$AUTO_YES" -eq 0 ] && [ -t 0 ]; then
    echo
    warn "After pairing, go back to the phone Wireless debugging main page."
    printf 'Press Enter when the main page is open and the phone is unlocked... '
    IFS= read -r _
  fi
}

discover_targets() {
  local browse_out="$TMP_DIR/browse.txt"
  local instances_file="$TMP_DIR/instances.txt"
  local targets_file="$TMP_DIR/targets.txt"
  local index=0

  : >"$instances_file"
  : >"$targets_file"

  info "Scanning wireless debugging connect services for ${DISCOVER_SECONDS}s"
  run_for "$DISCOVER_SECONDS" "$browse_out" dns-sd -B _adb-tls-connect._tcp local.

  awk '/Add/ && /_adb-tls-connect\._tcp\./ {
    sub(/^.*_adb-tls-connect\._tcp\. */, "")
    if (length($0) > 0) print
  }' "$browse_out" | sort -u >"$instances_file"

  if [ ! -s "$instances_file" ]; then
    return 1
  fi

  while IFS= read -r instance; do
    [ -n "$instance" ] || continue
    index=$((index + 1))

    local lookup_out="$TMP_DIR/lookup_$index.txt"
    local ip_out="$TMP_DIR/ip_$index.txt"
    local reached
    local host
    local port
    local ip
    local target_host

    run_for 2 "$lookup_out" dns-sd -L "$instance" _adb-tls-connect._tcp local.
    reached=$(awk '/can be reached at/ { line=$0 } END { print line }' "$lookup_out")

    host=$(printf '%s\n' "$reached" | sed -E 's/^.*can be reached at ([^ ]+):([0-9]+) \(interface.*$/\1/')
    port=$(printf '%s\n' "$reached" | sed -E 's/^.*can be reached at ([^ ]+):([0-9]+) \(interface.*$/\2/')

    if [ -z "$host" ] || [ -z "$port" ] || [ "$host" = "$reached" ] || [ "$port" = "$reached" ]; then
      continue
    fi

    run_for 2 "$ip_out" dns-sd -G v4 "$host"
    ip=$(awk '{
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {
          print $i
          exit
        }
      }
    }' "$ip_out")

    target_host="${ip:-${host%.}}"
    printf '%s:%s\n' "$target_host" "$port" >>"$targets_file"
  done <"$instances_file"

  sort -u "$targets_file"
}

prompt_manual_connect() {
  local target=""

  if [ "$AUTO_YES" -eq 1 ] || [ ! -t 0 ]; then
    return 1
  fi

  echo
  warn "No connectable port was found automatically."
  echo "On the phone, open Developer options > Wireless debugging."
  echo "Copy the IP address and port from the main Wireless debugging page."
  printf 'Manual connect IP:PORT, or Enter to quit: '
  IFS= read -r target

  [ -n "$target" ] || return 1
  connect_target "$target"
}

cleanup() {
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --pair)
      shift
      [ "$#" -gt 0 ] || die "--pair requires IP:PORT."
      PAIR_TARGET="$1"
      shift
      if [ "$#" -gt 0 ]; then
        case "$1" in
          --*) ;;
          *)
            PAIR_CODE="$1"
            shift
            ;;
        esac
      fi
      ;;
    --connect)
      shift
      [ "$#" -gt 0 ] || die "--connect requires IP:PORT."
      MANUAL_CONNECT="$1"
      shift
      ;;
    --skip-pair|--no-pair)
      SKIP_PAIR=1
      shift
      ;;
    --restart-adb)
      RESTART_ADB=1
      shift
      ;;
    --seconds)
      shift
      [ "$#" -gt 0 ] || die "--seconds requires a number."
      DISCOVER_SECONDS="$1"
      shift
      ;;
    -y|--yes)
      AUTO_YES=1
      shift
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

is_positive_integer "$DISCOVER_SECONDS" || die "--seconds must be a positive integer."

ADB=$(find_adb) || die "Could not find adb. Install Android Studio SDK Platform-Tools first."
need_cmd dns-sd

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/adb-wifi-connect.XXXXXX")
trap cleanup EXIT

if [ "$RESTART_ADB" -eq 1 ]; then
  info "Restarting adb server"
  "$ADB" kill-server || true
fi

"$ADB" start-server >/dev/null

if [ -n "$MANUAL_CONNECT" ]; then
  if connect_target "$MANUAL_CONNECT"; then
    show_devices
    exit 0
  fi
  show_devices
  exit 1
fi

do_pair_if_needed

targets=$(discover_targets || true)
connected=0

if [ -n "$targets" ]; then
  echo >&2
  info "Discovered connect target(s):"
  printf '%s\n' "$targets" >&2
  echo >&2

  while IFS= read -r target; do
    [ -n "$target" ] || continue
    if connect_target "$target"; then
      connected=1
    fi
  done <<EOF
$targets
EOF
fi

if [ "$connected" -eq 0 ]; then
  if prompt_manual_connect; then
    connected=1
  fi
fi

show_devices

if [ "$connected" -eq 1 ]; then
  echo
  info "Done. If Android Studio still does not show the phone, close the pairing dialog and refresh the device dropdown."
  exit 0
fi

echo
warn "Could not connect automatically."
echo "Keep the phone unlocked on the Wireless debugging main page, then run this tool again."
exit 1
