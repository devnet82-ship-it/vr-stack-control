#!/usr/bin/env bash
set -Eeuo pipefail

SERVICE="vr-stack-control.service"
TRAY_SERVICE="vr-stack-tray.service"
APP_TITLE="VR Stack Control"

CFG_DIR="$HOME/.config/vr-stack"
CFG="$CFG_DIR/stack.conf"
RUN_LOG="$HOME/.local/share/vr-stack.log"

mkdir -p "$CFG_DIR"

PROFILES_DIR="$CFG_DIR/profiles"
mkdir -p "$PROFILES_DIR"

have() { command -v "$1" >/dev/null 2>&1; }

# ---------------- systemd helpers ----------------
is_active()  { systemctl --user is-active --quiet "$SERVICE"; }
is_enabled() { systemctl --user is-enabled --quiet "$SERVICE"; }

status_str()    { is_active && echo "RUNNING" || echo "STOPPED"; }
autostart_str() { is_enabled && echo "ENABLED" || echo "DISABLED"; }

start_vr()   { systemctl --user start "$SERVICE"; }
stop_vr()    { systemctl --user stop "$SERVICE"; }
restart_vr() { systemctl --user restart "$SERVICE"; }

tray_is_active()  { systemctl --user is-active --quiet "$TRAY_SERVICE"; }
tray_is_enabled() { systemctl --user is-enabled --quiet "$TRAY_SERVICE"; }
tray_status_str() { tray_is_active && echo "RUNNING" || echo "STOPPED"; }
tray_autostart_str() { tray_is_enabled && echo "ENABLED" || echo "DISABLED"; }

tray_start()  { systemctl --user start "$TRAY_SERVICE" || true; }
tray_stop()   { systemctl --user stop "$TRAY_SERVICE" || true; }
tray_enable() { systemctl --user enable "$TRAY_SERVICE" || true; }
tray_disable(){ systemctl --user disable "$TRAY_SERVICE" || true; }

toggle_autostart() {
  if is_enabled; then systemctl --user disable "$SERVICE" || true
  else systemctl --user enable "$SERVICE" || true
  fi
}

# ---------------- connections ----------------
adb_state() {
  if ! have adb; then echo "no-adb"; return; fi
  if adb devices 2>/dev/null | awk 'NR>1 && $2=="device"{found=1} END{exit !found}'; then echo "connected"; return; fi
  if adb devices 2>/dev/null | awk 'NR>1 && ($2=="unauthorized" || $2=="offline"){found=1} END{exit !found}'; then echo "unauthorized"; return; fi
  echo "disconnected"
}

wivrn_state() {
  local regex="${WIVRN_CONNECTED_REGEX:-connected|connection established|client.*connected|new client|session.*created}"
  local text
  text="$(journalctl --user -u "$SERVICE" -n 250 --no-pager 2>/dev/null || true)"
  [[ -z "$text" ]] && { echo "unknown"; return; }
  echo "$text" | rg -i -q "$regex" && echo "connected" || echo "disconnected"
}

# ---------------- profiles ----------------
list_profiles() { ls -1 "$PROFILES_DIR"/*.conf 2>/dev/null | xargs -n1 basename | sed 's/\.conf$//' || true; }

current_profile_name() {
  if [[ -L "$CFG" ]]; then
    basename "$(readlink -f "$CFG")" | sed 's/\.conf$//'
  else
    echo "default"
  fi
}

ensure_default_profile() {
  if [[ ! -f "$PROFILES_DIR/default.conf" ]]; then
    # Seed from existing config if present (and not a symlink)
    [[ -f "$CFG" && ! -L "$CFG" ]] && cp -f "$CFG" "$PROFILES_DIR/default.conf" || true
  fi

  # Ensure stack.conf is a symlink to a profile
  if [[ ! -L "$CFG" ]]; then
    rm -f "$CFG"
    ln -sf "$PROFILES_DIR/default.conf" "$CFG"
  fi
}

switch_profile() {
  ensure_default_profile
  local items choice
  items="$(list_profiles)"
  [[ -z "$items" ]] && yad --info --title="$APP_TITLE" --text="No profiles found." && return 0

  choice="$(printf "%s\n" $items | yad --list --title="Select Profile" --column="Profile" --height=420 --width=520 --center --button="Select":0 --button="Cancel":1 2>/dev/null)" || return 1
  [[ -z "$choice" ]] && return 0
  ln -sf "$PROFILES_DIR/$choice.conf" "$CFG"
}

save_current_as_profile() {
  ensure_default_profile
  local name
  name="$(yad --entry --title="New Profile" --text="Profile name:" --entry-text="new-profile" --center 2>/dev/null)" || return 1
  [[ -z "${name// }" ]] && return 0
  name="$(sed -E 's/[^a-zA-Z0-9._-]+/-/g' <<<"$name")"
  cp -f "$(readlink -f "$CFG")" "$PROFILES_DIR/$name.conf"
  ln -sf "$PROFILES_DIR/$name.conf" "$CFG"
}

delete_profile() {
  ensure_default_profile
  local items choice cur
  cur="$(current_profile_name)"
  items="$(list_profiles | sed "/^$cur$/d")"
  [[ -z "$items" ]] && yad --info --title="$APP_TITLE" --text="No deletable profiles (current is '$cur')." && return 0

  choice="$(printf "%s\n" $items | yad --list --title="Delete Profile" --column="Profile" --height=420 --width=520 --center --button="Delete":0 --button="Cancel":1 2>/dev/null)" || return 1
  [[ -z "$choice" ]] && return 0
  rm -f "$PROFILES_DIR/$choice.conf"
}

# ---------------- app picker ----------------
strip_exec_placeholders() { sed -E "s/[[:space:]]%[0-9]?[a-zA-Z]//g" <<<"$1"; }

desktop_apps_list() {
  local dirs=("$HOME/.local/share/applications" "/usr/share/applications")
  for d in "${dirs[@]}"; do
    [[ -d "$d" ]] || continue
    for f in "$d"/*.desktop; do
      [[ -f "$f" ]] || continue
      local name exec
      name="$(rg -m1 '^Name=' "$f" | head -n1 | sed 's/^Name=//')"
      exec="$(rg -m1 '^Exec=' "$f" | head -n1 | sed 's/^Exec=//')"
      [[ -n "${name:-}" && -n "${exec:-}" ]] || continue
      exec="$(strip_exec_placeholders "$exec")"
      printf "%s\t%s\t%s\n" "$name" "$exec" "$f"
    done
  done | sort -u
}

path_cmds_list() {
  local cmds=( slimevr wayvr wivrn-server monado-service envision steamvr )
  for c in "${cmds[@]}"; do
    command -v "$c" >/dev/null 2>&1 && printf "%s\t%s\n" "$c (PATH)" "$c"
  done
}

build_menu() {
  {
    desktop_apps_list | while IFS=$'\t' read -r name exec file; do
      printf "%s\t%s\n" "$name (Desktop)" "$exec"
    done
    path_cmds_list
    printf "%s\t%s\n" "None (skip this stage)" ""
  } | awk -F'\t' 'NF>=2 {print $1 "|" $2}' | sort -u
}

pick_from_menu() {
  local title="$1"
  local current_exec="${2:-}"
  local menu values choice picked_label custom

  menu="$(build_menu)"
  values="$(cut -d'|' -f1 <<<"$menu" | paste -sd',' -)"

  choice="$(yad --title="$APP_TITLE" \
    --form --center --width=960 --height=250 --borders=12 \
    --field="$title:CB" "$values" \
    --field="Custom command (overrides dropdown):" "$current_exec" \
    --button="OK":0 --button="Cancel":1 2>/dev/null)" || return 1

  picked_label="$(cut -d'|' -f1 <<<"$choice")"
  custom="$(cut -d'|' -f2- <<<"$choice")"

  if [[ -n "${custom// }" ]]; then
    printf "%s\n" "$custom"
    return 0
  fi

  awk -F'|' -v lbl="$picked_label" '$1==lbl {print $2; exit}' <<<"$menu"
}

# ---------------- config ----------------
load_cfg() {
  # Defaults
  TRACK_CMD="/opt/slimevr/slimevr"
  TRACK_READY_PGREP="slimevr\.jar"
  SERVER_CMD="wivrn-server"
  SERVER_PGREP="wivrn-server"
  VR_CMD="wayvr"
  VR_PGREP="(^|/)(wayvr)(\\s|$)"
  OPENXR_JSON="/usr/share/openxr/1/openxr_wivrn.json"

  [[ -f "$CFG" ]] && source "$CFG" || true
}

save_cfg() {
  cat > "$CFG" <<EOF2
# VR Stack configuration (bash-sourced)

TRACK_CMD="$(printf "%s" "${TRACK_CMD:-}" | sed "s/\"/\\\\\"/g")"
TRACK_READY_PGREP="$(printf "%s" "${TRACK_READY_PGREP:-}" | sed "s/\"/\\\\\"/g")"

SERVER_CMD="$(printf "%s" "${SERVER_CMD:-}" | sed "s/\"/\\\\\"/g")"
SERVER_PGREP="$(printf "%s" "${SERVER_PGREP:-}" | sed "s/\"/\\\\\"/g")"

VR_CMD="$(printf "%s" "${VR_CMD:-}" | sed "s/\"/\\\\\"/g")"
VR_PGREP="$(printf "%s" "${VR_PGREP:-}" | sed "s/\"/\\\\\"/g")"

OPENXR_JSON="$(printf "%s" "${OPENXR_JSON:-}" | sed "s/\"/\\\\\"/g")"
EOF2
}

edit_patterns() {
  load_cfg
  local out
  out="$(yad --title="$APP_TITLE" --form --center --width=960 --height=270 --borders=12 \
    --field="Tracking ready pgrep (blank = no wait):" "${TRACK_READY_PGREP:-}" \
    --field="Server pgrep pattern:" "${SERVER_PGREP:-}" \
    --field="VR app pgrep pattern:" "${VR_PGREP:-}" \
    --button="OK":0 --button="Cancel":1 2>/dev/null)" || return 1

  TRACK_READY_PGREP="$(cut -d'|' -f1 <<<"$out")"
  SERVER_PGREP="$(cut -d'|' -f2 <<<"$out")"
  VR_PGREP="$(cut -d'|' -f3 <<<"$out")"
  save_cfg
}

set_tracking() {
  load_cfg
  TRACK_CMD="$(pick_from_menu "Tracking app" "${TRACK_CMD:-}")" || return 0
  [[ "$TRACK_CMD" == *slimevr* ]] && TRACK_READY_PGREP="slimevr\.jar"
  save_cfg
}

set_server() {
  load_cfg
  SERVER_CMD="$(pick_from_menu "Server app" "${SERVER_CMD:-}")" || return 0
  [[ "$SERVER_CMD" == "wivrn-server" ]] && SERVER_PGREP="wivrn-server"
  save_cfg
}

set_vr_app() {
  load_cfg
  VR_CMD="$(pick_from_menu "VR app (OpenXR client)" "${VR_CMD:-}")" || return 0
  [[ "$VR_CMD" == "wayvr" ]] && VR_PGREP="(^|/)(wayvr)(\\s|$)"
  save_cfg
}

# ---------------- debug ----------------
copy_debug_bundle() {
  local tmp
  tmp="$(mktemp)"
  {
    echo "=== VR DEBUG BUNDLE ==="
    echo "Timestamp: $(date -Is)"
    echo "Host: $(hostname)"
    echo
    echo "--- Profile ---"
    echo "Current profile: $(current_profile_name)"
    echo "Config file: $(readlink -f "$CFG" 2>/dev/null || echo "$CFG")"
    echo
    echo "--- config ---"
    [[ -f "$CFG" ]] && cat "$CFG" || echo "(missing)"
    echo
    echo "--- systemd status ---"
    systemctl --user status "$SERVICE" --no-pager || true
    echo
    echo "--- systemd show ---"
    systemctl --user show -p ActiveState -p SubState -p Result "$SERVICE" || true
    echo
    echo "--- connections ---"
    echo "Quest ADB: $(adb_state)"
    echo "WiVRn: $(wivrn_state)"
    echo
    echo "--- processes ---"
    pgrep -af "slimevr\.jar|wivrn-server|(^|/)(wayvr)(\\s|$)|/opt/slimevr/slimevr|vr-stack-run\.sh" || echo "(none)"
    echo
    echo "--- journal (last 250) ---"
    journalctl --user -u "$SERVICE" -n 250 --no-pager || true
    echo
    echo "--- runner log ($RUN_LOG) tail 200 ---"
    [[ -f "$RUN_LOG" ]] && tail -n 200 "$RUN_LOG" || echo "(missing)"
  } > "$tmp"

  if have xclip; then
    xclip -selection clipboard < "$tmp" || true
    yad --info --title="$APP_TITLE" --text="Debug info copied to clipboard."
  else
    yad --text-info --title="$APP_TITLE — Debug Bundle" --filename="$tmp" --width=980 --height=650
  fi
  rm -f "$tmp"
}

show_logs() {
  journalctl --user -u "$SERVICE" -n 250 --no-pager 2>/dev/null | \
    yad --text-info --title="$APP_TITLE — Logs (journalctl)" --width=980 --height=650 --wrap
}

open_runner_log() {
  [[ -f "$RUN_LOG" ]] || { yad --info --title="$APP_TITLE" --text="No runner log yet:\n$RUN_LOG"; return 0; }
  if have xdg-open; then
    xdg-open "$RUN_LOG" >/dev/null 2>&1 || true
  else
    yad --text-info --title="$APP_TITLE — Runner log" --width=980 --height=650 --wrap --filename="$RUN_LOG"
  fi
}

# ---------------- action dispatcher (for tray / future) ----------------
if [[ "${1:-}" == "--do" ]]; then
  shift || true
  case "${1:-}" in
    start) start_vr ;;
    tray-start) tray_start ;;
    tray-stop) tray_stop ;;
    tray-enable) tray_enable ;;
    tray-disable) tray_disable ;;
    stop) stop_vr ;;
    restart) restart_vr ;;
    autostart) toggle_autostart ;;
    set-tracking) set_tracking ;;
    set-server) set_server ;;
    set-vr) set_vr_app ;;
    patterns) edit_patterns ;;
    profile-select) switch_profile ;;
    profile-saveas) save_current_as_profile ;;
    profile-delete) delete_profile ;;
    logs) show_logs ;;
    debug-bundle) copy_debug_bundle ;;
    open-runlog) open_runner_log ;;
    *) : ;;
  esac
  exit 0
fi

# ---------------- tabbed UI ----------------
ensure_default_profile
load_cfg

while true; do
  STATE="$(status_str)"
  AUTO="$(autostart_str)"
  PROF="$(current_profile_name)"
  QUEST="$(adb_state)"
  WIVRN="$(wivrn_state)"

  load_cfg

  CONTROL_TEXT=$(
    cat <<TXT
<b>Status</b>
Service: <b>$STATE</b>
Autostart: <b>$AUTO</b>
Profile: <b>$PROF</b>
Tray: <b>$(tray_status_str)</b> (Autostart: <b>$(tray_autostart_str)</b>)

<b>Connections</b>
Quest (ADB): <b>$QUEST</b>
WiVRn: <b>$WIVRN</b>
TXT
  )

  APPS_TEXT=$(
    cat <<TXT
<b>Current app config (active profile)</b>

Tracking:
  CMD: <b>${TRACK_CMD:-}</b>
  READY: <b>${TRACK_READY_PGREP:-}</b>

Server:
  CMD: <b>${SERVER_CMD:-}</b>
  PGREP: <b>${SERVER_PGREP:-}</b>

VR App:
  CMD: <b>${VR_CMD:-}</b>
  PGREP: <b>${VR_PGREP:-}</b>
TXT
  )

  yad --title="$APP_TITLE" \
    --width=980 --height=640 --center --borders=12 \
    --notebook \
    --tab="Control" \
      --form \
        --field="":LBL "$CONTROL_TEXT" \
        --field="":BTN "Start!bash -lc \"$HOME/bin/vr-control-gui.sh --do start\"" \
        --field="":BTN "Stop!bash -lc \"$HOME/bin/vr-control-gui.sh --do stop\"" \
        --field="":BTN "Restart!bash -lc \"$HOME/bin/vr-control-gui.sh --do restart\"" \
        --field="":BTN "Toggle autostart!bash -lc \"$HOME/bin/vr-control-gui.sh --do autostart\"" \
        --field="":BTN "Start tray!bash -lc \"$HOME/bin/vr-control-gui.sh --do tray-start\"" \
        --field="":BTN "Stop tray!bash -lc \"$HOME/bin/vr-control-gui.sh --do tray-stop\"" \
        --field="":BTN "Enable tray autostart!bash -lc \"$HOME/bin/vr-control-gui.sh --do tray-enable\"" \
        --field="":BTN "Disable tray autostart!bash -lc \"$HOME/bin/vr-control-gui.sh --do tray-disable\"" \
    --tab="Apps" \
      --form \
        --field="":LBL "$APPS_TEXT" \
        --field="":BTN "Set Tracking…!bash -lc \"$HOME/bin/vr-control-gui.sh --do set-tracking\"" \
        --field="":BTN "Set Server…!bash -lc \"$HOME/bin/vr-control-gui.sh --do set-server\"" \
        --field="":BTN "Set VR App…!bash -lc \"$HOME/bin/vr-control-gui.sh --do set-vr\"" \
        --field="":BTN "Edit pgrep patterns…!bash -lc \"$HOME/bin/vr-control-gui.sh --do patterns\"" \
        --field="":BTN "Save config!bash -lc \"$HOME/bin/vr-control-gui.sh --do save\"" \
    --tab="Profiles" \
      --form \
        --field="":LBL "<b>Profiles</b>\nCurrent: <b>$PROF</b>\n\nProfiles live in:\n$PROFILES_DIR" \
        --field="":BTN "Select profile…!bash -lc \"$HOME/bin/vr-control-gui.sh --do profile-select\"" \
        --field="":BTN "Save current as new…!bash -lc \"$HOME/bin/vr-control-gui.sh --do profile-saveas\"" \
        --field="":BTN "Delete a profile…!bash -lc \"$HOME/bin/vr-control-gui.sh --do profile-delete\"" \
    --tab="Debug" \
      --form \
        --field="":LBL "<b>Debug tools</b>\n\nService logs come from journalctl.\nRunner log: $RUN_LOG" \
        --field="":BTN "View logs…!bash -lc \"$HOME/bin/vr-control-gui.sh --do logs\"" \
        --field="":BTN "Copy debug bundle…!bash -lc \"$HOME/bin/vr-control-gui.sh --do debug-bundle\"" \
        --field="":BTN "Open runner log…!bash -lc \"$HOME/bin/vr-control-gui.sh --do open-runlog\"" \
    --button="Refresh":252 \
    --button="Close":1 \
    2>/dev/null

  rc=$?
  [[ "$rc" == "252" ]] && continue
  exit 0
done
