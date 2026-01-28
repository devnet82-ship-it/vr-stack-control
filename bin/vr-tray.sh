#!/usr/bin/env bash
set -Eeuo pipefail

SERVICE="vr-stack-control.service"
TRAY_SERVICE="vr-stack-tray.service"
APP_TITLE="VR Stack Control"

WATCH_PIDFILE="$HOME/.local/share/vr-stack/quest-watch.pid"
mkdir -p "$(dirname "$WATCH_PIDFILE")"

have() { command -v "$1" >/dev/null 2>&1; }

is_active() { systemctl --user is-active --quiet "$SERVICE"; }
is_enabled() { systemctl --user is-enabled --quiet "$SERVICE"; }

start_vr()   { systemctl --user start "$SERVICE"; }
stop_vr()    { systemctl --user stop "$SERVICE"; }
restart_vr() { systemctl --user restart "$SERVICE"; }

toggle_autostart() {
  if is_enabled; then systemctl --user disable "$SERVICE" || true
  else systemctl --user enable "$SERVICE" || true
  fi
}

open_panel() { /usr/bin/env bash -lc "$HOME/bin/vr-control-gui.sh" >/dev/null 2>&1 & disown || true; }

show_logs() {
  journalctl --user -u "$SERVICE" -n 250 --no-pager | \
    yad --text-info --title="$APP_TITLE Logs" --width=980 --height=650 --wrap
}

adb_state() {
  if ! have adb; then echo "no-adb"; return; fi
  if adb devices 2>/dev/null | awk 'NR>1 && $2=="device"{found=1} END{exit !found}'; then
    echo "connected"; return
  fi
  if adb devices 2>/dev/null | awk 'NR>1 && ($2=="unauthorized" || $2=="offline"){found=1} END{exit !found}'; then
    echo "unauthorized"; return
  fi
  echo "disconnected"
}

wivrn_state() {
  local regex="${WIVRN_CONNECTED_REGEX:-connected|connection established|client.*connected|new client|session.*created}"
  local text
  text="$(journalctl --user -u "$SERVICE" -n 250 --no-pager 2>/dev/null || true)"
  [[ -z "$text" ]] && { echo "unknown"; return; }
  echo "$text" | rg -i -q "$regex" && echo "connected" || echo "disconnected"
}

watch_running() {
  [[ -f "$WATCH_PIDFILE" ]] || return 1
  local pid
  pid="$(cat "$WATCH_PIDFILE" 2>/dev/null || true)"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

start_watch() {
  if watch_running; then return 0; fi
  /usr/bin/env bash -lc "$HOME/bin/quest-watch.sh" >/dev/null 2>&1 &
  echo $! > "$WATCH_PIDFILE"
}

stop_watch() {
  if ! watch_running; then rm -f "$WATCH_PIDFILE"; return 0; fi
  local pid
  pid="$(cat "$WATCH_PIDFILE" 2>/dev/null || true)"
  kill "$pid" 2>/dev/null || true
  rm -f "$WATCH_PIDFILE"
}

toggle_watch() {
  if watch_running; then stop_watch; else start_watch; fi
}

show_status() {
  local s="STOPPED"; is_active && s="RUNNING"
  local a="DISABLED"; is_enabled && a="ENABLED"
  local q; q="$(adb_state)"
  local w; w="$(wivrn_state)"
  local watcher="OFF"; watch_running && watcher="ON"
  yad --info --title="$APP_TITLE" --text="Service: $s\nAutostart: $a\nTray watcher: $watcher\nQuest ADB: $q\nWiVRn client: $w"
}

quit_tray() {
  stop_watch || true

  # If launched by systemd, stop the unit so it doesn't respawn.
  if systemctl --user is-active --quiet "$TRAY_SERVICE"; then
    systemctl --user stop "$TRAY_SERVICE" || true
  fi

  exit 0
}

menu() {
  local s="STOPPED"; is_active && s="RUNNING"
  local a="DISABLED"; is_enabled && a="ENABLED"
  local q; q="$(adb_state)"
  local w; w="$(wivrn_state)"
  local watcher="OFF"; watch_running && watcher="ON"

  cat <<MENU
Open Control Panel!open_panel
Status… (Service: $s / Quest: $q / WiVRn: $w)!show_status
Start VR!start_vr
Stop VR!stop_vr
Restart VR!restart_vr
Autostart VR: $a!toggle_autostart
Watcher: $watcher (Quest + WiVRn)!toggle_watch
View logs…!show_logs
Quit tray icon!quit_tray
MENU
}

export -f open_panel start_vr stop_vr restart_vr toggle_autostart show_logs show_status toggle_watch quit_tray

yad --notification \
  --text="$APP_TITLE" \
  --image=preferences-system \
  --menu="$(menu)" \
  --command="bash -lc open_panel" \
  --no-middle \
  --listen
