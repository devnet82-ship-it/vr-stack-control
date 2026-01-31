#!/usr/bin/env bash
set -Eeuo pipefail

CFG_DIR="$HOME/.config/vr-stack"
CFG="$CFG_DIR/stack.conf"
LOG="$HOME/.local/share/vr-stack.log"

mkdir -p "$CFG_DIR" "$(dirname "$LOG")"

# defaults
TRACK_CMD="/opt/slimevr/slimevr"
TRACK_READY_PGREP="slimevr\.jar"
SERVER_CMD="wivrn-server"
SERVER_PGREP="wivrn-server"
VR_CMD="wayvr"
VR_PGREP="(^|/)(wayvr)(\s|$)"
OPENXR_JSON="/usr/share/openxr/1/openxr_wivrn.json"

load_cfg() {
  [[ -f "$CFG" ]] || return 0
  while IFS= read -r line; do
    line="${line%%#*}"
    [[ -z "${line//[[:space:]]/}" ]] && continue
    [[ "$line" != *"="* ]] && continue
    k="${line%%=*}"
    v="${line#*=}"
    k="$(echo "$k" | xargs)"
    v="${v#"${v%%[![:space:]]*}"}"
    v="${v%"${v##*[![:space:]]}"}"
    if [[ $v == """*""" ]]; then v="${v:1:-1}"; fi
    if [[ $v == "'"*"'" ]]; then v="${v:1:-1}"; fi
    case "$k" in
      TRACK_CMD|tracking_cmd) TRACK_CMD="$v" ;;
      TRACK_READY_PGREP|track_ready_pgrep) TRACK_READY_PGREP="$v" ;;
      SERVER_CMD|server_cmd) SERVER_CMD="$v" ;;
      SERVER_PGREP|server_pgrep) SERVER_PGREP="$v" ;;
      VR_CMD|vr_cmd) VR_CMD="$v" ;;
      VR_PGREP|vr_pgrep) VR_PGREP="$v" ;;
      OPENXR_JSON|openxr_json) OPENXR_JSON="$v" ;;
    esac
  done < "$CFG"
}
load_cfg

have_pgrep() { pgrep -f "$1" >/dev/null 2>&1; }

# Force OpenXR runtime
mkdir -p "$HOME/.config/openxr/1"
ln -sf "$OPENXR_JSON" "$HOME/.config/openxr/1/active_runtime.json"
export OPENXR_RUNTIME_JSON="$HOME/.config/openxr/1/active_runtime.json"
export XR_RUNTIME_JSON="$OPENXR_RUNTIME_JSON"

exec >>"$LOG" 2>&1
echo "=== $(date -Is) vr-stack-run start ==="
echo "TRACK_CMD=$TRACK_CMD"
echo "SERVER_CMD=$SERVER_CMD"
echo "VR_CMD=$VR_CMD"
echo "OPENXR_JSON=$OPENXR_JSON"

# Start tracking
if [[ -n "${TRACK_CMD:-}" ]]; then
  if ! have_pgrep "$TRACK_CMD" && ! have_pgrep "slimevr\.jar"; then
    echo "Starting tracking: $TRACK_CMD"
    APPIMAGE_EXTRACT_AND_RUN=1 $TRACK_CMD & disown || true
  else
    echo "Tracking already running"
  fi

  if [[ -n "${TRACK_READY_PGREP:-}" ]]; then
    echo "Waiting for tracking ready: $TRACK_READY_PGREP"
    for _ in {1..120}; do
      have_pgrep "$TRACK_READY_PGREP" && break
      sleep 0.25
    done
  fi
fi

# Start server (dedupe)
if [[ -n "${SERVER_CMD:-}" ]]; then
  if have_pgrep "$SERVER_PGREP"; then
    echo "Server already running"
  else
    echo "Starting server: $SERVER_CMD"
    $SERVER_CMD & disown || true
    sleep 1
  fi
fi

# Start VR app
if [[ -n "${VR_CMD:-}" ]]; then
  if have_pgrep "$VR_PGREP"; then
    echo "VR app already running"
  else
    echo "Starting VR app: $VR_CMD"
    $VR_CMD & disown || true
  fi
fi

echo "=== $(date -Is) vr-stack-run done ==="
