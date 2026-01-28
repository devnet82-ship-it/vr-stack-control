#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing dependency: $1"
    echo "On Arch/CachyOS: sudo pacman -S --needed yad ripgrep"
    exit 1
  fi
}

need_cmd systemctl
need_cmd yad
need_cmd rg

mkdir -p "$HOME/bin"
mkdir -p "$HOME/.config/systemd/user"
mkdir -p "$HOME/.local/share/applications"
mkdir -p "$HOME/.config/vr-stack"

install -m 0755 "$ROOT_DIR/bin/vr-stack-run.sh" "$HOME/bin/vr-stack-run.sh"
install -m 0755 "$ROOT_DIR/bin/vr-control-gui.sh" "$HOME/bin/vr-control-gui.sh"
install -m 0755 "$ROOT_DIR/bin/vr-tray.sh" "$HOME/bin/vr-tray.sh"
install -m 0755 "$ROOT_DIR/bin/quest-watch.sh" "$HOME/bin/quest-watch.sh"
install -m 0644 "$ROOT_DIR/systemd/vr-stack-control.service" "$HOME/.config/systemd/user/vr-stack-control.service"
install -m 0644 "$ROOT_DIR/systemd/vr-stack-tray.service" "$HOME/.config/systemd/user/vr-stack-tray.service"
install -m 0644 "$ROOT_DIR/desktop/vr-control-panel.desktop" "$HOME/.local/share/applications/vr-control-panel.desktop"
install -m 0644 "$ROOT_DIR/desktop/vr-tray.desktop" "$HOME/.local/share/applications/vr-tray.desktop"

# Only create config if user doesn't already have one
if [[ ! -f "$HOME/.config/vr-stack/stack.conf" ]]; then
  install -m 0644 "$ROOT_DIR/config/stack.conf.example" "$HOME/.config/vr-stack/stack.conf"
fi

systemctl --user daemon-reload

# Make desktop file "trusted" on some desktops (best effort)
gio set "$HOME/.local/share/applications/vr-control-panel.desktop" metadata::trusted true 2>/dev/null || true
gio set "$HOME/.local/share/applications/vr-tray.desktop" metadata::trusted true 2>/dev/null || true
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo "Installed VR Stack Control."
echo "Launch: VR Control Panel (from your app launcher)"
echo "Service name: vr-stack-control.service"
echo "Logs: journalctl --user -u vr-stack-control.service -f"
